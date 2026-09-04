#include "sync/SyncEngine.hpp"

#include "core/TaskStore.hpp"
#include "sync/SyncProtocol.hpp"
#include <algorithm>

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>

namespace waypoint {
namespace {

void assignError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

SyncEngine::SyncEngine(TaskStore *taskStore, QObject *parent) : QObject(parent), m_taskStore(taskStore) {
  m_periodicTimer.setInterval(15000);
  m_debounceTimer.setInterval(150);
  m_debounceTimer.setSingleShot(true);
  m_eventReconnectTimer.setSingleShot(true);
  connect(&m_periodicTimer, &QTimer::timeout, this, &SyncEngine::syncNow);
  connect(&m_debounceTimer, &QTimer::timeout, this, &SyncEngine::syncNow);
  connect(&m_eventReconnectTimer, &QTimer::timeout, this, &SyncEngine::openEventStream);
  connect(m_taskStore, &TaskStore::tasksChanged, this, &SyncEngine::scheduleSoon);
  connect(m_taskStore, &TaskStore::habitsChanged, this, &SyncEngine::scheduleSoon);
  connect(m_taskStore, &TaskStore::taskVisibilityChanged, this, &SyncEngine::scheduleSoon);
}

bool SyncEngine::enabled() const {
  return m_endpoint.isValid() && !m_endpoint.isEmpty() && !m_token.isEmpty();
}

QJsonObject SyncEngine::publicConfiguration() const {
  return {
      {QStringLiteral("endpoint"), m_endpoint.toString(QUrl::FullyEncoded)},
      {QStringLiteral("configured"), enabled()},
      {QStringLiteral("hasToken"), !m_token.isEmpty()},
  };
}

QJsonObject SyncEngine::status() const {
  return {
      {QStringLiteral("state"), m_state},
      {QStringLiteral("configured"), enabled()},
      {QStringLiteral("lastError"), m_lastError},
      {QStringLiteral("lastSuccessfulSync"),
       m_lastSuccessfulSync.isValid() ? m_lastSuccessfulSync.toUTC().toString(Qt::ISODateWithMs) : QString()},
  };
}

bool SyncEngine::updateConfiguration(const QString &endpointInput, const QByteArray &token, bool replaceToken,
                                     QString *errorMessage) {
  const QString trimmedEndpoint = endpointInput.trimmed();
  SyncConfiguration configuration;
  if (!trimmedEndpoint.isEmpty()) {
    configuration.endpoint = normalizeEndpoint(trimmedEndpoint, errorMessage);
    if (!configuration.endpoint.isValid() || configuration.endpoint.isEmpty()) {
      return false;
    }
    configuration.token = replaceToken ? token.trimmed() : m_token;
    if (configuration.token.isEmpty()) {
      assignError(errorMessage, QStringLiteral("Synchronization token cannot be empty"));
      return false;
    }
  }

  if (!m_taskStore->saveSyncConfiguration(configuration, errorMessage)) {
    return false;
  }
  m_endpoint = configuration.endpoint;
  m_token = configuration.token;
  m_debounceTimer.stop();
  closeEventStream();
  if (!enabled()) {
    m_periodicTimer.stop();
    setStatus(QStringLiteral("local-only"));
    return true;
  }

  if (!m_periodicTimer.isActive()) {
    m_periodicTimer.start();
  }
  setStatus(QStringLiteral("ready"));
  openEventStream();
  QTimer::singleShot(0, this, &SyncEngine::syncNow);
  return true;
}

void SyncEngine::start() {
  QString error;
  const SyncConfiguration configuration = m_taskStore->syncConfiguration(&error);
  if (!error.isEmpty()) {
    setStatus(QStringLiteral("error"), error);
    log(QStringLiteral("error"), error);
    return;
  }
  m_endpoint = configuration.endpoint;
  m_token = configuration.token;
  if (!enabled()) {
    setStatus(QStringLiteral("local-only"));
    log(QStringLiteral("info"), QStringLiteral("Remote synchronization is disabled"));
    return;
  }
  m_periodicTimer.start();
  setStatus(QStringLiteral("ready"));
  openEventStream();
  QTimer::singleShot(0, this, &SyncEngine::syncNow);
}

void SyncEngine::syncNow() {
  if (!enabled()) {
    return;
  }
  if (m_inFlight) {
    m_syncRequested = true;
    return;
  }

  QString error;
  const QJsonObject payload = buildSyncRequest(*m_taskStore, syncDeviceId(), &error);
  if (!error.isEmpty()) {
    setStatus(QStringLiteral("error"), error);
    log(QStringLiteral("error"), error);
    return;
  }
  QNetworkRequest request(m_endpoint);
  request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
  request.setRawHeader("Authorization", QByteArrayLiteral("Bearer ") + m_token);

  QNetworkReply *reply = m_network.post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
  reply->setParent(this);
  m_inFlight = true;
  setStatus(QStringLiteral("syncing"));
  connect(reply, &QNetworkReply::finished, this, &SyncEngine::finishSync);
}

void SyncEngine::finishSync() {
  auto *reply = qobject_cast<QNetworkReply *>(sender());
  m_inFlight = false;
  if (reply == nullptr) {
    continuePendingSync();
    return;
  }
  const auto finishRequest = [this, reply] {
    reply->deleteLater();
    continuePendingSync();
  };
  const QByteArray responseBytes = reply->readAll();
  if (reply->error() != QNetworkReply::NoError) {
    const QString message = QStringLiteral("HTTP %1: %2")
                                .arg(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt())
                                .arg(reply->errorString());
    setStatus(QStringLiteral("error"), message);
    log(QStringLiteral("warn"), QStringLiteral("Synchronization request failed: %1").arg(message));
    finishRequest();
    return;
  }

  QJsonParseError parseError;
  const QJsonDocument document = QJsonDocument::fromJson(responseBytes, &parseError);
  if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
    const QString message =
        QStringLiteral("Synchronization response is not valid JSON: %1").arg(parseError.errorString());
    setStatus(QStringLiteral("error"), message);
    log(QStringLiteral("error"), message);
    finishRequest();
    return;
  }

  QString storeError;
  if (!applySyncResponse(*m_taskStore, document.object(), &storeError)) {
    setStatus(QStringLiteral("error"), storeError);
    log(QStringLiteral("error"), storeError);
    finishRequest();
    return;
  }

  m_lastSuccessfulSync = QDateTime::currentDateTimeUtc();
  setStatus(QStringLiteral("ready"));
  finishRequest();
}

void SyncEngine::scheduleSoon() {
  if (enabled() && !m_debounceTimer.isActive()) {
    m_debounceTimer.start();
  }
}
void SyncEngine::consumeEventStream() {
  if (m_eventStream == nullptr) {
    return;
  }
  m_eventBuffer.append(m_eventStream->readAll());
  while (true) {
    const qsizetype lfSeparator = m_eventBuffer.indexOf(QByteArrayLiteral("\n\n"));
    const qsizetype crlfSeparator = m_eventBuffer.indexOf(QByteArrayLiteral("\r\n\r\n"));
    qsizetype separator = lfSeparator;
    qsizetype separatorSize = 2;
    if (separator < 0 || (crlfSeparator >= 0 && crlfSeparator < separator)) {
      separator = crlfSeparator;
      separatorSize = 4;
    }
    if (separator < 0) {
      return;
    }

    QByteArray event = m_eventBuffer.left(separator);
    m_eventBuffer.remove(0, separator + separatorSize);
    event.replace(QByteArrayLiteral("\r\n"), QByteArrayLiteral("\n"));
    bool isSyncWakeup = false;
    for (const QByteArray &line : event.split('\n')) {
      if (line == QByteArrayLiteral("event: sync-needed")) {
        isSyncWakeup = true;
        break;
      }
    }
    if (isSyncWakeup) {
      m_eventReconnectSeconds = 1;
      syncNow();
    }
  }
}

void SyncEngine::finishEventStream() {
  auto *reply = qobject_cast<QNetworkReply *>(sender());
  if (reply == nullptr || reply != m_eventStream) {
    if (reply != nullptr) {
      reply->deleteLater();
    }
    return;
  }
  consumeEventStream();
  m_eventStream = nullptr;
  reply->deleteLater();
  scheduleEventReconnect();
}

void SyncEngine::openEventStream() {
  if (!enabled() || m_eventStream != nullptr) {
    return;
  }
  QNetworkRequest request(eventStreamUrl());
  request.setRawHeader("Accept", QByteArrayLiteral("text/event-stream"));
  request.setRawHeader("Authorization", QByteArrayLiteral("Bearer ") + m_token);
  request.setRawHeader("Cache-Control", QByteArrayLiteral("no-cache"));
  m_eventBuffer.clear();
  m_eventStream = m_network.get(request);
  m_eventStream->setParent(this);
  connect(m_eventStream, &QNetworkReply::readyRead, this, &SyncEngine::consumeEventStream);
  connect(m_eventStream, &QNetworkReply::finished, this, &SyncEngine::finishEventStream);
}

QUrl SyncEngine::eventStreamUrl() const {
  QUrl url = m_endpoint;
  QString path = url.path();
  if (path.endsWith(QStringLiteral("/v1/sync"))) {
    path.chop(4);
    path.append(QStringLiteral("events"));
  } else {
    path = QStringLiteral("/v1/events");
  }
  url.setPath(path);
  return url;
}

void SyncEngine::closeEventStream() {
  m_eventReconnectTimer.stop();
  m_eventReconnectSeconds = 1;
  m_eventBuffer.clear();
  if (m_eventStream == nullptr) {
    return;
  }
  QNetworkReply *reply = m_eventStream;
  m_eventStream = nullptr;
  disconnect(reply, nullptr, this, nullptr);
  reply->abort();
  reply->deleteLater();
}

void SyncEngine::continuePendingSync() {
  if (!m_syncRequested) {
    return;
  }
  m_syncRequested = false;
  QTimer::singleShot(0, this, &SyncEngine::syncNow);
}

void SyncEngine::scheduleEventReconnect() {
  if (!enabled() || m_eventReconnectTimer.isActive()) {
    return;
  }
  m_eventReconnectTimer.start(m_eventReconnectSeconds * 1000);
  m_eventReconnectSeconds = std::min(m_eventReconnectSeconds * 2, 60);
}

QUrl SyncEngine::normalizeEndpoint(const QString &endpointInput, QString *errorMessage) const {
  QUrl endpoint = QUrl::fromUserInput(endpointInput);
  const QString scheme = endpoint.scheme().toLower();
  if (!endpoint.isValid() || endpoint.host().isEmpty() ||
      (scheme != QStringLiteral("http") && scheme != QStringLiteral("https"))) {
    assignError(errorMessage, QStringLiteral("Synchronization server must be a valid HTTP or HTTPS URL"));
    return {};
  }
  if (!endpoint.userInfo().isEmpty() || endpoint.hasQuery() || endpoint.hasFragment()) {
    assignError(errorMessage,
                QStringLiteral("Synchronization server URL cannot contain credentials, query, or fragment"));
    return {};
  }
  if (endpoint.path().isEmpty() || endpoint.path() == QStringLiteral("/")) {
    endpoint.setPath(QStringLiteral("/v1/sync"));
  } else if (endpoint.path().endsWith(QLatin1Char('/'))) {
    endpoint.setPath(endpoint.path() + QStringLiteral("v1/sync"));
  }
  return endpoint;
}

void SyncEngine::setStatus(const QString &state, const QString &errorMessage) {
  if (m_state == state && m_lastError == errorMessage) {
    return;
  }
  m_state = state;
  m_lastError = errorMessage;
  emit statusChanged();
}

void SyncEngine::log(const QString &level, const QString &message) const {
  const QJsonObject entry{{QStringLiteral("level"), level},
                          {QStringLiteral("component"), QStringLiteral("waypoint-sync")},
                          {QStringLiteral("message"), message}};
  const QByteArray line = QJsonDocument(entry).toJson(QJsonDocument::Compact);
  fprintf(level == QStringLiteral("error") ? stderr : stdout, "%s\n", line.constData());
  fflush(level == QStringLiteral("error") ? stderr : stdout);
}

} // namespace waypoint

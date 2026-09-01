#include "sync/SyncEngine.hpp"

#include "core/TaskStore.hpp"

#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSysInfo>

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
  connect(&m_periodicTimer, &QTimer::timeout, this, &SyncEngine::syncNow);
  connect(&m_debounceTimer, &QTimer::timeout, this, &SyncEngine::syncNow);
  connect(m_taskStore, &TaskStore::tasksChanged, this, &SyncEngine::scheduleSoon);
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
  if (!enabled()) {
    m_periodicTimer.stop();
    setStatus(QStringLiteral("local-only"));
    return true;
  }

  if (!m_periodicTimer.isActive()) {
    m_periodicTimer.start();
  }
  setStatus(QStringLiteral("ready"));
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
  QTimer::singleShot(0, this, &SyncEngine::syncNow);
}

void SyncEngine::syncNow() {
  if (!enabled() || m_inFlight) {
    return;
  }

  QString error;
  const QJsonArray mutations = m_taskStore->pendingMutations(&error);
  const QString cursor = m_taskStore->syncCursor(&error);
  if (!error.isEmpty()) {
    setStatus(QStringLiteral("error"), error);
    log(QStringLiteral("error"), error);
    return;
  }

  const QJsonObject payload{
      {QStringLiteral("deviceId"), deviceId()},
      {QStringLiteral("cursor"), cursor.toLongLong()},
      {QStringLiteral("mutations"), mutations},
  };
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
    return;
  }
  const QByteArray responseBytes = reply->readAll();
  if (reply->error() != QNetworkReply::NoError) {
    const QString message = QStringLiteral("HTTP %1: %2")
                                .arg(reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt())
                                .arg(reply->errorString());
    setStatus(QStringLiteral("error"), message);
    log(QStringLiteral("warn"), QStringLiteral("Synchronization request failed: %1").arg(message));
    reply->deleteLater();
    return;
  }

  QJsonParseError parseError;
  const QJsonDocument document = QJsonDocument::fromJson(responseBytes, &parseError);
  if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
    const QString message =
        QStringLiteral("Synchronization response is not valid JSON: %1").arg(parseError.errorString());
    setStatus(QStringLiteral("error"), message);
    log(QStringLiteral("error"), message);
    reply->deleteLater();
    return;
  }

  const QJsonObject response = document.object();
  QStringList acceptedMutationIds;
  for (const QJsonValue &value : response.value(QStringLiteral("acceptedMutationIds")).toArray()) {
    acceptedMutationIds.append(value.toString());
  }

  QString storeError;
  if (!m_taskStore->applyRemoteChanges(
          response.value(QStringLiteral("changes")).toArray(),
          QString::number(response.value(QStringLiteral("nextCursor")).toInteger()), acceptedMutationIds,
          &storeError)) {
    setStatus(QStringLiteral("error"), storeError);
    log(QStringLiteral("error"), storeError);
    reply->deleteLater();
    return;
  }

  m_lastSuccessfulSync = QDateTime::currentDateTimeUtc();
  setStatus(QStringLiteral("ready"));
  reply->deleteLater();
}

void SyncEngine::scheduleSoon() {
  if (enabled() && !m_debounceTimer.isActive()) {
    m_debounceTimer.start();
  }
}

QString SyncEngine::deviceId() const {
  const QString overrideId = qEnvironmentVariable("WAYPOINT_DEVICE_ID");
  if (!overrideId.isEmpty()) {
    return overrideId;
  }
  QByteArray identity = QSysInfo::machineUniqueId();
  if (identity.isEmpty()) {
    identity = QSysInfo::machineHostName().toUtf8();
  }
  return QString::fromLatin1(QCryptographicHash::hash(identity, QCryptographicHash::Sha256).toHex().left(24));
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

#include "sync/HolidaySyncEngine.hpp"

#include "core/SyncConfiguration.hpp"
#include "core/TaskStore.hpp"

#include <QDate>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrlQuery>

namespace waypoint {
namespace {

constexpr int holidayRefreshIntervalMilliseconds = 6 * 60 * 60 * 1000;

QString networkError(QNetworkReply *reply, const QString &context) {
  const QByteArray body = reply->readAll();
  const QJsonObject payload = QJsonDocument::fromJson(body).object();
  const QString serverMessage = payload.value(QStringLiteral("error")).toString();
  return serverMessage.isEmpty() ? QStringLiteral("%1: %2").arg(context, reply->errorString())
                                 : QStringLiteral("%1: %2").arg(context, serverMessage);
}

} // namespace

HolidaySyncEngine::HolidaySyncEngine(TaskStore *taskStore, QObject *parent)
    : QObject(parent), m_taskStore(taskStore) {
  m_periodicTimer.setInterval(holidayRefreshIntervalMilliseconds);
  connect(&m_periodicTimer, &QTimer::timeout, this, &HolidaySyncEngine::syncNow);
}

QJsonObject HolidaySyncEngine::status() const {
  return {
      {QStringLiteral("state"), m_state},
      {QStringLiteral("lastSuccessfulSync"), m_lastSuccessfulSync.toString(Qt::ISODateWithMs)},
      {QStringLiteral("lastError"), m_lastError},
      {QStringLiteral("inFlight"), m_inFlight},
  };
}

bool HolidaySyncEngine::updatePreferences(const QJsonObject &preferences, QString *errorMessage) {
  if (!m_taskStore->saveHolidayPreferences(preferences, errorMessage)) {
    return false;
  }
  syncNow();
  return true;
}

void HolidaySyncEngine::start() {
  m_periodicTimer.start();
  QTimer::singleShot(0, this, &HolidaySyncEngine::syncNow);
}

void HolidaySyncEngine::syncNow() {
  if (m_inFlight) {
    return;
  }
  QString error;
  const SyncConfiguration configuration = m_taskStore->syncConfiguration(&error);
  if (!error.isEmpty()) {
    setStatus(QStringLiteral("error"), error);
    return;
  }
  if (!configuration.enabled()) {
    setStatus(QStringLiteral("local-only"));
    return;
  }

  const int currentYear = QDate::currentDate().year();
  m_pendingYears = {currentYear - 1, currentYear, currentYear + 1};
  m_inFlight = true;
  setStatus(QStringLiteral("syncing"));
  uploadPreferences();
}

void HolidaySyncEngine::uploadPreferences() {
  QString error;
  const QJsonObject preferences = m_taskStore->holidayPreferences(&error);
  if (!error.isEmpty()) {
    m_inFlight = false;
    setStatus(QStringLiteral("error"), error);
    return;
  }
  QNetworkRequest request = authorizedRequest(apiUrl(QStringLiteral("holiday-preferences")));
  request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
  QNetworkReply *reply = m_network.put(request, QJsonDocument(preferences).toJson(QJsonDocument::Compact));
  connect(reply, &QNetworkReply::finished, this, [this, reply] { finishPreferencesUpload(reply); });
}

void HolidaySyncEngine::finishPreferencesUpload(QNetworkReply *reply) {
  reply->deleteLater();
  if (reply->error() != QNetworkReply::NoError) {
    m_inFlight = false;
    setStatus(QStringLiteral("offline"),
              networkError(reply, QStringLiteral("Cannot synchronize holiday preferences")));
    return;
  }
  fetchNextYear();
}

void HolidaySyncEngine::fetchNextYear() {
  if (m_pendingYears.isEmpty()) {
    m_inFlight = false;
    m_lastSuccessfulSync = QDateTime::currentDateTimeUtc();
    setStatus(QStringLiteral("ready"));
    return;
  }

  const int year = m_pendingYears.takeFirst();
  QUrl url = apiUrl(QStringLiteral("holidays"));
  QUrlQuery query;
  query.addQueryItem(QStringLiteral("from"), QDate(year, 1, 1).toString(Qt::ISODate));
  query.addQueryItem(QStringLiteral("to"), QDate(year, 12, 31).toString(Qt::ISODate));
  url.setQuery(query);
  QNetworkReply *reply = m_network.get(authorizedRequest(url));
  connect(reply, &QNetworkReply::finished, this, [this, reply, year] { finishYearFetch(reply, year); });
}

void HolidaySyncEngine::finishYearFetch(QNetworkReply *reply, int year) {
  reply->deleteLater();
  if (reply->error() != QNetworkReply::NoError) {
    m_inFlight = false;
    setStatus(QStringLiteral("offline"),
              networkError(reply, QStringLiteral("Cannot refresh holidays for %1").arg(year)));
    return;
  }
  const QByteArray body = reply->readAll();

  QJsonParseError parseError;
  const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
  const QJsonObject response = document.object();
  if (parseError.error != QJsonParseError::NoError || response.isEmpty()) {
    m_inFlight = false;
    setStatus(
        QStringLiteral("error"),
        QStringLiteral("Holiday response for %1 is invalid: %2").arg(year).arg(parseError.errorString()));
    return;
  }

  QString error;
  if (!m_taskStore->replaceHolidaySnapshot(QDate(year, 1, 1), QDate(year, 12, 31),
                                           response.value(QStringLiteral("holidays")).toArray(),
                                           response.value(QStringLiteral("coverage")).toArray(), &error)) {
    m_inFlight = false;
    setStatus(QStringLiteral("error"), error);
    return;
  }
  fetchNextYear();
}

void HolidaySyncEngine::refreshMunicipalities(const QString &stateCode) {
  const QString normalizedState = stateCode.trimmed().toUpper();
  if (normalizedState.size() != 2) {
    return;
  }
  if (m_municipalityRequests.contains(normalizedState)) {
    return;
  }
  QString error;
  const SyncConfiguration configuration = m_taskStore->syncConfiguration(&error);
  if (!error.isEmpty() || !configuration.enabled()) {
    return;
  }

  QUrl url = apiUrl(QStringLiteral("locations/municipalities"));
  QUrlQuery query;
  query.addQueryItem(QStringLiteral("state"), normalizedState);
  url.setQuery(query);
  m_municipalityRequests.insert(normalizedState);
  QNetworkReply *reply = m_network.get(authorizedRequest(url));
  connect(reply, &QNetworkReply::finished, this, [this, reply, normalizedState] {
    m_municipalityRequests.remove(normalizedState);
    const QByteArray body = reply->readAll();
    reply->deleteLater();
    if (reply->error() != QNetworkReply::NoError) {
      return;
    }
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
      return;
    }
    QString saveError;
    if (m_taskStore->replaceMunicipalities(normalizedState, document.array(), &saveError)) {
      emit municipalitiesChanged(normalizedState);
    }
  });
}

QUrl HolidaySyncEngine::apiUrl(const QString &path) const {
  QString error;
  const SyncConfiguration configuration = m_taskStore->syncConfiguration(&error);
  QUrl url = configuration.endpoint;
  QString basePath = url.path();
  if (basePath.endsWith(QStringLiteral("/sync"))) {
    basePath.chop(4);
  } else if (!basePath.endsWith(QLatin1Char('/'))) {
    basePath.append(QLatin1Char('/'));
  }
  url.setPath(basePath + path);
  url.setQuery(QString{});
  return url;
}

QNetworkRequest HolidaySyncEngine::authorizedRequest(const QUrl &url) const {
  QString error;
  const SyncConfiguration configuration = m_taskStore->syncConfiguration(&error);
  QNetworkRequest request(url);
  request.setRawHeader("Authorization", QByteArrayLiteral("Bearer ") + configuration.token);
  request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Waypoint/0.1"));
  return request;
}

void HolidaySyncEngine::setStatus(const QString &state, const QString &errorMessage) {
  if (m_state == state && m_lastError == errorMessage) {
    return;
  }
  m_state = state;
  m_lastError = errorMessage;
  emit statusChanged();
}

} // namespace waypoint

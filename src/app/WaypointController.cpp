#include "app/WaypointController.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>

namespace waypoint {

WaypointController::WaypointController(QObject *parent)
    : QObject(parent), m_client(this), m_todayTasks(this), m_selectedDateTasks(this), m_calendar(this),
      m_selectedDate(QDate::currentDate()) {
  m_todayTasks.setFocusDate(QDate::currentDate());
  m_selectedDateTasks.setFocusDate(m_selectedDate);
  m_refreshTimer.setInterval(1000);
  connect(&m_refreshTimer, &QTimer::timeout, this, &WaypointController::refresh);
}

TaskListModel *WaypointController::todayTasks() { return &m_todayTasks; }

TaskListModel *WaypointController::selectedDateTasks() { return &m_selectedDateTasks; }

CalendarModel *WaypointController::calendar() { return &m_calendar; }

QString WaypointController::selectedDateKey() const { return m_selectedDate.toString(Qt::ISODate); }

void WaypointController::setSelectedDateKey(const QString &dateKey) {
  const QDate date = QDate::fromString(dateKey, Qt::ISODate);
  if (!date.isValid() || m_selectedDate == date) {
    return;
  }
  m_selectedDate = date;
  m_selectedDateTasks.setFocusDate(date);
  updateSelectedDateHolidays();
  emit selectedDateKeyChanged();
}

bool WaypointController::online() const { return m_online; }

QString WaypointController::errorMessage() const { return m_errorMessage; }

QString WaypointController::syncEndpoint() const { return m_syncEndpoint; }

bool WaypointController::syncConfigured() const { return m_syncConfigured; }

QString WaypointController::syncState() const { return m_syncState; }

QString WaypointController::syncLastError() const { return m_syncLastError; }

QString WaypointController::lastSuccessfulSync() const { return m_lastSuccessfulSync; }
QString WaypointController::holidayStateCode() const { return m_holidayStateCode; }

QString WaypointController::holidayCityCode() const { return m_holidayCityCode; }

bool WaypointController::includeNationalHolidays() const { return m_includeNationalHolidays; }

bool WaypointController::includeStateHolidays() const { return m_includeStateHolidays; }

bool WaypointController::includeMunicipalHolidays() const { return m_includeMunicipalHolidays; }

bool WaypointController::includeCommemorativeDates() const { return m_includeCommemorativeDates; }
bool WaypointController::includeOptionalDates() const { return m_includeOptionalDates; }


QVariantList WaypointController::municipalities() const { return m_municipalities; }

QVariantList WaypointController::selectedDateHolidays() const {
  QVariantList selected;
  const QString dateKey = selectedDateKey();
  for (const QJsonValue &value : m_holidays) {
    const QJsonObject holiday = value.toObject();
    if (holiday.value(QStringLiteral("date")).toString() == dateKey) {
      selected.append(holiday.toVariantMap());
    }
  }
  return selected;
}

QString WaypointController::holidaySyncState() const { return m_holidaySyncState; }

QString WaypointController::holidaySyncLastError() const { return m_holidaySyncLastError; }

void WaypointController::start() {
  refresh();
  m_refreshTimer.start();
}

void WaypointController::refresh() {
  QString error;
  const QList<TaskRecord> tasks = m_client.listTasks(&error);
  if (!error.isEmpty()) {
    updateConnection(false, error);
    startDaemonOnce();
    return;
  }

  QJsonArray taskValues;
  for (const TaskRecord &task : tasks) {
    taskValues.append(task.toJson());
  }
  const QByteArray signature = QJsonDocument(taskValues).toJson(QJsonDocument::Compact);
  if (signature != m_snapshotSignature) {
    m_snapshotSignature = signature;
    publishTasks(tasks);
  }
  if (!refreshSyncDetails(&error)) {
    updateConnection(false, error);
    return;
  }
  if (!refreshHolidayDetails(&error)) {
    updateConnection(false, error);
    return;
  }
  updateConnection(true);
}

bool WaypointController::addTask(const QString &title, const QString &scheduledDateKey) {
  const QDate scheduledDate = QDate::fromString(scheduledDateKey, Qt::ISODate);
  if (!scheduledDate.isValid()) {
    updateConnection(m_online, QStringLiteral("Invalid scheduled date: %1").arg(scheduledDateKey));
    return false;
  }
  QString error;
  if (!m_client.addTask(title, scheduledDate, &error)) {
    updateConnection(false, error);
    return false;
  }
  refresh();
  return true;
}

bool WaypointController::setTaskCompleted(const QString &taskId, bool completed) {
  QString error;
  if (!m_client.setTaskCompleted(taskId, completed, &error)) {
    updateConnection(false, error);
    return false;
  }
  refresh();
  return true;
}

bool WaypointController::rescheduleTask(const QString &taskId, const QString &scheduledDateKey) {
  const QDate scheduledDate = QDate::fromString(scheduledDateKey, Qt::ISODate);
  if (!scheduledDate.isValid()) {
    updateConnection(m_online, QStringLiteral("Invalid scheduled date: %1").arg(scheduledDateKey));
    return false;
  }
  QString error;
  if (!m_client.rescheduleTask(taskId, scheduledDate, &error)) {
    updateConnection(false, error);
    return false;
  }
  refresh();
  return true;
}

bool WaypointController::deleteTask(const QString &taskId) {
  QString error;
  if (!m_client.deleteTask(taskId, &error)) {
    updateConnection(false, error);
    return false;
  }
  refresh();
  return true;
}

bool WaypointController::saveSyncConfiguration(const QString &endpoint, const QString &token) {
  QString error;
  const bool replaceToken = endpoint.trimmed().isEmpty() || !token.trimmed().isEmpty();
  if (!m_client.saveSyncConfiguration(endpoint, token, replaceToken, &error)) {
    updateConnection(false, error);
    return false;
  }
  if (!refreshSyncDetails(&error)) {
    updateConnection(false, error);
    return false;
  }
  updateConnection(true);
  return true;
}

bool WaypointController::disableRemoteSync() { return saveSyncConfiguration({}, {}); }

bool WaypointController::syncNow() {
  QString error;
  if (!m_client.syncNow(&error)) {
    updateConnection(false, error);
    return false;
  }
  if (!refreshSyncDetails(&error)) {
    updateConnection(false, error);
    return false;
  }
  updateConnection(true);
  return true;
}
bool WaypointController::saveHolidayPreferences(const QString &stateCode, const QString &cityCode,
                                                bool includeNational, bool includeState,
                                                bool includeMunicipal, bool includeCommemorative,
                                                bool includeOptional) {
  const QJsonObject preferences{
      {QStringLiteral("stateCode"), stateCode},
      {QStringLiteral("cityCode"), cityCode},
      {QStringLiteral("includeNational"), includeNational},
      {QStringLiteral("includeState"), includeState},
      {QStringLiteral("includeMunicipal"), includeMunicipal},
      {QStringLiteral("includeCommemorative"), includeCommemorative},
      {QStringLiteral("includeOptional"), includeOptional},
  };
  QString error;
  if (!m_client.saveHolidayPreferences(preferences, &error)) {
    updateConnection(false, error);
    return false;
  }
  if (!refreshHolidayDetails(&error)) {
    updateConnection(false, error);
    return false;
  }
  updateConnection(true);
  return true;
}

void WaypointController::loadMunicipalities(const QString &stateCode) {
  QString error;
  const QJsonArray values = m_client.municipalities(stateCode, &error);
  if (!error.isEmpty()) {
    updateConnection(false, error);
    return;
  }
  const QByteArray signature = QJsonDocument(values).toJson(QJsonDocument::Compact);
  if (signature == m_municipalitySignature) {
    return;
  }
  m_municipalitySignature = signature;
  m_municipalities = values.toVariantList();
  emit municipalitiesChanged();
}

bool WaypointController::refreshHolidays() {
  QString error;
  if (!m_client.refreshHolidays(&error)) {
    updateConnection(false, error);
    return false;
  }
  updateConnection(true);
  return true;
}

void WaypointController::updateConnection(bool online, const QString &errorMessage) {
  if (m_online != online) {
    m_online = online;
    emit connectionChanged();
  }
  if (m_errorMessage != errorMessage) {
    m_errorMessage = errorMessage;
    emit errorMessageChanged();
  }
}

void WaypointController::publishTasks(const QList<TaskRecord> &tasks) {
  m_todayTasks.setFocusDate(QDate::currentDate());
  m_todayTasks.setSourceTasks(tasks);
  m_selectedDateTasks.setSourceTasks(tasks);
  m_calendar.setSourceTasks(tasks);
}

bool WaypointController::refreshSyncDetails(QString *errorMessage) {
  const QJsonObject configuration = m_client.syncConfiguration(errorMessage);
  if (configuration.isEmpty()) {
    return false;
  }
  const QJsonObject status = m_client.syncStatus(errorMessage);
  if (status.isEmpty()) {
    return false;
  }

  const QString endpoint = configuration.value(QStringLiteral("endpoint")).toString();
  const bool configured = configuration.value(QStringLiteral("configured")).toBool();
  if (m_syncEndpoint != endpoint || m_syncConfigured != configured) {
    m_syncEndpoint = endpoint;
    m_syncConfigured = configured;
    emit syncConfigurationChanged();
  }

  const QString state = status.value(QStringLiteral("state")).toString();
  const QString lastError = status.value(QStringLiteral("lastError")).toString();
  const QString lastSuccessfulSync = status.value(QStringLiteral("lastSuccessfulSync")).toString();
  if (m_syncState != state || m_syncLastError != lastError || m_lastSuccessfulSync != lastSuccessfulSync) {
    m_syncState = state;
    m_syncLastError = lastError;
    m_lastSuccessfulSync = lastSuccessfulSync;
    emit syncStatusChanged();
  }
  return true;
}
bool WaypointController::refreshHolidayDetails(QString *errorMessage) {
  const QDate today = QDate::currentDate();
  const QJsonObject holidayData =
      m_client.holidays(QDate(today.year() - 1, 1, 1), QDate(today.year() + 1, 12, 31), errorMessage);
  if (holidayData.isEmpty()) {
    return false;
  }
  const QJsonArray holidays = holidayData.value(QStringLiteral("holidays")).toArray();
  const QByteArray signature = QJsonDocument(holidays).toJson(QJsonDocument::Compact);
  if (signature != m_holidaySignature) {
    m_holidaySignature = signature;
    m_holidays = holidays;
    m_calendar.setSourceHolidays(holidays);
    updateSelectedDateHolidays();
  }

  const QJsonObject preferences = m_client.holidayPreferences(errorMessage);
  if (preferences.isEmpty()) {
    return false;
  }
  const QString stateCode = preferences.value(QStringLiteral("stateCode")).toString();
  const QString cityCode = preferences.value(QStringLiteral("cityCode")).toString();
  const bool includeNational = preferences.value(QStringLiteral("includeNational")).toBool(true);
  const bool includeState = preferences.value(QStringLiteral("includeState")).toBool(true);
  const bool includeMunicipal = preferences.value(QStringLiteral("includeMunicipal")).toBool(true);
  const bool includeCommemorative = preferences.value(QStringLiteral("includeCommemorative")).toBool(false);
  const bool includeOptional = preferences.value(QStringLiteral("includeOptional")).toBool(true);
  if (stateCode != m_holidayStateCode || cityCode != m_holidayCityCode ||
      includeNational != m_includeNationalHolidays || includeState != m_includeStateHolidays ||
      includeMunicipal != m_includeMunicipalHolidays || includeCommemorative != m_includeCommemorativeDates ||
      includeOptional != m_includeOptionalDates) {
    m_holidayStateCode = stateCode;
    m_holidayCityCode = cityCode;
    m_includeNationalHolidays = includeNational;
    m_includeStateHolidays = includeState;
    m_includeMunicipalHolidays = includeMunicipal;
    m_includeCommemorativeDates = includeCommemorative;
    m_includeOptionalDates = includeOptional;
    emit holidayConfigurationChanged();
  }
  if (!stateCode.isEmpty()) {
    loadMunicipalities(stateCode);
  }

  const QJsonObject status = m_client.holidayStatus(errorMessage);
  if (status.isEmpty()) {
    return false;
  }
  const QString syncState = status.value(QStringLiteral("state")).toString();
  const QString syncError = status.value(QStringLiteral("lastError")).toString();
  if (syncState != m_holidaySyncState || syncError != m_holidaySyncLastError) {
    m_holidaySyncState = syncState;
    m_holidaySyncLastError = syncError;
    emit holidayStatusChanged();
  }
  return true;
}

void WaypointController::updateSelectedDateHolidays() { emit selectedDateHolidaysChanged(); }

void WaypointController::startDaemonOnce() {
  if (m_daemonStartAttempted) {
    return;
  }
  m_daemonStartAttempted = true;
  const QString daemonPath =
      QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("waypointd"));
  if (!QProcess::startDetached(daemonPath, {})) {
    updateConnection(false, QStringLiteral("Cannot start Waypoint daemon at %1").arg(daemonPath));
  }
}

} // namespace waypoint

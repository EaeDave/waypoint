#include "app/WaypointController.hpp"

#include <QCoreApplication>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>

namespace waypoint {
namespace {

RecurrenceFrequency recurrenceFrequency(const QString &name) {
  if (name == QStringLiteral("daily")) {
    return RecurrenceFrequency::Daily;
  }
  if (name == QStringLiteral("weekly")) {
    return RecurrenceFrequency::Weekly;
  }
  if (name == QStringLiteral("monthly")) {
    return RecurrenceFrequency::Monthly;
  }
  if (name == QStringLiteral("yearly")) {
    return RecurrenceFrequency::Yearly;
  }
  return RecurrenceFrequency::None;
}

RecurrenceEndMode recurrenceEndMode(const QString &name) {
  if (name == QStringLiteral("onDate")) {
    return RecurrenceEndMode::OnDate;
  }
  if (name == QStringLiteral("afterCount")) {
    return RecurrenceEndMode::AfterCount;
  }
  return RecurrenceEndMode::Never;
}

} // namespace

WaypointController::WaypointController(QObject *parent)
    : QObject(parent), m_client(this), m_todayTasks(this), m_selectedDateTasks(this), m_calendar(this),
      m_selectedDate(QDate::currentDate()) {
  m_todayTasks.setFocusDate(QDate::currentDate());
  m_selectedDateTasks.setFocusDate(m_selectedDate);
  m_refreshTimer.setInterval(1000);
  connect(&m_refreshTimer, &QTimer::timeout, this, &WaypointController::refresh);
  connect(&m_calendar, &CalendarModel::visibleMonthChanged, this, &WaypointController::refresh);
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
  const QDate today = QDate::currentDate();
  const QList<TaskOccurrence> todayOccurrences = m_client.listActionableOccurrences(today, &error);
  if (!error.isEmpty()) {
    updateConnection(false, error);
    startDaemonOnce();
    return;
  }

  const QDate visibleMonth(m_calendar.visibleYear(), m_calendar.visibleMonth(), 1);
  const QDate rangeStart = visibleMonth.addDays(-14);
  const QDate rangeEnd = visibleMonth.addMonths(1).addDays(14);
  const QList<TaskOccurrence> rangeOccurrences = m_client.listOccurrences(rangeStart, rangeEnd, &error);
  if (!error.isEmpty()) {
    updateConnection(false, error);
    return;
  }

  QJsonArray todayValues;
  for (const TaskOccurrence &occurrence : todayOccurrences) {
    todayValues.append(occurrence.toJson());
  }
  QJsonArray rangeValues;
  for (const TaskOccurrence &occurrence : rangeOccurrences) {
    rangeValues.append(occurrence.toJson());
  }
  const QByteArray signature = QJsonDocument(QJsonObject{{QStringLiteral("today"), todayValues},
                                                         {QStringLiteral("range"), rangeValues}})
                                   .toJson(QJsonDocument::Compact);
  if (signature != m_snapshotSignature) {
    m_snapshotSignature = signature;
    publishOccurrences(todayOccurrences, rangeOccurrences);
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

bool WaypointController::addTask(const QString &title, const QString &scheduledDateKey,
                                 const QString &scheduledTimeKey, const QString &frequency,
                                 const int interval, const QVariantList &weekdays, const QString &endMode,
                                 const QString &untilDateKey, const int occurrenceCount) {
  const QDate scheduledDate = QDate::fromString(scheduledDateKey, Qt::ISODate);
  const QTime scheduledTime = QTime::fromString(scheduledTimeKey, QStringLiteral("HH:mm"));
  if (!scheduledDate.isValid() || !scheduledTime.isValid()) {
    updateConnection(
        m_online,
        QStringLiteral("Invalid scheduled date or time: %1 %2").arg(scheduledDateKey, scheduledTimeKey));
    return false;
  }
  RecurrenceRule recurrence;
  recurrence.frequency = recurrenceFrequency(frequency);
  recurrence.interval = interval;
  for (const QVariant &weekday : weekdays) {
    recurrence.weekdays.append(weekday.toInt());
  }
  recurrence.endMode = recurrenceEndMode(endMode);
  recurrence.untilDate = QDate::fromString(untilDateKey, Qt::ISODate);
  recurrence.occurrenceCount = occurrenceCount;

  QString error;
  if (!m_client.addTask(title, scheduledDate, scheduledTime, recurrence, &error)) {
    updateConnection(false, error);
    return false;
  }
  refresh();
  return true;
}

bool WaypointController::setOccurrenceCompleted(const QString &taskId, const QString &occurrenceDateKey,
                                                const bool completed) {
  const QDate occurrenceDate = QDate::fromString(occurrenceDateKey, Qt::ISODate);
  QString error;
  if (!m_client.setOccurrenceCompleted(taskId, occurrenceDate, completed, &error)) {
    updateConnection(false, error);
    return false;
  }
  refresh();
  return true;
}

bool WaypointController::deleteOccurrence(const QString &taskId, const QString &occurrenceDateKey,
                                          const QString &scope) {
  const QDate occurrenceDate = QDate::fromString(occurrenceDateKey, Qt::ISODate);
  QString error;
  if (!m_client.deleteOccurrence(taskId, occurrenceDate, scope, &error)) {
    updateConnection(false, error);
    return false;
  }
  refresh();
  return true;
}

bool WaypointController::rescheduleTask(const QString &taskId, const QString &scheduledDateKey,
                                        const QString &scheduledTimeKey) {
  const QDate scheduledDate = QDate::fromString(scheduledDateKey, Qt::ISODate);
  const QTime scheduledTime = QTime::fromString(scheduledTimeKey, QStringLiteral("HH:mm"));
  if (!scheduledDate.isValid() || !scheduledTime.isValid()) {
    updateConnection(
        m_online,
        QStringLiteral("Invalid scheduled date or time: %1 %2").arg(scheduledDateKey, scheduledTimeKey));
    return false;
  }
  QString error;
  if (!m_client.rescheduleTask(taskId, scheduledDate, scheduledTime, &error)) {
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

void WaypointController::publishOccurrences(const QList<TaskOccurrence> &todayOccurrences,
                                            const QList<TaskOccurrence> &rangeOccurrences) {
  m_todayTasks.setFocusDate(QDate::currentDate());
  m_todayTasks.setSourceOccurrences(todayOccurrences);
  m_selectedDateTasks.setSourceOccurrences(rangeOccurrences);
  m_calendar.setSourceOccurrences(rangeOccurrences);
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

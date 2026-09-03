#include "mobile/MobileController.hpp"

#include "mobile/AndroidNotificationBridge.hpp"
#include "mobile/AndroidWidgetBridge.hpp"
#include "mobile/WidgetSnapshot.hpp"
#include <QCoreApplication>
#include <QDate>
#include <QDebug>
#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QTime>
#include <utility>

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

QList<int> integerValues(const QVariantList &values) {
  QList<int> result;
  result.reserve(values.size());
  for (const QVariant &value : values) {
    result.append(value.toInt());
  }
  return result;
}

QList<QTime> timeValues(const QVariantList &values) {
  QList<QTime> result;
  result.reserve(values.size());
  for (const QVariant &value : values) {
    result.append(QTime::fromString(value.toString(), QStringLiteral("HH:mm")));
  }
  return result;
}

QVariantList occurrenceValues(const QList<TaskOccurrence> &occurrences,
                              const QHash<QString, QString> &scheduledDates) {
  QVariantList result;
  result.reserve(occurrences.size());
  for (const TaskOccurrence &occurrence : occurrences) {
    QVariantMap value = occurrence.toJson().toVariantMap();
    value.insert(QStringLiteral("scheduledDate"), scheduledDates.value(occurrence.taskId));
    result.append(value);
  }
  return result;
}

QVariantList habitValues(const QList<HabitProgress> &progress) {
  QVariantList result;
  result.reserve(progress.size());
  for (const HabitProgress &item : progress) {
    result.append(item.toJson().toVariantMap());
  }
  return result;
}

QVariantList habitRecordValues(const QList<HabitRecord> &habits) {
  QVariantList result;
  result.reserve(habits.size());
  for (const HabitRecord &habit : habits) {
    result.append(habit.toJson().toVariantMap());
  }
  return result;
}

} // namespace

MobileController::MobileController(QObject *parent)
    : MobileController(defaultWaypointDatabasePath(), parent) {}

MobileController::MobileController(QString databasePath, QObject *parent)
    : QObject(parent), m_store(std::move(databasePath), this), m_syncEngine(&m_store, this),
      m_holidaySyncEngine(&m_store, this), m_updateChecker(UpdateAsset::AndroidArm64, this),
      m_updateInstaller(this), m_selectedDate(QDate::currentDate()), m_visibleYear(m_selectedDate.year()),
      m_visibleMonth(m_selectedDate.month()) {
  m_refreshTimer.setInterval(30000);
  connect(&m_refreshTimer, &QTimer::timeout, this, &MobileController::refresh);
  connect(&m_store, &TaskStore::tasksChanged, this, [this] {
    m_widgetSnapshotDirty = true;
    scheduleRefresh();
  });
  connect(&m_store, &TaskStore::habitsChanged, this, &MobileController::scheduleRefresh);
  connect(&m_store, &TaskStore::holidaysChanged, this, [this] {
    m_widgetSnapshotDirty = true;
    QTimer::singleShot(0, this, &MobileController::refresh);
  });
  connect(&m_syncEngine, &SyncEngine::statusChanged, this, &MobileController::refreshSyncProperties);
  connect(&m_holidaySyncEngine, &HolidaySyncEngine::statusChanged, this,
          [this] { QTimer::singleShot(0, this, &MobileController::refresh); });
  connect(&m_holidaySyncEngine, &HolidaySyncEngine::municipalitiesChanged, this,
          [this](const QString &stateCode) { loadMunicipalities(stateCode); });
  connect(&m_updateChecker, &UpdateChecker::statusChanged, this, &MobileController::refreshUpdateProperties);
  connect(&m_updateInstaller, &AndroidUpdateInstaller::statusChanged, this,
          &MobileController::refreshUpdateProperties);
}

bool MobileController::ready() const { return m_ready; }
QString MobileController::errorMessage() const { return m_errorMessage; }
QString MobileController::todayKey() const { return QDate::currentDate().toString(Qt::ISODate); }
QString MobileController::selectedDateKey() const { return m_selectedDate.toString(Qt::ISODate); }
int MobileController::visibleYear() const { return m_visibleYear; }
int MobileController::visibleMonth() const { return m_visibleMonth; }
QVariantList MobileController::todayTasks() const { return m_todayTasks; }
QVariantList MobileController::selectedTasks() const { return m_selectedTasks; }
QVariantList MobileController::todayHabits() const { return m_todayHabits; }
QVariantList MobileController::monthOccurrences() const { return m_monthOccurrences; }
QVariantList MobileController::monthHolidays() const { return m_monthHolidays; }
QVariantList MobileController::allHabits() const { return m_allHabits; }
QString MobileController::syncEndpoint() const { return m_syncEndpoint; }
bool MobileController::syncConfigured() const { return m_syncConfigured; }
QString MobileController::syncState() const { return m_syncState; }
QString MobileController::syncLastError() const { return m_syncLastError; }
QString MobileController::lastSuccessfulSync() const { return m_lastSuccessfulSync; }
QString MobileController::currentVersion() const { return QCoreApplication::applicationVersion(); }
QString MobileController::updateState() const { return m_updateState; }
QString MobileController::latestVersion() const { return m_latestVersion; }
QString MobileController::updateError() const { return m_updateError; }
bool MobileController::canInstallUpdate() const { return m_canInstallUpdate; }
qreal MobileController::updateProgress() const { return m_updateProgress; }

QVariantList MobileController::selectedDateHolidays() const {
  QVariantList result;
  for (const QVariant &value : m_monthHolidays) {
    const QVariantMap holiday = value.toMap();
    if (holiday.value(QStringLiteral("date")).toString() == selectedDateKey()) {
      result.append(holiday);
    }
  }
  return result;
}

QVariantMap MobileController::holidayPreferences() const { return m_holidayPreferences; }
QVariantList MobileController::municipalities() const { return m_municipalities; }

void MobileController::setSelectedDateKey(const QString &dateKey) {
  const QDate date = QDate::fromString(dateKey, Qt::ISODate);
  if (!date.isValid() || date == m_selectedDate) {
    return;
  }
  m_selectedDate = date;
  if (m_visibleYear != date.year() || m_visibleMonth != date.month()) {
    m_visibleYear = date.year();
    m_visibleMonth = date.month();
    emit visibleMonthChanged();
  }
  emit selectedDateChanged();
  refresh();
}

void MobileController::start() {
  if (m_ready) {
    refresh();
    return;
  }
  QString error;
  if (!m_store.open(&error)) {
    publishError(error);
    return;
  }
  m_ready = true;
  emit readyChanged();
  m_syncEngine.start();
  m_holidaySyncEngine.start();
  m_updateChecker.start();
  m_refreshTimer.start();
  refresh();
  refreshNotificationSchedule();
}

void MobileController::refresh() {
  if (!m_ready) {
    return;
  }
  const QDate today = QDate::currentDate();
  const QDate monthStart(m_visibleYear, m_visibleMonth, 1);
  const QDate monthEnd = monthStart.addMonths(1).addDays(-1);
  QString error;

  const QList<TaskOccurrence> todayOccurrences = m_store.listActionableOccurrences(today, &error);
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }
  const QList<TaskRecord> activeTasks = m_store.listActiveTasks(&error);
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }
  const QList<TaskOccurrence> month = m_store.listOccurrences(monthStart, monthEnd, &error);
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }
  const QList<HabitProgress> habits = m_store.listHabitProgress(today, &error);
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }
  const QList<HabitRecord> activeHabits = m_store.listActiveHabits(&error);
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }
  const QJsonArray holidays = m_store.listHolidays(monthStart, monthEnd, &error);
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }
  const QJsonObject holidayPreferences = m_store.holidayPreferences(&error);
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }

  QList<TaskOccurrence> selected;
  if (m_selectedDate == today) {
    selected = todayOccurrences;
  } else {
    for (const TaskOccurrence &occurrence : month) {
      const bool calendarVisible = !occurrence.recurring || occurrence.calendarMarker;
      if (occurrence.occurrenceDate == m_selectedDate && calendarVisible) {
        selected.append(occurrence);
      }
    }
  }
  QHash<QString, QString> scheduledDates;
  scheduledDates.reserve(activeTasks.size());
  for (const TaskRecord &task : activeTasks) {
    scheduledDates.insert(task.id, task.scheduledDate.toString(Qt::ISODate));
  }

  m_todayTasks = occurrenceValues(todayOccurrences, scheduledDates);
  m_selectedTasks = occurrenceValues(selected, scheduledDates);
  m_todayHabits = habitValues(habits);
  m_monthOccurrences = occurrenceValues(month, scheduledDates);
  m_allHabits = habitRecordValues(activeHabits);
  m_monthHolidays = holidays.toVariantList();
  const QVariantMap preferenceValues = holidayPreferences.toVariantMap();
  if (preferenceValues != m_holidayPreferences) {
    m_holidayPreferences = preferenceValues;
    emit holidayPreferencesChanged();
  }
  refreshSyncProperties();
  refreshWidgetSnapshot(today);
  publishError({});
  emit dataChanged();
}

void MobileController::moveMonth(const int delta) {
  const QDate next(m_visibleYear, m_visibleMonth, 1);
  const QDate moved = next.addMonths(delta);
  m_visibleYear = moved.year();
  m_visibleMonth = moved.month();
  m_selectedDate = moved;
  emit visibleMonthChanged();
  emit selectedDateChanged();
  refresh();
}

void MobileController::selectToday() {
  const QDate today = QDate::currentDate();
  m_selectedDate = today;
  m_visibleYear = today.year();
  m_visibleMonth = today.month();
  emit visibleMonthChanged();
  emit selectedDateChanged();
  refresh();
}

bool MobileController::saveTask(const QString &taskId, const QString &title, const QString &scheduledDateKey,
                                const QString &scheduledTimeKey, const QString &frequency, const int interval,
                                const QVariantList &weekdays, const QString &endMode,
                                const QString &untilDateKey, const int occurrenceCount,
                                const QVariantList &reminderMinutesBefore, const QString &emoji) {
  const QDate date = QDate::fromString(scheduledDateKey, Qt::ISODate);
  const QTime time = QTime::fromString(scheduledTimeKey, QStringLiteral("HH:mm"));
  if (!date.isValid() || !time.isValid()) {
    publishError(QStringLiteral("Use uma data YYYY-MM-DD e um horário HH:mm válidos"));
    return false;
  }
  RecurrenceRule recurrence;
  recurrence.frequency = recurrenceFrequency(frequency);
  recurrence.interval = interval;
  recurrence.weekdays = integerValues(weekdays);
  recurrence.endMode = recurrenceEndMode(endMode);
  recurrence.untilDate = QDate::fromString(untilDateKey, Qt::ISODate);
  recurrence.occurrenceCount = occurrenceCount;

  QString error;
  bool succeeded = false;
  if (taskId.isEmpty()) {
    succeeded = m_store.createTask(title, date, time, recurrence, integerValues(reminderMinutesBefore), emoji,
                                   nullptr, &error);
  } else {
    succeeded = m_store.editTask(taskId, title, time, recurrence, integerValues(reminderMinutesBefore), emoji,
                                 &error);
    if (succeeded) {
      succeeded = m_store.rescheduleTask(taskId, date, time, &error);
    }
  }
  return finishMutation(succeeded, error);
}

bool MobileController::setTaskCompleted(const QString &taskId, const QString &occurrenceDateKey,
                                        const bool recurring, const bool completed) {
  const QDate date = QDate::fromString(occurrenceDateKey, Qt::ISODate);
  QString error;
  const bool succeeded = recurring ? m_store.setOccurrenceCompleted(taskId, date, completed, &error)
                                   : m_store.setTaskCompleted(taskId, completed, &error);
  if (succeeded && completed) {
    AndroidNotificationBridge::playCompletionSound();
  }
  return finishMutation(succeeded, error);
}

bool MobileController::deleteTask(const QString &taskId) {
  QString error;
  return finishMutation(m_store.deleteTask(taskId, &error), error);
}

bool MobileController::saveHabit(const QString &habitId, const QString &title, const qint64 targetAmount,
                                 const QString &unit, const QString &checkInMode,
                                 const qint64 incrementAmount, const QVariantList &weekdays,
                                 const QVariantList &reminderTimes, const QString &emoji) {
  const QList<int> scheduledWeekdays = integerValues(weekdays);
  const QList<QTime> reminders = timeValues(reminderTimes);
  const HabitCheckInMode mode = habitCheckInModeFromName(checkInMode);
  QString error;
  const bool succeeded = habitId.isEmpty()
                             ? m_store.createHabit(title, targetAmount, unit, mode, incrementAmount,
                                                   scheduledWeekdays, reminders, emoji, nullptr, &error)
                             : m_store.editHabit(habitId, title, targetAmount, unit, mode, incrementAmount,
                                                 scheduledWeekdays, reminders, emoji, &error);
  return finishMutation(succeeded, error);
}

bool MobileController::recordHabit(const QString &habitId, const qint64 amount) {
  const std::optional<qint64> recordedAmount = amount > 0 ? std::optional<qint64>(amount) : std::nullopt;
  QString error;
  const bool succeeded = m_store.recordHabit(habitId, QDate::currentDate(), recordedAmount, nullptr, &error);
  if (succeeded) {
    AndroidNotificationBridge::playCompletionSound();
  }
  return finishMutation(succeeded, error);
}

bool MobileController::undoHabit(const QString &habitId) {
  QString error;
  return finishMutation(m_store.undoLastHabitEntry(habitId, QDate::currentDate(), &error), error);
}

bool MobileController::deleteHabit(const QString &habitId) {
  QString error;
  return finishMutation(m_store.deleteHabit(habitId, &error), error);
}

bool MobileController::saveSyncConfiguration(const QString &endpoint, const QString &token) {
  QString error;
  const bool replaceToken = endpoint.trimmed().isEmpty() || !token.trimmed().isEmpty();
  if (!m_syncEngine.updateConfiguration(endpoint, token.toUtf8(), replaceToken, &error)) {
    publishError(error);
    return false;
  }
  refreshSyncProperties();
  emit syncConfigurationChanged();
  emit syncStatusChanged();
  m_holidaySyncEngine.syncNow();
  return true;
}

bool MobileController::syncNow() {
  if (!m_syncConfigured) {
    publishError(QStringLiteral("Configure o servidor e o Bearer token primeiro"));
    return false;
  }
  m_syncEngine.syncNow();
  m_holidaySyncEngine.syncNow();
  refreshSyncProperties();
  emit syncStatusChanged();
  return true;
}

bool MobileController::saveHolidayPreferences(const QString &stateCode, const QString &cityCode,
                                              const bool includeNational, const bool includeState,
                                              const bool includeMunicipal, const bool includeCommemorative,
                                              const bool includeOptional) {
  const QJsonObject preferences{
      {QStringLiteral("stateCode"), stateCode.trimmed().toUpper()},
      {QStringLiteral("cityCode"), cityCode.trimmed()},
      {QStringLiteral("includeNational"), includeNational},
      {QStringLiteral("includeState"), includeState},
      {QStringLiteral("includeMunicipal"), includeMunicipal},
      {QStringLiteral("includeCommemorative"), includeCommemorative},
      {QStringLiteral("includeOptional"), includeOptional},
  };
  QString error;
  return finishMutation(m_holidaySyncEngine.updatePreferences(preferences, &error), error);
}

void MobileController::refreshHolidays() { m_holidaySyncEngine.syncNow(); }

void MobileController::checkForUpdate() { m_updateChecker.checkNow(); }

bool MobileController::installUpdate() {
  QString error;
  if (!m_updateInstaller.install(m_updateChecker.release(), &error)) {
    publishError(error);
    return false;
  }
  publishError({});
  refreshUpdateProperties();
  return true;
}

void MobileController::loadMunicipalities(const QString &stateCode) {
  const QString normalizedState = stateCode.trimmed().toUpper();
  QString error;
  const QVariantList values = m_store.listMunicipalities(normalizedState, &error).toVariantList();
  if (!error.isEmpty()) {
    publishError(error);
    return;
  }
  if (values != m_municipalities) {
    m_municipalities = values;
    emit municipalitiesChanged();
  }
  if (!normalizedState.isEmpty() && values.isEmpty()) {
    m_holidaySyncEngine.refreshMunicipalities(normalizedState);
  }
}

void MobileController::scheduleRefresh() {
  QTimer::singleShot(0, this, [this] {
    refresh();
    refreshNotificationSchedule();
  });
}

void MobileController::publishError(const QString &message) {
  if (m_errorMessage == message) {
    return;
  }
  m_errorMessage = message;
  emit errorMessageChanged();
}

bool MobileController::finishMutation(const bool succeeded, const QString &errorMessage) {
  if (!succeeded) {
    publishError(errorMessage);
    return false;
  }
  publishError({});
  refresh();
  return true;
}

void MobileController::refreshUpdateProperties() {
  const QJsonObject status = m_updateChecker.status();
  QString state = status.value(QStringLiteral("state")).toString();
  QString error = status.value(QStringLiteral("error")).toString();
  qreal progress = 0.0;
  if (m_updateInstaller.state() != QStringLiteral("idle")) {
    state = m_updateInstaller.state();
    error = m_updateInstaller.errorMessage();
    progress = m_updateInstaller.progress();
  }
  const QString latestVersion = status.value(QStringLiteral("latestVersion")).toString();
  const bool canInstall = status.value(QStringLiteral("canInstall")).toBool();
  if (m_updateState == state && m_latestVersion == latestVersion && m_updateError == error &&
      m_canInstallUpdate == canInstall && qFuzzyCompare(m_updateProgress, progress)) {
    return;
  }
  m_updateState = state;
  m_latestVersion = latestVersion;
  m_updateError = error;
  m_canInstallUpdate = canInstall;
  m_updateProgress = progress;
  emit updateStatusChanged();
}

void MobileController::refreshSyncProperties() {
  const QJsonObject configuration = m_syncEngine.publicConfiguration();
  const QJsonObject status = m_syncEngine.status();
  const QString endpoint = configuration.value(QStringLiteral("endpoint")).toString();
  const bool configured = configuration.value(QStringLiteral("configured")).toBool();
  if (endpoint != m_syncEndpoint || configured != m_syncConfigured) {
    m_syncEndpoint = endpoint;
    m_syncConfigured = configured;
    emit syncConfigurationChanged();
  }
  const QString state = status.value(QStringLiteral("state")).toString();
  const QString lastError = status.value(QStringLiteral("lastError")).toString();
  const QString lastSuccessful = status.value(QStringLiteral("lastSuccessfulSync")).toString();
  if (state != m_syncState || lastError != m_syncLastError || lastSuccessful != m_lastSuccessfulSync) {
    m_syncState = state;
    m_syncLastError = lastError;
    m_lastSuccessfulSync = lastSuccessful;
    emit syncStatusChanged();
  }
}

void MobileController::refreshWidgetSnapshot(const QDate &today) {
  if (!m_widgetSnapshotDirty && m_widgetSnapshotDate == today) {
    return;
  }
  QString error;
  const QJsonObject snapshot = buildWidgetSnapshot(m_store, today, 6, 12, &error);
  if (!error.isEmpty()) {
    qWarning().noquote() << "Unable to refresh Android widget snapshot:" << error;
    return;
  }
  const QByteArray serialized = QJsonDocument(snapshot).toJson(QJsonDocument::Compact);
  if (serialized != m_widgetSnapshot) {
    AndroidWidgetBridge::publishSnapshot(snapshot);
    m_widgetSnapshot = serialized;
  }
  m_widgetSnapshotDate = today;
  m_widgetSnapshotDirty = false;
}

void MobileController::refreshNotificationSchedule() {
  QString error;
  if (!AndroidNotificationBridge::replaceSchedule(&m_store, &error)) {
    publishError(error);
  }
}

} // namespace waypoint

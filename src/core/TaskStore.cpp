#include "core/TaskStore.hpp"

#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTextBoundaryFinder>
#include <QUuid>

namespace waypoint {
namespace {

QString queryFailure(const QString &context, const QSqlQuery &query) {
  return QStringLiteral("%1: %2").arg(context, query.lastError().text());
}

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

QString newIdentifier() { return QUuid::createUuid().toString(QUuid::WithoutBraces); }

bool isValidTaskEmoji(const QString &emoji) {
  if (emoji.isEmpty()) {
    return true;
  }
  if (emoji.size() > 64 || emoji.trimmed() != emoji) {
    return false;
  }
  QTextBoundaryFinder finder(QTextBoundaryFinder::Grapheme, emoji);
  finder.toStart();
  return finder.toNextBoundary() == emoji.size();
}

QString encodeJson(const QJsonObject &json) {
  return QString::fromUtf8(QJsonDocument(json).toJson(QJsonDocument::Compact));
}

TaskRecord taskFromQuery(const QSqlQuery &query) {
  TaskRecord task;
  task.id = query.value(0).toString();
  task.title = query.value(1).toString();
  task.scheduledDate = QDate::fromString(query.value(2).toString(), Qt::ISODate);
  task.completed = query.value(3).toBool();
  task.createdAt = QDateTime::fromString(query.value(4).toString(), Qt::ISODateWithMs);
  task.updatedAt = QDateTime::fromString(query.value(5).toString(), Qt::ISODateWithMs);
  task.version = query.value(6).toLongLong();
  task.scheduledTime = QTime::fromString(query.value(13).toString(), QStringLiteral("HH:mm"));
  task.emoji = query.value(14).toString();

  QJsonArray weekdays;
  const QJsonDocument weekdayDocument = QJsonDocument::fromJson(query.value(9).toByteArray());
  if (weekdayDocument.isArray()) {
    weekdays = weekdayDocument.array();
  }
  task.recurrence = RecurrenceRule::fromJson({
      {QStringLiteral("frequency"), query.value(7).toString()},
      {QStringLiteral("interval"), query.value(8).toInt()},
      {QStringLiteral("weekdays"), weekdays},
      {QStringLiteral("endMode"), query.value(10).toString()},
      {QStringLiteral("untilDate"), query.value(11).toString()},
      {QStringLiteral("occurrenceCount"), query.value(12).toInt()},
  });
  return task;
}

TaskOccurrenceState occurrenceStateFromQuery(const QSqlQuery &query) {
  TaskOccurrenceState state;
  state.taskId = query.value(0).toString();
  state.occurrenceDate = QDate::fromString(query.value(1).toString(), Qt::ISODate);
  const QString status = query.value(2).toString();
  state.status = status == QStringLiteral("skipped")   ? OccurrenceStatus::Skipped
                 : status == QStringLiteral("pending") ? OccurrenceStatus::Pending
                                                       : OccurrenceStatus::Completed;
  state.completedAt = QDateTime::fromString(query.value(3).toString(), Qt::ISODateWithMs);
  state.updatedAt = QDateTime::fromString(query.value(4).toString(), Qt::ISODateWithMs);
  state.version = query.value(5).toLongLong();
  return state;
}

QString recurrenceWeekdaysJson(const RecurrenceRule &recurrence) {
  return QString::fromUtf8(QJsonDocument(recurrence.toJson().value(QStringLiteral("weekdays")).toArray())
                               .toJson(QJsonDocument::Compact));
}

void addRecurrenceBindValues(QSqlQuery &query, const RecurrenceRule &recurrence) {
  const QJsonObject json = recurrence.toJson();
  query.addBindValue(json.value(QStringLiteral("frequency")).toString());
  query.addBindValue(recurrence.interval);
  query.addBindValue(recurrenceWeekdaysJson(recurrence));
  query.addBindValue(json.value(QStringLiteral("endMode")).toString());
  query.addBindValue(recurrence.untilDate.isValid() ? recurrence.untilDate.toString(Qt::ISODate)
                                                    : QVariant());
  query.addBindValue(recurrence.occurrenceCount);
}

} // namespace

QString defaultWaypointDatabasePath() {
  const QString overrideDirectory = qEnvironmentVariable("WAYPOINT_DATA_DIR");
  const QString directory = overrideDirectory.isEmpty()
                                ? QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
                                : overrideDirectory;
  return QDir(directory).filePath(QStringLiteral("waypoint.sqlite3"));
}

TaskStore::TaskStore(QString databasePath, QObject *parent)
    : QObject(parent), m_databasePath(std::move(databasePath)),
      m_connectionName(QStringLiteral("waypoint-store-%1").arg(newIdentifier())) {}

TaskStore::~TaskStore() {
  if (m_database.isValid()) {
    m_database.close();
    m_database = {};
  }
  QSqlDatabase::removeDatabase(m_connectionName);
}

bool TaskStore::open(QString *errorMessage) {
  const QFileInfo databaseFile(m_databasePath);
  if (!QDir().mkpath(databaseFile.absolutePath())) {
    setError(errorMessage,
             QStringLiteral("Cannot create Waypoint data directory: %1").arg(databaseFile.absolutePath()));
    return false;
  }

  m_database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
  m_database.setDatabaseName(m_databasePath);
  if (!m_database.open()) {
    setError(errorMessage, QStringLiteral("Cannot open Waypoint database %1: %2")
                               .arg(m_databasePath, m_database.lastError().text()));
    return false;
  }

  QSqlQuery pragma(m_database);
  if (!pragma.exec(QStringLiteral("PRAGMA journal_mode=WAL"))) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot enable SQLite WAL mode"), pragma));
    return false;
  }
  if (!pragma.exec(QStringLiteral("PRAGMA foreign_keys=ON"))) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot enable SQLite foreign keys"), pragma));
    return false;
  }
  return migrate(errorMessage);
}

bool TaskStore::migrate(QString *errorMessage) {
  const QStringList statements = {
      QStringLiteral(
          "CREATE TABLE IF NOT EXISTS tasks ("
          "id TEXT PRIMARY KEY, title TEXT NOT NULL CHECK(length(trim(title)) > 0), "
          "scheduled_date TEXT, completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1)), "
          "created_at TEXT NOT NULL, updated_at TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, "
          "deleted_at TEXT, recurrence_frequency TEXT NOT NULL DEFAULT 'none', "
          "recurrence_interval INTEGER NOT NULL DEFAULT 1, "
          "recurrence_weekdays TEXT NOT NULL DEFAULT '[]', "
          "recurrence_end_mode TEXT NOT NULL DEFAULT 'never', recurrence_until TEXT, "
          "recurrence_count INTEGER NOT NULL DEFAULT 0, scheduled_time TEXT, "
          "emoji TEXT NOT NULL DEFAULT '')"),
      QStringLiteral("CREATE INDEX IF NOT EXISTS tasks_schedule_idx "
                     "ON tasks(scheduled_date, completed) WHERE deleted_at IS NULL"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS outbox ("
                     "mutation_id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, "
                     "entity_id TEXT NOT NULL, operation TEXT NOT NULL, "
                     "payload_json TEXT NOT NULL, created_at TEXT NOT NULL)"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS task_occurrence_states ("
                     "task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, "
                     "occurrence_date TEXT NOT NULL, "
                     "status TEXT NOT NULL CHECK(status IN ('pending', 'completed', 'skipped')), "
                     "completed_at TEXT, updated_at TEXT NOT NULL, "
                     "version INTEGER NOT NULL DEFAULT 1, "
                     "PRIMARY KEY(task_id, occurrence_date))"),
      QStringLiteral("CREATE INDEX IF NOT EXISTS occurrence_states_date_idx "
                     "ON task_occurrence_states(occurrence_date)"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS reminder_deliveries ("
                     "task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, "
                     "occurrence_date TEXT NOT NULL, scheduled_time TEXT NOT NULL, "
                     "delivered_at TEXT NOT NULL, "
                     "PRIMARY KEY(task_id, occurrence_date, scheduled_time))"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS sync_state ("
                     "key TEXT PRIMARY KEY, value TEXT NOT NULL)"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS holiday_cache ("
                     "id INTEGER PRIMARY KEY AUTOINCREMENT, holiday_date TEXT NOT NULL, name TEXT NOT NULL, "
                     "description TEXT, kind TEXT NOT NULL, scope_level TEXT NOT NULL, state_code TEXT, "
                     "city_code TEXT, source TEXT NOT NULL)"),
      QStringLiteral("CREATE INDEX IF NOT EXISTS holiday_cache_date_idx "
                     "ON holiday_cache(holiday_date)"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS holiday_coverage ("
                     "source TEXT NOT NULL, holiday_year INTEGER NOT NULL, status TEXT NOT NULL, "
                     "fetched_at TEXT, last_error TEXT, PRIMARY KEY(source, holiday_year))"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS holiday_preferences ("
                     "singleton INTEGER PRIMARY KEY CHECK(singleton = 1), state_code TEXT, city_code TEXT, "
                     "include_national INTEGER NOT NULL DEFAULT 1, include_state INTEGER NOT NULL DEFAULT 1, "
                     "include_municipal INTEGER NOT NULL DEFAULT 1, "
                     "include_commemorative INTEGER NOT NULL DEFAULT 0, "
                     "include_optional INTEGER NOT NULL DEFAULT 1, revision INTEGER NOT NULL DEFAULT 0, "
                     "updated_at TEXT NOT NULL)"),
      QStringLiteral("INSERT OR IGNORE INTO holiday_preferences(singleton, updated_at) "
                     "VALUES(1, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS brazil_municipalities ("
                     "state_code TEXT NOT NULL, city_code TEXT PRIMARY KEY, name TEXT NOT NULL)"),
      QStringLiteral("CREATE INDEX IF NOT EXISTS brazil_municipalities_state_name_idx "
                     "ON brazil_municipalities(state_code, name)"),
  };

  for (const QString &statement : statements) {
    QSqlQuery query(m_database);
    if (!query.exec(statement)) {
      setError(errorMessage, queryFailure(QStringLiteral("Cannot migrate Waypoint database"), query));
      return false;
    }
  }

  QSet<QString> taskColumns;
  QSqlQuery inspectTasks(m_database);
  if (!inspectTasks.exec(QStringLiteral("PRAGMA table_info(tasks)"))) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot inspect task schema"), inspectTasks));
    return false;
  }
  while (inspectTasks.next()) {
    taskColumns.insert(inspectTasks.value(1).toString());
  }
  const QList<QPair<QString, QString>> recurrenceColumns = {
      {QStringLiteral("recurrence_frequency"), QStringLiteral("TEXT NOT NULL DEFAULT 'none'")},
      {QStringLiteral("recurrence_interval"), QStringLiteral("INTEGER NOT NULL DEFAULT 1")},
      {QStringLiteral("recurrence_weekdays"), QStringLiteral("TEXT NOT NULL DEFAULT '[]'")},
      {QStringLiteral("recurrence_end_mode"), QStringLiteral("TEXT NOT NULL DEFAULT 'never'")},
      {QStringLiteral("recurrence_until"), QStringLiteral("TEXT")},
      {QStringLiteral("recurrence_count"), QStringLiteral("INTEGER NOT NULL DEFAULT 0")},
      {QStringLiteral("scheduled_time"), QStringLiteral("TEXT")},
      {QStringLiteral("emoji"), QStringLiteral("TEXT NOT NULL DEFAULT ''")},
  };
  for (const auto &[name, definition] : recurrenceColumns) {
    if (taskColumns.contains(name)) {
      continue;
    }
    QSqlQuery addColumn(m_database);
    if (!addColumn.exec(QStringLiteral("ALTER TABLE tasks ADD COLUMN %1 %2").arg(name, definition))) {
      setError(errorMessage,
               queryFailure(QStringLiteral("Cannot add task recurrence column %1").arg(name), addColumn));
      return false;
    }
  }

  QSet<QString> outboxColumns;
  QSqlQuery inspectOutbox(m_database);
  if (!inspectOutbox.exec(QStringLiteral("PRAGMA table_info(outbox)"))) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot inspect outbox schema"), inspectOutbox));
    return false;
  }
  while (inspectOutbox.next()) {
    outboxColumns.insert(inspectOutbox.value(1).toString());
  }
  if (outboxColumns.contains(QStringLiteral("task_id")) &&
      !outboxColumns.contains(QStringLiteral("entity_type"))) {
    const QStringList outboxMigration = {
        QStringLiteral("DROP TABLE IF EXISTS outbox_v2"),
        QStringLiteral("CREATE TABLE outbox_v2 ("
                       "mutation_id TEXT PRIMARY KEY, entity_type TEXT NOT NULL, "
                       "entity_id TEXT NOT NULL, operation TEXT NOT NULL, "
                       "payload_json TEXT NOT NULL, created_at TEXT NOT NULL)"),
        QStringLiteral("INSERT INTO outbox_v2 "
                       "(mutation_id, entity_type, entity_id, operation, payload_json, created_at) "
                       "SELECT mutation_id, 'task', task_id, operation, payload_json, created_at "
                       "FROM outbox"),
        QStringLiteral("DROP TABLE outbox"),
        QStringLiteral("ALTER TABLE outbox_v2 RENAME TO outbox"),
    };
    if (!beginTransaction(errorMessage)) {
      return false;
    }
    for (const QString &statement : outboxMigration) {
      QSqlQuery migrateOutbox(m_database);
      if (!migrateOutbox.exec(statement)) {
        rollbackTransaction();
        setError(errorMessage,
                 queryFailure(QStringLiteral("Cannot migrate synchronization outbox"), migrateOutbox));
        return false;
      }
    }
    if (!commitTransaction(errorMessage)) {
      rollbackTransaction();
      return false;
    }
  }
  QSqlQuery columns(m_database);
  if (!columns.exec(QStringLiteral("PRAGMA table_info(holiday_preferences)"))) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot inspect holiday preference schema"), columns));
    return false;
  }
  bool hasOptionalPreference = false;
  while (columns.next()) {
    hasOptionalPreference =
        hasOptionalPreference || columns.value(1).toString() == QStringLiteral("include_optional");
  }
  if (!hasOptionalPreference) {
    QSqlQuery addOptionalPreference(m_database);
    if (!addOptionalPreference.exec(QStringLiteral(
            "ALTER TABLE holiday_preferences ADD COLUMN include_optional INTEGER NOT NULL DEFAULT 1"))) {
      setError(errorMessage,
               queryFailure(QStringLiteral("Cannot add optional holiday preference"), addOptionalPreference));
      return false;
    }
  }
  return true;
}

QList<TaskRecord> TaskStore::listActiveTasks(QString *errorMessage) const {
  QList<TaskRecord> tasks;
  QSqlQuery query(m_database);
  query.prepare(
      QStringLiteral("SELECT id, title, scheduled_date, completed, created_at, updated_at, version, "
                     "recurrence_frequency, recurrence_interval, recurrence_weekdays, "
                     "recurrence_end_mode, recurrence_until, recurrence_count, scheduled_time, emoji "
                     "FROM tasks WHERE deleted_at IS NULL "
                     "ORDER BY scheduled_date IS NULL, scheduled_date, completed, created_at"));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot list active tasks"), query));
    return tasks;
  }
  while (query.next()) {
    tasks.append(taskFromQuery(query));
  }
  return tasks;
}

QList<TaskOccurrenceState> TaskStore::listOccurrenceStates(QString *errorMessage) const {
  QList<TaskOccurrenceState> states;
  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("SELECT task_id, occurrence_date, status, completed_at, updated_at, version "
                               "FROM task_occurrence_states ORDER BY occurrence_date, task_id"));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot list task occurrence states"), query));
    return states;
  }
  while (query.next()) {
    states.append(occurrenceStateFromQuery(query));
  }
  return states;
}

QList<TaskOccurrence> TaskStore::listOccurrences(const QDate &from, const QDate &to,
                                                 QString *errorMessage) const {
  if (!from.isValid() || !to.isValid() || from > to) {
    setError(errorMessage, QStringLiteral("Occurrence range requires valid ordered dates"));
    return {};
  }
  QString error;
  const QList<TaskRecord> tasks = listActiveTasks(&error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  const QList<TaskOccurrenceState> states = listOccurrenceStates(&error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  return assignCalendarMarkers(projectOccurrences(tasks, states, from, to), tasks, states,
                               QDate::currentDate());
}

bool TaskStore::claimReminderDelivery(const QString &taskId, const QDate &occurrenceDate,
                                      const QTime &scheduledTime, bool *claimed, QString *errorMessage) {
  if (taskId.isEmpty() || !occurrenceDate.isValid() || !scheduledTime.isValid() || claimed == nullptr) {
    setError(errorMessage, QStringLiteral("Reminder delivery requires a task, date, time, and result"));
    return false;
  }

  QSqlQuery query(m_database);
  query.prepare(
      QStringLiteral("INSERT OR IGNORE INTO reminder_deliveries "
                     "(task_id, occurrence_date, scheduled_time, delivered_at) VALUES (?, ?, ?, ?)"));
  query.addBindValue(taskId);
  query.addBindValue(occurrenceDate.toString(Qt::ISODate));
  query.addBindValue(scheduledTime.toString(QStringLiteral("HH:mm")));
  query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot claim task reminder delivery"), query));
    return false;
  }
  *claimed = query.numRowsAffected() == 1;
  return true;
}

bool TaskStore::releaseReminderDelivery(const QString &taskId, const QDate &occurrenceDate,
                                        const QTime &scheduledTime, QString *errorMessage) {
  if (taskId.isEmpty() || !occurrenceDate.isValid() || !scheduledTime.isValid()) {
    setError(errorMessage, QStringLiteral("Reminder delivery release requires a task, date, and time"));
    return false;
  }

  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("DELETE FROM reminder_deliveries "
                               "WHERE task_id = ? AND occurrence_date = ? AND scheduled_time = ?"));
  query.addBindValue(taskId);
  query.addBindValue(occurrenceDate.toString(Qt::ISODate));
  query.addBindValue(scheduledTime.toString(QStringLiteral("HH:mm")));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot release task reminder delivery"), query));
    return false;
  }
  return true;
}

QList<TaskOccurrence> TaskStore::listActionableOccurrences(const QDate &today, QString *errorMessage) const {
  if (!today.isValid()) {
    setError(errorMessage, QStringLiteral("Today must be a valid calendar date"));
    return {};
  }
  QString error;
  const QList<TaskRecord> tasks = listActiveTasks(&error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  const QList<TaskOccurrenceState> states = listOccurrenceStates(&error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  return projectActionableOccurrences(tasks, states, today);
}

bool TaskStore::createTask(const QString &title, const QDate &scheduledDate, const QTime &scheduledTime,
                           const RecurrenceRule &recurrence, const QString &emoji, TaskRecord *createdTask,
                           QString *errorMessage) {
  const QString normalizedTitle = title.trimmed();
  if (normalizedTitle.isEmpty()) {
    setError(errorMessage, QStringLiteral("Task title must contain at least one visible character"));
    return false;
  }
  if (!isValidTaskEmoji(emoji)) {
    setError(errorMessage, QStringLiteral("Task emoji must be empty or contain one grapheme"));
    return false;
  }
  QString recurrenceError;
  if (!recurrence.isValid(&recurrenceError) || (recurrence.isRecurring() && !scheduledDate.isValid()) ||
      (recurrence.endMode == RecurrenceEndMode::OnDate && recurrence.untilDate < scheduledDate)) {
    setError(errorMessage, recurrenceError.isEmpty()
                               ? QStringLiteral("Recurring tasks require a valid anchor and end date")
                               : recurrenceError);
    return false;
  }

  TaskRecord task;
  task.id = newIdentifier();
  task.title = normalizedTitle;
  task.scheduledDate = scheduledDate;
  const QTime now = QTime::currentTime();
  task.scheduledTime = scheduledTime.isValid() ? QTime(scheduledTime.hour(), scheduledTime.minute())
                                               : QTime(now.hour(), now.minute());
  task.emoji = emoji.isNull() ? QStringLiteral("") : emoji;
  task.recurrence = recurrence;
  task.createdAt = QDateTime::currentDateTimeUtc();
  task.updatedAt = task.createdAt;
  task.version = 1;

  if (!beginTransaction(errorMessage)) {
    return false;
  }

  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("INSERT INTO tasks "
                               "(id, title, scheduled_date, completed, created_at, updated_at, version, "
                               "recurrence_frequency, recurrence_interval, recurrence_weekdays, "
                               "recurrence_end_mode, recurrence_until, recurrence_count, scheduled_time, "
                               "emoji) VALUES (?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"));
  query.addBindValue(task.id);
  query.addBindValue(task.title);
  query.addBindValue(task.scheduledDate.isValid() ? task.scheduledDate.toString(Qt::ISODate) : QVariant());
  query.addBindValue(task.createdAt.toString(Qt::ISODateWithMs));
  query.addBindValue(task.updatedAt.toString(Qt::ISODateWithMs));
  query.addBindValue(task.version);
  addRecurrenceBindValues(query, task.recurrence);
  query.addBindValue(task.scheduledTime.toString(QStringLiteral("HH:mm")));
  query.addBindValue(task.emoji);
  if (!query.exec()) {
    rollbackTransaction();
    setError(errorMessage,
             queryFailure(QStringLiteral("Cannot create task '%1'").arg(normalizedTitle), query));
    return false;
  }

  const QString mutationId = newIdentifier();
  if (!enqueueMutation(mutationId, QStringLiteral("task"), task.id, QStringLiteral("upsert"), task.toJson(),
                       errorMessage) ||
      !commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }

  if (createdTask != nullptr) {
    *createdTask = task;
  }
  emit tasksChanged();
  return true;
}

bool TaskStore::setTaskCompleted(const QString &taskId, bool completed, QString *errorMessage) {
  return mutateTask(taskId, QStringLiteral("upsert"), {{QStringLiteral("completed"), completed}},
                    errorMessage);
}

bool TaskStore::setOccurrenceCompleted(const QString &taskId, const QDate &occurrenceDate,
                                       const bool completed, QString *errorMessage) {
  return setOccurrenceState(taskId, occurrenceDate,
                            completed ? OccurrenceStatus::Completed : OccurrenceStatus::Pending,
                            errorMessage);
}

bool TaskStore::skipOccurrence(const QString &taskId, const QDate &occurrenceDate, QString *errorMessage) {
  return setOccurrenceState(taskId, occurrenceDate, OccurrenceStatus::Skipped, errorMessage);
}

bool TaskStore::setOccurrenceState(const QString &taskId, const QDate &occurrenceDate,
                                   const OccurrenceStatus status, QString *errorMessage) {
  if (!occurrenceDate.isValid()) {
    setError(errorMessage, QStringLiteral("Occurrence date must be a valid calendar date"));
    return false;
  }

  QSqlQuery selectTask(m_database);
  selectTask.prepare(
      QStringLiteral("SELECT id, title, scheduled_date, completed, created_at, updated_at, version, "
                     "recurrence_frequency, recurrence_interval, recurrence_weekdays, "
                     "recurrence_end_mode, recurrence_until, recurrence_count, scheduled_time, emoji "
                     "FROM tasks WHERE id = ? AND deleted_at IS NULL"));
  selectTask.addBindValue(taskId);
  if (!selectTask.exec() || !selectTask.next()) {
    setError(errorMessage, selectTask.lastError().isValid()
                               ? queryFailure(QStringLiteral("Cannot read task %1").arg(taskId), selectTask)
                               : QStringLiteral("Cannot mutate occurrence for missing task: %1").arg(taskId));
    return false;
  }
  const TaskRecord task = taskFromQuery(selectTask);
  if (!task.recurrence.isRecurring()) {
    if (occurrenceDate != task.scheduledDate || status == OccurrenceStatus::Skipped) {
      setError(errorMessage, QStringLiteral("Task %1 has no occurrence on %2")
                                 .arg(taskId, occurrenceDate.toString(Qt::ISODate)));
      return false;
    }
    return setTaskCompleted(taskId, status == OccurrenceStatus::Completed, errorMessage);
  }
  if (recurrenceDates(task.scheduledDate, task.recurrence, occurrenceDate, occurrenceDate).isEmpty()) {
    setError(
        errorMessage,
        QStringLiteral("Task %1 has no occurrence on %2").arg(taskId, occurrenceDate.toString(Qt::ISODate)));
    return false;
  }

  qint64 version = 1;
  QSqlQuery current(m_database);
  current.prepare(
      QStringLiteral("SELECT version FROM task_occurrence_states WHERE task_id = ? AND occurrence_date = ?"));
  current.addBindValue(taskId);
  current.addBindValue(occurrenceDate.toString(Qt::ISODate));
  if (!current.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot read occurrence state"), current));
    return false;
  }
  if (current.next()) {
    version = current.value(0).toLongLong() + 1;
  }

  TaskOccurrenceState state;
  state.taskId = taskId;
  state.occurrenceDate = occurrenceDate;
  state.status = status;
  state.completedAt = status == OccurrenceStatus::Completed ? QDateTime::currentDateTimeUtc() : QDateTime();
  state.updatedAt = QDateTime::currentDateTimeUtc();
  state.version = version;

  QString statusText = QStringLiteral("pending");
  if (status == OccurrenceStatus::Completed) {
    statusText = QStringLiteral("completed");
  } else if (status == OccurrenceStatus::Skipped) {
    statusText = QStringLiteral("skipped");
  }

  if (!beginTransaction(errorMessage)) {
    return false;
  }
  QSqlQuery upsert(m_database);
  upsert.prepare(QStringLiteral("INSERT INTO task_occurrence_states "
                                "(task_id, occurrence_date, status, completed_at, updated_at, version) "
                                "VALUES (?, ?, ?, ?, ?, ?) "
                                "ON CONFLICT(task_id, occurrence_date) DO UPDATE SET "
                                "status=excluded.status, completed_at=excluded.completed_at, "
                                "updated_at=excluded.updated_at, version=excluded.version"));
  upsert.addBindValue(state.taskId);
  upsert.addBindValue(state.occurrenceDate.toString(Qt::ISODate));
  upsert.addBindValue(statusText);
  upsert.addBindValue(state.completedAt.isValid() ? state.completedAt.toString(Qt::ISODateWithMs)
                                                  : QVariant());
  upsert.addBindValue(state.updatedAt.toString(Qt::ISODateWithMs));
  upsert.addBindValue(state.version);
  if (!upsert.exec() ||
      !enqueueMutation(newIdentifier(), QStringLiteral("occurrence"),
                       occurrenceKey(state.taskId, state.occurrenceDate), QStringLiteral("upsert"),
                       state.toJson(), errorMessage) ||
      !commitTransaction(errorMessage)) {
    if (upsert.lastError().isValid()) {
      setError(errorMessage, queryFailure(QStringLiteral("Cannot update occurrence state"), upsert));
    }
    rollbackTransaction();
    return false;
  }
  emit tasksChanged();
  return true;
}

bool TaskStore::rescheduleTask(const QString &taskId, const QDate &scheduledDate, const QTime &scheduledTime,
                               QString *errorMessage) {
  if (!scheduledDate.isValid() || !scheduledTime.isValid()) {
    setError(errorMessage,
             QStringLiteral("Cannot reschedule task %1: expected an ISO calendar date and HH:mm time")
                 .arg(taskId));
    return false;
  }
  return mutateTask(taskId, QStringLiteral("upsert"),
                    {{QStringLiteral("scheduledDate"), scheduledDate.toString(Qt::ISODate)},
                     {QStringLiteral("scheduledTime"), scheduledTime.toString(QStringLiteral("HH:mm"))}},
                    errorMessage);
}
bool TaskStore::editTask(const QString &taskId, const QString &title, const QTime &scheduledTime,
                         const RecurrenceRule &recurrence, const QString &emoji, QString *errorMessage) {
  return mutateTask(taskId, QStringLiteral("upsert"),
                    {{QStringLiteral("title"), title},
                     {QStringLiteral("scheduledTime"), scheduledTime.toString(QStringLiteral("HH:mm"))},
                     {QStringLiteral("recurrence"), recurrence.toJson()},
                     {QStringLiteral("emoji"), emoji}},
                    errorMessage);
}

bool TaskStore::deleteOccurrence(const QString &taskId, const QDate &occurrenceDate,
                                 const RecurrenceEditScope scope, QString *errorMessage) {
  QSqlQuery select(m_database);
  select.prepare(
      QStringLiteral("SELECT id, title, scheduled_date, completed, created_at, updated_at, version, "
                     "recurrence_frequency, recurrence_interval, recurrence_weekdays, "
                     "recurrence_end_mode, recurrence_until, recurrence_count, scheduled_time, emoji "
                     "FROM tasks WHERE id = ? AND deleted_at IS NULL"));
  select.addBindValue(taskId);
  if (!select.exec() || !select.next()) {
    setError(errorMessage, select.lastError().isValid()
                               ? queryFailure(QStringLiteral("Cannot read task %1").arg(taskId), select)
                               : QStringLiteral("Cannot delete occurrence for missing task: %1").arg(taskId));
    return false;
  }
  const TaskRecord task = taskFromQuery(select);
  if (!task.recurrence.isRecurring() || scope == RecurrenceEditScope::Series) {
    return deleteTask(taskId, errorMessage);
  }
  if (recurrenceDates(task.scheduledDate, task.recurrence, occurrenceDate, occurrenceDate).isEmpty()) {
    setError(
        errorMessage,
        QStringLiteral("Task %1 has no occurrence on %2").arg(taskId, occurrenceDate.toString(Qt::ISODate)));
    return false;
  }
  if (scope == RecurrenceEditScope::Occurrence) {
    return skipOccurrence(taskId, occurrenceDate, errorMessage);
  }
  if (occurrenceDate <= task.scheduledDate) {
    return deleteTask(taskId, errorMessage);
  }

  RecurrenceRule recurrence = task.recurrence;
  recurrence.endMode = RecurrenceEndMode::OnDate;
  recurrence.untilDate = occurrenceDate.addDays(-1);
  recurrence.occurrenceCount = 0;
  return mutateTask(taskId, QStringLiteral("upsert"), {{QStringLiteral("recurrence"), recurrence.toJson()}},
                    errorMessage);
}

bool TaskStore::mutateTask(const QString &taskId, const QString &operation, const QJsonObject &fields,
                           QString *errorMessage) {
  QSqlQuery select(m_database);
  select.prepare(
      QStringLiteral("SELECT id, title, scheduled_date, completed, created_at, updated_at, version, "
                     "recurrence_frequency, recurrence_interval, recurrence_weekdays, "
                     "recurrence_end_mode, recurrence_until, recurrence_count, scheduled_time, emoji "
                     "FROM tasks WHERE id = ? AND deleted_at IS NULL"));
  select.addBindValue(taskId);
  if (!select.exec() || !select.next()) {
    setError(errorMessage, select.lastError().isValid()
                               ? queryFailure(QStringLiteral("Cannot read task %1").arg(taskId), select)
                               : QStringLiteral("Cannot mutate missing task: %1").arg(taskId));
    return false;
  }

  TaskRecord task = taskFromQuery(select);
  if (fields.contains(QStringLiteral("title"))) {
    task.title = fields.value(QStringLiteral("title")).toString().trimmed();
  }
  if (task.title.isEmpty()) {
    setError(errorMessage, QStringLiteral("Task title must contain at least one visible character"));
    return false;
  }
  if (fields.contains(QStringLiteral("completed"))) {
    task.completed = fields.value(QStringLiteral("completed")).toBool();
  }
  if (fields.contains(QStringLiteral("scheduledDate"))) {
    task.scheduledDate =
        QDate::fromString(fields.value(QStringLiteral("scheduledDate")).toString(), Qt::ISODate);
  }
  if (fields.contains(QStringLiteral("scheduledTime"))) {
    task.scheduledTime =
        QTime::fromString(fields.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("HH:mm"));
  }
  if (fields.contains(QStringLiteral("emoji"))) {
    task.emoji = fields.value(QStringLiteral("emoji")).toString(QStringLiteral(""));
  }
  if (!isValidTaskEmoji(task.emoji)) {
    setError(errorMessage, QStringLiteral("Task emoji must be empty or contain one grapheme"));
    return false;
  }
  if (!task.scheduledTime.isValid()) {
    setError(errorMessage, QStringLiteral("Task time must use HH:mm local wall-clock format"));
    return false;
  }
  if (fields.contains(QStringLiteral("recurrence"))) {
    task.recurrence = RecurrenceRule::fromJson(fields.value(QStringLiteral("recurrence")).toObject());
  }
  QString recurrenceError;
  if (!task.recurrence.isValid(&recurrenceError) || (task.recurrence.endMode == RecurrenceEndMode::OnDate &&
                                                     task.recurrence.untilDate < task.scheduledDate)) {
    setError(errorMessage, recurrenceError.isEmpty() ? QStringLiteral("Recurrence end precedes its anchor")
                                                     : recurrenceError);
    return false;
  }
  task.updatedAt = QDateTime::currentDateTimeUtc();
  ++task.version;

  if (!beginTransaction(errorMessage)) {
    return false;
  }
  QSqlQuery update(m_database);
  update.prepare(
      QStringLiteral("UPDATE tasks SET title = ?, scheduled_date = ?, completed = ?, updated_at = ?, "
                     "version = ?, recurrence_frequency = ?, recurrence_interval = ?, "
                     "recurrence_weekdays = ?, recurrence_end_mode = ?, recurrence_until = ?, "
                     "recurrence_count = ?, scheduled_time = ?, emoji = ? "
                     "WHERE id = ? AND deleted_at IS NULL"));
  update.addBindValue(task.title);
  update.addBindValue(task.scheduledDate.isValid() ? task.scheduledDate.toString(Qt::ISODate) : QVariant());
  update.addBindValue(task.completed);
  update.addBindValue(task.updatedAt.toString(Qt::ISODateWithMs));
  update.addBindValue(task.version);
  addRecurrenceBindValues(update, task.recurrence);
  update.addBindValue(task.scheduledTime.toString(QStringLiteral("HH:mm")));
  update.addBindValue(task.emoji);
  update.addBindValue(task.id);
  if (!update.exec()) {
    rollbackTransaction();
    setError(errorMessage, queryFailure(QStringLiteral("Cannot update task %1").arg(taskId), update));
    return false;
  }

  if (!enqueueMutation(newIdentifier(), QStringLiteral("task"), task.id, operation, task.toJson(),
                       errorMessage) ||
      !commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }
  emit tasksChanged();
  return true;
}

bool TaskStore::deleteTask(const QString &taskId, QString *errorMessage) {
  const QDateTime deletedAt = QDateTime::currentDateTimeUtc();
  QJsonObject tombstone{{QStringLiteral("id"), taskId},
                        {QStringLiteral("deletedAt"), deletedAt.toString(Qt::ISODateWithMs)}};
  if (!beginTransaction(errorMessage)) {
    return false;
  }

  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("UPDATE tasks SET deleted_at = ?, updated_at = ?, version = version + 1 "
                               "WHERE id = ? AND deleted_at IS NULL"));
  query.addBindValue(deletedAt.toString(Qt::ISODateWithMs));
  query.addBindValue(deletedAt.toString(Qt::ISODateWithMs));
  query.addBindValue(taskId);
  if (!query.exec() || query.numRowsAffected() != 1) {
    rollbackTransaction();
    setError(errorMessage, query.lastError().isValid()
                               ? queryFailure(QStringLiteral("Cannot delete task %1").arg(taskId), query)
                               : QStringLiteral("Cannot delete missing task: %1").arg(taskId));
    return false;
  }

  if (!enqueueMutation(newIdentifier(), QStringLiteral("task"), taskId, QStringLiteral("delete"), tombstone,
                       errorMessage) ||
      !commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }
  emit tasksChanged();
  return true;
}

bool TaskStore::enqueueMutation(const QString &mutationId, const QString &entityType, const QString &entityId,
                                const QString &operation, const QJsonObject &payload, QString *errorMessage) {
  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("INSERT INTO outbox "
                               "(mutation_id, entity_type, entity_id, operation, payload_json, created_at) "
                               "VALUES (?, ?, ?, ?, ?, ?)"));
  query.addBindValue(mutationId);
  query.addBindValue(entityType);
  query.addBindValue(entityId);
  query.addBindValue(operation);
  query.addBindValue(encodeJson(payload));
  query.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  if (query.exec()) {
    return true;
  }
  setError(errorMessage, queryFailure(QStringLiteral("Cannot enqueue mutation %1").arg(mutationId), query));
  return false;
}

QJsonArray TaskStore::pendingMutations(QString *errorMessage) const {
  QJsonArray mutations;
  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("SELECT mutation_id, entity_type, entity_id, operation, payload_json "
                               "FROM outbox ORDER BY created_at"));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot list sync outbox"), query));
    return mutations;
  }
  while (query.next()) {
    QJsonParseError parseError;
    const QJsonDocument payload = QJsonDocument::fromJson(query.value(4).toByteArray(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !payload.isObject()) {
      setError(errorMessage, QStringLiteral("Invalid outbox payload for mutation %1: %2")
                                 .arg(query.value(0).toString(), parseError.errorString()));
      return {};
    }
    mutations.append(QJsonObject{
        {QStringLiteral("mutationId"), query.value(0).toString()},
        {QStringLiteral("entityType"), query.value(1).toString()},
        {QStringLiteral("entityId"), query.value(2).toString()},
        {QStringLiteral("operation"), query.value(3).toString()},
        {QStringLiteral("payload"), payload.object()},
    });
  }
  return mutations;
}

QString TaskStore::syncCursor(QString *errorMessage) const {
  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("SELECT value FROM sync_state WHERE key = 'cursor'"));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot read sync cursor"), query));
    return {};
  }
  return query.next() ? query.value(0).toString() : QStringLiteral("0");
}

SyncConfiguration TaskStore::syncConfiguration(QString *errorMessage) const {
  SyncConfiguration configuration;
  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("SELECT key, value FROM sync_state WHERE key IN ('endpoint', 'token')"));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot read synchronization configuration"), query));
    return configuration;
  }
  while (query.next()) {
    const QString key = query.value(0).toString();
    if (key == QStringLiteral("endpoint")) {
      configuration.endpoint = QUrl(query.value(1).toString(), QUrl::StrictMode);
    } else if (key == QStringLiteral("token")) {
      configuration.token = query.value(1).toByteArray();
    }
  }
  return configuration;
}

bool TaskStore::saveSyncConfiguration(const SyncConfiguration &configuration, QString *errorMessage) {
  if (!beginTransaction(errorMessage)) {
    return false;
  }

  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("INSERT INTO sync_state(key, value) VALUES(?, ?) "
                               "ON CONFLICT(key) DO UPDATE SET value=excluded.value"));
  const QString endpointValue = configuration.endpoint.isEmpty()
                                    ? QStringLiteral("")
                                    : configuration.endpoint.toString(QUrl::FullyEncoded);
  const QString tokenValue =
      configuration.token.isEmpty() ? QStringLiteral("") : QString::fromUtf8(configuration.token);
  const QList<QPair<QString, QVariant>> values{
      {QStringLiteral("endpoint"), endpointValue},
      {QStringLiteral("token"), tokenValue},
  };
  for (const auto &[key, value] : values) {
    query.bindValue(0, key);
    query.bindValue(1, value);
    if (!query.exec()) {
      rollbackTransaction();
      setError(errorMessage,
               queryFailure(QStringLiteral("Cannot save synchronization setting '%1'").arg(key), query));
      return false;
    }
  }
  if (!commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }
  return true;
}
QJsonObject TaskStore::holidayPreferences(QString *errorMessage) const {
  QSqlQuery query(m_database);
  query.prepare(
      QStringLiteral("SELECT state_code, city_code, include_national, include_state, include_municipal, "
                     "include_commemorative, include_optional, revision, updated_at "
                     "FROM holiday_preferences WHERE singleton = 1"));
  if (!query.exec() || !query.next()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot read holiday preferences"), query));
    return {};
  }
  return {
      {QStringLiteral("stateCode"), query.value(0).toString()},
      {QStringLiteral("cityCode"), query.value(1).toString()},
      {QStringLiteral("includeNational"), query.value(2).toBool()},
      {QStringLiteral("includeState"), query.value(3).toBool()},
      {QStringLiteral("includeMunicipal"), query.value(4).toBool()},
      {QStringLiteral("includeCommemorative"), query.value(5).toBool()},
      {QStringLiteral("includeOptional"), query.value(6).toBool()},
      {QStringLiteral("revision"), query.value(7).toLongLong()},
      {QStringLiteral("updatedAt"), query.value(8).toString()},
  };
}

bool TaskStore::saveHolidayPreferences(const QJsonObject &preferences, QString *errorMessage) {
  const QString stateCode = preferences.value(QStringLiteral("stateCode")).toString().trimmed().toUpper();
  const QString cityCode = preferences.value(QStringLiteral("cityCode")).toString().trimmed();
  const bool stateValid = stateCode.isEmpty() ||
                          (stateCode.size() == 2 && stateCode.at(0).isLetter() && stateCode.at(1).isLetter());
  if (!stateValid) {
    setError(errorMessage, QStringLiteral("Brazilian state code must contain exactly two letters"));
    return false;
  }
  if (!cityCode.isEmpty() && stateCode.isEmpty()) {
    setError(errorMessage, QStringLiteral("A city can only be selected together with a state"));
    return false;
  }

  QSqlQuery query(m_database);
  query.prepare(QStringLiteral(
      "UPDATE holiday_preferences SET state_code = ?, city_code = ?, include_national = ?, "
      "include_state = ?, include_municipal = ?, include_commemorative = ?, include_optional = ?, "
      "revision = revision + 1, updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') "
      "WHERE singleton = 1"));
  query.addBindValue(stateCode.isEmpty() ? QVariant() : stateCode);
  query.addBindValue(cityCode.isEmpty() ? QVariant() : cityCode);
  query.addBindValue(preferences.value(QStringLiteral("includeNational")).toBool(true));
  query.addBindValue(preferences.value(QStringLiteral("includeState")).toBool(true));
  query.addBindValue(preferences.value(QStringLiteral("includeMunicipal")).toBool(true));
  query.addBindValue(preferences.value(QStringLiteral("includeCommemorative")).toBool(false));
  query.addBindValue(preferences.value(QStringLiteral("includeOptional")).toBool(true));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot save holiday preferences"), query));
    return false;
  }
  emit holidayPreferencesChanged();
  return true;
}

QJsonArray TaskStore::listHolidays(const QDate &from, const QDate &to, QString *errorMessage) const {
  QJsonArray holidays;
  if (!from.isValid() || !to.isValid() || from > to) {
    setError(errorMessage, QStringLiteral("Holiday range requires valid ordered dates"));
    return holidays;
  }
  QSqlQuery query(m_database);
  query.prepare(QStringLiteral(
      "SELECT holiday_date, name, description, kind, scope_level, state_code, city_code, source "
      "FROM holiday_cache WHERE holiday_date BETWEEN ? AND ? "
      "ORDER BY holiday_date, kind, scope_level, name"));
  query.addBindValue(from.toString(Qt::ISODate));
  query.addBindValue(to.toString(Qt::ISODate));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot list cached holidays"), query));
    return holidays;
  }
  while (query.next()) {
    holidays.append(QJsonObject{
        {QStringLiteral("date"), query.value(0).toString()},
        {QStringLiteral("name"), query.value(1).toString()},
        {QStringLiteral("description"), query.value(2).toString()},
        {QStringLiteral("kind"), query.value(3).toString()},
        {QStringLiteral("scope"), query.value(4).toString()},
        {QStringLiteral("stateCode"), query.value(5).toString()},
        {QStringLiteral("cityCode"), query.value(6).toString()},
        {QStringLiteral("source"), query.value(7).toString()},
    });
  }
  return holidays;
}

QJsonArray TaskStore::holidayCoverage(QString *errorMessage) const {
  QJsonArray coverage;
  QSqlQuery query(m_database);
  query.prepare(
      QStringLiteral("SELECT source, holiday_year, status, fetched_at, last_error FROM holiday_coverage "
                     "ORDER BY holiday_year, source"));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot read holiday cache coverage"), query));
    return coverage;
  }
  while (query.next()) {
    coverage.append(QJsonObject{
        {QStringLiteral("source"), query.value(0).toString()},
        {QStringLiteral("year"), query.value(1).toInt()},
        {QStringLiteral("status"), query.value(2).toString()},
        {QStringLiteral("fetchedAt"), query.value(3).toString()},
        {QStringLiteral("lastError"), query.value(4).toString()},
    });
  }
  return coverage;
}

bool TaskStore::replaceHolidaySnapshot(const QDate &from, const QDate &to, const QJsonArray &holidays,
                                       const QJsonArray &coverage, QString *errorMessage) {
  if (!from.isValid() || !to.isValid() || from > to) {
    setError(errorMessage, QStringLiteral("Holiday snapshot requires valid ordered dates"));
    return false;
  }
  if (!beginTransaction(errorMessage)) {
    return false;
  }

  QSqlQuery removeHolidays(m_database);
  removeHolidays.prepare(QStringLiteral("DELETE FROM holiday_cache WHERE holiday_date BETWEEN ? AND ?"));
  removeHolidays.addBindValue(from.toString(Qt::ISODate));
  removeHolidays.addBindValue(to.toString(Qt::ISODate));
  if (!removeHolidays.exec()) {
    rollbackTransaction();
    setError(errorMessage,
             queryFailure(QStringLiteral("Cannot replace cached holiday range"), removeHolidays));
    return false;
  }

  QSqlQuery insertHoliday(m_database);
  insertHoliday.prepare(QStringLiteral(
      "INSERT INTO holiday_cache(holiday_date, name, description, kind, scope_level, state_code, "
      "city_code, source) VALUES(?, ?, ?, ?, ?, ?, ?, ?)"));
  for (const QJsonValue &value : holidays) {
    const QJsonObject holiday = value.toObject();
    const QDate date = QDate::fromString(holiday.value(QStringLiteral("date")).toString(), Qt::ISODate);
    const QString name = holiday.value(QStringLiteral("name")).toString().trimmed();
    if (!date.isValid() || date < from || date > to || name.isEmpty()) {
      rollbackTransaction();
      setError(errorMessage, QStringLiteral("Holiday snapshot contains an invalid or out-of-range event"));
      return false;
    }
    const QList<QVariant> values{
        date.toString(Qt::ISODate),
        name,
        holiday.value(QStringLiteral("description")).toString(),
        holiday.value(QStringLiteral("kind")).toString(),
        holiday.value(QStringLiteral("scope")).toString(),
        holiday.value(QStringLiteral("stateCode")).toString(),
        holiday.value(QStringLiteral("cityCode")).toString(),
        holiday.value(QStringLiteral("source")).toString(),
    };
    for (qsizetype index = 0; index < values.size(); ++index) {
      insertHoliday.bindValue(index, values.at(index));
    }
    if (!insertHoliday.exec()) {
      rollbackTransaction();
      setError(errorMessage,
               queryFailure(QStringLiteral("Cannot cache holiday '%1'").arg(name), insertHoliday));
      return false;
    }
  }

  QSqlQuery removeCoverage(m_database);
  removeCoverage.prepare(QStringLiteral("DELETE FROM holiday_coverage WHERE holiday_year BETWEEN ? AND ?"));
  removeCoverage.addBindValue(from.year());
  removeCoverage.addBindValue(to.year());
  if (!removeCoverage.exec()) {
    rollbackTransaction();
    setError(errorMessage, queryFailure(QStringLiteral("Cannot replace holiday coverage"), removeCoverage));
    return false;
  }
  QSqlQuery insertCoverage(m_database);
  insertCoverage.prepare(
      QStringLiteral("INSERT INTO holiday_coverage(source, holiday_year, status, fetched_at, last_error) "
                     "VALUES(?, ?, ?, ?, ?)"));
  for (const QJsonValue &value : coverage) {
    const QJsonObject item = value.toObject();
    insertCoverage.bindValue(0, item.value(QStringLiteral("source")).toString());
    insertCoverage.bindValue(1, item.value(QStringLiteral("year")).toInt());
    insertCoverage.bindValue(2, item.value(QStringLiteral("status")).toString());
    insertCoverage.bindValue(3, item.value(QStringLiteral("fetchedAt")).toString());
    insertCoverage.bindValue(4, item.value(QStringLiteral("lastError")).toString());
    if (!insertCoverage.exec()) {
      rollbackTransaction();
      setError(errorMessage,
               queryFailure(QStringLiteral("Cannot cache holiday source coverage"), insertCoverage));
      return false;
    }
  }
  if (!commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }
  emit holidaysChanged();
  return true;
}

QJsonArray TaskStore::listMunicipalities(const QString &stateCode, QString *errorMessage) const {
  QJsonArray municipalities;
  QSqlQuery query(m_database);
  query.prepare(
      QStringLiteral("SELECT city_code, name FROM brazil_municipalities WHERE state_code = ? ORDER BY name"));
  query.addBindValue(stateCode.trimmed().toUpper());
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot list cached municipalities"), query));
    return municipalities;
  }
  while (query.next()) {
    municipalities.append(QJsonObject{
        {QStringLiteral("code"), query.value(0).toString()},
        {QStringLiteral("name"), query.value(1).toString()},
    });
  }
  return municipalities;
}

bool TaskStore::replaceMunicipalities(const QString &stateCode, const QJsonArray &municipalities,
                                      QString *errorMessage) {
  const QString normalizedState = stateCode.trimmed().toUpper();
  if (normalizedState.size() != 2) {
    setError(errorMessage, QStringLiteral("Brazilian state code must contain exactly two letters"));
    return false;
  }
  if (!beginTransaction(errorMessage)) {
    return false;
  }
  QSqlQuery remove(m_database);
  remove.prepare(QStringLiteral("DELETE FROM brazil_municipalities WHERE state_code = ?"));
  remove.addBindValue(normalizedState);
  if (!remove.exec()) {
    rollbackTransaction();
    setError(errorMessage, queryFailure(QStringLiteral("Cannot replace municipalities"), remove));
    return false;
  }
  QSqlQuery insert(m_database);
  insert.prepare(
      QStringLiteral("INSERT INTO brazil_municipalities(state_code, city_code, name) VALUES(?, ?, ?)"));
  for (const QJsonValue &value : municipalities) {
    const QJsonObject municipality = value.toObject();
    const QString code = municipality.value(QStringLiteral("code")).toString().trimmed();
    const QString name = municipality.value(QStringLiteral("name")).toString().trimmed();
    if (code.isEmpty() || name.isEmpty()) {
      rollbackTransaction();
      setError(errorMessage, QStringLiteral("Municipality snapshot contains an invalid entry"));
      return false;
    }
    insert.bindValue(0, normalizedState);
    insert.bindValue(1, code);
    insert.bindValue(2, name);
    if (!insert.exec()) {
      rollbackTransaction();
      setError(errorMessage,
               queryFailure(QStringLiteral("Cannot cache municipality '%1'").arg(name), insert));
      return false;
    }
  }
  if (!commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }
  return true;
}

bool TaskStore::applyRemoteChanges(const QJsonArray &changes, const QString &nextCursor,
                                   const QStringList &acceptedMutationIds, QString *errorMessage) {
  if (!beginTransaction(errorMessage)) {
    return false;
  }

  for (const QJsonValue &value : changes) {
    const QJsonObject change = value.toObject();
    const QString entityType = change.value(QStringLiteral("entityType")).toString();
    const QString entityId = change.value(QStringLiteral("entityId")).toString();
    const QString operation = change.value(QStringLiteral("operation")).toString();
    const QJsonObject payload = change.value(QStringLiteral("payload")).toObject();
    if ((entityType != QStringLiteral("task") && entityType != QStringLiteral("occurrence")) ||
        entityId.isEmpty()) {
      rollbackTransaction();
      setError(errorMessage,
               QStringLiteral("Remote change has an invalid entity identity at cursor %1").arg(nextCursor));
      return false;
    }

    QSqlQuery apply(m_database);
    if (entityType == QStringLiteral("task")) {
      const QString taskId = payload.value(QStringLiteral("id")).toString();
      if (taskId != entityId) {
        rollbackTransaction();
        setError(errorMessage,
                 QStringLiteral("Remote task identity does not match entityId %1").arg(entityId));
        return false;
      }
      if (operation == QStringLiteral("delete")) {
        const QString deletedAt = payload.value(QStringLiteral("deletedAt")).toString();
        const qint64 version = payload.value(QStringLiteral("version")).toInteger();
        apply.prepare(QStringLiteral("UPDATE tasks SET deleted_at = ?, updated_at = ?, version = ? "
                                     "WHERE id = ? AND version <= ?"));
        apply.addBindValue(deletedAt);
        apply.addBindValue(deletedAt);
        apply.addBindValue(version);
        apply.addBindValue(taskId);
        apply.addBindValue(version);
      } else {
        const TaskRecord task = TaskRecord::fromJson(payload);
        if (!isValidTaskEmoji(task.emoji)) {
          rollbackTransaction();
          setError(errorMessage, QStringLiteral("Remote task emoji must be empty or contain one grapheme"));
          return false;
        }
        apply.prepare(QStringLiteral(
            "INSERT INTO tasks "
            "(id, title, scheduled_date, completed, created_at, updated_at, version, deleted_at, "
            "recurrence_frequency, recurrence_interval, recurrence_weekdays, "
            "recurrence_end_mode, recurrence_until, recurrence_count, scheduled_time, emoji) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT(id) DO UPDATE SET title=excluded.title, "
            "scheduled_date=excluded.scheduled_date, scheduled_time=excluded.scheduled_time, "
            "emoji=excluded.emoji, completed=excluded.completed, "
            "updated_at=excluded.updated_at, version=excluded.version, deleted_at=NULL, "
            "recurrence_frequency=excluded.recurrence_frequency, "
            "recurrence_interval=excluded.recurrence_interval, "
            "recurrence_weekdays=excluded.recurrence_weekdays, "
            "recurrence_end_mode=excluded.recurrence_end_mode, "
            "recurrence_until=excluded.recurrence_until, "
            "recurrence_count=excluded.recurrence_count "
            "WHERE excluded.version >= tasks.version"));
        apply.addBindValue(task.id);
        apply.addBindValue(task.title);
        apply.addBindValue(task.scheduledDate.isValid() ? task.scheduledDate.toString(Qt::ISODate)
                                                        : QVariant());
        apply.addBindValue(task.completed);
        apply.addBindValue(task.createdAt.toUTC().toString(Qt::ISODateWithMs));
        apply.addBindValue(task.updatedAt.toUTC().toString(Qt::ISODateWithMs));
        apply.addBindValue(task.version);
        addRecurrenceBindValues(apply, task.recurrence);
        apply.addBindValue(task.scheduledTime.isValid() ? task.scheduledTime.toString(QStringLiteral("HH:mm"))
                                                        : QVariant());
        apply.addBindValue(task.emoji);
      }
    } else {
      const TaskOccurrenceState state = TaskOccurrenceState::fromJson(payload);
      if (occurrenceKey(state.taskId, state.occurrenceDate) != entityId) {
        rollbackTransaction();
        setError(errorMessage,
                 QStringLiteral("Remote occurrence identity does not match entityId %1").arg(entityId));
        return false;
      }
      if (operation == QStringLiteral("delete")) {
        apply.prepare(QStringLiteral("DELETE FROM task_occurrence_states "
                                     "WHERE task_id = ? AND occurrence_date = ? AND version <= ?"));
        apply.addBindValue(state.taskId);
        apply.addBindValue(state.occurrenceDate.toString(Qt::ISODate));
        apply.addBindValue(state.version);
      } else {
        QString status = QStringLiteral("pending");
        if (state.status == OccurrenceStatus::Completed) {
          status = QStringLiteral("completed");
        } else if (state.status == OccurrenceStatus::Skipped) {
          status = QStringLiteral("skipped");
        }
        apply.prepare(QStringLiteral("INSERT INTO task_occurrence_states "
                                     "(task_id, occurrence_date, status, completed_at, updated_at, version) "
                                     "VALUES (?, ?, ?, ?, ?, ?) "
                                     "ON CONFLICT(task_id, occurrence_date) DO UPDATE SET "
                                     "status=excluded.status, completed_at=excluded.completed_at, "
                                     "updated_at=excluded.updated_at, version=excluded.version "
                                     "WHERE excluded.version >= task_occurrence_states.version"));
        apply.addBindValue(state.taskId);
        apply.addBindValue(state.occurrenceDate.toString(Qt::ISODate));
        apply.addBindValue(status);
        apply.addBindValue(state.completedAt.isValid() ? state.completedAt.toUTC().toString(Qt::ISODateWithMs)
                                                       : QVariant());
        apply.addBindValue(state.updatedAt.toUTC().toString(Qt::ISODateWithMs));
        apply.addBindValue(state.version);
      }
    }
    if (!apply.exec()) {
      rollbackTransaction();
      setError(errorMessage,
               queryFailure(QStringLiteral("Cannot apply remote entity %1").arg(entityId), apply));
      return false;
    }
  }

  QSqlQuery removeAccepted(m_database);
  removeAccepted.prepare(QStringLiteral("DELETE FROM outbox WHERE mutation_id = ?"));
  for (const QString &mutationId : acceptedMutationIds) {
    removeAccepted.bindValue(0, mutationId);
    if (!removeAccepted.exec()) {
      rollbackTransaction();
      setError(errorMessage, queryFailure(QStringLiteral("Cannot acknowledge mutation %1").arg(mutationId),
                                          removeAccepted));
      return false;
    }
  }

  QSqlQuery cursor(m_database);
  cursor.prepare(QStringLiteral("INSERT INTO sync_state(key, value) VALUES('cursor', ?) "
                                "ON CONFLICT(key) DO UPDATE SET value=excluded.value"));
  cursor.addBindValue(nextCursor);
  if (!cursor.exec()) {
    rollbackTransaction();
    setError(errorMessage,
             queryFailure(QStringLiteral("Cannot persist sync cursor %1").arg(nextCursor), cursor));
    return false;
  }
  if (!commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }
  if (!changes.isEmpty()) {
    emit tasksChanged();
  }
  return true;
}

bool TaskStore::beginTransaction(QString *errorMessage) {
  if (m_database.transaction()) {
    return true;
  }
  setError(errorMessage,
           QStringLiteral("Cannot begin SQLite transaction: %1").arg(m_database.lastError().text()));
  return false;
}

bool TaskStore::commitTransaction(QString *errorMessage) {
  if (m_database.commit()) {
    return true;
  }
  setError(errorMessage,
           QStringLiteral("Cannot commit SQLite transaction: %1").arg(m_database.lastError().text()));
  return false;
}

void TaskStore::rollbackTransaction() { m_database.rollback(); }

} // namespace waypoint

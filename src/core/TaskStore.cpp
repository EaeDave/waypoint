#include "core/TaskStore.hpp"

#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
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
  return task;
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
          "deleted_at TEXT)"),
      QStringLiteral("CREATE INDEX IF NOT EXISTS tasks_schedule_idx "
                     "ON tasks(scheduled_date, completed) WHERE deleted_at IS NULL"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS outbox ("
                     "mutation_id TEXT PRIMARY KEY, task_id TEXT NOT NULL, operation TEXT NOT NULL, "
                     "payload_json TEXT NOT NULL, created_at TEXT NOT NULL)"),
      QStringLiteral("CREATE TABLE IF NOT EXISTS sync_state ("
                     "key TEXT PRIMARY KEY, value TEXT NOT NULL)"),
  };

  for (const QString &statement : statements) {
    QSqlQuery query(m_database);
    if (!query.exec(statement)) {
      setError(errorMessage, queryFailure(QStringLiteral("Cannot migrate Waypoint database"), query));
      return false;
    }
  }
  return true;
}

QList<TaskRecord> TaskStore::listActiveTasks(QString *errorMessage) const {
  QList<TaskRecord> tasks;
  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("SELECT id, title, scheduled_date, completed, created_at, updated_at, version "
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

bool TaskStore::createTask(const QString &title, const QDate &scheduledDate, TaskRecord *createdTask,
                           QString *errorMessage) {
  const QString normalizedTitle = title.trimmed();
  if (normalizedTitle.isEmpty()) {
    setError(errorMessage, QStringLiteral("Task title must contain at least one visible character"));
    return false;
  }

  TaskRecord task;
  task.id = newIdentifier();
  task.title = normalizedTitle;
  task.scheduledDate = scheduledDate;
  task.createdAt = QDateTime::currentDateTimeUtc();
  task.updatedAt = task.createdAt;
  task.version = 1;

  if (!beginTransaction(errorMessage)) {
    return false;
  }

  QSqlQuery query(m_database);
  query.prepare(QStringLiteral("INSERT INTO tasks "
                               "(id, title, scheduled_date, completed, created_at, updated_at, version) "
                               "VALUES (?, ?, ?, 0, ?, ?, ?)"));
  query.addBindValue(task.id);
  query.addBindValue(task.title);
  query.addBindValue(task.scheduledDate.isValid() ? task.scheduledDate.toString(Qt::ISODate) : QVariant());
  query.addBindValue(task.createdAt.toString(Qt::ISODateWithMs));
  query.addBindValue(task.updatedAt.toString(Qt::ISODateWithMs));
  query.addBindValue(task.version);
  if (!query.exec()) {
    rollbackTransaction();
    setError(errorMessage,
             queryFailure(QStringLiteral("Cannot create task '%1'").arg(normalizedTitle), query));
    return false;
  }

  const QString mutationId = newIdentifier();
  if (!enqueueMutation(mutationId, task.id, QStringLiteral("upsert"), task.toJson(), errorMessage) ||
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

bool TaskStore::rescheduleTask(const QString &taskId, const QDate &scheduledDate, QString *errorMessage) {
  if (!scheduledDate.isValid()) {
    setError(errorMessage,
             QStringLiteral("Cannot reschedule task %1: expected an ISO calendar date").arg(taskId));
    return false;
  }
  return mutateTask(taskId, QStringLiteral("upsert"),
                    {{QStringLiteral("scheduledDate"), scheduledDate.toString(Qt::ISODate)}}, errorMessage);
}

bool TaskStore::mutateTask(const QString &taskId, const QString &operation, const QJsonObject &fields,
                           QString *errorMessage) {
  QSqlQuery select(m_database);
  select.prepare(
      QStringLiteral("SELECT id, title, scheduled_date, completed, created_at, updated_at, version "
                     "FROM tasks WHERE id = ? AND deleted_at IS NULL"));
  select.addBindValue(taskId);
  if (!select.exec() || !select.next()) {
    setError(errorMessage, select.lastError().isValid()
                               ? queryFailure(QStringLiteral("Cannot read task %1").arg(taskId), select)
                               : QStringLiteral("Cannot mutate missing task: %1").arg(taskId));
    return false;
  }

  TaskRecord task = taskFromQuery(select);
  if (fields.contains(QStringLiteral("completed"))) {
    task.completed = fields.value(QStringLiteral("completed")).toBool();
  }
  if (fields.contains(QStringLiteral("scheduledDate"))) {
    task.scheduledDate =
        QDate::fromString(fields.value(QStringLiteral("scheduledDate")).toString(), Qt::ISODate);
  }
  task.updatedAt = QDateTime::currentDateTimeUtc();
  ++task.version;

  if (!beginTransaction(errorMessage)) {
    return false;
  }
  QSqlQuery update(m_database);
  update.prepare(
      QStringLiteral("UPDATE tasks SET scheduled_date = ?, completed = ?, updated_at = ?, version = ? "
                     "WHERE id = ? AND deleted_at IS NULL"));
  update.addBindValue(task.scheduledDate.isValid() ? task.scheduledDate.toString(Qt::ISODate) : QVariant());
  update.addBindValue(task.completed);
  update.addBindValue(task.updatedAt.toString(Qt::ISODateWithMs));
  update.addBindValue(task.version);
  update.addBindValue(task.id);
  if (!update.exec()) {
    rollbackTransaction();
    setError(errorMessage, queryFailure(QStringLiteral("Cannot update task %1").arg(taskId), update));
    return false;
  }

  if (!enqueueMutation(newIdentifier(), task.id, operation, task.toJson(), errorMessage) ||
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

  if (!enqueueMutation(newIdentifier(), taskId, QStringLiteral("delete"), tombstone, errorMessage) ||
      !commitTransaction(errorMessage)) {
    rollbackTransaction();
    return false;
  }
  emit tasksChanged();
  return true;
}

bool TaskStore::enqueueMutation(const QString &mutationId, const QString &taskId, const QString &operation,
                                const QJsonObject &task, QString *errorMessage) {
  QSqlQuery query(m_database);
  query.prepare(
      QStringLiteral("INSERT INTO outbox "
                     "(mutation_id, task_id, operation, payload_json, created_at) VALUES (?, ?, ?, ?, ?)"));
  query.addBindValue(mutationId);
  query.addBindValue(taskId);
  query.addBindValue(operation);
  query.addBindValue(encodeJson(task));
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
  query.prepare(
      QStringLiteral("SELECT mutation_id, task_id, operation, payload_json FROM outbox ORDER BY created_at"));
  if (!query.exec()) {
    setError(errorMessage, queryFailure(QStringLiteral("Cannot list sync outbox"), query));
    return mutations;
  }
  while (query.next()) {
    QJsonParseError parseError;
    const QJsonDocument payload = QJsonDocument::fromJson(query.value(3).toByteArray(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !payload.isObject()) {
      setError(errorMessage, QStringLiteral("Invalid outbox payload for mutation %1: %2")
                                 .arg(query.value(0).toString(), parseError.errorString()));
      return {};
    }
    mutations.append(QJsonObject{
        {QStringLiteral("mutationId"), query.value(0).toString()},
        {QStringLiteral("taskId"), query.value(1).toString()},
        {QStringLiteral("operation"), query.value(2).toString()},
        {QStringLiteral("task"), payload.object()},
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

bool TaskStore::applyRemoteChanges(const QJsonArray &changes, const QString &nextCursor,
                                   const QStringList &acceptedMutationIds, QString *errorMessage) {
  if (!beginTransaction(errorMessage)) {
    return false;
  }

  for (const QJsonValue &value : changes) {
    const QJsonObject change = value.toObject();
    const QJsonObject taskJson = change.value(QStringLiteral("task")).toObject();
    const QString taskId = taskJson.value(QStringLiteral("id")).toString();
    if (taskId.isEmpty()) {
      rollbackTransaction();
      setError(errorMessage, QStringLiteral("Remote change is missing task.id at cursor %1").arg(nextCursor));
      return false;
    }

    QSqlQuery upsert(m_database);
    if (change.value(QStringLiteral("operation")).toString() == QStringLiteral("delete")) {
      upsert.prepare(QStringLiteral("UPDATE tasks SET deleted_at = ?, updated_at = ?, version = ? "
                                    "WHERE id = ? AND version <= ?"));
      const QString deletedAt = taskJson.value(QStringLiteral("deletedAt")).toString();
      const qint64 version = taskJson.value(QStringLiteral("version")).toInteger();
      upsert.addBindValue(deletedAt);
      upsert.addBindValue(deletedAt);
      upsert.addBindValue(version);
      upsert.addBindValue(taskId);
      upsert.addBindValue(version);
    } else {
      const TaskRecord task = TaskRecord::fromJson(taskJson);
      upsert.prepare(QStringLiteral(
          "INSERT INTO tasks "
          "(id, title, scheduled_date, completed, created_at, updated_at, version, deleted_at) "
          "VALUES (?, ?, ?, ?, ?, ?, ?, NULL) "
          "ON CONFLICT(id) DO UPDATE SET title=excluded.title, "
          "scheduled_date=excluded.scheduled_date, completed=excluded.completed, "
          "updated_at=excluded.updated_at, version=excluded.version, deleted_at=NULL "
          "WHERE excluded.version >= tasks.version"));
      upsert.addBindValue(task.id);
      upsert.addBindValue(task.title);
      upsert.addBindValue(task.scheduledDate.isValid() ? task.scheduledDate.toString(Qt::ISODate)
                                                       : QVariant());
      upsert.addBindValue(task.completed);
      upsert.addBindValue(task.createdAt.toUTC().toString(Qt::ISODateWithMs));
      upsert.addBindValue(task.updatedAt.toUTC().toString(Qt::ISODateWithMs));
      upsert.addBindValue(task.version);
    }
    if (!upsert.exec()) {
      rollbackTransaction();
      setError(errorMessage, queryFailure(QStringLiteral("Cannot apply remote task %1").arg(taskId), upsert));
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
  emit tasksChanged();
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

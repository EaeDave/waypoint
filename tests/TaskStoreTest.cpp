#include "core/TaskStore.hpp"

#include <QJsonArray>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>

#include <optional>

class TaskStoreTest final : public QObject {
  Q_OBJECT

private slots:
  void createCompleteAndRescheduleTask();
  void editTaskTitleAndTimeAtomically();
  void persistFiveReminderOffsetsAndRejectInvalidLists();
  void persistCompoundEmojiAcrossStorageAndSync();
  void rejectInvisibleTitle();
  void preserveFloatingCalendarDate();
  void persistSyncConfiguration();
  void cacheHolidaySnapshotAtomically();
  void persistHolidayPreferencesAndMunicipalities();
  void persistRecurrenceAndOccurrenceState();
  void migrateLegacyTaskRowsAndOutbox();
  void applyRemoteOccurrenceChangesIdempotently();
  void applyRecurrenceDeletionScopes();
};

void TaskStoreTest::createCompleteAndRescheduleTask() {
  QTemporaryDir directory;
  QVERIFY(directory.isValid());
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::TaskRecord created;
  QVERIFY2(store.createTask(QStringLiteral("  Revisar calendário  "), QDate(2026, 9, 1), QTime(9, 30), {},
                            QList<int>{0}, {}, &created, &error),
           qPrintable(error));
  QCOMPARE(created.title, QStringLiteral("Revisar calendário"));
  QCOMPARE(created.scheduledDate, QDate(2026, 9, 1));
  QCOMPARE(created.scheduledTime, QTime(9, 30));

  QVERIFY2(store.setTaskCompleted(created.id, true, &error), qPrintable(error));
  QVERIFY2(store.rescheduleTask(created.id, QDate(2026, 9, 2), QTime(11, 45), &error), qPrintable(error));

  const QList<waypoint::TaskRecord> tasks = store.listActiveTasks(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(tasks.size(), 1);
  QCOMPARE(tasks.first().scheduledDate, QDate(2026, 9, 2));
  QCOMPARE(tasks.first().scheduledTime, QTime(11, 45));
  QVERIFY(tasks.first().completed);
  QCOMPARE(tasks.first().version, 3);
  const QJsonArray mutations = store.pendingMutations(&error);
  QCOMPARE(mutations.size(), 3);
  QCOMPARE(mutations.last()
               .toObject()
               .value(QStringLiteral("payload"))
               .toObject()
               .value(QStringLiteral("scheduledTime"))
               .toString(),
           QStringLiteral("11:45"));
}
void TaskStoreTest::editTaskTitleAndTimeAtomically() {
  QTemporaryDir directory;
  QVERIFY(directory.isValid());
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::TaskRecord created;
  QVERIFY2(store.createTask(QStringLiteral("Teste"), QDate(2026, 9, 1), QTime(17, 38), {}, QList<int>{0}, {},
                            &created, &error),
           qPrintable(error));
  waypoint::RecurrenceRule recurrence;
  recurrence.frequency = waypoint::RecurrenceFrequency::Weekly;
  recurrence.interval = 2;
  recurrence.weekdays = {1, 3};
  recurrence.endMode = waypoint::RecurrenceEndMode::AfterCount;
  recurrence.occurrenceCount = 5;
  QVERIFY2(store.editTask(created.id, QStringLiteral("  Teste editado  "), QTime(18, 25), recurrence,
                          QList<int>{0}, {}, &error),
           qPrintable(error));
  const QList<waypoint::TaskRecord> tasks = store.listActiveTasks(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(tasks.size(), 1);
  QCOMPARE(tasks.first().title, QStringLiteral("Teste editado"));
  QCOMPARE(tasks.first().scheduledDate, QDate(2026, 9, 1));
  QCOMPARE(tasks.first().scheduledTime, QTime(18, 25));
  QCOMPARE(tasks.first().version, 2);
  QCOMPARE(tasks.first().recurrence.frequency, waypoint::RecurrenceFrequency::Weekly);
  QCOMPARE(tasks.first().recurrence.interval, 2);
  QCOMPARE(tasks.first().recurrence.weekdays, QList<int>({1, 3}));
  QCOMPARE(tasks.first().recurrence.endMode, waypoint::RecurrenceEndMode::AfterCount);
  QCOMPARE(tasks.first().recurrence.occurrenceCount, 5);

  const QJsonObject payload =
      store.pendingMutations(&error).last().toObject().value(QStringLiteral("payload")).toObject();
  QCOMPARE(payload.value(QStringLiteral("title")).toString(), QStringLiteral("Teste editado"));
  QCOMPARE(payload.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("18:25"));
  const QJsonObject payloadRecurrence = payload.value(QStringLiteral("recurrence")).toObject();
  QCOMPARE(payloadRecurrence.value(QStringLiteral("frequency")).toString(), QStringLiteral("weekly"));
  QCOMPARE(payloadRecurrence.value(QStringLiteral("interval")).toInt(), 2);
  QCOMPARE(payloadRecurrence.value(QStringLiteral("endMode")).toString(), QStringLiteral("afterCount"));
  QCOMPARE(payloadRecurrence.value(QStringLiteral("occurrenceCount")).toInt(), 5);

  QVERIFY(!store.editTask(created.id, QStringLiteral(" \t "), QTime(19, 0), recurrence, QList<int>{0}, {},
                          &error));
  QVERIFY(error.contains(QStringLiteral("visible character")));
  const waypoint::TaskRecord unchanged = store.listActiveTasks().first();
  QCOMPARE(unchanged.title, QStringLiteral("Teste editado"));
  QCOMPARE(unchanged.scheduledTime, QTime(18, 25));
}

void TaskStoreTest::persistFiveReminderOffsetsAndRejectInvalidLists() {
  QTemporaryDir directory;
  const QString path = directory.filePath(QStringLiteral("tasks.sqlite3"));
  QString error;
  QString taskId;
  const QList<int> reminders{300, 180, 60, 30, 0};

  {
    waypoint::TaskStore store(path);
    QVERIFY2(store.open(&error), qPrintable(error));
    waypoint::TaskRecord created;
    QVERIFY2(store.createTask(QStringLiteral("Preparar viagem"), QDate(2026, 9, 2), QTime(9, 0), {},
                              reminders, {}, &created, &error),
             qPrintable(error));
    taskId = created.id;
    QCOMPARE(created.reminderMinutesBefore, reminders);
    QCOMPARE(
        store.listOccurrences(QDate(2026, 9, 2), QDate(2026, 9, 2), &error).first().reminderMinutesBefore,
        reminders);
    const QJsonObject payload =
        store.pendingMutations(&error).first().toObject().value(QStringLiteral("payload")).toObject();
    QCOMPARE(payload.value(QStringLiteral("reminderMinutesBefore")).toArray(),
             QJsonArray({300, 180, 60, 30, 0}));

    QVERIFY(!store.createTask(QStringLiteral("Muitos lembretes"), QDate(2026, 9, 2), QTime(9, 0), {},
                              QList<int>{360, 300, 180, 60, 30, 0}, {}, nullptr, &error));
    QVERIFY(error.contains(QStringLiteral("at most 5")));
    QVERIFY(!store.editTask(taskId, QStringLiteral("Preparar viagem"), QTime(9, 0), {}, QList<int>{30, 30},
                            {}, &error));
    QVERIFY(error.contains(QStringLiteral("duplicate")));
    QVERIFY(!store.editTask(taskId, QStringLiteral("Preparar viagem"), QTime(9, 0), {}, QList<int>{-1}, {},
                            &error));
    QVERIFY(error.contains(QStringLiteral("non-negative")));
  }

  waypoint::TaskStore reopened(path);
  QVERIFY2(reopened.open(&error), qPrintable(error));
  QCOMPARE(reopened.listActiveTasks(&error).first().reminderMinutesBefore, reminders);
  QVERIFY2(
      reopened.editTask(taskId, QStringLiteral("Preparar viagem"), QTime(9, 0), {}, std::nullopt, {}, &error),
      qPrintable(error));
  QCOMPARE(reopened.listActiveTasks(&error).first().reminderMinutesBefore, reminders);
  QVERIFY2(
      reopened.editTask(taskId, QStringLiteral("Preparar viagem"), QTime(9, 0), {}, QList<int>{}, {}, &error),
      qPrintable(error));
  QVERIFY(reopened.listActiveTasks(&error).first().reminderMinutesBefore.isEmpty());
}

void TaskStoreTest::persistCompoundEmojiAcrossStorageAndSync() {
  QTemporaryDir directory;
  QVERIFY(directory.isValid());
  const QString path = directory.filePath(QStringLiteral("tasks.sqlite3"));
  const QString compoundEmoji = QStringLiteral("👨‍💻");
  QString taskId;
  QString error;

  {
    waypoint::TaskStore store(path);
    QVERIFY2(store.open(&error), qPrintable(error));
    waypoint::TaskRecord created;
    QVERIFY2(store.createTask(QStringLiteral("Programar"), QDate(2026, 9, 1), QTime(9, 30), {}, QList<int>{0},
                              compoundEmoji, &created, &error),
             qPrintable(error));
    taskId = created.id;
    QCOMPARE(created.emoji, compoundEmoji);
    QCOMPARE(store.listOccurrences(QDate(2026, 9, 1), QDate(2026, 9, 1), &error).first().emoji,
             compoundEmoji);
    const QJsonObject payload =
        store.pendingMutations(&error).last().toObject().value(QStringLiteral("payload")).toObject();
    QCOMPARE(payload.value(QStringLiteral("emoji")).toString(), compoundEmoji);
  }

  waypoint::TaskStore reopened(path);
  QVERIFY2(reopened.open(&error), qPrintable(error));
  QCOMPARE(reopened.listActiveTasks(&error).first().emoji, compoundEmoji);

  const QString flagEmoji = QStringLiteral("🇧🇷");
  QVERIFY2(reopened.editTask(taskId, QStringLiteral("Programar"), QTime(10, 0), {}, QList<int>{0}, flagEmoji,
                             &error),
           qPrintable(error));
  QCOMPARE(reopened.listActiveTasks(&error).first().emoji, flagEmoji);
  QVERIFY(!reopened.editTask(taskId, QStringLiteral("Programar"), QTime(10, 0), {}, QList<int>{0},
                             QStringLiteral("😀🚀"), &error));
  QVERIFY(error.contains(QStringLiteral("one grapheme")));
  QCOMPARE(reopened.listActiveTasks().first().emoji, flagEmoji);
}

void TaskStoreTest::rejectInvisibleTitle() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  QVERIFY(!store.createTask(QStringLiteral("   \t"), QDate::currentDate(), {}, {}, QList<int>{0}, {}, nullptr,
                            &error));
  QVERIFY(error.contains(QStringLiteral("visible character")));
  QCOMPARE(store.listActiveTasks().size(), 0);
}

void TaskStoreTest::preserveFloatingCalendarDate() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  const QDate expectedDate(2026, 9, 1);
  const QTime before = QTime(QTime::currentTime().hour(), QTime::currentTime().minute());
  QVERIFY2(store.createTask(QStringLiteral("Data flutuante"), expectedDate, {}, {}, QList<int>{0}, {},
                            nullptr, &error),
           qPrintable(error));
  const QTime after = QTime(QTime::currentTime().hour(), QTime::currentTime().minute());
  const waypoint::TaskRecord stored = store.listActiveTasks(&error).first();
  QCOMPARE(stored.scheduledDate, expectedDate);
  QVERIFY(stored.scheduledTime == before || stored.scheduledTime == after);
}

void TaskStoreTest::persistRecurrenceAndOccurrenceState() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::RecurrenceRule recurrence;
  recurrence.frequency = waypoint::RecurrenceFrequency::Daily;
  recurrence.interval = 1;
  waypoint::TaskRecord created;
  QVERIFY2(store.createTask(QStringLiteral("Caminhar"), QDate(2026, 1, 1), QTime(7, 15), recurrence,
                            QList<int>{0}, {}, &created, &error),
           qPrintable(error));

  const auto tasks = store.listActiveTasks(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(tasks.size(), 1);
  QCOMPARE(tasks.first().recurrence.frequency, waypoint::RecurrenceFrequency::Daily);
  QCOMPARE(tasks.first().scheduledTime, QTime(7, 15));
  QCOMPARE(store.listOccurrences(QDate(2026, 1, 1), QDate(2026, 1, 3), &error).size(), 3);

  QVERIFY2(store.setOccurrenceCompleted(created.id, QDate(2026, 1, 2), true, &error), qPrintable(error));
  auto states = store.listOccurrenceStates(&error);
  QCOMPARE(states.size(), 1);
  QCOMPARE(states.first().occurrenceDate, QDate(2026, 1, 2));
  QCOMPARE(states.first().status, waypoint::OccurrenceStatus::Completed);

  QVERIFY2(store.setOccurrenceCompleted(created.id, QDate(2026, 1, 2), false, &error), qPrintable(error));
  states = store.listOccurrenceStates(&error);
  QCOMPARE(states.size(), 1);
  QCOMPARE(states.first().status, waypoint::OccurrenceStatus::Pending);
  QCOMPARE(states.first().version, 2);

  const QJsonArray mutations = store.pendingMutations(&error);
  QCOMPARE(mutations.size(), 3);
  QCOMPARE(mutations.at(0).toObject().value(QStringLiteral("entityType")).toString(), QStringLiteral("task"));
  QCOMPARE(mutations.at(1).toObject().value(QStringLiteral("entityType")).toString(),
           QStringLiteral("occurrence"));
}

void TaskStoreTest::migrateLegacyTaskRowsAndOutbox() {
  QTemporaryDir directory;
  const QString path = directory.filePath(QStringLiteral("legacy.sqlite3"));
  const QString connection = QStringLiteral("legacy-setup");
  {
    QSqlDatabase database = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connection);
    database.setDatabaseName(path);
    QVERIFY(database.open());
    QSqlQuery query(database);
    QVERIFY(query.exec(
        QStringLiteral("CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, scheduled_date TEXT, "
                       "completed INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL, "
                       "updated_at TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1, deleted_at TEXT)")));
    QVERIFY(query.exec(QStringLiteral("INSERT INTO tasks VALUES "
                                      "('legacy-task', 'Legado', '2026-09-01', 0, "
                                      "'2026-08-01T00:00:00.000Z', '2026-08-01T00:00:00.000Z', 1, NULL)")));
    QVERIFY(query.exec(
        QStringLiteral("CREATE TABLE outbox (mutation_id TEXT PRIMARY KEY, task_id TEXT NOT NULL, "
                       "operation TEXT NOT NULL, payload_json TEXT NOT NULL, created_at TEXT NOT NULL)")));
    QVERIFY(query.exec(
        QStringLiteral("INSERT INTO outbox VALUES "
                       "('legacy-mutation', 'legacy-task', 'upsert', "
                       "'{\"id\":\"legacy-task\",\"title\":\"Legado\",\"scheduledDate\":\"2026-09-01\"}', "
                       "'2026-08-01T00:00:00.000Z')")));
    QVERIFY(query.exec(QStringLiteral(
        "CREATE TABLE reminder_deliveries ("
        "task_id TEXT NOT NULL, occurrence_date TEXT NOT NULL, scheduled_time TEXT NOT NULL, "
        "delivered_at TEXT NOT NULL, PRIMARY KEY(task_id, occurrence_date, scheduled_time))")));
    QVERIFY(query.exec(QStringLiteral("INSERT INTO reminder_deliveries VALUES "
                                      "('legacy-task', '2026-09-01', '09:00', '2026-09-01T09:00:00.000Z')")));
    database.close();
  }
  QSqlDatabase::removeDatabase(connection);

  waypoint::TaskStore store(path);
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  const auto tasks = store.listActiveTasks(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(tasks.size(), 1);
  QCOMPARE(tasks.first().id, QStringLiteral("legacy-task"));
  QVERIFY(!tasks.first().recurrence.isRecurring());
  QVERIFY(!tasks.first().scheduledTime.isValid());
  QVERIFY(tasks.first().emoji.isEmpty());
  QCOMPARE(tasks.first().reminderMinutesBefore, QList<int>({0}));
  bool claimed = true;
  QVERIFY2(store.claimReminderDelivery(QStringLiteral("legacy-task"), QDate(2026, 9, 1), 0, &claimed, &error),
           qPrintable(error));
  QVERIFY(!claimed);
  QVERIFY2(
      store.claimReminderDelivery(QStringLiteral("legacy-task"), QDate(2026, 9, 1), 30, &claimed, &error),
      qPrintable(error));
  QVERIFY(claimed);

  const QJsonArray mutations = store.pendingMutations(&error);
  QCOMPARE(mutations.size(), 1);
  QCOMPARE(mutations.first().toObject().value(QStringLiteral("entityType")).toString(),
           QStringLiteral("task"));
  QCOMPARE(mutations.first().toObject().value(QStringLiteral("entityId")).toString(),
           QStringLiteral("legacy-task"));
}

void TaskStoreTest::applyRemoteOccurrenceChangesIdempotently() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::RecurrenceRule recurrence;
  recurrence.frequency = waypoint::RecurrenceFrequency::Daily;
  waypoint::TaskRecord task;
  QVERIFY2(store.createTask(QStringLiteral("Sincronizar"), QDate(2026, 1, 1), QTime(8, 0), recurrence,
                            QList<int>{0}, {}, &task, &error),
           qPrintable(error));
  const QString acceptedTaskMutation =
      store.pendingMutations(&error).first().toObject().value(QStringLiteral("mutationId")).toString();
  waypoint::TaskRecord remoteTask = task;
  remoteTask.scheduledTime = QTime(9, 30);
  remoteTask.emoji = QStringLiteral("🧠");
  remoteTask.version = 2;
  remoteTask.updatedAt = remoteTask.updatedAt.addSecs(1);
  const QJsonObject taskChange{
      {QStringLiteral("entityType"), QStringLiteral("task")},
      {QStringLiteral("entityId"), task.id},
      {QStringLiteral("operation"), QStringLiteral("upsert")},
      {QStringLiteral("payload"), remoteTask.toJson()},
  };

  const auto occurrenceChange = [&task](const QDate &date, const QString &status, const qint64 version) {
    const QString dateKey = date.toString(Qt::ISODate);
    return QJsonObject{
        {QStringLiteral("entityType"), QStringLiteral("occurrence")},
        {QStringLiteral("entityId"), waypoint::occurrenceKey(task.id, date)},
        {QStringLiteral("operation"), QStringLiteral("upsert")},
        {QStringLiteral("payload"),
         QJsonObject{{QStringLiteral("taskId"), task.id},
                     {QStringLiteral("occurrenceDate"), dateKey},
                     {QStringLiteral("status"), status},
                     {QStringLiteral("completedAt"), status == QStringLiteral("completed")
                                                         ? QStringLiteral("2026-01-02T12:00:00.000Z")
                                                         : QString()},
                     {QStringLiteral("updatedAt"), QStringLiteral("2026-01-02T12:00:00.000Z")},
                     {QStringLiteral("version"), version}}},
    };
  };

  QVERIFY2(store.applyRemoteChanges({taskChange,
                                     occurrenceChange(QDate(2026, 1, 2), QStringLiteral("completed"), 5),
                                     occurrenceChange(QDate(2026, 1, 3), QStringLiteral("pending"), 1)},
                                    QStringLiteral("2"), {acceptedTaskMutation}, &error),
           qPrintable(error));
  QCOMPARE(store.listOccurrenceStates(&error).size(), 2);
  QCOMPARE(store.pendingMutations(&error).size(), 0);
  QCOMPARE(store.listActiveTasks(&error).first().scheduledTime, QTime(9, 30));
  QCOMPARE(store.listActiveTasks(&error).first().emoji, QStringLiteral("🧠"));

  QVERIFY2(store.applyRemoteChanges({occurrenceChange(QDate(2026, 1, 2), QStringLiteral("skipped"), 4),
                                     occurrenceChange(QDate(2026, 1, 3), QStringLiteral("completed"), 2)},
                                    QStringLiteral("4"), {}, &error),
           qPrintable(error));
  const auto states = store.listOccurrenceStates(&error);
  QCOMPARE(states.size(), 2);
  QCOMPARE(states.at(0).occurrenceDate, QDate(2026, 1, 2));
  QCOMPARE(states.at(0).status, waypoint::OccurrenceStatus::Completed);
  QCOMPARE(states.at(0).version, 5);
  QCOMPARE(states.at(1).occurrenceDate, QDate(2026, 1, 3));
  QCOMPARE(states.at(1).status, waypoint::OccurrenceStatus::Completed);
  QCOMPARE(states.at(1).version, 2);

  QVERIFY2(store.applyRemoteChanges({occurrenceChange(QDate(2026, 1, 2), QStringLiteral("completed"), 5),
                                     occurrenceChange(QDate(2026, 1, 3), QStringLiteral("completed"), 2)},
                                    QStringLiteral("6"), {}, &error),
           qPrintable(error));
  QCOMPARE(store.listOccurrenceStates(&error).size(), 2);

  QSignalSpy tasksChanged(&store, &waypoint::TaskStore::tasksChanged);
  QVERIFY2(store.applyRemoteChanges({}, QStringLiteral("6"), {}, &error), qPrintable(error));
  QCOMPARE(tasksChanged.count(), 0);
}

void TaskStoreTest::applyRecurrenceDeletionScopes() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::RecurrenceRule recurrence;
  recurrence.frequency = waypoint::RecurrenceFrequency::Daily;
  waypoint::TaskRecord task;
  QVERIFY2(store.createTask(QStringLiteral("Escopo"), QDate(2026, 1, 1), QTime(8, 0), recurrence,
                            QList<int>{0}, {}, &task, &error),
           qPrintable(error));
  QVERIFY2(
      store.deleteOccurrence(task.id, QDate(2026, 1, 2), waypoint::RecurrenceEditScope::Occurrence, &error),
      qPrintable(error));
  auto occurrences = store.listOccurrences(QDate(2026, 1, 1), QDate(2026, 1, 4), &error);
  QCOMPARE(occurrences.size(), 3);
  QCOMPARE(occurrences.at(0).occurrenceDate, QDate(2026, 1, 1));
  QCOMPARE(occurrences.at(1).occurrenceDate, QDate(2026, 1, 3));

  QVERIFY2(
      store.deleteOccurrence(task.id, QDate(2026, 1, 3), waypoint::RecurrenceEditScope::Following, &error),
      qPrintable(error));
  occurrences = store.listOccurrences(QDate(2026, 1, 1), QDate(2026, 1, 5), &error);
  QCOMPARE(occurrences.size(), 1);
  QCOMPARE(occurrences.first().occurrenceDate, QDate(2026, 1, 1));
  QCOMPARE(store.listActiveTasks(&error).first().recurrence.untilDate, QDate(2026, 1, 2));
}

void TaskStoreTest::persistSyncConfiguration() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::SyncConfiguration expected{
      QUrl(QStringLiteral("https://waypoint.example/v1/sync")),
      QByteArrayLiteral("personal-access-token"),
  };
  QVERIFY2(store.saveSyncConfiguration(expected, &error), qPrintable(error));

  const waypoint::SyncConfiguration loaded = store.syncConfiguration(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(loaded.endpoint, expected.endpoint);
  QCOMPARE(loaded.token, expected.token);
  QVERIFY(loaded.enabled());

  QVERIFY2(store.saveSyncConfiguration({}, &error), qPrintable(error));
  const waypoint::SyncConfiguration disabled = store.syncConfiguration(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QVERIFY(!disabled.enabled());
  QVERIFY(disabled.endpoint.isEmpty());
  QVERIFY(disabled.token.isEmpty());
}

void TaskStoreTest::cacheHolidaySnapshotAtomically() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  const QDate from(2026, 1, 1);
  const QDate to(2026, 12, 31);
  const QJsonArray holidays{
      QJsonObject{{QStringLiteral("date"), QStringLiteral("2026-04-21")},
                  {QStringLiteral("name"), QStringLiteral("Tiradentes")},
                  {QStringLiteral("kind"), QStringLiteral("legal")},
                  {QStringLiteral("scope"), QStringLiteral("national")},
                  {QStringLiteral("source"), QStringLiteral("feriados-brasil/nacional")}},
      QJsonObject{{QStringLiteral("date"), QStringLiteral("2026-04-21")},
                  {QStringLiteral("name"), QStringLiteral("Aniversário municipal")},
                  {QStringLiteral("kind"), QStringLiteral("legal")},
                  {QStringLiteral("scope"), QStringLiteral("municipal")},
                  {QStringLiteral("cityCode"), QStringLiteral("3550308")},
                  {QStringLiteral("source"), QStringLiteral("feriados-brasil/municipal")}},
  };
  const QJsonArray coverage{
      QJsonObject{{QStringLiteral("source"), QStringLiteral("feriados-brasil/nacional")},
                  {QStringLiteral("year"), 2026},
                  {QStringLiteral("status"), QStringLiteral("ready")}},
  };
  QVERIFY2(store.replaceHolidaySnapshot(from, to, holidays, coverage, &error), qPrintable(error));
  QCOMPARE(store.listHolidays(QDate(2026, 4, 21), QDate(2026, 4, 21), &error).size(), 2);

  const QJsonArray invalid{
      QJsonObject{{QStringLiteral("date"), QStringLiteral("2027-01-01")},
                  {QStringLiteral("name"), QStringLiteral("Out of range")}},
  };
  QVERIFY(!store.replaceHolidaySnapshot(from, to, invalid, {}, &error));
  QCOMPARE(store.listHolidays(QDate(2026, 4, 21), QDate(2026, 4, 21)).size(), 2);
}

void TaskStoreTest::persistHolidayPreferencesAndMunicipalities() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  QJsonObject preferences = store.holidayPreferences(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QVERIFY(preferences.value(QStringLiteral("includeNational")).toBool());
  QVERIFY(!preferences.value(QStringLiteral("includeCommemorative")).toBool());
  QVERIFY(preferences.value(QStringLiteral("includeOptional")).toBool());

  preferences.insert(QStringLiteral("stateCode"), QStringLiteral(" sp "));
  preferences.insert(QStringLiteral("cityCode"), QStringLiteral("3550308"));
  preferences.insert(QStringLiteral("includeCommemorative"), true);
  preferences.insert(QStringLiteral("includeOptional"), false);
  QVERIFY2(store.saveHolidayPreferences(preferences, &error), qPrintable(error));
  const QJsonObject loaded = store.holidayPreferences(&error);
  QCOMPARE(loaded.value(QStringLiteral("stateCode")).toString(), QStringLiteral("SP"));
  QCOMPARE(loaded.value(QStringLiteral("cityCode")).toString(), QStringLiteral("3550308"));
  QVERIFY(loaded.value(QStringLiteral("includeCommemorative")).toBool());
  QVERIFY(!loaded.value(QStringLiteral("includeOptional")).toBool());

  const QJsonArray municipalities{
      QJsonObject{{QStringLiteral("code"), QStringLiteral("3550308")},
                  {QStringLiteral("name"), QStringLiteral("São Paulo")}},
      QJsonObject{{QStringLiteral("code"), QStringLiteral("3509502")},
                  {QStringLiteral("name"), QStringLiteral("Campinas")}},
  };
  QVERIFY2(store.replaceMunicipalities(QStringLiteral("sp"), municipalities, &error), qPrintable(error));
  const QJsonArray stored = store.listMunicipalities(QStringLiteral("SP"), &error);
  QCOMPARE(stored.size(), 2);
  QCOMPARE(stored.first().toObject().value(QStringLiteral("name")).toString(), QStringLiteral("Campinas"));
}

QTEST_MAIN(TaskStoreTest)
#include "TaskStoreTest.moc"

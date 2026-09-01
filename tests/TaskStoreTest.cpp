#include "core/TaskStore.hpp"

#include <QJsonArray>
#include <QTemporaryDir>
#include <QtTest>

class TaskStoreTest final : public QObject {
  Q_OBJECT

private slots:
  void createCompleteAndRescheduleTask();
  void rejectInvisibleTitle();
  void preserveFloatingCalendarDate();
  void persistSyncConfiguration();
};

void TaskStoreTest::createCompleteAndRescheduleTask() {
  QTemporaryDir directory;
  QVERIFY(directory.isValid());
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::TaskRecord created;
  QVERIFY2(store.createTask(QStringLiteral("  Revisar calendário  "), QDate(2026, 9, 1), &created, &error),
           qPrintable(error));
  QCOMPARE(created.title, QStringLiteral("Revisar calendário"));
  QCOMPARE(created.scheduledDate, QDate(2026, 9, 1));

  QVERIFY2(store.setTaskCompleted(created.id, true, &error), qPrintable(error));
  QVERIFY2(store.rescheduleTask(created.id, QDate(2026, 9, 2), &error), qPrintable(error));

  const QList<waypoint::TaskRecord> tasks = store.listActiveTasks(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(tasks.size(), 1);
  QCOMPARE(tasks.first().scheduledDate, QDate(2026, 9, 2));
  QVERIFY(tasks.first().completed);
  QCOMPARE(tasks.first().version, 3);
  QCOMPARE(store.pendingMutations(&error).size(), 3);
}

void TaskStoreTest::rejectInvisibleTitle() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  QVERIFY(!store.createTask(QStringLiteral("   \t"), QDate::currentDate(), nullptr, &error));
  QVERIFY(error.contains(QStringLiteral("visible character")));
  QCOMPARE(store.listActiveTasks().size(), 0);
}

void TaskStoreTest::preserveFloatingCalendarDate() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  const QDate expectedDate(2026, 9, 1);
  QVERIFY2(store.createTask(QStringLiteral("Data flutuante"), expectedDate, nullptr, &error),
           qPrintable(error));
  QCOMPARE(store.listActiveTasks(&error).first().scheduledDate, expectedDate);
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

QTEST_MAIN(TaskStoreTest)
#include "TaskStoreTest.moc"

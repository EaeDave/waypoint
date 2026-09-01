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
  void cacheHolidaySnapshotAtomically();
  void persistHolidayPreferencesAndMunicipalities();
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

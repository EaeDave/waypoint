#include "core/TaskStore.hpp"

#include <QJsonArray>
#include <QTemporaryDir>
#include <QtTest>

#include <algorithm>

class HabitStoreTest final : public QObject {
  Q_OBJECT

private slots:
  void trackFixedManualAndCompleteAllHabits();
  void projectOnlyScheduledDaysAndResetProgress();
  void persistDefinitionsEntriesDeliveriesAndOutbox();
  void applyRemoteHabitAndEntryChanges();
};

void HabitStoreTest::trackFixedManualAndCompleteAllHabits() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("waypoint.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  const QDate date(2026, 9, 1);

  waypoint::HabitRecord fixed;
  QVERIFY2(store.createHabit(QStringLiteral("Água"), 2000, QStringLiteral("ml"),
                             waypoint::HabitCheckInMode::Fixed, 250, {date.dayOfWeek()}, {},
                             QStringLiteral("💧"), &fixed, &error),
           qPrintable(error));
  QVERIFY2(store.recordHabit(fixed.id, date, std::nullopt, nullptr, &error), qPrintable(error));
  error.clear();
  QVERIFY(!store.recordHabit(fixed.id, date, 500, nullptr, &error));
  QCOMPARE(error, QStringLiteral("Fixed check-ins must use the configured increment"));
  for (int checkIn = 1; checkIn < 8; ++checkIn) {
    QVERIFY2(store.recordHabit(fixed.id, date, std::nullopt, nullptr, &error), qPrintable(error));
  }
  QList<waypoint::HabitProgress> progress = store.listHabitProgress(date, &error);
  QCOMPARE(progress.first().amount, 2000);
  QVERIFY(progress.first().completed());
  QVERIFY2(store.undoLastHabitEntry(fixed.id, date, &error), qPrintable(error));
  progress = store.listHabitProgress(date, &error);
  QCOMPARE(progress.first().amount, 1750);
  QVERIFY(!progress.first().completed());

  waypoint::HabitRecord manual;
  QVERIFY2(store.createHabit(QStringLiteral("Leitura"), 10, QStringLiteral("páginas"),
                             waypoint::HabitCheckInMode::Manual, 1, {date.dayOfWeek()}, {}, {},
                             &manual, &error),
           qPrintable(error));
  error.clear();
  QVERIFY(!store.recordHabit(manual.id, date, std::nullopt, nullptr, &error));
  QVERIFY2(store.recordHabit(manual.id, date, 6, nullptr, &error), qPrintable(error));
  QVERIFY2(store.recordHabit(manual.id, date, 7, nullptr, &error), qPrintable(error));

  waypoint::HabitRecord completeAll;
  QVERIFY2(store.createHabit(QStringLiteral("Meditar"), 1, {},
                             waypoint::HabitCheckInMode::CompleteAll, 1, {date.dayOfWeek()}, {}, {},
                             &completeAll, &error),
           qPrintable(error));
  QVERIFY2(store.recordHabit(completeAll.id, date, std::nullopt, nullptr, &error), qPrintable(error));

  progress = store.listHabitProgress(date, &error);
  QCOMPARE(progress.size(), 3);
  const auto manualProgress = std::ranges::find_if(progress, [&](const waypoint::HabitProgress &item) {
    return item.habit.id == manual.id;
  });
  QVERIFY(manualProgress != progress.end());
  QCOMPARE(manualProgress->amount, 13);
  QVERIFY(manualProgress->completed());
}

void HabitStoreTest::projectOnlyScheduledDaysAndResetProgress() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("waypoint.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  const QDate tuesday(2026, 9, 1);
  waypoint::HabitRecord habit;
  QVERIFY2(store.createHabit(QStringLiteral("Alongar"), 1, {},
                             waypoint::HabitCheckInMode::CompleteAll, 1, {Qt::Tuesday}, {}, {},
                             &habit, &error),
           qPrintable(error));
  QVERIFY2(store.recordHabit(habit.id, tuesday, std::nullopt, nullptr, &error), qPrintable(error));
  QCOMPARE(store.listHabitProgress(tuesday, &error).first().amount, 1);
  QVERIFY(store.listHabitProgress(tuesday.addDays(1), &error).isEmpty());
  const QList<waypoint::HabitProgress> nextWeek = store.listHabitProgress(tuesday.addDays(7), &error);
  QCOMPARE(nextWeek.size(), 1);
  QCOMPARE(nextWeek.first().amount, 0);
  error.clear();
  QVERIFY(!store.recordHabit(habit.id, tuesday.addDays(1), std::nullopt, nullptr, &error));
}

void HabitStoreTest::persistDefinitionsEntriesDeliveriesAndOutbox() {
  QTemporaryDir directory;
  const QString databasePath = directory.filePath(QStringLiteral("waypoint.sqlite3"));
  QString habitId;
  const QDate date(2026, 9, 1);
  {
    waypoint::TaskStore store(databasePath);
    QString error;
    QVERIFY2(store.open(&error), qPrintable(error));
    waypoint::HabitRecord habit;
    QVERIFY2(store.createHabit(QStringLiteral("Água"), 8, QStringLiteral("copos"),
                               waypoint::HabitCheckInMode::Fixed, 1, {date.dayOfWeek()},
                               {QTime(8, 0), QTime(12, 0)}, {}, &habit, &error),
             qPrintable(error));
    habitId = habit.id;
    QVERIFY2(store.recordHabit(habit.id, date, std::nullopt, nullptr, &error), qPrintable(error));
    bool claimed = false;
    QVERIFY2(store.claimHabitReminderDelivery(habit.id, date, QTime(8, 0), &claimed, &error),
             qPrintable(error));
    QVERIFY(claimed);
    const QJsonArray outbox = store.pendingMutations(&error);
    QCOMPARE(outbox.size(), 2);
    QCOMPARE(outbox.at(0).toObject().value(QStringLiteral("entityType")).toString(),
             QStringLiteral("habit"));
    QCOMPARE(outbox.at(1).toObject().value(QStringLiteral("entityType")).toString(),
             QStringLiteral("habit-entry"));
  }
  {
    waypoint::TaskStore reopened(databasePath);
    QString error;
    QVERIFY2(reopened.open(&error), qPrintable(error));
    const QList<waypoint::HabitRecord> habits = reopened.listActiveHabits(&error);
    QCOMPARE(habits.size(), 1);
    QCOMPARE(habits.first().reminderTimes, QList<QTime>({QTime(8, 0), QTime(12, 0)}));
    QCOMPARE(reopened.listHabitEntries(habitId, date, &error).size(), 1);
    bool claimed = true;
    QVERIFY2(reopened.claimHabitReminderDelivery(habitId, date, QTime(8, 0), &claimed, &error),
             qPrintable(error));
    QVERIFY(!claimed);
  }
}

void HabitStoreTest::applyRemoteHabitAndEntryChanges() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("waypoint.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::HabitRecord habit;
  habit.id = QStringLiteral("11111111-1111-4111-8111-111111111111");
  habit.title = QStringLiteral("Remoto");
  habit.targetAmount = 5;
  habit.unit = QStringLiteral("vezes");
  habit.checkInMode = waypoint::HabitCheckInMode::Manual;
  habit.incrementAmount = 1;
  habit.weekdays = {1, 2, 3, 4, 5, 6, 7};
  habit.reminderTimes = {QTime(9, 0)};
  habit.createdAt = QDateTime::currentDateTimeUtc();
  habit.updatedAt = habit.createdAt;
  habit.version = 3;

  waypoint::HabitEntry entry;
  entry.id = QStringLiteral("22222222-2222-4222-8222-222222222222");
  entry.habitId = habit.id;
  entry.entryDate = QDate(2026, 9, 1);
  entry.amount = 3;
  entry.loggedAt = habit.createdAt;
  entry.updatedAt = habit.createdAt;
  entry.version = 2;

  const QJsonArray changes{
      QJsonObject{{QStringLiteral("entityType"), QStringLiteral("habit")},
                  {QStringLiteral("entityId"), habit.id},
                  {QStringLiteral("operation"), QStringLiteral("upsert")},
                  {QStringLiteral("payload"), habit.toJson()}},
      QJsonObject{{QStringLiteral("entityType"), QStringLiteral("habit-entry")},
                  {QStringLiteral("entityId"), entry.id},
                  {QStringLiteral("operation"), QStringLiteral("upsert")},
                  {QStringLiteral("payload"), entry.toJson()}},
  };
  QVERIFY2(store.applyRemoteChanges(changes, QStringLiteral("2"), {}, &error), qPrintable(error));
  const QList<waypoint::HabitProgress> progress = store.listHabitProgress(entry.entryDate, &error);
  QCOMPARE(progress.size(), 1);
  QCOMPARE(progress.first().amount, 3);

  QJsonObject entryTombstone = entry.toJson();
  entryTombstone.insert(QStringLiteral("version"), 4);
  entryTombstone.insert(QStringLiteral("deletedAt"),
                        QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  const QJsonArray deletion{
      QJsonObject{{QStringLiteral("entityType"), QStringLiteral("habit-entry")},
                  {QStringLiteral("entityId"), entry.id},
                  {QStringLiteral("operation"), QStringLiteral("delete")},
                  {QStringLiteral("payload"), entryTombstone}},
  };
  QVERIFY2(store.applyRemoteChanges(deletion, QStringLiteral("3"), {}, &error), qPrintable(error));
  QCOMPARE(store.listHabitProgress(entry.entryDate, &error).first().amount, 0);
}

QTEST_MAIN(HabitStoreTest)
#include "HabitStoreTest.moc"

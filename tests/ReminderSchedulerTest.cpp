#include "reminders/ReminderScheduler.hpp"
#include "core/TaskStore.hpp"

#include <QTemporaryDir>
#include <QtTest>

class ReminderSchedulerTest final : public QObject {
  Q_OBJECT

private slots:
  void deliverDuePendingTaskExactlyOnce();
  void retryNotificationFailureWithinDueMinute();
  void deliverRecurringOccurrenceOnItsDate();
  void deliverEveryConfiguredReminderAcrossDates();
  void deliverHabitRemindersUntilGoalCompletion();
};

namespace {

class RecordingNotificationSink final : public waypoint::TaskNotificationSink {
public:
  bool failNextSend = false;
  QList<waypoint::TaskOccurrence> deliveries;
  QList<int> reminderMinutesBefore;
  QList<waypoint::HabitProgress> habitDeliveries;
  QList<QTime> habitReminderTimes;

  bool send(const waypoint::TaskOccurrence &occurrence, const int minutesBefore,
            QString *errorMessage) override {
    if (failNextSend) {
      failNextSend = false;
      if (errorMessage != nullptr) {
        *errorMessage = QStringLiteral("notification service unavailable");
      }
      return false;
    }
    deliveries.append(occurrence);
    reminderMinutesBefore.append(minutesBefore);
    return true;
  }

  bool sendHabit(const waypoint::HabitProgress &progress, const QTime &reminderTime,
                 QString *errorMessage) override {
    if (failNextSend) {
      failNextSend = false;
      if (errorMessage != nullptr) {
        *errorMessage = QStringLiteral("notification service unavailable");
      }
      return false;
    }
    habitDeliveries.append(progress);
    habitReminderTimes.append(reminderTime);
    return true;
  }
};

} // namespace

void ReminderSchedulerTest::deliverDuePendingTaskExactlyOnce() {
  QTemporaryDir directory;
  QVERIFY(directory.isValid());
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  const QDate date(2026, 9, 1);
  const QTime dueTime(9, 30);
  waypoint::TaskRecord dueTask;
  QVERIFY2(store.createTask(QStringLiteral("Reunião"), date, dueTime, {}, QList<int>{0}, QStringLiteral("📣"),
                            &dueTask, &error),
           qPrintable(error));
  waypoint::TaskRecord completedTask;
  QVERIFY2(store.createTask(QStringLiteral("Concluída"), date, dueTime, {}, QList<int>{0}, {}, &completedTask,
                            &error),
           qPrintable(error));
  QVERIFY2(store.setTaskCompleted(completedTask.id, true, &error), qPrintable(error));
  QVERIFY2(store.createTask(QStringLiteral("Mais tarde"), date, QTime(10, 0), {}, QList<int>{0}, {}, nullptr,
                            &error),
           qPrintable(error));

  RecordingNotificationSink sink;
  waypoint::ReminderScheduler scheduler(&store, &sink);
  const QDateTime dueMinute(date, dueTime);
  QVERIFY2(scheduler.dispatchDueReminders(dueMinute, &error), qPrintable(error));
  QCOMPARE(sink.deliveries.size(), 1);
  QCOMPARE(sink.deliveries.first().taskId, dueTask.id);
  QCOMPARE(sink.deliveries.first().emoji, QStringLiteral("📣"));

  QVERIFY2(scheduler.dispatchDueReminders(dueMinute.addSecs(20), &error), qPrintable(error));
  QCOMPARE(sink.deliveries.size(), 1);

  RecordingNotificationSink restartedSink;
  waypoint::ReminderScheduler restartedScheduler(&store, &restartedSink);
  QVERIFY2(restartedScheduler.dispatchDueReminders(dueMinute.addSecs(40), &error), qPrintable(error));
  QCOMPARE(restartedSink.deliveries.size(), 0);
}

void ReminderSchedulerTest::retryNotificationFailureWithinDueMinute() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  const QDate date(2026, 9, 1);
  const QTime dueTime(14, 5);
  QVERIFY2(store.createTask(QStringLiteral("Tentar novamente"), date, dueTime, {}, QList<int>{0}, {}, nullptr,
                            &error),
           qPrintable(error));

  RecordingNotificationSink sink;
  sink.failNextSend = true;
  waypoint::ReminderScheduler scheduler(&store, &sink);
  QVERIFY(!scheduler.dispatchDueReminders(QDateTime(date, dueTime), &error));
  QCOMPARE(error, QStringLiteral("notification service unavailable"));
  QCOMPARE(sink.deliveries.size(), 0);

  error.clear();
  QVERIFY2(scheduler.dispatchDueReminders(QDateTime(date, dueTime).addSecs(10), &error), qPrintable(error));
  QCOMPARE(sink.deliveries.size(), 1);
}

void ReminderSchedulerTest::deliverRecurringOccurrenceOnItsDate() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  waypoint::RecurrenceRule recurrence;
  recurrence.frequency = waypoint::RecurrenceFrequency::Daily;
  const QDate anchorDate(2026, 9, 1);
  const QTime dueTime(7, 45);
  waypoint::TaskRecord task;
  QVERIFY2(store.createTask(QStringLiteral("Alongar"), anchorDate, dueTime, recurrence, QList<int>{60, 0}, {},
                            &task, &error),
           qPrintable(error));

  RecordingNotificationSink sink;
  waypoint::ReminderScheduler scheduler(&store, &sink);
  const QDate occurrenceDate = anchorDate.addDays(1);
  const auto actionable = store.listActionableOccurrences(occurrenceDate, &error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(actionable.size(), 1);
  QCOMPARE(actionable.first().occurrenceDate, anchorDate);
  QCOMPARE(actionable.first().reminderMinutesBefore, QList<int>({60, 0}));

  QVERIFY2(scheduler.dispatchDueReminders(QDateTime(occurrenceDate, dueTime).addSecs(-60 * 60), &error),
           qPrintable(error));
  QCOMPARE(sink.deliveries.size(), 1);
  QCOMPARE(sink.reminderMinutesBefore, QList<int>({60}));

  QVERIFY2(scheduler.dispatchDueReminders(QDateTime(occurrenceDate, dueTime), &error), qPrintable(error));
  QCOMPARE(sink.deliveries.size(), 2);
  QCOMPARE(sink.deliveries.first().taskId, task.id);
  QCOMPARE(sink.deliveries.first().occurrenceDate, occurrenceDate);
  QVERIFY(sink.deliveries.first().recurring);
  QCOMPARE(sink.reminderMinutesBefore, QList<int>({60, 0}));
}

void ReminderSchedulerTest::deliverEveryConfiguredReminderAcrossDates() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  const QDate dueDate(2026, 9, 2);
  const QTime dueTime(2, 0);
  const QList<int> reminders{300, 180, 60, 30, 0};
  QVERIFY2(store.createTask(QStringLiteral("Viagem"), dueDate, dueTime, {}, reminders, {}, nullptr, &error),
           qPrintable(error));

  RecordingNotificationSink sink;
  waypoint::ReminderScheduler scheduler(&store, &sink);
  const QDateTime dueMoment(dueDate, dueTime);
  for (const int minutesBefore : reminders) {
    QVERIFY2(scheduler.dispatchDueReminders(dueMoment.addSecs(-minutesBefore * 60), &error),
             qPrintable(error));
  }

  QCOMPARE(sink.deliveries.size(), reminders.size());
  QCOMPARE(sink.reminderMinutesBefore, reminders);
  QCOMPARE(sink.deliveries.first().occurrenceDate, dueDate);
}

void ReminderSchedulerTest::deliverHabitRemindersUntilGoalCompletion() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  const QDate date(2026, 9, 1);
  const QList<QTime> reminders{QTime(8, 0), QTime(9, 0), QTime(10, 0)};
  waypoint::HabitRecord habit;
  QVERIFY2(store.createHabit(QStringLiteral("Água"), 2, QStringLiteral("copos"),
                             waypoint::HabitCheckInMode::Fixed, 1, {date.dayOfWeek()}, reminders,
                             QStringLiteral("💧"), &habit, &error),
           qPrintable(error));

  RecordingNotificationSink sink;
  waypoint::ReminderScheduler scheduler(&store, &sink);
  QVERIFY2(scheduler.dispatchDueReminders(QDateTime(date, reminders.at(0)), &error), qPrintable(error));
  QCOMPARE(sink.habitDeliveries.size(), 1);
  QCOMPARE(sink.habitDeliveries.first().amount, 0);

  QVERIFY2(store.recordHabit(habit.id, date, std::nullopt, nullptr, &error), qPrintable(error));
  QVERIFY2(scheduler.dispatchDueReminders(QDateTime(date, reminders.at(1)), &error), qPrintable(error));
  QCOMPARE(sink.habitDeliveries.size(), 2);
  QCOMPARE(sink.habitDeliveries.last().amount, 1);

  QVERIFY2(store.recordHabit(habit.id, date, std::nullopt, nullptr, &error), qPrintable(error));
  QVERIFY2(scheduler.dispatchDueReminders(QDateTime(date, reminders.at(2)), &error), qPrintable(error));
  QCOMPARE(sink.habitDeliveries.size(), 2);
  QCOMPARE(sink.habitReminderTimes, QList<QTime>({QTime(8, 0), QTime(9, 0)}));
}

QTEST_MAIN(ReminderSchedulerTest)
#include "ReminderSchedulerTest.moc"

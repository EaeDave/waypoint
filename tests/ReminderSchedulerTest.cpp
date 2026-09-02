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
};

namespace {

class RecordingNotificationSink final : public waypoint::TaskNotificationSink {
public:
  bool failNextSend = false;
  QList<waypoint::TaskOccurrence> deliveries;

  bool send(const waypoint::TaskOccurrence &occurrence, QString *errorMessage) override {
    if (failNextSend) {
      failNextSend = false;
      if (errorMessage != nullptr) {
        *errorMessage = QStringLiteral("notification service unavailable");
      }
      return false;
    }
    deliveries.append(occurrence);
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
  QVERIFY2(
      store.createTask(QStringLiteral("Reunião"), date, dueTime, {}, QStringLiteral("📣"), &dueTask, &error),
      qPrintable(error));
  waypoint::TaskRecord completedTask;
  QVERIFY2(store.createTask(QStringLiteral("Concluída"), date, dueTime, {}, {}, &completedTask, &error),
           qPrintable(error));
  QVERIFY2(store.setTaskCompleted(completedTask.id, true, &error), qPrintable(error));
  QVERIFY2(store.createTask(QStringLiteral("Mais tarde"), date, QTime(10, 0), {}, {}, nullptr, &error),
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
  QVERIFY2(store.createTask(QStringLiteral("Tentar novamente"), date, dueTime, {}, {}, nullptr, &error),
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
  QVERIFY2(store.createTask(QStringLiteral("Alongar"), anchorDate, dueTime, recurrence, {}, &task, &error),
           qPrintable(error));

  RecordingNotificationSink sink;
  waypoint::ReminderScheduler scheduler(&store, &sink);
  const QDate occurrenceDate = anchorDate.addDays(1);
  const auto actionable = store.listActionableOccurrences(occurrenceDate, &error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(actionable.size(), 1);
  QCOMPARE(actionable.first().occurrenceDate, anchorDate);

  QVERIFY2(scheduler.dispatchDueReminders(QDateTime(occurrenceDate, dueTime), &error), qPrintable(error));
  QCOMPARE(sink.deliveries.size(), 1);
  QCOMPARE(sink.deliveries.first().taskId, task.id);
  QCOMPARE(sink.deliveries.first().occurrenceDate, occurrenceDate);
  QVERIFY(sink.deliveries.first().recurring);
}

QTEST_MAIN(ReminderSchedulerTest)
#include "ReminderSchedulerTest.moc"

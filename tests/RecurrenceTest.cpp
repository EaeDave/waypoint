#include "core/Recurrence.hpp"
#include "core/TaskRecord.hpp"

#include <QtTest>
#include <algorithm>

class RecurrenceTest final : public QObject {
  Q_OBJECT

private slots:
  void serializeTypedRule();
  void generateBoundedDailyOccurrences();
  void selectWeekdaysInAnchoredWeeks();
  void keepOriginalMonthlyAnchor();
  void clampLeapDayFromOriginalAnchor();
  void honorEndingConditions();
  void projectOccurrenceStateByDate();
  void holdOldestUnresolvedDueRecurringOccurrence();
  void hideSkippedOccurrenceUntilNextRecurrence();
  void advanceCalendarMarkerAfterResolvedOccurrence();
  void isolateDailyCountsAcrossMidnightAndSeries();
  void sortActionableTasksByTimeWithCompletedLast();
};

void RecurrenceTest::serializeTypedRule() {
  waypoint::RecurrenceRule expected;
  expected.frequency = waypoint::RecurrenceFrequency::Weekly;
  expected.interval = 2;
  expected.weekdays = {1, 4};
  expected.endMode = waypoint::RecurrenceEndMode::AfterCount;
  expected.occurrenceCount = 9;

  const waypoint::RecurrenceRule actual = waypoint::RecurrenceRule::fromJson(expected.toJson());
  QCOMPARE(actual.frequency, expected.frequency);
  QCOMPARE(actual.interval, 2);
  QCOMPARE(actual.weekdays, QList<int>({1, 4}));
  QCOMPARE(actual.endMode, waypoint::RecurrenceEndMode::AfterCount);
  QCOMPARE(actual.occurrenceCount, 9);
  QVERIFY(actual.isValid());
}

void RecurrenceTest::generateBoundedDailyOccurrences() {
  waypoint::RecurrenceRule rule;
  rule.frequency = waypoint::RecurrenceFrequency::Daily;
  rule.interval = 2;

  QCOMPARE(waypoint::recurrenceDates(QDate(2026, 1, 1), rule, QDate(2026, 1, 4), QDate(2026, 1, 8)),
           QList<QDate>({QDate(2026, 1, 5), QDate(2026, 1, 7)}));
}

void RecurrenceTest::selectWeekdaysInAnchoredWeeks() {
  waypoint::RecurrenceRule rule;
  rule.frequency = waypoint::RecurrenceFrequency::Weekly;
  rule.interval = 2;
  rule.weekdays = {1, 3};

  QCOMPARE(waypoint::recurrenceDates(QDate(2026, 1, 7), rule, QDate(2026, 1, 1), QDate(2026, 1, 31)),
           QList<QDate>({QDate(2026, 1, 7), QDate(2026, 1, 19), QDate(2026, 1, 21)}));
}

void RecurrenceTest::keepOriginalMonthlyAnchor() {
  waypoint::RecurrenceRule rule;
  rule.frequency = waypoint::RecurrenceFrequency::Monthly;

  QCOMPARE(waypoint::recurrenceDates(QDate(2025, 1, 31), rule, QDate(2025, 1, 1), QDate(2025, 4, 30)),
           QList<QDate>({QDate(2025, 1, 31), QDate(2025, 2, 28), QDate(2025, 3, 31), QDate(2025, 4, 30)}));
}

void RecurrenceTest::clampLeapDayFromOriginalAnchor() {
  waypoint::RecurrenceRule rule;
  rule.frequency = waypoint::RecurrenceFrequency::Yearly;

  QCOMPARE(waypoint::recurrenceDates(QDate(2024, 2, 29), rule, QDate(2024, 1, 1), QDate(2028, 12, 31)),
           QList<QDate>({QDate(2024, 2, 29), QDate(2025, 2, 28), QDate(2026, 2, 28), QDate(2027, 2, 28),
                         QDate(2028, 2, 29)}));
}

void RecurrenceTest::honorEndingConditions() {
  waypoint::RecurrenceRule untilRule;
  untilRule.frequency = waypoint::RecurrenceFrequency::Daily;
  untilRule.endMode = waypoint::RecurrenceEndMode::OnDate;
  untilRule.untilDate = QDate(2026, 1, 3);
  QCOMPARE(waypoint::recurrenceDates(QDate(2026, 1, 1), untilRule, QDate(2026, 1, 1), QDate(2026, 1, 10)),
           QList<QDate>({QDate(2026, 1, 1), QDate(2026, 1, 2), QDate(2026, 1, 3)}));

  waypoint::RecurrenceRule countRule = untilRule;
  countRule.endMode = waypoint::RecurrenceEndMode::AfterCount;
  countRule.occurrenceCount = 2;
  QCOMPARE(waypoint::recurrenceDates(QDate(2026, 1, 1), countRule, QDate(2026, 1, 1), QDate(2026, 1, 10)),
           QList<QDate>({QDate(2026, 1, 1), QDate(2026, 1, 2)}));
}

void RecurrenceTest::projectOccurrenceStateByDate() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("task-a");
  task.title = QStringLiteral("Praticar");
  task.scheduledDate = QDate(2026, 1, 1);
  task.scheduledTime = QTime(18, 20);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;

  waypoint::TaskOccurrenceState completed;
  completed.taskId = task.id;
  completed.occurrenceDate = QDate(2026, 1, 2);

  const auto occurrences =
      waypoint::projectOccurrences({task}, {completed}, QDate(2026, 1, 1), QDate(2026, 1, 3));
  QCOMPARE(occurrences.size(), 3);
  QVERIFY(!occurrences.at(0).completed);
  QVERIFY(occurrences.at(1).completed);
  QVERIFY(!occurrences.at(2).completed);
  QCOMPARE(occurrences.at(1).key(), QStringLiteral("task-a@2026-01-02"));
  QCOMPARE(occurrences.at(1).scheduledTime, QTime(18, 20));
}

void RecurrenceTest::holdOldestUnresolvedDueRecurringOccurrence() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("task-a");
  task.title = QStringLiteral("Praticar");
  task.scheduledDate = QDate(2026, 1, 1);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;
  const QDate today(2026, 1, 2);

  const auto overdue = waypoint::projectActionableOccurrences({task}, {}, today);
  QCOMPARE(overdue.size(), 1);
  QCOMPARE(overdue.first().occurrenceDate, QDate(2026, 1, 1));

  waypoint::TaskOccurrenceState resolved;
  resolved.taskId = task.id;
  resolved.occurrenceDate = QDate(2026, 1, 1);
  resolved.status = waypoint::OccurrenceStatus::Completed;
  const auto afterCompletion = waypoint::projectActionableOccurrences({task}, {resolved}, today);
  QCOMPARE(afterCompletion.size(), 1);
  QCOMPARE(afterCompletion.first().occurrenceDate, today);

  resolved.status = waypoint::OccurrenceStatus::Skipped;
  const auto afterSkip = waypoint::projectActionableOccurrences({task}, {resolved}, today);
  QCOMPARE(afterSkip.size(), 1);
  QCOMPARE(afterSkip.first().occurrenceDate, today);
}
void RecurrenceTest::hideSkippedOccurrenceUntilNextRecurrence() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("task-a");
  task.title = QStringLiteral("Praticar");
  task.scheduledDate = QDate(2026, 1, 1);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;

  waypoint::TaskOccurrenceState first;
  first.taskId = task.id;
  first.occurrenceDate = QDate(2026, 1, 1);
  first.status = waypoint::OccurrenceStatus::Completed;
  waypoint::TaskOccurrenceState second = first;
  second.occurrenceDate = QDate(2026, 1, 2);
  waypoint::TaskOccurrenceState skipped = first;
  skipped.occurrenceDate = QDate(2026, 1, 3);
  skipped.status = waypoint::OccurrenceStatus::Skipped;
  const QList<waypoint::TaskOccurrenceState> states{first, second, skipped};

  QVERIFY(waypoint::projectActionableOccurrences({task}, states, QDate(2026, 1, 3)).isEmpty());

  const auto nextDay = waypoint::projectActionableOccurrences({task}, states, QDate(2026, 1, 4));
  QCOMPARE(nextDay.size(), 1);
  QCOMPARE(nextDay.first().occurrenceDate, QDate(2026, 1, 4));
}

void RecurrenceTest::advanceCalendarMarkerAfterResolvedOccurrence() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("task-a");
  task.title = QStringLiteral("Praticar");
  task.scheduledDate = QDate(2026, 1, 1);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;
  const QDate yesterday(2026, 1, 1);
  const QDate today(2026, 1, 2);
  const QDate tomorrow(2026, 1, 3);

  const auto overdue = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, {}, yesterday, tomorrow), {task}, {}, today);
  QCOMPARE(overdue.size(), 3);
  QVERIFY(overdue.at(0).calendarMarker);
  QVERIFY(!overdue.at(1).calendarMarker);
  QVERIFY(!overdue.at(2).calendarMarker);

  waypoint::TaskOccurrenceState resolved;
  resolved.taskId = task.id;
  resolved.occurrenceDate = yesterday;
  resolved.status = waypoint::OccurrenceStatus::Completed;
  const auto afterCompletion = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, {resolved}, yesterday, tomorrow), {task}, {resolved}, today);
  QCOMPARE(afterCompletion.size(), 3);
  QVERIFY(!afterCompletion.at(0).calendarMarker);
  QVERIFY(afterCompletion.at(1).calendarMarker);
  QVERIFY(!afterCompletion.at(2).calendarMarker);

  waypoint::TaskOccurrenceState completedToday = resolved;
  completedToday.occurrenceDate = today;
  const QList<waypoint::TaskOccurrenceState> completedThroughToday{resolved, completedToday};
  const auto nextPending = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, completedThroughToday, yesterday, tomorrow), {task},
      completedThroughToday, today);
  QCOMPARE(nextPending.size(), 3);
  QVERIFY(!nextPending.at(0).calendarMarker);
  QVERIFY(!nextPending.at(1).calendarMarker);
  QVERIFY(nextPending.at(2).calendarMarker);

  resolved.status = waypoint::OccurrenceStatus::Skipped;
  const auto afterSkip = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, {resolved}, yesterday, tomorrow), {task}, {resolved}, today);
  QCOMPARE(afterSkip.size(), 2);
  QCOMPARE(afterSkip.at(0).occurrenceDate, today);
  QVERIFY(afterSkip.at(0).calendarMarker);
  QVERIFY(!afterSkip.at(1).calendarMarker);
}

void RecurrenceTest::isolateDailyCountsAcrossMidnightAndSeries() {
  waypoint::TaskRecord first;
  first.id = QStringLiteral("first");
  first.title = QStringLiteral("Primeira");
  first.scheduledDate = QDate(2026, 1, 1);
  first.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;

  waypoint::TaskRecord second;
  second.id = QStringLiteral("second");
  second.title = QStringLiteral("Segunda");
  second.scheduledDate = QDate(2026, 1, 2);
  second.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;

  waypoint::TaskOccurrenceState completed;
  completed.taskId = first.id;
  completed.occurrenceDate = QDate(2026, 1, 1);
  completed.status = waypoint::OccurrenceStatus::Completed;

  const auto projected =
      waypoint::projectOccurrences({first, second}, {completed}, QDate(2026, 1, 1), QDate(2026, 1, 2));
  QCOMPARE(projected.size(), 3);
  const waypoint::OccurrenceSummary januaryFirst =
      waypoint::summarizeOccurrences(projected, QDate(2026, 1, 1));
  QCOMPARE(januaryFirst.pendingToday, 0);
  QCOMPARE(januaryFirst.overdue, 0);

  const auto afterMidnight =
      waypoint::projectActionableOccurrences({first, second}, {completed}, QDate(2026, 1, 2));
  const waypoint::OccurrenceSummary januarySecond =
      waypoint::summarizeOccurrences(afterMidnight, QDate(2026, 1, 2));
  QCOMPARE(januarySecond.pendingToday, 2);
  QCOMPARE(januarySecond.overdue, 0);
  QVERIFY(std::ranges::all_of(afterMidnight, [](const auto &occurrence) {
    return occurrence.occurrenceDate == QDate(2026, 1, 2) && !occurrence.completed;
  }));
}

void RecurrenceTest::sortActionableTasksByTimeWithCompletedLast() {
  const QDate today(2026, 9, 2);
  waypoint::TaskRecord late;
  late.id = QStringLiteral("late");
  late.title = QStringLiteral("Escovar os dentes");
  late.scheduledDate = today;
  late.scheduledTime = QTime(13, 30);

  waypoint::TaskRecord early = late;
  early.id = QStringLiteral("early");
  early.title = QStringLiteral("Almoçar");
  early.scheduledTime = QTime(12, 0);

  waypoint::TaskRecord completed = late;
  completed.id = QStringLiteral("completed");
  completed.title = QStringLiteral("Tomar creatina");
  completed.scheduledTime = QTime(9, 0);
  completed.completed = true;

  const auto actionable = waypoint::projectActionableOccurrences({late, completed, early}, {}, today);
  QCOMPARE(actionable.size(), 3);
  QCOMPARE(actionable.at(0).taskId, QStringLiteral("early"));
  QCOMPARE(actionable.at(1).taskId, QStringLiteral("late"));
  QCOMPARE(actionable.at(2).taskId, QStringLiteral("completed"));

  const auto ranged = waypoint::projectOccurrences({late, completed, early}, {}, today, today);
  QCOMPARE(ranged.size(), 3);
  QCOMPARE(ranged.at(0).taskId, QStringLiteral("early"));
  QCOMPARE(ranged.at(1).taskId, QStringLiteral("late"));
  QCOMPARE(ranged.at(2).taskId, QStringLiteral("completed"));
}

QTEST_MAIN(RecurrenceTest)
#include "RecurrenceTest.moc"

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
  void exposeOnlyLatestDueRecurringOccurrence();
  void hideSkippedOccurrenceUntilNextRecurrence();
  void isolateDailyCountsAcrossMidnightAndSeries();
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

void RecurrenceTest::exposeOnlyLatestDueRecurringOccurrence() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("task-a");
  task.title = QStringLiteral("Praticar");
  task.scheduledDate = QDate(2026, 1, 1);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;

  waypoint::TaskOccurrenceState yesterday;
  yesterday.taskId = task.id;
  yesterday.occurrenceDate = QDate(2026, 1, 2);

  const auto occurrences = waypoint::projectActionableOccurrences({task}, {yesterday}, QDate(2026, 1, 3));
  QCOMPARE(occurrences.size(), 1);
  QCOMPARE(occurrences.first().occurrenceDate, QDate(2026, 1, 3));
  QVERIFY(!occurrences.first().completed);
}
void RecurrenceTest::hideSkippedOccurrenceUntilNextRecurrence() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("task-a");
  task.title = QStringLiteral("Praticar");
  task.scheduledDate = QDate(2026, 1, 1);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;

  waypoint::TaskOccurrenceState skipped;
  skipped.taskId = task.id;
  skipped.occurrenceDate = QDate(2026, 1, 3);
  skipped.status = waypoint::OccurrenceStatus::Skipped;

  QVERIFY(waypoint::projectActionableOccurrences({task}, {skipped}, QDate(2026, 1, 3)).isEmpty());

  const auto nextDay = waypoint::projectActionableOccurrences({task}, {skipped}, QDate(2026, 1, 4));
  QCOMPARE(nextDay.size(), 1);
  QCOMPARE(nextDay.first().occurrenceDate, QDate(2026, 1, 4));
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

QTEST_MAIN(RecurrenceTest)
#include "RecurrenceTest.moc"

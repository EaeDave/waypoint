#include "core/Recurrence.hpp"
#include "core/TaskRecord.hpp"
#include "core/TaskVisibility.hpp"

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
  void keepSkippedOccurrenceVisibleWhileAdvancingRecurrence();
  void advanceCalendarMarkerAfterResolvedOccurrence();
  void keepLateMonthlyCompletionOnDueDay();
  void distinguishActualCompletionFromRegistration();
  void decodeLegacyCompletionWithoutInventingActualDay();
  void isolateDailyCountsAcrossMidnightAndSeries();
  void sortActionableTasksByTimeWithCompletedLast();
  void projectMonthlyDefinitionWithoutMovingAnchor();
  void projectDefinitionPendingDate_data();
  void projectDefinitionPendingDate();
  void preserveNonRecurringDefinitionCompletion();
  void filterCalendarListsAndRegistrationHistory();
};

void RecurrenceTest::filterCalendarListsAndRegistrationHistory() {
  const std::optional<QStringList> bills = QStringList{QStringLiteral("bills")};
  const std::optional<QStringList> none = QStringList{};
  QVERIFY(waypoint::isTaskListVisible(QStringLiteral("new-list"), std::nullopt));
  QVERIFY(!waypoint::isTaskListVisible(QStringLiteral("bills"), none));
  QVERIFY(!waypoint::isTaskListVisible(QString(), none));
  QVERIFY(waypoint::isTaskListVisible(QString(), QStringList{QString()}));
  QVERIFY(!waypoint::isTaskListVisible(QStringLiteral("bills"), QStringList{QString()}));
  QVERIFY(waypoint::isTaskListVisible(QStringLiteral("bills"), bills));
  QVERIFY(!waypoint::isTaskListVisible(QStringLiteral("routine"), bills));

  waypoint::TaskRecord bill;
  bill.id = QStringLiteral("bill");
  bill.categoryId = QStringLiteral("bills");
  bill.categoryName = QStringLiteral("Contas a pagar");
  bill.scheduledDate = QDate(2026, 9, 3);
  bill.completed = true;
  bill.completedDate = QDate(2026, 9, 3);
  bill.registeredAt = QDateTime(QDate(2026, 9, 4), QTime(12, 0));
  waypoint::TaskRecord inbox = bill;
  inbox.id = QStringLiteral("inbox");
  inbox.categoryId.clear();
  inbox.categoryName.clear();
  const auto history = waypoint::projectRegistrationActivity(
      {bill, inbox}, {}, QDate(2026, 9, 4), QDate(2026, 9, 4))
                           .value(QStringLiteral("2026-09-04")).toArray();
  QCOMPARE(history.size(), 2);
  const auto selected = waypoint::filterTaskListActivity(history, bills);
  QCOMPARE(selected.size(), 1);
  QCOMPARE(selected.first().toObject().value(QStringLiteral("taskId")).toString(), bill.id);
  QCOMPARE(waypoint::filterTaskListActivity(history, std::nullopt), history);
  QVERIFY(waypoint::filterTaskListActivity(history, none).isEmpty());
  const auto entrance = waypoint::filterTaskListActivity(history, QStringList{QString()});
  QCOMPARE(entrance.size(), 1);
  QCOMPARE(entrance.first().toObject().value(QStringLiteral("taskId")).toString(), inbox.id);
}

void RecurrenceTest::projectMonthlyDefinitionWithoutMovingAnchor() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("rent");
  task.scheduledDate = QDate(2026, 9, 3);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Monthly;
  waypoint::TaskOccurrenceState september;
  september.taskId = task.id;
  september.occurrenceDate = task.scheduledDate;
  september.status = waypoint::OccurrenceStatus::Completed;
  september.completedDate = QDate(2026, 9, 3);
  const QDate today(2026, 9, 30);

  const auto paid = waypoint::projectTaskDefinitions({task}, {september}, today).first().toObject();
  QCOMPARE(paid.value(QStringLiteral("scheduledDate")).toString(), QStringLiteral("2026-09-03"));
  QCOMPARE(paid.value(QStringLiteral("pendingDate")).toString(), QStringLiteral("2026-10-03"));
  QVERIFY(!paid.value(QStringLiteral("overdue")).toBool());
  QVERIFY(!paid.value(QStringLiteral("completed")).toBool());

  september.status = waypoint::OccurrenceStatus::Pending;
  const auto reopened = waypoint::projectTaskDefinitions({task}, {september}, today).first().toObject();
  QCOMPARE(reopened.value(QStringLiteral("pendingDate")).toString(), QStringLiteral("2026-09-03"));
  QVERIFY(reopened.value(QStringLiteral("overdue")).toBool());
  september.status = waypoint::OccurrenceStatus::Skipped;
  const auto skipped = waypoint::projectTaskDefinitions({task}, {september}, today).first().toObject();
  QCOMPARE(skipped.value(QStringLiteral("pendingDate")).toString(), QStringLiteral("2026-10-03"));
  QVERIFY(!skipped.value(QStringLiteral("overdue")).toBool());
}

void RecurrenceTest::projectDefinitionPendingDate_data() {
  QTest::addColumn<QString>("frequency");
  QTest::addColumn<QDate>("anchor");
  QTest::addColumn<int>("interval");
  QTest::addColumn<QList<int>>("weekdays");
  QTest::addColumn<QList<QDate>>("resolvedDates");
  QTest::addColumn<QString>("endMode");
  QTest::addColumn<QDate>("until");
  QTest::addColumn<int>("count");
  QTest::addColumn<QDate>("today");
  QTest::addColumn<QDate>("pending");

  QTest::newRow("daily-interval-future-resolved")
      << QStringLiteral("daily") << QDate(2026, 9, 29) << 2 << QList<int>{}
      << QList<QDate>{QDate(2026, 9, 29), QDate(2026, 10, 1), QDate(2026, 10, 3)}
      << QStringLiteral("never") << QDate{} << 0 << QDate(2026, 9, 30) << QDate(2026, 10, 5);
  QTest::newRow("weekly-interval-partial-first-week")
      << QStringLiteral("weekly") << QDate(2026, 9, 30) << 2 << QList<int>{1, 3}
      << QList<QDate>{QDate(2026, 9, 30), QDate(2026, 10, 12)}
      << QStringLiteral("never") << QDate{} << 0 << QDate(2026, 9, 30) << QDate(2026, 10, 14);
  QTest::newRow("monthly-end-restores-anchor")
      << QStringLiteral("monthly") << QDate(2025, 1, 31) << 1 << QList<int>{}
      << QList<QDate>{QDate(2025, 1, 31), QDate(2025, 2, 28)}
      << QStringLiteral("never") << QDate{} << 0 << QDate(2025, 3, 1) << QDate(2025, 3, 31);
  QTest::newRow("monthly-interval")
      << QStringLiteral("monthly") << QDate(2026, 7, 31) << 2 << QList<int>{}
      << QList<QDate>{QDate(2026, 7, 31), QDate(2026, 9, 30)}
      << QStringLiteral("never") << QDate{} << 0 << QDate(2026, 9, 30) << QDate(2026, 11, 30);
  QTest::newRow("yearly-leap-anchor")
      << QStringLiteral("yearly") << QDate(2024, 2, 29) << 2 << QList<int>{}
      << QList<QDate>{QDate(2024, 2, 29), QDate(2026, 2, 28)}
      << QStringLiteral("never") << QDate{} << 0 << QDate(2026, 9, 30) << QDate(2028, 2, 29);
  QTest::newRow("finite-count-resolved")
      << QStringLiteral("monthly") << QDate(2026, 9, 3) << 1 << QList<int>{}
      << QList<QDate>{QDate(2026, 9, 3), QDate(2026, 10, 3)}
      << QStringLiteral("afterCount") << QDate{} << 2 << QDate(2026, 9, 30) << QDate{};
  QTest::newRow("finite-until-resolved")
      << QStringLiteral("monthly") << QDate(2026, 9, 3) << 1 << QList<int>{}
      << QList<QDate>{QDate(2026, 9, 3)}
      << QStringLiteral("onDate") << QDate(2026, 9, 3) << 0 << QDate(2026, 9, 30) << QDate{};
  QTest::newRow("ended-but-unresolved")
      << QStringLiteral("daily") << QDate(2026, 9, 1) << 1 << QList<int>{}
      << QList<QDate>{QDate(2026, 9, 1), QDate(2026, 9, 3)}
      << QStringLiteral("onDate") << QDate(2026, 9, 3) << 0 << QDate(2026, 9, 30) << QDate(2026, 9, 2);
  QTest::newRow("ancient-open-series")
      << QStringLiteral("daily") << QDate(1900, 1, 1) << 1 << QList<int>{} << QList<QDate>{}
      << QStringLiteral("never") << QDate{} << 0 << QDate(2026, 9, 30) << QDate(1900, 1, 1);
  QTest::newRow("future-unresolved")
      << QStringLiteral("monthly") << QDate(2027, 1, 3) << 1 << QList<int>{} << QList<QDate>{}
      << QStringLiteral("never") << QDate{} << 0 << QDate(2026, 9, 30) << QDate(2027, 1, 3);
}

void RecurrenceTest::projectDefinitionPendingDate() {
  QFETCH(QString, frequency);
  QFETCH(QDate, anchor);
  QFETCH(int, interval);
  QFETCH(QList<int>, weekdays);
  QFETCH(QList<QDate>, resolvedDates);
  QFETCH(QString, endMode);
  QFETCH(QDate, until);
  QFETCH(int, count);
  QFETCH(QDate, today);
  QFETCH(QDate, pending);
  waypoint::TaskRecord task;
  task.id = QStringLiteral("series");
  task.scheduledDate = anchor;
  task.recurrence = waypoint::RecurrenceRule::fromJson({
      {QStringLiteral("frequency"), frequency},
      {QStringLiteral("interval"), interval},
      {QStringLiteral("endMode"), endMode},
      {QStringLiteral("untilDate"), until.toString(Qt::ISODate)},
      {QStringLiteral("occurrenceCount"), count},
  });
  task.recurrence.weekdays = weekdays;
  QList<waypoint::TaskOccurrenceState> states;
  for (const QDate &date : resolvedDates) {
    waypoint::TaskOccurrenceState state;
    state.taskId = task.id;
    state.occurrenceDate = date;
    state.status = states.size() % 2 == 0 ? waypoint::OccurrenceStatus::Completed
                                        : waypoint::OccurrenceStatus::Skipped;
    state.completedDate = today;
    states.append(state);
  }
  const auto value = waypoint::projectTaskDefinitions({task}, states, today).first().toObject();
  QCOMPARE(value.value(QStringLiteral("pendingDate")).toString(), pending.toString(Qt::ISODate));
  QCOMPARE(value.value(QStringLiteral("overdue")).toBool(), pending.isValid() && pending < today);
  QCOMPARE(value.value(QStringLiteral("scheduledDate")).toString(), anchor.toString(Qt::ISODate));
  QVERIFY(!value.value(QStringLiteral("completed")).toBool());
}

void RecurrenceTest::preserveNonRecurringDefinitionCompletion() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("once");
  task.scheduledDate = QDate(2026, 9, 3);
  const QDate today(2026, 9, 30);
  const auto pending = waypoint::projectTaskDefinitions({task}, {}, today).first().toObject();
  QCOMPARE(pending.value(QStringLiteral("pendingDate")).toString(), QStringLiteral("2026-09-03"));
  QVERIFY(pending.value(QStringLiteral("overdue")).toBool());
  task.completed = true;
  task.completedDate = QDate(2026, 9, 4);
  const auto completed = waypoint::projectTaskDefinitions({task}, {}, today).first().toObject();
  QVERIFY(completed.value(QStringLiteral("completed")).toBool());
  QVERIFY(completed.value(QStringLiteral("completionLate")).toBool());
  QVERIFY(completed.value(QStringLiteral("pendingDate")).toString().isEmpty());
  QVERIFY(!completed.value(QStringLiteral("overdue")).toBool());
}

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
void RecurrenceTest::keepSkippedOccurrenceVisibleWhileAdvancingRecurrence() {
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

  const auto skippedToday = waypoint::projectActionableOccurrences({task}, states, QDate(2026, 1, 3));
  QCOMPARE(skippedToday.size(), 1);
  QVERIFY(skippedToday.first().skipped);
  QVERIFY(!skippedToday.first().completed);
  QVERIFY(skippedToday.first().toJson().value(QStringLiteral("skipped")).toBool());

  const auto projected = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, states, QDate(2026, 1, 1), QDate(2026, 1, 3)), {task}, states,
      QDate(2026, 1, 3));
  QCOMPARE(projected.size(), 3);
  QVERIFY(projected.at(2).skipped);
  QVERIFY(projected.at(2).calendarMarker);

  const auto nextDay = waypoint::projectActionableOccurrences({task}, states, QDate(2026, 1, 4));
  QCOMPARE(nextDay.size(), 1);
  QCOMPARE(nextDay.first().occurrenceDate, QDate(2026, 1, 4));
  QVERIFY(!nextDay.first().skipped);
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
  QVERIFY(afterCompletion.at(0).calendarMarker);
  QVERIFY(afterCompletion.at(1).calendarMarker);
  QVERIFY(!afterCompletion.at(2).calendarMarker);

  waypoint::TaskOccurrenceState completedToday = resolved;
  completedToday.occurrenceDate = today;
  const QList<waypoint::TaskOccurrenceState> completedThroughToday{resolved, completedToday};
  const auto nextPending = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, completedThroughToday, yesterday, tomorrow), {task},
      completedThroughToday, today);
  QCOMPARE(nextPending.size(), 3);
  QVERIFY(nextPending.at(0).calendarMarker);
  QVERIFY(nextPending.at(1).calendarMarker);
  QVERIFY(nextPending.at(2).calendarMarker);

  resolved.status = waypoint::OccurrenceStatus::Skipped;
  const auto afterSkip = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, {resolved}, yesterday, tomorrow), {task}, {resolved}, today);
  QCOMPARE(afterSkip.size(), 3);
  QCOMPARE(afterSkip.at(0).occurrenceDate, yesterday);
  QVERIFY(afterSkip.at(0).skipped);
  QVERIFY(afterSkip.at(0).calendarMarker);
  QVERIFY(afterSkip.at(1).calendarMarker);
  QVERIFY(!afterSkip.at(2).calendarMarker);
}

void RecurrenceTest::keepLateMonthlyCompletionOnDueDay() {
  waypoint::TaskRecord task;
  task.id = QStringLiteral("vivo-easy");
  task.title = QStringLiteral("Vivo Easy");
  task.scheduledDate = QDate(2026, 9, 19);
  task.scheduledTime = QTime(9, 0);
  task.recurrence.frequency = waypoint::RecurrenceFrequency::Monthly;

  waypoint::TaskOccurrenceState completed;
  completed.taskId = task.id;
  completed.occurrenceDate = QDate(2026, 9, 19);
  completed.status = waypoint::OccurrenceStatus::Completed;
  completed.completedDate = QDate(2026, 9, 20);
  completed.registeredAt = QDateTime(QDate(2026, 9, 21), QTime(12, 0));

  const QDate completionDay(2026, 9, 21);
  const auto calendarOccurrences = waypoint::assignCalendarMarkers(
      waypoint::projectOccurrences({task}, {completed}, task.scheduledDate, completionDay), {task}, {completed},
      completionDay);
  QCOMPARE(calendarOccurrences.size(), 1);
  QCOMPARE(calendarOccurrences.first().occurrenceDate, QDate(2026, 9, 19));
  QCOMPARE(calendarOccurrences.first().calendarDate, task.scheduledDate);
  QVERIFY(calendarOccurrences.first().completed);
  QVERIFY(calendarOccurrences.first().calendarMarker);

  const auto todayOccurrences = waypoint::projectActionableOccurrences({task}, {completed}, completionDay);
  QVERIFY(todayOccurrences.isEmpty());
  QVERIFY(waypoint::projectOccurrences({task}, {completed}, completionDay, completionDay).isEmpty());
  const auto dueDay = waypoint::projectActionableOccurrences({task}, {completed}, task.scheduledDate);
  QCOMPARE(dueDay.first().completedDate, completed.completedDate);
  QCOMPARE(dueDay.first().registeredAt, completed.registeredAt);

  const auto octoberOccurrences =
      waypoint::projectOccurrences({task}, {completed}, QDate(2026, 10, 19), QDate(2026, 10, 19));
  QCOMPARE(octoberOccurrences.size(), 1);
  QCOMPARE(octoberOccurrences.first().occurrenceDate, QDate(2026, 10, 19));
  QCOMPARE(octoberOccurrences.first().calendarDate, QDate(2026, 10, 19));
  QVERIFY(!octoberOccurrences.first().completed);
}

void RecurrenceTest::distinguishActualCompletionFromRegistration() {
  waypoint::TaskOccurrence occurrence;
  occurrence.completed = true;
  occurrence.occurrenceDate = QDate(2026, 12, 31);
  occurrence.completedDate = occurrence.occurrenceDate;
  occurrence.registeredAt = QDateTime(QDate(2027, 1, 2), QTime(12, 0));
  QVERIFY(!occurrence.completionLate());
  QVERIFY(occurrence.completionLabel().contains(QStringLiteral("31/12/2026")));
  QVERIFY(occurrence.completionLabel().contains(QStringLiteral("REGISTRADA")));
  occurrence.completedDate = QDate(2027, 1, 1);
  QVERIFY(occurrence.completionLate());
  QVERIFY(!occurrence.completionLabel().contains(QStringLiteral("REGISTRADA")));
  occurrence.completedDate = {};
  QVERIFY(!occurrence.completionLate());
  QVERIFY(occurrence.completionLabel().contains(QStringLiteral("REGISTRADA")));
  QCOMPARE(occurrence.toJson().value(QStringLiteral("completedDate")).toString(), QString());
  occurrence.completed = false;
  QVERIFY(occurrence.completionLabel().isEmpty());
}

void RecurrenceTest::decodeLegacyCompletionWithoutInventingActualDay() {
  QJsonObject payload{
      {QStringLiteral("completed"), true},
      {QStringLiteral("status"), QStringLiteral("completed")},
      {QStringLiteral("completedAt"), QStringLiteral("2026-09-21T12:00:00.000Z")},
      {QStringLiteral("updatedAt"), QStringLiteral("2026-09-22T12:00:00.000Z")},
  };
  const QDateTime registered = QDateTime::fromString(payload.value(QStringLiteral("completedAt")).toString(), Qt::ISODateWithMs);
  auto task = waypoint::TaskRecord::fromJson(payload);
  auto state = waypoint::TaskOccurrenceState::fromJson(payload);
  QCOMPARE(task.registeredAt, registered);
  QCOMPARE(state.registeredAt, registered);
  QVERIFY(!task.completedDate.isValid());
  QVERIFY(!state.completedDate.isValid());
  QVERIFY(!task.toJson().contains(QStringLiteral("completedAt")));
  QVERIFY(!state.toJson().contains(QStringLiteral("completedAt")));
  payload.insert(QStringLiteral("registeredAt"), QString());
  task = waypoint::TaskRecord::fromJson(payload);
  state = waypoint::TaskOccurrenceState::fromJson(payload);
  QVERIFY(!task.registeredAt.isValid());
  QVERIFY(!state.registeredAt.isValid());
  payload.remove(QStringLiteral("registeredAt"));
  payload.remove(QStringLiteral("completedAt"));
  QVERIFY(!waypoint::TaskRecord::fromJson(payload).registeredAt.isValid());
  QVERIFY(!waypoint::TaskOccurrenceState::fromJson(payload).registeredAt.isValid());
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

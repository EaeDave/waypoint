#include "app/CalendarModel.hpp"
#include "app/TaskListModel.hpp"

#include <QtTest>

class AppModelsTest final : public QObject {
  Q_OBJECT

private slots:
  void aggregateTaskMarkersByCalendarDate();
  void showOnlyEligibleRecurringTaskMarkers();
  void aggregateHolidayMarkersByCalendarDate();
  void includeOverdueTasksOnlyInTodayView();
  void showOnlyCurrentRecurringOccurrenceInDateLists();
  void exposeSkippedRecurringOccurrence();
  void sortTasksByFloatingLocalTime();
  void exposeEmojiRoleWithoutBreakingLegacyTasks();
};

namespace {

waypoint::TaskOccurrence occurrence(QString id, const QDate &date, bool completed, bool recurring = false,
                                    const QTime &scheduledTime = QTime(9, 0)) {
  waypoint::TaskOccurrence value;
  value.taskId = std::move(id);
  value.title = QStringLiteral("Task %1").arg(value.taskId);
  value.occurrenceDate = date;
  value.scheduledTime = scheduledTime;
  value.completed = completed;
  value.recurring = recurring;
  value.recurrenceLabel = recurring ? QStringLiteral("DIÁRIA") : QString();
  if (recurring) {
    value.recurrence.frequency = waypoint::RecurrenceFrequency::Daily;
  }
  return value;
}

} // namespace

void AppModelsTest::aggregateTaskMarkersByCalendarDate() {
  waypoint::CalendarModel model;
  const QDate today = QDate::currentDate();
  model.setSourceOccurrences(
      {occurrence(QStringLiteral("pending"), today, false), occurrence(QStringLiteral("done"), today, true)});

  bool foundToday = false;
  for (int row = 0; row < model.rowCount(); ++row) {
    const QModelIndex index = model.index(row, 0);
    if (model.data(index, waypoint::CalendarModel::DateRole).toString() != today.toString(Qt::ISODate)) {
      continue;
    }
    foundToday = true;
    QCOMPARE(model.data(index, waypoint::CalendarModel::PendingCountRole).toInt(), 1);
    QCOMPARE(model.data(index, waypoint::CalendarModel::CompletedCountRole).toInt(), 1);
  }
  QVERIFY(foundToday);
}

void AppModelsTest::showOnlyEligibleRecurringTaskMarkers() {
  waypoint::CalendarModel model;
  const QDate today = QDate::currentDate();
  const QDate tomorrow = today.addDays(1);
  waypoint::TaskOccurrence hiddenFuture =
      occurrence(QStringLiteral("hidden-recurring-tomorrow"), tomorrow, false, true);
  hiddenFuture.calendarMarker = false;
  waypoint::TaskOccurrence hiddenCompleted =
      occurrence(QStringLiteral("completed-recurring-tomorrow"), tomorrow, true, true);
  hiddenCompleted.calendarMarker = false;
  model.setSourceOccurrences({
      occurrence(QStringLiteral("recurring-today"), today, false, true),
      occurrence(QStringLiteral("next-recurring-tomorrow"), tomorrow, false, true),
      hiddenFuture,
      hiddenCompleted,
      occurrence(QStringLiteral("one-off-tomorrow"), tomorrow, false),
  });

  const auto countForDate = [&model](const QDate &date, const waypoint::CalendarModel::Role role) {
    for (int row = 0; row < model.rowCount(); ++row) {
      const QModelIndex index = model.index(row, 0);
      if (model.data(index, waypoint::CalendarModel::DateRole).toString() == date.toString(Qt::ISODate)) {
        return model.data(index, role).toInt();
      }
    }
    return -1;
  };

  QCOMPARE(countForDate(today, waypoint::CalendarModel::PendingCountRole), 1);
  QCOMPARE(countForDate(tomorrow, waypoint::CalendarModel::PendingCountRole), 2);
  QCOMPARE(countForDate(tomorrow, waypoint::CalendarModel::CompletedCountRole), 0);
}

void AppModelsTest::aggregateHolidayMarkersByCalendarDate() {
  waypoint::CalendarModel model;
  const QDate today = QDate::currentDate();
  model.setSourceHolidays({
      QJsonObject{{QStringLiteral("date"), today.toString(Qt::ISODate)},
                  {QStringLiteral("name"), QStringLiteral("Feriado legal")},
                  {QStringLiteral("kind"), QStringLiteral("legal")}},
      QJsonObject{{QStringLiteral("date"), today.toString(Qt::ISODate)},
                  {QStringLiteral("name"), QStringLiteral("Ponto facultativo")},
                  {QStringLiteral("kind"), QStringLiteral("optional")}},
      QJsonObject{{QStringLiteral("date"), today.toString(Qt::ISODate)},
                  {QStringLiteral("name"), QStringLiteral("Data comemorativa")},
                  {QStringLiteral("kind"), QStringLiteral("commemorative")}},
  });

  for (int row = 0; row < model.rowCount(); ++row) {
    const QModelIndex index = model.index(row, 0);
    if (model.data(index, waypoint::CalendarModel::DateRole).toString() != today.toString(Qt::ISODate)) {
      continue;
    }
    QCOMPARE(model.data(index, waypoint::CalendarModel::HolidayCountRole).toInt(), 3);
    QCOMPARE(model.data(index, waypoint::CalendarModel::HolidayKindRole).toString(), QStringLiteral("legal"));
    QCOMPARE(model.data(index, waypoint::CalendarModel::HolidayNamesRole).toStringList().size(), 3);
    return;
  }
  QFAIL("today is absent from the visible calendar grid");
}

void AppModelsTest::includeOverdueTasksOnlyInTodayView() {
  const QDate today = QDate::currentDate();
  waypoint::TaskListModel model;
  model.setSourceOccurrences({occurrence(QStringLiteral("overdue"), today.addDays(-1), false),
                              occurrence(QStringLiteral("today"), today, false, true),
                              occurrence(QStringLiteral("tomorrow"), today.addDays(1), false)});

  model.setFocusDate(today);
  QCOMPARE(model.rowCount(), 2);
  QCOMPARE(model.overdueCount(), 1);

  model.setFocusDate(today.addDays(1));
  QCOMPARE(model.rowCount(), 1);
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("tomorrow"));
  model.setFocusDate(today);
  QCOMPARE(model.data(model.index(1, 0), waypoint::TaskListModel::RecurringRole).toBool(), true);
  QCOMPARE(model.data(model.index(1, 0), waypoint::TaskListModel::RecurrenceLabelRole).toString(),
           QStringLiteral("DIÁRIA"));
  QCOMPARE(model.data(model.index(1, 0), waypoint::TaskListModel::RecurrenceRole)
               .toMap()
               .value(QStringLiteral("frequency"))
               .toString(),
           QStringLiteral("daily"));
}

void AppModelsTest::showOnlyCurrentRecurringOccurrenceInDateLists() {
  const QDate today = QDate::currentDate();
  const QDate tomorrow = today.addDays(1);
  const QDate later = today.addDays(5);
  waypoint::TaskOccurrence completedToday = occurrence(QStringLiteral("completed-today"), today, true, true);
  completedToday.calendarMarker = false;
  waypoint::TaskOccurrence projectedLater = occurrence(QStringLiteral("projected-later"), later, false, true);
  projectedLater.calendarMarker = false;

  waypoint::TaskListModel model;
  model.setSourceOccurrences({
      completedToday,
      occurrence(QStringLiteral("current-tomorrow"), tomorrow, false, true),
      projectedLater,
      occurrence(QStringLiteral("one-off-later"), later, false),
  });

  model.setFocusDate(later);
  QCOMPARE(model.rowCount(), 1);
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("one-off-later"));

  model.setFocusDate(tomorrow);
  QCOMPARE(model.rowCount(), 1);
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("current-tomorrow"));

  model.setFocusDate(today);
  QCOMPARE(model.rowCount(), 1);
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("completed-today"));
}

void AppModelsTest::exposeSkippedRecurringOccurrence() {
  const QDate skippedDate = QDate::currentDate().addDays(-1);
  waypoint::TaskOccurrence skipped =
      occurrence(QStringLiteral("skipped-recurring"), skippedDate, false, true);
  skipped.skipped = true;
  skipped.calendarMarker = true;

  waypoint::TaskListModel tasks;
  tasks.setSourceOccurrences({skipped});
  tasks.setFocusDate(skippedDate);
  QCOMPARE(tasks.rowCount(), 1);
  QCOMPARE(tasks.pendingCount(), 0);
  QCOMPARE(tasks.overdueCount(), 0);
  QCOMPARE(tasks.skippedCount(), 1);
  QVERIFY(tasks.data(tasks.index(0, 0), waypoint::TaskListModel::SkippedRole).toBool());
  QCOMPARE(tasks.roleNames().value(waypoint::TaskListModel::SkippedRole), QByteArrayLiteral("skipped"));

  waypoint::CalendarModel calendar;
  calendar.setSourceOccurrences({skipped});
  for (int row = 0; row < calendar.rowCount(); ++row) {
    const QModelIndex index = calendar.index(row, 0);
    if (calendar.data(index, waypoint::CalendarModel::DateRole).toString() ==
        skippedDate.toString(Qt::ISODate)) {
      QCOMPARE(calendar.data(index, waypoint::CalendarModel::PendingCountRole).toInt(), 0);
      QCOMPARE(calendar.data(index, waypoint::CalendarModel::SkippedCountRole).toInt(), 1);
      return;
    }
  }
  QFAIL("skipped date is absent from the visible calendar grid");
}

void AppModelsTest::exposeEmojiRoleWithoutBreakingLegacyTasks() {
  const QDate today = QDate::currentDate();
  waypoint::TaskOccurrence decorated = occurrence(QStringLiteral("decorated"), today, false);
  decorated.emoji = QStringLiteral("👨‍💻");
  decorated.reminderMinutesBefore = {60, 30, 0};
  waypoint::TaskListModel model;
  model.setSourceOccurrences(
      {decorated, occurrence(QStringLiteral("legacy"), today, false, false, QTime(10, 0))});

  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::EmojiRole).toString(),
           QStringLiteral("👨‍💻"));
  QCOMPARE(model.data(model.index(1, 0), waypoint::TaskListModel::EmojiRole).toString(), QString());
  QCOMPARE(model.roleNames().value(waypoint::TaskListModel::EmojiRole), QByteArrayLiteral("emoji"));
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::ReminderMinutesBeforeRole).toList(),
           QVariantList({60, 30, 0}));
  QCOMPARE(model.data(model.index(1, 0), waypoint::TaskListModel::ReminderMinutesBeforeRole).toList(),
           QVariantList({0}));
  QCOMPARE(model.roleNames().value(waypoint::TaskListModel::ReminderMinutesBeforeRole),
           QByteArrayLiteral("reminderMinutesBefore"));
}
void AppModelsTest::sortTasksByFloatingLocalTime() {
  const QDate today = QDate::currentDate();
  waypoint::TaskListModel model;
  model.setSourceOccurrences(
      {occurrence(QStringLiteral("late"), today, false, false, QTime(17, 45)),
       occurrence(QStringLiteral("completed-early"), today, true, false, QTime(6, 30)),
       occurrence(QStringLiteral("early"), today, false, false, QTime(8, 15))});

  QCOMPARE(model.rowCount(), 3);
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("early"));
  QCOMPARE(model.data(model.index(1, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("late"));
  QCOMPARE(model.data(model.index(2, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("completed-early"));
}

QTEST_MAIN(AppModelsTest)
#include "AppModelsTest.moc"

#include "app/CalendarModel.hpp"
#include "app/TaskListModel.hpp"

#include <QtTest>

class AppModelsTest final : public QObject {
  Q_OBJECT

private slots:
  void aggregateTaskMarkersByCalendarDate();
  void aggregateHolidayMarkersByCalendarDate();
  void includeOverdueTasksOnlyInTodayView();
  void sortTasksByFloatingLocalTime();
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
}
void AppModelsTest::sortTasksByFloatingLocalTime() {
  const QDate today = QDate::currentDate();
  waypoint::TaskListModel model;
  model.setSourceOccurrences({occurrence(QStringLiteral("late"), today, false, false, QTime(17, 45)),
                              occurrence(QStringLiteral("early"), today, false, false, QTime(8, 15))});

  QCOMPARE(model.rowCount(), 2);
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("early"));
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::ScheduledTimeRole).toString(),
           QStringLiteral("08:15"));
}

QTEST_MAIN(AppModelsTest)
#include "AppModelsTest.moc"

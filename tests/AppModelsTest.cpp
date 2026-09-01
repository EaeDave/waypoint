#include "app/CalendarModel.hpp"
#include "app/TaskListModel.hpp"

#include <QtTest>

class AppModelsTest final : public QObject {
  Q_OBJECT

private slots:
  void aggregateTaskMarkersByCalendarDate();
  void includeOverdueTasksOnlyInTodayView();
};

namespace {

waypoint::TaskRecord task(QString id, const QDate &date, bool completed) {
  waypoint::TaskRecord record;
  record.id = std::move(id);
  record.title = QStringLiteral("Task %1").arg(record.id);
  record.scheduledDate = date;
  record.completed = completed;
  record.createdAt = QDateTime::currentDateTimeUtc();
  record.updatedAt = record.createdAt;
  record.version = 1;
  return record;
}

} // namespace

void AppModelsTest::aggregateTaskMarkersByCalendarDate() {
  waypoint::CalendarModel model;
  const QDate today = QDate::currentDate();
  model.setSourceTasks(
      {task(QStringLiteral("pending"), today, false), task(QStringLiteral("done"), today, true)});

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

void AppModelsTest::includeOverdueTasksOnlyInTodayView() {
  const QDate today = QDate::currentDate();
  waypoint::TaskListModel model;
  model.setSourceTasks({task(QStringLiteral("overdue"), today.addDays(-1), false),
                        task(QStringLiteral("today"), today, false),
                        task(QStringLiteral("tomorrow"), today.addDays(1), false)});

  model.setFocusDate(today);
  QCOMPARE(model.rowCount(), 2);
  QCOMPARE(model.overdueCount(), 1);

  model.setFocusDate(today.addDays(1));
  QCOMPARE(model.rowCount(), 1);
  QCOMPARE(model.data(model.index(0, 0), waypoint::TaskListModel::TaskIdRole).toString(),
           QStringLiteral("tomorrow"));
}

QTEST_MAIN(AppModelsTest)
#include "AppModelsTest.moc"

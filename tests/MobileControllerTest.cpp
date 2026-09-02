#include "mobile/MobileController.hpp"
#include "mobile/NotificationSchedule.hpp"

#include <QJsonArray>
#include <QJsonObject>
#include <QTemporaryDir>
#include <QtTest>

class MobileControllerTest final : public QObject {
  Q_OBJECT

private slots:
  void exposeTaskAndHabitWorkflows();
  void showOnlyFirstPendingRecurrenceOnCalendar();
  void exposeCachedMunicipalities();
  void buildFutureTaskAndHabitNotifications();
};

void MobileControllerTest::exposeTaskAndHabitWorkflows() {
  QTemporaryDir directory;
  waypoint::MobileController controller(directory.filePath(QStringLiteral("waypoint.sqlite3")), nullptr);
  controller.start();
  QVERIFY(controller.ready());

  const QDate today = QDate::currentDate();
  const QVariantList weekday{today.dayOfWeek()};
  QVERIFY(controller.saveTask({}, QStringLiteral("Enviar relatório"), today.toString(Qt::ISODate),
                              QStringLiteral("12:30"), QStringLiteral("weekly"), 2, weekday,
                              QStringLiteral("afterCount"), {}, 4, QVariantList{0, 30},
                              QStringLiteral("📤")));
  QCOMPARE(controller.todayTasks().size(), 1);
  const QVariantMap task = controller.todayTasks().first().toMap();
  QCOMPARE(task.value(QStringLiteral("title")).toString(), QStringLiteral("Enviar relatório"));
  QCOMPARE(task.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("12:30"));
  const QVariantMap recurrence = task.value(QStringLiteral("recurrence")).toMap();
  QCOMPARE(recurrence.value(QStringLiteral("frequency")).toString(), QStringLiteral("weekly"));
  QCOMPARE(recurrence.value(QStringLiteral("endMode")).toString(), QStringLiteral("afterCount"));
  QCOMPARE(recurrence.value(QStringLiteral("occurrenceCount")).toInt(), 4);

  QVERIFY(controller.setTaskCompleted(task.value(QStringLiteral("taskId")).toString(),
                                      today.toString(Qt::ISODate), true, true));
  QVERIFY(controller.todayTasks().first().toMap().value(QStringLiteral("completed")).toBool());

  QVERIFY(controller.saveHabit(
      {}, QStringLiteral("Água"), 8, QStringLiteral("copos"), QStringLiteral("fixed"), 2, weekday,
      QVariantList{QStringLiteral("09:00"), QStringLiteral("15:00")}, QStringLiteral("💧")));
  QCOMPARE(controller.allHabits().size(), 1);
  QCOMPARE(controller.todayHabits().size(), 1);
  const QString habitId = controller.allHabits().first().toMap().value(QStringLiteral("id")).toString();
  QVERIFY(controller.recordHabit(habitId));
  QCOMPARE(controller.todayHabits().first().toMap().value(QStringLiteral("amount")).toLongLong(), 2);
  QVERIFY(controller.undoHabit(habitId));
  QCOMPARE(controller.todayHabits().first().toMap().value(QStringLiteral("amount")).toLongLong(), 0);
}

void MobileControllerTest::showOnlyFirstPendingRecurrenceOnCalendar() {
  QTemporaryDir directory;
  waypoint::MobileController controller(directory.filePath(QStringLiteral("waypoint.sqlite3")), nullptr);
  controller.start();
  QVERIFY(controller.ready());

  const QDate today = QDate::currentDate();
  QVERIFY(controller.saveTask({}, QStringLiteral("Rotina diária"), today.toString(Qt::ISODate),
                              QStringLiteral("09:00"), QStringLiteral("daily"), 1, {},
                              QStringLiteral("never"), {}, 0, {}, QStringLiteral("✓")));

  QCOMPARE(controller.selectedTasks().size(), 1);
  const QVariantMap todayTask = controller.selectedTasks().first().toMap();
  QCOMPARE(todayTask.value(QStringLiteral("recurrenceLabel")).toString(), QStringLiteral("DIÁRIA"));
  QVERIFY(controller.setTaskCompleted(todayTask.value(QStringLiteral("taskId")).toString(),
                                      today.toString(Qt::ISODate), true, true));
  QCOMPARE(controller.selectedTasks().size(), 1);
  QVERIFY(controller.selectedTasks().first().toMap().value(QStringLiteral("completed")).toBool());

  controller.setSelectedDateKey(today.addDays(1).toString(Qt::ISODate));
  QCOMPARE(controller.selectedTasks().size(), 1);
  const QVariantMap nextPending = controller.selectedTasks().first().toMap();
  QCOMPARE(nextPending.value(QStringLiteral("occurrenceDate")).toString(),
           today.addDays(1).toString(Qt::ISODate));
  QCOMPARE(nextPending.value(QStringLiteral("recurrenceLabel")).toString(), QStringLiteral("DIÁRIA"));

  controller.setSelectedDateKey(today.addDays(5).toString(Qt::ISODate));
  QCOMPARE(controller.selectedTasks().size(), 0);
}

void MobileControllerTest::exposeCachedMunicipalities() {
  QTemporaryDir directory;
  const QString databasePath = directory.filePath(QStringLiteral("waypoint.sqlite3"));
  {
    waypoint::TaskStore store(databasePath);
    QString error;
    QVERIFY2(store.open(&error), qPrintable(error));
    const QJsonArray municipalities{
        QJsonObject{{QStringLiteral("code"), QStringLiteral("3302403")},
                    {QStringLiteral("name"), QStringLiteral("Macaé")}},
    };
    QVERIFY2(store.replaceMunicipalities(QStringLiteral("RJ"), municipalities, &error), qPrintable(error));
  }

  waypoint::MobileController controller(databasePath, nullptr);
  controller.start();
  controller.loadMunicipalities(QStringLiteral("RJ"));
  QCOMPARE(controller.municipalities().size(), 1);
  const QVariantMap municipality = controller.municipalities().first().toMap();
  QCOMPARE(municipality.value(QStringLiteral("code")).toString(), QStringLiteral("3302403"));
  QCOMPARE(municipality.value(QStringLiteral("name")).toString(), QStringLiteral("Macaé"));
}

void MobileControllerTest::buildFutureTaskAndHabitNotifications() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("waypoint.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));

  const QDate date(2026, 9, 1);
  const QDateTime now(date, QTime(8, 0));
  waypoint::TaskRecord task;
  QVERIFY2(store.createTask(QStringLiteral("Consulta"), date, QTime(9, 0), {}, {0, 30}, QStringLiteral("🩺"),
                            &task, &error),
           qPrintable(error));
  waypoint::HabitRecord habit;
  QVERIFY2(store.createHabit(QStringLiteral("Água"), 2, QStringLiteral("copos"),
                             waypoint::HabitCheckInMode::CompleteAll, 1, {date.dayOfWeek()}, {QTime(10, 0)},
                             QStringLiteral("💧"), &habit, &error),
           qPrintable(error));

  QJsonArray schedule;
  QVERIFY2(waypoint::buildNotificationSchedule(store, now, 0, &schedule, &error), qPrintable(error));
  QCOMPARE(schedule.size(), 3);
  QCOMPARE(schedule.at(0).toObject().value(QStringLiteral("key")).toString(),
           QStringLiteral("task:%1@2026-09-01:0").arg(task.id));
  QCOMPARE(schedule.at(1).toObject().value(QStringLiteral("key")).toString(),
           QStringLiteral("task:%1@2026-09-01:30").arg(task.id));
  QCOMPARE(schedule.at(2).toObject().value(QStringLiteral("key")).toString(),
           QStringLiteral("habit:%1@2026-09-01:10:00").arg(habit.id));

  QVERIFY2(store.recordHabit(habit.id, date, std::nullopt, nullptr, &error), qPrintable(error));
  QVERIFY2(waypoint::buildNotificationSchedule(store, now, 0, &schedule, &error), qPrintable(error));
  QCOMPARE(schedule.size(), 2);
}

QTEST_MAIN(MobileControllerTest)
#include "MobileControllerTest.moc"

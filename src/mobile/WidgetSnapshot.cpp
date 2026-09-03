#include "mobile/WidgetSnapshot.hpp"

#include "core/TaskStore.hpp"

#include <QJsonArray>

namespace waypoint {
namespace {

void setError(QString *errorMessage, const QString &message) {
  if (errorMessage != nullptr) {
    *errorMessage = message;
  }
}

QJsonObject occurrenceValue(const TaskOccurrence &occurrence, const QDate &today) {
  QJsonObject value = occurrence.toJson();
  value.insert(QStringLiteral("overdue"), occurrence.occurrenceDate < today && !occurrence.completed);
  return value;
}

QJsonArray occurrenceValues(const QList<TaskOccurrence> &occurrences, const QDate &today,
                            const bool calendarOnly) {
  QJsonArray values;
  for (const TaskOccurrence &occurrence : occurrences) {
    if (calendarOnly && occurrence.recurring && !occurrence.calendarMarker) {
      continue;
    }
    values.append(occurrenceValue(occurrence, today));
  }
  return values;
}

QJsonArray habitValues(const QList<HabitProgress> &progress) {
  QJsonArray values;
  for (const HabitProgress &habit : progress) {
    values.append(habit.toJson());
  }
  return values;
}

void setTasksForDate(QJsonObject *dates, const QString &dateKey, const QJsonArray &tasks) {
  QJsonObject date = dates->value(dateKey).toObject();
  date.insert(QStringLiteral("tasks"), tasks);
  dates->insert(dateKey, date);
}

void appendTask(QJsonObject *dates, const TaskOccurrence &occurrence, const QDate &today) {
  const QString dateKey = occurrence.occurrenceDate.toString(Qt::ISODate);
  QJsonObject date = dates->value(dateKey).toObject();
  QJsonArray tasks = date.value(QStringLiteral("tasks")).toArray();
  tasks.append(occurrenceValue(occurrence, today));
  date.insert(QStringLiteral("tasks"), tasks);
  dates->insert(dateKey, date);
}

void appendHoliday(QJsonObject *dates, const QJsonObject &holiday) {
  const QString dateKey = holiday.value(QStringLiteral("date")).toString();
  if (dateKey.isEmpty()) {
    return;
  }
  QJsonObject date = dates->value(dateKey).toObject();
  QJsonArray holidays = date.value(QStringLiteral("holidays")).toArray();
  holidays.append(holiday);
  date.insert(QStringLiteral("holidays"), holidays);
  dates->insert(dateKey, date);
}

} // namespace

QJsonObject buildWidgetSnapshot(TaskStore &store, const QDate &today, const int monthsBefore,
                                const int monthsAfter, QString *errorMessage) {
  if (!today.isValid() || monthsBefore < 0 || monthsAfter < 0 || monthsBefore > 24 || monthsAfter > 24) {
    setError(errorMessage,
             QStringLiteral("Widget snapshot requires a valid date and a range of 0 to 24 months"));
    return {};
  }

  const QDate currentMonth(today.year(), today.month(), 1);
  const QDate rangeStart = currentMonth.addMonths(-monthsBefore);
  const QDate rangeEnd = currentMonth.addMonths(monthsAfter + 1).addDays(-1);
  QString error;
  const QList<TaskOccurrence> occurrences = store.listOccurrences(rangeStart, rangeEnd, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  const QList<TaskOccurrence> todayOccurrences = store.listActionableOccurrences(today, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  const QList<HabitProgress> habitProgress = store.listHabitProgress(today, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  const QJsonArray holidays = store.listHolidays(rangeStart, rangeEnd, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }

  QJsonObject dates;
  for (const TaskOccurrence &occurrence : occurrences) {
    if (!occurrence.recurring || occurrence.calendarMarker) {
      appendTask(&dates, occurrence, today);
    }
  }
  setTasksForDate(&dates, today.toString(Qt::ISODate), occurrenceValues(todayOccurrences, today, false));
  for (const QJsonValue &holiday : holidays) {
    appendHoliday(&dates, holiday.toObject());
  }

  setError(errorMessage, {});
  return {
      {QStringLiteral("schemaVersion"), 2},
      {QStringLiteral("today"), today.toString(Qt::ISODate)},
      {QStringLiteral("rangeStart"), rangeStart.toString(Qt::ISODate)},
      {QStringLiteral("rangeEnd"), rangeEnd.toString(Qt::ISODate)},
      {QStringLiteral("dates"), dates},
      {QStringLiteral("habits"), habitValues(habitProgress)},
  };
}

} // namespace waypoint

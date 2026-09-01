#include "core/TaskRecord.hpp"

namespace waypoint {

QJsonObject TaskRecord::toJson() const {
  return {
      {QStringLiteral("id"), id},
      {QStringLiteral("title"), title},
      {QStringLiteral("scheduledDate"),
       scheduledDate.isValid() ? scheduledDate.toString(Qt::ISODate) : QString()},
      {QStringLiteral("scheduledTime"),
       scheduledTime.isValid() ? scheduledTime.toString(QStringLiteral("HH:mm")) : QString()},
      {QStringLiteral("completed"), completed},
      {QStringLiteral("recurrence"), recurrence.toJson()},
      {QStringLiteral("createdAt"), createdAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("updatedAt"), updatedAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("version"), version},
  };
}

TaskRecord TaskRecord::fromJson(const QJsonObject &json) {
  TaskRecord task;
  task.id = json.value(QStringLiteral("id")).toString();
  task.title = json.value(QStringLiteral("title")).toString();
  task.scheduledDate = QDate::fromString(json.value(QStringLiteral("scheduledDate")).toString(), Qt::ISODate);
  task.scheduledTime =
      QTime::fromString(json.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("HH:mm"));
  task.completed = json.value(QStringLiteral("completed")).toBool();
  task.recurrence = RecurrenceRule::fromJson(json.value(QStringLiteral("recurrence")).toObject());
  task.createdAt =
      QDateTime::fromString(json.value(QStringLiteral("createdAt")).toString(), Qt::ISODateWithMs);
  task.updatedAt =
      QDateTime::fromString(json.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
  task.version = json.value(QStringLiteral("version")).toInteger();
  return task;
}

} // namespace waypoint

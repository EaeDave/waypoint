#include "core/TaskRecord.hpp"

#include <QSet>

#include <cmath>
#include <limits>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

bool validateTaskReminderMinutesBefore(const QList<int> &minutesBefore, QString *errorMessage) {
  if (minutesBefore.size() > maximumTaskReminderCount) {
    setError(errorMessage,
             QStringLiteral("A task can have at most %1 reminders").arg(maximumTaskReminderCount));
    return false;
  }

  QSet<int> unique;
  for (const int minutes : minutesBefore) {
    if (minutes < 0) {
      setError(errorMessage, QStringLiteral("Task reminder minutes must be non-negative"));
      return false;
    }
    if (unique.contains(minutes)) {
      setError(errorMessage, QStringLiteral("Task reminders cannot contain duplicate times"));
      return false;
    }
    unique.insert(minutes);
  }
  return true;
}

QJsonArray taskReminderMinutesBeforeToJson(const QList<int> &minutesBefore) {
  QJsonArray values;
  for (const int minutes : minutesBefore) {
    values.append(minutes);
  }
  return values;
}

QList<int> taskReminderMinutesBeforeFromJson(const QJsonValue &value) {
  if (value.isUndefined()) {
    return {0};
  }
  if (!value.isArray()) {
    return {-1};
  }

  QList<int> minutesBefore;
  const QJsonArray values = value.toArray();
  minutesBefore.reserve(values.size());
  for (const QJsonValue &item : values) {
    const double number = item.toDouble(-1.0);
    if (!item.isDouble() || std::floor(number) != number || number > std::numeric_limits<int>::max()) {
      return {-1};
    }
    minutesBefore.append(static_cast<int>(number));
  }
  return minutesBefore;
}

QJsonObject TaskRecord::toJson() const {
  return {
      {QStringLiteral("id"), id},
      {QStringLiteral("title"), title},
      {QStringLiteral("scheduledDate"),
       scheduledDate.isValid() ? scheduledDate.toString(Qt::ISODate) : QString()},
      {QStringLiteral("scheduledTime"),
       scheduledTime.isValid() ? scheduledTime.toString(QStringLiteral("HH:mm")) : QString()},
      {QStringLiteral("emoji"), emoji},
      {QStringLiteral("completed"), completed},
      {QStringLiteral("reminderMinutesBefore"), taskReminderMinutesBeforeToJson(reminderMinutesBefore)},
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
  task.emoji = json.value(QStringLiteral("emoji")).toString(QStringLiteral(""));
  task.completed = json.value(QStringLiteral("completed")).toBool();
  task.reminderMinutesBefore =
      taskReminderMinutesBeforeFromJson(json.value(QStringLiteral("reminderMinutesBefore")));
  task.recurrence = RecurrenceRule::fromJson(json.value(QStringLiteral("recurrence")).toObject());
  task.createdAt =
      QDateTime::fromString(json.value(QStringLiteral("createdAt")).toString(), Qt::ISODateWithMs);
  task.updatedAt =
      QDateTime::fromString(json.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
  task.version = json.value(QStringLiteral("version")).toInteger();
  return task;
}

} // namespace waypoint

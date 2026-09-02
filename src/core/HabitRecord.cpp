#include "core/HabitRecord.hpp"

#include <QJsonArray>
#include <QSet>
#include <QTextBoundaryFinder>

#include <algorithm>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

bool isSingleGrapheme(const QString &value) {
  if (value.isEmpty()) {
    return true;
  }
  if (value.size() > 64 || value.trimmed() != value) {
    return false;
  }
  QTextBoundaryFinder finder(QTextBoundaryFinder::Grapheme, value);
  finder.toStart();
  return finder.toNextBoundary() == value.size();
}

QList<int> weekdaysFromJson(const QJsonValue &value) {
  QList<int> weekdays;
  for (const QJsonValue &weekday : value.toArray()) {
    weekdays.append(weekday.toInt());
  }
  std::ranges::sort(weekdays);
  weekdays.erase(std::unique(weekdays.begin(), weekdays.end()), weekdays.end());
  return weekdays;
}

QList<QTime> reminderTimesFromJson(const QJsonValue &value) {
  QList<QTime> times;
  for (const QJsonValue &time : value.toArray()) {
    const QTime parsed = QTime::fromString(time.toString(), QStringLiteral("HH:mm"));
    if (parsed.isValid()) {
      times.append(parsed);
    }
  }
  std::ranges::sort(times);
  times.erase(std::unique(times.begin(), times.end()), times.end());
  return times;
}

QJsonArray weekdaysToJson(const QList<int> &weekdays) {
  QJsonArray result;
  for (const int weekday : weekdays) {
    result.append(weekday);
  }
  return result;
}

QJsonArray reminderTimesToJson(const QList<QTime> &times) {
  QJsonArray result;
  for (const QTime &time : times) {
    result.append(time.toString(QStringLiteral("HH:mm")));
  }
  return result;
}

} // namespace

QString habitCheckInModeName(const HabitCheckInMode mode) {
  switch (mode) {
  case HabitCheckInMode::Fixed:
    return QStringLiteral("fixed");
  case HabitCheckInMode::Manual:
    return QStringLiteral("manual");
  case HabitCheckInMode::CompleteAll:
    return QStringLiteral("complete");
  }
  return QStringLiteral("complete");
}

HabitCheckInMode habitCheckInModeFromName(const QString &name) {
  if (name == QStringLiteral("fixed")) {
    return HabitCheckInMode::Fixed;
  }
  if (name == QStringLiteral("manual")) {
    return HabitCheckInMode::Manual;
  }
  return HabitCheckInMode::CompleteAll;
}

bool HabitRecord::isScheduledOn(const QDate &date) const {
  return date.isValid() && weekdays.contains(date.dayOfWeek());
}

bool HabitRecord::isValid(QString *errorMessage) const {
  const QString normalizedTitle = title.trimmed();
  if (normalizedTitle.isEmpty() || normalizedTitle.size() > 500) {
    setError(errorMessage, QStringLiteral("Habit title must contain 1 to 500 characters"));
    return false;
  }
  if (targetAmount < 1 || targetAmount > maximumHabitAmount) {
    setError(errorMessage, QStringLiteral("Habit goal must be between 1 and %1").arg(maximumHabitAmount));
    return false;
  }
  if (unit.trimmed() != unit || unit.size() > 32 || unit.contains(u'\n') || unit.contains(u'\r')) {
    setError(errorMessage, QStringLiteral("Habit unit must be a single trimmed line of at most 32 characters"));
    return false;
  }
  if (incrementAmount < 1 || incrementAmount > maximumHabitAmount) {
    setError(errorMessage,
             QStringLiteral("Habit increment must be between 1 and %1").arg(maximumHabitAmount));
    return false;
  }
  if (checkInMode == HabitCheckInMode::Fixed && incrementAmount > targetAmount) {
    setError(errorMessage, QStringLiteral("Fixed habit increment cannot exceed its goal"));
    return false;
  }
  if (weekdays.isEmpty() || weekdays.size() > 7) {
    setError(errorMessage, QStringLiteral("Habit must be scheduled on at least one weekday"));
    return false;
  }
  QSet<int> uniqueWeekdays;
  for (const int weekday : weekdays) {
    if (weekday < 1 || weekday > 7 || uniqueWeekdays.contains(weekday)) {
      setError(errorMessage, QStringLiteral("Habit weekdays must be unique values from 1 to 7"));
      return false;
    }
    uniqueWeekdays.insert(weekday);
  }
  if (reminderTimes.size() > maximumHabitReminderCount) {
    setError(errorMessage,
             QStringLiteral("Habit supports at most %1 reminder times").arg(maximumHabitReminderCount));
    return false;
  }
  QSet<QTime> uniqueReminderTimes;
  for (const QTime &time : reminderTimes) {
    if (!time.isValid() || uniqueReminderTimes.contains(time)) {
      setError(errorMessage, QStringLiteral("Habit reminder times must be valid and unique"));
      return false;
    }
    uniqueReminderTimes.insert(time);
  }
  if (!isSingleGrapheme(emoji)) {
    setError(errorMessage, QStringLiteral("Habit emoji must contain at most one emoji"));
    return false;
  }
  return true;
}

QJsonObject HabitRecord::toJson() const {
  return {
      {QStringLiteral("id"), id},
      {QStringLiteral("title"), title},
      {QStringLiteral("targetAmount"), targetAmount},
      {QStringLiteral("unit"), unit},
      {QStringLiteral("checkInMode"), habitCheckInModeName(checkInMode)},
      {QStringLiteral("incrementAmount"), incrementAmount},
      {QStringLiteral("weekdays"), weekdaysToJson(weekdays)},
      {QStringLiteral("reminderTimes"), reminderTimesToJson(reminderTimes)},
      {QStringLiteral("emoji"), emoji},
      {QStringLiteral("createdAt"), createdAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("updatedAt"), updatedAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("version"), version},
  };
}

HabitRecord HabitRecord::fromJson(const QJsonObject &json) {
  HabitRecord habit;
  habit.id = json.value(QStringLiteral("id")).toString();
  habit.title = json.value(QStringLiteral("title")).toString();
  habit.targetAmount = json.value(QStringLiteral("targetAmount")).toInteger(1);
  habit.unit = json.value(QStringLiteral("unit")).toString();
  habit.checkInMode = habitCheckInModeFromName(json.value(QStringLiteral("checkInMode")).toString());
  habit.incrementAmount = json.value(QStringLiteral("incrementAmount")).toInteger(1);
  habit.weekdays = weekdaysFromJson(json.value(QStringLiteral("weekdays")));
  habit.reminderTimes = reminderTimesFromJson(json.value(QStringLiteral("reminderTimes")));
  habit.emoji = json.value(QStringLiteral("emoji")).toString();
  habit.createdAt = QDateTime::fromString(json.value(QStringLiteral("createdAt")).toString(), Qt::ISODateWithMs);
  habit.updatedAt = QDateTime::fromString(json.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
  habit.version = json.value(QStringLiteral("version")).toInteger();
  return habit;
}

bool HabitEntry::isValid(QString *errorMessage) const {
  if (id.isEmpty() || habitId.isEmpty()) {
    setError(errorMessage, QStringLiteral("Habit entry requires identifiers"));
    return false;
  }
  if (!entryDate.isValid()) {
    setError(errorMessage, QStringLiteral("Habit entry requires a valid calendar date"));
    return false;
  }
  if (amount < 1 || amount > maximumHabitAmount) {
    setError(errorMessage,
             QStringLiteral("Habit entry amount must be between 1 and %1").arg(maximumHabitAmount));
    return false;
  }
  return true;
}

QJsonObject HabitEntry::toJson() const {
  return {
      {QStringLiteral("id"), id},
      {QStringLiteral("habitId"), habitId},
      {QStringLiteral("entryDate"), entryDate.toString(Qt::ISODate)},
      {QStringLiteral("amount"), amount},
      {QStringLiteral("loggedAt"), loggedAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("updatedAt"), updatedAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("version"), version},
  };
}

HabitEntry HabitEntry::fromJson(const QJsonObject &json) {
  HabitEntry entry;
  entry.id = json.value(QStringLiteral("id")).toString();
  entry.habitId = json.value(QStringLiteral("habitId")).toString();
  entry.entryDate = QDate::fromString(json.value(QStringLiteral("entryDate")).toString(), Qt::ISODate);
  entry.amount = json.value(QStringLiteral("amount")).toInteger();
  entry.loggedAt = QDateTime::fromString(json.value(QStringLiteral("loggedAt")).toString(), Qt::ISODateWithMs);
  entry.updatedAt = QDateTime::fromString(json.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
  entry.version = json.value(QStringLiteral("version")).toInteger();
  return entry;
}

bool HabitProgress::completed() const { return amount >= habit.targetAmount; }

QJsonObject HabitProgress::toJson() const {
  QJsonObject result = habit.toJson();
  result.insert(QStringLiteral("date"), date.toString(Qt::ISODate));
  result.insert(QStringLiteral("amount"), amount);
  result.insert(QStringLiteral("remainingAmount"), std::max<qint64>(0, habit.targetAmount - amount));
  result.insert(QStringLiteral("completed"), completed());
  return result;
}

} // namespace waypoint

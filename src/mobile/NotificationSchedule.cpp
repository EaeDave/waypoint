#include "mobile/NotificationSchedule.hpp"

#include "core/TaskStore.hpp"

#include <QHash>
#include <QJsonObject>

#include <algorithm>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

QJsonObject scheduledNotification(const QString &key, const QDateTime &trigger, const QString &title,
                                  const QString &body) {
  return {
      {QStringLiteral("key"), key},
      {QStringLiteral("at"), trigger.toMSecsSinceEpoch()},
      {QStringLiteral("title"), title},
      {QStringLiteral("body"), body},
  };
}

QString decoratedTitle(const QString &emoji, const QString &title) {
  return emoji.isEmpty() ? title : QStringLiteral("%1  %2").arg(emoji, title);
}

} // namespace

bool buildNotificationSchedule(TaskStore &store, const QDateTime &now, const int horizonDays,
                               QJsonArray *schedule, QString *errorMessage) {
  if (!now.isValid() || horizonDays < 0 || schedule == nullptr) {
    setError(errorMessage, QStringLiteral("Invalid notification schedule request"));
    return false;
  }

  const QDate firstDate = now.date();
  const QDate lastDate = firstDate.addDays(horizonDays);
  QString error;
  const QList<TaskOccurrence> occurrences = store.listOccurrences(firstDate, lastDate, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }
  const QList<HabitRecord> habits = store.listActiveHabits(&error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }
  const QList<HabitProgress> todayProgress = store.listHabitProgress(firstDate, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }

  QHash<QString, bool> completedToday;
  for (const HabitProgress &progress : todayProgress) {
    completedToday.insert(progress.habit.id, progress.completed());
  }

  QList<QJsonObject> notifications;
  for (const TaskOccurrence &occurrence : occurrences) {
    if (occurrence.completed || !occurrence.scheduledTime.isValid()) {
      continue;
    }
    const QDateTime dueAt(occurrence.occurrenceDate, occurrence.scheduledTime);
    int catchUpMinutesBefore = -1;
    QDateTime mostRecentMissedTrigger;
    for (const int minutesBefore : occurrence.reminderMinutesBefore) {
      const QDateTime trigger = dueAt.addSecs(-minutesBefore * 60);
      if (trigger > now) {
        const QString key = QStringLiteral("task:%1@%2:%3")
                                .arg(occurrence.taskId, occurrence.occurrenceDate.toString(Qt::ISODate))
                                .arg(minutesBefore);
        const QString body =
            minutesBefore == 0 ? QStringLiteral("Agora · %1").arg(occurrence.scheduledTime.toString("HH:mm"))
                               : QStringLiteral("Em %1 min · %2")
                                     .arg(minutesBefore)
                                     .arg(occurrence.scheduledTime.toString("HH:mm"));
        notifications.append(
            scheduledNotification(key, trigger, decoratedTitle(occurrence.emoji, occurrence.title), body));
        continue;
      }
      if (dueAt > now && (!mostRecentMissedTrigger.isValid() || trigger > mostRecentMissedTrigger)) {
        catchUpMinutesBefore = minutesBefore;
        mostRecentMissedTrigger = trigger;
      }
    }
    if (catchUpMinutesBefore >= 0) {
      const QString key = QStringLiteral("task:%1@%2:%3")
                              .arg(occurrence.taskId, occurrence.occurrenceDate.toString(Qt::ISODate))
                              .arg(catchUpMinutesBefore);
      const QString body = QStringLiteral("Em %1 min · %2")
                               .arg(catchUpMinutesBefore)
                               .arg(occurrence.scheduledTime.toString("HH:mm"));
      notifications.append(scheduledNotification(key, now.addSecs(1),
                                                 decoratedTitle(occurrence.emoji, occurrence.title), body));
    }
  }

  for (const HabitRecord &habit : habits) {
    for (QDate date = firstDate; date <= lastDate; date = date.addDays(1)) {
      if (!habit.isScheduledOn(date) || (date == firstDate && completedToday.value(habit.id, false))) {
        continue;
      }
      for (const QTime &time : habit.reminderTimes) {
        const QDateTime trigger(date, time);
        if (trigger <= now) {
          continue;
        }
        const QString key = QStringLiteral("habit:%1@%2:%3")
                                .arg(habit.id, date.toString(Qt::ISODate), time.toString("HH:mm"));
        const QString goal = habit.unit.isEmpty()
                                 ? QString::number(habit.targetAmount)
                                 : QStringLiteral("%1 %2").arg(habit.targetAmount).arg(habit.unit);
        notifications.append(scheduledNotification(key, trigger, decoratedTitle(habit.emoji, habit.title),
                                                   QStringLiteral("Meta diária · %1").arg(goal)));
      }
    }
  }

  std::sort(
      notifications.begin(), notifications.end(), [](const QJsonObject &left, const QJsonObject &right) {
        const double leftTrigger = left.value(QStringLiteral("at")).toDouble();
        const double rightTrigger = right.value(QStringLiteral("at")).toDouble();
        if (leftTrigger != rightTrigger) {
          return leftTrigger < rightTrigger;
        }
        return left.value(QStringLiteral("key")).toString() < right.value(QStringLiteral("key")).toString();
      });

  constexpr int maximumScheduledNotifications = 384;
  QJsonArray result;
  for (const QJsonObject &notification : notifications) {
    if (result.size() >= maximumScheduledNotifications) {
      break;
    }
    result.append(notification);
  }

  *schedule = result;
  setError(errorMessage, {});
  return true;
}

} // namespace waypoint

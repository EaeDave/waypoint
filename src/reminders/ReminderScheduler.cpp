#include "reminders/ReminderScheduler.hpp"

#include "core/TaskStore.hpp"

#include <algorithm>
#include <chrono>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

ReminderScheduler::ReminderScheduler(TaskStore *taskStore, TaskNotificationSink *notificationSink,
                                     QObject *parent)
    : QObject(parent), m_taskStore(taskStore), m_notificationSink(notificationSink) {
  m_timer.setInterval(std::chrono::seconds(10));
  connect(&m_timer, &QTimer::timeout, this, &ReminderScheduler::dispatchCurrentMinute);
  connect(m_taskStore, &TaskStore::tasksChanged, this, &ReminderScheduler::dispatchCurrentMinute);
  connect(m_taskStore, &TaskStore::habitsChanged, this, &ReminderScheduler::dispatchCurrentMinute);
}

void ReminderScheduler::start() {
  if (m_timer.isActive()) {
    return;
  }
  dispatchCurrentMinute();
  m_timer.start();
}

bool ReminderScheduler::dispatchDueReminders(const QDateTime &localNow, QString *errorMessage) {
  if (!localNow.isValid()) {
    setError(errorMessage, QStringLiteral("Reminder check requires a valid local date and time"));
    return false;
  }

  QString loadError;
  const QList<TaskRecord> tasks = m_taskStore->listActiveTasks(&loadError);
  if (!loadError.isEmpty()) {
    setError(errorMessage, loadError);
    return false;
  }
  const QList<TaskOccurrenceState> states = m_taskStore->listOccurrenceStates(&loadError);
  if (!loadError.isEmpty()) {
    setError(errorMessage, loadError);
    return false;
  }

  const QDateTime currentMinute(localNow.date(), QTime(localNow.time().hour(), localNow.time().minute()));
  int maximumReminderMinutes = 0;
  for (const TaskRecord &task : tasks) {
    for (const int minutesBefore : task.reminderMinutesBefore) {
      maximumReminderMinutes = std::max(maximumReminderMinutes, minutesBefore);
    }
  }
  const QDate reminderHorizon =
      currentMinute.addSecs(static_cast<qint64>(maximumReminderMinutes) * 60).date();
  const QList<TaskOccurrence> occurrences =
      projectOccurrences(tasks, states, currentMinute.date(), reminderHorizon);
  for (const TaskOccurrence &occurrence : occurrences) {
    if (occurrence.completed || !occurrence.scheduledTime.isValid()) {
      continue;
    }
    const QDateTime dueMinute(occurrence.occurrenceDate, occurrence.scheduledTime);
    if (dueMinute < currentMinute) {
      continue;
    }

    int reminderMinutesBefore = -1;
    QDateTime mostRecentTrigger;
    for (const int candidateMinutesBefore : occurrence.reminderMinutesBefore) {
      const QDateTime triggerMinute = dueMinute.addSecs(-static_cast<qint64>(candidateMinutesBefore) * 60);
      if (triggerMinute > currentMinute ||
          (mostRecentTrigger.isValid() && triggerMinute <= mostRecentTrigger)) {
        continue;
      }
      reminderMinutesBefore = candidateMinutesBefore;
      mostRecentTrigger = triggerMinute;
    }
    if (reminderMinutesBefore < 0) {
      continue;
    }

    bool claimed = false;
    QString claimError;
    if (!m_taskStore->claimReminderDelivery(occurrence.taskId, occurrence.occurrenceDate,
                                            reminderMinutesBefore, &claimed, &claimError)) {
      setError(errorMessage, claimError);
      return false;
    }
    if (!claimed) {
      continue;
    }

    QString notificationError;
    if (!m_notificationSink->send(occurrence, reminderMinutesBefore, &notificationError)) {
      QString releaseError;
      if (!m_taskStore->releaseReminderDelivery(occurrence.taskId, occurrence.occurrenceDate,
                                                reminderMinutesBefore, &releaseError)) {
        notificationError += QStringLiteral("; cannot release reminder claim: %1").arg(releaseError);
      }
      setError(errorMessage, notificationError);
      return false;
    }
    emit reminderDelivered(occurrence.taskId, occurrence.title);
  }

  const QList<HabitProgress> habits = m_taskStore->listHabitProgress(currentMinute.date(), &loadError);
  if (!loadError.isEmpty()) {
    setError(errorMessage, loadError);
    return false;
  }
  for (const HabitProgress &progress : habits) {
    if (progress.completed() || !progress.habit.reminderTimes.contains(currentMinute.time())) {
      continue;
    }
    bool claimed = false;
    QString claimError;
    if (!m_taskStore->claimHabitReminderDelivery(progress.habit.id, progress.date, currentMinute.time(),
                                                 &claimed, &claimError)) {
      setError(errorMessage, claimError);
      return false;
    }
    if (!claimed) {
      continue;
    }
    QString notificationError;
    if (!m_notificationSink->sendHabit(progress, currentMinute.time(), &notificationError)) {
      QString releaseError;
      if (!m_taskStore->releaseHabitReminderDelivery(progress.habit.id, progress.date, currentMinute.time(),
                                                     &releaseError)) {
        notificationError += QStringLiteral("; cannot release habit reminder claim: %1").arg(releaseError);
      }
      setError(errorMessage, notificationError);
      return false;
    }
    emit reminderDelivered(progress.habit.id, progress.habit.title);
  }
  return true;
}

void ReminderScheduler::dispatchCurrentMinute() {
  QString error;
  if (!dispatchDueReminders(QDateTime::currentDateTime(), &error)) {
    emit deliveryFailed(error);
  }
}

} // namespace waypoint

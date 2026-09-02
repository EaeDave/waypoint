#include "reminders/ReminderScheduler.hpp"

#include "core/TaskStore.hpp"

#include <chrono>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

ReminderScheduler::ReminderScheduler(TaskStore *taskStore,
                                     TaskNotificationSink *notificationSink,
                                     QObject *parent)
    : QObject(parent), m_taskStore(taskStore), m_notificationSink(notificationSink) {
  m_timer.setInterval(std::chrono::seconds(10));
  connect(&m_timer, &QTimer::timeout, this, &ReminderScheduler::dispatchCurrentMinute);
  connect(m_taskStore, &TaskStore::tasksChanged, this,
          &ReminderScheduler::dispatchCurrentMinute);
}

void ReminderScheduler::start() {
  if (m_timer.isActive()) {
    return;
  }
  dispatchCurrentMinute();
  m_timer.start();
}

bool ReminderScheduler::dispatchDueReminders(const QDateTime &localNow,
                                             QString *errorMessage) {
  if (!localNow.isValid()) {
    setError(errorMessage, QStringLiteral("Reminder check requires a valid local date and time"));
    return false;
  }

  QString loadError;
  const QList<TaskOccurrence> occurrences =
      m_taskStore->listOccurrences(localNow.date(), localNow.date(), &loadError);
  if (!loadError.isEmpty()) {
    setError(errorMessage, loadError);
    return false;
  }

  const QTime currentMinute(localNow.time().hour(), localNow.time().minute());
  for (const TaskOccurrence &occurrence : occurrences) {
    if (occurrence.completed || occurrence.scheduledTime != currentMinute) {
      continue;
    }

    bool claimed = false;
    QString claimError;
    if (!m_taskStore->claimReminderDelivery(occurrence.taskId, occurrence.occurrenceDate,
                                            occurrence.scheduledTime, &claimed, &claimError)) {
      setError(errorMessage, claimError);
      return false;
    }
    if (!claimed) {
      continue;
    }

    QString notificationError;
    if (!m_notificationSink->send(occurrence, &notificationError)) {
      QString releaseError;
      if (!m_taskStore->releaseReminderDelivery(occurrence.taskId, occurrence.occurrenceDate,
                                                occurrence.scheduledTime, &releaseError)) {
        notificationError += QStringLiteral("; cannot release reminder claim: %1").arg(releaseError);
      }
      setError(errorMessage, notificationError);
      return false;
    }
    emit reminderDelivered(occurrence.taskId, occurrence.title);
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

#pragma once

#include "core/Recurrence.hpp"

#include <QDateTime>
#include <QObject>
#include <QTimer>

namespace waypoint {

class TaskStore;

class TaskNotificationSink {
public:
  virtual ~TaskNotificationSink() = default;
  [[nodiscard]] virtual bool send(const TaskOccurrence &occurrence, int reminderMinutesBefore,
                                  QString *errorMessage = nullptr) = 0;
};

class ReminderScheduler final : public QObject {
  Q_OBJECT

public:
  ReminderScheduler(TaskStore *taskStore, TaskNotificationSink *notificationSink, QObject *parent = nullptr);

  void start();
  [[nodiscard]] bool dispatchDueReminders(const QDateTime &localNow, QString *errorMessage = nullptr);

signals:
  void reminderDelivered(const QString &taskId, const QString &title);
  void deliveryFailed(const QString &message);

private:
  void dispatchCurrentMinute();

  TaskStore *m_taskStore;
  TaskNotificationSink *m_notificationSink;
  QTimer m_timer;
};

} // namespace waypoint

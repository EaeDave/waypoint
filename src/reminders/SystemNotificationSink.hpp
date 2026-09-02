#pragma once

#include "reminders/ReminderScheduler.hpp"

namespace waypoint {

class SystemNotificationSink final : public TaskNotificationSink {
public:
  [[nodiscard]] bool send(const TaskOccurrence &occurrence, int reminderMinutesBefore,
                          QString *errorMessage = nullptr) override;
  [[nodiscard]] bool sendHabit(const HabitProgress &progress, const QTime &reminderTime,
                               QString *errorMessage = nullptr) override;
};

} // namespace waypoint

#pragma once

#include "reminders/ReminderScheduler.hpp"

namespace waypoint {

class SystemNotificationSink final : public TaskNotificationSink {
public:
  [[nodiscard]] bool send(const TaskOccurrence &occurrence,
                          QString *errorMessage = nullptr) override;
};

} // namespace waypoint

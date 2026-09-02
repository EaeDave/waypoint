#pragma once

#include <QString>

namespace waypoint {

class TaskStore;

class AndroidNotificationBridge final {
public:
  [[nodiscard]] static bool replaceSchedule(TaskStore *store, QString *errorMessage = nullptr);
  static void playCompletionSound();
};

} // namespace waypoint

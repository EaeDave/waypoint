#include "core/TaskVisibility.hpp"

namespace waypoint {

QString taskVisibilityModeName(const TaskVisibilityMode mode) {
  return mode == TaskVisibilityMode::Pending ? QStringLiteral("pending") : QStringLiteral("all");
}

std::optional<TaskVisibilityMode> taskVisibilityModeFromName(const QString &name) {
  if (name == QStringLiteral("all")) {
    return TaskVisibilityMode::All;
  }
  if (name == QStringLiteral("pending")) {
    return TaskVisibilityMode::Pending;
  }
  return std::nullopt;
}

bool isTaskVisible(const TaskOccurrence &occurrence, const TaskVisibilityMode mode) {
  return mode == TaskVisibilityMode::All || (!occurrence.completed && !occurrence.skipped);
}

} // namespace waypoint

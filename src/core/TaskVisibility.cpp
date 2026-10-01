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

bool isTaskListVisible(const QString &categoryId, const std::optional<QStringList> &listIds) {
  return !listIds.has_value() || listIds->contains(categoryId);
}

QJsonArray filterTaskListActivity(const QJsonArray &groups, const std::optional<QStringList> &listIds) {
  if (!listIds.has_value()) {
    return groups;
  }
  QJsonArray visible;
  for (const QJsonValue &group : groups) {
    if (isTaskListVisible(group.toObject().value(QStringLiteral("categoryId")).toString(), listIds)) {
      visible.append(group);
    }
  }
  return visible;
}

} // namespace waypoint

#pragma once

#include "core/Recurrence.hpp"

#include <QString>

#include <optional>

namespace waypoint {

enum class TaskVisibilityMode { All, Pending };

[[nodiscard]] QString taskVisibilityModeName(TaskVisibilityMode mode);
[[nodiscard]] std::optional<TaskVisibilityMode> taskVisibilityModeFromName(const QString &name);
[[nodiscard]] bool isTaskVisible(const TaskOccurrence &occurrence, TaskVisibilityMode mode);

} // namespace waypoint

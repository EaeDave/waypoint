#pragma once

#include "core/Recurrence.hpp"

#include <QString>
#include <QStringList>

#include <optional>

namespace waypoint {

enum class TaskVisibilityMode { All, Pending };

[[nodiscard]] QString taskVisibilityModeName(TaskVisibilityMode mode);
[[nodiscard]] std::optional<TaskVisibilityMode> taskVisibilityModeFromName(const QString &name);
[[nodiscard]] bool isTaskVisible(const TaskOccurrence &occurrence, TaskVisibilityMode mode);
[[nodiscard]] bool isTaskListVisible(const QString &categoryId,
                                     const std::optional<QStringList> &listIds);
[[nodiscard]] QJsonArray filterTaskListActivity(const QJsonArray &groups,
                                                const std::optional<QStringList> &listIds);

} // namespace waypoint

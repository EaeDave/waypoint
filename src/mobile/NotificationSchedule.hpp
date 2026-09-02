#pragma once

#include <QDateTime>
#include <QJsonArray>

namespace waypoint {

class TaskStore;

[[nodiscard]] bool buildNotificationSchedule(TaskStore &store, const QDateTime &now, int horizonDays,
                                             QJsonArray *schedule, QString *errorMessage = nullptr);

} // namespace waypoint

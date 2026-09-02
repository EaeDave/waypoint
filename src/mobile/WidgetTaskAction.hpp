#pragma once

#include <QDate>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QString>

namespace waypoint {

class TaskStore;

struct WidgetTaskActionResult final {
  QJsonObject snapshot;
  QJsonArray notificationSchedule;
};

[[nodiscard]] bool applyWidgetTaskCompletion(TaskStore &store, const QString &taskId,
                                             const QDate &occurrenceDate, bool recurring, bool completed,
                                             const QDateTime &now, WidgetTaskActionResult *result,
                                             QString *errorMessage = nullptr);

} // namespace waypoint

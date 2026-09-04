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
[[nodiscard]] bool applyWidgetTaskVisibility(TaskStore &store, const QString &taskVisibility,
                                             const QDateTime &now, WidgetTaskActionResult *result,
                                             QString *errorMessage = nullptr);

[[nodiscard]] bool applyWidgetHabitCheckIn(TaskStore &store, const QString &habitId, const QDate &date,
                                           qint64 amount, const QDateTime &now,
                                           WidgetTaskActionResult *result, QString *errorMessage = nullptr);

} // namespace waypoint

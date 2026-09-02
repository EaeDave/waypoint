#include "mobile/WidgetTaskAction.hpp"

#include "core/TaskStore.hpp"
#include "mobile/NotificationSchedule.hpp"
#include "mobile/WidgetSnapshot.hpp"

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

bool applyWidgetTaskCompletion(TaskStore &store, const QString &taskId, const QDate &occurrenceDate,
                               const bool recurring, const bool completed, const QDateTime &now,
                               WidgetTaskActionResult *result, QString *errorMessage) {
  if (taskId.isEmpty() || !occurrenceDate.isValid() || !now.isValid() || result == nullptr) {
    setError(errorMessage, QStringLiteral("Invalid widget task completion request"));
    return false;
  }

  QString error;
  const bool changed = recurring ? store.setOccurrenceCompleted(taskId, occurrenceDate, completed, &error)
                                 : store.setTaskCompleted(taskId, completed, &error);
  if (!changed) {
    setError(errorMessage, error);
    return false;
  }

  WidgetTaskActionResult updated;
  updated.snapshot = buildWidgetSnapshot(store, now.date(), 1, 1, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }
  if (!buildNotificationSchedule(store, now, 31, &updated.notificationSchedule, &error)) {
    setError(errorMessage, error);
    return false;
  }

  *result = updated;
  setError(errorMessage, {});
  return true;
}

} // namespace waypoint

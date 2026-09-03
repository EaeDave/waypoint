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

bool refreshWidgetActionResult(waypoint::TaskStore &store, const QDateTime &now,
                               waypoint::WidgetTaskActionResult *result, QString *errorMessage) {
  QString error;
  waypoint::WidgetTaskActionResult updated;
  updated.snapshot = waypoint::buildWidgetSnapshot(store, now.date(), 1, 1, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }
  if (!waypoint::buildNotificationSchedule(store, now, 31, &updated.notificationSchedule, &error)) {
    setError(errorMessage, error);
    return false;
  }
  *result = updated;
  setError(errorMessage, {});
  return true;
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

  return refreshWidgetActionResult(store, now, result, errorMessage);
}

bool applyWidgetHabitCheckIn(TaskStore &store, const QString &habitId, const QDate &date, const qint64 amount,
                             const QDateTime &now, WidgetTaskActionResult *result, QString *errorMessage) {
  if (habitId.isEmpty() || !date.isValid() || amount < 0 || !now.isValid() || result == nullptr) {
    setError(errorMessage, QStringLiteral("Invalid widget habit check-in request"));
    return false;
  }

  QString error;
  const std::optional<qint64> recordedAmount = amount > 0 ? std::optional<qint64>(amount) : std::nullopt;
  if (!store.recordHabit(habitId, date, recordedAmount, nullptr, &error)) {
    setError(errorMessage, error);
    return false;
  }
  return refreshWidgetActionResult(store, now, result, errorMessage);
}

} // namespace waypoint

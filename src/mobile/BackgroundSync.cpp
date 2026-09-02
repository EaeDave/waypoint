#include "mobile/BackgroundSync.hpp"

#include "core/TaskStore.hpp"
#include "mobile/NotificationSchedule.hpp"
#include "mobile/WidgetSnapshot.hpp"
#include "sync/SyncProtocol.hpp"

#include <QDateTime>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

bool prepareBackgroundSync(TaskStore &store, BackgroundSyncRequest *request, QString *errorMessage) {
  if (request == nullptr) {
    setError(errorMessage, QStringLiteral("Background sync request destination is required"));
    return false;
  }

  QString error;
  const SyncConfiguration configuration = store.syncConfiguration(&error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }
  if (!configuration.endpoint.isValid() || configuration.endpoint.isEmpty() || configuration.token.isEmpty()) {
    setError(errorMessage, QStringLiteral("Remote synchronization is disabled"));
    return false;
  }

  BackgroundSyncRequest prepared;
  prepared.endpoint = configuration.endpoint;
  prepared.token = configuration.token;
  prepared.payload = buildSyncRequest(store, syncDeviceId(), &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }

  *request = prepared;
  setError(errorMessage, {});
  return true;
}

bool applyBackgroundSync(TaskStore &store, const QJsonObject &response, BackgroundSyncResult *result,
                         QString *errorMessage) {
  if (result == nullptr) {
    setError(errorMessage, QStringLiteral("Background sync result destination is required"));
    return false;
  }

  QString error;
  if (!applySyncResponse(store, response, &error)) {
    setError(errorMessage, error);
    return false;
  }

  BackgroundSyncResult applied;
  const QDateTime now = QDateTime::currentDateTime();
  applied.widgetSnapshot = buildWidgetSnapshot(store, now.date(), 6, 12, &error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return false;
  }
  if (!buildNotificationSchedule(store, now, 31, &applied.notificationSchedule, &error)) {
    setError(errorMessage, error);
    return false;
  }

  *result = applied;
  setError(errorMessage, {});
  return true;
}

} // namespace waypoint

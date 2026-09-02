#pragma once

#include <QByteArray>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrl>

namespace waypoint {

class TaskStore;

struct BackgroundSyncRequest final {
  QUrl endpoint;
  QByteArray token;
  QJsonObject payload;
};

struct BackgroundSyncResult final {
  QJsonObject widgetSnapshot;
  QJsonArray notificationSchedule;
};

[[nodiscard]] bool prepareBackgroundSync(TaskStore &store, BackgroundSyncRequest *request,
                                         QString *errorMessage = nullptr);
[[nodiscard]] bool applyBackgroundSync(TaskStore &store, const QJsonObject &response,
                                       BackgroundSyncResult *result, QString *errorMessage = nullptr);

} // namespace waypoint

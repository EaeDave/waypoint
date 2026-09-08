#pragma once

#include <QJsonObject>
#include <QString>

namespace waypoint {

class TaskStore;

[[nodiscard]] QString syncDeviceId();
[[nodiscard]] QJsonObject buildSyncRequest(TaskStore &store, const QString &deviceId,
                                           bool includeCategoryMutations,
                                           QString *errorMessage = nullptr);
[[nodiscard]] bool applySyncResponse(TaskStore &store, const QJsonObject &response,
                                     QString *errorMessage = nullptr);

} // namespace waypoint

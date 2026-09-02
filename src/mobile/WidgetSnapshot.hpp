#pragma once

#include <QDate>
#include <QJsonObject>
#include <QString>

namespace waypoint {

class TaskStore;

[[nodiscard]] QJsonObject buildWidgetSnapshot(TaskStore &store, const QDate &today, int monthsBefore = 6,
                                              int monthsAfter = 12, QString *errorMessage = nullptr);

} // namespace waypoint

#pragma once

#include <QJsonObject>

namespace waypoint {

class AndroidWidgetBridge final {
public:
  static void publishSnapshot(const QJsonObject &snapshot);
};

} // namespace waypoint

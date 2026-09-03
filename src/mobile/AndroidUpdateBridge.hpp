#pragma once

#include <QString>

namespace waypoint {

class AndroidUpdateBridge final {
public:
  [[nodiscard]] static bool installApk(const QString &path, QString *errorMessage = nullptr);
};

} // namespace waypoint

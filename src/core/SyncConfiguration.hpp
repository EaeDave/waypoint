#pragma once

#include <QByteArray>
#include <QUrl>

namespace waypoint {

struct SyncConfiguration {
  QUrl endpoint;
  QByteArray token;

  [[nodiscard]] bool enabled() const { return endpoint.isValid() && !endpoint.isEmpty() && !token.isEmpty(); }
};

} // namespace waypoint

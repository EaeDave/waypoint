#pragma once

#include <QJsonObject>
#include <QString>

class QIODevice;

namespace waypoint::protocol {

inline constexpr auto socketName = "waypoint-ipc-v1";

[[nodiscard]] QByteArray encodeMessage(const QJsonObject &message);
[[nodiscard]] QJsonObject decodeMessage(const QByteArray &line, QString *errorMessage = nullptr);
[[nodiscard]] bool writeMessage(QIODevice *device, const QJsonObject &message,
                                QString *errorMessage = nullptr);
[[nodiscard]] QJsonObject errorResponse(const QString &message);

} // namespace waypoint::protocol

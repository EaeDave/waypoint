#include "ipc/WaypointProtocol.hpp"

#include <QIODevice>
#include <QJsonDocument>
#include <QJsonParseError>

namespace waypoint::protocol {

QByteArray encodeMessage(const QJsonObject &message) {
  return QJsonDocument(message).toJson(QJsonDocument::Compact) + '\n';
}

QJsonObject decodeMessage(const QByteArray &line, QString *errorMessage) {
  QJsonParseError parseError;
  const QJsonDocument document = QJsonDocument::fromJson(line.trimmed(), &parseError);
  if (parseError.error == QJsonParseError::NoError && document.isObject()) {
    return document.object();
  }
  if (errorMessage != nullptr) {
    *errorMessage = QStringLiteral("Invalid IPC JSON: %1").arg(parseError.errorString());
  }
  return {};
}

bool writeMessage(QIODevice *device, const QJsonObject &message, QString *errorMessage) {
  const QByteArray encoded = encodeMessage(message);
  const qint64 written = device->write(encoded);
  if (written == encoded.size()) {
    return true;
  }
  if (errorMessage != nullptr) {
    *errorMessage = QStringLiteral("IPC wrote %1 of %2 bytes").arg(written).arg(encoded.size());
  }
  return false;
}

QJsonObject errorResponse(const QString &message) {
  return {{QStringLiteral("ok"), false}, {QStringLiteral("error"), message}};
}

} // namespace waypoint::protocol

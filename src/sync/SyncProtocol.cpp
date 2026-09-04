#include "sync/SyncProtocol.hpp"

#include "core/TaskStore.hpp"

#include <QCryptographicHash>
#include <QJsonArray>
#include <QSysInfo>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

QString syncDeviceId() {
  const QString overrideId = qEnvironmentVariable("WAYPOINT_DEVICE_ID");
  if (!overrideId.isEmpty()) {
    return overrideId;
  }
  QByteArray identity = QSysInfo::machineUniqueId();
  if (identity.isEmpty()) {
    identity = QSysInfo::machineHostName().toUtf8();
  }
  return QString::fromLatin1(QCryptographicHash::hash(identity, QCryptographicHash::Sha256).toHex().left(24));
}

QJsonObject buildSyncRequest(TaskStore &store, const QString &deviceId, QString *errorMessage) {
  if (deviceId.trimmed().isEmpty()) {
    setError(errorMessage, QStringLiteral("Synchronization requires a device identifier"));
    return {};
  }
  QString error;
  const QJsonArray mutations = store.pendingMutations(&error);
  const QString cursor = store.syncCursor(&error);
  const QJsonObject preferenceMutation = store.pendingUserPreferencesMutation(&error);
  if (!error.isEmpty()) {
    setError(errorMessage, error);
    return {};
  }
  QJsonObject request{
      {QStringLiteral("deviceId"), deviceId},
      {QStringLiteral("cursor"), cursor.toLongLong()},
      {QStringLiteral("mutations"), mutations},
  };
  if (!preferenceMutation.isEmpty()) {
    request.insert(QStringLiteral("preferenceMutation"), preferenceMutation);
  }
  setError(errorMessage, {});
  return request;
}

bool applySyncResponse(TaskStore &store, const QJsonObject &response, QString *errorMessage) {
  QStringList acceptedMutationIds;
  for (const QJsonValue &value : response.value(QStringLiteral("acceptedMutationIds")).toArray()) {
    acceptedMutationIds.append(value.toString());
  }
  QString error;
  if (!store.applyRemoteChanges(response.value(QStringLiteral("changes")).toArray(),
                                QString::number(response.value(QStringLiteral("nextCursor")).toInteger()),
                                acceptedMutationIds, &error)) {
    setError(errorMessage, error);
    return false;
  }
  const QJsonObject preferences = response.value(QStringLiteral("preferences")).toObject();
  if (!preferences.isEmpty() &&
      !store.applySyncedUserPreferences(
          preferences, response.value(QStringLiteral("acceptedPreferenceMutationId")).toString(), &error)) {
    setError(errorMessage, error);
    return false;
  }
  setError(errorMessage, {});
  return true;
}

} // namespace waypoint

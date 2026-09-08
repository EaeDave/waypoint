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
constexpr qsizetype maximumMutationBatchSize = 500;
QStringList legacyEntityTypes() {
  return {
      QStringLiteral("task"),
      QStringLiteral("occurrence"),
      QStringLiteral("habit"),
      QStringLiteral("habit-entry"),
  };
}

QStringList supportedEntityTypes() {
  QStringList types = legacyEntityTypes();
  types.append(QStringLiteral("category"));
  return types;
}

QJsonArray jsonStringArray(const QStringList &values) {
  QJsonArray array;
  for (const QString &value : values) {
    array.append(value);
  }
  return array;
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

QJsonObject buildSyncRequest(TaskStore &store, const QString &deviceId,
                             const bool includeCategoryMutations, QString *errorMessage) {
  if (deviceId.trimmed().isEmpty()) {
    setError(errorMessage, QStringLiteral("Synchronization requires a device identifier"));
    return {};
  }
  QString error;
  const QStringList uploadTypes =
      includeCategoryMutations ? supportedEntityTypes() : legacyEntityTypes();
  const QJsonArray mutations =
      store.pendingMutations(uploadTypes, maximumMutationBatchSize, &error);
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
      {QStringLiteral("supportedEntityTypes"), jsonStringArray(supportedEntityTypes())},
  };
  if (!preferenceMutation.isEmpty()) {
    request.insert(QStringLiteral("preferenceMutation"), preferenceMutation);
  }
  setError(errorMessage, {});
  return request;
}

bool applySyncResponse(TaskStore &store, const QJsonObject &response, QString *errorMessage) {
  QStringList serverTypes = legacyEntityTypes();
  if (response.contains(QStringLiteral("supportedEntityTypes"))) {
    const QJsonValue capabilityValue = response.value(QStringLiteral("supportedEntityTypes"));
    if (!capabilityValue.isArray()) {
      setError(errorMessage, QStringLiteral("Synchronization response capabilities are invalid"));
      return false;
    }
    serverTypes.clear();
    const QJsonArray values = capabilityValue.toArray();
    for (const QJsonValue &value : values) {
      const QString entityType = value.toString();
      if (entityType.isEmpty() || serverTypes.contains(entityType)) {
        setError(errorMessage, QStringLiteral("Synchronization response capabilities are invalid"));
        return false;
      }
      serverTypes.append(entityType);
    }
  }

  QString error;
  if (!store.saveServerSupportedEntityTypes(serverTypes, &error)) {
    setError(errorMessage, error);
    return false;
  }
  QStringList acceptedMutationIds;
  for (const QJsonValue &value : response.value(QStringLiteral("acceptedMutationIds")).toArray()) {
    acceptedMutationIds.append(value.toString());
  }
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

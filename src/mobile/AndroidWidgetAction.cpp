#include "core/TaskStore.hpp"
#include "mobile/BackgroundSync.hpp"
#include "mobile/WidgetTaskAction.hpp"

#include <QJsonDocument>
#include <QJsonObject>

#include <jni.h>

namespace {

QString fromJavaString(JNIEnv *environment, jstring value) {
  if (value == nullptr) {
    return {};
  }
  const jchar *characters = environment->GetStringChars(value, nullptr);
  if (characters == nullptr) {
    return {};
  }
  const QString converted =
      QString::fromUtf16(reinterpret_cast<const char16_t *>(characters), environment->GetStringLength(value));
  environment->ReleaseStringChars(value, characters);
  return converted;
}

jstring toJavaString(JNIEnv *environment, const QString &value) {
  return environment->NewString(reinterpret_cast<const jchar *>(value.utf16()), value.size());
}

jstring widgetActionResponse(JNIEnv *environment, const bool applied,
                             const waypoint::WidgetTaskActionResult &result, const QString &error) {
  QJsonObject response{{QStringLiteral("ok"), applied}};
  if (applied) {
    response.insert(QStringLiteral("snapshot"), result.snapshot);
    response.insert(QStringLiteral("schedule"), result.notificationSchedule);
  } else {
    response.insert(QStringLiteral("error"), error);
  }
  return toJavaString(environment, QString::fromUtf8(QJsonDocument(response).toJson(QJsonDocument::Compact)));
}

} // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_org_eaedave_waypoint_WaypointWidgetActionService_applyTaskCompletion(
    JNIEnv *environment, jclass, jstring databasePath, jstring taskId, jstring occurrenceDate,
    const jboolean recurring, const jboolean completed) {
  QString error;
  waypoint::TaskStore store(fromJavaString(environment, databasePath));
  waypoint::WidgetTaskActionResult result;
  const bool opened = store.open(&error);
  const bool applied =
      opened &&
      waypoint::applyWidgetTaskCompletion(
          store, fromJavaString(environment, taskId),
          QDate::fromString(fromJavaString(environment, occurrenceDate), Qt::ISODate), recurring == JNI_TRUE,
          completed == JNI_TRUE, QDateTime::currentDateTime(), &result, &error);
  return widgetActionResponse(environment, applied, result, error);
}

extern "C" JNIEXPORT jstring JNICALL Java_org_eaedave_waypoint_WaypointWidgetActionService_applyHabitCheckIn(
    JNIEnv *environment, jclass, jstring databasePath, jstring habitId, jstring date, const jlong amount) {
  QString error;
  waypoint::TaskStore store(fromJavaString(environment, databasePath));
  waypoint::WidgetTaskActionResult result;
  const bool applied =
      store.open(&error) &&
      waypoint::applyWidgetHabitCheckIn(store, fromJavaString(environment, habitId),
                                        QDate::fromString(fromJavaString(environment, date), Qt::ISODate),
                                        amount, QDateTime::currentDateTime(), &result, &error);
  return widgetActionResponse(environment, applied, result, error);
}

extern "C" JNIEXPORT jstring JNICALL
Java_org_eaedave_waypoint_WaypointBackgroundSyncService_prepareBackgroundSync(JNIEnv *environment, jclass,
                                                                              jstring databasePath) {
  QJsonObject response;
  QString error;
  waypoint::TaskStore store(fromJavaString(environment, databasePath));
  waypoint::BackgroundSyncRequest request;
  const bool opened = store.open(&error);
  const bool prepared = opened && waypoint::prepareBackgroundSync(store, &request, &error);
  response.insert(QStringLiteral("ok"), prepared);
  if (prepared) {
    response.insert(QStringLiteral("endpoint"), request.endpoint.toString(QUrl::FullyEncoded));
    response.insert(QStringLiteral("token"), QString::fromUtf8(request.token));
    response.insert(QStringLiteral("request"), request.payload);
  } else {
    response.insert(QStringLiteral("error"), error);
    response.insert(QStringLiteral("retry"),
                    !opened || error != QStringLiteral("Remote synchronization is disabled"));
  }
  return toJavaString(environment, QString::fromUtf8(QJsonDocument(response).toJson(QJsonDocument::Compact)));
}

extern "C" JNIEXPORT jstring JNICALL
Java_org_eaedave_waypoint_WaypointBackgroundSyncService_applyBackgroundSync(JNIEnv *environment, jclass,
                                                                            jstring databasePath,
                                                                            jstring responsePayload) {
  QJsonObject resultJson;
  QString error;
  QJsonParseError parseError;
  const QJsonDocument document =
      QJsonDocument::fromJson(fromJavaString(environment, responsePayload).toUtf8(), &parseError);
  waypoint::TaskStore store(fromJavaString(environment, databasePath));
  waypoint::BackgroundSyncResult result;
  const bool applied = parseError.error == QJsonParseError::NoError && document.isObject() &&
                       store.open(&error) &&
                       waypoint::applyBackgroundSync(store, document.object(), &result, &error);
  if (parseError.error != QJsonParseError::NoError) {
    error = QStringLiteral("Synchronization response is not valid JSON: %1").arg(parseError.errorString());
  }
  resultJson.insert(QStringLiteral("ok"), applied);
  if (applied) {
    resultJson.insert(QStringLiteral("snapshot"), result.widgetSnapshot);
    resultJson.insert(QStringLiteral("schedule"), result.notificationSchedule);
  } else {
    resultJson.insert(QStringLiteral("error"), error);
  }
  return toJavaString(environment,
                      QString::fromUtf8(QJsonDocument(resultJson).toJson(QJsonDocument::Compact)));
}

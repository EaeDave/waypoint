#include "core/TaskStore.hpp"
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

} // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_org_eaedave_waypoint_WaypointWidgetActionService_applyTaskCompletion(
    JNIEnv *environment, jclass, jstring databasePath, jstring taskId, jstring occurrenceDate,
    const jboolean recurring, const jboolean completed) {
  QJsonObject response;
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
  response.insert(QStringLiteral("ok"), applied);
  if (applied) {
    response.insert(QStringLiteral("snapshot"), result.snapshot);
    response.insert(QStringLiteral("schedule"), result.notificationSchedule);
  } else {
    response.insert(QStringLiteral("error"), error);
  }
  return toJavaString(environment, QString::fromUtf8(QJsonDocument(response).toJson(QJsonDocument::Compact)));
}

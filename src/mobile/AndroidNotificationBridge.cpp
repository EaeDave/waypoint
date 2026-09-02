#include "mobile/AndroidNotificationBridge.hpp"

#include "mobile/NotificationSchedule.hpp"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonDocument>

#include <QCoreApplication>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

namespace waypoint {

bool AndroidNotificationBridge::replaceSchedule(TaskStore *store, QString *errorMessage) {
  if (store == nullptr) {
    if (errorMessage != nullptr) {
      *errorMessage = QStringLiteral("Cannot schedule Android notifications without a task store");
    }
    return false;
  }

  QJsonArray schedule;
  if (!buildNotificationSchedule(*store, QDateTime::currentDateTime(), 31, &schedule, errorMessage)) {
    return false;
  }

#ifdef Q_OS_ANDROID
  const QJniObject context = QNativeInterface::QAndroidApplication::context();
  const QJniObject payload =
      QJniObject::fromString(QString::fromUtf8(QJsonDocument(schedule).toJson(QJsonDocument::Compact)));
  QJniObject::callStaticMethod<void>("org/eaedave/waypoint/WaypointNotifications", "replaceSchedule",
                                     "(Landroid/content/Context;Ljava/lang/String;)V",
                                     context.object<jobject>(), payload.object<jstring>());
#else
  Q_UNUSED(schedule);
#endif
  return true;
}

void AndroidNotificationBridge::playCompletionSound() {
#ifdef Q_OS_ANDROID
  const QJniObject context = QNativeInterface::QAndroidApplication::context();
  QJniObject::callStaticMethod<void>("org/eaedave/waypoint/WaypointNotifications", "playCompletionSound",
                                     "(Landroid/content/Context;)V", context.object<jobject>());
#endif
}

} // namespace waypoint

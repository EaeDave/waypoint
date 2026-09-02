#include "mobile/AndroidWidgetBridge.hpp"

#include <QCoreApplication>
#include <QJsonDocument>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

namespace waypoint {

void AndroidWidgetBridge::publishSnapshot(const QJsonObject &snapshot) {
#ifdef Q_OS_ANDROID
  const QJniObject context = QNativeInterface::QAndroidApplication::context();
  const QJniObject payload =
      QJniObject::fromString(QString::fromUtf8(QJsonDocument(snapshot).toJson(QJsonDocument::Compact)));
  QJniObject::callStaticMethod<void>("org/eaedave/waypoint/WaypointWidgetBridge", "publishSnapshot",
                                     "(Landroid/content/Context;Ljava/lang/String;)V",
                                     context.object<jobject>(), payload.object<jstring>());
#else
  Q_UNUSED(snapshot);
#endif
}

} // namespace waypoint

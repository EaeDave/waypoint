#include "mobile/AndroidBackgroundSyncBridge.hpp"

#include <QCoreApplication>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

namespace waypoint {

void AndroidBackgroundSyncBridge::configure(const bool enabled) {
#ifdef Q_OS_ANDROID
  const QJniObject context = QNativeInterface::QAndroidApplication::context();
  QJniObject::callStaticMethod<void>("org/eaedave/waypoint/WaypointBackgroundSyncScheduler", "configure",
                                     "(Landroid/content/Context;Z)V", context.object<jobject>(),
                                     static_cast<jboolean>(enabled));
#else
  Q_UNUSED(enabled);
#endif
}

} // namespace waypoint

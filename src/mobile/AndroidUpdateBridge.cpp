#include "mobile/AndroidUpdateBridge.hpp"

#include <QCoreApplication>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

namespace waypoint {

bool AndroidUpdateBridge::installApk(const QString &path, QString *errorMessage) {
#ifdef Q_OS_ANDROID
  const QJniObject context = QNativeInterface::QAndroidApplication::context();
  const QJniObject javaPath = QJniObject::fromString(path);
  const jboolean started = QJniObject::callStaticMethod<jboolean>(
      "org/eaedave/waypoint/WaypointUpdate", "install", "(Landroid/content/Context;Ljava/lang/String;)Z",
      context.object<jobject>(), javaPath.object<jstring>());
  if (started == JNI_TRUE) {
    return true;
  }
  if (errorMessage != nullptr) {
    *errorMessage = QStringLiteral("O Android não conseguiu abrir o instalador da atualização");
  }
  return false;
#else
  Q_UNUSED(path);
  if (errorMessage != nullptr) {
    *errorMessage = QStringLiteral("A instalação de APK só está disponível no Android");
  }
  return false;
#endif
}

} // namespace waypoint

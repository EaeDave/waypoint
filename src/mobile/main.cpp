#include "mobile/MobileController.hpp"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QVariant>
#include <QtCore/private/qandroidextras_p.h>

int main(int argc, char *argv[]) {
  QCoreApplication::setOrganizationName(QStringLiteral("eaedave"));
  QCoreApplication::setOrganizationDomain(QStringLiteral("eaedave.org"));
  QCoreApplication::setApplicationName(QStringLiteral("Waypoint"));

  const QString launchMode = argc > 1 ? QString::fromUtf8(argv[1]) : QString{};
  if (launchMode == QStringLiteral("-widget-action-service") ||
      launchMode == QStringLiteral("-background-sync-service")) {
    QAndroidService service(argc, argv);
    return service.exec();
  }

  QGuiApplication application(argc, argv);
  QQuickStyle::setStyle(QStringLiteral("Basic"));

  waypoint::MobileController controller;
  QQmlApplicationEngine engine;
  engine.setInitialProperties({{QStringLiteral("controller"), QVariant::fromValue(&controller)}});
  QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &application,
                   &QCoreApplication::quit, Qt::QueuedConnection);
  QObject::connect(&application, &QGuiApplication::applicationStateChanged, &controller,
                   [&controller](const Qt::ApplicationState state) {
                     if (state == Qt::ApplicationActive) {
                       controller.refresh();
                     }
                   });
  engine.loadFromModule(QStringLiteral("Waypoint.Mobile"), QStringLiteral("Main"));

  return application.exec();
}

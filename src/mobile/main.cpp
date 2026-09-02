#include "mobile/MobileController.hpp"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QVariant>

int main(int argc, char *argv[]) {
  QGuiApplication::setOrganizationName(QStringLiteral("eaedave"));
  QGuiApplication::setOrganizationDomain(QStringLiteral("eaedave.org"));
  QGuiApplication::setApplicationName(QStringLiteral("Waypoint"));


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

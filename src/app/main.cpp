#include "app/WaypointController.hpp"

#include <QCommandLineParser>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>

int main(int argc, char *argv[]) {
  QGuiApplication application(argc, argv);
  QCommandLineParser parser;
  parser.addHelpOption();
  parser.addOption({QStringLiteral("screenshot"), QStringLiteral("Render the month view to a PNG and exit"),
                    QStringLiteral("path")});
  parser.addOption({QStringLiteral("settings"), QStringLiteral("Open synchronization settings")});
  parser.process(application);
  QCoreApplication::setOrganizationName(QStringLiteral("Waypoint"));
  QCoreApplication::setApplicationName(QStringLiteral("Waypoint"));
  QGuiApplication::setApplicationDisplayName(QStringLiteral("Waypoint"));

  waypoint::WaypointController controller;
  QQmlApplicationEngine engine;
  engine.setInitialProperties({{QStringLiteral("waypointController"), QVariant::fromValue(&controller)}});

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &application, [] { QCoreApplication::exit(1); },
      Qt::QueuedConnection);
  engine.loadFromModule(QStringLiteral("Waypoint"), QStringLiteral("Main"));

  if (parser.isSet(QStringLiteral("settings")) && !engine.rootObjects().isEmpty()) {
    engine.rootObjects().constFirst()->setProperty("activePage", 2);
  }

  const QString screenshotPath = parser.value(QStringLiteral("screenshot"));
  if (!screenshotPath.isEmpty() && !engine.rootObjects().isEmpty()) {
    QObject *rootObject = engine.rootObjects().constFirst();
    rootObject->setProperty("activePage", 1);
    QTimer::singleShot(750, &application, [rootObject, screenshotPath] {
      auto *window = qobject_cast<QQuickWindow *>(rootObject);
      const bool saved = window != nullptr && window->grabWindow().save(screenshotPath, "PNG");
      QCoreApplication::exit(saved ? 0 : 2);
    });
  }

  return application.exec();
}

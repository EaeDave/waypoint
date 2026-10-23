#include "WaypointVersion.hpp"
#include "app/WaypointController.hpp"

#include <QCommandLineParser>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>

int main(int argc, char *argv[]) {
  QLocale::setDefault(QLocale(QLocale::Portuguese, QLocale::Brazil));

  QGuiApplication application(argc, argv);
  QCommandLineParser parser;
  parser.addHelpOption();
  parser.addOption({QStringLiteral("screenshot"), QStringLiteral("Renderiza a janela em PNG e encerra"),
                    QStringLiteral("caminho")});
  parser.addOption({QStringLiteral("page"), QStringLiteral("Abre uma página: today, tasks, calendar ou settings"),
                    QStringLiteral("página")});
  parser.addOption({QStringLiteral("settings"), QStringLiteral("Abre as configurações de sincronização")});
  parser.process(application);
  QCoreApplication::setOrganizationName(QStringLiteral("Waypoint"));
  QCoreApplication::setApplicationName(QStringLiteral("Waypoint"));
  QGuiApplication::setApplicationDisplayName(QStringLiteral("Waypoint"));
  QCoreApplication::setApplicationVersion(QString::fromLatin1(waypoint::version));

  waypoint::WaypointController controller;
  QQmlApplicationEngine engine;
  engine.setInitialProperties({{QStringLiteral("waypointController"), QVariant::fromValue(&controller)}});

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreationFailed, &application, [] { QCoreApplication::exit(1); },
      Qt::QueuedConnection);
  engine.loadFromModule(QStringLiteral("Waypoint"), QStringLiteral("Main"));

  const QString page =
      parser.isSet(QStringLiteral("settings")) ? QStringLiteral("settings") : parser.value(QStringLiteral("page"));
  if (!page.isEmpty() && !engine.rootObjects().isEmpty()) {
    engine.rootObjects().constFirst()->setProperty("activePage", page);
  }

  const QString screenshotPath = parser.value(QStringLiteral("screenshot"));
  if (!screenshotPath.isEmpty() && !engine.rootObjects().isEmpty()) {
    QObject *rootObject = engine.rootObjects().constFirst();
    QTimer::singleShot(750, &application, [rootObject, screenshotPath] {
      auto *window = qobject_cast<QQuickWindow *>(rootObject);
      const bool saved = window != nullptr && window->grabWindow().save(screenshotPath, "PNG");
      QCoreApplication::exit(saved ? 0 : 2);
    });
  }

  return application.exec();
}

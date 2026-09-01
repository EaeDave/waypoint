#include "core/TaskStore.hpp"
#include "ipc/WaypointIpcServer.hpp"
#include "sync/HolidaySyncEngine.hpp"
#include "sync/SyncEngine.hpp"

#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>

namespace {

void logJson(const QString &level, const QString &message) {
  const QJsonObject entry{{QStringLiteral("level"), level},
                          {QStringLiteral("component"), QStringLiteral("waypointd")},
                          {QStringLiteral("message"), message}};
  const QByteArray line = QJsonDocument(entry).toJson(QJsonDocument::Compact);
  if (level == QStringLiteral("error")) {
    fprintf(stderr, "%s\n", line.constData());
  } else {
    fprintf(stdout, "%s\n", line.constData());
  }
  fflush(level == QStringLiteral("error") ? stderr : stdout);
}

} // namespace

int main(int argc, char *argv[]) {
  QCoreApplication application(argc, argv);
  QCoreApplication::setOrganizationName(QStringLiteral("Waypoint"));
  QCoreApplication::setApplicationName(QStringLiteral("Waypoint"));

  waypoint::TaskStore taskStore(waypoint::defaultWaypointDatabasePath());
  QString error;
  if (!taskStore.open(&error)) {
    logJson(QStringLiteral("error"), error);
    return 1;
  }

  waypoint::SyncEngine syncEngine(&taskStore);
  waypoint::HolidaySyncEngine holidaySyncEngine(&taskStore);
  waypoint::WaypointIpcServer server(&taskStore, &syncEngine, &holidaySyncEngine);
  if (!server.listen(&error)) {
    logJson(QStringLiteral("error"), error);
    return 1;
  }
  syncEngine.start();
  holidaySyncEngine.start();

  logJson(QStringLiteral("info"), QStringLiteral("Waypoint daemon is ready"));
  return application.exec();
}

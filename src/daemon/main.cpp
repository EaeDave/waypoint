#include "WaypointVersion.hpp"
#include "core/TaskStore.hpp"
#include "ipc/WaypointIpcServer.hpp"
#include "reminders/ReminderScheduler.hpp"
#include "reminders/SystemNotificationSink.hpp"
#include "sync/HolidaySyncEngine.hpp"
#include "sync/SyncEngine.hpp"
#include "update/UpdateChecker.hpp"

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
  QCoreApplication::setApplicationVersion(QString::fromLatin1(waypoint::version));

  waypoint::TaskStore taskStore(waypoint::defaultWaypointDatabasePath());
  QString error;
  if (!taskStore.open(&error)) {
    logJson(QStringLiteral("error"), error);
    return 1;
  }

  waypoint::SyncEngine syncEngine(&taskStore);
  waypoint::HolidaySyncEngine holidaySyncEngine(&taskStore);
  waypoint::SystemNotificationSink notificationSink;
  waypoint::ReminderScheduler reminderScheduler(&taskStore, &notificationSink);
  QObject::connect(&reminderScheduler, &waypoint::ReminderScheduler::deliveryFailed,
                   [](const QString &message) { logJson(QStringLiteral("error"), message); });
  QObject::connect(&reminderScheduler, &waypoint::ReminderScheduler::reminderDelivered,
                   [](const QString &taskId, const QString &title) {
                     logJson(QStringLiteral("info"),
                             QStringLiteral("Delivered reminder for task %1: %2").arg(taskId, title));
                   });
  waypoint::UpdateChecker updateChecker(waypoint::UpdateAsset::LinuxX86_64);
  waypoint::WaypointIpcServer server(&taskStore, &syncEngine, &holidaySyncEngine, &updateChecker);
  if (!server.listen(&error)) {
    logJson(QStringLiteral("error"), error);
    return 1;
  }
  syncEngine.start();
  holidaySyncEngine.start();
  updateChecker.start();
  reminderScheduler.start();

  logJson(QStringLiteral("info"), QStringLiteral("Waypoint daemon is ready"));
  return application.exec();
}

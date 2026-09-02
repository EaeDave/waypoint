#include "reminders/SystemNotificationSink.hpp"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QProcess>
#include <QStandardPaths>
#include <QVariantMap>

namespace waypoint {
namespace {

constexpr auto notificationSoundName = "message-new-instant";

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

bool SystemNotificationSink::send(const TaskOccurrence &occurrence,
                                  QString *errorMessage) {
  const QDBusConnection sessionBus = QDBusConnection::sessionBus();
  if (!sessionBus.isConnected()) {
    setError(errorMessage, QStringLiteral("Cannot connect to the desktop notification bus"));
    return false;
  }

  const QString soundPlayer = QStandardPaths::findExecutable(QStringLiteral("canberra-gtk-play"));
  QVariantMap hints{
      {QStringLiteral("category"), QStringLiteral("reminder")},
      {QStringLiteral("desktop-entry"), QStringLiteral("waypoint")},
      {QStringLiteral("sound-name"), QString::fromLatin1(notificationSoundName)},
      {QStringLiteral("urgency"), QVariant::fromValue(static_cast<uchar>(1))},
  };
  if (!soundPlayer.isEmpty()) {
    hints.insert(QStringLiteral("suppress-sound"), true);
  }

  const QString summary = occurrence.emoji.isEmpty()
                              ? occurrence.title
                              : QStringLiteral("%1  %2").arg(occurrence.emoji, occurrence.title);
  const QString body = QStringLiteral("Agora · %1")
                           .arg(occurrence.scheduledTime.toString(QStringLiteral("HH:mm")));
  QDBusMessage request = QDBusMessage::createMethodCall(
      QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
      QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("Notify"));
  request << QStringLiteral("Waypoint") << static_cast<uint>(0)
          << QStringLiteral("view-calendar-tasks") << summary << body << QStringList{} << hints << -1;

  const QDBusMessage response = sessionBus.call(request, QDBus::Block, 3000);
  if (response.type() == QDBusMessage::ErrorMessage) {
    setError(errorMessage,
             QStringLiteral("Cannot send desktop notification: %1").arg(response.errorMessage()));
    return false;
  }

  if (!soundPlayer.isEmpty()) {
    QProcess::startDetached(soundPlayer,
                            {QStringLiteral("-i"), QString::fromLatin1(notificationSoundName),
                             QStringLiteral("-d"), QStringLiteral("Waypoint task reminder")});
  }
  return true;
}

} // namespace waypoint

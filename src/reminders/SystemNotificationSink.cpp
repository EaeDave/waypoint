#include "reminders/SystemNotificationSink.hpp"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QProcess>
#include <QStandardPaths>
#include <QVariantMap>

namespace waypoint {
namespace {

constexpr auto notificationSoundName = "message-new-instant";

QString reminderLeadLabel(const int minutesBefore) {
  if (minutesBefore % (7 * 24 * 60) == 0) {
    const int weeks = minutesBefore / (7 * 24 * 60);
    return weeks == 1 ? QStringLiteral("1 semana antes") : QStringLiteral("%1 semanas antes").arg(weeks);
  }
  if (minutesBefore % (24 * 60) == 0) {
    const int days = minutesBefore / (24 * 60);
    return days == 1 ? QStringLiteral("1 dia antes") : QStringLiteral("%1 dias antes").arg(days);
  }
  if (minutesBefore % 60 == 0) {
    const int hours = minutesBefore / 60;
    return hours == 1 ? QStringLiteral("1 hora antes") : QStringLiteral("%1 horas antes").arg(hours);
  }
  return minutesBefore == 1 ? QStringLiteral("1 minuto antes")
                            : QStringLiteral("%1 minutos antes").arg(minutesBefore);
}

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

bool sendDesktopNotification(const QString &summary, const QString &body, const QString &soundDescription,
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
  QDBusMessage request = QDBusMessage::createMethodCall(
      QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"),
      QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("Notify"));
  request << QStringLiteral("Waypoint") << static_cast<uint>(0) << QStringLiteral("view-calendar-tasks")
          << summary << body << QStringList{} << hints << -1;
  const QDBusMessage response = sessionBus.call(request, QDBus::Block, 3000);
  if (response.type() == QDBusMessage::ErrorMessage) {
    setError(errorMessage,
             QStringLiteral("Cannot send desktop notification: %1").arg(response.errorMessage()));
    return false;
  }
  if (!soundPlayer.isEmpty()) {
    QProcess::startDetached(soundPlayer, {QStringLiteral("-i"), QString::fromLatin1(notificationSoundName),
                                          QStringLiteral("-d"), soundDescription});
  }
  return true;
}

} // namespace

bool SystemNotificationSink::send(const TaskOccurrence &occurrence, const int reminderMinutesBefore,
                                  QString *errorMessage) {
  const QString summary = occurrence.emoji.isEmpty()
                              ? occurrence.title
                              : QStringLiteral("%1  %2").arg(occurrence.emoji, occurrence.title);
  const QString body =
      reminderMinutesBefore == 0
          ? QStringLiteral("Agora · %1").arg(occurrence.scheduledTime.toString(QStringLiteral("HH:mm")))
          : QStringLiteral("%1 · %2 às %3")
                .arg(reminderLeadLabel(reminderMinutesBefore),
                     occurrence.occurrenceDate.toString(QStringLiteral("dd/MM")),
                     occurrence.scheduledTime.toString(QStringLiteral("HH:mm")));
  return sendDesktopNotification(summary, body, QStringLiteral("Waypoint task reminder"), errorMessage);
}

bool SystemNotificationSink::sendHabit(const HabitProgress &progress, const QTime &reminderTime,
                                       QString *errorMessage) {
  const QString summary =
      progress.habit.emoji.isEmpty()
          ? progress.habit.title
          : QStringLiteral("%1  %2").arg(progress.habit.emoji, progress.habit.title);
  const QString unitSuffix =
      progress.habit.unit.isEmpty() ? QString() : QStringLiteral(" %1").arg(progress.habit.unit);
  const QString body =
      QStringLiteral("%1 · %2 / %3%4 · registre seu progresso")
          .arg(reminderTime.toString(QStringLiteral("HH:mm")))
          .arg(progress.amount)
          .arg(progress.habit.targetAmount)
          .arg(unitSuffix);
  return sendDesktopNotification(summary, body, QStringLiteral("Waypoint habit reminder"), errorMessage);
}

} // namespace waypoint

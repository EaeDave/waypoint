#include "ipc/WaypointIpcClient.hpp"

#include "ipc/WaypointProtocol.hpp"

#include <QJsonArray>
#include <QLocalSocket>

namespace waypoint {
namespace {

bool responseSucceeded(const QJsonObject &response, QString *errorMessage) {
  if (response.value(QStringLiteral("ok")).toBool()) {
    return true;
  }
  if (errorMessage != nullptr) {
    *errorMessage =
        response.value(QStringLiteral("error")).toString(QStringLiteral("Waypoint IPC request failed"));
  }
  return false;
}

TaskOccurrence occurrenceFromJson(const QJsonObject &json) {
  TaskOccurrence occurrence;
  occurrence.taskId = json.value(QStringLiteral("taskId")).toString();
  occurrence.title = json.value(QStringLiteral("title")).toString();
  occurrence.occurrenceDate =
      QDate::fromString(json.value(QStringLiteral("occurrenceDate")).toString(), Qt::ISODate);
  occurrence.scheduledTime =
      QTime::fromString(json.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("HH:mm"));
  occurrence.reminderMinutesBefore =
      taskReminderMinutesBeforeFromJson(json.value(QStringLiteral("reminderMinutesBefore")));
  occurrence.emoji = json.value(QStringLiteral("emoji")).toString();
  occurrence.completed = json.value(QStringLiteral("completed")).toBool();
  occurrence.recurring = json.value(QStringLiteral("recurring")).toBool();
  occurrence.calendarMarker = json.value(QStringLiteral("calendarMarker")).toBool(true);
  occurrence.recurrenceLabel = json.value(QStringLiteral("recurrenceLabel")).toString();
  occurrence.recurrence = RecurrenceRule::fromJson(json.value(QStringLiteral("recurrence")).toObject());
  return occurrence;
}

} // namespace

WaypointIpcClient::WaypointIpcClient(QObject *parent) : QObject(parent) {}

QJsonObject WaypointIpcClient::request(const QJsonObject &message, QString *errorMessage,
                                       int timeoutMilliseconds) const {
  QLocalSocket socket;
  socket.connectToServer(QString::fromLatin1(protocol::socketName), QIODevice::ReadWrite);
  if (!socket.waitForConnected(timeoutMilliseconds)) {
    if (errorMessage != nullptr) {
      *errorMessage = QStringLiteral("Cannot connect to Waypoint daemon: %1").arg(socket.errorString());
    }
    return {};
  }

  QString writeError;
  if (!protocol::writeMessage(&socket, message, &writeError) ||
      !socket.waitForBytesWritten(timeoutMilliseconds)) {
    if (errorMessage != nullptr) {
      *errorMessage =
          writeError.isEmpty()
              ? QStringLiteral("Cannot send request to Waypoint daemon: %1").arg(socket.errorString())
              : writeError;
    }
    return {};
  }

  QByteArray responseLine;
  while (!responseLine.contains('\n')) {
    if (!socket.waitForReadyRead(timeoutMilliseconds)) {
      if (errorMessage != nullptr) {
        *errorMessage =
            QStringLiteral("Waypoint daemon did not respond within %1 ms").arg(timeoutMilliseconds);
      }
      return {};
    }
    responseLine.append(socket.readAll());
  }
  return protocol::decodeMessage(responseLine.left(responseLine.indexOf('\n')), errorMessage);
}

bool WaypointIpcClient::ping(QString *errorMessage) const {
  const QJsonObject response = request({{QStringLiteral("command"), QStringLiteral("ping")}}, errorMessage);
  return responseSucceeded(response, errorMessage);
}

QList<TaskRecord> WaypointIpcClient::listTasks(QString *errorMessage) const {
  const QJsonObject response = request({{QStringLiteral("command"), QStringLiteral("list")}}, errorMessage);
  if (!responseSucceeded(response, errorMessage)) {
    return {};
  }
  QList<TaskRecord> tasks;
  const QJsonArray taskValues = response.value(QStringLiteral("tasks")).toArray();
  tasks.reserve(taskValues.size());
  for (const QJsonValue &value : taskValues) {
    tasks.append(TaskRecord::fromJson(value.toObject()));
  }
  return tasks;
}

QList<TaskOccurrence> WaypointIpcClient::listOccurrences(const QDate &from, const QDate &to,
                                                         QString *errorMessage) const {
  const QJsonObject response = request({{QStringLiteral("command"), QStringLiteral("occurrences")},
                                        {QStringLiteral("from"), from.toString(Qt::ISODate)},
                                        {QStringLiteral("to"), to.toString(Qt::ISODate)}},
                                       errorMessage);
  if (!responseSucceeded(response, errorMessage)) {
    return {};
  }
  QList<TaskOccurrence> occurrences;
  for (const QJsonValue &value : response.value(QStringLiteral("occurrences")).toArray()) {
    occurrences.append(occurrenceFromJson(value.toObject()));
  }
  return occurrences;
}

QList<TaskOccurrence> WaypointIpcClient::listActionableOccurrences(const QDate &today,
                                                                   QString *errorMessage) const {
  const QJsonObject response = request({{QStringLiteral("command"), QStringLiteral("today")},
                                        {QStringLiteral("date"), today.toString(Qt::ISODate)}},
                                       errorMessage);
  if (!responseSucceeded(response, errorMessage)) {
    return {};
  }
  QList<TaskOccurrence> occurrences;
  for (const QJsonValue &value : response.value(QStringLiteral("occurrences")).toArray()) {
    occurrences.append(occurrenceFromJson(value.toObject()));
  }
  return occurrences;
}

bool WaypointIpcClient::addTask(const QString &title, const QDate &scheduledDate, const QTime &scheduledTime,
                                const RecurrenceRule &recurrence, const QList<int> &reminderMinutesBefore,
                                const QString &emoji, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("add")},
          {QStringLiteral("title"), title},
          {QStringLiteral("scheduledDate"), scheduledDate.toString(Qt::ISODate)},
          {QStringLiteral("scheduledTime"),
           scheduledTime.isValid() ? scheduledTime.toString(QStringLiteral("HH:mm")) : QString()},
          {QStringLiteral("recurrence"), recurrence.toJson()},
          {QStringLiteral("emoji"), emoji},
          {QStringLiteral("reminderMinutesBefore"), taskReminderMinutesBeforeToJson(reminderMinutesBefore)},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage);
}

bool WaypointIpcClient::setTaskCompleted(const QString &taskId, bool completed, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("complete")},
          {QStringLiteral("taskId"), taskId},
          {QStringLiteral("completed"), completed},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage);
}

bool WaypointIpcClient::setOccurrenceCompleted(const QString &taskId, const QDate &occurrenceDate,
                                               const bool completed, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("complete")},
          {QStringLiteral("taskId"), taskId},
          {QStringLiteral("occurrenceDate"), occurrenceDate.toString(Qt::ISODate)},
          {QStringLiteral("completed"), completed},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage);
}

bool WaypointIpcClient::skipOccurrence(const QString &taskId, const QDate &occurrenceDate,
                                       QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("skip")},
          {QStringLiteral("taskId"), taskId},
          {QStringLiteral("occurrenceDate"), occurrenceDate.toString(Qt::ISODate)},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage);
}

bool WaypointIpcClient::deleteOccurrence(const QString &taskId, const QDate &occurrenceDate,
                                         const QString &scope, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("delete-occurrence")},
          {QStringLiteral("taskId"), taskId},
          {QStringLiteral("occurrenceDate"), occurrenceDate.toString(Qt::ISODate)},
          {QStringLiteral("scope"), scope},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage);
}

bool WaypointIpcClient::rescheduleTask(const QString &taskId, const QDate &scheduledDate,
                                       const QTime &scheduledTime, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("reschedule")},
          {QStringLiteral("taskId"), taskId},
          {QStringLiteral("scheduledDate"), scheduledDate.toString(Qt::ISODate)},
          {QStringLiteral("scheduledTime"), scheduledTime.toString(QStringLiteral("HH:mm"))},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage);
}
bool WaypointIpcClient::editTask(const QString &taskId, const QString &title, const QTime &scheduledTime,
                                 const RecurrenceRule &recurrence,
                                 const std::optional<QList<int>> &reminderMinutesBefore, const QString &emoji,
                                 QString *errorMessage) const {
  QJsonObject message{
      {QStringLiteral("command"), QStringLiteral("edit")},
      {QStringLiteral("taskId"), taskId},
      {QStringLiteral("title"), title},
      {QStringLiteral("scheduledTime"), scheduledTime.toString(QStringLiteral("HH:mm"))},
      {QStringLiteral("recurrence"), recurrence.toJson()},
      {QStringLiteral("emoji"), emoji},
  };
  if (reminderMinutesBefore.has_value()) {
    message.insert(QStringLiteral("reminderMinutesBefore"),
                   taskReminderMinutesBeforeToJson(*reminderMinutesBefore));
  }
  const QJsonObject response = request(message, errorMessage);
  return responseSucceeded(response, errorMessage);
}

bool WaypointIpcClient::deleteTask(const QString &taskId, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("delete")},
          {QStringLiteral("taskId"), taskId},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage);
}

QJsonObject WaypointIpcClient::syncConfiguration(QString *errorMessage) const {
  const QJsonObject response =
      request({{QStringLiteral("command"), QStringLiteral("get-sync-config")}}, errorMessage);
  return responseSucceeded(response, errorMessage) ? response : QJsonObject{};
}

QJsonObject WaypointIpcClient::syncStatus(QString *errorMessage) const {
  const QJsonObject response =
      request({{QStringLiteral("command"), QStringLiteral("sync-status")}}, errorMessage);
  return responseSucceeded(response, errorMessage) ? response : QJsonObject{};
}

bool WaypointIpcClient::saveSyncConfiguration(const QString &endpoint, const QString &token,
                                              bool replaceToken, QString *errorMessage) const {
  QJsonObject message{
      {QStringLiteral("command"), QStringLiteral("set-sync-config")},
      {QStringLiteral("endpoint"), endpoint},
  };
  if (replaceToken) {
    message.insert(QStringLiteral("token"), token);
  }
  return responseSucceeded(request(message, errorMessage), errorMessage);
}

bool WaypointIpcClient::syncNow(QString *errorMessage) const {
  return responseSucceeded(request({{QStringLiteral("command"), QStringLiteral("sync-now")}}, errorMessage),
                           errorMessage);
}
QJsonObject WaypointIpcClient::holidayPreferences(QString *errorMessage) const {
  const QJsonObject response =
      request({{QStringLiteral("command"), QStringLiteral("holiday-preferences")}}, errorMessage);
  return responseSucceeded(response, errorMessage) ? response.value(QStringLiteral("preferences")).toObject()
                                                   : QJsonObject{};
}

bool WaypointIpcClient::saveHolidayPreferences(const QJsonObject &preferences, QString *errorMessage) const {
  return responseSucceeded(request(
                               {
                                   {QStringLiteral("command"), QStringLiteral("set-holiday-preferences")},
                                   {QStringLiteral("preferences"), preferences},
                               },
                               errorMessage),
                           errorMessage);
}

QJsonObject WaypointIpcClient::holidays(const QDate &from, const QDate &to, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("holidays")},
          {QStringLiteral("from"), from.toString(Qt::ISODate)},
          {QStringLiteral("to"), to.toString(Qt::ISODate)},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage) ? response : QJsonObject{};
}

QJsonArray WaypointIpcClient::municipalities(const QString &stateCode, QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("municipalities")},
          {QStringLiteral("state"), stateCode},
      },
      errorMessage);
  return responseSucceeded(response, errorMessage)
             ? response.value(QStringLiteral("municipalities")).toArray()
             : QJsonArray{};
}

QJsonObject WaypointIpcClient::holidayStatus(QString *errorMessage) const {
  const QJsonObject response =
      request({{QStringLiteral("command"), QStringLiteral("holiday-status")}}, errorMessage);
  return responseSucceeded(response, errorMessage) ? response : QJsonObject{};
}

bool WaypointIpcClient::refreshHolidays(QString *errorMessage) const {
  return responseSucceeded(
      request({{QStringLiteral("command"), QStringLiteral("refresh-holidays")}}, errorMessage), errorMessage);
}

} // namespace waypoint

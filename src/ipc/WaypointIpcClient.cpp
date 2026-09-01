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

bool WaypointIpcClient::addTask(const QString &title, const QDate &scheduledDate,
                                QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("add")},
          {QStringLiteral("title"), title},
          {QStringLiteral("scheduledDate"), scheduledDate.toString(Qt::ISODate)},
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

bool WaypointIpcClient::rescheduleTask(const QString &taskId, const QDate &scheduledDate,
                                       QString *errorMessage) const {
  const QJsonObject response = request(
      {
          {QStringLiteral("command"), QStringLiteral("reschedule")},
          {QStringLiteral("taskId"), taskId},
          {QStringLiteral("scheduledDate"), scheduledDate.toString(Qt::ISODate)},
      },
      errorMessage);
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

} // namespace waypoint

#include "ipc/WaypointIpcServer.hpp"

#include "core/TaskStore.hpp"
#include "ipc/WaypointProtocol.hpp"
#include "sync/HolidaySyncEngine.hpp"
#include "sync/SyncEngine.hpp"

#include <QJsonArray>
#include <QLocalSocket>

namespace waypoint {

WaypointIpcServer::WaypointIpcServer(TaskStore *taskStore, SyncEngine *syncEngine,
                                     HolidaySyncEngine *holidaySyncEngine, QObject *parent)
    : QObject(parent), m_taskStore(taskStore), m_syncEngine(syncEngine),
      m_holidaySyncEngine(holidaySyncEngine) {
  connect(&m_server, &QLocalServer::newConnection, this, &WaypointIpcServer::acceptConnections);
}

bool WaypointIpcServer::listen(QString *errorMessage) {
  m_server.setSocketOptions(QLocalServer::UserAccessOption);
  if (m_server.listen(QString::fromLatin1(protocol::socketName))) {
    return true;
  }

  // QLocalServer may leave a stale filesystem socket after a crash. Probe
  // before unlinking it: removing a live daemon's socket creates split-brain.
  QLocalSocket probe;
  probe.connectToServer(QString::fromLatin1(protocol::socketName), QIODevice::ReadOnly);
  if (probe.waitForConnected(100)) {
    if (errorMessage != nullptr) {
      *errorMessage = QStringLiteral("A Waypoint daemon is already listening on '%1'")
                          .arg(QString::fromLatin1(protocol::socketName));
    }
    return false;
  }
  QLocalServer::removeServer(QString::fromLatin1(protocol::socketName));
  if (m_server.listen(QString::fromLatin1(protocol::socketName))) {
    return true;
  }
  if (errorMessage != nullptr) {
    *errorMessage = QStringLiteral("Cannot listen on Waypoint IPC socket '%1': %2")
                        .arg(QString::fromLatin1(protocol::socketName), m_server.errorString());
  }
  return false;
}

void WaypointIpcServer::acceptConnections() {
  while (QLocalSocket *socket = m_server.nextPendingConnection()) {
    m_buffers.insert(socket, {});
    connect(socket, &QLocalSocket::readyRead, this, &WaypointIpcServer::readClientMessage);
    connect(socket, &QLocalSocket::disconnected, this, &WaypointIpcServer::removeClient);
  }
}

void WaypointIpcServer::readClientMessage() {
  auto *socket = qobject_cast<QLocalSocket *>(sender());
  if (socket == nullptr) {
    return;
  }
  QByteArray &buffer = m_buffers[socket];
  buffer.append(socket->readAll());
  const qsizetype newline = buffer.indexOf('\n');
  if (newline < 0) {
    return;
  }

  QString decodeError;
  const QJsonObject request = protocol::decodeMessage(buffer.left(newline), &decodeError);
  if (!decodeError.isEmpty()) {
    respondAndClose(socket, protocol::errorResponse(decodeError));
    return;
  }
  respondAndClose(socket, handleRequest(request));
}

QJsonObject WaypointIpcServer::handleRequest(const QJsonObject &request) {
  const QString command = request.value(QStringLiteral("command")).toString();
  QString error;

  if (command == QStringLiteral("ping")) {
    return {{QStringLiteral("ok"), true}, {QStringLiteral("status"), QStringLiteral("ready")}};
  }
  if (command == QStringLiteral("list")) {
    QJsonArray tasks;
    const QList<TaskRecord> records = m_taskStore->listActiveTasks(&error);
    if (!error.isEmpty()) {
      return protocol::errorResponse(error);
    }
    for (const TaskRecord &task : records) {
      tasks.append(task.toJson());
    }
    return {{QStringLiteral("ok"), true}, {QStringLiteral("tasks"), tasks}};
  }
  if (command == QStringLiteral("add")) {
    TaskRecord task;
    const QString title = request.value(QStringLiteral("title")).toString();
    const QDate date =
        QDate::fromString(request.value(QStringLiteral("scheduledDate")).toString(), Qt::ISODate);
    if (!m_taskStore->createTask(title, date, &task, &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}, {QStringLiteral("task"), task.toJson()}};
  }
  if (command == QStringLiteral("complete")) {
    const QString taskId = request.value(QStringLiteral("taskId")).toString();
    const bool completed = request.value(QStringLiteral("completed")).toBool(true);
    if (!m_taskStore->setTaskCompleted(taskId, completed, &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("reschedule")) {
    const QString taskId = request.value(QStringLiteral("taskId")).toString();
    const QDate date =
        QDate::fromString(request.value(QStringLiteral("scheduledDate")).toString(), Qt::ISODate);
    if (!m_taskStore->rescheduleTask(taskId, date, &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("delete")) {
    const QString taskId = request.value(QStringLiteral("taskId")).toString();
    if (!m_taskStore->deleteTask(taskId, &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("get-sync-config")) {
    QJsonObject response = m_syncEngine->publicConfiguration();
    response.insert(QStringLiteral("ok"), true);
    return response;
  }
  if (command == QStringLiteral("sync-status")) {
    QJsonObject response = m_syncEngine->status();
    response.insert(QStringLiteral("ok"), true);
    return response;
  }
  if (command == QStringLiteral("set-sync-config")) {
    const bool replaceToken = request.contains(QStringLiteral("token"));
    if (!m_syncEngine->updateConfiguration(request.value(QStringLiteral("endpoint")).toString(),
                                           request.value(QStringLiteral("token")).toString().toUtf8(),
                                           replaceToken, &error)) {
      return protocol::errorResponse(error);
    }
    m_holidaySyncEngine->syncNow();
    QJsonObject response = m_syncEngine->publicConfiguration();
    response.insert(QStringLiteral("ok"), true);
    return response;
  }
  if (command == QStringLiteral("sync-now")) {
    m_syncEngine->syncNow();
    m_holidaySyncEngine->syncNow();
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("holiday-preferences")) {
    QJsonObject preferences = m_taskStore->holidayPreferences(&error);
    if (!error.isEmpty()) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}, {QStringLiteral("preferences"), preferences}};
  }
  if (command == QStringLiteral("set-holiday-preferences")) {
    if (!m_holidaySyncEngine->updatePreferences(request.value(QStringLiteral("preferences")).toObject(),
                                                &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("holidays")) {
    const QDate from = QDate::fromString(request.value(QStringLiteral("from")).toString(), Qt::ISODate);
    const QDate to = QDate::fromString(request.value(QStringLiteral("to")).toString(), Qt::ISODate);
    const QJsonArray holidays = m_taskStore->listHolidays(from, to, &error);
    if (!error.isEmpty()) {
      return protocol::errorResponse(error);
    }
    const QJsonArray coverage = m_taskStore->holidayCoverage(&error);
    if (!error.isEmpty()) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true},
            {QStringLiteral("holidays"), holidays},
            {QStringLiteral("coverage"), coverage}};
  }
  if (command == QStringLiteral("municipalities")) {
    const QString stateCode = request.value(QStringLiteral("state")).toString();
    const QJsonArray municipalities = m_taskStore->listMunicipalities(stateCode, &error);
    if (!error.isEmpty()) {
      return protocol::errorResponse(error);
    }
    if (municipalities.isEmpty()) {
      m_holidaySyncEngine->refreshMunicipalities(stateCode);
    }
    return {{QStringLiteral("ok"), true}, {QStringLiteral("municipalities"), municipalities}};
  }
  if (command == QStringLiteral("holiday-status")) {
    QJsonObject response = m_holidaySyncEngine->status();
    response.insert(QStringLiteral("ok"), true);
    return response;
  }
  if (command == QStringLiteral("refresh-holidays")) {
    m_holidaySyncEngine->syncNow();
    return {{QStringLiteral("ok"), true}};
  }
  return protocol::errorResponse(QStringLiteral("Unknown Waypoint IPC command: '%1'").arg(command));
}

void WaypointIpcServer::respondAndClose(QLocalSocket *socket, const QJsonObject &response) {
  QString writeError;
  if (!protocol::writeMessage(socket, response, &writeError)) {
    qWarning().noquote() << writeError;
  }
  socket->flush();
  socket->disconnectFromServer();
}

void WaypointIpcServer::removeClient() {
  auto *socket = qobject_cast<QLocalSocket *>(sender());
  if (socket == nullptr) {
    return;
  }
  m_buffers.remove(socket);
  socket->deleteLater();
}

} // namespace waypoint

#include "ipc/WaypointIpcServer.hpp"

#include "core/TaskStore.hpp"
#include "ipc/WaypointProtocol.hpp"
#include "sync/HolidaySyncEngine.hpp"
#include "sync/SyncEngine.hpp"

#include <QJsonArray>
#include <QLocalSocket>
#include <QProcess>
#include <QStandardPaths>

namespace waypoint {
namespace {

constexpr auto completionSoundName = "complete";

void playCompletionSound() {
  const QString soundPlayer = QStandardPaths::findExecutable(QStringLiteral("canberra-gtk-play"));
  if (soundPlayer.isEmpty()) {
    return;
  }
  QProcess::startDetached(soundPlayer, {QStringLiteral("-i"), QString::fromLatin1(completionSoundName),
                                        QStringLiteral("-d"), QStringLiteral("Waypoint task completed")});
}

} // namespace

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
  if (command == QStringLiteral("occurrences")) {
    const QDate from = QDate::fromString(request.value(QStringLiteral("from")).toString(), Qt::ISODate);
    const QDate to = QDate::fromString(request.value(QStringLiteral("to")).toString(), Qt::ISODate);
    const QList<TaskOccurrence> records = m_taskStore->listOccurrences(from, to, &error);
    if (!error.isEmpty()) {
      return protocol::errorResponse(error);
    }
    QJsonArray occurrences;
    for (const TaskOccurrence &occurrence : records) {
      occurrences.append(occurrence.toJson());
    }
    return {{QStringLiteral("ok"), true},
            {QStringLiteral("from"), from.toString(Qt::ISODate)},
            {QStringLiteral("to"), to.toString(Qt::ISODate)},
            {QStringLiteral("occurrences"), occurrences}};
  }
  if (command == QStringLiteral("today")) {
    const QString requestedDate = request.value(QStringLiteral("date")).toString();
    const QDate today =
        requestedDate.isEmpty() ? QDate::currentDate() : QDate::fromString(requestedDate, Qt::ISODate);
    const QList<TaskOccurrence> records = m_taskStore->listActionableOccurrences(today, &error);
    if (!error.isEmpty()) {
      return protocol::errorResponse(error);
    }
    QJsonArray occurrences;
    for (const TaskOccurrence &occurrence : records) {
      occurrences.append(occurrence.toJson());
    }
    const OccurrenceSummary summary = summarizeOccurrences(records, today);
    return {{QStringLiteral("ok"), true},
            {QStringLiteral("date"), today.toString(Qt::ISODate)},
            {QStringLiteral("pendingCount"), summary.pendingToday},
            {QStringLiteral("overdueCount"), summary.overdue},
            {QStringLiteral("occurrences"), occurrences}};
  }
  if (command == QStringLiteral("add")) {
    TaskRecord task;
    const QString title = request.value(QStringLiteral("title")).toString();
    const QString emoji = request.value(QStringLiteral("emoji")).toString();
    const QDate date =
        QDate::fromString(request.value(QStringLiteral("scheduledDate")).toString(), Qt::ISODate);
    const QTime time =
        QTime::fromString(request.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("HH:mm"));
    const RecurrenceRule recurrence =
        RecurrenceRule::fromJson(request.value(QStringLiteral("recurrence")).toObject());
    if (!m_taskStore->createTask(title, date, time, recurrence, emoji, &task, &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}, {QStringLiteral("task"), task.toJson()}};
  }
  if (command == QStringLiteral("complete")) {
    const QString taskId = request.value(QStringLiteral("taskId")).toString();
    const bool completed = request.value(QStringLiteral("completed")).toBool(true);
    const QString occurrenceDateKey = request.value(QStringLiteral("occurrenceDate")).toString();
    const bool succeeded =
        occurrenceDateKey.isEmpty()
            ? m_taskStore->setTaskCompleted(taskId, completed, &error)
            : m_taskStore->setOccurrenceCompleted(taskId, QDate::fromString(occurrenceDateKey, Qt::ISODate),
                                                  completed, &error);
    if (!succeeded) {
      return protocol::errorResponse(error);
    }
    if (completed) {
      playCompletionSound();
    }
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("delete-occurrence")) {
    const QString taskId = request.value(QStringLiteral("taskId")).toString();
    const QDate occurrenceDate =
        QDate::fromString(request.value(QStringLiteral("occurrenceDate")).toString(), Qt::ISODate);
    const QString scopeName = request.value(QStringLiteral("scope")).toString();
    RecurrenceEditScope scope = RecurrenceEditScope::Occurrence;
    if (scopeName == QStringLiteral("following")) {
      scope = RecurrenceEditScope::Following;
    } else if (scopeName == QStringLiteral("series")) {
      scope = RecurrenceEditScope::Series;
    } else if (scopeName != QStringLiteral("occurrence")) {
      return protocol::errorResponse(QStringLiteral("Invalid recurrence edit scope"));
    }
    if (!m_taskStore->deleteOccurrence(taskId, occurrenceDate, scope, &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("edit")) {
    const QString taskId = request.value(QStringLiteral("taskId")).toString();
    const QString title = request.value(QStringLiteral("title")).toString();
    const QString emoji = request.value(QStringLiteral("emoji")).toString();
    const QTime time =
        QTime::fromString(request.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("HH:mm"));
    const RecurrenceRule recurrence =
        RecurrenceRule::fromJson(request.value(QStringLiteral("recurrence")).toObject());
    if (!m_taskStore->editTask(taskId, title, time, recurrence, emoji, &error)) {
      return protocol::errorResponse(error);
    }
    return {{QStringLiteral("ok"), true}};
  }
  if (command == QStringLiteral("reschedule")) {
    const QString taskId = request.value(QStringLiteral("taskId")).toString();
    const QDate date =
        QDate::fromString(request.value(QStringLiteral("scheduledDate")).toString(), Qt::ISODate);
    const QTime time =
        QTime::fromString(request.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("HH:mm"));
    if (!m_taskStore->rescheduleTask(taskId, date, time, &error)) {
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

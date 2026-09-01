#pragma once

#include <QHash>
#include <QLocalServer>
#include <QObject>

class QLocalSocket;

namespace waypoint {

class TaskStore;
class SyncEngine;

class WaypointIpcServer final : public QObject {
  Q_OBJECT

public:
  explicit WaypointIpcServer(TaskStore *taskStore, SyncEngine *syncEngine, QObject *parent = nullptr);

  [[nodiscard]] bool listen(QString *errorMessage = nullptr);

private slots:
  void acceptConnections();
  void readClientMessage();
  void removeClient();

private:
  [[nodiscard]] QJsonObject handleRequest(const QJsonObject &request);
  void respondAndClose(QLocalSocket *socket, const QJsonObject &response);

  TaskStore *m_taskStore;
  SyncEngine *m_syncEngine;
  QLocalServer m_server;
  QHash<QLocalSocket *, QByteArray> m_buffers;
};

} // namespace waypoint

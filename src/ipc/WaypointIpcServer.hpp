#pragma once

#include <QHash>
#include <QLocalServer>
#include <QObject>

class QLocalSocket;

namespace waypoint {

class TaskStore;
class HolidaySyncEngine;
class SyncEngine;

class WaypointIpcServer final : public QObject {
  Q_OBJECT

public:
  explicit WaypointIpcServer(TaskStore *taskStore, SyncEngine *syncEngine,
                             HolidaySyncEngine *holidaySyncEngine, QObject *parent = nullptr);

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
  HolidaySyncEngine *m_holidaySyncEngine;
  QLocalServer m_server;
  QHash<QLocalSocket *, QByteArray> m_buffers;
};

} // namespace waypoint

#pragma once

#include "core/SyncConfiguration.hpp"
#include "core/TaskRecord.hpp"

#include <QJsonArray>
#include <QList>
#include <QObject>
#include <QSqlDatabase>

namespace waypoint {

class TaskStore final : public QObject {
  Q_OBJECT

public:
  explicit TaskStore(QString databasePath, QObject *parent = nullptr);
  ~TaskStore() override;

  [[nodiscard]] bool open(QString *errorMessage = nullptr);
  [[nodiscard]] QList<TaskRecord> listActiveTasks(QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonArray pendingMutations(QString *errorMessage = nullptr) const;
  [[nodiscard]] QString syncCursor(QString *errorMessage = nullptr) const;
  [[nodiscard]] SyncConfiguration syncConfiguration(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool saveSyncConfiguration(const SyncConfiguration &configuration,
                                           QString *errorMessage = nullptr);

  [[nodiscard]] bool createTask(const QString &title, const QDate &scheduledDate,
                                TaskRecord *createdTask = nullptr, QString *errorMessage = nullptr);
  [[nodiscard]] bool setTaskCompleted(const QString &taskId, bool completed, QString *errorMessage = nullptr);
  [[nodiscard]] bool rescheduleTask(const QString &taskId, const QDate &scheduledDate,
                                    QString *errorMessage = nullptr);
  [[nodiscard]] bool deleteTask(const QString &taskId, QString *errorMessage = nullptr);
  [[nodiscard]] bool applyRemoteChanges(const QJsonArray &changes, const QString &nextCursor,
                                        const QStringList &acceptedMutationIds,
                                        QString *errorMessage = nullptr);

signals:
  void tasksChanged();

private:
  [[nodiscard]] bool migrate(QString *errorMessage);
  [[nodiscard]] bool mutateTask(const QString &taskId, const QString &operation, const QJsonObject &fields,
                                QString *errorMessage);
  [[nodiscard]] bool enqueueMutation(const QString &mutationId, const QString &taskId,
                                     const QString &operation, const QJsonObject &task,
                                     QString *errorMessage);
  [[nodiscard]] bool beginTransaction(QString *errorMessage);
  [[nodiscard]] bool commitTransaction(QString *errorMessage);
  void rollbackTransaction();

  QString m_databasePath;
  QString m_connectionName;
  QSqlDatabase m_database;
};

[[nodiscard]] QString defaultWaypointDatabasePath();

} // namespace waypoint

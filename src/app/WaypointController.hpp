#pragma once

#include "app/CalendarModel.hpp"
#include "app/TaskListModel.hpp"
#include "ipc/WaypointIpcClient.hpp"

#include <QDate>
#include <QObject>
#include <QTimer>

namespace waypoint {

class WaypointController final : public QObject {
  Q_OBJECT
  Q_PROPERTY(TaskListModel *todayTasks READ todayTasks CONSTANT)
  Q_PROPERTY(TaskListModel *selectedDateTasks READ selectedDateTasks CONSTANT)
  Q_PROPERTY(CalendarModel *calendar READ calendar CONSTANT)
  Q_PROPERTY(
      QString selectedDateKey READ selectedDateKey WRITE setSelectedDateKey NOTIFY selectedDateKeyChanged)
  Q_PROPERTY(bool online READ online NOTIFY connectionChanged)
  Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
  Q_PROPERTY(QString syncEndpoint READ syncEndpoint NOTIFY syncConfigurationChanged)
  Q_PROPERTY(bool syncConfigured READ syncConfigured NOTIFY syncConfigurationChanged)
  Q_PROPERTY(QString syncState READ syncState NOTIFY syncStatusChanged)
  Q_PROPERTY(QString syncLastError READ syncLastError NOTIFY syncStatusChanged)
  Q_PROPERTY(QString lastSuccessfulSync READ lastSuccessfulSync NOTIFY syncStatusChanged)

public:
  explicit WaypointController(QObject *parent = nullptr);

  [[nodiscard]] TaskListModel *todayTasks();
  [[nodiscard]] TaskListModel *selectedDateTasks();
  [[nodiscard]] CalendarModel *calendar();
  [[nodiscard]] QString selectedDateKey() const;
  void setSelectedDateKey(const QString &dateKey);
  [[nodiscard]] bool online() const;
  [[nodiscard]] QString errorMessage() const;
  [[nodiscard]] QString syncEndpoint() const;
  [[nodiscard]] bool syncConfigured() const;
  [[nodiscard]] QString syncState() const;
  [[nodiscard]] QString syncLastError() const;
  [[nodiscard]] QString lastSuccessfulSync() const;

  Q_INVOKABLE void start();
  Q_INVOKABLE void refresh();
  Q_INVOKABLE bool addTask(const QString &title, const QString &scheduledDateKey);
  Q_INVOKABLE bool setTaskCompleted(const QString &taskId, bool completed);
  Q_INVOKABLE bool rescheduleTask(const QString &taskId, const QString &scheduledDateKey);
  Q_INVOKABLE bool deleteTask(const QString &taskId);
  Q_INVOKABLE bool saveSyncConfiguration(const QString &endpoint, const QString &token);
  Q_INVOKABLE bool disableRemoteSync();
  Q_INVOKABLE bool syncNow();

signals:
  void selectedDateKeyChanged();
  void connectionChanged();
  void errorMessageChanged();
  void syncConfigurationChanged();
  void syncStatusChanged();

private:
  void updateConnection(bool online, const QString &errorMessage = {});
  void publishTasks(const QList<TaskRecord> &tasks);
  void startDaemonOnce();
  bool refreshSyncDetails(QString *errorMessage);

  WaypointIpcClient m_client;
  TaskListModel m_todayTasks;
  TaskListModel m_selectedDateTasks;
  CalendarModel m_calendar;
  QTimer m_refreshTimer;
  QDate m_selectedDate;
  QByteArray m_snapshotSignature;
  bool m_online = false;
  bool m_daemonStartAttempted = false;
  QString m_errorMessage;
  QString m_syncEndpoint;
  QString m_syncState = QStringLiteral("local-only");
  QString m_syncLastError;
  QString m_lastSuccessfulSync;
  bool m_syncConfigured = false;
};

} // namespace waypoint

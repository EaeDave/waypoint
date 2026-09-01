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
  [[nodiscard]] QList<TaskOccurrenceState> listOccurrenceStates(QString *errorMessage = nullptr) const;
  [[nodiscard]] QList<TaskOccurrence> listOccurrences(const QDate &from, const QDate &to,
                                                      QString *errorMessage = nullptr) const;
  [[nodiscard]] QList<TaskOccurrence> listActionableOccurrences(const QDate &today,
                                                                QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonArray pendingMutations(QString *errorMessage = nullptr) const;
  [[nodiscard]] QString syncCursor(QString *errorMessage = nullptr) const;
  [[nodiscard]] SyncConfiguration syncConfiguration(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool saveSyncConfiguration(const SyncConfiguration &configuration,
                                           QString *errorMessage = nullptr);
  [[nodiscard]] QJsonObject holidayPreferences(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool saveHolidayPreferences(const QJsonObject &preferences, QString *errorMessage = nullptr);
  [[nodiscard]] QJsonArray listHolidays(const QDate &from, const QDate &to,
                                        QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonArray holidayCoverage(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool replaceHolidaySnapshot(const QDate &from, const QDate &to, const QJsonArray &holidays,
                                            const QJsonArray &coverage, QString *errorMessage = nullptr);
  [[nodiscard]] QJsonArray listMunicipalities(const QString &stateCode,
                                              QString *errorMessage = nullptr) const;
  [[nodiscard]] bool replaceMunicipalities(const QString &stateCode, const QJsonArray &municipalities,
                                           QString *errorMessage = nullptr);

  [[nodiscard]] bool createTask(const QString &title, const QDate &scheduledDate, const QTime &scheduledTime,
                                const RecurrenceRule &recurrence, TaskRecord *createdTask = nullptr,
                                QString *errorMessage = nullptr);
  [[nodiscard]] bool setTaskCompleted(const QString &taskId, bool completed, QString *errorMessage = nullptr);
  [[nodiscard]] bool setOccurrenceCompleted(const QString &taskId, const QDate &occurrenceDate,
                                            bool completed, QString *errorMessage = nullptr);
  [[nodiscard]] bool skipOccurrence(const QString &taskId, const QDate &occurrenceDate,
                                    QString *errorMessage = nullptr);
  [[nodiscard]] bool rescheduleTask(const QString &taskId, const QDate &scheduledDate,
                                    const QTime &scheduledTime, QString *errorMessage = nullptr);
  [[nodiscard]] bool editTask(const QString &taskId, const QString &title, const QTime &scheduledTime,
                              const RecurrenceRule &recurrence, QString *errorMessage = nullptr);
  [[nodiscard]] bool deleteOccurrence(const QString &taskId, const QDate &occurrenceDate,
                                      RecurrenceEditScope scope, QString *errorMessage = nullptr);
  [[nodiscard]] bool deleteTask(const QString &taskId, QString *errorMessage = nullptr);
  [[nodiscard]] bool applyRemoteChanges(const QJsonArray &changes, const QString &nextCursor,
                                        const QStringList &acceptedMutationIds,
                                        QString *errorMessage = nullptr);

signals:
  void tasksChanged();
  void holidaysChanged();
  void holidayPreferencesChanged();

private:
  [[nodiscard]] bool migrate(QString *errorMessage);
  [[nodiscard]] bool mutateTask(const QString &taskId, const QString &operation, const QJsonObject &fields,
                                QString *errorMessage);
  [[nodiscard]] bool enqueueMutation(const QString &mutationId, const QString &entityType,
                                     const QString &entityId, const QString &operation,
                                     const QJsonObject &payload, QString *errorMessage);
  [[nodiscard]] bool setOccurrenceState(const QString &taskId, const QDate &occurrenceDate,
                                        OccurrenceStatus status, QString *errorMessage);
  [[nodiscard]] bool beginTransaction(QString *errorMessage);
  [[nodiscard]] bool commitTransaction(QString *errorMessage);
  void rollbackTransaction();

  QString m_databasePath;
  QString m_connectionName;
  QSqlDatabase m_database;
};

[[nodiscard]] QString defaultWaypointDatabasePath();

} // namespace waypoint

#pragma once

#include "core/HabitRecord.hpp"
#include "core/TaskRecord.hpp"

#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QObject>

#include <optional>

namespace waypoint {

class WaypointIpcClient final : public QObject {
  Q_OBJECT

public:
  explicit WaypointIpcClient(QObject *parent = nullptr);

  [[nodiscard]] bool ping(QString *errorMessage = nullptr) const;
  [[nodiscard]] QList<TaskRecord> listTasks(QString *errorMessage = nullptr) const;
  [[nodiscard]] QList<TaskOccurrence> listOccurrences(const QDate &from, const QDate &to,
                                                      QString *errorMessage = nullptr) const;
  [[nodiscard]] QList<TaskOccurrence> listActionableOccurrences(const QDate &today,
                                                                QString *errorMessage = nullptr) const;
  [[nodiscard]] QList<HabitProgress> listHabitProgress(const QDate &date,
                                                       QString *errorMessage = nullptr) const;
  [[nodiscard]] bool addHabit(const HabitRecord &habit, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool editHabit(const HabitRecord &habit, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool recordHabit(const QString &habitId, const QDate &date,
                                 const std::optional<qint64> &amount, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool undoLastHabitEntry(const QString &habitId, const QDate &date,
                                        QString *errorMessage = nullptr) const;
  [[nodiscard]] bool deleteHabit(const QString &habitId, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool addTask(const QString &title, const QDate &scheduledDate, const QTime &scheduledTime,
                             const RecurrenceRule &recurrence, const QList<int> &reminderMinutesBefore,
                             const QString &emoji, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool setTaskCompleted(const QString &taskId, bool completed,
                                      QString *errorMessage = nullptr) const;
  [[nodiscard]] bool setOccurrenceCompleted(const QString &taskId, const QDate &occurrenceDate,
                                            bool completed, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool skipOccurrence(const QString &taskId, const QDate &occurrenceDate,
                                    QString *errorMessage = nullptr) const;
  [[nodiscard]] bool deleteOccurrence(const QString &taskId, const QDate &occurrenceDate,
                                      const QString &scope, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool rescheduleTask(const QString &taskId, const QDate &scheduledDate,
                                    const QTime &scheduledTime, QString *errorMessage = nullptr) const;
  [[nodiscard]] bool editTask(const QString &taskId, const QString &title, const QTime &scheduledTime,
                              const RecurrenceRule &recurrence,
                              const std::optional<QList<int>> &reminderMinutesBefore, const QString &emoji,
                              QString *errorMessage = nullptr) const;
  [[nodiscard]] bool deleteTask(const QString &taskId, QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject syncConfiguration(QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject syncStatus(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool saveSyncConfiguration(const QString &endpoint, const QString &token, bool replaceToken,
                                           QString *errorMessage = nullptr) const;
  [[nodiscard]] bool syncNow(QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject holidayPreferences(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool saveHolidayPreferences(const QJsonObject &preferences,
                                            QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject holidays(const QDate &from, const QDate &to,
                                     QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonArray municipalities(const QString &stateCode, QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject holidayStatus(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool refreshHolidays(QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject updateStatus(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool checkForUpdate(QString *errorMessage = nullptr) const;
  [[nodiscard]] bool installUpdate(bool relaunchDesktop, QString *errorMessage = nullptr) const;

  [[nodiscard]] QJsonObject request(const QJsonObject &message, QString *errorMessage = nullptr,
                                    int timeoutMilliseconds = 750) const;
};

} // namespace waypoint

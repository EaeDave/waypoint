#pragma once

#include "app/CalendarModel.hpp"
#include "app/TaskListModel.hpp"
#include "ipc/WaypointIpcClient.hpp"

#include <QDate>
#include <QJsonArray>
#include <QObject>
#include <QTimer>
#include <QVariantList>

namespace waypoint {

class WaypointController final : public QObject {
  Q_OBJECT
  Q_PROPERTY(TaskListModel *todayTasks READ todayTasks CONSTANT)
  Q_PROPERTY(TaskListModel *selectedDateTasks READ selectedDateTasks CONSTANT)
  Q_PROPERTY(QVariantList todayHabits READ todayHabits NOTIFY habitsChanged)
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
  Q_PROPERTY(QString holidayStateCode READ holidayStateCode NOTIFY holidayConfigurationChanged)
  Q_PROPERTY(QString holidayCityCode READ holidayCityCode NOTIFY holidayConfigurationChanged)
  Q_PROPERTY(bool includeNationalHolidays READ includeNationalHolidays NOTIFY holidayConfigurationChanged)
  Q_PROPERTY(bool includeStateHolidays READ includeStateHolidays NOTIFY holidayConfigurationChanged)
  Q_PROPERTY(bool includeMunicipalHolidays READ includeMunicipalHolidays NOTIFY holidayConfigurationChanged)
  Q_PROPERTY(bool includeCommemorativeDates READ includeCommemorativeDates NOTIFY holidayConfigurationChanged)
  Q_PROPERTY(bool includeOptionalDates READ includeOptionalDates NOTIFY holidayConfigurationChanged)
  Q_PROPERTY(QVariantList municipalities READ municipalities NOTIFY municipalitiesChanged)
  Q_PROPERTY(QVariantList selectedDateHolidays READ selectedDateHolidays NOTIFY selectedDateHolidaysChanged)
  Q_PROPERTY(QString holidaySyncState READ holidaySyncState NOTIFY holidayStatusChanged)
  Q_PROPERTY(QString holidaySyncLastError READ holidaySyncLastError NOTIFY holidayStatusChanged)

public:
  explicit WaypointController(QObject *parent = nullptr);

  [[nodiscard]] TaskListModel *todayTasks();
  [[nodiscard]] TaskListModel *selectedDateTasks();
  [[nodiscard]] QVariantList todayHabits() const;
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
  [[nodiscard]] QString holidayStateCode() const;
  [[nodiscard]] QString holidayCityCode() const;
  [[nodiscard]] bool includeNationalHolidays() const;
  [[nodiscard]] bool includeStateHolidays() const;
  [[nodiscard]] bool includeMunicipalHolidays() const;
  [[nodiscard]] bool includeCommemorativeDates() const;
  [[nodiscard]] bool includeOptionalDates() const;
  [[nodiscard]] QVariantList municipalities() const;
  [[nodiscard]] QVariantList selectedDateHolidays() const;
  [[nodiscard]] QString holidaySyncState() const;
  [[nodiscard]] QString holidaySyncLastError() const;

  Q_INVOKABLE void start();
  Q_INVOKABLE void refresh();
  Q_INVOKABLE bool addTask(const QString &title, const QString &scheduledDateKey,
                           const QString &scheduledTimeKey, const QString &frequency, int interval,
                           const QVariantList &weekdays, const QString &endMode, const QString &untilDateKey,
                           int occurrenceCount, const QVariantList &reminderMinutesBefore,
                           const QString &emoji);
  Q_INVOKABLE bool setOccurrenceCompleted(const QString &taskId, const QString &occurrenceDateKey,
                                          bool completed);
  Q_INVOKABLE bool skipOccurrence(const QString &taskId, const QString &occurrenceDateKey);
  Q_INVOKABLE bool deleteOccurrence(const QString &taskId, const QString &occurrenceDateKey,
                                    const QString &scope);
  Q_INVOKABLE bool rescheduleTask(const QString &taskId, const QString &scheduledDateKey,
                                  const QString &scheduledTimeKey);
  Q_INVOKABLE bool editTask(const QString &taskId, const QString &title, const QString &scheduledTimeKey,
                            const QString &frequency, int interval, const QVariantList &weekdays,
                            const QString &endMode, const QString &untilDateKey, int occurrenceCount,
                            const QVariantList &reminderMinutesBefore, const QString &emoji);
  Q_INVOKABLE bool deleteTask(const QString &taskId);
  Q_INVOKABLE bool saveHabit(const QString &habitId, const QString &title, qint64 targetAmount,
                             const QString &unit, const QString &checkInMode, qint64 incrementAmount,
                             const QVariantList &weekdays, const QVariantList &reminderTimes,
                             const QString &emoji);
  Q_INVOKABLE bool recordHabit(const QString &habitId, qint64 amount = 0);
  Q_INVOKABLE bool undoHabit(const QString &habitId);
  Q_INVOKABLE bool deleteHabit(const QString &habitId);
  Q_INVOKABLE bool saveSyncConfiguration(const QString &endpoint, const QString &token);
  Q_INVOKABLE bool disableRemoteSync();
  Q_INVOKABLE bool syncNow();
  Q_INVOKABLE bool saveHolidayPreferences(const QString &stateCode, const QString &cityCode,
                                          bool includeNational, bool includeState, bool includeMunicipal,
                                          bool includeCommemorative, bool includeOptional);
  Q_INVOKABLE void loadMunicipalities(const QString &stateCode);
  Q_INVOKABLE bool refreshHolidays();

signals:
  void selectedDateKeyChanged();
  void habitsChanged();
  void connectionChanged();
  void errorMessageChanged();
  void syncConfigurationChanged();
  void syncStatusChanged();
  void holidayConfigurationChanged();
  void municipalitiesChanged();
  void selectedDateHolidaysChanged();
  void holidayStatusChanged();

private:
  void updateConnection(bool online, const QString &errorMessage = {});
  void publishOccurrences(const QList<TaskOccurrence> &todayOccurrences,
                          const QList<TaskOccurrence> &rangeOccurrences);
  void startDaemonOnce();
  bool refreshSyncDetails(QString *errorMessage);
  bool refreshHolidayDetails(QString *errorMessage);
  void updateSelectedDateHolidays();

  WaypointIpcClient m_client;
  TaskListModel m_todayTasks;
  TaskListModel m_selectedDateTasks;
  CalendarModel m_calendar;
  QVariantList m_todayHabits;
  QTimer m_refreshTimer;
  QDate m_selectedDate;
  QByteArray m_snapshotSignature;
  QByteArray m_holidaySignature;
  QByteArray m_municipalitySignature;
  QJsonArray m_holidays;
  QVariantList m_municipalities;
  bool m_online = false;
  bool m_daemonStartAttempted = false;
  QString m_errorMessage;
  QString m_syncEndpoint;
  QString m_syncState = QStringLiteral("local-only");
  QString m_syncLastError;
  QString m_lastSuccessfulSync;
  QString m_holidayStateCode;
  QString m_holidayCityCode;
  QString m_holidaySyncState = QStringLiteral("local-only");
  QString m_holidaySyncLastError;
  bool m_includeNationalHolidays = true;
  bool m_includeStateHolidays = true;
  bool m_includeMunicipalHolidays = true;
  bool m_includeCommemorativeDates = false;
  bool m_includeOptionalDates = true;
  bool m_syncConfigured = false;
};

} // namespace waypoint

#pragma once

#include "core/TaskStore.hpp"
#include "sync/HolidaySyncEngine.hpp"
#include "sync/SyncEngine.hpp"

#include <QByteArray>
#include <QDate>
#include <QObject>
#include <QTimer>
#include <QVariantList>

namespace waypoint {

class MobileController final : public QObject {
  Q_OBJECT
  Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
  Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
  Q_PROPERTY(QString todayKey READ todayKey CONSTANT)
  Q_PROPERTY(QString selectedDateKey READ selectedDateKey WRITE setSelectedDateKey NOTIFY selectedDateChanged)
  Q_PROPERTY(int visibleYear READ visibleYear NOTIFY visibleMonthChanged)
  Q_PROPERTY(int visibleMonth READ visibleMonth NOTIFY visibleMonthChanged)
  Q_PROPERTY(QVariantList todayTasks READ todayTasks NOTIFY dataChanged)
  Q_PROPERTY(QVariantList selectedTasks READ selectedTasks NOTIFY dataChanged)
  Q_PROPERTY(QVariantList todayHabits READ todayHabits NOTIFY dataChanged)
  Q_PROPERTY(QVariantList monthOccurrences READ monthOccurrences NOTIFY dataChanged)
  Q_PROPERTY(QVariantList allHabits READ allHabits NOTIFY dataChanged)
  Q_PROPERTY(QVariantList monthHolidays READ monthHolidays NOTIFY dataChanged)
  Q_PROPERTY(QVariantMap holidayPreferences READ holidayPreferences NOTIFY holidayPreferencesChanged)
  Q_PROPERTY(QVariantList municipalities READ municipalities NOTIFY municipalitiesChanged)
  Q_PROPERTY(QVariantList selectedDateHolidays READ selectedDateHolidays NOTIFY dataChanged)
  Q_PROPERTY(QString syncEndpoint READ syncEndpoint NOTIFY syncConfigurationChanged)
  Q_PROPERTY(bool syncConfigured READ syncConfigured NOTIFY syncConfigurationChanged)
  Q_PROPERTY(QString syncState READ syncState NOTIFY syncStatusChanged)
  Q_PROPERTY(QString syncLastError READ syncLastError NOTIFY syncStatusChanged)
  Q_PROPERTY(QString lastSuccessfulSync READ lastSuccessfulSync NOTIFY syncStatusChanged)

public:
  explicit MobileController(QObject *parent = nullptr);
  MobileController(QString databasePath, QObject *parent);

  [[nodiscard]] bool ready() const;
  [[nodiscard]] QString errorMessage() const;
  [[nodiscard]] QString todayKey() const;
  [[nodiscard]] QString selectedDateKey() const;
  void setSelectedDateKey(const QString &dateKey);
  [[nodiscard]] int visibleYear() const;
  [[nodiscard]] int visibleMonth() const;
  [[nodiscard]] QVariantList todayTasks() const;
  [[nodiscard]] QVariantList selectedTasks() const;
  [[nodiscard]] QVariantList todayHabits() const;
  [[nodiscard]] QVariantList monthOccurrences() const;
  [[nodiscard]] QVariantList monthHolidays() const;
  [[nodiscard]] QVariantList allHabits() const;
  [[nodiscard]] QVariantList selectedDateHolidays() const;
  [[nodiscard]] QVariantMap holidayPreferences() const;
  [[nodiscard]] QVariantList municipalities() const;
  [[nodiscard]] QString syncEndpoint() const;
  [[nodiscard]] bool syncConfigured() const;
  [[nodiscard]] QString syncState() const;
  [[nodiscard]] QString syncLastError() const;
  [[nodiscard]] QString lastSuccessfulSync() const;

  Q_INVOKABLE void start();
  Q_INVOKABLE void refresh();
  Q_INVOKABLE void moveMonth(int delta);
  Q_INVOKABLE void selectToday();

  Q_INVOKABLE bool saveTask(const QString &taskId, const QString &title, const QString &scheduledDateKey,
                            const QString &scheduledTimeKey, const QString &frequency, int interval,
                            const QVariantList &weekdays, const QString &endMode, const QString &untilDateKey,
                            int occurrenceCount, const QVariantList &reminderMinutesBefore,
                            const QString &emoji);
  Q_INVOKABLE bool setTaskCompleted(const QString &taskId, const QString &occurrenceDateKey, bool recurring,
                                    bool completed);
  Q_INVOKABLE bool deleteTask(const QString &taskId);

  Q_INVOKABLE bool saveHabit(const QString &habitId, const QString &title, qint64 targetAmount,
                             const QString &unit, const QString &checkInMode, qint64 incrementAmount,
                             const QVariantList &weekdays, const QVariantList &reminderTimes,
                             const QString &emoji);
  Q_INVOKABLE bool recordHabit(const QString &habitId, qint64 amount = 0);
  Q_INVOKABLE bool undoHabit(const QString &habitId);
  Q_INVOKABLE bool deleteHabit(const QString &habitId);

  Q_INVOKABLE bool saveSyncConfiguration(const QString &endpoint, const QString &token);
  Q_INVOKABLE bool syncNow();
  Q_INVOKABLE bool saveHolidayPreferences(const QString &stateCode, const QString &cityCode,
                                          bool includeNational, bool includeState, bool includeMunicipal,
                                          bool includeCommemorative, bool includeOptional);
  Q_INVOKABLE void refreshHolidays();
  Q_INVOKABLE void loadMunicipalities(const QString &stateCode);

signals:
  void readyChanged();
  void errorMessageChanged();
  void selectedDateChanged();
  void visibleMonthChanged();
  void dataChanged();
  void holidayPreferencesChanged();
  void municipalitiesChanged();
  void syncConfigurationChanged();
  void syncStatusChanged();

private:
  void scheduleRefresh();
  void publishError(const QString &message);
  bool finishMutation(bool succeeded, const QString &errorMessage);
  void refreshSyncProperties();
  void refreshNotificationSchedule();
  void refreshWidgetSnapshot(const QDate &today);

  TaskStore m_store;
  SyncEngine m_syncEngine;
  HolidaySyncEngine m_holidaySyncEngine;
  QTimer m_refreshTimer;
  QDate m_selectedDate;
  int m_visibleYear = 0;
  int m_visibleMonth = 0;
  QVariantList m_todayTasks;
  QVariantList m_selectedTasks;
  QVariantList m_todayHabits;
  QVariantList m_monthOccurrences;
  QVariantList m_allHabits;
  QVariantList m_monthHolidays;
  bool m_ready = false;
  QVariantMap m_holidayPreferences;
  QVariantList m_municipalities;
  QString m_errorMessage;
  QString m_syncEndpoint;
  bool m_syncConfigured = false;
  QString m_syncState = QStringLiteral("local-only");
  QString m_syncLastError;
  QString m_lastSuccessfulSync;
  QDate m_widgetSnapshotDate;
  QByteArray m_widgetSnapshot;
  bool m_widgetSnapshotDirty = true;
};

} // namespace waypoint

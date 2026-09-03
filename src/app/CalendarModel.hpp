#pragma once

#include "core/Recurrence.hpp"

#include <QAbstractListModel>
#include <QDate>
#include <QJsonArray>
#include <QList>

namespace waypoint {

class CalendarModel final : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(int visibleYear READ visibleYear NOTIFY visibleMonthChanged)
  Q_PROPERTY(int visibleMonth READ visibleMonth NOTIFY visibleMonthChanged)
  Q_PROPERTY(QString monthLabel READ monthLabel NOTIFY visibleMonthChanged)

public:
  enum Role {
    DateRole = Qt::UserRole + 1,
    DayNumberRole,
    InVisibleMonthRole,
    TodayRole,
    WeekendRole,
    PendingCountRole,
    CompletedCountRole,
    OverdueCountRole,
    SkippedCountRole,
    WeekNumberRole,
    HolidayCountRole,
    HolidayKindRole,
    HolidayNamesRole,
  };
  Q_ENUM(Role)

  explicit CalendarModel(QObject *parent = nullptr);

  [[nodiscard]] int rowCount(const QModelIndex &parent = {}) const override;
  [[nodiscard]] QVariant data(const QModelIndex &index, int role) const override;
  [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

  [[nodiscard]] int visibleYear() const;
  [[nodiscard]] int visibleMonth() const;
  [[nodiscard]] QString monthLabel() const;
  void setSourceOccurrences(const QList<TaskOccurrence> &occurrences);
  void setSourceHolidays(const QJsonArray &holidays);

  Q_INVOKABLE void showPreviousMonth();
  Q_INVOKABLE void showNextMonth();
  Q_INVOKABLE void showCurrentMonth();
  Q_INVOKABLE [[nodiscard]] int weekNumberAtRow(int row) const;

signals:
  void visibleMonthChanged();

private:
  struct CalendarCell final {
    QDate date;
    bool inVisibleMonth = false;
    int pendingCount = 0;
    int completedCount = 0;
    int overdueCount = 0;
    int skippedCount = 0;
    int holidayCount = 0;
    QString holidayKind;
    QStringList holidayNames;
  };

  void setVisibleMonth(const QDate &month);
  void rebuildCells();

  QDate m_visibleMonth;
  QList<TaskOccurrence> m_sourceOccurrences;
  QJsonArray m_sourceHolidays;
  QList<CalendarCell> m_cells;
};

} // namespace waypoint

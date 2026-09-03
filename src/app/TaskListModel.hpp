#pragma once

#include "core/Recurrence.hpp"

#include <QAbstractListModel>
#include <QDate>
#include <QList>

namespace waypoint {

class TaskListModel final : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(QDate focusDate READ focusDate WRITE setFocusDate NOTIFY focusDateChanged)
  Q_PROPERTY(int pendingCount READ pendingCount NOTIFY summaryChanged)
  Q_PROPERTY(int overdueCount READ overdueCount NOTIFY summaryChanged)
  Q_PROPERTY(int skippedCount READ skippedCount NOTIFY summaryChanged)

public:
  enum Role {
    TaskIdRole = Qt::UserRole + 1,
    TitleRole,
    ScheduledDateRole,
    ScheduledTimeRole,
    ReminderMinutesBeforeRole,
    EmojiRole,
    CompletedRole,
    SkippedRole,
    OverdueRole,
    RecurringRole,
    RecurrenceLabelRole,
    RecurrenceRole,
  };
  Q_ENUM(Role)

  explicit TaskListModel(QObject *parent = nullptr);

  [[nodiscard]] int rowCount(const QModelIndex &parent = {}) const override;
  [[nodiscard]] QVariant data(const QModelIndex &index, int role) const override;
  [[nodiscard]] QHash<int, QByteArray> roleNames() const override;

  [[nodiscard]] QDate focusDate() const;
  void setFocusDate(const QDate &date);
  [[nodiscard]] int pendingCount() const;
  [[nodiscard]] int overdueCount() const;
  [[nodiscard]] int skippedCount() const;
  void setSourceOccurrences(const QList<TaskOccurrence> &occurrences);

signals:
  void focusDateChanged();
  void summaryChanged();

private:
  void rebuildVisibleTasks();

  QDate m_focusDate;
  QList<TaskOccurrence> m_sourceOccurrences;
  QList<TaskOccurrence> m_visibleOccurrences;
};

} // namespace waypoint

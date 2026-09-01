#pragma once

#include "core/TaskRecord.hpp"

#include <QAbstractListModel>
#include <QDate>
#include <QList>

namespace waypoint {

class TaskListModel final : public QAbstractListModel {
  Q_OBJECT
  Q_PROPERTY(QDate focusDate READ focusDate WRITE setFocusDate NOTIFY focusDateChanged)
  Q_PROPERTY(int pendingCount READ pendingCount NOTIFY summaryChanged)
  Q_PROPERTY(int overdueCount READ overdueCount NOTIFY summaryChanged)

public:
  enum Role {
    TaskIdRole = Qt::UserRole + 1,
    TitleRole,
    ScheduledDateRole,
    CompletedRole,
    OverdueRole,
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
  void setSourceTasks(const QList<TaskRecord> &tasks);

signals:
  void focusDateChanged();
  void summaryChanged();

private:
  void rebuildVisibleTasks();

  QDate m_focusDate;
  QList<TaskRecord> m_sourceTasks;
  QList<TaskRecord> m_visibleTasks;
};

} // namespace waypoint

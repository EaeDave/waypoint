#include "app/TaskListModel.hpp"

#include <algorithm>

namespace waypoint {

TaskListModel::TaskListModel(QObject *parent)
    : QAbstractListModel(parent), m_focusDate(QDate::currentDate()) {}

int TaskListModel::rowCount(const QModelIndex &parent) const {
  return parent.isValid() ? 0 : m_visibleTasks.size();
}

QVariant TaskListModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_visibleTasks.size()) {
    return {};
  }
  const TaskRecord &task = m_visibleTasks.at(index.row());
  switch (role) {
  case TaskIdRole:
    return task.id;
  case TitleRole:
    return task.title;
  case ScheduledDateRole:
    return task.scheduledDate.toString(Qt::ISODate);
  case CompletedRole:
    return task.completed;
  case OverdueRole:
    return !task.completed && task.scheduledDate.isValid() && task.scheduledDate < QDate::currentDate();
  default:
    return {};
  }
}

QHash<int, QByteArray> TaskListModel::roleNames() const {
  return {
      {TaskIdRole, "taskId"},       {TitleRole, "title"},     {ScheduledDateRole, "scheduledDateKey"},
      {CompletedRole, "completed"}, {OverdueRole, "overdue"},
  };
}

QDate TaskListModel::focusDate() const { return m_focusDate; }

void TaskListModel::setFocusDate(const QDate &date) {
  if (!date.isValid() || m_focusDate == date) {
    return;
  }
  m_focusDate = date;
  rebuildVisibleTasks();
  emit focusDateChanged();
}

int TaskListModel::pendingCount() const {
  return static_cast<int>(std::count_if(m_visibleTasks.cbegin(), m_visibleTasks.cend(),
                                        [](const TaskRecord &task) { return !task.completed; }));
}

int TaskListModel::overdueCount() const {
  const QDate today = QDate::currentDate();
  return static_cast<int>(
      std::count_if(m_visibleTasks.cbegin(), m_visibleTasks.cend(), [today](const TaskRecord &task) {
        return !task.completed && task.scheduledDate < today;
      }));
}

void TaskListModel::setSourceTasks(const QList<TaskRecord> &tasks) {
  m_sourceTasks = tasks;
  rebuildVisibleTasks();
}

void TaskListModel::rebuildVisibleTasks() {
  QList<TaskRecord> visible;
  const QDate today = QDate::currentDate();
  for (const TaskRecord &task : m_sourceTasks) {
    const bool belongsToFocusDate = task.scheduledDate == m_focusDate;
    const bool overdueOnTodayView =
        m_focusDate == today && !task.completed && task.scheduledDate.isValid() && task.scheduledDate < today;
    if (belongsToFocusDate || overdueOnTodayView) {
      visible.append(task);
    }
  }

  std::ranges::sort(visible, [today](const TaskRecord &left, const TaskRecord &right) {
    const bool leftOverdue = !left.completed && left.scheduledDate < today;
    const bool rightOverdue = !right.completed && right.scheduledDate < today;
    if (leftOverdue != rightOverdue) {
      return leftOverdue;
    }
    if (left.completed != right.completed) {
      return !left.completed;
    }
    return left.createdAt < right.createdAt;
  });

  beginResetModel();
  m_visibleTasks = std::move(visible);
  endResetModel();
  emit summaryChanged();
}

} // namespace waypoint

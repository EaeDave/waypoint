#include "app/TaskListModel.hpp"

#include <algorithm>

namespace waypoint {

TaskListModel::TaskListModel(QObject *parent)
    : QAbstractListModel(parent), m_focusDate(QDate::currentDate()) {}

int TaskListModel::rowCount(const QModelIndex &parent) const {
  return parent.isValid() ? 0 : m_visibleOccurrences.size();
}

QVariant TaskListModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_visibleOccurrences.size()) {
    return {};
  }
  const TaskOccurrence &occurrence = m_visibleOccurrences.at(index.row());
  switch (role) {
  case TaskIdRole:
    return occurrence.taskId;
  case TitleRole:
    return occurrence.title;
  case ScheduledDateRole:
    return occurrence.occurrenceDate.toString(Qt::ISODate);
  case ScheduledTimeRole:
    return occurrence.scheduledTime.isValid() ? occurrence.scheduledTime.toString(QStringLiteral("HH:mm"))
                                              : QString();
  case EmojiRole:
    return occurrence.emoji;
  case CompletedRole:
    return occurrence.completed;
  case OverdueRole:
    return !occurrence.completed && occurrence.occurrenceDate.isValid() &&
           occurrence.occurrenceDate < QDate::currentDate();
  case RecurringRole:
    return occurrence.recurring;
  case RecurrenceLabelRole:
    return occurrence.recurrenceLabel;
  case RecurrenceRole:
    return occurrence.recurrence.toJson().toVariantMap();
  default:
    return {};
  }
}

QHash<int, QByteArray> TaskListModel::roleNames() const {
  return {
      {TaskIdRole, "taskId"},
      {TitleRole, "title"},
      {ScheduledDateRole, "scheduledDateKey"},
      {ScheduledTimeRole, "scheduledTimeKey"},
      {EmojiRole, "emoji"},
      {CompletedRole, "completed"},
      {OverdueRole, "overdue"},
      {RecurringRole, "recurring"},
      {RecurrenceLabelRole, "recurrenceLabel"},
      {RecurrenceRole, "recurrence"},
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
  return static_cast<int>(
      std::count_if(m_visibleOccurrences.cbegin(), m_visibleOccurrences.cend(),
                    [](const TaskOccurrence &occurrence) { return !occurrence.completed; }));
}

int TaskListModel::overdueCount() const {
  const QDate today = QDate::currentDate();
  return static_cast<int>(std::count_if(m_visibleOccurrences.cbegin(), m_visibleOccurrences.cend(),
                                        [today](const TaskOccurrence &occurrence) {
                                          return !occurrence.completed && occurrence.occurrenceDate < today;
                                        }));
}

void TaskListModel::setSourceOccurrences(const QList<TaskOccurrence> &occurrences) {
  m_sourceOccurrences = occurrences;
  rebuildVisibleTasks();
}

void TaskListModel::rebuildVisibleTasks() {
  QList<TaskOccurrence> visible;
  const QDate today = QDate::currentDate();
  for (const TaskOccurrence &occurrence : m_sourceOccurrences) {
    const bool calendarVisible = m_focusDate == today || !occurrence.recurring || occurrence.calendarMarker;
    const bool belongsToFocusDate = occurrence.occurrenceDate == m_focusDate;
    const bool overdueOnTodayView = m_focusDate == today && !occurrence.completed &&
                                    occurrence.occurrenceDate.isValid() && occurrence.occurrenceDate < today;
    if (calendarVisible && (belongsToFocusDate || overdueOnTodayView)) {
      visible.append(occurrence);
    }
  }

  std::ranges::sort(visible, [today](const TaskOccurrence &left, const TaskOccurrence &right) {
    const bool leftOverdue = !left.completed && left.occurrenceDate < today;
    const bool rightOverdue = !right.completed && right.occurrenceDate < today;
    if (leftOverdue != rightOverdue) {
      return leftOverdue;
    }
    if (left.completed != right.completed) {
      return !left.completed;
    }
    if (left.occurrenceDate != right.occurrenceDate) {
      return left.occurrenceDate < right.occurrenceDate;
    }
    if (left.scheduledTime != right.scheduledTime) {
      return left.scheduledTime < right.scheduledTime;
    }
    return left.taskId < right.taskId;
  });

  beginResetModel();
  m_visibleOccurrences = std::move(visible);
  endResetModel();
  emit summaryChanged();
}

} // namespace waypoint

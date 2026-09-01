#include "app/CalendarModel.hpp"

#include <QLocale>

namespace waypoint {
namespace {

int holidayKindPriority(const QString &kind) {
  if (kind == QStringLiteral("legal")) {
    return 3;
  }
  if (kind == QStringLiteral("optional")) {
    return 2;
  }
  if (kind == QStringLiteral("commemorative")) {
    return 1;
  }
  return 0;
}

} // namespace


CalendarModel::CalendarModel(QObject *parent) : QAbstractListModel(parent) {
  const QDate today = QDate::currentDate();
  m_visibleMonth = QDate(today.year(), today.month(), 1);
  rebuildCells();
}

int CalendarModel::rowCount(const QModelIndex &parent) const { return parent.isValid() ? 0 : m_cells.size(); }

QVariant CalendarModel::data(const QModelIndex &index, int role) const {
  if (!index.isValid() || index.row() < 0 || index.row() >= m_cells.size()) {
    return {};
  }
  const CalendarCell &cell = m_cells.at(index.row());
  switch (role) {
  case DateRole:
    return cell.date.toString(Qt::ISODate);
  case DayNumberRole:
    return cell.date.day();
  case InVisibleMonthRole:
    return cell.inVisibleMonth;
  case TodayRole:
    return cell.date == QDate::currentDate();
  case WeekendRole:
    return cell.date.dayOfWeek() == Qt::Saturday || cell.date.dayOfWeek() == Qt::Sunday;
  case PendingCountRole:
    return cell.pendingCount;
  case CompletedCountRole:
    return cell.completedCount;
  case OverdueCountRole:
    return cell.overdueCount;
  case WeekNumberRole:
    return cell.date.weekNumber();
  case HolidayCountRole:
    return cell.holidayCount;
  case HolidayKindRole:
    return cell.holidayKind;
  case HolidayNamesRole:
    return cell.holidayNames;
  default:
    return {};
  }
}

QHash<int, QByteArray> CalendarModel::roleNames() const {
  return {
      {DateRole, "calendarDateKey"},
      {DayNumberRole, "dayNumber"},
      {InVisibleMonthRole, "inVisibleMonth"},
      {TodayRole, "today"},
      {WeekendRole, "weekend"},
      {PendingCountRole, "pendingCount"},
      {CompletedCountRole, "completedCount"},
      {OverdueCountRole, "overdueCount"},
      {HolidayCountRole, "holidayCount"},
      {HolidayKindRole, "holidayKind"},
      {HolidayNamesRole, "holidayNames"},
      {WeekNumberRole, "weekNumber"},
  };
}

int CalendarModel::visibleYear() const { return m_visibleMonth.year(); }

int CalendarModel::visibleMonth() const { return m_visibleMonth.month(); }

QString CalendarModel::monthLabel() const {
  const QLocale locale;
  return QStringLiteral("%1 %2")
      .arg(locale.standaloneMonthName(m_visibleMonth.month(), QLocale::LongFormat))
      .arg(m_visibleMonth.year());
}

int CalendarModel::weekNumberAtRow(int row) const {
  const int index = row * 7;
  if (row < 0 || index >= m_cells.size()) {
    return 0;
  }
  return m_cells.at(index).date.weekNumber();
}

void CalendarModel::setSourceOccurrences(
    const QList<TaskOccurrence> &occurrences) {
  m_sourceOccurrences = occurrences;
  rebuildCells();
}
void CalendarModel::setSourceHolidays(const QJsonArray &holidays) {
  m_sourceHolidays = holidays;
  rebuildCells();
}

void CalendarModel::showPreviousMonth() { setVisibleMonth(m_visibleMonth.addMonths(-1)); }

void CalendarModel::showNextMonth() { setVisibleMonth(m_visibleMonth.addMonths(1)); }

void CalendarModel::showCurrentMonth() {
  const QDate today = QDate::currentDate();
  setVisibleMonth(QDate(today.year(), today.month(), 1));
}

void CalendarModel::setVisibleMonth(const QDate &month) {
  const QDate normalized(month.year(), month.month(), 1);
  if (!normalized.isValid() || normalized == m_visibleMonth) {
    return;
  }
  m_visibleMonth = normalized;
  rebuildCells();
  emit visibleMonthChanged();
}

void CalendarModel::rebuildCells() {
  const int firstDayOfWeek = static_cast<int>(QLocale().firstDayOfWeek());
  const int offset = (m_visibleMonth.dayOfWeek() - firstDayOfWeek + 7) % 7;
  const QDate gridStart = m_visibleMonth.addDays(-offset);
  const QDate today = QDate::currentDate();

  QList<CalendarCell> cells;
  cells.reserve(42);
  for (int index = 0; index < 42; ++index) {
    CalendarCell cell;
    cell.date = gridStart.addDays(index);
    cell.inVisibleMonth =
        cell.date.month() == m_visibleMonth.month() && cell.date.year() == m_visibleMonth.year();
    for (const TaskOccurrence &occurrence : m_sourceOccurrences) {
      if (occurrence.occurrenceDate != cell.date) {
        continue;
      }
      if (occurrence.recurring && cell.date != today) {
        continue;
      }
      if (occurrence.completed) {
        ++cell.completedCount;
      } else {
        ++cell.pendingCount;
        if (occurrence.occurrenceDate < today) {
          ++cell.overdueCount;
        }
      }
    }
    for (const QJsonValue &value : m_sourceHolidays) {
      const QJsonObject holiday = value.toObject();
      if (holiday.value(QStringLiteral("date")).toString() != cell.date.toString(Qt::ISODate)) {
        continue;
      }
      ++cell.holidayCount;
      const QString kind = holiday.value(QStringLiteral("kind")).toString();
      if (holidayKindPriority(kind) > holidayKindPriority(cell.holidayKind)) {
        cell.holidayKind = kind;
      }
      cell.holidayNames.append(holiday.value(QStringLiteral("name")).toString());
    }
    cells.append(cell);
  }

  beginResetModel();
  m_cells = std::move(cells);
  endResetModel();
}

} // namespace waypoint

#include "core/Recurrence.hpp"

#include "core/TaskRecord.hpp"

#include <QHash>
#include <QJsonArray>
#include <QStringList>

#include <algorithm>

namespace waypoint {
namespace {

QString frequencyName(const RecurrenceFrequency frequency) {
  switch (frequency) {
  case RecurrenceFrequency::Daily:
    return QStringLiteral("daily");
  case RecurrenceFrequency::Weekly:
    return QStringLiteral("weekly");
  case RecurrenceFrequency::Monthly:
    return QStringLiteral("monthly");
  case RecurrenceFrequency::Yearly:
    return QStringLiteral("yearly");
  case RecurrenceFrequency::None:
    return QStringLiteral("none");
  }
  return QStringLiteral("none");
}

RecurrenceFrequency parseFrequency(const QString &name) {
  if (name == QStringLiteral("daily")) {
    return RecurrenceFrequency::Daily;
  }
  if (name == QStringLiteral("weekly")) {
    return RecurrenceFrequency::Weekly;
  }
  if (name == QStringLiteral("monthly")) {
    return RecurrenceFrequency::Monthly;
  }
  if (name == QStringLiteral("yearly")) {
    return RecurrenceFrequency::Yearly;
  }
  return RecurrenceFrequency::None;
}

QString endModeName(const RecurrenceEndMode endMode) {
  switch (endMode) {
  case RecurrenceEndMode::OnDate:
    return QStringLiteral("onDate");
  case RecurrenceEndMode::AfterCount:
    return QStringLiteral("afterCount");
  case RecurrenceEndMode::Never:
    return QStringLiteral("never");
  }
  return QStringLiteral("never");
}

RecurrenceEndMode parseEndMode(const QString &name) {
  if (name == QStringLiteral("onDate")) {
    return RecurrenceEndMode::OnDate;
  }
  if (name == QStringLiteral("afterCount")) {
    return RecurrenceEndMode::AfterCount;
  }
  return RecurrenceEndMode::Never;
}

QString statusName(const OccurrenceStatus status) {
  switch (status) {
  case OccurrenceStatus::Pending:
    return QStringLiteral("pending");
  case OccurrenceStatus::Skipped:
    return QStringLiteral("skipped");
  case OccurrenceStatus::Completed:
    return QStringLiteral("completed");
  }
  return QStringLiteral("pending");
}

OccurrenceStatus parseStatus(const QString &name) {
  if (name == QStringLiteral("skipped")) {
    return OccurrenceStatus::Skipped;
  }
  if (name == QStringLiteral("pending")) {
    return OccurrenceStatus::Pending;
  }
  return OccurrenceStatus::Completed;
}

QString weekdayLabel(const int weekday) {
  static const QStringList labels = {
      QStringLiteral("SEG"), QStringLiteral("TER"), QStringLiteral("QUA"), QStringLiteral("QUI"),
      QStringLiteral("SEX"), QStringLiteral("SÁB"), QStringLiteral("DOM"),
  };
  return weekday >= 1 && weekday <= labels.size() ? labels.at(weekday - 1) : QString();
}

bool appendDate(QList<QDate> &dates, const QDate &date, const QDate &from, const QDate &to,
                const RecurrenceRule &rule, int &generatedCount) {
  if (rule.endMode == RecurrenceEndMode::OnDate && date > rule.untilDate) {
    return false;
  }
  if (rule.endMode == RecurrenceEndMode::AfterCount && generatedCount >= rule.occurrenceCount) {
    return false;
  }

  ++generatedCount;
  if (date >= from && date <= to) {
    dates.append(date);
  }
  return true;
}

QDate clampedMonthDate(const QDate &anchorDate, const int monthsFromAnchor) {
  const QDate targetMonth = QDate(anchorDate.year(), anchorDate.month(), 1).addMonths(monthsFromAnchor);
  return QDate(targetMonth.year(), targetMonth.month(),
               std::min(anchorDate.day(), targetMonth.daysInMonth()));
}

QDate clampedYearDate(const QDate &anchorDate, const int yearsFromAnchor) {
  const int year = anchorDate.year() + yearsFromAnchor;
  const QDate targetMonth(year, anchorDate.month(), 1);
  return QDate(year, anchorDate.month(), std::min(anchorDate.day(), targetMonth.daysInMonth()));
}
QDate nextRecurrenceSearchEnd(const TaskRecord &task, const QDate &today) {
  const QDate base = task.scheduledDate > today ? task.scheduledDate : today;
  const int interval = std::max(1, task.recurrence.interval);
  switch (task.recurrence.frequency) {
  case RecurrenceFrequency::Daily:
    return base.addDays(interval);
  case RecurrenceFrequency::Weekly:
    return base.addDays(interval * 7 + 6);
  case RecurrenceFrequency::Monthly:
    return base.addMonths(interval + 1);
  case RecurrenceFrequency::Yearly:
    return base.addYears(interval + 1);
  case RecurrenceFrequency::None:
    return base;
  }
  return base;
}

QDate firstUnresolvedDueDate(const TaskRecord &task,
                             const QHash<QString, TaskOccurrenceState> &stateByOccurrence,
                             const QDate &today) {
  const QList<QDate> dueDates =
      recurrenceDates(task.scheduledDate, task.recurrence, task.scheduledDate, today);
  for (const QDate &date : dueDates) {
    const auto state = stateByOccurrence.constFind(occurrenceKey(task.id, date));
    if (state == stateByOccurrence.cend() || state->status == OccurrenceStatus::Pending) {
      return date;
    }
  }
  return {};
}

int occurrenceStatusRank(const TaskOccurrence &occurrence) {
  if (occurrence.completed) {
    return 2;
  }
  return occurrence.skipped ? 1 : 0;
}

TaskOccurrence occurrenceFor(const TaskRecord &task, const QDate &date, const TaskOccurrenceState *state) {
  TaskOccurrence occurrence;
  occurrence.taskId = task.id;
  occurrence.title = task.title;
  occurrence.occurrenceDate = date;
  occurrence.scheduledTime = task.scheduledTime;
  occurrence.reminderMinutesBefore = task.reminderMinutesBefore;
  occurrence.emoji = task.emoji;
  occurrence.completed = state != nullptr && state->status == OccurrenceStatus::Completed;
  occurrence.skipped = state != nullptr && state->status == OccurrenceStatus::Skipped;
  occurrence.recurring = task.recurrence.isRecurring();
  occurrence.calendarMarker = !occurrence.recurring;
  occurrence.recurrenceLabel = task.recurrence.label();
  occurrence.recurrence = task.recurrence;
  return occurrence;
}

} // namespace

bool RecurrenceRule::isRecurring() const { return frequency != RecurrenceFrequency::None; }

bool RecurrenceRule::isValid(QString *errorMessage) const {
  const auto fail = [errorMessage](const QString &message) {
    if (errorMessage != nullptr) {
      *errorMessage = message;
    }
    return false;
  };

  if (!isRecurring()) {
    return true;
  }
  if (interval < 1) {
    return fail(QStringLiteral("O intervalo deve ser maior que zero."));
  }
  if (frequency == RecurrenceFrequency::Weekly) {
    QList<int> uniqueWeekdays;
    for (const int weekday : weekdays) {
      if (weekday < 1 || weekday > 7) {
        return fail(QStringLiteral("O dia da semana é inválido."));
      }
      if (uniqueWeekdays.contains(weekday)) {
        return fail(QStringLiteral("Os dias da semana não podem se repetir."));
      }
      uniqueWeekdays.append(weekday);
    }
  }
  if (endMode == RecurrenceEndMode::OnDate && !untilDate.isValid()) {
    return fail(QStringLiteral("A data final é inválida."));
  }
  if (endMode == RecurrenceEndMode::AfterCount && occurrenceCount < 1) {
    return fail(QStringLiteral("A quantidade de ocorrências deve ser maior que zero."));
  }
  return true;
}

QString RecurrenceRule::label() const {
  if (!isRecurring()) {
    return {};
  }

  switch (frequency) {
  case RecurrenceFrequency::Daily:
    return interval == 1 ? QStringLiteral("DIÁRIA") : QStringLiteral("A CADA %1 DIAS").arg(interval);
  case RecurrenceFrequency::Weekly: {
    QString base =
        interval == 1 ? QStringLiteral("SEMANAL") : QStringLiteral("A CADA %1 SEMANAS").arg(interval);
    if (!weekdays.isEmpty()) {
      QStringList labels;
      for (const int weekday : weekdays) {
        labels.append(weekdayLabel(weekday));
      }
      base += QStringLiteral(" · ") + labels.join(QStringLiteral(", "));
    }
    return base;
  }
  case RecurrenceFrequency::Monthly:
    return interval == 1 ? QStringLiteral("MENSAL") : QStringLiteral("A CADA %1 MESES").arg(interval);
  case RecurrenceFrequency::Yearly:
    return interval == 1 ? QStringLiteral("ANUAL") : QStringLiteral("A CADA %1 ANOS").arg(interval);
  case RecurrenceFrequency::None:
    return {};
  }
  return {};
}

QJsonObject RecurrenceRule::toJson() const {
  QJsonArray serializedWeekdays;
  for (const int weekday : weekdays) {
    serializedWeekdays.append(weekday);
  }
  return {
      {QStringLiteral("frequency"), frequencyName(frequency)},
      {QStringLiteral("interval"), interval},
      {QStringLiteral("weekdays"), serializedWeekdays},
      {QStringLiteral("endMode"), endModeName(endMode)},
      {QStringLiteral("untilDate"), untilDate.isValid() ? untilDate.toString(Qt::ISODate) : QString()},
      {QStringLiteral("occurrenceCount"), occurrenceCount},
  };
}

RecurrenceRule RecurrenceRule::fromJson(const QJsonObject &json) {
  RecurrenceRule rule;
  rule.frequency = parseFrequency(json.value(QStringLiteral("frequency")).toString());
  rule.interval = json.value(QStringLiteral("interval")).toInt(1);
  for (const QJsonValue value : json.value(QStringLiteral("weekdays")).toArray()) {
    rule.weekdays.append(value.toInt());
  }
  rule.endMode = parseEndMode(json.value(QStringLiteral("endMode")).toString());
  rule.untilDate = QDate::fromString(json.value(QStringLiteral("untilDate")).toString(), Qt::ISODate);
  rule.occurrenceCount = json.value(QStringLiteral("occurrenceCount")).toInt();
  return rule;
}

QJsonObject TaskOccurrenceState::toJson() const {
  return {
      {QStringLiteral("taskId"), taskId},
      {QStringLiteral("occurrenceDate"), occurrenceDate.toString(Qt::ISODate)},
      {QStringLiteral("status"), statusName(status)},
      {QStringLiteral("completedAt"),
       completedAt.isValid() ? completedAt.toUTC().toString(Qt::ISODateWithMs) : QString()},
      {QStringLiteral("updatedAt"), updatedAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("version"), version},
  };
}

TaskOccurrenceState TaskOccurrenceState::fromJson(const QJsonObject &json) {
  TaskOccurrenceState state;
  state.taskId = json.value(QStringLiteral("taskId")).toString();
  state.occurrenceDate =
      QDate::fromString(json.value(QStringLiteral("occurrenceDate")).toString(), Qt::ISODate);
  state.status = parseStatus(json.value(QStringLiteral("status")).toString());
  state.completedAt =
      QDateTime::fromString(json.value(QStringLiteral("completedAt")).toString(), Qt::ISODateWithMs);
  state.updatedAt =
      QDateTime::fromString(json.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
  state.version = json.value(QStringLiteral("version")).toInteger();
  return state;
}

QString TaskOccurrence::key() const { return occurrenceKey(taskId, occurrenceDate); }

QJsonObject TaskOccurrence::toJson() const {
  const QString date = occurrenceDate.toString(Qt::ISODate);
  return {
      {QStringLiteral("taskId"), taskId},
      {QStringLiteral("occurrenceKey"), key()},
      {QStringLiteral("title"), title},
      {QStringLiteral("occurrenceDate"), date},
      {QStringLiteral("scheduledDate"), date},
      {QStringLiteral("scheduledTime"),
       scheduledTime.isValid() ? scheduledTime.toString(QStringLiteral("HH:mm")) : QString()},
      {QStringLiteral("reminderMinutesBefore"), taskReminderMinutesBeforeToJson(reminderMinutesBefore)},
      {QStringLiteral("emoji"), emoji},
      {QStringLiteral("completed"), completed},
      {QStringLiteral("skipped"), skipped},
      {QStringLiteral("recurring"), recurring},
      {QStringLiteral("calendarMarker"), calendarMarker},
      {QStringLiteral("recurrenceLabel"), recurrenceLabel},
      {QStringLiteral("recurrence"), recurrence.toJson()},
  };
}

QString occurrenceKey(const QString &taskId, const QDate &occurrenceDate) {
  return taskId + QLatin1Char('@') + occurrenceDate.toString(Qt::ISODate);
}

QList<QDate> recurrenceDates(const QDate &anchorDate, const RecurrenceRule &rule, const QDate &from,
                             const QDate &to) {
  QList<QDate> dates;
  if (!anchorDate.isValid() || !from.isValid() || !to.isValid() || from > to || !rule.isRecurring() ||
      !rule.isValid() || (rule.endMode == RecurrenceEndMode::OnDate && rule.untilDate < anchorDate)) {
    return dates;
  }

  int generatedCount = 0;
  switch (rule.frequency) {
  case RecurrenceFrequency::Daily:
    for (QDate date = anchorDate; date <= to; date = date.addDays(rule.interval)) {
      if (!appendDate(dates, date, from, to, rule, generatedCount)) {
        break;
      }
    }
    break;
  case RecurrenceFrequency::Weekly: {
    QList<int> weekdays = rule.weekdays;
    if (weekdays.isEmpty()) {
      weekdays.append(anchorDate.dayOfWeek());
    }
    std::sort(weekdays.begin(), weekdays.end());
    const QDate anchorWeek = anchorDate.addDays(1 - anchorDate.dayOfWeek());
    for (QDate date = anchorDate; date <= to; date = date.addDays(1)) {
      const QDate dateWeek = date.addDays(1 - date.dayOfWeek());
      const int weekIndex = anchorWeek.daysTo(dateWeek) / 7;
      if (weekIndex % rule.interval != 0 || !weekdays.contains(date.dayOfWeek())) {
        continue;
      }
      if (!appendDate(dates, date, from, to, rule, generatedCount)) {
        break;
      }
    }
    break;
  }
  case RecurrenceFrequency::Monthly:
    for (int index = 0;; ++index) {
      const QDate date = clampedMonthDate(anchorDate, index * rule.interval);
      if (date > to || !appendDate(dates, date, from, to, rule, generatedCount)) {
        break;
      }
    }
    break;
  case RecurrenceFrequency::Yearly:
    for (int index = 0;; ++index) {
      const QDate date = clampedYearDate(anchorDate, index * rule.interval);
      if (date > to || !appendDate(dates, date, from, to, rule, generatedCount)) {
        break;
      }
    }
    break;
  case RecurrenceFrequency::None:
    break;
  }
  return dates;
}

QList<TaskOccurrence> projectOccurrences(const QList<TaskRecord> &tasks,
                                         const QList<TaskOccurrenceState> &states, const QDate &from,
                                         const QDate &to) {
  QHash<QString, TaskOccurrenceState> stateByOccurrence;
  for (const TaskOccurrenceState &state : states) {
    stateByOccurrence.insert(occurrenceKey(state.taskId, state.occurrenceDate), state);
  }

  QList<TaskOccurrence> occurrences;
  for (const TaskRecord &task : tasks) {
    if (!task.recurrence.isRecurring()) {
      if (task.scheduledDate >= from && task.scheduledDate <= to) {
        TaskOccurrence occurrence = occurrenceFor(task, task.scheduledDate, nullptr);
        occurrence.completed = task.completed;
        occurrences.append(occurrence);
      }
      continue;
    }

    for (const QDate &date : recurrenceDates(task.scheduledDate, task.recurrence, from, to)) {
      const auto state = stateByOccurrence.constFind(occurrenceKey(task.id, date));
      occurrences.append(
          occurrenceFor(task, date, state == stateByOccurrence.cend() ? nullptr : &state.value()));
    }
  }

  std::sort(occurrences.begin(), occurrences.end(),
            [](const TaskOccurrence &left, const TaskOccurrence &right) {
              if (left.occurrenceDate != right.occurrenceDate) {
                return left.occurrenceDate < right.occurrenceDate;
              }
              const int leftStatus = occurrenceStatusRank(left);
              const int rightStatus = occurrenceStatusRank(right);
              if (leftStatus != rightStatus) {
                return leftStatus < rightStatus;
              }
              if (left.scheduledTime != right.scheduledTime) {
                return left.scheduledTime < right.scheduledTime;
              }
              return left.taskId < right.taskId;
            });
  return occurrences;
}

QList<TaskOccurrence> assignCalendarMarkers(QList<TaskOccurrence> occurrences, const QList<TaskRecord> &tasks,
                                            const QList<TaskOccurrenceState> &states, const QDate &today) {
  QHash<QString, TaskOccurrenceState> stateByOccurrence;
  for (const TaskOccurrenceState &state : states) {
    stateByOccurrence.insert(occurrenceKey(state.taskId, state.occurrenceDate), state);
  }

  for (const TaskRecord &task : tasks) {
    if (!task.recurrence.isRecurring()) {
      continue;
    }

    const QDate unresolvedDueDate = firstUnresolvedDueDate(task, stateByOccurrence, today);
    QDate pendingMarkerDate = unresolvedDueDate;
    if (!pendingMarkerDate.isValid()) {
      const QList<QDate> nextDates = recurrenceDates(task.scheduledDate, task.recurrence, today.addDays(1),
                                                     nextRecurrenceSearchEnd(task, today));
      if (!nextDates.isEmpty()) {
        pendingMarkerDate = nextDates.constFirst();
      }
    }

    for (TaskOccurrence &occurrence : occurrences) {
      if (occurrence.taskId != task.id) {
        continue;
      }
      occurrence.calendarMarker = occurrence.skipped || occurrence.occurrenceDate == pendingMarkerDate;
    }
  }
  return occurrences;
}

QList<TaskOccurrence> projectActionableOccurrences(const QList<TaskRecord> &tasks,
                                                   const QList<TaskOccurrenceState> &states,
                                                   const QDate &today) {
  QHash<QString, TaskOccurrenceState> stateByOccurrence;
  for (const TaskOccurrenceState &state : states) {
    stateByOccurrence.insert(occurrenceKey(state.taskId, state.occurrenceDate), state);
  }

  QList<TaskOccurrence> occurrences;
  for (const TaskRecord &task : tasks) {
    if (!task.recurrence.isRecurring()) {
      if (task.scheduledDate <= today && (!task.completed || task.scheduledDate == today)) {
        TaskOccurrence occurrence = occurrenceFor(task, task.scheduledDate, nullptr);
        occurrence.completed = task.completed;
        occurrences.append(occurrence);
      }
      continue;
    }

    const QDate unresolvedDueDate = firstUnresolvedDueDate(task, stateByOccurrence, today);
    if (unresolvedDueDate.isValid()) {
      const auto state = stateByOccurrence.constFind(occurrenceKey(task.id, unresolvedDueDate));
      occurrences.append(occurrenceFor(task, unresolvedDueDate,
                                       state == stateByOccurrence.cend() ? nullptr : &state.value()));
      continue;
    }

    const auto todayState = stateByOccurrence.constFind(occurrenceKey(task.id, today));
    if (todayState != stateByOccurrence.cend() &&
        (todayState->status == OccurrenceStatus::Completed ||
         todayState->status == OccurrenceStatus::Skipped)) {
      occurrences.append(occurrenceFor(task, today, &todayState.value()));
    }
  }

  std::sort(occurrences.begin(), occurrences.end(),
            [](const TaskOccurrence &left, const TaskOccurrence &right) {
              const int leftStatus = occurrenceStatusRank(left);
              const int rightStatus = occurrenceStatusRank(right);
              if (leftStatus != rightStatus) {
                return leftStatus < rightStatus;
              }
              if (left.scheduledTime != right.scheduledTime) {
                return left.scheduledTime < right.scheduledTime;
              }
              if (left.occurrenceDate != right.occurrenceDate) {
                return left.occurrenceDate < right.occurrenceDate;
              }
              return left.taskId < right.taskId;
            });
  return occurrences;
}

OccurrenceSummary summarizeOccurrences(const QList<TaskOccurrence> &occurrences, const QDate &today) {
  OccurrenceSummary summary;
  for (const TaskOccurrence &occurrence : occurrences) {
    if (occurrence.skipped) {
      continue;
    }
    if (occurrence.completed) {
      continue;
    }
    if (occurrence.occurrenceDate == today) {
      ++summary.pendingToday;
    } else if (occurrence.occurrenceDate < today) {
      ++summary.overdue;
    }
  }
  return summary;
}

} // namespace waypoint

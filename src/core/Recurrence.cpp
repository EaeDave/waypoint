#include "core/Recurrence.hpp"

#include "core/TaskRecord.hpp"

#include <QHash>
#include <QJsonArray>
#include <QMap>
#include <QSet>
#include <QStringList>

#include <algorithm>
#include <utility>
#include <limits>

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
                             const QDate &today,
                             const int candidateLimit = std::numeric_limits<int>::max()) {
  RecurrenceRule rule = task.recurrence;
  QDate searchEnd = today;
  if (rule.endMode == RecurrenceEndMode::OnDate) {
    searchEnd = std::min(searchEnd, rule.untilDate);
  }
  rule.occurrenceCount = rule.endMode == RecurrenceEndMode::AfterCount
                             ? std::min(rule.occurrenceCount, candidateLimit)
                             : candidateLimit;
  rule.endMode = RecurrenceEndMode::AfterCount;
  const QList<QDate> dueDates =
      recurrenceDates(task.scheduledDate, rule, task.scheduledDate, searchEnd);
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
  occurrence.calendarDate = date;
  occurrence.scheduledTime = task.scheduledTime;
  occurrence.reminderMinutesBefore = task.reminderMinutesBefore;
  occurrence.emoji = task.emoji;
  occurrence.categoryId = task.categoryName.isEmpty() ? QString{} : task.categoryId;
  occurrence.categoryName = task.categoryName;
  occurrence.categoryColor = task.categoryColor;
  occurrence.completed = state != nullptr ? state->status == OccurrenceStatus::Completed
                                          : !task.recurrence.isRecurring() && task.completed;
  occurrence.skipped = state != nullptr && state->status == OccurrenceStatus::Skipped;
  occurrence.recurring = task.recurrence.isRecurring();
  occurrence.calendarMarker = !occurrence.recurring || occurrence.completed;
  occurrence.recurrenceLabel = task.recurrence.label();
  occurrence.recurrence = task.recurrence;
  if (occurrence.completed) {
    occurrence.completedDate = state != nullptr ? state->completedDate : task.completedDate;
    occurrence.registeredAt = state != nullptr ? state->registeredAt : task.registeredAt;
  }
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
      {QStringLiteral("completedDate"), completedDate.toString(Qt::ISODate)},
      {QStringLiteral("registeredAt"), registeredAt.toUTC().toString(Qt::ISODateWithMs)},
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
  if (state.status == OccurrenceStatus::Completed) {
    state.completedDate = QDate::fromString(json.value(QStringLiteral("completedDate")).toString(), Qt::ISODate);
    state.registeredAt = QDateTime::fromString(
        json.value(json.contains(QStringLiteral("registeredAt")) ? QStringLiteral("registeredAt")
                                                                 : QStringLiteral("completedAt")).toString(),
        Qt::ISODateWithMs);
  }
  state.updatedAt =
      QDateTime::fromString(json.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
  state.version = json.value(QStringLiteral("version")).toInteger();
  return state;
}

QString TaskOccurrence::key() const { return occurrenceKey(taskId, occurrenceDate); }

QDate TaskOccurrence::effectiveCalendarDate() const {
  return occurrenceDate;
}

bool TaskOccurrence::completionLate() const {
  return completed && completedDate.isValid() && occurrenceDate.isValid() && completedDate > occurrenceDate;
}

QString TaskOccurrence::completionLabel() const {
  if (!completed) {
    return {};
  }
  const QDate registrationDate = registeredAt.toLocalTime().date();
  const auto dateLabel = [](const QDate &date) { return date.toString(QStringLiteral("dd/MM/yyyy")); };
  if (!completedDate.isValid()) {
    return registrationDate.isValid()
               ? QStringLiteral("CONCLUÍDA · REGISTRADA %1").arg(dateLabel(registrationDate))
               : QStringLiteral("CONCLUÍDA");
  }
  if (completionLate()) {
    const qint64 days = occurrenceDate.daysTo(completedDate);
    return QStringLiteral("CONCLUÍDA %1 · %2 %3 DEPOIS")
        .arg(dateLabel(completedDate)).arg(days)
        .arg(days == 1 ? QStringLiteral("DIA") : QStringLiteral("DIAS"));
  }
  if (registrationDate.isValid() && registrationDate != completedDate) {
    return QStringLiteral("CONCLUÍDA %1 · REGISTRADA %2")
        .arg(dateLabel(completedDate), dateLabel(registrationDate));
  }
  return completedDate == occurrenceDate
             ? QStringLiteral("CONCLUÍDA")
             : QStringLiteral("CONCLUÍDA %1").arg(dateLabel(completedDate));
}

QJsonObject TaskOccurrence::toJson() const {
  const QString date = occurrenceDate.toString(Qt::ISODate);
  return {
      {QStringLiteral("taskId"), taskId},
      {QStringLiteral("occurrenceKey"), key()},
      {QStringLiteral("title"), title},
      {QStringLiteral("occurrenceDate"), date},
      {QStringLiteral("scheduledDate"), date},
      {QStringLiteral("calendarDate"), effectiveCalendarDate().toString(Qt::ISODate)},
      {QStringLiteral("scheduledTime"),
       scheduledTime.isValid() ? scheduledTime.toString(QStringLiteral("HH:mm")) : QString()},
      {QStringLiteral("reminderMinutesBefore"), taskReminderMinutesBeforeToJson(reminderMinutesBefore)},
      {QStringLiteral("emoji"), emoji},
      {QStringLiteral("categoryId"),
       categoryId.isEmpty() ? QJsonValue(QJsonValue::Null) : QJsonValue(categoryId)},
      {QStringLiteral("categoryName"), categoryName},
      {QStringLiteral("categoryColor"), categoryColor},
      {QStringLiteral("completed"), completed},
      {QStringLiteral("completedDate"), completedDate.toString(Qt::ISODate)},
      {QStringLiteral("registeredAt"), registeredAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("completionLabel"), completionLabel()},
      {QStringLiteral("completionLate"), completionLate()},
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

QJsonArray projectTaskDefinitions(const QList<TaskRecord> &tasks,
                                  const QList<TaskOccurrenceState> &states, const QDate &today) {
  QHash<QString, TaskOccurrenceState> stateByOccurrence;
  QHash<QString, QDate> lastResolvedDate;
  QHash<QString, int> resolvedCounts;
  for (const TaskOccurrenceState &state : states) {
    stateByOccurrence.insert(occurrenceKey(state.taskId, state.occurrenceDate), state);
    if (state.status != OccurrenceStatus::Pending) {
      lastResolvedDate[state.taskId] = std::max(lastResolvedDate.value(state.taskId), state.occurrenceDate);
      ++resolvedCounts[state.taskId];
    }
  }

  QJsonArray result;
  for (const TaskRecord &task : tasks) {
    QDate pendingDate = task.completed ? QDate{} : task.scheduledDate;
    if (task.recurrence.isRecurring()) {
      // At most N resolved occurrences can precede the first unresolved one.
      // Bound generation by stored history, not by the age of an open-ended series.
      pendingDate = firstUnresolvedDueDate(
          task, stateByOccurrence,
          nextRecurrenceSearchEnd(task, lastResolvedDate.value(task.id, task.scheduledDate)),
          resolvedCounts.value(task.id) + 1);
    }
    QJsonObject value = task.toJson();
    value.insert(QStringLiteral("taskId"), task.id);
    value.insert(QStringLiteral("categoryName"), task.categoryName);
    value.insert(QStringLiteral("categoryColor"), task.categoryColor);
    value.insert(QStringLiteral("recurring"), task.recurrence.isRecurring());
    value.insert(QStringLiteral("recurrenceLabel"), task.recurrence.label());
    TaskOccurrence occurrence;
    occurrence.occurrenceDate = task.scheduledDate;
    occurrence.completed = task.completed;
    occurrence.completedDate = task.completedDate;
    occurrence.registeredAt = task.registeredAt;
    value.insert(QStringLiteral("completionLabel"), occurrence.completionLabel());
    value.insert(QStringLiteral("completionLate"), occurrence.completionLate());
    value.insert(QStringLiteral("pendingDate"), pendingDate.toString(Qt::ISODate));
    value.insert(QStringLiteral("overdue"), pendingDate.isValid() && pendingDate < today);
    result.append(value);
  }
  return result;
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
      const TaskOccurrence occurrence = occurrenceFor(task, task.scheduledDate, nullptr);
      if (occurrence.calendarDate >= from && occurrence.calendarDate <= to) {
        occurrences.append(occurrence);
      }
      continue;
    }

    for (const QDate &date : recurrenceDates(task.scheduledDate, task.recurrence, from, to)) {
      const auto state = stateByOccurrence.constFind(occurrenceKey(task.id, date));
      const TaskOccurrence occurrence =
          occurrenceFor(task, date, state == stateByOccurrence.cend() ? nullptr : &state.value());
      occurrences.append(occurrence);
    }
  }

  std::sort(occurrences.begin(), occurrences.end(),
            [](const TaskOccurrence &left, const TaskOccurrence &right) {
              if (left.calendarDate != right.calendarDate) {
                return left.calendarDate < right.calendarDate;
              }
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
      occurrence.calendarMarker =
          occurrence.completed || occurrence.skipped || occurrence.occurrenceDate == pendingMarkerDate;
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
      const TaskOccurrence occurrence = occurrenceFor(task, task.scheduledDate, nullptr);
      if ((!occurrence.completed && task.scheduledDate <= today) ||
          (occurrence.completed && occurrence.calendarDate == today)) {
        occurrences.append(occurrence);
      }
      continue;
    }

    const auto todayState = stateByOccurrence.constFind(occurrenceKey(task.id, today));
    if (todayState != stateByOccurrence.cend() && todayState->status != OccurrenceStatus::Pending &&
        !recurrenceDates(task.scheduledDate, task.recurrence, today, today).isEmpty()) {
      occurrences.append(occurrenceFor(task, today, &todayState.value()));
    }

    const QDate unresolvedDueDate = firstUnresolvedDueDate(task, stateByOccurrence, today);
    if (unresolvedDueDate.isValid()) {
      const auto state = stateByOccurrence.constFind(occurrenceKey(task.id, unresolvedDueDate));
      occurrences.append(occurrenceFor(task, unresolvedDueDate,
                                       state == stateByOccurrence.cend() ? nullptr : &state.value()));
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
              if (left.calendarDate != right.calendarDate) {
                return left.calendarDate < right.calendarDate;
              }
              if (left.occurrenceDate != right.occurrenceDate) {
                return left.occurrenceDate < right.occurrenceDate;
              }
              return left.taskId < right.taskId;
            });
  return occurrences;
}

QJsonObject projectRegistrationActivity(const QList<TaskRecord> &tasks,
                                        const QList<TaskOccurrenceState> &states,
                                        const QDate &from, const QDate &to) {
  QHash<QString, const TaskRecord *> taskById;
  taskById.reserve(tasks.size());
  QMap<QDate, QMap<QString, QList<TaskOccurrence>>> grouped;
  const auto addOccurrence = [&grouped, &from, &to](TaskOccurrence occurrence) {
    const QDate day = occurrence.registeredAt.toLocalTime().date();
    if (occurrence.completed && occurrence.occurrenceDate.isValid() && day.isValid() &&
        day >= from && day <= to && day != occurrence.occurrenceDate) {
      grouped[day][occurrence.taskId].append(std::move(occurrence));
    }
  };
  for (const TaskRecord &task : tasks) {
    taskById.insert(task.id, &task);
    if (task.completed && !task.recurrence.isRecurring()) {
      addOccurrence(occurrenceFor(task, task.scheduledDate, nullptr));
    }
  }
  for (const TaskOccurrenceState &state : states) {
    const auto task = taskById.constFind(state.taskId);
    if (task == taskById.cend() || !(*task)->recurrence.isRecurring() ||
        state.status != OccurrenceStatus::Completed) {
      continue;
    }
    const QDate day = state.registeredAt.toLocalTime().date();
    if (!day.isValid() || day < from || day > to || day == state.occurrenceDate ||
        recurrenceDates((*task)->scheduledDate, (*task)->recurrence,
                        state.occurrenceDate, state.occurrenceDate).isEmpty()) {
      continue;
    }
    addOccurrence(occurrenceFor(**task, state.occurrenceDate, &state));
  }
  QJsonObject result;
  for (auto day = grouped.begin(); day != grouped.end(); ++day) {
    QJsonArray groups;
    for (auto task = day->begin(); task != day->end(); ++task) {
      auto &occurrences = task.value();
      std::sort(occurrences.begin(), occurrences.end(), [](const auto &left, const auto &right) {
        return left.occurrenceDate < right.occurrenceDate;
      });
      QJsonArray children;
      QStringList dates;
      for (const TaskOccurrence &occurrence : std::as_const(occurrences)) {
        children.append(occurrence.toJson());
        dates.append(occurrence.occurrenceDate.toString(QStringLiteral("dd/MM/yyyy")));
      }
      const TaskOccurrence &first = occurrences.constFirst();
      groups.append(QJsonObject{
          {QStringLiteral("taskId"), first.taskId},
          {QStringLiteral("title"), first.title},
          {QStringLiteral("emoji"), first.emoji},
          {QStringLiteral("categoryId"), first.categoryId},
          {QStringLiteral("count"), occurrences.size()},
          {QStringLiteral("dateSummary"), QStringLiteral("REFERENTES A %1").arg(dates.join(QStringLiteral(", ")))},
          {QStringLiteral("occurrences"), children},
      });
    }
    result.insert(day.key().toString(Qt::ISODate), groups);
  }
  return result;
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

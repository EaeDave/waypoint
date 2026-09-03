#pragma once

#include <QDate>
#include <QDateTime>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QTime>

namespace waypoint {

struct TaskRecord;

enum class RecurrenceFrequency { None, Daily, Weekly, Monthly, Yearly };
enum class RecurrenceEndMode { Never, OnDate, AfterCount };
enum class OccurrenceStatus { Pending, Completed, Skipped };
enum class RecurrenceEditScope { Occurrence, Following, Series };

struct RecurrenceRule final {
  RecurrenceFrequency frequency = RecurrenceFrequency::None;
  int interval = 1;
  QList<int> weekdays;
  RecurrenceEndMode endMode = RecurrenceEndMode::Never;
  QDate untilDate;
  int occurrenceCount = 0;

  [[nodiscard]] bool isRecurring() const;
  [[nodiscard]] bool isValid(QString *errorMessage = nullptr) const;
  [[nodiscard]] QString label() const;
  [[nodiscard]] QJsonObject toJson() const;
  [[nodiscard]] static RecurrenceRule fromJson(const QJsonObject &json);
};

struct TaskOccurrenceState final {
  QString taskId;
  QDate occurrenceDate;
  OccurrenceStatus status = OccurrenceStatus::Completed;
  QDateTime completedAt;
  QDateTime updatedAt;
  qint64 version = 0;

  [[nodiscard]] QJsonObject toJson() const;
  [[nodiscard]] static TaskOccurrenceState fromJson(const QJsonObject &json);
};

struct TaskOccurrence final {
  QString taskId;
  QString title;
  QDate occurrenceDate;
  QTime scheduledTime;
  QList<int> reminderMinutesBefore{0};
  QString emoji;
  bool completed = false;
  bool skipped = false;
  bool recurring = false;
  bool calendarMarker = true;
  QString recurrenceLabel;
  RecurrenceRule recurrence;

  [[nodiscard]] QString key() const;
  [[nodiscard]] QJsonObject toJson() const;
};

struct OccurrenceSummary final {
  int pendingToday = 0;
  int overdue = 0;
};

[[nodiscard]] QString occurrenceKey(const QString &taskId, const QDate &occurrenceDate);
[[nodiscard]] QList<QDate> recurrenceDates(const QDate &anchorDate, const RecurrenceRule &rule,
                                           const QDate &from, const QDate &to);
[[nodiscard]] QList<TaskOccurrence> projectOccurrences(const QList<TaskRecord> &tasks,
                                                       const QList<TaskOccurrenceState> &states,
                                                       const QDate &from, const QDate &to);
[[nodiscard]] QList<TaskOccurrence> assignCalendarMarkers(QList<TaskOccurrence> occurrences,
                                                          const QList<TaskRecord> &tasks,
                                                          const QList<TaskOccurrenceState> &states,
                                                          const QDate &today);
[[nodiscard]] QList<TaskOccurrence> projectActionableOccurrences(const QList<TaskRecord> &tasks,
                                                                 const QList<TaskOccurrenceState> &states,
                                                                 const QDate &today);

[[nodiscard]] OccurrenceSummary summarizeOccurrences(const QList<TaskOccurrence> &occurrences,
                                                     const QDate &today);
} // namespace waypoint

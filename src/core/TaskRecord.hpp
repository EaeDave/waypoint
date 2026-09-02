#pragma once

#include "core/Recurrence.hpp"

#include <QDate>
#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QTime>

namespace waypoint {
inline constexpr qsizetype maximumTaskReminderCount = 5;

[[nodiscard]] bool validateTaskReminderMinutesBefore(const QList<int> &minutesBefore,
                                                     QString *errorMessage = nullptr);
[[nodiscard]] QJsonArray taskReminderMinutesBeforeToJson(const QList<int> &minutesBefore);
[[nodiscard]] QList<int> taskReminderMinutesBeforeFromJson(const QJsonValue &value);

struct TaskRecord final {
  QString id;
  QString title;
  QDate scheduledDate;
  QTime scheduledTime;
  QList<int> reminderMinutesBefore{0};
  QString emoji;
  bool completed = false;
  RecurrenceRule recurrence;
  QDateTime createdAt;
  QDateTime updatedAt;
  qint64 version = 0;

  [[nodiscard]] QJsonObject toJson() const;
  [[nodiscard]] static TaskRecord fromJson(const QJsonObject &json);
};

} // namespace waypoint

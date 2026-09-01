#pragma once

#include "core/Recurrence.hpp"

#include <QDate>
#include <QDateTime>
#include <QJsonObject>
#include <QString>
#include <QTime>

namespace waypoint {

struct TaskRecord final {
  QString id;
  QString title;
  QDate scheduledDate;
  QTime scheduledTime;
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

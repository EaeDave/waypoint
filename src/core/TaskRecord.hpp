#pragma once

#include <QDate>
#include <QDateTime>
#include <QJsonObject>
#include <QString>

namespace waypoint {

struct TaskRecord final {
  QString id;
  QString title;
  QDate scheduledDate;
  bool completed = false;
  QDateTime createdAt;
  QDateTime updatedAt;
  qint64 version = 0;

  [[nodiscard]] QJsonObject toJson() const;
  [[nodiscard]] static TaskRecord fromJson(const QJsonObject &json);
};

} // namespace waypoint

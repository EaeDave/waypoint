#pragma once

#include <QDateTime>
#include <QJsonObject>
#include <QString>

namespace waypoint {

inline constexpr qsizetype maximumTaskCategoryNameLength = 80;

[[nodiscard]] bool validateTaskCategoryName(const QString &name, QString *errorMessage = nullptr);
[[nodiscard]] bool validateTaskCategoryColor(const QString &color, QString *errorMessage = nullptr);

struct TaskCategory final {
  QString id;
  QString name;
  QString color;
  QDateTime createdAt;
  QDateTime updatedAt;
  qint64 version = 0;

  [[nodiscard]] QJsonObject toJson() const;
  [[nodiscard]] static TaskCategory fromJson(const QJsonObject &json);
};

} // namespace waypoint

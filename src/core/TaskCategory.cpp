#include "core/TaskCategory.hpp"

#include <QRegularExpression>

namespace waypoint {
namespace {

void setError(QString *destination, const QString &message) {
  if (destination != nullptr) {
    *destination = message;
  }
}

} // namespace

bool validateTaskCategoryName(const QString &name, QString *errorMessage) {
  const QString normalized = name.trimmed();
  if (normalized.isEmpty() || normalized.size() > maximumTaskCategoryNameLength) {
    setError(errorMessage,
             QStringLiteral("Category name must contain 1 to %1 characters")
                 .arg(maximumTaskCategoryNameLength));
    return false;
  }
  setError(errorMessage, {});
  return true;
}

bool validateTaskCategoryColor(const QString &color, QString *errorMessage) {
  static const QRegularExpression pattern(QStringLiteral("^#[0-9A-Fa-f]{6}$"));
  if (!pattern.match(color).hasMatch()) {
    setError(errorMessage, QStringLiteral("Category color must use #RRGGBB format"));
    return false;
  }
  setError(errorMessage, {});
  return true;
}

QJsonObject TaskCategory::toJson() const {
  return {
      {QStringLiteral("id"), id},
      {QStringLiteral("name"), name},
      {QStringLiteral("color"), color.toUpper()},
      {QStringLiteral("createdAt"), createdAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("updatedAt"), updatedAt.toUTC().toString(Qt::ISODateWithMs)},
      {QStringLiteral("version"), version},
  };
}

TaskCategory TaskCategory::fromJson(const QJsonObject &json) {
  TaskCategory category;
  category.id = json.value(QStringLiteral("id")).toString();
  category.name = json.value(QStringLiteral("name")).toString();
  category.color = json.value(QStringLiteral("color")).toString().toUpper();
  category.createdAt =
      QDateTime::fromString(json.value(QStringLiteral("createdAt")).toString(), Qt::ISODateWithMs);
  category.updatedAt =
      QDateTime::fromString(json.value(QStringLiteral("updatedAt")).toString(), Qt::ISODateWithMs);
  category.version = json.value(QStringLiteral("version")).toInteger();
  return category;
}

} // namespace waypoint

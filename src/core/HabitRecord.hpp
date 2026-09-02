#pragma once

#include <QDate>
#include <QDateTime>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QTime>

namespace waypoint {

inline constexpr qsizetype maximumHabitReminderCount = 10;
inline constexpr qint64 maximumHabitAmount = 1'000'000'000;

enum class HabitCheckInMode { Fixed, Manual, CompleteAll };

[[nodiscard]] QString habitCheckInModeName(HabitCheckInMode mode);
[[nodiscard]] HabitCheckInMode habitCheckInModeFromName(const QString &name);

struct HabitRecord final {
  QString id;
  QString title;
  qint64 targetAmount = 1;
  QString unit;
  HabitCheckInMode checkInMode = HabitCheckInMode::CompleteAll;
  qint64 incrementAmount = 1;
  QList<int> weekdays{1, 2, 3, 4, 5, 6, 7};
  QList<QTime> reminderTimes;
  QString emoji;
  QDateTime createdAt;
  QDateTime updatedAt;
  qint64 version = 0;

  [[nodiscard]] bool isScheduledOn(const QDate &date) const;
  [[nodiscard]] bool isValid(QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject toJson() const;
  [[nodiscard]] static HabitRecord fromJson(const QJsonObject &json);
};

struct HabitEntry final {
  QString id;
  QString habitId;
  QDate entryDate;
  qint64 amount = 0;
  QDateTime loggedAt;
  QDateTime updatedAt;
  qint64 version = 0;

  [[nodiscard]] bool isValid(QString *errorMessage = nullptr) const;
  [[nodiscard]] QJsonObject toJson() const;
  [[nodiscard]] static HabitEntry fromJson(const QJsonObject &json);
};

struct HabitProgress final {
  HabitRecord habit;
  QDate date;
  qint64 amount = 0;

  [[nodiscard]] bool completed() const;
  [[nodiscard]] QJsonObject toJson() const;
};

} // namespace waypoint

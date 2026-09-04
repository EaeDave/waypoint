#include "WaypointVersion.hpp"

#include "ipc/WaypointIpcClient.hpp"

#include <QCommandLineParser>
#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <cstdio>

#include <algorithm>
#include <optional>

namespace {

int printError(const QString &message) {
  const QByteArray bytes = message.toUtf8();
  fprintf(stderr, "%s\n", bytes.constData());
  return 1;
}

void printJson(const QJsonObject &json) {
  const QByteArray bytes = QJsonDocument(json).toJson(QJsonDocument::Compact);
  fprintf(stdout, "%s\n", bytes.constData());
}

std::optional<QList<int>> parseReminderMinutesBefore(const QString &value, QString *errorMessage) {
  if (value.trimmed() == QStringLiteral("none")) {
    return QList<int>{};
  }

  QList<int> reminders;
  const QStringList values = value.split(QLatin1Char(','), Qt::SkipEmptyParts);
  reminders.reserve(values.size());
  for (const QString &item : values) {
    bool valid = false;
    const int minutes = item.trimmed().toInt(&valid);
    if (!valid) {
      *errorMessage = QStringLiteral("--reminders must be 'none' or comma-separated minutes");
      return std::nullopt;
    }
    reminders.append(minutes);
  }
  std::ranges::sort(reminders, std::greater{});
  if (!waypoint::validateTaskReminderMinutesBefore(reminders, errorMessage)) {
    return std::nullopt;
  }
  return reminders;
}

std::optional<waypoint::HabitRecord> habitFromOptions(const QCommandLineParser &parser,
                                                      QString *errorMessage) {
  waypoint::HabitRecord habit;
  habit.title = parser.value(QStringLiteral("title")).trimmed();
  bool validGoal = false;
  habit.targetAmount = parser.value(QStringLiteral("goal")).toLongLong(&validGoal);
  habit.unit = parser.value(QStringLiteral("unit")).trimmed();
  const QString mode = parser.value(QStringLiteral("check-in"));
  if (!QStringList{QStringLiteral("fixed"), QStringLiteral("manual"), QStringLiteral("complete")}.contains(
          mode)) {
    *errorMessage = QStringLiteral("--check-in must be fixed, manual, or complete");
    return std::nullopt;
  }
  habit.checkInMode = waypoint::habitCheckInModeFromName(mode);
  bool validIncrement = false;
  habit.incrementAmount = parser.value(QStringLiteral("increment")).toLongLong(&validIncrement);
  habit.emoji = parser.value(QStringLiteral("emoji"));
  if (!validGoal || !validIncrement) {
    *errorMessage = QStringLiteral("--goal and --increment must be integers");
    return std::nullopt;
  }

  const QString weekdayInput = parser.isSet(QStringLiteral("weekdays"))
                                   ? parser.value(QStringLiteral("weekdays"))
                                   : QStringLiteral("1,2,3,4,5,6,7");
  habit.weekdays.clear();
  for (const QString &value : weekdayInput.split(QLatin1Char(','), Qt::SkipEmptyParts)) {
    bool valid = false;
    const int weekday = value.trimmed().toInt(&valid);
    if (!valid || weekday < 1 || weekday > 7) {
      *errorMessage = QStringLiteral("--weekdays must contain values from 1 through 7");
      return std::nullopt;
    }
    habit.weekdays.append(weekday);
  }

  const QString reminderInput = parser.isSet(QStringLiteral("reminder-times"))
                                    ? parser.value(QStringLiteral("reminder-times"))
                                    : QStringLiteral("none");
  if (reminderInput.trimmed() != QStringLiteral("none")) {
    for (const QString &value : reminderInput.split(QLatin1Char(','), Qt::SkipEmptyParts)) {
      const QTime time = QTime::fromString(value.trimmed(), QStringLiteral("HH:mm"));
      if (!time.isValid()) {
        *errorMessage = QStringLiteral("--reminder-times must be 'none' or comma-separated HH:mm times");
        return std::nullopt;
      }
      habit.reminderTimes.append(time);
    }
  }

  QString validationError;
  if (!habit.isValid(&validationError)) {
    *errorMessage = validationError;
    return std::nullopt;
  }
  return habit;
}

} // namespace

int main(int argc, char *argv[]) {
  QCoreApplication application(argc, argv);
  QCoreApplication::setApplicationName(QStringLiteral("waypointctl"));
  QCoreApplication::setApplicationVersion(QString::fromLatin1(waypoint::version));

  QCommandLineParser parser;
  parser.setApplicationDescription(QStringLiteral("Local command line client for Waypoint"));
  parser.addHelpOption();
  parser.addVersionOption();
  parser.addPositionalArgument(
      QStringLiteral("command"),
      QStringLiteral("ping, snapshot, habits, add-habit, edit-habit, record-habit, undo-habit, "
                     "delete-habit, add, complete, reopen, skip, edit, reschedule, delete, "
                     "task-visibility, sync-status, sync-config, configure-sync, disable-sync, sync-now, "
                     "holiday-status, holiday-preferences, configure-holidays, municipalities, holidays, "
                     "refresh-holidays, update-status, check-update, or update"));
  parser.addPositionalArgument(QStringLiteral("arguments"), QStringLiteral("Command arguments"),
                               QStringLiteral("[arguments...]"));
  parser.addOption({{QStringLiteral("t"), QStringLiteral("title")},
                    QStringLiteral("Task or habit title"),
                    QStringLiteral("title")});
  parser.addOption({{QStringLiteral("d"), QStringLiteral("date")},
                    QStringLiteral("Calendar date in YYYY-MM-DD format"),
                    QStringLiteral("date")});
  parser.addOption({QStringLiteral("time"), QStringLiteral("Scheduled local time in HH:mm format"),
                    QStringLiteral("time")});
  parser.addOption(
      {QStringLiteral("emoji"), QStringLiteral("Optional task or habit emoji"), QStringLiteral("emoji")});
  parser.addOption({QStringLiteral("reminders"),
                    QStringLiteral("Comma-separated minutes before the task, up to 5; use 'none' to disable"),
                    QStringLiteral("minutes")});
  parser.addOption({QStringLiteral("frequency"),
                    QStringLiteral("Recurrence frequency: none, daily, weekly, monthly, or yearly"),
                    QStringLiteral("frequency"), QStringLiteral("none")});
  parser.addOption({QStringLiteral("interval"), QStringLiteral("Recurrence interval"),
                    QStringLiteral("count"), QStringLiteral("1")});
  parser.addOption({QStringLiteral("weekdays"),
                    QStringLiteral("Comma-separated ISO weekdays (1=Monday, 7=Sunday)"),
                    QStringLiteral("days")});
  parser.addOption({QStringLiteral("goal"), QStringLiteral("Habit daily goal"), QStringLiteral("amount"),
                    QStringLiteral("1")});
  parser.addOption({QStringLiteral("unit"), QStringLiteral("Habit goal unit"), QStringLiteral("unit")});
  parser.addOption({QStringLiteral("check-in"),
                    QStringLiteral("Habit check-in mode: fixed, manual, or complete"), QStringLiteral("mode"),
                    QStringLiteral("complete")});
  parser.addOption({QStringLiteral("increment"), QStringLiteral("Fixed habit check-in increment"),
                    QStringLiteral("amount"), QStringLiteral("1")});
  parser.addOption({QStringLiteral("reminder-times"),
                    QStringLiteral("Comma-separated habit reminder times, up to 10; use 'none' to disable"),
                    QStringLiteral("times")});
  parser.addOption(
      {QStringLiteral("amount"), QStringLiteral("Manual habit check-in amount"), QStringLiteral("amount")});
  parser.addOption({QStringLiteral("end-mode"),
                    QStringLiteral("Recurrence ending: never, onDate, or afterCount"), QStringLiteral("mode"),
                    QStringLiteral("never")});
  parser.addOption({QStringLiteral("until"), QStringLiteral("Recurrence end date in YYYY-MM-DD format"),
                    QStringLiteral("date")});
  parser.addOption({QStringLiteral("count"), QStringLiteral("Recurrence occurrence count"),
                    QStringLiteral("count"), QStringLiteral("0")});
  parser.addOption({QStringLiteral("endpoint"), QStringLiteral("Waypoint synchronization server URL"),
                    QStringLiteral("url")});
  parser.addOption({QStringLiteral("token"), QStringLiteral("Waypoint synchronization access token"),
                    QStringLiteral("token")});
  parser.addOption({QStringLiteral("state"), QStringLiteral("Brazilian state code"), QStringLiteral("UF")});
  parser.addOption(
      {QStringLiteral("city"), QStringLiteral("IBGE municipality code"), QStringLiteral("code")});
  parser.addOption({QStringLiteral("national"), QStringLiteral("Include national holidays (on/off)"),
                    QStringLiteral("on|off")});
  parser.addOption({QStringLiteral("state-holidays"), QStringLiteral("Include state holidays (on/off)"),
                    QStringLiteral("on|off")});
  parser.addOption({QStringLiteral("municipal"), QStringLiteral("Include municipal holidays (on/off)"),
                    QStringLiteral("on|off")});
  parser.addOption({QStringLiteral("commemorative"), QStringLiteral("Include commemorative dates (on/off)"),
                    QStringLiteral("on|off")});
  parser.addOption({QStringLiteral("optional"), QStringLiteral("Include optional dates (on/off)"),
                    QStringLiteral("on|off")});
  parser.addOption(
      {QStringLiteral("from"), QStringLiteral("Range start in YYYY-MM-DD format"), QStringLiteral("date")});
  parser.addOption(
      {QStringLiteral("to"), QStringLiteral("Range end in YYYY-MM-DD format"), QStringLiteral("date")});
  parser.process(application);

  const QStringList positional = parser.positionalArguments();
  if (positional.isEmpty()) {
    parser.showHelp(1);
  }

  waypoint::WaypointIpcClient client;
  QString error;
  const QString command = positional.first();
  if (command == QStringLiteral("ping")) {
    if (!client.ping(&error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}, {QStringLiteral("status"), QStringLiteral("ready")}});
    return 0;
  }
  if (command == QStringLiteral("snapshot")) {
    QJsonObject todaySummary = client.request({{QStringLiteral("command"), QStringLiteral("today")}}, &error);
    if (!error.isEmpty() || !todaySummary.value(QStringLiteral("ok")).toBool()) {
      return printError(error.isEmpty() ? todaySummary.value(QStringLiteral("error")).toString() : error);
    }
    todaySummary.remove(QStringLiteral("ok"));

    const bool hasRange = parser.isSet(QStringLiteral("from")) || parser.isSet(QStringLiteral("to"));
    const QDate requestedFrom = QDate::fromString(parser.value(QStringLiteral("from")), Qt::ISODate);
    const QDate requestedTo = QDate::fromString(parser.value(QStringLiteral("to")), Qt::ISODate);
    if (hasRange && (!requestedFrom.isValid() || !requestedTo.isValid() || requestedFrom > requestedTo)) {
      return printError(QStringLiteral("snapshot range requires ordered --from and --to dates"));
    }
    QJsonArray occurrences = todaySummary.value(QStringLiteral("occurrences")).toArray();
    if (hasRange) {
      occurrences = {};
      for (const waypoint::TaskOccurrence &occurrence :
           client.listOccurrences(requestedFrom, requestedTo, &error)) {
        occurrences.append(occurrence.toJson());
      }
      if (!error.isEmpty()) {
        return printError(error);
      }
    }

    const QJsonObject sync = client.syncStatus(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    const QDate today = QDate::currentDate();
    const QDate holidayFrom = hasRange ? requestedFrom : QDate(today.year() - 1, 1, 1);
    const QDate holidayTo = hasRange ? requestedTo : QDate(today.year() + 1, 12, 31);
    const QJsonObject holidayData = client.holidays(holidayFrom, holidayTo, &error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    const QJsonObject holidayPreferences = client.holidayPreferences(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    const QJsonObject holidayStatus = client.holidayStatus(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    const QString taskVisibility = client.taskVisibility(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    const QJsonObject updateStatus = client.updateStatus(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true},
               {QStringLiteral("today"), todaySummary},
               {QStringLiteral("occurrences"), occurrences},
               {QStringLiteral("taskVisibility"), taskVisibility},
               {QStringLiteral("sync"), sync},
               {QStringLiteral("holidays"), holidayData.value(QStringLiteral("holidays"))},
               {QStringLiteral("holidayCoverage"), holidayData.value(QStringLiteral("coverage"))},
               {QStringLiteral("holidayPreferences"), holidayPreferences},
               {QStringLiteral("holidaySync"), holidayStatus},
               {QStringLiteral("update"), updateStatus}});
    return 0;
  }
  if (command == QStringLiteral("habits")) {
    const QDate date = parser.isSet(QStringLiteral("date"))
                           ? QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate)
                           : QDate::currentDate();
    if (!date.isValid()) {
      return printError(QStringLiteral("habits requires --date YYYY-MM-DD"));
    }
    QJsonArray habits;
    for (const waypoint::HabitProgress &progress : client.listHabitProgress(date, &error)) {
      habits.append(progress.toJson());
    }
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true},
               {QStringLiteral("date"), date.toString(Qt::ISODate)},
               {QStringLiteral("habits"), habits}});
    return 0;
  }
  if (command == QStringLiteral("add-habit")) {
    const auto habit = habitFromOptions(parser, &error);
    if (!habit.has_value()) {
      return printError(error);
    }
    if (!client.addHabit(*habit, &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("edit-habit")) {
    if (positional.size() < 2) {
      return printError(QStringLiteral("edit-habit requires a habit id"));
    }
    auto habit = habitFromOptions(parser, &error);
    if (!habit.has_value()) {
      return printError(error);
    }
    habit->id = positional.at(1);
    if (!client.editHabit(*habit, &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("record-habit")) {
    if (positional.size() < 2) {
      return printError(QStringLiteral("record-habit requires a habit id"));
    }
    const QDate date = parser.isSet(QStringLiteral("date"))
                           ? QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate)
                           : QDate::currentDate();
    if (!date.isValid()) {
      return printError(QStringLiteral("record-habit requires --date YYYY-MM-DD"));
    }
    std::optional<qint64> amount;
    if (parser.isSet(QStringLiteral("amount"))) {
      bool valid = false;
      const qint64 parsedAmount = parser.value(QStringLiteral("amount")).toLongLong(&valid);
      if (!valid) {
        return printError(QStringLiteral("--amount must be an integer"));
      }
      amount = parsedAmount;
    }
    if (!client.recordHabit(positional.at(1), date, amount, &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("undo-habit")) {
    if (positional.size() < 2) {
      return printError(QStringLiteral("undo-habit requires a habit id"));
    }
    const QDate date = parser.isSet(QStringLiteral("date"))
                           ? QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate)
                           : QDate::currentDate();
    if (!date.isValid() || !client.undoLastHabitEntry(positional.at(1), date, &error)) {
      return printError(error.isEmpty() ? QStringLiteral("undo-habit requires --date YYYY-MM-DD") : error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("delete-habit")) {
    if (positional.size() < 2) {
      return printError(QStringLiteral("delete-habit requires a habit id"));
    }
    if (!client.deleteHabit(positional.at(1), &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("add")) {
    const QDate date = QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate);
    const QTime time = QTime::fromString(parser.value(QStringLiteral("time")), QStringLiteral("HH:mm"));
    if (!date.isValid()) {
      return printError(QStringLiteral("add requires --date YYYY-MM-DD"));
    }
    if (parser.isSet(QStringLiteral("time")) && !time.isValid()) {
      return printError(QStringLiteral("--time requires HH:mm"));
    }
    const auto reminders = parseReminderMinutesBefore(parser.isSet(QStringLiteral("reminders"))
                                                          ? parser.value(QStringLiteral("reminders"))
                                                          : QStringLiteral("0"),
                                                      &error);
    if (!reminders.has_value()) {
      return printError(error);
    }
    if (!client.addTask(parser.value(QStringLiteral("title")), date, time, {}, *reminders,
                        parser.value(QStringLiteral("emoji")), &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("sync-status")) {
    const QJsonObject status = client.syncStatus(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson(status);
    return 0;
  }
  if (command == QStringLiteral("task-visibility")) {
    if (positional.size() == 1) {
      const QString taskVisibility = client.taskVisibility(&error);
      if (!error.isEmpty()) {
        return printError(error);
      }
      printJson({{QStringLiteral("ok"), true}, {QStringLiteral("taskVisibility"), taskVisibility}});
      return 0;
    }
    const QString taskVisibility = positional.at(1);
    if (!client.saveTaskVisibility(taskVisibility, &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}, {QStringLiteral("taskVisibility"), taskVisibility}});
    return 0;
  }
  if (command == QStringLiteral("sync-config")) {
    const QJsonObject configuration = client.syncConfiguration(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson(configuration);
    return 0;
  }
  if (command == QStringLiteral("configure-sync")) {
    const QString endpoint = parser.value(QStringLiteral("endpoint"));
    const QString token = parser.value(QStringLiteral("token"));
    if (endpoint.trimmed().isEmpty()) {
      return printError(QStringLiteral("configure-sync requires --endpoint"));
    }
    if (!client.saveSyncConfiguration(endpoint, token, !token.isEmpty(), &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("disable-sync")) {
    if (!client.saveSyncConfiguration({}, {}, true, &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("sync-now")) {
    if (!client.syncNow(&error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("holiday-status")) {
    const QJsonObject status = client.holidayStatus(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson(status);
    return 0;
  }
  if (command == QStringLiteral("holiday-preferences")) {
    const QJsonObject preferences = client.holidayPreferences(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson(preferences);
    return 0;
  }
  if (command == QStringLiteral("configure-holidays")) {
    QJsonObject preferences = client.holidayPreferences(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    if (parser.isSet(QStringLiteral("state"))) {
      preferences.insert(QStringLiteral("stateCode"), parser.value(QStringLiteral("state")));
    }
    if (parser.isSet(QStringLiteral("city"))) {
      preferences.insert(QStringLiteral("cityCode"), parser.value(QStringLiteral("city")));
    }
    const QList<QPair<QString, QString>> flags{
        {QStringLiteral("national"), QStringLiteral("includeNational")},
        {QStringLiteral("state-holidays"), QStringLiteral("includeState")},
        {QStringLiteral("municipal"), QStringLiteral("includeMunicipal")},
        {QStringLiteral("commemorative"), QStringLiteral("includeCommemorative")},
        {QStringLiteral("optional"), QStringLiteral("includeOptional")},
    };
    for (const auto &[option, field] : flags) {
      if (!parser.isSet(option)) {
        continue;
      }
      const QString value = parser.value(option).trimmed().toLower();
      if (value != QStringLiteral("on") && value != QStringLiteral("off")) {
        return printError(QStringLiteral("--%1 requires on or off").arg(option));
      }
      preferences.insert(field, value == QStringLiteral("on"));
    }
    if (!client.saveHolidayPreferences(preferences, &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("municipalities")) {
    const QString stateCode = parser.value(QStringLiteral("state"));
    if (stateCode.isEmpty()) {
      return printError(QStringLiteral("municipalities requires --state UF"));
    }
    const QJsonArray municipalities = client.municipalities(stateCode, &error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}, {QStringLiteral("municipalities"), municipalities}});
    return 0;
  }
  if (command == QStringLiteral("holidays")) {
    const QDate from = QDate::fromString(parser.value(QStringLiteral("from")), Qt::ISODate);
    const QDate to = QDate::fromString(parser.value(QStringLiteral("to")), Qt::ISODate);
    if (!from.isValid() || !to.isValid()) {
      return printError(QStringLiteral("holidays requires --from and --to in YYYY-MM-DD format"));
    }
    const QJsonObject holidays = client.holidays(from, to, &error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson(holidays);
    return 0;
  }
  if (command == QStringLiteral("refresh-holidays")) {
    if (!client.refreshHolidays(&error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("update-status")) {
    const QJsonObject status = client.updateStatus(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    printJson(status);
    return 0;
  }
  if (command == QStringLiteral("check-update")) {
    if (!client.checkForUpdate(&error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}});
    return 0;
  }
  if (command == QStringLiteral("update")) {
    if (!client.installUpdate(false, &error)) {
      return printError(error);
    }
    printJson({{QStringLiteral("ok"), true}, {QStringLiteral("status"), QStringLiteral("installing")}});
    return 0;
  }
  if (positional.size() < 2) {
    return printError(QStringLiteral("%1 requires a task id").arg(command));
  }

  const QString taskId = positional.at(1);
  bool succeeded = false;
  if (command == QStringLiteral("complete") || command == QStringLiteral("reopen")) {
    const bool completed = command == QStringLiteral("complete");
    const QDate occurrenceDate = QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate);
    succeeded = occurrenceDate.isValid()
                    ? client.setOccurrenceCompleted(taskId, occurrenceDate, completed, &error)
                    : client.setTaskCompleted(taskId, completed, &error);
  } else if (command == QStringLiteral("skip")) {
    const QDate occurrenceDate = QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate);
    if (!occurrenceDate.isValid()) {
      return printError(QStringLiteral("skip requires --date YYYY-MM-DD"));
    }
    succeeded = client.skipOccurrence(taskId, occurrenceDate, &error);
  } else if (command == QStringLiteral("edit")) {
    const QString title = parser.value(QStringLiteral("title")).trimmed();
    const QTime time = QTime::fromString(parser.value(QStringLiteral("time")), QStringLiteral("HH:mm"));
    const QString frequency = parser.value(QStringLiteral("frequency"));
    const QStringList frequencies{QStringLiteral("none"), QStringLiteral("daily"), QStringLiteral("weekly"),
                                  QStringLiteral("monthly"), QStringLiteral("yearly")};
    if (title.isEmpty() || !time.isValid()) {
      return printError(QStringLiteral("edit requires --title and --time HH:mm"));
    }
    if (!frequencies.contains(frequency)) {
      return printError(QStringLiteral("--frequency must be none, daily, weekly, monthly, or yearly"));
    }
    QJsonArray weekdays;
    const QStringList weekdayValues =
        parser.value(QStringLiteral("weekdays")).split(QLatin1Char(','), Qt::SkipEmptyParts);
    for (const QString &weekdayValue : weekdayValues) {
      bool validWeekday = false;
      const int weekday = weekdayValue.toInt(&validWeekday);
      if (!validWeekday || weekday < 1 || weekday > 7) {
        return printError(QStringLiteral("--weekdays must contain values from 1 through 7"));
      }
      weekdays.append(weekday);
    }
    const waypoint::RecurrenceRule recurrence = waypoint::RecurrenceRule::fromJson(
        {{QStringLiteral("frequency"), frequency},
         {QStringLiteral("interval"), parser.value(QStringLiteral("interval")).toInt()},
         {QStringLiteral("weekdays"), weekdays},
         {QStringLiteral("endMode"), parser.value(QStringLiteral("end-mode"))},
         {QStringLiteral("untilDate"), parser.value(QStringLiteral("until"))},
         {QStringLiteral("occurrenceCount"), parser.value(QStringLiteral("count")).toInt()}});
    std::optional<QList<int>> reminders;
    if (parser.isSet(QStringLiteral("reminders"))) {
      const auto parsedReminders =
          parseReminderMinutesBefore(parser.value(QStringLiteral("reminders")), &error);
      if (!parsedReminders.has_value()) {
        return printError(error);
      }
      reminders = *parsedReminders;
    }
    succeeded = client.editTask(taskId, title, time, recurrence, reminders,
                                parser.value(QStringLiteral("emoji")), &error);
  } else if (command == QStringLiteral("reschedule")) {
    const QDate date = QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate);
    const QTime time = QTime::fromString(parser.value(QStringLiteral("time")), QStringLiteral("HH:mm"));
    if (!date.isValid() || !time.isValid()) {
      return printError(QStringLiteral("reschedule requires --date YYYY-MM-DD and --time HH:mm"));
    }
    succeeded = client.rescheduleTask(taskId, date, time, &error);
  } else if (command == QStringLiteral("delete")) {
    succeeded = client.deleteTask(taskId, &error);
  } else {
    return printError(QStringLiteral("Unknown command: %1").arg(command));
  }

  if (!succeeded) {
    return printError(error);
  }
  printJson({{QStringLiteral("ok"), true}});
  return 0;
}

#include "ipc/WaypointIpcClient.hpp"

#include <QCommandLineParser>
#include <QCoreApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <cstdio>

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

} // namespace

int main(int argc, char *argv[]) {
  QCoreApplication application(argc, argv);
  QCoreApplication::setApplicationName(QStringLiteral("waypointctl"));
  QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));

  QCommandLineParser parser;
  parser.setApplicationDescription(QStringLiteral("Local command line client for Waypoint"));
  parser.addHelpOption();
  parser.addVersionOption();
  parser.addPositionalArgument(
      QStringLiteral("command"),
      QStringLiteral("ping, snapshot, add, complete, reopen, reschedule, delete, sync-status, "
                     "sync-config, configure-sync, disable-sync, sync-now, holiday-status, "
                     "holiday-preferences, configure-holidays, municipalities, holidays, or "
                     "refresh-holidays"));
  parser.addPositionalArgument(QStringLiteral("arguments"), QStringLiteral("Command arguments"),
                               QStringLiteral("[arguments...]"));
  parser.addOption({{QStringLiteral("t"), QStringLiteral("title")},
                    QStringLiteral("Task title"),
                    QStringLiteral("title")});
  parser.addOption({{QStringLiteral("d"), QStringLiteral("date")},
                    QStringLiteral("Scheduled date in YYYY-MM-DD format"),
                    QStringLiteral("date")});
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
    const QList<waypoint::TaskRecord> tasks = client.listTasks(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    QJsonArray values;
    for (const waypoint::TaskRecord &task : tasks) {
      values.append(task.toJson());
    }
    const QJsonObject sync = client.syncStatus(&error);
    if (!error.isEmpty()) {
      return printError(error);
    }
    const QDate today = QDate::currentDate();
    const QJsonObject holidayData =
        client.holidays(QDate(today.year() - 1, 1, 1), QDate(today.year() + 1, 12, 31), &error);
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
    printJson({{QStringLiteral("ok"), true},
               {QStringLiteral("tasks"), values},
               {QStringLiteral("sync"), sync},
               {QStringLiteral("holidays"), holidayData.value(QStringLiteral("holidays"))},
               {QStringLiteral("holidayCoverage"), holidayData.value(QStringLiteral("coverage"))},
               {QStringLiteral("holidayPreferences"), holidayPreferences},
               {QStringLiteral("holidaySync"), holidayStatus}});
    return 0;
  }
  if (command == QStringLiteral("add")) {
    const QDate date = QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate);
    if (!date.isValid()) {
      return printError(QStringLiteral("add requires --date YYYY-MM-DD"));
    }
    if (!client.addTask(parser.value(QStringLiteral("title")), date, &error)) {
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
  if (positional.size() < 2) {
    return printError(QStringLiteral("%1 requires a task id").arg(command));
  }

  const QString taskId = positional.at(1);
  bool succeeded = false;
  if (command == QStringLiteral("complete")) {
    succeeded = client.setTaskCompleted(taskId, true, &error);
  } else if (command == QStringLiteral("reopen")) {
    succeeded = client.setTaskCompleted(taskId, false, &error);
  } else if (command == QStringLiteral("reschedule")) {
    const QDate date = QDate::fromString(parser.value(QStringLiteral("date")), Qt::ISODate);
    if (!date.isValid()) {
      return printError(QStringLiteral("reschedule requires --date YYYY-MM-DD"));
    }
    succeeded = client.rescheduleTask(taskId, date, &error);
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

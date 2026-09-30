#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QScopeGuard>
#include <QTemporaryDir>
#include <QtTest>

class CliCreationTest final : public QObject {
  Q_OBJECT

private slots:
  void createRecurringTaskAndRejectInvalidWeekdays() {
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    // QLocalServer resolves its relative socket name through TMPDIR, not XDG_RUNTIME_DIR.
    environment.insert(QStringLiteral("TMPDIR"), directory.path());
    environment.insert(QStringLiteral("WAYPOINT_DATA_DIR"), directory.path());
    QProcess daemon;
    daemon.setProcessEnvironment(environment);
    daemon.setProcessChannelMode(QProcess::MergedChannels);
    daemon.start(QString::fromUtf8(WAYPOINT_DAEMON_PATH), {});
    const auto stopDaemon = qScopeGuard([&daemon] {
      daemon.terminate();
      if (!daemon.waitForFinished(3000)) {
        daemon.kill();
        daemon.waitForFinished();
      }
    });
    QVERIFY(daemon.waitForStarted());
    QByteArray log;
    QElapsedTimer startup;
    startup.start();
    while (!log.contains("Waypoint daemon is ready") && startup.elapsed() < 5000) {
      daemon.waitForReadyRead(100);
      log += daemon.readAll();
    }
    QVERIFY2(log.contains("Waypoint daemon is ready"), log.constData());

    QProcess cli;
    cli.setProcessEnvironment(environment);
    const QStringList options{
        QStringLiteral("add"),         QStringLiteral("--title"),     QStringLiteral("Weekly planning"),
        QStringLiteral("--date"),      QStringLiteral("2026-10-05"),  QStringLiteral("--time"),
        QStringLiteral("09:30"),       QStringLiteral("--reminders"), QStringLiteral("none"),
        QStringLiteral("--frequency"), QStringLiteral("weekly"),      QStringLiteral("--end-mode"),
        QStringLiteral("afterCount"),  QStringLiteral("--count"),     QStringLiteral("3"),
        QStringLiteral("--weekdays")};
    cli.start(QString::fromUtf8(WAYPOINT_CLI_PATH), options + QStringList{QStringLiteral("1,8")});
    QVERIFY(cli.waitForFinished());
    QCOMPARE(cli.exitCode(), 1);
    QVERIFY(cli.readAllStandardError().contains("--weekdays"));
    cli.start(QString::fromUtf8(WAYPOINT_CLI_PATH), options + QStringList{QStringLiteral("1,3")});
    QVERIFY(cli.waitForFinished());
    QCOMPARE(cli.exitCode(), 0);
    cli.start(QString::fromUtf8(WAYPOINT_CLI_PATH),
              {QStringLiteral("snapshot"), QStringLiteral("--from"), QStringLiteral("2026-10-01"),
               QStringLiteral("--to"), QStringLiteral("2026-10-31")});
    QVERIFY(cli.waitForFinished());
    QCOMPARE(cli.exitCode(), 0);
    const QJsonArray occurrences = QJsonDocument::fromJson(cli.readAllStandardOutput())
                                       .object()
                                       .value(QStringLiteral("occurrences"))
                                       .toArray();
    QStringList dates;
    for (const QJsonValue &value : occurrences) {
      const QJsonObject task = value.toObject();
      QCOMPARE(task.value(QStringLiteral("title")).toString(), QStringLiteral("Weekly planning"));
      QCOMPARE(task.value(QStringLiteral("scheduledTime")).toString(), QStringLiteral("09:30"));
      QVERIFY(task.value(QStringLiteral("recurring")).toBool());
      dates.append(task.value(QStringLiteral("occurrenceDate")).toString());
    }
    QCOMPARE(dates, (QStringList{QStringLiteral("2026-10-05"), QStringLiteral("2026-10-07"),
                                 QStringLiteral("2026-10-12")}));
  }
};

QTEST_GUILESS_MAIN(CliCreationTest)
#include "CliCreationTest.moc"

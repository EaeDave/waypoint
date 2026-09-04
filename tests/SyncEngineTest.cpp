#include "sync/SyncEngine.hpp"
#include "core/TaskStore.hpp"
#include "sync/HolidaySyncEngine.hpp"
#include "sync/SyncProtocol.hpp"

#include <QHostAddress>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QtTest>

class SyncEngineTest final : public QObject {
  Q_OBJECT

private slots:
  void normalizeAndPersistServerUrl();
  void rejectUnsafeServerUrl();
  void preserveExistingTokenWhenRequested();
  void synchronizeTaskVisibilityCompatibly();
  void syncsImmediatelyWhenEventArrives();
  void preserveHolidayPreferencesWithoutServer();
  void downloadNewerHolidayPreferences();
};

void SyncEngineTest::normalizeAndPersistServerUrl() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  waypoint::SyncEngine engine(&store);

  QVERIFY2(engine.updateConfiguration(QStringLiteral("https://waypoint.example"), QByteArrayLiteral("token"),
                                      true, &error),
           qPrintable(error));
  QCOMPARE(engine.publicConfiguration().value(QStringLiteral("endpoint")).toString(),
           QStringLiteral("https://waypoint.example/v1/sync"));
  QVERIFY(engine.enabled());

  QVERIFY2(engine.updateConfiguration({}, {}, true, &error), qPrintable(error));
}

void SyncEngineTest::rejectUnsafeServerUrl() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  waypoint::SyncEngine engine(&store);

  QVERIFY(!engine.updateConfiguration(QStringLiteral("ftp://waypoint.example"), QByteArrayLiteral("token"),
                                      true, &error));
  QVERIFY(error.contains(QStringLiteral("HTTP or HTTPS")));
  QVERIFY(!engine.enabled());
}

void SyncEngineTest::preserveExistingTokenWhenRequested() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  waypoint::SyncEngine engine(&store);

  QVERIFY2(engine.updateConfiguration(QStringLiteral("https://one.example"), QByteArrayLiteral("token"), true,
                                      &error),
           qPrintable(error));
  QVERIFY2(engine.updateConfiguration(QStringLiteral("https://two.example"), {}, false, &error),
           qPrintable(error));

  const waypoint::SyncConfiguration stored = store.syncConfiguration(&error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(stored.endpoint, QUrl(QStringLiteral("https://two.example/v1/sync")));
  QCOMPARE(stored.token, QByteArrayLiteral("token"));

  QVERIFY2(engine.updateConfiguration({}, {}, true, &error), qPrintable(error));
}

void SyncEngineTest::syncsImmediatelyWhenEventArrives() {
  QTcpServer server;
  QVERIFY(server.listen(QHostAddress::LocalHost));

  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  const waypoint::SyncConfiguration configuration{
      QUrl(QStringLiteral("http://127.0.0.1:%1/v1/sync").arg(server.serverPort())),
      QByteArrayLiteral("token"),
  };
  QVERIFY2(store.saveSyncConfiguration(configuration, &error), qPrintable(error));

  waypoint::SyncEngine engine(&store);
  engine.start();

  QTcpSocket *eventSocket = nullptr;
  int syncRequests = 0;
  const QByteArray syncBody = QByteArrayLiteral(R"({"nextCursor":0,"acceptedMutationIds":[],"changes":[]})");
  const QByteArray syncResponse =
      QByteArrayLiteral(
          "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: ") +
      QByteArray::number(syncBody.size()) + QByteArrayLiteral("\r\n\r\n") + syncBody;

  for (int requestIndex = 0; requestIndex < 2; ++requestIndex) {
    QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 2000);
    QTcpSocket *socket = server.nextPendingConnection();
    QVERIFY(socket != nullptr);
    QTRY_VERIFY_WITH_TIMEOUT(socket->bytesAvailable() > 0, 2000);
    const QByteArray request = socket->readAll();
    QVERIFY2(request.toLower().contains("authorization: bearer token"), request.constData());
    if (request.startsWith("GET /v1/events ")) {
      eventSocket = socket;
      const QByteArray headers = QByteArrayLiteral(
          "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\n"
          "Connection: keep-alive\r\n\r\n");
      QCOMPARE(socket->write(headers), headers.size());
      QVERIFY(socket->flush());
    } else {
      QVERIFY2(request.startsWith("POST /v1/sync "), request.constData());
      ++syncRequests;
      QCOMPARE(socket->write(syncResponse), syncResponse.size());
      QVERIFY(socket->flush());
    }
  }
  QVERIFY(eventSocket != nullptr);
  QCOMPARE(syncRequests, 1);

  const QByteArray event = QByteArrayLiteral("event: sync-needed\ndata: {\"sequence\":1}\n\n");
  QCOMPARE(eventSocket->write(event), event.size());
  QVERIFY(eventSocket->flush());

  QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 2000);
  QTcpSocket *triggeredSocket = server.nextPendingConnection();
  QVERIFY(triggeredSocket != nullptr);
  QTRY_VERIFY_WITH_TIMEOUT(triggeredSocket->bytesAvailable() > 0, 2000);
  const QByteArray triggeredRequest = triggeredSocket->readAll();
  QVERIFY2(triggeredRequest.startsWith("POST /v1/sync "), triggeredRequest.constData());
  QCOMPARE(triggeredSocket->write(syncResponse), syncResponse.size());
  QVERIFY(triggeredSocket->flush());
}

void SyncEngineTest::preserveHolidayPreferencesWithoutServer() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  waypoint::HolidaySyncEngine engine(&store);

  const QJsonObject preferences{
      {QStringLiteral("stateCode"), QStringLiteral("MG")},
      {QStringLiteral("cityCode"), QStringLiteral("3106200")},
      {QStringLiteral("includeNational"), true},
      {QStringLiteral("includeState"), true},
      {QStringLiteral("includeMunicipal"), true},
      {QStringLiteral("includeCommemorative"), true},
  };
  QVERIFY2(engine.updatePreferences(preferences, &error), qPrintable(error));
  QCOMPARE(engine.status().value(QStringLiteral("state")).toString(), QStringLiteral("local-only"));
  QCOMPARE(store.holidayPreferences(&error).value(QStringLiteral("cityCode")).toString(),
           QStringLiteral("3106200"));
}

void SyncEngineTest::downloadNewerHolidayPreferences() {
  QTcpServer server;
  QVERIFY(server.listen(QHostAddress::LocalHost));

  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  const QString endpoint = QStringLiteral("http://127.0.0.1:%1").arg(server.serverPort());
  const waypoint::SyncConfiguration configuration{
      QUrl(endpoint + QStringLiteral("/v1/sync")),
      QByteArrayLiteral("token"),
  };
  QVERIFY2(store.saveSyncConfiguration(configuration, &error), qPrintable(error));

  waypoint::HolidaySyncEngine holidayEngine(&store);
  holidayEngine.start();
  QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 2000);
  QTcpSocket *socket = server.nextPendingConnection();
  QVERIFY(socket != nullptr);
  QTRY_VERIFY_WITH_TIMEOUT(socket->bytesAvailable() > 0, 2000);
  const QByteArray request = socket->readAll();
  QVERIFY2(request.startsWith("GET /v1/holiday-preferences "), request.constData());

  const QByteArray body = QByteArrayLiteral(
      R"({"stateCode":"RJ","cityCode":"3302403","includeNational":true,"includeState":true,"includeMunicipal":true,"includeCommemorative":false,"includeOptional":true,"revision":7,"updatedAt":"2026-02-01T12:00:00.000Z"})");
  const QByteArray response =
      QByteArrayLiteral(
          "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: ") +
      QByteArray::number(body.size()) + QByteArrayLiteral("\r\n\r\n") + body;
  QCOMPARE(socket->write(response), response.size());
  QVERIFY(socket->flush());

  QTRY_COMPARE_WITH_TIMEOUT(store.holidayPreferences(&error).value(QStringLiteral("stateCode")).toString(),
                            QStringLiteral("RJ"), 2000);
  const QJsonObject applied = store.holidayPreferences(&error);
  QCOMPARE(applied.value(QStringLiteral("cityCode")).toString(), QStringLiteral("3302403"));
  QCOMPARE(applied.value(QStringLiteral("revision")).toInteger(), 7);
}

void SyncEngineTest::synchronizeTaskVisibilityCompatibly() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  QVERIFY2(store.setTaskVisibilityMode(waypoint::TaskVisibilityMode::Pending, &error), qPrintable(error));

  const QJsonObject request = waypoint::buildSyncRequest(store, QStringLiteral("test-device"), &error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  const QJsonObject mutation = request.value(QStringLiteral("preferenceMutation")).toObject();
  QCOMPARE(mutation.value(QStringLiteral("taskVisibility")).toString(), QStringLiteral("pending"));

  const QJsonObject legacyResponse{
      {QStringLiteral("nextCursor"), 0},
      {QStringLiteral("acceptedMutationIds"), QJsonArray{}},
      {QStringLiteral("changes"), QJsonArray{}},
  };
  QVERIFY2(waypoint::applySyncResponse(store, legacyResponse, &error), qPrintable(error));
  QVERIFY(!store.pendingUserPreferencesMutation(&error).isEmpty());

  const QJsonObject synchronizedResponse{
      {QStringLiteral("nextCursor"), 0},
      {QStringLiteral("acceptedMutationIds"), QJsonArray{}},
      {QStringLiteral("acceptedPreferenceMutationId"),
       mutation.value(QStringLiteral("mutationId")).toString()},
      {QStringLiteral("changes"), QJsonArray{}},
      {QStringLiteral("preferences"),
       QJsonObject{{QStringLiteral("taskVisibility"), QStringLiteral("pending")},
                   {QStringLiteral("revision"), 3},
                   {QStringLiteral("updatedAt"), QStringLiteral("2026-09-01T12:00:00.000Z")}}},
  };
  QVERIFY2(waypoint::applySyncResponse(store, synchronizedResponse, &error), qPrintable(error));
  QVERIFY(store.pendingUserPreferencesMutation(&error).isEmpty());
  QCOMPARE(store.taskVisibilityMode(&error), waypoint::TaskVisibilityMode::Pending);
}

QTEST_MAIN(SyncEngineTest)
#include "SyncEngineTest.moc"

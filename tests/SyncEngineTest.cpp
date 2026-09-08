#include "sync/SyncEngine.hpp"
#include "core/TaskStore.hpp"
#include "sync/HolidaySyncEngine.hpp"
#include "sync/SyncProtocol.hpp"

#include <QHostAddress>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QtTest>
namespace {

bool appendCompleteHttpRequest(QTcpSocket *socket, QByteArray *request) {
  request->append(socket->readAll());
  const qsizetype headerEnd = request->indexOf(QByteArrayLiteral("\r\n\r\n"));
  if (headerEnd < 0) {
    return false;
  }

  qint64 contentLength = 0;
  const QList<QByteArray> headerLines = request->left(headerEnd).split('\n');
  for (const QByteArray &rawLine : headerLines) {
    const QByteArray line = rawLine.trimmed();
    if (!line.toLower().startsWith(QByteArrayLiteral("content-length:"))) {
      continue;
    }
    bool converted = false;
    contentLength =
        line.sliced(sizeof("content-length:") - 1).trimmed().toLongLong(&converted);
    if (!converted || contentLength < 0) {
      return false;
    }
    break;
  }
  return request->size() >= headerEnd + 4 + contentLength;
}

} // namespace

class SyncEngineTest final : public QObject {
  Q_OBJECT

private slots:
  void normalizeAndPersistServerUrl();
  void rejectUnsafeServerUrl();
  void preserveExistingTokenWhenRequested();
  void synchronizeTaskVisibilityCompatibly();
  void negotiateCategorySyncCapabilities();
  void renegotiateBeforeUploadingCategories();
  void discardSyncReplyAfterEndpointChange();
  void syncsImmediatelyWhenEventArrives();
  void recoversWhenSyncRequestStopsTransferring();
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

void SyncEngineTest::recoversWhenSyncRequestStopsTransferring() {
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

  waypoint::SyncEngine engine(&store, nullptr, 100);
  engine.start();

  QList<QTcpSocket *> sockets;
  for (int requestIndex = 0; requestIndex < 2; ++requestIndex) {
    QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 2000);
    QTcpSocket *socket = server.nextPendingConnection();
    QVERIFY(socket != nullptr);
    sockets.append(socket);
    QTRY_VERIFY_WITH_TIMEOUT(socket->bytesAvailable() > 0, 2000);
  }

  QTRY_COMPARE_WITH_TIMEOUT(engine.status().value(QStringLiteral("state")).toString(),
                            QStringLiteral("error"), 2000);
  QVERIFY(!engine.status().value(QStringLiteral("lastError")).toString().isEmpty());

  engine.syncNow();
  QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 2000);
  QTcpSocket *retrySocket = server.nextPendingConnection();
  QVERIFY(retrySocket != nullptr);
  sockets.append(retrySocket);
  QTRY_VERIFY_WITH_TIMEOUT(retrySocket->bytesAvailable() > 0, 2000);
  QVERIFY2(retrySocket->readAll().startsWith("POST /v1/sync "), "Synchronization did not retry");
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

  const QJsonObject request =
      waypoint::buildSyncRequest(store, QStringLiteral("test-device"), false, &error);
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

void SyncEngineTest::negotiateCategorySyncCapabilities() {
  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  QVERIFY2(store.createTaskCategory(QStringLiteral("Work"), QStringLiteral("#3B82F6"), nullptr, &error),
           qPrintable(error));

  QJsonObject request =
      waypoint::buildSyncRequest(store, QStringLiteral("test-device"), false, &error);
  QVERIFY2(error.isEmpty(), qPrintable(error));
  QCOMPARE(request.value(QStringLiteral("supportedEntityTypes")).toArray().last().toString(),
           QStringLiteral("category"));
  QVERIFY(request.value(QStringLiteral("mutations")).toArray().isEmpty());

  const QJsonObject legacyResponse{
      {QStringLiteral("nextCursor"), 0},
      {QStringLiteral("acceptedMutationIds"), QJsonArray{}},
      {QStringLiteral("changes"), QJsonArray{}},
  };
  QVERIFY2(waypoint::applySyncResponse(store, legacyResponse, &error), qPrintable(error));
  request = waypoint::buildSyncRequest(store, QStringLiteral("test-device"), false, &error);
  QVERIFY(request.value(QStringLiteral("mutations")).toArray().isEmpty());

  QJsonObject malformedResponse = legacyResponse;
  malformedResponse.insert(QStringLiteral("supportedEntityTypes"),
                           QStringLiteral("category"));
  QVERIFY(!waypoint::applySyncResponse(store, malformedResponse, &error));
  QVERIFY(error.contains(QStringLiteral("capabilities")));
  error.clear();

  QJsonArray supported{
      QStringLiteral("task"),
      QStringLiteral("occurrence"),
      QStringLiteral("habit"),
      QStringLiteral("habit-entry"),
      QStringLiteral("category"),
  };
  QJsonObject currentResponse = legacyResponse;
  currentResponse.insert(QStringLiteral("supportedEntityTypes"), supported);
  QVERIFY2(waypoint::applySyncResponse(store, currentResponse, &error), qPrintable(error));
  request = waypoint::buildSyncRequest(store, QStringLiteral("test-device"), true, &error);
  const QJsonArray mutations = request.value(QStringLiteral("mutations")).toArray();
  QCOMPARE(mutations.size(), 1);
  QCOMPARE(mutations.first().toObject().value(QStringLiteral("entityType")).toString(),
           QStringLiteral("category"));
}

void SyncEngineTest::renegotiateBeforeUploadingCategories() {
  QTcpServer server;
  QVERIFY(server.listen(QHostAddress::LocalHost));

  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  QVERIFY2(store.createTaskCategory(QStringLiteral("Work"), QStringLiteral("#3B82F6"),
                                    nullptr, &error),
           qPrintable(error));
  QVERIFY2(store.saveServerSupportedEntityTypes(
               {QStringLiteral("task"), QStringLiteral("occurrence"),
                QStringLiteral("habit"), QStringLiteral("habit-entry"),
                QStringLiteral("category")},
               &error),
           qPrintable(error));
  const waypoint::SyncConfiguration configuration{
      QUrl(QStringLiteral("http://127.0.0.1:%1/v1/sync").arg(server.serverPort())),
      QByteArrayLiteral("token"),
  };
  QVERIFY2(store.saveSyncConfiguration(configuration, &error), qPrintable(error));

  waypoint::SyncEngine engine(&store);
  engine.start();

  const QByteArray body = QByteArrayLiteral(
      R"({"nextCursor":0,"acceptedMutationIds":[],"changes":[],"supportedEntityTypes":["task","occurrence","habit","habit-entry","category"]})");
  const QByteArray response =
      QByteArrayLiteral(
          "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: ") +
      QByteArray::number(body.size()) + QByteArrayLiteral("\r\n\r\n") + body;

  QTcpSocket *eventSocket = nullptr;
  QByteArray firstSyncRequest;
  for (int requestIndex = 0; requestIndex < 2; ++requestIndex) {
    QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 2000);
    QTcpSocket *socket = server.nextPendingConnection();
    QVERIFY(socket != nullptr);
    QByteArray request;
    QTRY_VERIFY_WITH_TIMEOUT(appendCompleteHttpRequest(socket, &request), 2000);
    if (request.startsWith("GET /v1/events ")) {
      eventSocket = socket;
      const QByteArray headers = QByteArrayLiteral(
          "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\n"
          "Connection: keep-alive\r\n\r\n");
      QCOMPARE(socket->write(headers), headers.size());
      QVERIFY(socket->flush());
    } else {
      firstSyncRequest = request;
      QCOMPARE(socket->write(response), response.size());
      QVERIFY(socket->flush());
    }
  }
  QVERIFY(eventSocket != nullptr);
  QVERIFY2(!firstSyncRequest.contains("\"entityType\":\"category\""),
           firstSyncRequest.constData());

  QTRY_VERIFY_WITH_TIMEOUT(server.hasPendingConnections(), 2000);
  QTcpSocket *followUp = server.nextPendingConnection();
  QVERIFY(followUp != nullptr);
  QByteArray followUpRequest;
  QTRY_VERIFY_WITH_TIMEOUT(
      appendCompleteHttpRequest(followUp, &followUpRequest), 2000);
  QVERIFY2(followUpRequest.startsWith("POST /v1/sync "), followUpRequest.constData());
  QVERIFY2(followUpRequest.contains("\"entityType\":\"category\""),
           followUpRequest.constData());
  QCOMPARE(followUp->write(response), response.size());
  QVERIFY(followUp->flush());
}

void SyncEngineTest::discardSyncReplyAfterEndpointChange() {
  QTcpServer oldServer;
  QTcpServer newServer;
  QVERIFY(oldServer.listen(QHostAddress::LocalHost));
  QVERIFY(newServer.listen(QHostAddress::LocalHost));

  QTemporaryDir directory;
  waypoint::TaskStore store(directory.filePath(QStringLiteral("tasks.sqlite3")));
  QString error;
  QVERIFY2(store.open(&error), qPrintable(error));
  QVERIFY2(store.createTaskCategory(QStringLiteral("Work"), QStringLiteral("#3B82F6"),
                                    nullptr, &error),
           qPrintable(error));
  const waypoint::SyncConfiguration oldConfiguration{
      QUrl(QStringLiteral("http://127.0.0.1:%1/v1/sync")
               .arg(oldServer.serverPort())),
      QByteArrayLiteral("old-token"),
  };
  QVERIFY2(store.saveSyncConfiguration(oldConfiguration, &error),
           qPrintable(error));

  waypoint::SyncEngine engine(&store);
  engine.start();

  const QByteArray eventHeaders = QByteArrayLiteral(
      "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n"
      "Cache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n");
  QTcpSocket *oldSyncSocket = nullptr;
  for (int requestIndex = 0; requestIndex < 2; ++requestIndex) {
    QTRY_VERIFY_WITH_TIMEOUT(oldServer.hasPendingConnections(), 2000);
    QTcpSocket *socket = oldServer.nextPendingConnection();
    QVERIFY(socket != nullptr);
    QByteArray request;
    QTRY_VERIFY_WITH_TIMEOUT(
        appendCompleteHttpRequest(socket, &request), 2000);
    if (request.startsWith("GET /v1/events ")) {
      QCOMPARE(socket->write(eventHeaders), eventHeaders.size());
      QVERIFY(socket->flush());
    } else {
      QVERIFY2(request.startsWith("POST /v1/sync "), request.constData());
      oldSyncSocket = socket;
    }
  }
  QVERIFY(oldSyncSocket != nullptr);

  QVERIFY2(
      engine.updateConfiguration(
          QStringLiteral("http://127.0.0.1:%1/v1/sync")
              .arg(newServer.serverPort()),
          QByteArrayLiteral("new-token"), true, &error),
      qPrintable(error));

  const QByteArray capabilityBody = QByteArrayLiteral(
      R"({"nextCursor":0,"acceptedMutationIds":[],"changes":[],"supportedEntityTypes":["task","occurrence","habit","habit-entry","category"]})");
  const QByteArray staleResponse =
      QByteArrayLiteral(
          "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
          "Connection: close\r\nContent-Length: ") +
      QByteArray::number(capabilityBody.size()) +
      QByteArrayLiteral("\r\n\r\n") + capabilityBody;
  oldSyncSocket->write(staleResponse);
  oldSyncSocket->flush();

  const QByteArray legacyBody = QByteArrayLiteral(
      R"({"nextCursor":0,"acceptedMutationIds":[],"changes":[]})");
  const QByteArray legacyResponse =
      QByteArrayLiteral(
          "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
          "Connection: close\r\nContent-Length: ") +
      QByteArray::number(legacyBody.size()) +
      QByteArrayLiteral("\r\n\r\n") + legacyBody;
  QByteArray newSyncRequest;
  for (int requestIndex = 0; requestIndex < 2; ++requestIndex) {
    QTRY_VERIFY_WITH_TIMEOUT(newServer.hasPendingConnections(), 2000);
    QTcpSocket *socket = newServer.nextPendingConnection();
    QVERIFY(socket != nullptr);
    QByteArray request;
    QTRY_VERIFY_WITH_TIMEOUT(
        appendCompleteHttpRequest(socket, &request), 2000);
    if (request.startsWith("GET /v1/events ")) {
      QCOMPARE(socket->write(eventHeaders), eventHeaders.size());
      QVERIFY(socket->flush());
    } else {
      newSyncRequest = request;
      QCOMPARE(socket->write(legacyResponse), legacyResponse.size());
      QVERIFY(socket->flush());
    }
  }

  QVERIFY2(newSyncRequest.startsWith("POST /v1/sync "),
           newSyncRequest.constData());
  QVERIFY2(!newSyncRequest.contains("\"entityType\":\"category\""),
           newSyncRequest.constData());
}


QTEST_MAIN(SyncEngineTest)
#include "SyncEngineTest.moc"

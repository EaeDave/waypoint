#include "sync/SyncEngine.hpp"
#include "core/TaskStore.hpp"

#include <QTemporaryDir>
#include <QtTest>

class SyncEngineTest final : public QObject {
  Q_OBJECT

private slots:
  void normalizeAndPersistServerUrl();
  void rejectUnsafeServerUrl();
  void preserveExistingTokenWhenRequested();
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

QTEST_MAIN(SyncEngineTest)
#include "SyncEngineTest.moc"

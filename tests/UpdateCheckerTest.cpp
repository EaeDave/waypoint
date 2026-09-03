#include "update/UpdateChecker.hpp"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtTest>

namespace {

QByteArray releasePayload(const QString &version, const QString &assetName, const QString &assetUrl,
                          const bool prerelease = false) {
  const QString base =
      QStringLiteral("https://github.com/EaeDave/waypoint/releases/download/v%1/").arg(version);
  const QJsonArray assets{
      QJsonObject{{QStringLiteral("name"), assetName}, {QStringLiteral("browser_download_url"), assetUrl}},
      QJsonObject{{QStringLiteral("name"), QStringLiteral("SHA256SUMS")},
                  {QStringLiteral("browser_download_url"), base + QStringLiteral("SHA256SUMS")}}};
  return QJsonDocument(QJsonObject{{QStringLiteral("tag_name"), QStringLiteral("v") + version},
                                   {QStringLiteral("draft"), false},
                                   {QStringLiteral("prerelease"), prerelease},
                                   {QStringLiteral("assets"), assets}})
      .toJson(QJsonDocument::Compact);
}

} // namespace

class UpdateCheckerTest final : public QObject {
  Q_OBJECT

private slots:
  void compareSemanticVersions();
  void parseTrustedLinuxRelease();
  void parseTrustedAndroidRelease();
  void rejectUntrustedReleaseMetadata();
};

void UpdateCheckerTest::compareSemanticVersions() {
  QVERIFY(waypoint::isNewerVersion(QStringLiteral("1.2.4"), QStringLiteral("1.2.3")));
  QVERIFY(waypoint::isNewerVersion(QStringLiteral("1.3.0"), QStringLiteral("1.2.99")));
  QVERIFY(waypoint::isNewerVersion(QStringLiteral("2.0.0"), QStringLiteral("1.99.99")));
  QVERIFY(!waypoint::isNewerVersion(QStringLiteral("1.2.3"), QStringLiteral("1.2.3")));
  QVERIFY(!waypoint::isNewerVersion(QStringLiteral("1.2.2"), QStringLiteral("1.2.3")));
  QVERIFY(!waypoint::isNewerVersion(QStringLiteral("1.02.4"), QStringLiteral("1.2.3")));
  QVERIFY(!waypoint::isNewerVersion(QStringLiteral("latest"), QStringLiteral("1.2.3")));
}

void UpdateCheckerTest::parseTrustedLinuxRelease() {
  const QString version = QStringLiteral("1.4.2");
  const QString url = QStringLiteral(
      "https://github.com/EaeDave/waypoint/releases/download/v1.4.2/waypoint-linux-x86_64.tar.gz");
  waypoint::ReleaseInfo release;
  QString error;

  QVERIFY(waypoint::parseLatestRelease(
      releasePayload(version, QStringLiteral("waypoint-linux-x86_64.tar.gz"), url),
      waypoint::UpdateAsset::LinuxX86_64, &release, &error));
  QCOMPARE(release.version, version);
  QCOMPARE(release.downloadUrl, QUrl(url));
  QCOMPARE(release.checksumsUrl,
           QUrl(QStringLiteral("https://github.com/EaeDave/waypoint/releases/download/v1.4.2/SHA256SUMS")));
  QVERIFY(error.isEmpty());
}

void UpdateCheckerTest::parseTrustedAndroidRelease() {
  const QString version = QStringLiteral("3.0.1");
  const QString url = QStringLiteral(
      "https://github.com/EaeDave/waypoint/releases/download/v3.0.1/waypoint-android-arm64.apk");
  waypoint::ReleaseInfo release;

  QVERIFY(
      waypoint::parseLatestRelease(releasePayload(version, QStringLiteral("waypoint-android-arm64.apk"), url),
                                   waypoint::UpdateAsset::AndroidArm64, &release));
  QCOMPARE(release.downloadUrl, QUrl(url));
}

void UpdateCheckerTest::rejectUntrustedReleaseMetadata() {
  const QString version = QStringLiteral("1.4.2");
  const QString trustedUrl = QStringLiteral(
      "https://github.com/EaeDave/waypoint/releases/download/v1.4.2/waypoint-linux-x86_64.tar.gz");
  waypoint::ReleaseInfo release;

  QVERIFY(!waypoint::parseLatestRelease(
      releasePayload(version, QStringLiteral("waypoint-linux-x86_64.tar.gz"), trustedUrl, true),
      waypoint::UpdateAsset::LinuxX86_64, &release));
  QVERIFY(!waypoint::parseLatestRelease(
      releasePayload(version, QStringLiteral("waypoint-linux-x86_64.tar.gz"),
                     QStringLiteral("https://example.com/waypoint-linux-x86_64.tar.gz")),
      waypoint::UpdateAsset::LinuxX86_64, &release));
  QVERIFY(
      !waypoint::parseLatestRelease(releasePayload(version, QStringLiteral("waypoint-linux-x86_64.tar.gz"),
                                                   trustedUrl + QStringLiteral("?token=1")),
                                    waypoint::UpdateAsset::LinuxX86_64, &release));
}

QTEST_APPLESS_MAIN(UpdateCheckerTest)

#include "UpdateCheckerTest.moc"

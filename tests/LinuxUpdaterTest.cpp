#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QTemporaryDir>
#include <QtTest>

namespace {

constexpr auto releaseVersion = "9.9.9";

bool writeFile(const QString &path, const QByteArray &contents, const bool executable = false) {
  QDir().mkpath(QFileInfo(path).absolutePath());
  QFile file(path);
  if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate) || file.write(contents) != contents.size()) {
    return false;
  }
  file.close();
  if (executable) {
    return file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner |
                               QFileDevice::ReadGroup | QFileDevice::ExeGroup | QFileDevice::ReadOther |
                               QFileDevice::ExeOther);
  }
  return true;
}

} // namespace

class LinuxUpdaterTest final : public QObject {
  Q_OBJECT

private slots:
  void updatesOmarchyPlugin_data();
  void updatesOmarchyPlugin();
};

void LinuxUpdaterTest::updatesOmarchyPlugin_data() {
  QTest::addColumn<QString>("pluginKind");
  QTest::addColumn<bool>("daemonFails");
  QTest::newRow("migrate-versioned-link") << QStringLiteral("legacy") << false;
  QTest::newRow("preserve-source-link") << QStringLiteral("source") << false;
  QTest::newRow("preserve-local-directory") << QStringLiteral("directory") << false;
  QTest::newRow("restore-active-link-on-failure") << QStringLiteral("current") << true;
}

void LinuxUpdaterTest::updatesOmarchyPlugin() {
  QFETCH(QString, pluginKind);
  QFETCH(bool, daemonFails);
  QTemporaryDir sandbox;
  QVERIFY(sandbox.isValid());

  const QString home = sandbox.filePath(QStringLiteral("home"));
  const QString installPrefix = sandbox.filePath(QStringLiteral("prefix"));
  const QString fakeBin = sandbox.filePath(QStringLiteral("bin"));
  const QString previousRoot = QDir(installPrefix).filePath(QStringLiteral("lib/waypoint-9.9.8"));
  const QString currentLink = QDir(installPrefix).filePath(QStringLiteral("lib/waypoint-current"));
  const QString controlLink = QDir(installPrefix).filePath(QStringLiteral("bin/waypointctl"));
  const QString restartMarker = sandbox.filePath(QStringLiteral("omarchy-restarted"));

  const QString pluginPath = QStringLiteral("usr/share/waypoint/omarchy-waypoint");
  const QString pluginTarget =
      QDir(home).filePath(QStringLiteral(".config/omarchy/plugins/io.waypoint.bar"));
  QVERIFY(QDir().mkpath(QFileInfo(pluginTarget).absolutePath()));
  QVERIFY(writeFile(QDir(previousRoot).filePath(pluginPath + QStringLiteral("/manifest.json")),
                    QByteArrayLiteral("{}")));
  const QString sourcePlugin = sandbox.filePath(QStringLiteral("checkout/plugin"));
  QString initialPluginLink;
  if (pluginKind == QStringLiteral("directory")) {
    QVERIFY(writeFile(QDir(pluginTarget).filePath(QStringLiteral("manifest.json")), QByteArrayLiteral("{}")));
  } else {
    if (pluginKind == QStringLiteral("source")) {
      QVERIFY(writeFile(QDir(sourcePlugin).filePath(QStringLiteral("manifest.json")), QByteArrayLiteral("{}")));
      initialPluginLink = sourcePlugin;
    } else if (pluginKind == QStringLiteral("current")) {
      initialPluginLink = QDir(currentLink).filePath(pluginPath);
    } else {
      initialPluginLink = QDir(previousRoot).filePath(pluginPath);
    }
    QVERIFY(QFile::link(initialPluginLink, pluginTarget));
  }
  QVERIFY(writeFile(QDir(previousRoot).filePath(QStringLiteral("usr/share/waypoint/VERSION")),
                    QByteArrayLiteral("9.9.8\n")));
  QVERIFY(writeFile(QDir(previousRoot).filePath(QStringLiteral("usr/bin/waypointctl")),
                    QByteArrayLiteral("#!/bin/sh\nexit 0\n"), true));
  QVERIFY(QFile::link(QStringLiteral("waypoint-9.9.8"), currentLink));
  QVERIFY(QDir().mkpath(QFileInfo(controlLink).absolutePath()));
  QVERIFY(QFile::link(QDir(currentLink).filePath(QStringLiteral("usr/bin/waypointctl")), controlLink));

  const QByteArray curlScript = R"(#!/bin/sh
output=
url=
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output" ]; then
    output=$2
    shift 2
  else
    case "$1" in https://*) url=$1 ;; esac
    shift
  fi
done
case "$url" in
  */SHA256SUMS) printf '%s  waypoint-linux-x86_64.tar.gz\n' "$WAYPOINT_TEST_ARCHIVE_SHA" >"$output" ;;
  *) printf 'archive' >"$output" ;;
esac
)";
  const QByteArray tarScript = R"(#!/bin/sh
case "$1" in
  -xOf)
    printf '%s\n' "$WAYPOINT_TEST_RELEASE_VERSION"
    ;;
  -tzf)
    printf '%s\n' \
      './usr/bin/waypoint' \
      './usr/bin/waypointd' \
      './usr/bin/waypointctl' \
      './usr/bin/waypoint-updater' \
      './usr/share/waypoint/VERSION' \
      './usr/share/waypoint/omarchy-waypoint/manifest.json' \
      './usr/share/applications/waypoint.desktop' \
      './usr/share/icons/hicolor/scalable/apps/waypoint.svg' \
      './usr/share/systemd/user/waypointd.service'
    ;;
  -xzf)
    root=$4
    mkdir -p \
      "$root/usr/bin" \
      "$root/usr/share/waypoint/omarchy-waypoint" \
      "$root/usr/share/applications" \
      "$root/usr/share/icons/hicolor/scalable/apps" \
      "$root/usr/share/systemd/user"
    : >"$root/usr/bin/waypoint"
    : >"$root/usr/bin/waypointd"
    printf '#!/bin/sh\nexit 0\n' >"$root/usr/bin/waypointctl"
    chmod 755 "$root/usr/bin/waypointctl"
    : >"$root/usr/bin/waypoint-updater"
    printf '%s\n' "$WAYPOINT_TEST_RELEASE_VERSION" >"$root/usr/share/waypoint/VERSION"
    : >"$root/usr/share/waypoint/omarchy-waypoint/manifest.json"
    : >"$root/usr/share/applications/waypoint.desktop"
    : >"$root/usr/share/icons/hicolor/scalable/apps/waypoint.svg"
    : >"$root/usr/share/systemd/user/waypointd.service"
    ;;
  *) exit 2 ;;
esac
)";
  const QByteArray omarchyShellScript = R"(#!/bin/sh
[ "$1 $2" = "shell rescanPlugins" ] || exit 2
printf 'rescan\n' >>"$WAYPOINT_TEST_OMARCHY_MARKER"
)";
  const QByteArray omarchyScript = R"(#!/bin/sh
[ "$1 $2" = "restart shell" ] || exit 2
sleep 1
printf 'restart\n' >>"$WAYPOINT_TEST_OMARCHY_MARKER"
)";

  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("curl")), curlScript, true));
  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("tar")), tarScript, true));
  const QByteArray systemctlScript = R"(#!/bin/sh
if [ "$*" = "--user restart waypointd.service" ] && [ "$WAYPOINT_TEST_DAEMON_FAILS" = 1 ] &&
   grep -qx "$WAYPOINT_TEST_RELEASE_VERSION" "$WAYPOINT_INSTALL_PREFIX/lib/waypoint-current/usr/share/waypoint/VERSION"; then
  exit 1
fi
)";
  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("systemctl")), systemctlScript, true));
  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("omarchy")), omarchyScript, true));
  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("omarchy-shell")), omarchyShellScript, true));

  QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
  environment.insert(QStringLiteral("HOME"), home);
  environment.insert(QStringLiteral("XDG_CONFIG_HOME"), QDir(home).filePath(QStringLiteral(".config")));
  environment.insert(QStringLiteral("XDG_DATA_HOME"), QDir(home).filePath(QStringLiteral(".local/share")));
  environment.insert(QStringLiteral("WAYPOINT_INSTALL_PREFIX"), installPrefix);
  environment.insert(
      QStringLiteral("WAYPOINT_TEST_ARCHIVE_SHA"),
      QString::fromLatin1(
          QCryptographicHash::hash(QByteArrayLiteral("archive"), QCryptographicHash::Sha256).toHex()));
  environment.insert(QStringLiteral("WAYPOINT_TEST_RELEASE_VERSION"), QString::fromLatin1(releaseVersion));
  environment.insert(QStringLiteral("WAYPOINT_TEST_OMARCHY_MARKER"), restartMarker);
  environment.insert(QStringLiteral("WAYPOINT_TEST_DAEMON_FAILS"), daemonFails ? QStringLiteral("1") : QStringLiteral("0"));
  environment.insert(QStringLiteral("PATH"),
                     fakeBin + QDir::listSeparator() + environment.value(QStringLiteral("PATH")));

  QProcess updater;
  updater.setProcessEnvironment(environment);
  updater.setProcessChannelMode(QProcess::MergedChannels);
  updater.start(
      QStringLiteral(WAYPOINT_UPDATER_PATH),
      {QStringLiteral("--version"), QString::fromLatin1(releaseVersion), QStringLiteral("--archive-url"),
       QStringLiteral(
           "https://github.com/EaeDave/waypoint/releases/download/v9.9.9/waypoint-linux-x86_64.tar.gz"),
       QStringLiteral("--checksums-url"),
       QStringLiteral("https://github.com/EaeDave/waypoint/releases/download/v9.9.9/SHA256SUMS"),
       QStringLiteral("--repository"), QStringLiteral("EaeDave/waypoint")});

  QVERIFY2(updater.waitForFinished(15000), qPrintable(updater.errorString()));
  const QByteArray output = updater.readAll();
  QVERIFY2(updater.exitStatus() == QProcess::NormalExit, output.constData());
  QCOMPARE(updater.exitCode(), daemonFails ? 1 : 0);
  const QString expectedRoot = daemonFails
      ? previousRoot : QDir(installPrefix).filePath(QStringLiteral("lib/waypoint-9.9.9"));
  QCOMPARE(QFileInfo(currentLink).canonicalFilePath(), QFileInfo(expectedRoot).canonicalFilePath());

  if (pluginKind == QStringLiteral("legacy")) {
    QFile restartLog(restartMarker);
    QVERIFY2(restartLog.open(QIODevice::ReadOnly), "The updater did not reload the Omarchy plugin");
    QCOMPARE(restartLog.readAll(), QByteArrayLiteral("rescan\nrestart\n"));
    QCOMPARE(QFileInfo(pluginTarget).symLinkTarget(), QDir(currentLink).filePath(pluginPath));
    QCOMPARE(QFileInfo(pluginTarget).canonicalFilePath(), QDir(expectedRoot).filePath(pluginPath));
  } else {
    QVERIFY(!QFileInfo::exists(restartMarker));
    QCOMPARE(QFileInfo(pluginTarget).symLinkTarget(), initialPluginLink);
    if (daemonFails) {
      QFile status(QDir(home).filePath(QStringLiteral(".local/share/Waypoint/Waypoint/update-release.json")));
      QVERIFY(status.open(QIODevice::ReadOnly));
      const auto result = QJsonDocument::fromJson(status.readAll()).object();
      QCOMPARE(result.value(QStringLiteral("installState")).toString(), QStringLiteral("error"));
      QVERIFY(result.value(QStringLiteral("installError")).toString().contains(
          QStringLiteral("restored the previous version")));
      QCOMPARE(QFileInfo(pluginTarget).canonicalFilePath(), QDir(previousRoot).filePath(pluginPath));
    } else {
      QVERIFY(QFileInfo::exists(QDir(pluginTarget).filePath(QStringLiteral("manifest.json"))));
    }
  }
}

QTEST_APPLESS_MAIN(LinuxUpdaterTest)

#include "LinuxUpdaterTest.moc"

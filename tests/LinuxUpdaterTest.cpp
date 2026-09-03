#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
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
  void waitsForOmarchyShellRestart();
};

void LinuxUpdaterTest::waitsForOmarchyShellRestart() {
  QTemporaryDir sandbox;
  QVERIFY(sandbox.isValid());

  const QString home = sandbox.filePath(QStringLiteral("home"));
  const QString installPrefix = sandbox.filePath(QStringLiteral("prefix"));
  const QString fakeBin = sandbox.filePath(QStringLiteral("bin"));
  const QString previousRoot = QDir(installPrefix).filePath(QStringLiteral("lib/waypoint-9.9.8"));
  const QString currentLink = QDir(installPrefix).filePath(QStringLiteral("lib/waypoint-current"));
  const QString controlLink = QDir(installPrefix).filePath(QStringLiteral("bin/waypointctl"));
  const QString restartMarker = sandbox.filePath(QStringLiteral("omarchy-restarted"));

  QVERIFY(QDir().mkpath(QDir(home).filePath(QStringLiteral(".config/omarchy"))));
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
  const QByteArray omarchyScript = R"(#!/bin/sh
sleep 1
printf 'restarted\n' >"$WAYPOINT_TEST_OMARCHY_MARKER"
)";

  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("curl")), curlScript, true));
  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("tar")), tarScript, true));
  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("systemctl")),
                    QByteArrayLiteral("#!/bin/sh\nexit 0\n"), true));
  QVERIFY(writeFile(QDir(fakeBin).filePath(QStringLiteral("omarchy")), omarchyScript, true));

  QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
  environment.insert(QStringLiteral("HOME"), home);
  environment.insert(QStringLiteral("XDG_CONFIG_HOME"), QDir(home).filePath(QStringLiteral(".config")));
  environment.insert(QStringLiteral("XDG_DATA_HOME"), QDir(home).filePath(QStringLiteral(".local/share")));
  environment.insert(QStringLiteral("WAYPOINT_INSTALL_PREFIX"), installPrefix);
  environment.insert(QStringLiteral("WAYPOINT_TEST_ARCHIVE_SHA"),
                     QString::fromLatin1(QCryptographicHash::hash(QByteArrayLiteral("archive"),
                                                                  QCryptographicHash::Sha256)
                                             .toHex()));
  environment.insert(QStringLiteral("WAYPOINT_TEST_RELEASE_VERSION"), QString::fromLatin1(releaseVersion));
  environment.insert(QStringLiteral("WAYPOINT_TEST_OMARCHY_MARKER"), restartMarker);
  environment.insert(QStringLiteral("PATH"), fakeBin + QDir::listSeparator() + environment.value(QStringLiteral("PATH")));

  QProcess updater;
  updater.setProcessEnvironment(environment);
  updater.setProcessChannelMode(QProcess::MergedChannels);
  updater.start(QStringLiteral(WAYPOINT_UPDATER_PATH),
                {QStringLiteral("--version"), QString::fromLatin1(releaseVersion),
                 QStringLiteral("--archive-url"),
                 QStringLiteral("https://github.com/EaeDave/waypoint/releases/download/v9.9.9/waypoint-linux-x86_64.tar.gz"),
                 QStringLiteral("--checksums-url"),
                 QStringLiteral("https://github.com/EaeDave/waypoint/releases/download/v9.9.9/SHA256SUMS"),
                 QStringLiteral("--repository"), QStringLiteral("EaeDave/waypoint")});

  QVERIFY2(updater.waitForFinished(15000), qPrintable(updater.errorString()));
  const QByteArray output = updater.readAll();
  QVERIFY2(updater.exitStatus() == QProcess::NormalExit && updater.exitCode() == 0, output.constData());
  QVERIFY2(QFileInfo::exists(restartMarker), "The updater returned before Omarchy finished restarting");
  QCOMPARE(QFileInfo(currentLink).canonicalFilePath(),
           QFileInfo(QDir(installPrefix).filePath(QStringLiteral("lib/waypoint-9.9.9"))).canonicalFilePath());

  const QString pluginTarget = QDir(home).filePath(QStringLiteral(".config/omarchy/plugins/io.waypoint.bar"));
  QCOMPARE(QFileInfo(pluginTarget).symLinkTarget(),
           QDir(currentLink).filePath(QStringLiteral("usr/share/waypoint/omarchy-waypoint")));
}

QTEST_APPLESS_MAIN(LinuxUpdaterTest)

#include "LinuxUpdaterTest.moc"

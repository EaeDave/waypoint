#include "WaypointVersion.hpp"
#include "update/UpdateChecker.hpp"

#include <QCommandLineParser>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QThread>
#include <QUrl>

#include <filesystem>

namespace {

constexpr auto archiveName = "waypoint-linux-x86_64.tar.gz";
constexpr auto checksumName = "SHA256SUMS";

bool run(const QString &program, const QStringList &arguments, QByteArray *output, QString *errorMessage) {
  QProcess process;
  process.start(program, arguments);
  if (!process.waitForStarted() || !process.waitForFinished(-1) ||
      process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
    if (errorMessage != nullptr) {
      const QString detail = QString::fromUtf8(process.readAllStandardError()).trimmed();
      *errorMessage = detail.isEmpty() ? QStringLiteral("%1 failed").arg(program)
                                       : QStringLiteral("%1 failed: %2").arg(program, detail);
    }
    return false;
  }
  if (output != nullptr) {
    *output = process.readAllStandardOutput();
  }
  return true;
}

bool validReleaseUrl(const QUrl &url, const QString &version, const QString &fileName) {
  const QString expectedPath =
      QStringLiteral("/EaeDave/waypoint/releases/download/v%1/%2").arg(version, fileName);
  return url.scheme() == QStringLiteral("https") && url.host() == QStringLiteral("github.com") &&
         url.path() == expectedPath && url.query().isEmpty() && url.fragment().isEmpty();
}

QString statusPath() {
  return QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) +
         QStringLiteral("/update-release.json");
}

void writeStatus(const QString &state, const QString &version, const QString &error = {}) {
  QFile current(statusPath());
  QJsonObject object;
  if (current.open(QIODevice::ReadOnly)) {
    object = QJsonDocument::fromJson(current.readAll()).object();
  }
  object.insert(QStringLiteral("installState"), state);
  object.insert(QStringLiteral("installVersion"), version);
  object.insert(QStringLiteral("installError"), error);
  QDir().mkpath(QFileInfo(statusPath()).absolutePath());
  QSaveFile saved(statusPath());
  if (saved.open(QIODevice::WriteOnly)) {
    saved.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    saved.commit();
  }
}

bool replaceSymlink(const QString &linkPath, const QString &target, QString *errorMessage) {
  const std::filesystem::path link = linkPath.toStdString();
  const std::filesystem::path temporary =
      (linkPath + QStringLiteral(".tmp.%1").arg(QCoreApplication::applicationPid())).toStdString();
  std::error_code error;
  std::filesystem::remove(temporary, error);
  error.clear();
  std::filesystem::create_symlink(target.toStdString(), temporary, error);
  if (error) {
    if (errorMessage != nullptr) {
      *errorMessage = QStringLiteral("Cannot create update symlink %1: %2")
                          .arg(linkPath, QString::fromStdString(error.message()));
    }
    return false;
  }
  std::filesystem::rename(temporary, link, error);
  if (error) {
    std::filesystem::remove(temporary);
    if (errorMessage != nullptr) {
      *errorMessage = QStringLiteral("Cannot activate update symlink %1: %2")
                          .arg(linkPath, QString::fromStdString(error.message()));
    }
    return false;
  }
  return true;
}

QString checksumForArchive(const QByteArray &manifest) {
  for (const QByteArray &line : manifest.split('\n')) {
    const QList<QByteArray> fields = line.simplified().split(' ');
    if (fields.size() == 2 && fields.at(1) == archiveName && fields.at(0).size() == 64) {
      return QString::fromLatin1(fields.at(0)).toLower();
    }
  }
  return {};
}

QString fileSha256(const QString &path) {
  QFile file(path);
  if (!file.open(QIODevice::ReadOnly)) {
    return {};
  }
  QCryptographicHash hash(QCryptographicHash::Sha256);
  if (!hash.addData(&file)) {
    return {};
  }
  return QString::fromLatin1(hash.result().toHex());
}

void launchDesktop(const QString &installBase) {
  QProcess::startDetached(QDir(installBase).filePath(QStringLiteral("bin/waypoint")), {});
}

} // namespace

int main(int argc, char *argv[]) {
  QCoreApplication application(argc, argv);
  QCoreApplication::setOrganizationName(QStringLiteral("Waypoint"));
  QCoreApplication::setApplicationName(QStringLiteral("Waypoint"));
  QCoreApplication::setApplicationVersion(QString::fromLatin1(waypoint::version));

  QCommandLineParser parser;
  parser.addHelpOption();
  parser.addOption({QStringLiteral("version"), QStringLiteral("Release version"), QStringLiteral("version")});
  parser.addOption(
      {QStringLiteral("archive-url"), QStringLiteral("Release archive URL"), QStringLiteral("url")});
  parser.addOption(
      {QStringLiteral("checksums-url"), QStringLiteral("Release checksums URL"), QStringLiteral("url")});
  parser.addOption({QStringLiteral("repository"), QStringLiteral("Expected GitHub repository"),
                    QStringLiteral("owner/name"), QStringLiteral("EaeDave/waypoint")});
  parser.addOption({QStringLiteral("relaunch-desktop"), QStringLiteral("Relaunch Waypoint after updating")});
  parser.process(application);

  const QString releaseVersion = parser.value(QStringLiteral("version"));
  const QUrl archiveUrl(parser.value(QStringLiteral("archive-url")));
  const QUrl checksumsUrl(parser.value(QStringLiteral("checksums-url")));
  const QString installBase =
      qEnvironmentVariable("WAYPOINT_INSTALL_PREFIX", QDir::homePath() + QStringLiteral("/.local"));
  const bool relaunchDesktop = parser.isSet(QStringLiteral("relaunch-desktop"));
  const auto fail = [&](const QString &message) {
    writeStatus(QStringLiteral("error"), releaseVersion, message);
    if (relaunchDesktop) {
      launchDesktop(installBase);
    }
    return 1;
  };

  if (parser.value(QStringLiteral("repository")) != QStringLiteral("EaeDave/waypoint") ||
      !validReleaseUrl(archiveUrl, releaseVersion, QString::fromLatin1(archiveName)) ||
      !validReleaseUrl(checksumsUrl, releaseVersion, QString::fromLatin1(checksumName))) {
    return fail(QStringLiteral("The update contains an untrusted release URL"));
  }

  const QString currentLink = QDir(installBase).filePath(QStringLiteral("lib/waypoint-current"));
  const QString previousRoot = QFileInfo(currentLink).symLinkTarget();
  const QString previousVersionFile =
      QDir(previousRoot).filePath(QStringLiteral("usr/share/waypoint/VERSION"));
  QFile previousVersion(previousVersionFile);
  if (previousRoot.isEmpty() || !previousVersion.open(QIODevice::ReadOnly)) {
    return fail(QStringLiteral("Waypoint is not installed through the managed release installer"));
  }
  if (!waypoint::isNewerVersion(releaseVersion, QString::fromUtf8(previousVersion.readAll()).trimmed())) {
    return fail(QStringLiteral("Waypoint only installs a newer semantic version"));
  }

  QTemporaryDir downloads;
  if (!downloads.isValid()) {
    return fail(QStringLiteral("Cannot create the update download directory"));
  }
  const QString archivePath = downloads.filePath(QString::fromLatin1(archiveName));
  const QString checksumsPath = downloads.filePath(QString::fromLatin1(checksumName));
  QString error;
  const QString curl = QStandardPaths::findExecutable(QStringLiteral("curl"));
  const QString tar = QStandardPaths::findExecutable(QStringLiteral("tar"));
  if (curl.isEmpty() || tar.isEmpty()) {
    return fail(QStringLiteral("The update requires curl and tar"));
  }
  writeStatus(QStringLiteral("downloading"), releaseVersion);
  const QStringList curlArguments{QStringLiteral("--fail"), QStringLiteral("--location"),
                                  QStringLiteral("--proto"), QStringLiteral("=https"),
                                  QStringLiteral("--tlsv1.2")};
  if (!run(curl,
           curlArguments + QStringList{checksumsUrl.toString(), QStringLiteral("--output"), checksumsPath},
           nullptr, &error) ||
      !run(curl, curlArguments + QStringList{archiveUrl.toString(), QStringLiteral("--output"), archivePath},
           nullptr, &error)) {
    return fail(error);
  }
  QFile checksums(checksumsPath);
  if (!checksums.open(QIODevice::ReadOnly)) {
    return fail(QStringLiteral("Cannot read downloaded checksums"));
  }
  const QString expectedChecksum = checksumForArchive(checksums.readAll());
  const QString actualChecksum = fileSha256(archivePath);
  if (expectedChecksum.isEmpty() || actualChecksum != expectedChecksum) {
    return fail(QStringLiteral("The downloaded Waypoint archive failed SHA-256 verification"));
  }
  QByteArray packagedVersion;
  if (!run(tar, {QStringLiteral("-xOf"), archivePath, QStringLiteral("./usr/share/waypoint/VERSION")},
           &packagedVersion, &error) ||
      QString::fromUtf8(packagedVersion).trimmed() != releaseVersion) {
    return fail(
        QStringLiteral("The downloaded archive version does not match Waypoint %1").arg(releaseVersion));
  }

  const QString libraryDirectory = QDir(installBase).filePath(QStringLiteral("lib"));
  const QString installRoot =
      QDir(libraryDirectory).filePath(QStringLiteral("waypoint-%1").arg(releaseVersion));
  const QString stagingRoot = installRoot + QStringLiteral(".tmp.%1").arg(QCoreApplication::applicationPid());
  QDir().mkpath(libraryDirectory);
  QDir(stagingRoot).removeRecursively();
  QDir().mkpath(stagingRoot);
  writeStatus(QStringLiteral("installing"), releaseVersion);
  QByteArray archiveEntries;
  if (!run(tar, {QStringLiteral("-tzf"), archivePath}, &archiveEntries, &error)) {
    return fail(error);
  }
  for (const QByteArray &entry : archiveEntries.split('\n')) {
    const QString path = QString::fromUtf8(entry).trimmed();
    const QString cleaned = QDir::cleanPath(path);
    if (!path.isEmpty() && (QDir::isAbsolutePath(path) || cleaned == QStringLiteral("..") ||
                            cleaned.startsWith(QStringLiteral("../")))) {
      return fail(QStringLiteral("The update archive contains an unsafe path"));
    }
  }
  if (!run(tar, {QStringLiteral("-xzf"), archivePath, QStringLiteral("-C"), stagingRoot}, nullptr, &error)) {
    return fail(error);
  }
  const QStringList requiredFiles{QStringLiteral("usr/bin/waypoint"),
                                  QStringLiteral("usr/bin/waypointd"),
                                  QStringLiteral("usr/bin/waypointctl"),
                                  QStringLiteral("usr/bin/waypoint-updater"),
                                  QStringLiteral("usr/share/waypoint/VERSION"),
                                  QStringLiteral("usr/share/applications/waypoint.desktop"),
                                  QStringLiteral("usr/share/icons/hicolor/scalable/apps/waypoint.svg"),
                                  QStringLiteral("usr/share/systemd/user/waypointd.service")};
  for (const QString &required : requiredFiles) {
    if (!QFileInfo::exists(QDir(stagingRoot).filePath(required))) {
      QDir(stagingRoot).removeRecursively();
      return fail(QStringLiteral("The update archive is missing %1").arg(required));
    }
  }
  QDir(installRoot).removeRecursively();
  if (!QDir().rename(stagingRoot, installRoot)) {
    return fail(QStringLiteral("Cannot move the staged update into %1").arg(installRoot));
  }
  if (!replaceSymlink(currentLink, QStringLiteral("waypoint-%1").arg(releaseVersion), &error)) {
    return fail(error);
  }

  const QStringList sharedTargets{
      QDir(currentLink).filePath(QStringLiteral("usr/share/applications/waypoint.desktop")),
      QDir(currentLink).filePath(QStringLiteral("usr/share/icons/hicolor/scalable/apps/waypoint.svg")),
      QDir(currentLink).filePath(QStringLiteral("usr/share/systemd/user/waypointd.service"))};
  const QStringList sharedLinks{
      QDir(installBase).filePath(QStringLiteral("share/applications/waypoint.desktop")),
      QDir(installBase).filePath(QStringLiteral("share/icons/hicolor/scalable/apps/waypoint.svg")),
      QDir::home().filePath(QStringLiteral(".config/systemd/user/waypointd.service"))};
  for (qsizetype index = 0; index < sharedTargets.size(); ++index) {
    QDir().mkpath(QFileInfo(sharedLinks.at(index)).absolutePath());
    if (!replaceSymlink(sharedLinks.at(index), sharedTargets.at(index), &error)) {
      replaceSymlink(currentLink, previousRoot, nullptr);
      return fail(error);
    }
  }

  const QString pluginSource =
      QDir(currentLink).filePath(QStringLiteral("usr/share/waypoint/omarchy-waypoint"));
  const QString pluginTarget =
      QDir::home().filePath(QStringLiteral(".config/omarchy/plugins/io.waypoint.bar"));
  if (QFileInfo(pluginSource).isDir() &&
      QFileInfo::exists(QDir::home().filePath(QStringLiteral(".config/omarchy")))) {
    QDir().mkpath(QFileInfo(pluginTarget).absolutePath());
    if (!replaceSymlink(pluginTarget, pluginSource, &error)) {
      replaceSymlink(currentLink, previousRoot, nullptr);
      return fail(error);
    }
  }

  const QString systemctl = QStandardPaths::findExecutable(QStringLiteral("systemctl"));
  if (!systemctl.isEmpty()) {
    run(systemctl, {QStringLiteral("--user"), QStringLiteral("daemon-reload")}, nullptr, nullptr);
    if (!run(systemctl,
             {QStringLiteral("--user"), QStringLiteral("restart"), QStringLiteral("waypointd.service")},
             nullptr, &error)) {
      replaceSymlink(currentLink, previousRoot, nullptr);
      run(systemctl,
          {QStringLiteral("--user"), QStringLiteral("restart"), QStringLiteral("waypointd.service")}, nullptr,
          nullptr);
      return fail(QStringLiteral("The new daemon failed to restart; Waypoint restored the previous version"));
    }
  }

  const QString control = QDir(installBase).filePath(QStringLiteral("bin/waypointctl"));
  bool daemonReady = systemctl.isEmpty();
  for (int attempt = 0; !daemonReady && attempt < 10; ++attempt) {
    QThread::msleep(500);
    daemonReady = run(control, {QStringLiteral("ping")}, nullptr, nullptr);
  }
  if (!daemonReady) {
    replaceSymlink(currentLink, previousRoot, nullptr);
    run(systemctl, {QStringLiteral("--user"), QStringLiteral("restart"), QStringLiteral("waypointd.service")},
        nullptr, nullptr);
    return fail(
        QStringLiteral("The new daemon did not become ready; Waypoint restored the previous version"));
  }

  writeStatus(QStringLiteral("complete"), releaseVersion);
  const QString omarchy = QStandardPaths::findExecutable(QStringLiteral("omarchy"));
  if (!omarchy.isEmpty() && QFileInfo::exists(pluginTarget)) {
    QProcess::startDetached(omarchy, {QStringLiteral("restart"), QStringLiteral("shell")});
  }
  if (relaunchDesktop) {
    launchDesktop(installBase);
  }
  return 0;
}

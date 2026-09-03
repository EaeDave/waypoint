#include "update/UpdateChecker.hpp"

#include "WaypointVersion.hpp"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QSaveFile>
#include <QStandardPaths>

namespace waypoint {
namespace {

constexpr auto latestReleaseUrl = "https://api.github.com/repos/EaeDave/waypoint/releases/latest";
constexpr auto linuxAssetName = "waypoint-linux-x86_64.tar.gz";
constexpr auto androidAssetName = "waypoint-android-arm64.apk";
constexpr auto checksumsAssetName = "SHA256SUMS";
constexpr auto repositoryName = "EaeDave/waypoint";
constexpr qint64 checkIntervalMilliseconds = 6LL * 60LL * 60LL * 1000LL;

void setError(QString *errorMessage, const QString &message) {
  if (errorMessage != nullptr) {
    *errorMessage = message;
  }
}

QList<int> versionParts(const QString &value) {
  const QStringList fields = value.split(QLatin1Char('.'));
  if (fields.size() != 3) {
    return {};
  }
  QList<int> parts;
  for (const QString &field : fields) {
    bool valid = false;
    const int part = field.toInt(&valid);
    if (!valid || part < 0 || QString::number(part) != field) {
      return {};
    }
    parts.append(part);
  }
  return parts;
}

QString assetName(UpdateAsset asset) {
  return asset == UpdateAsset::LinuxX86_64 ? QString::fromLatin1(linuxAssetName)
                                           : QString::fromLatin1(androidAssetName);
}

bool validReleaseAssetUrl(const QUrl &url, const QString &version, const QString &name) {
  const QString expectedPath =
      QStringLiteral("/EaeDave/waypoint/releases/download/v%1/%2").arg(version, name);
  return url.scheme() == QStringLiteral("https") && url.host() == QStringLiteral("github.com") &&
         url.path() == expectedPath && url.query().isEmpty() && url.fragment().isEmpty();
}

} // namespace

bool isNewerVersion(const QString &candidate, const QString &current) {
  const QList<int> candidateParts = versionParts(candidate);
  const QList<int> currentParts = versionParts(current);
  if (candidateParts.size() != 3 || currentParts.size() != 3) {
    return false;
  }
  for (qsizetype index = 0; index < candidateParts.size(); ++index) {
    if (candidateParts.at(index) != currentParts.at(index)) {
      return candidateParts.at(index) > currentParts.at(index);
    }
  }
  return false;
}

bool parseLatestRelease(const QByteArray &payload, const UpdateAsset asset, ReleaseInfo *release,
                        QString *errorMessage) {
  if (release == nullptr) {
    setError(errorMessage, QStringLiteral("Cannot parse a release without an output value"));
    return false;
  }
  QJsonParseError parseError;
  const QJsonDocument document = QJsonDocument::fromJson(payload, &parseError);
  if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
    setError(errorMessage,
             QStringLiteral("GitHub returned invalid release metadata: %1").arg(parseError.errorString()));
    return false;
  }
  const QJsonObject object = document.object();
  if (object.value(QStringLiteral("draft")).toBool() || object.value(QStringLiteral("prerelease")).toBool()) {
    setError(errorMessage, QStringLiteral("GitHub latest release is not a stable published release"));
    return false;
  }
  QString tag = object.value(QStringLiteral("tag_name")).toString();
  if (tag.startsWith(QLatin1Char('v'))) {
    tag.remove(0, 1);
  }
  if (versionParts(tag).size() != 3) {
    setError(errorMessage, QStringLiteral("GitHub release tag is not a semantic version"));
    return false;
  }

  QUrl downloadUrl;
  QUrl checksumsUrl;
  const QString wantedAsset = assetName(asset);
  for (const QJsonValue &value : object.value(QStringLiteral("assets")).toArray()) {
    const QJsonObject releaseAsset = value.toObject();
    const QString name = releaseAsset.value(QStringLiteral("name")).toString();
    const QUrl url(releaseAsset.value(QStringLiteral("browser_download_url")).toString());
    if (name == wantedAsset) {
      downloadUrl = url;
    } else if (name == QString::fromLatin1(checksumsAssetName)) {
      checksumsUrl = url;
    }
  }
  if (!validReleaseAssetUrl(downloadUrl, tag, wantedAsset) ||
      !validReleaseAssetUrl(checksumsUrl, tag, QString::fromLatin1(checksumsAssetName))) {
    setError(errorMessage,
             QStringLiteral("Waypoint %1 release has missing or untrusted download assets").arg(tag));
    return false;
  }
  release->version = tag;
  release->downloadUrl = downloadUrl;
  release->checksumsUrl = checksumsUrl;
  return true;
}

UpdateChecker::UpdateChecker(const UpdateAsset asset, QObject *parent) : QObject(parent), m_asset(asset) {
  m_timer.setInterval(checkIntervalMilliseconds);
  connect(&m_timer, &QTimer::timeout, this, &UpdateChecker::checkNow);
  loadCache();
}

void UpdateChecker::start() {
  if (m_started) {
    return;
  }
  m_started = true;
  m_timer.start();
  QTimer::singleShot(5000, this, &UpdateChecker::checkNow);
}

QJsonObject UpdateChecker::status() {
  if (!m_requestInFlight) {
    loadCache();
  }
  return {{QStringLiteral("state"), m_state},
          {QStringLiteral("currentVersion"), QString::fromLatin1(version)},
          {QStringLiteral("latestVersion"), m_release.version},
          {QStringLiteral("checkedAt"), m_checkedAt},
          {QStringLiteral("error"), m_errorMessage},
          {QStringLiteral("canInstall"), canInstall()}};
}

ReleaseInfo UpdateChecker::release() const { return m_release; }

void UpdateChecker::checkNow() {
  if (m_requestInFlight) {
    return;
  }
  m_requestInFlight = true;
  setState(QStringLiteral("checking"));
  QNetworkRequest request(QUrl(QString::fromLatin1(latestReleaseUrl)));
  request.setHeader(QNetworkRequest::UserAgentHeader,
                    QStringLiteral("Waypoint/%1").arg(QString::fromLatin1(version)));
  request.setRawHeader("Accept", "application/vnd.github+json");
  request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
  request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
  if (!m_etag.isEmpty()) {
    request.setRawHeader("If-None-Match", m_etag);
  }
  QNetworkReply *reply = m_network.get(request);
  connect(reply, &QNetworkReply::finished, this, [this, reply] {
    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray payload = reply->readAll();
    const QByteArray etag = reply->rawHeader("ETag");
    const QString networkError = reply->errorString();
    const QNetworkReply::NetworkError error = reply->error();
    reply->deleteLater();
    m_requestInFlight = false;
    m_checkedAt = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    if (statusCode == 304) {
      setState(isNewerVersion(m_release.version, QString::fromLatin1(version))
                   ? QStringLiteral("available")
                   : QStringLiteral("up-to-date"));
      saveCache(true);
      return;
    }
    if (error != QNetworkReply::NoError) {
      setState(QStringLiteral("error"),
               QStringLiteral("Cannot check Waypoint releases: %1").arg(networkError));
      return;
    }
    ReleaseInfo releaseInfo;
    QString parseError;
    if (!parseLatestRelease(payload, m_asset, &releaseInfo, &parseError)) {
      setState(QStringLiteral("error"), parseError);
      return;
    }
    m_release = releaseInfo;
    m_etag = etag;
    setState(isNewerVersion(m_release.version, QString::fromLatin1(version)) ? QStringLiteral("available")
                                                                             : QStringLiteral("up-to-date"));
    saveCache(true);
  });
}

bool UpdateChecker::installLinuxUpdate(const bool relaunchDesktop, QString *errorMessage) {
  if (m_asset != UpdateAsset::LinuxX86_64 || m_state != QStringLiteral("available")) {
    setError(errorMessage, QStringLiteral("No installable Linux update is available"));
    return false;
  }
  const QString helper = QStandardPaths::findExecutable(QStringLiteral("waypoint-updater"),
                                                        {QCoreApplication::applicationDirPath()});
  if (helper.isEmpty()) {
    setError(errorMessage,
             QStringLiteral("waypoint-updater is unavailable; install Waypoint from a release package"));
    return false;
  }
  QStringList arguments{QStringLiteral("--version"),       m_release.version,
                        QStringLiteral("--archive-url"),   m_release.downloadUrl.toString(),
                        QStringLiteral("--checksums-url"), m_release.checksumsUrl.toString(),
                        QStringLiteral("--repository"),    QString::fromLatin1(repositoryName)};
  if (relaunchDesktop) {
    arguments.append(QStringLiteral("--relaunch-desktop"));
  }
  if (!QProcess::startDetached(helper, arguments)) {
    setError(errorMessage, QStringLiteral("Cannot start the Waypoint update helper"));
    return false;
  }
  markDownloading();
  return true;
}

void UpdateChecker::markDownloading() { setState(QStringLiteral("installing")); }

void UpdateChecker::loadCache() {
  const QString path = cachePath();
  const QFileInfo cacheInfo(path);
  if (!cacheInfo.exists() || cacheInfo.lastModified() == m_cacheModified) {
    return;
  }
  QFile file(path);
  if (!file.open(QIODevice::ReadOnly)) {
    return;
  }
  m_cacheModified = cacheInfo.lastModified();
  const QJsonObject object = QJsonDocument::fromJson(file.readAll()).object();
  m_release.version = object.value(QStringLiteral("latestVersion")).toString();
  m_release.downloadUrl = QUrl(object.value(QStringLiteral("downloadUrl")).toString());
  m_release.checksumsUrl = QUrl(object.value(QStringLiteral("checksumsUrl")).toString());
  m_checkedAt = object.value(QStringLiteral("checkedAt")).toString();
  m_etag = QByteArray::fromBase64(object.value(QStringLiteral("etag")).toString().toLatin1());
  const QString installState = object.value(QStringLiteral("installState")).toString();
  const QString installVersion = object.value(QStringLiteral("installVersion")).toString();
  if (installState == QStringLiteral("error")) {
    m_state = QStringLiteral("error");
    m_errorMessage = object.value(QStringLiteral("installError")).toString();
  } else if (installState == QStringLiteral("downloading") || installState == QStringLiteral("installing")) {
    m_state = installState;
    m_errorMessage.clear();
  } else if (installState == QStringLiteral("complete") && installVersion == QString::fromLatin1(version) &&
             !isNewerVersion(m_release.version, QString::fromLatin1(version))) {
    m_state = QStringLiteral("up-to-date");
    m_errorMessage.clear();
  } else {
    m_state = isNewerVersion(m_release.version, QString::fromLatin1(version)) ? QStringLiteral("available")
                                                                              : QStringLiteral("idle");
    m_errorMessage.clear();
  }
}

void UpdateChecker::saveCache(const bool clearInstallState) {
  const QString path = cachePath();
  QDir().mkpath(QFileInfo(path).absolutePath());
  QJsonObject object;
  QFile existing(path);
  if (existing.open(QIODevice::ReadOnly)) {
    object = QJsonDocument::fromJson(existing.readAll()).object();
  }
  if (clearInstallState) {
    object.remove(QStringLiteral("installState"));
    object.remove(QStringLiteral("installVersion"));
    object.remove(QStringLiteral("installError"));
  }
  object.insert(QStringLiteral("latestVersion"), m_release.version);
  object.insert(QStringLiteral("downloadUrl"), m_release.downloadUrl.toString());
  object.insert(QStringLiteral("checksumsUrl"), m_release.checksumsUrl.toString());
  object.insert(QStringLiteral("checkedAt"), m_checkedAt);
  object.insert(QStringLiteral("etag"), QString::fromLatin1(m_etag.toBase64()));
  QSaveFile file(path);
  if (file.open(QIODevice::WriteOnly)) {
    file.write(QJsonDocument(object).toJson(QJsonDocument::Compact));
    if (file.commit()) {
      m_cacheModified = QFileInfo(path).lastModified();
    }
  }
}

void UpdateChecker::setState(const QString &state, const QString &errorMessage) {
  const bool changed = m_state != state || m_errorMessage != errorMessage;
  m_state = state;
  m_errorMessage = errorMessage;
  if (changed) {
    emit statusChanged();
  }
}

QString UpdateChecker::cachePath() const {
  return QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) +
         QStringLiteral("/update-release.json");
}

bool UpdateChecker::canInstall() const {
#ifdef Q_OS_ANDROID
  return m_asset == UpdateAsset::AndroidArm64;
#elif defined(Q_OS_LINUX)
  const QString helper = QStandardPaths::findExecutable(QStringLiteral("waypoint-updater"),
                                                        {QCoreApplication::applicationDirPath()});
  const QString installBase =
      qEnvironmentVariable("WAYPOINT_INSTALL_PREFIX", QDir::homePath() + QStringLiteral("/.local"));
  const QString versionFile =
      QDir(installBase).filePath(QStringLiteral("lib/waypoint-current/usr/share/waypoint/VERSION"));
  return m_asset == UpdateAsset::LinuxX86_64 && !helper.isEmpty() && QFileInfo::exists(versionFile);
#else
  return false;
#endif
}

} // namespace waypoint

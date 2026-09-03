#include "mobile/AndroidUpdateInstaller.hpp"

#include "mobile/AndroidUpdateBridge.hpp"

#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>

namespace waypoint {
namespace {

constexpr auto apkName = "waypoint-android-arm64.apk";

QByteArray apkChecksum(const QByteArray &manifest) {
  for (const QByteArray &line : manifest.split('\n')) {
    const QList<QByteArray> fields = line.simplified().split(' ');
    if (fields.size() == 2 && fields.at(1) == apkName && fields.at(0).size() == 64) {
      return fields.at(0).toLower();
    }
  }
  return {};
}

} // namespace

AndroidUpdateInstaller::AndroidUpdateInstaller(QObject *parent) : QObject(parent) {}

QString AndroidUpdateInstaller::state() const { return m_state; }

QString AndroidUpdateInstaller::errorMessage() const { return m_errorMessage; }

qreal AndroidUpdateInstaller::progress() const { return m_progress; }

bool AndroidUpdateInstaller::install(const ReleaseInfo &release, QString *errorMessage) {
  if (m_reply != nullptr || release.version.isEmpty() || !release.downloadUrl.isValid() ||
      !release.checksumsUrl.isValid()) {
    if (errorMessage != nullptr) {
      *errorMessage = QStringLiteral("Nenhuma atualização válida está disponível");
    }
    return false;
  }
  if (m_state == QStringLiteral("waiting-for-android") && QFileInfo::exists(m_apkPath)) {
    return AndroidUpdateBridge::installApk(m_apkPath, errorMessage);
  }
  m_release = release;
  m_errorMessage.clear();
  m_progress = 0.0;
  downloadChecksums();
  return true;
}

void AndroidUpdateInstaller::downloadChecksums() {
  setState(QStringLiteral("downloading"));
  QNetworkRequest request(m_release.checksumsUrl);
  request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
  m_reply = m_network.get(request);
  connect(m_reply, &QNetworkReply::finished, this, &AndroidUpdateInstaller::finishChecksums);
}

void AndroidUpdateInstaller::finishChecksums() {
  QNetworkReply *reply = m_reply;
  m_reply = nullptr;
  const QByteArray manifest = reply->readAll();
  const QString networkError = reply->errorString();
  const bool succeeded = reply->error() == QNetworkReply::NoError;
  reply->deleteLater();
  if (!succeeded) {
    fail(QStringLiteral("Não foi possível baixar os checksums: %1").arg(networkError));
    return;
  }
  const QByteArray expected = apkChecksum(manifest);
  if (expected.isEmpty()) {
    fail(QStringLiteral("A release não contém um checksum válido para o APK"));
    return;
  }
  downloadApk(expected);
}

void AndroidUpdateInstaller::downloadApk(const QByteArray &expectedSha256) {
  const QString updateDirectory =
      QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) + QStringLiteral("/updates");
  QDir().mkpath(updateDirectory);
  m_apkPath = QDir(updateDirectory).filePath(QStringLiteral("waypoint-%1.apk").arg(m_release.version));
  m_apkFile = std::make_unique<QSaveFile>(m_apkPath);
  if (!m_apkFile->open(QIODevice::WriteOnly)) {
    fail(QStringLiteral("Não foi possível criar o arquivo temporário da atualização"));
    return;
  }
  m_expectedSha256 = expectedSha256;
  m_writeFailed = false;
  m_hash = std::make_unique<QCryptographicHash>(QCryptographicHash::Sha256);
  QNetworkRequest request(m_release.downloadUrl);
  request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
  m_reply = m_network.get(request);
  connect(m_reply, &QNetworkReply::readyRead, this, &AndroidUpdateInstaller::appendApkData);
  connect(m_reply, &QNetworkReply::downloadProgress, this, [this](const qint64 received, const qint64 total) {
    m_progress = total > 0 ? static_cast<qreal>(received) / static_cast<qreal>(total) : 0.0;
    emit statusChanged();
  });
  connect(m_reply, &QNetworkReply::finished, this, &AndroidUpdateInstaller::finishApk);
}

void AndroidUpdateInstaller::appendApkData() {
  const QByteArray chunk = m_reply->readAll();
  if (m_apkFile->write(chunk) != chunk.size()) {
    m_writeFailed = true;
    m_reply->abort();
    return;
  }
  m_hash->addData(chunk);
}

void AndroidUpdateInstaller::finishApk() {
  QNetworkReply *reply = m_reply;
  appendApkData();
  m_reply = nullptr;
  const QString networkError = reply->errorString();
  const bool downloaded = reply->error() == QNetworkReply::NoError;
  reply->deleteLater();
  if (!downloaded || m_writeFailed) {
    m_apkFile->cancelWriting();
    m_apkFile.reset();
    m_hash.reset();
    fail(m_writeFailed ? QStringLiteral("Não foi possível salvar a atualização")
                       : QStringLiteral("Não foi possível baixar a atualização: %1").arg(networkError));
    return;
  }
  const QByteArray actualSha256 = m_hash->result().toHex();
  m_hash.reset();
  if (actualSha256 != m_expectedSha256 || !m_apkFile->commit()) {
    m_apkFile.reset();
    fail(QStringLiteral("O APK baixado falhou na verificação SHA-256"));
    return;
  }
  m_apkFile.reset();
  QString installError;
  if (!AndroidUpdateBridge::installApk(m_apkPath, &installError)) {
    fail(installError);
    return;
  }
  m_progress = 1.0;
  setState(QStringLiteral("waiting-for-android"));
}

void AndroidUpdateInstaller::fail(const QString &message) {
  m_errorMessage = message;
  m_progress = 0.0;
  setState(QStringLiteral("error"));
}

void AndroidUpdateInstaller::setState(const QString &state) {
  m_state = state;
  emit statusChanged();
}

} // namespace waypoint

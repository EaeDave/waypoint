#pragma once

#include "update/UpdateChecker.hpp"

#include <QCryptographicHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QSaveFile>

#include <memory>

class QNetworkReply;

namespace waypoint {

class AndroidUpdateInstaller final : public QObject {
  Q_OBJECT

public:
  explicit AndroidUpdateInstaller(QObject *parent = nullptr);

  [[nodiscard]] QString state() const;
  [[nodiscard]] QString errorMessage() const;
  [[nodiscard]] qreal progress() const;
  [[nodiscard]] bool install(const ReleaseInfo &release, QString *errorMessage = nullptr);

signals:
  void statusChanged();

private:
  void downloadChecksums();
  void finishChecksums();
  void downloadApk(const QByteArray &expectedSha256);
  void appendApkData();
  void finishApk();
  void fail(const QString &message);
  void setState(const QString &state);

  QNetworkAccessManager m_network;
  ReleaseInfo m_release;
  QNetworkReply *m_reply = nullptr;
  std::unique_ptr<QSaveFile> m_apkFile;
  std::unique_ptr<QCryptographicHash> m_hash;
  QByteArray m_expectedSha256;
  QString m_apkPath;
  QString m_state = QStringLiteral("idle");
  QString m_errorMessage;
  bool m_writeFailed = false;
  qreal m_progress = 0.0;
};

} // namespace waypoint

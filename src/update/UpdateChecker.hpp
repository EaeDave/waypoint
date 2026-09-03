#pragma once

#include <QDateTime>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QTimer>
#include <QUrl>

namespace waypoint {

enum class UpdateAsset { LinuxX86_64, AndroidArm64 };

struct ReleaseInfo final {
  QString version;
  QUrl downloadUrl;
  QUrl checksumsUrl;
};

[[nodiscard]] bool parseLatestRelease(const QByteArray &payload, UpdateAsset asset, ReleaseInfo *release,
                                      QString *errorMessage = nullptr);
[[nodiscard]] bool isNewerVersion(const QString &candidate, const QString &current);

class UpdateChecker final : public QObject {
  Q_OBJECT

public:
  explicit UpdateChecker(UpdateAsset asset, QObject *parent = nullptr);

  void start();
  [[nodiscard]] QJsonObject status();
  [[nodiscard]] ReleaseInfo release() const;
  [[nodiscard]] bool installLinuxUpdate(bool relaunchDesktop, QString *errorMessage = nullptr);
  void markDownloading();

public slots:
  void checkNow();

signals:
  void statusChanged();

private:
  void loadCache();
  void saveCache(bool clearInstallState = false);
  void setState(const QString &state, const QString &errorMessage = {});
  [[nodiscard]] QString cachePath() const;
  [[nodiscard]] bool canInstall() const;

  UpdateAsset m_asset;
  QNetworkAccessManager m_network;
  QTimer m_timer;
  ReleaseInfo m_release;
  QString m_state = QStringLiteral("idle");
  QString m_errorMessage;
  QString m_checkedAt;
  QByteArray m_etag;
  QDateTime m_cacheModified;
  bool m_started = false;
  bool m_requestInFlight = false;
};

} // namespace waypoint

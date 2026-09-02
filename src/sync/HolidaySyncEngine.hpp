#pragma once

#include <QDateTime>
#include <QJsonObject>
#include <QList>
#include <QNetworkAccessManager>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QUrl>

class QNetworkReply;
class QNetworkRequest;

namespace waypoint {

class TaskStore;

class HolidaySyncEngine final : public QObject {
  Q_OBJECT

public:
  explicit HolidaySyncEngine(TaskStore *taskStore, QObject *parent = nullptr);

  [[nodiscard]] QJsonObject status() const;
  [[nodiscard]] bool updatePreferences(const QJsonObject &preferences, QString *errorMessage = nullptr);
  void start();
  void refreshMunicipalities(const QString &stateCode);

public slots:
  void syncNow();

signals:
  void statusChanged();
  void municipalitiesChanged(const QString &stateCode);

private:
  [[nodiscard]] QUrl apiUrl(const QString &path) const;
  [[nodiscard]] QNetworkRequest authorizedRequest(const QUrl &url) const;
  void downloadPreferences();
  void uploadPreferences();
  void fetchNextYear();
  void finishPreferencesUpload(QNetworkReply *reply);
  void finishPreferencesDownload(QNetworkReply *reply);
  void finishYearFetch(QNetworkReply *reply, int year);
  void setStatus(const QString &state, const QString &errorMessage = {});

  TaskStore *m_taskStore;
  QNetworkAccessManager m_network;
  QTimer m_periodicTimer;
  QList<int> m_pendingYears;
  QSet<QString> m_municipalityRequests;
  QDateTime m_lastSuccessfulSync;
  QString m_state = QStringLiteral("local-only");
  QString m_lastError;
  QStringList m_coverageErrors;
  bool m_preferencesNeedUpload = false;
  bool m_inFlight = false;
};

} // namespace waypoint

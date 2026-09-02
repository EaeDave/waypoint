#pragma once

#include <QDateTime>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QTimer>
#include <QUrl>

namespace waypoint {

class TaskStore;


class SyncEngine final : public QObject {
  Q_OBJECT

public:
  explicit SyncEngine(TaskStore *taskStore, QObject *parent = nullptr);

  [[nodiscard]] bool enabled() const;
  [[nodiscard]] QJsonObject publicConfiguration() const;
  [[nodiscard]] QJsonObject status() const;
  [[nodiscard]] bool updateConfiguration(const QString &endpointInput, const QByteArray &token,
                                         bool replaceToken, QString *errorMessage = nullptr);
  void start();

public slots:
  void syncNow();

signals:
  void statusChanged();

private slots:
  void finishSync();
  void scheduleSoon();
  void consumeEventStream();
  void finishEventStream();
  void openEventStream();

private:
  [[nodiscard]] QUrl normalizeEndpoint(const QString &endpointInput, QString *errorMessage) const;
  [[nodiscard]] QUrl eventStreamUrl() const;
  void closeEventStream();
  void continuePendingSync();
  void scheduleEventReconnect();
  void setStatus(const QString &state, const QString &errorMessage = {});
  void log(const QString &level, const QString &message) const;

  TaskStore *m_taskStore;
  QNetworkAccessManager m_network;
  QTimer m_periodicTimer;
  QTimer m_debounceTimer;
  QTimer m_eventReconnectTimer;
  QNetworkReply *m_eventStream = nullptr;
  QByteArray m_eventBuffer;
  QUrl m_endpoint;
  QByteArray m_token;
  QDateTime m_lastSuccessfulSync;
  QString m_state = QStringLiteral("local-only");
  QString m_lastError;
  bool m_inFlight = false;
  bool m_syncRequested = false;
  int m_eventReconnectSeconds = 1;
};

} // namespace waypoint

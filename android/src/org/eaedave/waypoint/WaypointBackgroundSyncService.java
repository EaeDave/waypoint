package org.eaedave.waypoint;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.json.JSONException;
import org.json.JSONObject;
import org.qtproject.qt.android.bindings.QtService;

public final class WaypointBackgroundSyncService extends QtService {
  private static final String TAG = "WaypointBackgroundSync";
  private static final String CHANNEL_ID = "waypoint-background-sync";
  private static final int NOTIFICATION_ID = -4819;
  private static final Object STATE_LOCK = new Object();
  private static final ExecutorService EXECUTOR = Executors.newSingleThreadExecutor();
  private static boolean running;
  private static boolean pending;

  public static void start(Context context) {
    Intent intent = new Intent(context, WaypointBackgroundSyncService.class);
    if (Build.VERSION.SDK_INT >= 26) {
      context.startForegroundService(intent);
    } else {
      context.startService(intent);
    }
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    startForeground(NOTIFICATION_ID, foregroundNotification());
    super.onStartCommand(intent, flags, startId);
    synchronized (STATE_LOCK) {
      pending = true;
      if (running) {
        return START_NOT_STICKY;
      }
      running = true;
    }
    EXECUTOR.execute(() -> drainSyncRequests(startId));
    return START_NOT_STICKY;
  }

  private void drainSyncRequests(int startId) {
    while (true) {
      synchronized (STATE_LOCK) {
        pending = false;
      }
      synchronizeOnce();
      synchronized (STATE_LOCK) {
        if (!pending) {
          running = false;
          break;
        }
      }
    }
    stopForeground(STOP_FOREGROUND_REMOVE);
    stopSelf(startId);
  }

  private void synchronizeOnce() {
    try {
      String databasePath = getFilesDir().getAbsolutePath() + "/waypoint.sqlite3";
      JSONObject prepared = new JSONObject(prepareBackgroundSync(databasePath));
      if (!prepared.optBoolean("ok", false)) {
        Log.i(TAG, prepared.optString("error", "Background synchronization is unavailable"));
        return;
      }

      String endpoint = prepared.getString("endpoint");
      String syncToken = prepared.getString("token");
      JSONObject request = prepared.getJSONObject("request");
      registerPushToken(endpoint, syncToken, request.getString("deviceId"));
      String response = request("POST", new URL(endpoint), syncToken, request.toString());
      JSONObject applied = new JSONObject(applyBackgroundSync(databasePath, response));
      if (!applied.optBoolean("ok", false)) {
        Log.w(TAG, applied.optString("error", "Unable to apply synchronization response"));
        return;
      }
      WaypointWidgetBridge.publishSnapshot(this, applied.getJSONObject("snapshot").toString());
      WaypointNotifications.replaceSchedule(this, applied.getJSONArray("schedule").toString());
    } catch (IOException | JSONException error) {
      Log.w(TAG, "Background synchronization failed", error);
    }
  }

  private void registerPushToken(String endpoint, String syncToken, String deviceId)
      throws IOException, JSONException {
    String pushToken = WaypointPushToken.current(this);
    if (pushToken.isEmpty()) {
      return;
    }
    URL registrationUrl = deviceRegistrationUrl(endpoint, deviceId);
    String target = registrationUrl.toString() + "|" + pushToken;
    if (!WaypointPushToken.needsRegistration(this, target)) {
      return;
    }
    JSONObject body = new JSONObject().put("platform", "android").put("pushToken", pushToken);
    request("PUT", registrationUrl, syncToken, body.toString());
    WaypointPushToken.markRegistered(this, target);
  }

  private static URL deviceRegistrationUrl(String endpoint, String deviceId) throws IOException {
    URL syncUrl = new URL(endpoint);
    String path = syncUrl.getPath();
    if (path.endsWith("/v1/sync")) {
      path = path.substring(0, path.length() - "sync".length()) + "devices/";
    } else {
      path = "/v1/devices/";
    }
    path += URLEncoder.encode(deviceId, StandardCharsets.UTF_8.name()).replace("+", "%20");
    return new URL(syncUrl.getProtocol(), syncUrl.getHost(), syncUrl.getPort(), path);
  }

  private static String request(String method, URL url, String token, String payload) throws IOException {
    byte[] body = payload.getBytes(StandardCharsets.UTF_8);
    HttpURLConnection connection = (HttpURLConnection)url.openConnection();
    connection.setRequestMethod(method);
    connection.setConnectTimeout(10000);
    connection.setReadTimeout(15000);
    connection.setRequestProperty("Authorization", "Bearer " + token);
    connection.setRequestProperty("Content-Type", "application/json");
    connection.setRequestProperty("Accept", "application/json");
    connection.setDoOutput(true);
    connection.setFixedLengthStreamingMode(body.length);
    try (OutputStream output = connection.getOutputStream()) {
      output.write(body);
    }

    int status = connection.getResponseCode();
    InputStream responseStream = status >= 200 && status < 300 ? connection.getInputStream()
                                                               : connection.getErrorStream();
    String response;
    try {
      response = read(responseStream);
    } finally {
      connection.disconnect();
    }
    if (status < 200 || status >= 300) {
      throw new IOException("HTTP " + status + (response.isEmpty() ? "" : ": " + response));
    }
    return response;
  }

  private static String read(InputStream stream) throws IOException {
    if (stream == null) {
      return "";
    }
    StringBuilder result = new StringBuilder();
    try (BufferedReader reader =
             new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
      String line;
      while ((line = reader.readLine()) != null) {
        result.append(line);
      }
    }
    return result.toString();
  }

  private android.app.Notification foregroundNotification() {
    if (Build.VERSION.SDK_INT >= 26) {
      NotificationChannel channel = new NotificationChannel(
          CHANNEL_ID, "Sincronização em segundo plano", NotificationManager.IMPORTANCE_MIN);
      channel.setDescription("Mantém widgets e lembretes do Waypoint atualizados");
      channel.enableVibration(false);
      channel.setShowBadge(false);
      NotificationManager manager = (NotificationManager)getSystemService(Context.NOTIFICATION_SERVICE);
      manager.createNotificationChannel(channel);
    }
    return new NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_popup_sync)
        .setContentTitle("Waypoint")
        .setContentText("Sincronizando")
        .setPriority(NotificationCompat.PRIORITY_MIN)
        .setSilent(true)
        .setOngoing(true)
        .build();
  }

  private static native String prepareBackgroundSync(String databasePath);
  private static native String applyBackgroundSync(String databasePath, String responsePayload);
}

package org.eaedave.waypoint;

import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;
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
  static final int MESSAGE_SYNCHRONIZE = 1;
  static final int MESSAGE_REFRESH_WIDGET = 2;
  static final int RESULT_SUCCESS = 0;
  static final int RESULT_RETRY = 1;

  private static final String TAG = "WaypointBackgroundSync";
  private static final ExecutorService EXECUTOR = Executors.newSingleThreadExecutor();

  private final Messenger requestMessenger =
      new Messenger(new Handler(Looper.getMainLooper(), this::handleRequest));

  @Override
  public IBinder onBind(Intent intent) {
    return requestMessenger.getBinder();
  }

  private boolean handleRequest(Message message) {
    if (message.what != MESSAGE_SYNCHRONIZE && message.what != MESSAGE_REFRESH_WIDGET) {
      return false;
    }
    int operation = message.what;
    Messenger replyTo = message.replyTo;
    EXECUTOR.execute(
        ()
            -> reply(replyTo, operation,
                     operation == MESSAGE_REFRESH_WIDGET ? refreshWidgetSnapshotOnce() : synchronizeOnce()));
    return true;
  }

  private static void reply(Messenger recipient, int operation, int result) {
    if (recipient == null) {
      return;
    }
    try {
      recipient.send(Message.obtain(null, operation, result, 0));
    } catch (RemoteException error) {
      Log.w(TAG, "Background work result receiver disappeared", error);
    }
  }

  private int synchronizeOnce() {
    try {
      String databasePath = getFilesDir().getAbsolutePath() + "/waypoint.sqlite3";
      JSONObject prepared = new JSONObject(prepareBackgroundSync(databasePath));
      if (!prepared.optBoolean("ok", false)) {
        Log.i(TAG, prepared.optString("error", "Background synchronization is unavailable"));
        return prepared.optBoolean("retry", true) ? RESULT_RETRY : RESULT_SUCCESS;
      }

      String endpoint = prepared.getString("endpoint");
      String syncToken = prepared.getString("token");
      JSONObject request = prepared.getJSONObject("request");
      registerPushToken(endpoint, syncToken, request.getString("deviceId"));
      String response = request("POST", new URL(endpoint), syncToken, request.toString());
      JSONObject applied = new JSONObject(applyBackgroundSync(databasePath, response));
      if (!applied.optBoolean("ok", false)) {
        Log.w(TAG, applied.optString("error", "Unable to apply synchronization response"));
        return RESULT_RETRY;
      }
      WaypointWidgetBridge.publishSnapshot(this, applied.getJSONObject("snapshot").toString());
      WaypointNotifications.replaceSchedule(this, applied.getJSONArray("schedule").toString());
      return RESULT_SUCCESS;
    } catch (IOException | JSONException error) {
      Log.w(TAG, "Background synchronization failed", error);
      return RESULT_RETRY;
    }
  }

  private int refreshWidgetSnapshotOnce() {
    try {
      String databasePath = getFilesDir().getAbsolutePath() + "/waypoint.sqlite3";
      JSONObject refreshed = new JSONObject(refreshWidgetSnapshot(databasePath));
      if (!refreshed.optBoolean("ok", false)) {
        Log.w(TAG, refreshed.optString("error", "Unable to refresh the widget snapshot"));
        return RESULT_RETRY;
      }
      WaypointWidgetBridge.publishSnapshot(this, refreshed.getJSONObject("snapshot").toString());
      return RESULT_SUCCESS;
    } catch (JSONException error) {
      Log.w(TAG, "Unable to decode the refreshed widget snapshot", error);
      return RESULT_RETRY;
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
    InputStream responseStream =
        status >= 200 && status < 300 ? connection.getInputStream() : connection.getErrorStream();
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
    try (BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8))) {
      String line;
      while ((line = reader.readLine()) != null) {
        result.append(line);
      }
    }
    return result.toString();
  }

  private static native String prepareBackgroundSync(String databasePath);
  private static native String refreshWidgetSnapshot(String databasePath);
  private static native String applyBackgroundSync(String databasePath, String responsePayload);
}

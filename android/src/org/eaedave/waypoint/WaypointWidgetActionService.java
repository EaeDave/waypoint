package org.eaedave.waypoint;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import androidx.core.app.NotificationCompat;
import org.json.JSONException;
import org.json.JSONObject;
import org.qtproject.qt.android.bindings.QtService;

public final class WaypointWidgetActionService extends QtService {
  static final String EXTRA_COMPLETED = "completed";
  static final String EXTRA_OCCURRENCE_DATE = "occurrenceDate";
  static final String EXTRA_RECURRING = "recurring";
  static final String EXTRA_TASK_ID = "taskId";

  private static final String CHANNEL_ID = "waypoint-widget-actions";
  private static final int NOTIFICATION_ID = -4818;

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    startForeground(NOTIFICATION_ID, foregroundNotification());
    super.onStartCommand(intent, flags, startId);
    try {
      if (intent == null) {
        return START_NOT_STICKY;
      }
      String responsePayload = applyTaskCompletion(
          getFilesDir().getAbsolutePath() + "/waypoint.sqlite3", intent.getStringExtra(EXTRA_TASK_ID),
          intent.getStringExtra(EXTRA_OCCURRENCE_DATE), intent.getBooleanExtra(EXTRA_RECURRING, false),
          intent.getBooleanExtra(EXTRA_COMPLETED, false));
      JSONObject response = new JSONObject(responsePayload);
      if (!response.optBoolean("ok", false)) {
        return START_NOT_STICKY;
      }
      WaypointWidgetBridge.publishSnapshot(this, response.getJSONObject("snapshot").toString());
      WaypointNotifications.replaceSchedule(this, response.getJSONArray("schedule").toString());
      WaypointBackgroundSyncService.start(this);
      if (intent.getBooleanExtra(EXTRA_COMPLETED, false)) {
        WaypointNotifications.playCompletionSound(this);
      }
      return START_NOT_STICKY;
    } catch (JSONException ignored) {
      return START_NOT_STICKY;
    } finally {
      stopForeground(STOP_FOREGROUND_REMOVE);
      stopSelf(startId);
    }
  }

  private android.app.Notification foregroundNotification() {
    if (Build.VERSION.SDK_INT >= 26) {
      NotificationChannel channel =
          new NotificationChannel(CHANNEL_ID, "Ações do widget", NotificationManager.IMPORTANCE_MIN);
      channel.setDescription("Atualizações rápidas iniciadas pelo widget");
      channel.enableVibration(false);
      channel.setShowBadge(false);
      NotificationManager manager = (NotificationManager)getSystemService(Context.NOTIFICATION_SERVICE);
      manager.createNotificationChannel(channel);
    }
    return new NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_popup_sync)
        .setContentTitle("Waypoint")
        .setContentText("Atualizando tarefa")
        .setPriority(NotificationCompat.PRIORITY_MIN)
        .setSilent(true)
        .setOngoing(true)
        .build();
  }

  private static native String applyTaskCompletion(String databasePath, String taskId, String occurrenceDate,
                                                   boolean recurring, boolean completed);
}

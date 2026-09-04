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
  static final String EXTRA_HABIT_AMOUNT = "habitAmount";
  static final String EXTRA_HABIT_DATE = "habitDate";
  static final String EXTRA_HABIT_ID = "habitId";
  static final String EXTRA_OCCURRENCE_DATE = "occurrenceDate";
  static final String EXTRA_RECURRING = "recurring";
  static final String EXTRA_TASK_ID = "taskId";
  static final String EXTRA_TASK_VISIBILITY = "taskVisibility";

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
      boolean habitAction = intent.hasExtra(EXTRA_HABIT_ID);
      boolean visibilityAction = intent.hasExtra(EXTRA_TASK_VISIBILITY);
      String databasePath = getFilesDir().getAbsolutePath() + "/waypoint.sqlite3";
      String responsePayload;
      if (visibilityAction) {
        responsePayload =
            applyTaskVisibility(databasePath, intent.getStringExtra(EXTRA_TASK_VISIBILITY));
      } else if (habitAction) {
        responsePayload = applyHabitCheckIn(databasePath, intent.getStringExtra(EXTRA_HABIT_ID),
                                            intent.getStringExtra(EXTRA_HABIT_DATE),
                                            intent.getLongExtra(EXTRA_HABIT_AMOUNT, 0));
      } else {
        responsePayload = applyTaskCompletion(
            databasePath, intent.getStringExtra(EXTRA_TASK_ID),
            intent.getStringExtra(EXTRA_OCCURRENCE_DATE),
            intent.getBooleanExtra(EXTRA_RECURRING, false),
            intent.getBooleanExtra(EXTRA_COMPLETED, false));
      }
      JSONObject response = new JSONObject(responsePayload);
      if (!response.optBoolean("ok", false)) {
        return START_NOT_STICKY;
      }
      WaypointWidgetBridge.publishSnapshot(this, response.getJSONObject("snapshot").toString());
      WaypointNotifications.replaceSchedule(this, response.getJSONArray("schedule").toString());
      WaypointBackgroundSyncScheduler.requestImmediate(this);
      if (!visibilityAction &&
          (habitAction || intent.getBooleanExtra(EXTRA_COMPLETED, false))) {
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
        .setContentText("Atualizando registro")
        .setPriority(NotificationCompat.PRIORITY_MIN)
        .setSilent(true)
        .setOngoing(true)
        .build();
  }

  private static native String applyTaskCompletion(String databasePath, String taskId, String occurrenceDate,
                                                   boolean recurring, boolean completed);
  private static native String applyTaskVisibility(String databasePath, String taskVisibility);
  private static native String applyHabitCheckIn(String databasePath, String habitId, String date,
                                                 long amount);
}

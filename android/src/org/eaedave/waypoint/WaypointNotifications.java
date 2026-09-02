package org.eaedave.waypoint;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;

import androidx.core.app.NotificationCompat;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.HashSet;
import java.util.Set;

public final class WaypointNotifications {
    static final String EXTRA_BODY = "body";
    static final String EXTRA_NOTIFICATION_ID = "notificationId";
    static final String EXTRA_TITLE = "title";

    private static final String CHANNEL_ID = "waypoint-reminders";
    private static final String PREFERENCES = "waypoint-notifications";
    private static final String SCHEDULE = "schedule";

    private WaypointNotifications() {}

    public static void replaceSchedule(Context context, String payload) {
        try {
            JSONArray incoming = new JSONArray(payload);
            JSONArray enriched = addRequestCodes(incoming);
            cancelStored(context);
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                    .edit()
                    .putString(SCHEDULE, enriched.toString())
                    .apply();
            schedule(context, enriched);
        } catch (JSONException ignored) {
            // Native validation owns the payload. Keep the previous schedule on malformed input.
        }
    }

    public static void rescheduleStored(Context context) {
        String stored = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .getString(SCHEDULE, "[]");
        try {
            schedule(context, new JSONArray(stored));
        } catch (JSONException ignored) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                    .edit()
                    .remove(SCHEDULE)
                    .apply();
        }
    }

    public static void playCompletionSound(Context context) {
        ToneGenerator tone = new ToneGenerator(AudioManager.STREAM_NOTIFICATION, 72);
        tone.startTone(ToneGenerator.TONE_PROP_ACK, 140);
        new Handler(Looper.getMainLooper()).postDelayed(tone::release, 220);
    }

    static void show(Context context, Intent intent) {
        createChannel(context);
        int notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0);
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        PendingIntent launch = launchIntent == null
                ? null
                : PendingIntent.getActivity(
                        context,
                        notificationId,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setContentTitle(intent.getStringExtra(EXTRA_TITLE))
                .setContentText(intent.getStringExtra(EXTRA_BODY))
                .setAutoCancel(true)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setPriority(NotificationCompat.PRIORITY_HIGH);
        if (launch != null) {
            builder.setContentIntent(launch);
        }
        NotificationManager manager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        manager.notify(notificationId, builder.build());
    }

    private static JSONArray addRequestCodes(JSONArray source) throws JSONException {
        JSONArray result = new JSONArray();
        Set<Integer> usedCodes = new HashSet<>();
        for (int index = 0; index < source.length(); ++index) {
            JSONObject item = source.getJSONObject(index);
            int requestCode = item.getString("key").hashCode() & 0x7fffffff;
            while (!usedCodes.add(requestCode)) {
                requestCode = requestCode == Integer.MAX_VALUE ? 0 : requestCode + 1;
            }
            item.put("requestCode", requestCode);
            result.put(item);
        }
        return result;
    }

    private static void cancelStored(Context context) {
        String stored = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .getString(SCHEDULE, "[]");
        try {
            JSONArray schedule = new JSONArray(stored);
            AlarmManager alarmManager =
                    (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            for (int index = 0; index < schedule.length(); ++index) {
                JSONObject item = schedule.getJSONObject(index);
                PendingIntent pending = reminderIntent(context, item);
                alarmManager.cancel(pending);
                pending.cancel();
            }
        } catch (JSONException ignored) {
            // Replacing the preference below repairs malformed state.
        }
    }

    private static void schedule(Context context, JSONArray schedule) throws JSONException {
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        long now = System.currentTimeMillis();
        for (int index = 0; index < schedule.length(); ++index) {
            JSONObject item = schedule.getJSONObject(index);
            long triggerAt = item.getLong("at");
            if (triggerAt <= now) {
                continue;
            }
            PendingIntent pending = reminderIntent(context, item);
            if (Build.VERSION.SDK_INT >= 23) {
                if (Build.VERSION.SDK_INT < 31 || alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending);
                } else {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pending);
                }
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending);
            }
        }
    }

    private static PendingIntent reminderIntent(Context context, JSONObject item) throws JSONException {
        Intent intent = new Intent(context, WaypointReminderReceiver.class)
                .putExtra(EXTRA_NOTIFICATION_ID, item.getInt("requestCode"))
                .putExtra(EXTRA_TITLE, item.getString("title"))
                .putExtra(EXTRA_BODY, item.getString("body"));
        return PendingIntent.getBroadcast(
                context,
                item.getInt("requestCode"),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private static void createChannel(Context context) {
        if (Build.VERSION.SDK_INT < 26) {
            return;
        }
        NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Lembretes",
                NotificationManager.IMPORTANCE_HIGH);
        channel.setDescription("Tarefas e hábitos do Waypoint");
        channel.enableVibration(true);
        NotificationManager manager =
                (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        manager.createNotificationChannel(channel);
    }
}

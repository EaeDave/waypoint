package org.eaedave.waypoint;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.ExistingWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.OutOfQuotaPolicy;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;
import java.util.concurrent.TimeUnit;

public final class WaypointBackgroundSyncScheduler {
  private static final String PREFERENCES = "waypoint-background-sync";
  private static final String ENABLED = "enabled";
  private static final String PERIODIC_WORK = "waypoint-periodic-sync";
  private static final String IMMEDIATE_WORK = "waypoint-immediate-sync";
  private static final String LOCAL_WIDGET_REFRESH_WORK = "waypoint-local-widget-refresh";
  private static final long REPEAT_INTERVAL_MINUTES = 15;
  private static final long RETRY_DELAY_MINUTES = 1;

  private WaypointBackgroundSyncScheduler() {}

  public static void configure(Context context, boolean enabled) {
    Context applicationContext = context.getApplicationContext();
    preferences(applicationContext).edit().putBoolean(ENABLED, enabled).apply();
    WorkManager workManager = WorkManager.getInstance(applicationContext);
    if (!enabled) {
      workManager.cancelUniqueWork(PERIODIC_WORK);
      workManager.cancelUniqueWork(IMMEDIATE_WORK);
      return;
    }

    PeriodicWorkRequest periodicRequest =
        new PeriodicWorkRequest
            .Builder(WaypointBackgroundSyncWorker.class, REPEAT_INTERVAL_MINUTES, TimeUnit.MINUTES)
            .setConstraints(networkConstraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, RETRY_DELAY_MINUTES, TimeUnit.MINUTES)
            .build();
    workManager.enqueueUniquePeriodicWork(PERIODIC_WORK, ExistingPeriodicWorkPolicy.UPDATE, periodicRequest);
  }

  public static void restore(Context context) {
    if (preferences(context).getBoolean(ENABLED, false)) {
      configure(context, true);
    }
  }

  public static void requestImmediate(Context context) {
    Context applicationContext = context.getApplicationContext();
    if (!preferences(applicationContext).getBoolean(ENABLED, false)) {
      return;
    }
    OneTimeWorkRequest request =
        new OneTimeWorkRequest.Builder(WaypointBackgroundSyncWorker.class)
            .setConstraints(networkConstraints())
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, RETRY_DELAY_MINUTES, TimeUnit.MINUTES)
            .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
            .build();
    WorkManager.getInstance(applicationContext)
        .enqueueUniqueWork(IMMEDIATE_WORK, ExistingWorkPolicy.KEEP, request);
  }

  public static void requestLocalWidgetRefresh(Context context) {
    Data input = new Data.Builder()
                     .putString(WaypointBackgroundSyncWorker.OPERATION_KEY,
                                WaypointBackgroundSyncWorker.OPERATION_LOCAL_WIDGET_REFRESH)
                     .build();
    OneTimeWorkRequest request = new OneTimeWorkRequest.Builder(WaypointBackgroundSyncWorker.class)
                                     .setInputData(input)
                                     .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                                     .build();
    WorkManager.getInstance(context.getApplicationContext())
        .enqueueUniqueWork(LOCAL_WIDGET_REFRESH_WORK, ExistingWorkPolicy.KEEP, request);
  }

  private static Constraints networkConstraints() {
    return new Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build();
  }

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
  }
}

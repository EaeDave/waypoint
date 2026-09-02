package org.eaedave.waypoint;

import android.content.Context;
import android.content.SharedPreferences;

final class WaypointPushToken {
  private static final String PREFERENCES = "waypoint-push";
  private static final String TOKEN = "token";
  private static final String REGISTERED_TARGET = "registered-target";

  private WaypointPushToken() {}

  static void update(Context context, String token) {
    if (token == null || token.trim().isEmpty()) {
      return;
    }
    SharedPreferences preferences = preferences(context);
    if (token.equals(preferences.getString(TOKEN, ""))) {
      return;
    }
    preferences.edit().putString(TOKEN, token).remove(REGISTERED_TARGET).apply();
    WaypointBackgroundSyncService.start(context);
  }

  static String current(Context context) {
    return preferences(context).getString(TOKEN, "");
  }

  static boolean needsRegistration(Context context, String target) {
    return !target.equals(preferences(context).getString(REGISTERED_TARGET, ""));
  }

  static void markRegistered(Context context, String target) {
    preferences(context).edit().putString(REGISTERED_TARGET, target).apply();
  }

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
  }
}

package org.eaedave.waypoint;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.HashSet;
import java.util.Set;

final class WaypointWidgetHistoryState {
  private static final String PREFERENCES = "waypoint_widget_history";
  private static final String SECTION = "section";

  private WaypointWidgetHistoryState() {}

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
  }

  private static String entry(String date, String taskId) {
    return date + ":" + (taskId.isEmpty() ? SECTION : "task:" + taskId);
  }

  static boolean isExpanded(Context context, int widgetId, String date, String taskId) {
    return preferences(context).getStringSet(Integer.toString(widgetId), new HashSet<>())
        .contains(entry(date, taskId));
  }

  static void toggle(Context context, int widgetId, String date, String taskId) {
    SharedPreferences preferences = preferences(context);
    String key = Integer.toString(widgetId);
    Set<String> expanded = new HashSet<>(preferences.getStringSet(key, new HashSet<>()));
    String entry = entry(date, taskId);
    if (!expanded.remove(entry)) {
      expanded.add(entry);
    }
    preferences.edit().putStringSet(key, expanded).apply();
  }

  static void remove(Context context, int widgetId) {
    preferences(context).edit().remove(Integer.toString(widgetId)).apply();
  }
}

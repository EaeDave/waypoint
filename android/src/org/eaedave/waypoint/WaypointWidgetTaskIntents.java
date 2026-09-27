package org.eaedave.waypoint;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import org.json.JSONObject;

final class WaypointWidgetTaskIntents {
  static final String EXTRA_TASK = "widgetTask";
  static final String EXTRA_MODE = "widgetTaskMode";
  static final String MODE_TOGGLE = "toggle";
  static final String MODE_EDIT = "edit";

  private WaypointWidgetTaskIntents() {}

  static Intent completionActivity(Context context, int widgetId, JSONObject task, String mode) {
    return new Intent(context, WaypointWidgetCompletionActivity.class)
        .setData(new Uri.Builder().scheme("waypoint").authority("widget")
                     .appendPath(Integer.toString(widgetId)).appendPath("completion")
                     .appendPath(task.optString("taskId", ""))
                     .appendPath(task.optString("occurrenceDate", "")).appendPath(mode).build())
        .putExtra(EXTRA_TASK, task.toString())
        .putExtra(EXTRA_MODE, mode)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
  }

  static PendingIntent completion(Context context, int widgetId, JSONObject task, String mode) {
    // The launcher starts the Activity directly. A service/receiver trampoline loses BAL privileges.
    return PendingIntent.getActivity(context, 0, completionActivity(context, widgetId, task, mode),
                                     PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  static Intent completionService(Context context, JSONObject task, boolean completed, String completedDate) {
    return new Intent(context, WaypointWidgetActionService.class)
        .putExtra(WaypointWidgetActionService.EXTRA_TASK_ID, task.optString("taskId", ""))
        .putExtra(WaypointWidgetActionService.EXTRA_OCCURRENCE_DATE, task.optString("occurrenceDate", ""))
        .putExtra(WaypointWidgetActionService.EXTRA_RECURRING, task.optBoolean("recurring", false))
        .putExtra(WaypointWidgetActionService.EXTRA_COMPLETED, completed)
        .putExtra(WaypointWidgetActionService.EXTRA_COMPLETED_DATE, completed ? completedDate : "")
        .putExtra(WaypointWidgetActionService.EXTRA_EDITING, task.optBoolean("completed", false));
  }
}

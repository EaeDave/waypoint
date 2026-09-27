package org.eaedave.waypoint;

import android.graphics.Color;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import org.json.JSONObject;

final class WaypointWidgetTaskText {
  static final int NEUTRAL = Color.rgb(174, 178, 191);
  static final int AMBER = Color.rgb(232, 189, 117);
  static final int URGENT = Color.rgb(179, 117, 128);
  private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd/MM/yyyy");

  private WaypointWidgetTaskText() {}

  static String title(JSONObject task) {
    String emoji = task.optString("emoji", "").trim();
    return (emoji.isEmpty() ? "" : emoji + "  ") + task.optString("title", "Tarefa");
  }

  static String metadata(JSONObject task, boolean historyChild) {
    String label = task.optString("scheduledTime", "");
    if (historyChild) {
      LocalDate due = WaypointWidgetCompletionState.parseDate(task.optString("occurrenceDate", ""));
      label = append("PREVISTA " + (due == null ? task.optString("occurrenceDate", "") : due.format(DATE)), label);
    }
    if (task.optBoolean("completed", false)) {
      label = append(label, task.optString("completionLabel", "CONCLUÍDA"));
    } else if (task.optBoolean("skipped", false)) {
      label = append(label, "NÃO FEITA");
    } else if (task.optBoolean("overdue", false)) {
      label = append(label, "ATRASADA");
    }
    return append(label, task.optString("categoryName", ""));
  }

  static int metadataColor(JSONObject task) {
    if (task.optBoolean("completed", false)) {
      return task.optBoolean("completionLate", false) ? AMBER : NEUTRAL;
    }
    return task.optBoolean("skipped", false) || task.optBoolean("overdue", false) ? URGENT : NEUTRAL;
  }

  private static String append(String before, String after) {
    return after.isEmpty() ? before : before.isEmpty() ? after : before + " · " + after;
  }
}

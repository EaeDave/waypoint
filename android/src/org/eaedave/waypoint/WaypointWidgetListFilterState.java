package org.eaedave.waypoint;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.HashSet;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;

final class WaypointWidgetListFilterState {
  private static final String PREFERENCES = "waypoint_widget_list_filter";

  private WaypointWidgetListFilterState() {}

  private static SharedPreferences preferences(Context context) {
    return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
  }

  // Absent means all current and future lists; an explicitly empty set means none.
  static Set<String> read(Context context, int widgetId) {
    Set<String> ids = preferences(context).getStringSet(Integer.toString(widgetId), null);
    return ids == null ? null : new HashSet<>(ids);
  }

  static void set(Context context, int widgetId, Set<String> ids) {
    preferences(context).edit().putStringSet(Integer.toString(widgetId), new HashSet<>(ids)).apply();
  }

  static void clear(Context context, int widgetId) {
    preferences(context).edit().remove(Integer.toString(widgetId)).apply();
  }

  static Set<String> availableIds(JSONArray categories) {
    Set<String> ids = new HashSet<>();
    ids.add("");
    for (int index = 0; categories != null && index < categories.length(); ++index) {
      JSONObject category = categories.optJSONObject(index);
      if (category != null) {
        ids.add(category.optString("id", ""));
      }
    }
    return ids;
  }

  static String categoryId(JSONObject value) {
    return value.isNull("categoryId") ? "" : value.optString("categoryId", "");
  }

  static JSONArray filter(JSONArray values, Set<String> ids) {
    if (values == null || ids == null) {
      return values;
    }
    JSONArray visible = new JSONArray();
    for (int index = 0; index < values.length(); ++index) {
      JSONObject value = values.optJSONObject(index);
      if (value != null && ids.contains(categoryId(value))) {
        visible.put(value);
      }
    }
    return visible;
  }

  static String label(Set<String> ids, JSONArray categories) {
    if (ids == null) {
      return "Listas: Todas";
    }
    if (ids.size() != 1) {
      return "Listas: " + ids.size();
    }
    String id = ids.iterator().next();
    if (id.isEmpty()) {
      return "Listas: Entrada";
    }
    for (int index = 0; categories != null && index < categories.length(); ++index) {
      JSONObject category = categories.optJSONObject(index);
      if (category != null && id.equals(category.optString("id", ""))) {
        return "Listas: " + category.optString("name", "Lista");
      }
    }
    return "Listas: 1 (indisponível)";
  }

  static String emptyText(Set<String> ids) {
    return ids != null && ids.isEmpty()
        ? "Nenhuma lista selecionada. Mostrar todas"
        : "Nenhuma tarefa nas listas selecionadas. Mostrar todas";
  }
}

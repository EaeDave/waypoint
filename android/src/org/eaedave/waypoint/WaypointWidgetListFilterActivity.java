package org.eaedave.waypoint;

import android.app.Activity;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import androidx.core.content.ContextCompat;
import java.util.Collections;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;

public final class WaypointWidgetListFilterActivity extends Activity {
  private int widgetId = AppWidgetManager.INVALID_APPWIDGET_ID;
  private ScrollView scroll;
  private LinearLayout content;
  private final BroadcastReceiver snapshotChanged = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      render();
    }
  };

  static PendingIntent pendingIntent(Context context, int widgetId) {
    Intent intent = new Intent(context, WaypointWidgetListFilterActivity.class)
        .setData(new Uri.Builder().scheme("waypoint").authority("widget")
                     .appendPath(Integer.toString(widgetId)).appendPath("lists").build())
        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    return PendingIntent.getActivity(context, 0, intent,
        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    widgetId = getIntent().getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);
    if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
      finish();
      return;
    }
    scroll = new ScrollView(this);
    content = new LinearLayout(this);
    content.setOrientation(LinearLayout.VERTICAL);
    content.setPadding(dp(16), dp(12), dp(16), dp(12));
    scroll.addView(content);
    setContentView(scroll);
  }

  @Override
  protected void onResume() {
    super.onResume();
    if (content == null) {
      return;
    }
    ContextCompat.registerReceiver(this, snapshotChanged,
        new IntentFilter(WaypointWidgetBridge.ACTION_SNAPSHOT_CHANGED), ContextCompat.RECEIVER_NOT_EXPORTED);
    render();
  }

  @Override
  protected void onPause() {
    if (content != null) {
      unregisterReceiver(snapshotChanged);
    }
    super.onPause();
  }

  private void render() {
    int scrollY = scroll.getScrollY();
    content.removeAllViews();
    JSONObject snapshot = WaypointWidgetProvider.snapshot(this);
    JSONArray categories = snapshot.optJSONArray("taskCategories");
    Set<String> selected = WaypointWidgetListFilterState.read(this, widgetId);
    TextView title = new TextView(this);
    title.setText(WaypointWidgetListFilterState.label(selected, categories));
    title.setTextSize(18);
    title.setTextColor(selected == null ? Color.WHITE : Color.rgb(151, 159, 236));
    content.addView(title);
    Button reset = new Button(this);
    reset.setText("Mostrar todas");
    reset.setAllCaps(false);
    reset.setOnClickListener(view -> {
      WaypointWidgetListFilterState.clear(this, widgetId);
      changed();
    });
    content.addView(reset);
    addRow("", "Entrada", "#979FEC", selected, categories);
    for (int index = 0; categories != null && index < categories.length(); ++index) {
      JSONObject category = categories.optJSONObject(index);
      if (category != null && !category.optString("id", "").isEmpty()) {
        addRow(category.optString("id"), category.optString("name"), category.optString("color"),
               selected, categories);
      }
    }
    if (snapshot.optInt("schemaVersion", 0) < 10) {
      TextView refreshing = new TextView(this);
      refreshing.setText("Atualizando listas…");
      content.addView(refreshing);
      WaypointBackgroundSyncScheduler.requestLocalWidgetRefresh(this);
    }
    Button close = new Button(this);
    close.setText("Fechar");
    close.setAllCaps(false);
    close.setOnClickListener(view -> finish());
    content.addView(close);
    scroll.post(() -> scroll.scrollTo(0, scrollY));
  }

  private void addRow(String id, String name, String color, Set<String> selected, JSONArray categories) {
    LinearLayout row = new LinearLayout(this);
    row.setGravity(Gravity.CENTER_VERTICAL);
    TextView swatch = new TextView(this);
    swatch.setText("●");
    swatch.setTextSize(18);
    swatch.setImportantForAccessibility(android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO);
    swatch.setTextColor(WaypointWidgetProvider.colorValue(color, Color.rgb(151, 159, 236)));
    row.addView(swatch);
    CheckBox choice = new CheckBox(this);
    choice.setText(name);
    choice.setChecked(selected == null || selected.contains(id));
    choice.setMinHeight(dp(48));
    choice.setOnCheckedChangeListener((button, checked) -> {
      Set<String> ids = WaypointWidgetListFilterState.read(this, widgetId);
      if (ids == null) {
        ids = WaypointWidgetListFilterState.availableIds(categories);
      }
      if (checked) {
        ids.add(id);
      } else {
        ids.remove(id);
      }
      WaypointWidgetListFilterState.set(this, widgetId, ids);
      changed();
    });
    row.addView(choice, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
    Button only = new Button(this);
    only.setText("Somente");
    only.setAllCaps(false);
    only.setContentDescription("Mostrar somente " + name);
    only.setOnClickListener(view -> {
      WaypointWidgetListFilterState.set(this, widgetId, Collections.singleton(id));
      changed();
    });
    row.addView(only);
    content.addView(row);
  }

  private void changed() {
    WaypointWidgetProvider.updateAll(this);
    render();
  }

  private int dp(int value) {
    return Math.round(value * getResources().getDisplayMetrics().density);
  }
}

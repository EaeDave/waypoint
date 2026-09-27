package org.eaedave.waypoint;

import android.app.Activity;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.content.Context;
import android.content.Intent;
import android.content.BroadcastReceiver;
import android.content.IntentFilter;
import androidx.core.content.ContextCompat;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import org.json.JSONArray;
import org.json.JSONObject;

public final class WaypointWidgetHistoryActivity extends Activity {
  static final String EXTRA_DATE = "historyDate";
  private int widgetId;
  private String date;
  private ScrollView scroll;
  private LinearLayout content;
  private final BroadcastReceiver snapshotChanged = new BroadcastReceiver() {
    @Override
    public void onReceive(Context context, Intent intent) {
      render();
    }
  };

  static PendingIntent pendingIntent(Context context, int widgetId, String date) {
    Intent intent = new Intent(context, WaypointWidgetHistoryActivity.class)
                        .setData(new Uri.Builder().scheme("waypoint").authority("widget")
                                     .appendPath(Integer.toString(widgetId)).appendPath("history")
                                     .appendPath(date).build())
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                        .putExtra(EXTRA_DATE, date)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    return PendingIntent.getActivity(context, 0, intent,
                                     PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    widgetId = getIntent().getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);
    LocalDate selected = WaypointWidgetCompletionState.parseDate(getIntent().getStringExtra(EXTRA_DATE));
    if (selected == null || widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
      finish();
      return;
    }
    date = selected.toString();
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
    if (date == null) {
      return;
    }
    ContextCompat.registerReceiver(this, snapshotChanged,
        new IntentFilter(WaypointWidgetBridge.ACTION_SNAPSHOT_CHANGED), ContextCompat.RECEIVER_NOT_EXPORTED);
    render();
  }

  @Override
  protected void onPause() {
    if (date != null) {
      unregisterReceiver(snapshotChanged);
    }
    super.onPause();
  }


  private void render() {
    int scrollY = scroll.getScrollY();
    content.removeAllViews();
    addText("Waypoint · " + LocalDate.parse(date).format(DateTimeFormatter.ofPattern("dd/MM/yyyy")), Color.WHITE);
    JSONObject snapshot = WaypointWidgetProvider.snapshot(this);
    if (!LocalDate.now().toString().equals(snapshot.optString("today", "")) ||
        snapshot.optInt("schemaVersion", 0) < 9) {
      addText("Atualizando registros…", WaypointWidgetTaskText.NEUTRAL);
      WaypointBackgroundSyncScheduler.requestLocalWidgetRefresh(this);
    } else {
      JSONObject dates = snapshot.optJSONObject("dates");
      JSONObject day = dates == null ? null : dates.optJSONObject(date);
      JSONArray tasks = day == null ? null : day.optJSONArray("tasks");
      addText("TAREFAS", WaypointWidgetTaskText.NEUTRAL);
      if (tasks == null || tasks.length() == 0) {
        addText("Nenhuma tarefa para este dia.", WaypointWidgetTaskText.NEUTRAL);
      }
      for (int index = 0; tasks != null && index < tasks.length(); ++index) {
        JSONObject task = tasks.optJSONObject(index);
        if (task != null) {
          addTask(task, false);
        }
      }
      addHistory(day == null ? null : day.optJSONArray("registrationActivity"));
    }
    Button close = addButton("Fechar");
    close.setOnClickListener(view -> finish());
    scroll.post(() -> scroll.scrollTo(0, scrollY));
  }

  private void addHistory(JSONArray groups) {
    if (groups == null || groups.length() == 0) {
      return;
    }
    boolean expanded = WaypointWidgetHistoryState.isExpanded(this, widgetId, date, "");
    Button section = addButton((expanded ? "▾ " : "▸ ") + "CONCLUSÕES REGISTRADAS · " + groups.length());
    section.setContentDescription((expanded ? "Recolher" : "Expandir") + " conclusões registradas neste dia");
    section.setOnClickListener(view -> toggle(""));
    if (!expanded) {
      return;
    }
    for (int index = 0; index < groups.length(); ++index) {
      JSONObject group = groups.optJSONObject(index);
      if (group == null) {
        continue;
      }
      String taskId = group.optString("taskId", "");
      boolean groupExpanded = WaypointWidgetHistoryState.isExpanded(this, widgetId, date, taskId);
      Button title = addButton((groupExpanded ? "▾ " : "▸ ") + WaypointWidgetTaskText.title(group) + " · " +
                               group.optInt("count", 0) + "\n" + group.optString("dateSummary", ""));
      title.setContentDescription((groupExpanded ? "Recolher " : "Expandir ") + title.getText());
      title.setOnClickListener(view -> toggle(taskId));
      JSONArray children = group.optJSONArray("occurrences");
      for (int child = 0; groupExpanded && children != null && child < children.length(); ++child) {
        JSONObject task = children.optJSONObject(child);
        if (task != null) {
          addTask(task, true);
        }
      }
    }
  }

  private void toggle(String taskId) {
    WaypointWidgetHistoryState.toggle(this, widgetId, date, taskId);
    WaypointWidgetProvider.updateAll(this);
    render();
  }

  private void addTask(JSONObject task, boolean historyChild) {
    addText(WaypointWidgetTaskText.title(task), task.optBoolean("completed", false)
                                                 ? WaypointWidgetTaskText.NEUTRAL : Color.WHITE);
    addText(WaypointWidgetTaskText.metadata(task, historyChild), WaypointWidgetTaskText.metadataColor(task));
    LinearLayout actions = new LinearLayout(this);
    content.addView(actions);
    Button toggle = new Button(this);
    toggle.setText(task.optBoolean("completed", false) ? "Desfazer conclusão"
                   : task.optBoolean("skipped", false) ? "Reabrir" : "Concluir");
    toggle.setOnClickListener(view -> startActivity(WaypointWidgetTaskIntents.completionActivity(
        this, widgetId, task, WaypointWidgetTaskIntents.MODE_TOGGLE)));
    actions.addView(toggle, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
    if (task.optBoolean("completed", false)) {
      Button edit = new Button(this);
      edit.setText("Alterar data");
      edit.setContentDescription("Alterar data da conclusão de " + WaypointWidgetTaskText.title(task));
      edit.setOnClickListener(view -> startActivity(WaypointWidgetTaskIntents.completionActivity(
          this, widgetId, task, WaypointWidgetTaskIntents.MODE_EDIT)));
      actions.addView(edit, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));
    }
  }

  private void addText(String value, int color) {
    TextView text = new TextView(this);
    text.setText(value);
    text.setTextColor(color);
    text.setTextSize(13);
    text.setPadding(0, dp(6), 0, dp(6));
    content.addView(text);
  }

  private Button addButton(String label) {
    Button button = new Button(this);
    button.setText(label);
    button.setAllCaps(false);
    content.addView(button);
    return button;
  }

  private int dp(int value) {
    return Math.round(value * getResources().getDisplayMetrics().density);
  }
}

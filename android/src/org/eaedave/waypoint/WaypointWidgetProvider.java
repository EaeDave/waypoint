package org.eaedave.waypoint;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.StrikethroughSpan;
import android.view.View;
import android.widget.RemoteViews;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.time.temporal.TemporalAdjusters;
import java.util.Locale;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public final class WaypointWidgetProvider extends AppWidgetProvider {
  private static final String ACTION_MOVE_MONTH = "org.eaedave.waypoint.widget.MOVE_MONTH";
  private static final String ACTION_SELECT_DATE = "org.eaedave.waypoint.widget.SELECT_DATE";
  private static final String EXTRA_MONTH_DELTA = "monthDelta";
  private static final String EXTRA_DATE = "date";
  private static final String STATE_PREFERENCES = "waypoint_widget_state";
  private static final String SELECTED_DATE_PREFIX = "selectedDate:";
  private static final Locale PORTUGUESE = Locale.forLanguageTag("pt-BR");
  private static final DateTimeFormatter DATE_LABEL =
      DateTimeFormatter.ofPattern("EEE, d 'de' MMM", PORTUGUESE);
  private static final int COLOR_FOREGROUND = Color.rgb(255, 255, 255);
  private static final int COLOR_SUBDUED = Color.argb(148, 255, 255, 255);
  private static final int COLOR_DISABLED = Color.argb(69, 255, 255, 255);
  private static final int COLOR_ACCENT = Color.rgb(151, 159, 236);
  private static final int COLOR_URGENT = Color.rgb(179, 117, 128);
  private static final int COLOR_HOLIDAY = Color.rgb(232, 189, 117);
  private static final int[] DAY_IDS = {
      R.id.widget_day_0,  R.id.widget_day_1,  R.id.widget_day_2,  R.id.widget_day_3,  R.id.widget_day_4,
      R.id.widget_day_5,  R.id.widget_day_6,  R.id.widget_day_7,  R.id.widget_day_8,  R.id.widget_day_9,
      R.id.widget_day_10, R.id.widget_day_11, R.id.widget_day_12, R.id.widget_day_13, R.id.widget_day_14,
      R.id.widget_day_15, R.id.widget_day_16, R.id.widget_day_17, R.id.widget_day_18, R.id.widget_day_19,
      R.id.widget_day_20, R.id.widget_day_21, R.id.widget_day_22, R.id.widget_day_23, R.id.widget_day_24,
      R.id.widget_day_25, R.id.widget_day_26, R.id.widget_day_27, R.id.widget_day_28, R.id.widget_day_29,
      R.id.widget_day_30, R.id.widget_day_31, R.id.widget_day_32, R.id.widget_day_33, R.id.widget_day_34,
      R.id.widget_day_35, R.id.widget_day_36, R.id.widget_day_37, R.id.widget_day_38, R.id.widget_day_39,
      R.id.widget_day_40, R.id.widget_day_41};
  private static final int[] TASK_ROW_IDS = {R.id.widget_task_row_0, R.id.widget_task_row_1,
                                             R.id.widget_task_row_2, R.id.widget_task_row_3};
  private static final int[] TASK_STATUS_IDS = {R.id.widget_task_status_0, R.id.widget_task_status_1,
                                                R.id.widget_task_status_2, R.id.widget_task_status_3};
  private static final int[] TASK_TITLE_IDS = {R.id.widget_task_title_0, R.id.widget_task_title_1,
                                               R.id.widget_task_title_2, R.id.widget_task_title_3};
  private static final int[] TASK_TIME_IDS = {R.id.widget_task_time_0, R.id.widget_task_time_1,
                                              R.id.widget_task_time_2, R.id.widget_task_time_3};
  private static final int[] HABIT_ROW_IDS = {R.id.widget_habit_row_0, R.id.widget_habit_row_1,
                                              R.id.widget_habit_row_2, R.id.widget_habit_row_3};
  private static final int[] HABIT_TITLE_IDS = {R.id.widget_habit_title_0, R.id.widget_habit_title_1,
                                                R.id.widget_habit_title_2, R.id.widget_habit_title_3};
  private static final int[] HABIT_PROGRESS_IDS = {R.id.widget_habit_progress_0,
                                                   R.id.widget_habit_progress_1,
                                                   R.id.widget_habit_progress_2,
                                                   R.id.widget_habit_progress_3};
  private static final int[] HABIT_ACTION_IDS = {R.id.widget_habit_action_0, R.id.widget_habit_action_1,
                                                 R.id.widget_habit_action_2, R.id.widget_habit_action_3};

  @Override
  public void onEnabled(Context context) {
    WaypointBackgroundSyncScheduler.requestImmediate(context);
  }

  @Override
  public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
    for (int appWidgetId : appWidgetIds) {
      updateWidget(context, appWidgetManager, appWidgetId);
    }
  }

  @Override
  public void onAppWidgetOptionsChanged(Context context, AppWidgetManager appWidgetManager, int appWidgetId,
                                        Bundle newOptions) {
    updateWidget(context, appWidgetManager, appWidgetId);
  }

  @Override
  public void onDeleted(Context context, int[] appWidgetIds) {
    SharedPreferences.Editor editor = state(context).edit();
    for (int appWidgetId : appWidgetIds) {
      editor.remove(SELECTED_DATE_PREFIX + appWidgetId);
    }
    editor.apply();
  }

  @Override
  public void onReceive(Context context, Intent intent) {
    String action = intent.getAction();
    if (ACTION_MOVE_MONTH.equals(action)) {
      int appWidgetId =
          intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);
      int delta = intent.getIntExtra(EXTRA_MONTH_DELTA, 0);
      moveMonth(context, appWidgetId, delta);
      return;
    }
    if (ACTION_SELECT_DATE.equals(action)) {
      int appWidgetId =
          intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID);
      selectDate(context, appWidgetId, intent.getStringExtra(EXTRA_DATE));
      return;
    }
    if (Intent.ACTION_DATE_CHANGED.equals(action) || Intent.ACTION_TIME_CHANGED.equals(action) ||
        Intent.ACTION_TIMEZONE_CHANGED.equals(action)) {
      updateAll(context);
      return;
    }
    super.onReceive(context, intent);
  }

  public static void updateAll(Context context) {
    AppWidgetManager manager = AppWidgetManager.getInstance(context);
    ComponentName provider = new ComponentName(context, WaypointWidgetProvider.class);
    int[] appWidgetIds = manager.getAppWidgetIds(provider);
    for (int appWidgetId : appWidgetIds) {
      updateWidget(context, manager, appWidgetId);
    }
  }

  private static void updateWidget(Context context, AppWidgetManager manager, int appWidgetId) {
    LocalDate today = LocalDate.now();
    LocalDate selectedDate = selectedDate(context, appWidgetId, today);
    JSONObject snapshot = snapshot(context);
    JSONObject dates = snapshot.optJSONObject("dates");
    if (dates == null) {
      dates = new JSONObject();
    }
    JSONArray habits = snapshot.optJSONArray("habits");
    RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.waypoint_widget);
    int[] detailLimits =
        detailLimits(context, manager, appWidgetId, selectedDate.equals(today) && habits != null);

    renderCalendar(context, views, appWidgetId, selectedDate, today, dates);
    renderTasks(context, views, appWidgetId, selectedDate, dates, detailLimits[0]);
    renderHabits(context, views, appWidgetId, habits, detailLimits[1]);

    PendingIntent openApp = openAppIntent(context, appWidgetId);
    views.setOnClickPendingIntent(R.id.widget_root, null);
    views.setOnClickPendingIntent(R.id.widget_month_title, openApp);
    views.setOnClickPendingIntent(R.id.widget_add_task, openApp);
    views.setOnClickPendingIntent(R.id.widget_previous_month, moveMonthIntent(context, appWidgetId, -1));
    views.setOnClickPendingIntent(R.id.widget_next_month, moveMonthIntent(context, appWidgetId, 1));
    manager.updateAppWidget(appWidgetId, views);
  }

  private static void renderCalendar(Context context, RemoteViews views, int appWidgetId,
                                     LocalDate selectedDate, LocalDate today, JSONObject dates) {
    YearMonth displayedMonth = YearMonth.from(selectedDate);
    String monthName =
        displayedMonth.getMonth().getDisplayName(TextStyle.FULL, PORTUGUESE).toUpperCase(PORTUGUESE);
    views.setTextViewText(R.id.widget_month_title, monthName + "  " + displayedMonth.getYear());

    LocalDate firstCell = displayedMonth.atDay(1).with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
    for (int index = 0; index < DAY_IDS.length; ++index) {
      LocalDate date = firstCell.plusDays(index);
      JSONObject dateData = dates.optJSONObject(date.toString());
      JSONArray dateTasks = dateData == null ? null : dateData.optJSONArray("tasks");
      boolean hasTasks = dateTasks != null && dateTasks.length() > 0;
      boolean hasSkippedTasks = false;
      for (int taskIndex = 0; dateTasks != null && taskIndex < dateTasks.length(); ++taskIndex) {
        JSONObject task = dateTasks.optJSONObject(taskIndex);
        hasSkippedTasks = hasSkippedTasks || task != null && task.optBoolean("skipped", false);
      }
      boolean hasHolidays = dateData != null && dateData.optJSONArray("holidays") != null &&
                            dateData.optJSONArray("holidays").length() > 0;
      String markers = (hasSkippedTasks ? "×" : hasTasks ? "•" : "") + (hasHolidays ? "◆" : "");
      String label = Integer.toString(date.getDayOfMonth());
      if (!markers.isEmpty()) {
        label += "\n" + markers;
      }

      int dayId = DAY_IDS[index];
      boolean selected = date.equals(selectedDate);
      int color = date.getMonth() == displayedMonth.getMonth() ? COLOR_SUBDUED : COLOR_DISABLED;
      if (hasHolidays) {
        color = COLOR_HOLIDAY;
      }
      if (date.equals(today)) {
        color = COLOR_ACCENT;
      }
      if (selected) {
        color = COLOR_FOREGROUND;
      }
      views.setTextViewText(dayId, label);
      views.setTextColor(dayId, color);
      views.setInt(dayId, "setBackgroundResource",
                   selected ? R.drawable.waypoint_widget_selected_day : android.R.color.transparent);
      views.setOnClickPendingIntent(dayId, selectDateIntent(context, appWidgetId, date, index));
    }
  }

  private static int[] detailLimits(Context context, AppWidgetManager manager, int appWidgetId,
                                    boolean includeHabits) {
    Bundle options = manager.getAppWidgetOptions(appWidgetId);
    String heightOption = context.getResources().getConfiguration().orientation ==
                                  android.content.res.Configuration.ORIENTATION_LANDSCAPE
                              ? AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
                              : AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT;
    int availableHeight = options.getInt(heightOption, 455);
    if (includeHabits) {
      if (availableHeight >= 676) {
        return new int[] {4, 4};
      }
      if (availableHeight >= 580) {
        return new int[] {3, 3};
      }
      if (availableHeight >= 494) {
        return new int[] {2, 2};
      }
      if (availableHeight >= 413) {
        return new int[] {1, 1};
      }
    }
    if (availableHeight >= 500) {
      return new int[] {4, 0};
    }
    if (availableHeight >= 440) {
      return new int[] {3, 0};
    }
    if (availableHeight >= 390) {
      return new int[] {2, 0};
    }
    if (availableHeight >= 345) {
      return new int[] {1, 0};
    }
    return new int[] {0, 0};
  }

  private static void renderTasks(Context context, RemoteViews views, int appWidgetId,
                                  LocalDate selectedDate, JSONObject dates, int taskLimit) {
    String dateLabel = selectedDate.format(DATE_LABEL);
    views.setTextViewText(R.id.widget_selected_date,
                          dateLabel.substring(0, 1).toUpperCase(PORTUGUESE) + dateLabel.substring(1));

    boolean showDetails = taskLimit > 0;
    JSONObject dateData = dates.optJSONObject(selectedDate.toString());
    int holidayCount = renderHolidays(views, dateData, showDetails);
    taskLimit = Math.max(0, taskLimit - Math.min(holidayCount, 3));
    views.setViewVisibility(R.id.widget_tasks_header, showDetails ? View.VISIBLE : View.GONE);

    JSONArray tasks = dateData == null ? null : dateData.optJSONArray("tasks");
    int taskCount = tasks == null ? 0 : tasks.length();
    boolean hasSnapshot = hasSnapshot(context);
    views.setTextViewText(R.id.widget_empty_tasks, hasSnapshot
                                                       ? "Nada marcado para este dia."
                                                       : "Abra o Waypoint para carregar suas tarefas.");
    views.setViewVisibility(R.id.widget_empty_tasks,
                            showDetails && taskCount == 0 && holidayCount == 0 ? View.VISIBLE : View.GONE);

    PendingIntent openApp = openAppIntent(context, appWidgetId);
    for (int index = 0; index < TASK_ROW_IDS.length; ++index) {
      if (index >= taskLimit || index >= taskCount) {
        views.setViewVisibility(TASK_ROW_IDS[index], View.GONE);
        continue;
      }
      JSONObject task = tasks.optJSONObject(index);
      if (task == null) {
        views.setViewVisibility(TASK_ROW_IDS[index], View.GONE);
        continue;
      }
      boolean completed = task.optBoolean("completed", false);
      boolean skipped = task.optBoolean("skipped", false);
      boolean overdue = task.optBoolean("overdue", false);
      String emoji = task.optString("emoji", "").trim();
      String title = task.optString("title", "Tarefa");
      if (!emoji.isEmpty()) {
        title = emoji + "  " + title;
      }
      CharSequence titleText = title;
      if (completed) {
        SpannableString struck = new SpannableString(title);
        struck.setSpan(new StrikethroughSpan(), 0, title.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
        titleText = struck;
      }
      String time = task.optString("scheduledTime", "");
      if (skipped) {
        time = time.isEmpty() ? "NÃO FEITA" : time + " · NÃO FEITA";
      } else if (overdue) {
        time = time.isEmpty() ? "ATRASADA" : time + " · ATRASADA";
      }

      views.setViewVisibility(TASK_ROW_IDS[index], View.VISIBLE);
      int statusResource = completed ? R.drawable.waypoint_widget_task_completed
                                     : skipped ? R.drawable.waypoint_widget_task_skipped
                                               : R.drawable.waypoint_widget_task_pending;
      views.setImageViewResource(TASK_STATUS_IDS[index], statusResource);
      views.setTextViewText(TASK_TITLE_IDS[index], titleText);
      views.setTextColor(TASK_TITLE_IDS[index],
                         completed ? COLOR_DISABLED : skipped ? COLOR_URGENT : COLOR_FOREGROUND);
      views.setTextViewText(TASK_TIME_IDS[index], time);
      views.setTextColor(TASK_TIME_IDS[index], skipped || overdue ? COLOR_URGENT : COLOR_SUBDUED);
      views.setOnClickPendingIntent(TASK_ROW_IDS[index], openApp);
      views.setOnClickPendingIntent(
          TASK_STATUS_IDS[index],
          taskCompletionIntent(context, appWidgetId, task, index, !completed && !skipped));
    }
  }

  private static void renderHabits(Context context, RemoteViews views, int appWidgetId,
                                   JSONArray habits, int habitLimit) {
    boolean showHabits = habitLimit > 0;
    views.setViewVisibility(R.id.widget_habits_divider, showHabits ? View.VISIBLE : View.GONE);
    views.setViewVisibility(R.id.widget_habits_header, showHabits ? View.VISIBLE : View.GONE);
    int habitCount = habits == null ? 0 : habits.length();
    views.setViewVisibility(R.id.widget_empty_habits,
                            showHabits && habitCount == 0 ? View.VISIBLE : View.GONE);

    PendingIntent openApp = openAppIntent(context, appWidgetId);
    for (int index = 0; index < HABIT_ROW_IDS.length; ++index) {
      if (index >= habitLimit || index >= habitCount) {
        views.setViewVisibility(HABIT_ROW_IDS[index], View.GONE);
        continue;
      }
      JSONObject habit = habits.optJSONObject(index);
      if (habit == null) {
        views.setViewVisibility(HABIT_ROW_IDS[index], View.GONE);
        continue;
      }

      boolean completed = habit.optBoolean("completed", false);
      String emoji = habit.optString("emoji", "").trim();
      String title = habit.optString("title", "Hábito");
      if (!emoji.isEmpty()) {
        title = emoji + "  " + title;
      }
      long amount = habit.optLong("amount", 0);
      long target = habit.optLong("targetAmount", 1);
      String unit = habit.optString("unit", "").trim();
      String progress = amount + " / " + target + (unit.isEmpty() ? "" : " " + unit);
      String checkInMode = habit.optString("checkInMode", "complete");
      long actionAmount = "manual".equals(checkInMode) ? 1 : 0;
      String actionLabel;
      if (completed) {
        actionLabel = "FEITO";
      } else if ("fixed".equals(checkInMode)) {
        long increment = habit.optLong("incrementAmount", 1);
        actionLabel = "+" + increment + (unit.isEmpty() ? "" : " " + unit);
      } else if ("manual".equals(checkInMode)) {
        actionLabel = "+1" + (unit.isEmpty() ? "" : " " + unit);
      } else {
        actionLabel = "CONCLUIR";
      }

      views.setViewVisibility(HABIT_ROW_IDS[index], View.VISIBLE);
      views.setTextViewText(HABIT_TITLE_IDS[index], title);
      views.setTextColor(HABIT_TITLE_IDS[index], completed ? COLOR_DISABLED : COLOR_FOREGROUND);
      views.setTextViewText(HABIT_PROGRESS_IDS[index], progress);
      views.setTextColor(HABIT_PROGRESS_IDS[index], completed ? COLOR_ACCENT : COLOR_SUBDUED);
      views.setTextViewText(HABIT_ACTION_IDS[index], actionLabel);
      views.setTextColor(HABIT_ACTION_IDS[index], completed ? COLOR_DISABLED : COLOR_FOREGROUND);
      views.setInt(HABIT_ACTION_IDS[index], "setBackgroundResource",
                   completed ? android.R.color.transparent : R.drawable.waypoint_widget_selected_day);
      views.setOnClickPendingIntent(HABIT_ROW_IDS[index], openApp);
      views.setOnClickPendingIntent(
          HABIT_ACTION_IDS[index],
          completed ? null : habitCheckInIntent(context, appWidgetId, habit, index, actionAmount));
    }
  }

  private static int renderHolidays(RemoteViews views, JSONObject dateData, boolean showDetails) {
    JSONArray holidays = dateData == null ? null : dateData.optJSONArray("holidays");
    if (!showDetails || holidays == null || holidays.length() == 0) {
      views.setViewVisibility(R.id.widget_holidays, View.GONE);
      return 0;
    }

    StringBuilder text = new StringBuilder();
    int displayedCount = 0;
    for (int index = 0; index < holidays.length() && displayedCount < 3; ++index) {
      JSONObject holiday = holidays.optJSONObject(index);
      if (holiday == null) {
        continue;
      }
      String name = holiday.optString("name", holiday.optString("title", "")).trim();
      if (name.isEmpty()) {
        continue;
      }
      if (displayedCount > 0) {
        text.append('\n');
      }
      text.append(holidayKindLabel(holiday.optString("kind", ""), holiday.optString("scope", "")));
      text.append("  ·  ").append(name);
      ++displayedCount;
    }

    if (displayedCount == 0) {
      views.setViewVisibility(R.id.widget_holidays, View.GONE);
      return 0;
    }
    views.setTextViewText(R.id.widget_holidays, text.toString());
    views.setViewVisibility(R.id.widget_holidays, View.VISIBLE);
    return displayedCount;
  }

  private static String holidayKindLabel(String kind, String scope) {
    String category = "DATA COMEMORATIVA";
    if ("legal".equals(kind)) {
      category = "FERIADO";
    } else if ("optional".equals(kind)) {
      category = "PONTO FACULTATIVO";
    }

    String coverage = "";
    if ("national".equals(scope)) {
      coverage = "NACIONAL";
    } else if ("state".equals(scope)) {
      coverage = "ESTADUAL";
    } else if ("municipal".equals(scope)) {
      coverage = "MUNICIPAL";
    }
    return coverage.isEmpty() ? category : category + " " + coverage;
  }

  private static JSONObject snapshot(Context context) {
    String snapshot =
        context.getSharedPreferences(WaypointWidgetBridge.SNAPSHOT_PREFERENCES, Context.MODE_PRIVATE)
            .getString(WaypointWidgetBridge.SNAPSHOT_KEY, "");
    if (snapshot == null || snapshot.isEmpty()) {
      return new JSONObject();
    }
    try {
      return new JSONObject(snapshot);
    } catch (JSONException ignored) {
      return new JSONObject();
    }
  }

  private static boolean hasSnapshot(Context context) {
    return context.getSharedPreferences(WaypointWidgetBridge.SNAPSHOT_PREFERENCES, Context.MODE_PRIVATE)
        .contains(WaypointWidgetBridge.SNAPSHOT_KEY);
  }

  private static LocalDate selectedDate(Context context, int appWidgetId, LocalDate fallback) {
    String value = state(context).getString(SELECTED_DATE_PREFIX + appWidgetId, "");
    if (value == null || value.isEmpty()) {
      return fallback;
    }
    try {
      return LocalDate.parse(value);
    } catch (RuntimeException ignored) {
      return fallback;
    }
  }

  private static void selectDate(Context context, int appWidgetId, String dateValue) {
    if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID || dateValue == null) {
      return;
    }
    try {
      LocalDate.parse(dateValue);
    } catch (RuntimeException ignored) {
      return;
    }
    state(context).edit().putString(SELECTED_DATE_PREFIX + appWidgetId, dateValue).apply();
    updateWidget(context, AppWidgetManager.getInstance(context), appWidgetId);
  }

  private static void moveMonth(Context context, int appWidgetId, int delta) {
    if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID || delta == 0) {
      return;
    }
    LocalDate current = selectedDate(context, appWidgetId, LocalDate.now());
    LocalDate moved = current.plusMonths(delta);
    state(context).edit().putString(SELECTED_DATE_PREFIX + appWidgetId, moved.toString()).apply();
    updateWidget(context, AppWidgetManager.getInstance(context), appWidgetId);
  }

  private static PendingIntent moveMonthIntent(Context context, int appWidgetId, int delta) {
    Intent intent = new Intent(context, WaypointWidgetProvider.class)
                        .setAction(ACTION_MOVE_MONTH)
                        .setData(Uri.parse("waypoint://widget/" + appWidgetId + "/month/" + delta))
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        .putExtra(EXTRA_MONTH_DELTA, delta);
    return PendingIntent.getBroadcast(context, appWidgetId * 100 + (delta < 0 ? 1 : 2), intent,
                                      PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  private static PendingIntent selectDateIntent(Context context, int appWidgetId, LocalDate date,
                                                int requestOffset) {
    Intent intent = new Intent(context, WaypointWidgetProvider.class)
                        .setAction(ACTION_SELECT_DATE)
                        .setData(Uri.parse("waypoint://widget/" + appWidgetId + "/date/" + date))
                        .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        .putExtra(EXTRA_DATE, date.toString());
    return PendingIntent.getBroadcast(context, appWidgetId * 100 + 10 + requestOffset, intent,
                                      PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  private static PendingIntent taskCompletionIntent(Context context, int appWidgetId, JSONObject task,
                                                    int requestOffset, boolean completed) {
    String taskId = task.optString("taskId", "");
    String occurrenceDate = task.optString("occurrenceDate", "");
    Intent intent =
        new Intent(context, WaypointWidgetActionService.class)
            .setData(new Uri.Builder()
                         .scheme("waypoint")
                         .authority("widget")
                         .appendPath(Integer.toString(appWidgetId))
                         .appendPath("task")
                         .appendPath(taskId)
                         .appendPath(occurrenceDate)
                         .build())
            .putExtra(WaypointWidgetActionService.EXTRA_TASK_ID, taskId)
            .putExtra(WaypointWidgetActionService.EXTRA_OCCURRENCE_DATE, occurrenceDate)
            .putExtra(WaypointWidgetActionService.EXTRA_RECURRING, task.optBoolean("recurring", false))
            .putExtra(WaypointWidgetActionService.EXTRA_COMPLETED, completed);
    return PendingIntent.getForegroundService(context, appWidgetId * 100 + 60 + requestOffset, intent,
                                              PendingIntent.FLAG_UPDATE_CURRENT |
                                                  PendingIntent.FLAG_IMMUTABLE);
  }

  private static PendingIntent habitCheckInIntent(Context context, int appWidgetId, JSONObject habit,
                                                  int requestOffset, long amount) {
    String habitId = habit.optString("id", "");
    String date = habit.optString("date", "");
    Intent intent =
        new Intent(context, WaypointWidgetActionService.class)
            .setData(new Uri.Builder()
                         .scheme("waypoint")
                         .authority("widget")
                         .appendPath(Integer.toString(appWidgetId))
                         .appendPath("habit")
                         .appendPath(habitId)
                         .appendPath(date)
                         .build())
            .putExtra(WaypointWidgetActionService.EXTRA_HABIT_ID, habitId)
            .putExtra(WaypointWidgetActionService.EXTRA_HABIT_DATE, date)
            .putExtra(WaypointWidgetActionService.EXTRA_HABIT_AMOUNT, amount);
    return PendingIntent.getForegroundService(context, appWidgetId * 100 + 70 + requestOffset, intent,
                                              PendingIntent.FLAG_UPDATE_CURRENT |
                                                  PendingIntent.FLAG_IMMUTABLE);
  }

  private static PendingIntent openAppIntent(Context context, int appWidgetId) {
    Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
    if (intent == null) {
      intent = new Intent(context, WaypointActivity.class)
                   .setAction(Intent.ACTION_MAIN)
                   .addCategory(Intent.CATEGORY_LAUNCHER);
    }
    intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    return PendingIntent.getActivity(context, appWidgetId * 100 + 99, intent,
                                     PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
  }

  private static SharedPreferences state(Context context) {
    return context.getSharedPreferences(STATE_PREFERENCES, Context.MODE_PRIVATE);
  }
}

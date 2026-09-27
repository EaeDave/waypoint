package org.eaedave.waypoint;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ResultReceiver;
import android.widget.DatePicker;
import android.widget.Toast;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import org.json.JSONException;
import org.json.JSONObject;

public final class WaypointWidgetCompletionActivity extends Activity {
  private JSONObject task;
  private DatePicker picker;
  private boolean saving;
  private boolean showingSuccess;
  private boolean choosingDate;
  private boolean previousCompleted;
  private String previousDate = "";
  private boolean requestedCompleted;
  private String requestedDate = "";
  private AlertDialog progress;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    try {
      task = new JSONObject(savedInstanceState == null
                                ? getIntent().getStringExtra(WaypointWidgetTaskIntents.EXTRA_TASK)
                                : savedInstanceState.getString("task"));
    } catch (JSONException | NullPointerException error) {
      finish();
      return;
    }
    LocalDate due = WaypointWidgetCompletionState.parseDate(task.optString("occurrenceDate", ""));
    if (task.optString("taskId", "").isEmpty() || due == null) {
      finish();
      return;
    }
    if (savedInstanceState != null && savedInstanceState.getBoolean("success")) {
      previousCompleted = savedInstanceState.getBoolean("previousCompleted");
      previousDate = savedInstanceState.getString("previousDate", "");
      showSuccess();
      return;
    }
    if (savedInstanceState != null && savedInstanceState.getBoolean("saving")) {
      apply(savedInstanceState.getBoolean("requestedCompleted"),
            savedInstanceState.getString("requestedDate", ""));
      return;
    }
    if (savedInstanceState != null && savedInstanceState.containsKey("pickerDate")) {
      showDatePicker(WaypointWidgetCompletionState.initialDate(savedInstanceState.getString("pickerDate"),
                                                              LocalDate.now()));
      return;
    }
    if (savedInstanceState != null && savedInstanceState.getBoolean("choosingDate")) {
      showChoices(due, task.optBoolean("completed", false));
      return;
    }
    boolean editing = WaypointWidgetTaskIntents.MODE_EDIT.equals(
        getIntent().getStringExtra(WaypointWidgetTaskIntents.EXTRA_MODE));
    boolean completed = task.optBoolean("completed", false);
    boolean skipped = task.optBoolean("skipped", false);
    if (!editing && (completed || skipped)) {
      apply(false, "");
    } else if (editing || WaypointWidgetCompletionState.needsDateChoice(
                               due.toString(), completed, skipped, LocalDate.now())) {
      showChoices(due, editing);
    } else {
      apply(true, LocalDate.now().toString());
    }
  }

  private void showChoices(LocalDate due, boolean editing) {
    showingSuccess = false;
    choosingDate = true;
    picker = null;
    List<String> labels = new ArrayList<>();
    List<Runnable> actions = new ArrayList<>();
    labels.add("Hoje");
    actions.add(() -> apply(true, LocalDate.now().toString()));
    if (!due.isAfter(LocalDate.now())) {
      labels.add("Na data prevista");
      actions.add(() -> apply(true, due.toString()));
    }
    labels.add("Escolher data");
    actions.add(() -> showDatePicker(WaypointWidgetCompletionState.initialDate(
        task.optString("completedDate", ""), LocalDate.now())));
    if (task.optBoolean("completed", false)) {
      labels.add("Desfazer conclusão");
      actions.add(() -> apply(false, ""));
    }
    new AlertDialog.Builder(this)
        .setTitle(editing ? "Alterar data da conclusão" : "Quando você concluiu?")
        .setItems(labels.toArray(new String[0]), (dialog, which) -> actions.get(which).run())
        .setNegativeButton("Cancelar", (dialog, which) -> finish())
        .setOnCancelListener(dialog -> finish())
        .show();
  }

  private void showDatePicker(LocalDate initial) {
    showingSuccess = false;
    choosingDate = false;
    DatePickerDialog dialog = new DatePickerDialog(this, (view, year, month, day) ->
        apply(true, LocalDate.of(year, month + 1, day).toString()),
        initial.getYear(), initial.getMonthValue() - 1, initial.getDayOfMonth());
    picker = dialog.getDatePicker();
    picker.setMaxDate(LocalDate.now().plusDays(1).atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli() - 1);
    dialog.setTitle("Data real da conclusão");
    dialog.setButton(DatePickerDialog.BUTTON_POSITIVE, "Salvar", dialog);
    dialog.setButton(DatePickerDialog.BUTTON_NEGATIVE, "Cancelar", (view, which) -> finish());
    dialog.setOnCancelListener(view -> finish());
    dialog.show();
  }

  private void apply(boolean completed, String completedDate) {
    LocalDate actual = WaypointWidgetCompletionState.parseDate(completedDate);
    if (completed && (actual == null || actual.isAfter(LocalDate.now()))) {
      Toast.makeText(this, "Escolha uma data até hoje.", Toast.LENGTH_LONG).show();
      showDatePicker(LocalDate.now());
      return;
    }
    picker = null;
    showingSuccess = false;
    choosingDate = false;
    previousCompleted = task.optBoolean("completed", false);
    previousDate = task.optString("completedDate", "");
    requestedCompleted = completed;
    requestedDate = completedDate;
    saving = true;
    progress = new AlertDialog.Builder(this).setMessage("Salvando conclusão…").setCancelable(false).show();
    ResultReceiver receiver = new ResultReceiver(new Handler(Looper.getMainLooper())) {
      @Override
      protected void onReceiveResult(int resultCode, Bundle resultData) {
        if (isFinishing() || isDestroyed()) {
          return;
        }
        saving = false;
        progress.dismiss();
        if (resultCode != 1) {
          Toast.makeText(WaypointWidgetCompletionActivity.this, "Não foi possível salvar a conclusão.",
                         Toast.LENGTH_LONG).show();
          finish();
          return;
        }
        try {
          task.put("completed", completed).put("skipped", false).put("completedDate", completedDate);
        } catch (JSONException error) {
          finish();
          return;
        }
        if (completed) {
          showSuccess();
        } else {
          Toast.makeText(WaypointWidgetCompletionActivity.this, "Conclusão desfeita.", Toast.LENGTH_SHORT).show();
          finish();
        }
      }
    };
    startForegroundService(WaypointWidgetTaskIntents.completionService(this, task, completed, completedDate)
                               .putExtra(WaypointWidgetActionService.EXTRA_RESULT_RECEIVER, receiver));
  }

  private void showSuccess() {
    showingSuccess = true;
    LocalDate actual = WaypointWidgetCompletionState.parseDate(task.optString("completedDate", ""));
    LocalDate due = WaypointWidgetCompletionState.parseDate(task.optString("occurrenceDate", ""));
    DateTimeFormatter format = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    String message = "Conclusão em " + actual.format(format) + " · prevista " + due.format(format) +
                     ". O histórico permanece na data prevista.";
    LocalDate previous = WaypointWidgetCompletionState.parseDate(previousDate);
    String undoLabel = previousCompleted && previous == null ? "Reabrir tarefa" : "Desfazer";
    new AlertDialog.Builder(this).setTitle("Conclusão salva").setMessage(message)
        .setPositiveButton("Fechar", (dialog, which) -> finish())
        .setNeutralButton("Alterar data", (dialog, which) -> showChoices(due, true))
        .setNegativeButton(undoLabel, (dialog, which) ->
            apply(previousCompleted && previous != null, previousCompleted && previous != null ? previousDate : ""))
        .setOnCancelListener(dialog -> finish()).show();
  }

  @Override
  protected void onSaveInstanceState(Bundle outState) {
    if (task != null) {
      outState.putString("task", task.toString());
    }
    outState.putBoolean("saving", saving);
    outState.putBoolean("success", showingSuccess);
    outState.putBoolean("choosingDate", choosingDate);
    outState.putBoolean("previousCompleted", previousCompleted);
    outState.putString("previousDate", previousDate);
    outState.putBoolean("requestedCompleted", requestedCompleted);
    outState.putString("requestedDate", requestedDate);
    if (picker != null) {
      outState.putString("pickerDate", LocalDate.of(picker.getYear(), picker.getMonth() + 1,
                                                   picker.getDayOfMonth()).toString());
    }
    super.onSaveInstanceState(outState);
  }
}

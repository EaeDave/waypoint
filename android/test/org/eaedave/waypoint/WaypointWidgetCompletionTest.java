package org.eaedave.waypoint;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.robolectric.Shadows.shadowOf;

import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Looper;
import android.os.ResultReceiver;
import java.time.LocalDate;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.android.controller.ActivityController;
import org.robolectric.annotation.Config;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.shadows.ShadowAlertDialog;

@RunWith(RobolectricTestRunner.class)
@Config(manifest = Config.NONE, sdk = 28)
public final class WaypointWidgetCompletionTest {
  private JSONObject task(LocalDate due, boolean completed, String actual) throws Exception {
    return new JSONObject().put("taskId", "daily-task").put("occurrenceDate", due.toString())
        .put("recurring", true).put("completed", completed).put("completedDate", actual);
  }

  private ActivityController<WaypointWidgetCompletionActivity> launch(JSONObject task, String mode) {
    Context context = RuntimeEnvironment.getApplication();
    return Robolectric.buildActivity(WaypointWidgetCompletionActivity.class,
                                    WaypointWidgetTaskIntents.completionActivity(context, 12, task, mode)).setup();
  }

  private void choose(int position) {
    AlertDialog dialog = ShadowAlertDialog.getLatestAlertDialog();
    dialog.getListView().performItemClick(null, position, position);
  }

  private void clickDialogButton(AlertDialog dialog, int button) {
    dialog.getButton(button).performClick();
    // Dialog button listeners run through the main looper, not inside performClick().
    shadowOf(Looper.getMainLooper()).idle();
  }

  private Intent nextService() {
    return shadowOf(RuntimeEnvironment.getApplication()).getNextStartedService();
  }

  private void succeed(Intent request) {
    ResultReceiver receiver = request.getParcelableExtra(WaypointWidgetActionService.EXTRA_RESULT_RECEIVER);
    receiver.send(1, Bundle.EMPTY);
    shadowOf(Looper.getMainLooper()).idle();
  }

  @Test
  public void overdueChoiceUsesScheduledDayWithoutChangingOccurrenceIdentity() throws Exception {
    LocalDate due = LocalDate.now().minusDays(5);
    try (ActivityController<WaypointWidgetCompletionActivity> activity =
             launch(task(due, false, ""), WaypointWidgetTaskIntents.MODE_TOGGLE)) {
      assertNull(nextService());
      choose(1);
      Intent request = nextService();
      assertEquals(due.toString(), request.getStringExtra(WaypointWidgetActionService.EXTRA_COMPLETED_DATE));
      assertEquals(due.toString(), request.getStringExtra(WaypointWidgetActionService.EXTRA_OCCURRENCE_DATE));
      assertTrue(request.getBooleanExtra(WaypointWidgetActionService.EXTRA_COMPLETED, false));
    }
  }

  @Test
  public void cancellingOverdueChooserDoesNotWriteCompletion() throws Exception {
    try (ActivityController<WaypointWidgetCompletionActivity> activity = launch(
             task(LocalDate.now().minusDays(1), false, ""), WaypointWidgetTaskIntents.MODE_TOGGLE)) {
      ShadowAlertDialog.getLatestAlertDialog().cancel();
      shadowOf(Looper.getMainLooper()).idle();
      assertTrue(activity.get().isFinishing());
      assertNull(nextService());
    }
  }

  @Test
  public void editingThenUndoRestoresActualDateInsteadOfReopeningTask() throws Exception {
    LocalDate due = LocalDate.now().minusDays(10);
    String oldActual = due.plusDays(2).toString();
    try (ActivityController<WaypointWidgetCompletionActivity> activity =
             launch(task(due, true, oldActual), WaypointWidgetTaskIntents.MODE_EDIT)) {
      choose(0);
      Intent edit = nextService();
      assertTrue(edit.getBooleanExtra(WaypointWidgetActionService.EXTRA_COMPLETED, false));
      succeed(edit);
      clickDialogButton(ShadowAlertDialog.getLatestAlertDialog(), AlertDialog.BUTTON_NEGATIVE);
      Intent undo = nextService();
      assertTrue(undo.getBooleanExtra(WaypointWidgetActionService.EXTRA_COMPLETED, false));
      assertEquals(oldActual, undo.getStringExtra(WaypointWidgetActionService.EXTRA_COMPLETED_DATE));
    }
  }

  @Test
  public void undoingNewCompletionReopensOriginalOccurrence() throws Exception {
    LocalDate due = LocalDate.now();
    try (ActivityController<WaypointWidgetCompletionActivity> activity =
             launch(task(due, false, ""), WaypointWidgetTaskIntents.MODE_TOGGLE)) {
      Intent completed = nextService();
      assertEquals(due.toString(), completed.getStringExtra(WaypointWidgetActionService.EXTRA_COMPLETED_DATE));
      succeed(completed);
      clickDialogButton(ShadowAlertDialog.getLatestAlertDialog(), AlertDialog.BUTTON_NEGATIVE);
      Intent undo = nextService();
      assertFalse(undo.getBooleanExtra(WaypointWidgetActionService.EXTRA_COMPLETED, true));
      assertEquals("", undo.getStringExtra(WaypointWidgetActionService.EXTRA_COMPLETED_DATE));
      assertEquals(due.toString(), undo.getStringExtra(WaypointWidgetActionService.EXTRA_OCCURRENCE_DATE));
    }
  }

  @Test
  public void selectedActualDateSurvivesDialogRecreation() throws Exception {
    LocalDate selected = LocalDate.now().minusDays(3);
    JSONObject task = task(selected.minusDays(2), true, selected.minusDays(1).toString());
    ActivityController<WaypointWidgetCompletionActivity> activity = launch(task, WaypointWidgetTaskIntents.MODE_EDIT);
    choose(2);
    DatePickerDialog picker = (DatePickerDialog)ShadowAlertDialog.getLatestAlertDialog();
    picker.updateDate(selected.getYear(), selected.getMonthValue() - 1, selected.getDayOfMonth());
    Bundle saved = new Bundle();
    activity.pause().saveInstanceState(saved).stop().destroy();
    Intent intent = WaypointWidgetTaskIntents.completionActivity(RuntimeEnvironment.getApplication(), 12,
                                                                task, WaypointWidgetTaskIntents.MODE_EDIT);
    try (ActivityController<WaypointWidgetCompletionActivity> restored =
             Robolectric.buildActivity(WaypointWidgetCompletionActivity.class, intent).setup(saved)) {
      DatePickerDialog restoredPicker = (DatePickerDialog)ShadowAlertDialog.getLatestAlertDialog();
      clickDialogButton(restoredPicker, AlertDialog.BUTTON_POSITIVE);
      assertEquals(selected.toString(), nextService().getStringExtra(WaypointWidgetActionService.EXTRA_COMPLETED_DATE));
    }
  }

  @Test
  public void pendingIntentIdentitySeparatesWidgetsOccurrencesAndEditing() throws Exception {
    Context context = RuntimeEnvironment.getApplication();
    JSONObject first = task(LocalDate.of(2026, 9, 1), true, "2026-09-02");
    JSONObject second = task(LocalDate.of(2026, 9, 2), true, "2026-09-03");
    PendingIntent undoFirst = WaypointWidgetTaskIntents.completion(context, 12, first, WaypointWidgetTaskIntents.MODE_TOGGLE);
    PendingIntent editFirst = WaypointWidgetTaskIntents.completion(context, 12, first, WaypointWidgetTaskIntents.MODE_EDIT);
    PendingIntent undoSecond = WaypointWidgetTaskIntents.completion(context, 12, second, WaypointWidgetTaskIntents.MODE_TOGGLE);
    PendingIntent otherWidget = WaypointWidgetTaskIntents.completion(context, 13, first, WaypointWidgetTaskIntents.MODE_TOGGLE);
    assertNotEquals(undoFirst, editFirst);
    assertNotEquals(undoFirst, undoSecond);
    assertNotEquals(undoFirst, otherWidget);
    undoFirst.send();
    Intent launched = shadowOf(RuntimeEnvironment.getApplication()).getNextStartedActivity();
    JSONObject selected = new JSONObject(launched.getStringExtra(WaypointWidgetTaskIntents.EXTRA_TASK));
    assertEquals("2026-09-01", selected.getString("occurrenceDate"));
    assertEquals(WaypointWidgetTaskIntents.MODE_TOGGLE, launched.getStringExtra(WaypointWidgetTaskIntents.EXTRA_MODE));
  }

  @Test
  public void completedMetadataOverridesStaleUrgencyWithNeutralOrAmber() throws Exception {
    JSONObject completed = task(LocalDate.of(2026, 9, 1), true, "2026-09-01")
                               .put("overdue", true).put("completionLate", false);
    assertEquals(WaypointWidgetTaskText.NEUTRAL, WaypointWidgetTaskText.metadataColor(completed));
    completed.put("completionLate", true);
    assertEquals(WaypointWidgetTaskText.AMBER, WaypointWidgetTaskText.metadataColor(completed));
    completed.put("completed", false);
    assertEquals(WaypointWidgetTaskText.URGENT, WaypointWidgetTaskText.metadataColor(completed));
  }

  @Test
  public void recreatingEditChoiceAfterCompletionDoesNotUndoTask() throws Exception {
    JSONObject task = task(LocalDate.now(), false, "");
    ActivityController<WaypointWidgetCompletionActivity> activity = launch(task, WaypointWidgetTaskIntents.MODE_TOGGLE);
    succeed(nextService());
    clickDialogButton(ShadowAlertDialog.getLatestAlertDialog(), AlertDialog.BUTTON_NEUTRAL);
    Bundle saved = new Bundle();
    activity.pause().saveInstanceState(saved).stop().destroy();
    Intent intent = WaypointWidgetTaskIntents.completionActivity(RuntimeEnvironment.getApplication(), 12,
                                                                task, WaypointWidgetTaskIntents.MODE_TOGGLE);
    try (ActivityController<WaypointWidgetCompletionActivity> restored =
             Robolectric.buildActivity(WaypointWidgetCompletionActivity.class, intent).setup(saved)) {
      assertNull(nextService());
      choose(0);
      assertTrue(nextService().getBooleanExtra(WaypointWidgetActionService.EXTRA_COMPLETED, false));
    }
  }
}

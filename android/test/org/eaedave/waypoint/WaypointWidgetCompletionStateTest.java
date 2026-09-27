package org.eaedave.waypoint;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.time.LocalDate;
import org.junit.Test;

public final class WaypointWidgetCompletionStateTest {
  private static final LocalDate TODAY = LocalDate.of(2026, 9, 4);

  @Test
  public void onlyPendingOverdueOccurrencesAskForActualDate() {
    assertTrue(WaypointWidgetCompletionState.needsDateChoice("2026-09-03", false, false, TODAY));
    assertFalse(WaypointWidgetCompletionState.needsDateChoice("2026-09-04", false, false, TODAY));
    assertFalse(WaypointWidgetCompletionState.needsDateChoice("2026-09-05", false, false, TODAY));
    assertFalse(WaypointWidgetCompletionState.needsDateChoice("2026-09-03", true, false, TODAY));
    assertFalse(WaypointWidgetCompletionState.needsDateChoice("2026-09-03", false, true, TODAY));
  }

  @Test
  public void editingUnknownActualDayDoesNotInventPastCompletionDate() {
    assertEquals(TODAY, WaypointWidgetCompletionState.initialDate("", TODAY));
    assertEquals(LocalDate.of(2026, 8, 31), WaypointWidgetCompletionState.initialDate("2026-08-31", TODAY));
  }

  @Test
  public void pickerNeverStartsOnInvalidOrFutureDay() {
    assertEquals(TODAY, WaypointWidgetCompletionState.initialDate("2026-09-05", TODAY));
    assertEquals(TODAY, WaypointWidgetCompletionState.initialDate("2026-02-30", TODAY));
  }
}

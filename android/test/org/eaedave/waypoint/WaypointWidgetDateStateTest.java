package org.eaedave.waypoint;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;

import java.time.LocalDate;
import org.junit.Test;

public final class WaypointWidgetDateStateTest {
  private static final LocalDate TODAY = LocalDate.of(2026, 9, 4);

  @Test
  public void preservesSelectionMadeToday() {
    assertEquals(LocalDate.of(2026, 9, 10),
                 WaypointWidgetDateState.currentSelectionOrNull("2026-09-10", "2026-09-04", TODAY));
  }

  @Test
  public void expiresSelectionMadeOnPreviousDay() {
    assertNull(WaypointWidgetDateState.currentSelectionOrNull("2026-09-03", "2026-09-03", TODAY));
  }

  @Test
  public void expiresFutureSelectionWhenInteractionDayChanges() {
    assertNull(WaypointWidgetDateState.currentSelectionOrNull("2026-09-10", "2026-09-03", TODAY));
  }

  @Test
  public void expiresLegacyAndInvalidSelectionState() {
    assertNull(WaypointWidgetDateState.currentSelectionOrNull("2026-09-03", "", TODAY));
    assertNull(WaypointWidgetDateState.currentSelectionOrNull("invalid", "2026-09-04", TODAY));
  }
}

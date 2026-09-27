package org.eaedave.waypoint;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(manifest = Config.NONE, sdk = 28)
public final class WaypointWidgetHistoryStateTest {
  @Test
  public void expansionsAreIndependentAcrossWidgetsDatesAndTasks() {
    Context context = RuntimeEnvironment.getApplication();
    WaypointWidgetHistoryState.toggle(context, 1, "2026-09-04", "task-a");
    assertTrue(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-04", "task-a"));
    assertFalse(WaypointWidgetHistoryState.isExpanded(context, 2, "2026-09-04", "task-a"));
    assertFalse(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-05", "task-a"));
    assertFalse(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-04", "task-b"));
    assertFalse(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-04", ""));
  }

  @Test
  public void collapsingSectionRetainsItsExpandedChildren() {
    Context context = RuntimeEnvironment.getApplication();
    WaypointWidgetHistoryState.toggle(context, 1, "2026-09-04", "");
    WaypointWidgetHistoryState.toggle(context, 1, "2026-09-04", "task-a");
    WaypointWidgetHistoryState.toggle(context, 1, "2026-09-04", "");
    assertFalse(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-04", ""));
    assertTrue(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-04", "task-a"));
    WaypointWidgetHistoryState.toggle(context, 1, "2026-09-04", "task-a");
    assertFalse(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-04", "task-a"));
  }

  @Test
  public void deletingWidgetDoesNotCollapseAnotherWidget() {
    Context context = RuntimeEnvironment.getApplication();
    WaypointWidgetHistoryState.toggle(context, 1, "2026-09-04", "task-a");
    WaypointWidgetHistoryState.toggle(context, 2, "2026-09-04", "task-a");
    WaypointWidgetHistoryState.remove(context, 1);
    assertFalse(WaypointWidgetHistoryState.isExpanded(context, 1, "2026-09-04", "task-a"));
    assertTrue(WaypointWidgetHistoryState.isExpanded(context, 2, "2026-09-04", "task-a"));
  }
}

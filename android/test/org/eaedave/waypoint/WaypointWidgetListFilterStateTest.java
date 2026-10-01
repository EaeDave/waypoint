package org.eaedave.waypoint;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(manifest = Config.NONE, sdk = 28)
public final class WaypointWidgetListFilterStateTest {
  @Test
  public void allIncludesFutureListsButEmptySelectionNeverDoes() throws Exception {
    Context context = RuntimeEnvironment.getApplication();
    JSONArray tasks = new JSONArray()
        .put(new JSONObject().put("taskId", "inbox").put("categoryId", ""))
        .put(new JSONObject().put("taskId", "new-task").put("categoryId", "new-list"));
    assertEquals(2, WaypointWidgetListFilterState.filter(tasks,
        WaypointWidgetListFilterState.read(context, 1)).length());
    WaypointWidgetListFilterState.set(context, 1, Collections.emptySet());
    assertEquals(0, WaypointWidgetListFilterState.filter(tasks,
        WaypointWidgetListFilterState.read(context, 1)).length());
    WaypointWidgetListFilterState.clear(context, 1);
    assertEquals(2, WaypointWidgetListFilterState.filter(tasks,
        WaypointWidgetListFilterState.read(context, 1)).length());
  }

  @Test
  public void filtersHistoryGroupsAndInboxByCategoryRatherThanName() throws Exception {
    JSONArray groups = new JSONArray()
        .put(new JSONObject().put("taskId", "inbox").put("categoryId", ""))
        .put(new JSONObject().put("taskId", "work").put("categoryId", "work")
                 .put("name", "Same name").put("count", 2).put("occurrences", new JSONArray()
                     .put(new JSONObject().put("occurrenceDate", "2026-09-01"))
                     .put(new JSONObject().put("occurrenceDate", "2026-09-02"))))
        .put(new JSONObject().put("taskId", "home").put("categoryId", "home")
                 .put("name", "Same name"));
    JSONArray filtered = WaypointWidgetListFilterState.filter(groups,
        new HashSet<>(Arrays.asList("", "work")));
    assertEquals(2, filtered.length());
    assertEquals("inbox", filtered.getJSONObject(0).getString("taskId"));
    assertEquals("work", filtered.getJSONObject(1).getString("taskId"));
    assertEquals("2026-09-02", filtered.getJSONObject(1).getJSONArray("occurrences")
        .getJSONObject(1).getString("occurrenceDate"));
    assertEquals(2, filtered.getJSONObject(1).getInt("count"));
  }

  @Test
  public void inboxIncludesNullEmptyAndAbsentCategoryIdsButNotTheStringNull() throws Exception {
    JSONArray tasks = new JSONArray()
        .put(new JSONObject().put("taskId", "json-null").put("categoryId", JSONObject.NULL))
        .put(new JSONObject().put("taskId", "empty").put("categoryId", ""))
        .put(new JSONObject().put("taskId", "absent"))
        .put(new JSONObject().put("taskId", "named-null").put("categoryId", "null"));
    JSONArray inbox = WaypointWidgetListFilterState.filter(tasks, Collections.singleton(""));
    assertEquals(3, inbox.length());
    assertEquals("json-null", inbox.getJSONObject(0).getString("taskId"));
    assertEquals("empty", inbox.getJSONObject(1).getString("taskId"));
    assertEquals("absent", inbox.getJSONObject(2).getString("taskId"));
  }

  @Test
  public void rememberedSelectionsAndDeletionAreIsolatedByWidget() {
    Context context = RuntimeEnvironment.getApplication();
    Set<String> chosen = new HashSet<>(Collections.singleton("work"));
    WaypointWidgetListFilterState.set(context, 1, chosen);
    WaypointWidgetListFilterState.set(context, 2, Collections.emptySet());
    chosen.clear();
    assertEquals(Collections.singleton("work"), WaypointWidgetListFilterState.read(context, 1));
    Set<String> loaded = WaypointWidgetListFilterState.read(context, 1);
    loaded.clear();
    assertEquals(Collections.singleton("work"), WaypointWidgetListFilterState.read(context, 1));
    new WaypointWidgetProvider().onDeleted(context, new int[] {1});
    assertNull(WaypointWidgetListFilterState.read(context, 1));
    assertEquals(Collections.emptySet(), WaypointWidgetListFilterState.read(context, 2));
  }

  @Test
  public void renamesResolveCurrentNamesAndDeletedSelectionDoesNotExposeOtherLists() throws Exception {
    Context context = RuntimeEnvironment.getApplication();
    WaypointWidgetListFilterState.set(context, 1, Collections.singleton("work"));
    JSONArray renamed = new JSONArray().put(new JSONObject().put("id", "work").put("name", "Renamed"));
    Set<String> selected = WaypointWidgetListFilterState.read(context, 1);
    assertTrue(WaypointWidgetListFilterState.label(selected, renamed).contains("Renamed"));
    JSONArray remaining = new JSONArray().put(new JSONObject().put("id", "home").put("name", "Home"));
    assertFalse(WaypointWidgetListFilterState.label(selected, remaining).contains("Home"));
    JSONArray tasks = new JSONArray().put(new JSONObject().put("taskId", "other").put("categoryId", "home"));
    assertEquals(0, WaypointWidgetListFilterState.filter(tasks,
        WaypointWidgetListFilterState.read(context, 1)).length());
    assertEquals(Collections.singleton("work"), WaypointWidgetListFilterState.read(context, 1));
    assertTrue(WaypointWidgetListFilterState.availableIds(remaining).contains(""));
  }
}

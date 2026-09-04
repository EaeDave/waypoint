package org.eaedave.waypoint;

import java.time.LocalDate;

final class WaypointWidgetDateState {
  private WaypointWidgetDateState() {}

  static LocalDate currentSelectionOrNull(String selectedDateValue, String selectedOnValue, LocalDate today) {
    if (selectedDateValue == null || selectedOnValue == null || today == null) {
      return null;
    }
    try {
      LocalDate selectedOn = LocalDate.parse(selectedOnValue);
      if (!today.equals(selectedOn)) {
        return null;
      }
      return LocalDate.parse(selectedDateValue);
    } catch (RuntimeException ignored) {
      return null;
    }
  }
}

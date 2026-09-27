package org.eaedave.waypoint;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

final class WaypointWidgetCompletionState {
  private WaypointWidgetCompletionState() {}

  static boolean needsDateChoice(String occurrenceDate, boolean completed, boolean skipped, LocalDate today) {
    LocalDate due = parseDate(occurrenceDate);
    return !completed && !skipped && due != null && due.isBefore(today);
  }

  static LocalDate initialDate(String completedDate, LocalDate today) {
    LocalDate actual = parseDate(completedDate);
    return actual != null && !actual.isAfter(today) ? actual : today;
  }

  static LocalDate parseDate(String value) {
    if (value == null || value.isEmpty()) {
      return null;
    }
    try {
      return LocalDate.parse(value);
    } catch (DateTimeParseException ignored) {
      return null;
    }
  }
}

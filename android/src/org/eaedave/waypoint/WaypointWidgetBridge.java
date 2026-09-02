package org.eaedave.waypoint;

import android.content.Context;

public final class WaypointWidgetBridge {
    static final String SNAPSHOT_PREFERENCES = "waypoint_widget_snapshot";
    static final String SNAPSHOT_KEY = "snapshot";

    private WaypointWidgetBridge() {
    }

    public static void publishSnapshot(Context context, String snapshot) {
        if (context == null || snapshot == null) {
            return;
        }
        context.getSharedPreferences(SNAPSHOT_PREFERENCES, Context.MODE_PRIVATE)
                .edit()
                .putString(SNAPSHOT_KEY, snapshot)
                .apply();
        WaypointWidgetProvider.updateAll(context);
    }
}

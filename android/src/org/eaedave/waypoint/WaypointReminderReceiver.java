package org.eaedave.waypoint;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public final class WaypointReminderReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        WaypointNotifications.show(context, intent);
    }
}

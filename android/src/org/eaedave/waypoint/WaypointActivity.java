package org.eaedave.waypoint;

import android.Manifest;
import android.app.AlarmManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Window;

import org.qtproject.qt.android.bindings.QtActivity;

public final class WaypointActivity extends QtActivity {
    private static final int NOTIFICATION_PERMISSION_REQUEST = 4817;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        configureSystemBars();
        if (!requestNotificationPermission()) {
            offerExactAlarmAccessOnce();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        WaypointNotifications.rescheduleStored(this);
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST) {
            offerExactAlarmAccessOnce();
        }
    }

    private void configureSystemBars() {
        Window window = getWindow();
        window.setStatusBarColor(Color.rgb(8, 9, 11));
        window.setNavigationBarColor(Color.rgb(8, 9, 11));
    }

    private boolean requestNotificationPermission() {
        if (Build.VERSION.SDK_INT < 33
                || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                == PackageManager.PERMISSION_GRANTED) {
            return false;
        }
        requestPermissions(
                new String[]{Manifest.permission.POST_NOTIFICATIONS},
                NOTIFICATION_PERMISSION_REQUEST);
        return true;
    }

    private void offerExactAlarmAccessOnce() {
        if (Build.VERSION.SDK_INT < 31) {
            return;
        }
        AlarmManager alarmManager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
        if (alarmManager.canScheduleExactAlarms()) {
            return;
        }
        if (getPreferences(Context.MODE_PRIVATE).getBoolean("offeredExactAlarmAccess", false)) {
            return;
        }
        getPreferences(Context.MODE_PRIVATE)
                .edit()
                .putBoolean("offeredExactAlarmAccess", true)
                .apply();
        Intent intent = new Intent(
                Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                Uri.parse("package:" + getPackageName()));
        startActivity(intent);
    }
}

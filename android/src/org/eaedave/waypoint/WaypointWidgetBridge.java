package org.eaedave.waypoint;

import android.content.Context;
import android.content.Intent;
import android.util.Log;
import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

public final class WaypointWidgetBridge {
    static final String ACTION_SNAPSHOT_CHANGED = "org.eaedave.waypoint.WIDGET_SNAPSHOT_CHANGED";
    private static final String SNAPSHOT_FILE = "widget-snapshot.json";

    private WaypointWidgetBridge() {
    }

    public static void publishSnapshot(Context context, String snapshot) {
        if (context == null || snapshot == null) {
            return;
        }
        File temporary = null;
        try {
            // Services run in separate Qt processes; SharedPreferences caches are not coherent across them.
            temporary = File.createTempFile("widget-snapshot-", ".json", context.getFilesDir());
            Files.write(temporary.toPath(), snapshot.getBytes(StandardCharsets.UTF_8));
            Files.move(temporary.toPath(), new File(context.getFilesDir(), SNAPSHOT_FILE).toPath(),
                       StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException error) {
            Log.e("WaypointWidget", "Unable to publish widget snapshot", error);
            return;
        } finally {
            if (temporary != null) {
                temporary.delete();
            }
        }
        // Render in the provider's process, where per-widget SharedPreferences are coherent.
        context.sendBroadcast(new Intent(context, WaypointWidgetProvider.class).setAction(ACTION_SNAPSHOT_CHANGED));
        context.sendBroadcast(new Intent(ACTION_SNAPSHOT_CHANGED).setPackage(context.getPackageName()));
    }

    static String readSnapshot(Context context) {
        File snapshot = new File(context.getFilesDir(), SNAPSHOT_FILE);
        if (!snapshot.exists()) {
            return "";
        }
        try {
            return new String(Files.readAllBytes(snapshot.toPath()), StandardCharsets.UTF_8);
        } catch (IOException error) {
            Log.e("WaypointWidget", "Unable to read widget snapshot", error);
            return "";
        }
    }

    static boolean hasSnapshot(Context context) {
        return new File(context.getFilesDir(), SNAPSHOT_FILE).isFile();
    }
}

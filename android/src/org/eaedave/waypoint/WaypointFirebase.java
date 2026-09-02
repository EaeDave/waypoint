package org.eaedave.waypoint;

import android.content.Context;
import android.content.res.Resources;
import android.util.Log;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;

final class WaypointFirebase {
  private static final String TAG = "WaypointFirebase";
  private static boolean initialized;

  private WaypointFirebase() {}

  static synchronized void initialize(Context context) {
    if (initialized) {
      return;
    }
    initialized = true;

    String applicationId = resource(context, "waypoint_firebase_application_id");
    String apiKey = resource(context, "waypoint_firebase_api_key");
    String projectId = resource(context, "waypoint_firebase_project_id");
    String senderId = resource(context, "waypoint_firebase_sender_id");
    if (applicationId.isEmpty() || apiKey.isEmpty() || projectId.isEmpty() || senderId.isEmpty()) {
      Log.i(TAG, "Firebase messaging is not configured; polling fallback remains active");
      return;
    }

    FirebaseOptions options = new FirebaseOptions.Builder()
                                  .setApplicationId(applicationId)
                                  .setApiKey(apiKey)
                                  .setProjectId(projectId)
                                  .setGcmSenderId(senderId)
                                  .build();
    FirebaseApp app = FirebaseApp.initializeApp(context.getApplicationContext(), options);
    if (app == null) {
      Log.w(TAG, "Firebase initialization returned no app");
      return;
    }
    FirebaseMessaging messaging = FirebaseMessaging.getInstance();
    messaging.setAutoInitEnabled(true);
    messaging.getToken().addOnCompleteListener(task -> {
      if (!task.isSuccessful()) {
        Log.w(TAG, "Unable to obtain Firebase messaging token", task.getException());
        return;
      }
      WaypointPushToken.update(context, task.getResult());
    });
  }

  private static String resource(Context context, String name) {
    Resources resources = context.getResources();
    int identifier = resources.getIdentifier(name, "string", context.getPackageName());
    return identifier == 0 ? "" : resources.getString(identifier).trim();
  }
}

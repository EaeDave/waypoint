package org.eaedave.waypoint;

import android.util.Log;
import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

public final class WaypointFirebaseMessagingService extends FirebaseMessagingService {
  private static final String TAG = "WaypointMessaging";

  @Override
  public void onNewToken(String token) {
    WaypointPushToken.update(this, token);
  }

  @Override
  public void onMessageReceived(RemoteMessage message) {
    if (!"sync-needed".equals(message.getData().get("type"))) {
      return;
    }
    try {
      WaypointBackgroundSyncService.start(this);
    } catch (RuntimeException error) {
      Log.w(TAG, "Android refused the background sync service start", error);
    }
  }
}

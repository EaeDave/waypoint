package org.eaedave.waypoint;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

public final class WaypointFirebaseMessagingService extends FirebaseMessagingService {

  @Override
  public void onNewToken(String token) {
    WaypointPushToken.update(this, token);
  }

  @Override
  public void onMessageReceived(RemoteMessage message) {
    if (!"sync-needed".equals(message.getData().get("type"))) {
      return;
    }
    WaypointBackgroundSyncScheduler.requestImmediate(this);
  }
}

package org.eaedave.waypoint;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.work.Worker;
import androidx.work.WorkerParameters;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

public final class WaypointBackgroundSyncWorker extends Worker {
  private static final String TAG = "WaypointSyncWorker";
  private static final long SYNC_TIMEOUT_SECONDS = 75;
  static final String OPERATION_KEY = "operation";
  static final String OPERATION_LOCAL_WIDGET_REFRESH = "local-widget-refresh";

  public WaypointBackgroundSyncWorker(@NonNull Context context, @NonNull WorkerParameters parameters) {
    super(context, parameters);
  }

  @NonNull
  @Override
  public Result doWork() {
    int messageWhat = OPERATION_LOCAL_WIDGET_REFRESH.equals(getInputData().getString(OPERATION_KEY))
                          ? WaypointBackgroundSyncService.MESSAGE_REFRESH_WIDGET
                          : WaypointBackgroundSyncService.MESSAGE_SYNCHRONIZE;
    SyncConnection connection = new SyncConnection(messageWhat);
    Intent intent = new Intent(getApplicationContext(), WaypointBackgroundSyncService.class);
    final boolean bound;
    try {
      bound = getApplicationContext().bindService(intent, connection, Context.BIND_AUTO_CREATE);
    } catch (RuntimeException error) {
      Log.w(TAG, "Unable to bind the background synchronization service", error);
      return Result.retry();
    }
    if (!bound) {
      Log.w(TAG, "Android did not bind the background synchronization service");
      return Result.retry();
    }

    try {
      if (!connection.await(SYNC_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
        Log.w(TAG, "Background work timed out");
        return Result.retry();
      }
      return connection.result() == WaypointBackgroundSyncService.RESULT_SUCCESS ? Result.success()
                                                                                 : Result.retry();
    } catch (InterruptedException error) {
      Thread.currentThread().interrupt();
      return Result.retry();
    } finally {
      try {
        getApplicationContext().unbindService(connection);
      } catch (IllegalArgumentException ignored) {
      }
    }
  }

  private static final class SyncConnection implements ServiceConnection {
    private static final int PENDING = -1;
    private final int messageWhat;
    private final CountDownLatch completed = new CountDownLatch(1);
    private final AtomicInteger result = new AtomicInteger(PENDING);
    private final Messenger responseMessenger =
        new Messenger(new Handler(Looper.getMainLooper(), this::handleResponse));

    SyncConnection(int messageWhat) { this.messageWhat = messageWhat; }

    @Override
    public void onServiceConnected(ComponentName name, IBinder service) {
      Message request = Message.obtain(null, messageWhat);
      request.replyTo = responseMessenger;
      try {
        new Messenger(service).send(request);
      } catch (RemoteException error) {
        Log.w(TAG, "Unable to request background work", error);
        finish(WaypointBackgroundSyncService.RESULT_RETRY);
      }
    }

    @Override
    public void onServiceDisconnected(ComponentName name) {
      finish(WaypointBackgroundSyncService.RESULT_RETRY);
    }

    @Override
    public void onBindingDied(ComponentName name) {
      finish(WaypointBackgroundSyncService.RESULT_RETRY);
    }

    @Override
    public void onNullBinding(ComponentName name) {
      finish(WaypointBackgroundSyncService.RESULT_RETRY);
    }

    boolean await(long timeout, TimeUnit unit) throws InterruptedException {
      return completed.await(timeout, unit);
    }

    int result() { return result.get(); }

    private boolean handleResponse(Message message) {
      if (message.what != messageWhat) {
        return false;
      }
      finish(message.arg1);
      return true;
    }

    private void finish(int value) {
      if (result.compareAndSet(PENDING, value)) {
        completed.countDown();
      }
    }
  }
}

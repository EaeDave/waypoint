package org.eaedave.waypoint;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.content.FileProvider;
import java.io.File;

public final class WaypointUpdate {
  private static final String PREFERENCES = "waypoint_update";
  private static final String PENDING_APK = "pendingApk";

  private WaypointUpdate() {}

  public static boolean install(Context context, String apkPath) {
    File apk = new File(apkPath);
    if (!apk.isFile()) {
      return false;
    }
    context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        .edit()
        .putString(PENDING_APK, apk.getAbsolutePath())
        .apply();
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        !context.getPackageManager().canRequestPackageInstalls()) {
      Intent permission = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                     Uri.parse("package:" + context.getPackageName()));
      permission.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
      context.startActivity(permission);
      return true;
    }
    return openInstaller(context, apk);
  }

  public static void resumePendingInstall(Context context) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
        !context.getPackageManager().canRequestPackageInstalls()) {
      return;
    }
    String path = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getString(PENDING_APK, "");
    if (!path.isEmpty()) {
      openInstaller(context, new File(path));
    }
  }

  private static boolean openInstaller(Context context, File apk) {
    if (!apk.isFile()) {
      clearPending(context);
      return false;
    }
    Uri uri = FileProvider.getUriForFile(context, context.getPackageName() + ".qtprovider", apk);
    Intent install = new Intent(Intent.ACTION_VIEW)
                         .setDataAndType(uri, "application/vnd.android.package-archive")
                         .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
    if (install.resolveActivity(context.getPackageManager()) == null) {
      return false;
    }
    clearPending(context);
    context.startActivity(install);
    return true;
  }

  private static void clearPending(Context context) {
    context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().remove(PENDING_APK).apply();
  }
}

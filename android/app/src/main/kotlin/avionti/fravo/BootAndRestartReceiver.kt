package avionti.fravo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.util.Log

/**
 * Receives BOOT_COMPLETED, LOCKED_BOOT_COMPLETED, MY_PACKAGE_REPLACED and
 * OEM QuickBoot broadcasts.
 *
 * With Option B (AccessibilityService), Android OS automatically restarts the
 * AppBlockerAccessibilityService after reboot — we don't need to manually start
 * any service here.
 *
 * What this receiver DOES do:
 * 1. Logs that boot was received (useful for debugging).
 * 2. Checks that the accessibility service is still enabled — if somehow it was
 *    disabled (e.g. after a system update), it logs a warning so the user
 *    knows to re-enable it when they next open Fravo.
 *
 * The SQLite database (zo_app_blocker.db) persists all blocked apps and time
 * limits on-disk — so the AccessibilityService reads the correct state the
 * moment it is auto-started by Android on boot, with NO dependency on Flutter
 * or the Dart engine being launched.
 */
class BootAndRestartReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FravoBootReceiver"
        private const val ACCESSIBILITY_SERVICE_CLASS =
            "com.example.zo_app_blocker.AppBlockerAccessibilityService"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        Log.i(TAG, "Received broadcast: $action")

        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                checkAccessibilityServiceEnabled(context)
            }
        }
    }

    /**
     * Checks if AppBlockerAccessibilityService is still enabled in system settings.
     * Android auto-starts it if enabled — no manual service start needed.
     */
    private fun checkAccessibilityServiceEnabled(context: Context) {
        val serviceName = "${context.packageName}/$ACCESSIBILITY_SERVICE_CLASS"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: ""

        val isEnabled = TextUtils.SimpleStringSplitter(':').let { splitter ->
            splitter.setString(enabledServices)
            splitter.any { it.equals(serviceName, ignoreCase = true) }
        }

        if (isEnabled) {
            Log.i(TAG, "AppBlockerAccessibilityService is enabled — Android will auto-start it. Blocked apps from SQLite DB will be enforced immediately.")
        } else {
            Log.w(TAG, "AppBlockerAccessibilityService is NOT enabled in Accessibility Settings. " +
                "Blocking will not be active until the user re-enables it in Fravo.")
        }
    }
}

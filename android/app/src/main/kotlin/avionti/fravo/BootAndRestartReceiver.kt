package avionti.fravo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Receives BOOT_COMPLETED and MY_PACKAGE_REPLACED broadcasts so that the
 * zo_app_blocker foreground service is restarted automatically after:
 *   • the device boots up, or
 *   • the app is updated (package replaced).
 *
 * The Flutter Dart engine is NOT started here — we only restart the native
 * blocker service, which keeps battery usage negligible while ensuring the
 * app-blocking functionality survives recents-swipe and device reboots.
 */
class BootAndRestartReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "FravoBootReceiver"

        /**
         * Fully-qualified class name of the blocker foreground service
         * declared in the zo_app_blocker plugin.
         */
        private const val BLOCKER_SERVICE_CLASS =
            "com.example.zo_app_blocker.AppBlockerForegroundService"
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
                startBlockerService(context)
            }
        }
    }

    private fun startBlockerService(context: Context) {
        try {
            val serviceClass = Class.forName(BLOCKER_SERVICE_CLASS)
            val serviceIntent = Intent(context, serviceClass)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // On Android 8+ we must use startForegroundService for a
                // service that will call startForeground() quickly.
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            Log.i(TAG, "ZoAppBlockerService start requested successfully.")
        } catch (e: ClassNotFoundException) {
            // The service class name may differ across plugin versions.
            // Log and continue — blocking will resume once the user opens the app.
            Log.w(TAG, "ZoAppBlockerService class not found: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start ZoAppBlockerService: ${e.message}")
        }
    }
}

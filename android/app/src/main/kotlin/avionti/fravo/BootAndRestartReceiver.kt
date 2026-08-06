package avionti.fravo

import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import android.util.Log

/**
 * Receives BOOT_COMPLETED, LOCKED_BOOT_COMPLETED, MY_PACKAGE_REPLACED and
 * OEM QuickBoot broadcasts.
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
                startForegroundService(context)
                killRunningBlockedApps(context)
            }
        }
    }

    /**
     * Starts the AppBlockerForegroundService so blocking is active immediately
     * after boot — before Flutter has a chance to run.
     */
    private fun startForegroundService(context: Context) {
        try {
            val svcIntent = Intent(context, com.example.zo_app_blocker.AppBlockerForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(svcIntent)
            } else {
                context.startService(svcIntent)
            }
            Log.i(TAG, "Started AppBlockerForegroundService after boot")
        } catch (e: Exception) {
            Log.w(TAG, "startForegroundService error: ${e.message}")
        }
    }

    /**
     * Kills any blocked app that is currently running in the foreground right after boot.
     * This ensures blocking is enforced even if the user never opens Fravo.
     */
    private fun killRunningBlockedApps(context: Context) {
        try {
            val prefsManager = com.example.zo_app_blocker.PreferencesManager(context)
            val blockedApps = prefsManager.getBlockedApps()
            if (blockedApps.isEmpty()) return

            val topPkg = getForegroundApp(context) ?: return

            if (topPkg == context.packageName || topPkg == "com.android.systemui") return
            if (blockedApps.contains(topPkg)) {
                val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                am.killBackgroundProcesses(topPkg)
                Log.i(TAG, "killRunningBlockedApps: killed $topPkg at boot time")
            }
        } catch (e: Exception) {
            Log.w(TAG, "killRunningBlockedApps error: ${e.message}")
        }
    }

    private fun getForegroundApp(context: Context): String? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val events = usm.queryEvents(time - 1000 * 60, time)
        
        var lastPkg: String? = null
        if (events != null) {
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                    lastPkg = event.packageName
                }
            }
        }
        
        if (lastPkg != null) return lastPkg

        // Fallback for boot time: USM events might be empty, check stats instead.
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 1000 * 60, time)
        if (stats != null && stats.isNotEmpty()) {
            var mostRecent: android.app.usage.UsageStats? = null
            for (usageStats in stats) {
                if (mostRecent == null || usageStats.lastTimeUsed > mostRecent.lastTimeUsed) {
                    mostRecent = usageStats
                }
            }
            return mostRecent?.packageName
        }
        
        return null
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

package com.example.zo_app_blocker

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class ZoAppBlockerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var syncEventChannel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var permissionManager: PermissionManager? = null
    private var appResolver: AppResolver? = null
    private var prefsManager: PreferencesManager? = null

    companion object {
        var instance: ZoAppBlockerPlugin? = null
            private set

        /**
         * Call this from the foreground/accessibility service whenever a
         * timed app is opened, so Flutter can instantly sync steps + usage.
         */
        fun onAppOpened(pkg: String) {
            instance?.syncEventChannel?.invokeMethod("onAppOpened", mapOf("package" to pkg))
        }

        /**
         * Call this whenever the user opens Fravo itself (app resumed).
         */
        fun onAppResumed() {
            instance?.syncEventChannel?.invokeMethod("onAppResumed", null)
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "zo_app_blocker")
        channel.setMethodCallHandler(this)

        // Event channel: native → Flutter for instant sync triggers
        syncEventChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "zo_app_blocker_sync_events")

        context = flutterPluginBinding.applicationContext
        permissionManager = PermissionManager(context!!)
        appResolver = AppResolver(context!!)
        prefsManager = PreferencesManager(context!!)
        instance = this

        // Start the foreground service if permissions are granted.
        if (permissionManager?.checkUsageStatsPermission() == "granted") {
            AppBlockerForegroundService.start(context!!)
        }
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        val prefs = prefsManager ?: return result.error("NO_PREFS", "Preferences not initialized", null)
        when (call.method) {
            "checkUsageStatsPermission" -> {
                result.success(permissionManager?.checkUsageStatsPermission() ?: "denied")
            }
            "requestUsageStatsPermission" -> {
                activity?.let { permissionManager?.requestUsageStatsPermission(it) }
                result.success(null)
            }
            "checkAccessibilityPermission" -> {
                val granted = context != null && AppBlockerAccessibilityService.isAccessibilityPermissionGranted(context!!)
                result.success(if (granted) "granted" else "denied")
            }
            "requestAccessibilityPermission" -> {
                context?.let { AppBlockerAccessibilityService.openAccessibilitySettings(it) }
                result.success(null)
            }
            "checkOverlayPermission" -> {
                result.success(permissionManager?.checkOverlayPermission() ?: "denied")
            }
            "requestOverlayPermission" -> {
                activity?.let { permissionManager?.requestOverlayPermission(it) }
                result.success(null)
            }
            "checkNotificationPermission" -> {
                result.success(permissionManager?.checkNotificationPermission() ?: "granted")
            }
            "requestNotificationPermission" -> {
                activity?.let { permissionManager?.requestNotificationPermission(it) }
                result.success(null)
            }
            "getApps" -> {
                CoroutineScope(Dispatchers.Main).launch {
                    val apps = appResolver?.getInstalledApps() ?: emptyList()
                    result.success(apps)
                }
            }
            "getBlockedApps" -> {
                CoroutineScope(Dispatchers.Main).launch {
                    val apps = appResolver?.getInstalledApps() ?: emptyList()
                    val blockedPackages = prefs.getBlockedApps()
                    val blockedApps = apps.filter {
                        val packageName = (it as? Map<*, *>)?.get("packageName") as? String
                        blockedPackages.contains(packageName)
                    }
                    result.success(blockedApps)
                }
            }
            "getAppIcon" -> {
                val packageName = call.argument<String>("packageName") ?: return result.error("INVALID_ARG", "Package name missing", null)
                CoroutineScope(Dispatchers.Main).launch {
                    val iconBytes = appResolver?.getAppIcon(packageName)
                    result.success(iconBytes)
                }
            }
            "blockApps" -> {
                val identifiers = call.argument<List<String>>("identifiers") ?: emptyList()
                val current = prefs.getBlockedApps().toMutableSet()
                current.addAll(identifiers)
                prefs.saveBlockedApps(current)
                prefs.setBlockAll(false)
                // Mark each app's time-limit record as exhausted (usedSeconds = limitSeconds).
                // This ensures the Accessibility Service time-limit branch sees remaining = 0
                // and immediately shows the block screen when the app is opened.
                for (pkg in identifiers) {
                    prefs.markTimeLimitExhausted(pkg)
                }
                AppBlockerAccessibilityService.instance?.checkCurrentForegroundApp()
                result.success(null)
            }
            "unblockApps" -> {
                val identifiers = call.argument<List<String>>("identifiers") ?: emptyList()
                val current = prefs.getBlockedApps().toMutableSet()
                current.removeAll(identifiers.toSet())
                prefs.saveBlockedApps(current)
                AppBlockerAccessibilityService.instance?.checkCurrentForegroundApp()
                result.success(null)
            }
            "blockAll" -> {
                prefs.setBlockAll(true)
                AppBlockerAccessibilityService.instance?.checkCurrentForegroundApp()
                result.success(null)
            }
            "unblockAll" -> {
                prefs.setBlockAll(false)
                prefs.saveBlockedApps(emptySet())
                AppBlockerAccessibilityService.instance?.checkCurrentForegroundApp()
                result.success(null)
            }
            "setNotificationConfig" -> {
                val configArgs = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val config = configArgs.entries.associate { it.key.toString() to it.value.toString() }
                prefs.setNotificationConfig(config)

                // If the service is already running, restart it so the new icon/title takes effect.
                context?.let {
                    if (AppBlockerForegroundService.instance != null) {
                        AppBlockerForegroundService.start(it)
                    }
                }
                result.success(null)
            }
            "saveBlockScreenCallbackHandle" -> {
                val rawHandle = call.argument<Number>("rawHandle")?.toLong()
                if (rawHandle != null) {
                    prefs.saveBlockScreenCallbackHandle(rawHandle)
                    result.success(null)
                } else {
                    result.error("INVALID_ARG", "rawHandle missing or invalid", null)
                }
            }
            "getBlockActivityLog" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val log = prefs.getBlockActivityLog()
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(log)
                    }
                }
            }
            "clearBlockActivityLog" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    prefs.clearBlockActivityLog()
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(null)
                    }
                }
            }

            // -----------------------------------------------------------------
            // Time Limit API
            // -----------------------------------------------------------------

            "setAppTimeLimit" -> {
                val packageName = call.argument<String>("packageName")
                    ?: return result.error("INVALID_ARG", "packageName missing", null)
                val dailyLimitMinutes = call.argument<Int>("dailyLimitMinutes")
                    ?: return result.error("INVALID_ARG", "dailyLimitMinutes missing", null)

                val limitSeconds = dailyLimitMinutes * 60L
                prefs.setAppTimeLimit(packageName, limitSeconds)
                result.success(null)
            }

            "removeAppTimeLimit" -> {
                val packageName = call.argument<String>("packageName")
                    ?: return result.error("INVALID_ARG", "packageName missing", null)

                prefs.removeAppTimeLimit(packageName)

                // If this package was only blocked because of the time limit, unblock it.
                val blocked = prefs.getBlockedApps().toMutableSet()
                if (blocked.remove(packageName)) {
                    prefs.saveBlockedApps(blocked)
                    AppBlockerAccessibilityService.instance?.checkCurrentForegroundApp()
                }
                result.success(null)
            }

            "getAppTimeLimits" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val limits = prefs.getLiveAppTimeLimits().map { row ->
                        val limitSec = (row["dailyLimitSeconds"] as? Long) ?: 0L
                        val usedSec  = (row["usedSeconds"]       as? Long) ?: 0L
                        val remSec   = (row["remainingSeconds"]   as? Long) ?: 0L
                        mapOf(
                            "packageName"        to row["packageName"],
                            "dailyLimitMinutes"  to (limitSec / 60).toInt(),
                            "usedMinutes"        to (usedSec  / 60).toInt(),
                            "remainingMinutes"   to (remSec   / 60).toInt(),
                            "dailyLimitSeconds"  to limitSec,
                            "usedSeconds"        to usedSec,
                            "remainingSeconds"   to remSec
                        )
                    }
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(limits)
                    }
                }
            }

            "resetAppUsage" -> {
                val packageName = call.argument<String>("packageName")
                    ?: return result.error("INVALID_ARG", "packageName missing", null)

                CoroutineScope(Dispatchers.IO).launch {
                    prefs.resetAppUsage(packageName)

                    // If the app was blocked due to limit exhaustion, unblock it.
                    val blocked = prefs.getBlockedApps().toMutableSet()
                    if (blocked.remove(packageName)) {
                        prefs.saveBlockedApps(blocked)
                        CoroutineScope(Dispatchers.Main).launch {
                            AppBlockerAccessibilityService.instance?.checkCurrentForegroundApp()
                        }
                    }
                    CoroutineScope(Dispatchers.Main).launch {
                        result.success(null)
                    }
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        instance = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}

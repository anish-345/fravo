package com.example.zo_app_blocker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * A foreground service that acts as the primary engine for app blocking.
 * It uses UsageStatsManager to poll for foreground apps every second.
 */
class AppBlockerForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID       = "zo_app_blocker_channel"
        private const val NOTIFICATION_ID  = 101
        private const val POLL_INTERVAL_MS = 500L

        /**
         * How long (ms) a persisted dismiss record is honoured after a service restart.
         * 5 minutes is enough to survive a START_STICKY restart while ensuring that if
         * the user explicitly re-opens the blocked app later the block is re-applied.
         */
        private const val DISMISS_GRACE_MS = 5 * 60 * 1000L

        @Volatile var instance: AppBlockerForegroundService? = null
            private set

        fun start(context: Context) {
            val intent = Intent(context, AppBlockerForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AppBlockerForegroundService::class.java))
        }

        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        fun todayString(): String = DATE_FORMAT.format(Date())
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isPolling = false

    private lateinit var prefsManager: PreferencesManager
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    internal lateinit var flutterOverlayManager: FlutterOverlayManager

    // Package name of the currently unblocked session app
    private var currentUnblockedSessionApp: String? = null

    /** Block screen dismissed by user — don't re-show until they open that app again. */
    private var userDismissedPackage: String? = null
    /**
     * Wall-clock time (System.currentTimeMillis) at which the user dismissed the block
     * screen. Stored in wall-clock ms so it can be compared directly against
     * UsageEvents.Event.getTimeStamp(), which is also wall-clock ms.
     *
     * Note: previously this used SystemClock.uptimeMillis() which is a *different* clock
     * (starts at boot, not epoch), causing the stale-resume guard to always evaluate as
     * false and the overlay to immediately re-appear after dismissal.
     */
    private var userDismissedAtWallMs: Long = 0L

    /** Latest ACTIVITY_RESUMED event from usage stats (used to detect fresh app opens). */
    private var lastResumeEventPackage: String? = null
    private var lastResumeEventTimeMs: Long = 0L

    /** Package blocked by the native (non-Flutter) overlay, if any. */
    private var currentNativeBlockedPackage: String? = null

    @Volatile var lastPackage: String = ""
        private set

    // Time-limit tracking state
    private var activeTimedPackage: String? = null
    private var sessionStartMs: Long = 0L
    private var lastCheckedDate: String = todayString()

    // -------------------------------------------------------------------------
    // Polling runnable
    // -------------------------------------------------------------------------

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isPolling) return
            poll()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // -------------------------------------------------------------------------
    // Service lifecycle
    // -------------------------------------------------------------------------

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefsManager = PreferencesManager(this)
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        flutterOverlayManager = FlutterOverlayManager(this)

        createNotificationChannel()
        flutterOverlayManager.preWarmEngine()

        // Restore dismiss state that was persisted before a service restart.
        // This prevents the overlay from immediately re-appearing when START_STICKY
        // causes the service to restart after being killed.
        restorePersistedDismissState()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification(null, null)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        startPolling()
        return START_STICKY
    }

    override fun onDestroy() {
        flushActiveSession()
        stopPolling()
        removeOverlay()
        flutterOverlayManager.destroy()
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // -------------------------------------------------------------------------
    // Polling loop
    // -------------------------------------------------------------------------

    private fun startPolling() {
        if (isPolling) return
        isPolling = true
        handler.post(pollRunnable)
    }

    private fun stopPolling() {
        isPolling = false
        handler.removeCallbacks(pollRunnable)
    }

    private fun poll() {
        val today = todayString()
        if (today != lastCheckedDate) {
            handleMidnightReset(prefsManager, today)
        }

        val currentPkg = getForegroundAppFromUsageStats()
        if (currentPkg.isNullOrEmpty()) {
            flushActiveSessionTo(prefsManager)
            if (userDismissedPackage != null) {
                removeOverlay()
            }
            return
        }

        // If the foreground app changes, end the session unblock.
        // We ignore our own package and systemui (notification shade) to avoid false positives.
        if (currentUnblockedSessionApp != null &&
            currentPkg != currentUnblockedSessionApp &&
            currentPkg != this.packageName &&
            currentPkg != "com.android.systemui") {
            currentUnblockedSessionApp = null
        }

        if (currentPkg == "com.android.systemui" || currentPkg == this.packageName || isLauncherPackage(currentPkg)) {
            lastPackage = currentPkg
            // Always ensure the overlay is gone when the user is on the launcher / home screen.
            // Previously this was guarded by userDismissedPackage != null which meant the
            // overlay could survive a "Go Back" tap if the dismiss state wasn't set yet.
            removeOverlay()
            return
        }

        lastPackage = currentPkg

        // Hard block (blockApps / budget exhausted) always wins over time-limit grace.
        val hardBlocked = prefsManager.isBlockAll() ||
            prefsManager.getBlockedApps().contains(currentPkg)
        if (hardBlocked) {
            if (activeTimedPackage != null) {
                flushActiveSessionTo(prefsManager)
            }
            checkCurrentForegroundApp()
            return
        }

        val timeLimitInfo = prefsManager.getAppTimeLimit(currentPkg)

        if (timeLimitInfo != null) {
            val remaining = timeLimitInfo["remainingSeconds"] as? Long ?: 0L

            if (remaining <= 0L) {
                flushActiveSessionTo(prefsManager)
                ensureAppIsBlocked(currentPkg, prefsManager)
                updateNotificationDefault(prefsManager)
                return
            }

            if (activeTimedPackage != currentPkg) {
                flushActiveSessionTo(prefsManager)
                activeTimedPackage = currentPkg
                sessionStartMs = System.currentTimeMillis()
            }

            val sessionElapsedSec = (System.currentTimeMillis() - sessionStartMs) / 1000L
            val liveRemaining = (remaining - sessionElapsedSec).coerceAtLeast(0L)

            if (liveRemaining <= 0L) {
                flushActiveSessionTo(prefsManager)
                ensureAppIsBlocked(currentPkg, prefsManager)
                updateNotificationDefault(prefsManager)
                return
            }

            val appName = getAppName(currentPkg)
            updateNotificationCountdown(appName, liveRemaining)

        } else {
            if (activeTimedPackage != null) {
                flushActiveSessionTo(prefsManager)
                updateNotificationDefault(prefsManager)
            }
            checkCurrentForegroundApp()
        }
    }

    private fun getForegroundAppFromUsageStats(): String? {
        var foregroundApp: String? = null
        var latestTime = 0L
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        // Use a wider window so we reliably see the most recent resume event.
        val events = usm.queryEvents(time - 3000L, time)
        if (events != null) {
            val event = UsageEvents.Event()
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED &&
                    event.timeStamp >= latestTime) {
                    latestTime = event.timeStamp
                    foregroundApp = event.packageName
                }
            }
        }
        if (foregroundApp != null) {
            lastResumeEventPackage = foregroundApp
            lastResumeEventTimeMs = latestTime
            // Ignore stale resume events for a package the user already dismissed.
            // Both latestTime and userDismissedAtWallMs are wall-clock ms so the
            // comparison is valid.
            if (userDismissedPackage == foregroundApp && latestTime <= userDismissedAtWallMs) {
                return null
            }
            return foregroundApp
        }
        return lastPackage.ifEmpty { null }
    }

    // -------------------------------------------------------------------------
    // Blocking Logic
    // -------------------------------------------------------------------------

    fun checkCurrentForegroundApp() {
        if (flutterOverlayManager.isOverlayVisible || overlayView != null) {
            val blockedPkg = flutterOverlayManager.currentBlockedPackage
                ?: currentNativeBlockedPackage
            if (blockedPkg == null) {
                removeOverlay()
                return
            }
            // Remove overlay if the user dismissed it via "Go Back" or if the app is
            // no longer in the blocked list.
            if (userDismissedPackage == blockedPkg) {
                removeOverlay()
                return
            }
            val stillBlocked = if (prefsManager.isBlockAll()) true
                               else prefsManager.getBlockedApps().contains(blockedPkg)
            if (!stillBlocked) {
                removeOverlay()
            }
            return
        }

        val pkg = lastPackage
        if (pkg.isEmpty() || pkg == "com.android.systemui" || isLauncherPackage(pkg)) return

        if (pkg == currentUnblockedSessionApp) return
        if (!shouldEnforceBlockFor(pkg)) return

        val shouldBlock = if (prefsManager.isBlockAll()) true
                          else prefsManager.getBlockedApps().contains(pkg)
        if (shouldBlock) {
            showOverlayForPackage(pkg)
        }
    }

    /**
     * Called when the user taps "Go Back" on the block screen.
     * Prevents the poll loop from immediately re-showing the overlay on the home screen.
     */
    fun onUserDismissedBlock(packageName: String?) {
        if (!packageName.isNullOrEmpty()) {
            userDismissedPackage = packageName
            // Use wall-clock ms — the same clock as UsageEvents.Event.getTimeStamp()
            // so the stale-resume guard in getForegroundAppFromUsageStats() works correctly.
            userDismissedAtWallMs = System.currentTimeMillis()
            // Persist so the overlay doesn't re-appear if START_STICKY restarts the service.
            persistDismissState(packageName, userDismissedAtWallMs)
        }
        lastPackage = ""
        removeOverlay()
        goHome()
    }

    /**
     * Returns false when the user dismissed the block screen and hasn't opened
     * that app again (no fresh ACTIVITY_RESUMED after dismiss).
     */
    private fun shouldEnforceBlockFor(packageName: String): Boolean {
        val dismissed = userDismissedPackage ?: return true
        if (dismissed != packageName) return true

        // User opened the blocked app again — allow re-blocking.
        if (lastResumeEventPackage == packageName &&
            lastResumeEventTimeMs > userDismissedAtWallMs) {
            userDismissedPackage = null
            userDismissedAtWallMs = 0L
            clearPersistedDismissState()
            return true
        }
        return false
    }

    fun showOverlayForPackage(packageName: String) {
        if ((flutterOverlayManager.isOverlayVisible || overlayView != null) &&
            flutterOverlayManager.currentBlockedPackage == packageName) return
        if (!shouldEnforceBlockFor(packageName)) return

        goHome()

        prefsManager.logBlockEvent(packageName)

        if (prefsManager.hasBlockScreenCallback()) {
            flutterOverlayManager.showOverlay(
                packageName, null, null,
                onEngineUnavailable = { showNativeOverlay(packageName) },
                onWindowAddFailed = { showNativeOverlay(packageName) }
            )

            Thread {
                val pm = packageManager
                var appName: String? = null
                var appIcon: ByteArray? = null
                try {
                    val appInfo = pm.getApplicationInfo(packageName, 0)
                    appName = pm.getApplicationLabel(appInfo).toString()
                    val appResolver = AppResolver(this)
                    appIcon = appResolver.getAppIconSync(packageName)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
                if (appName != null || appIcon != null) {
                    flutterOverlayManager.updateBlockedAppData(packageName, appName, appIcon)
                }
            }.start()
        } else {
            showNativeOverlay(packageName)
        }
    }

    fun temporarySessionUnlock(packageName: String) {
        // We use a strict foreground session instead
        currentUnblockedSessionApp = packageName
        if (userDismissedPackage == packageName) {
            userDismissedPackage = null
            userDismissedAtWallMs = 0L
            clearPersistedDismissState()
        }
        if (lastPackage == packageName) {
            lastPackage = ""
        }
        checkCurrentForegroundApp()
    }

    fun forceCheckBlockedApps() {
        val currentPkg = getForegroundAppFromUsageStats()
        if (!currentPkg.isNullOrEmpty()) {
            lastPackage = currentPkg
        }
        checkCurrentForegroundApp()
    }

    private fun goHome() {
        val startMain = Intent(Intent.ACTION_MAIN)
        startMain.addCategory(Intent.CATEGORY_HOME)
        startMain.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(startMain)
    }

    private fun removeOverlay() {
        flutterOverlayManager.hideOverlay()
        currentNativeBlockedPackage = null
        handler.post {
            try {
                if (overlayView != null && overlayView?.parent != null) {
                    windowManager.removeView(overlayView)
                    overlayView = null
                }
            } catch (e: Exception) {
                overlayView = null
            }
        }
    }

    private fun showNativeOverlay(packageName: String) {
        if (overlayView != null) return

        handler.post {
            try {
                if (overlayView == null) {
                    currentNativeBlockedPackage = packageName
                    overlayView = createOverlayView(packageName)
                    val params = WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            WindowManager.LayoutParams.TYPE_PHONE
                        },
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                        PixelFormat.TRANSLUCENT
                    )
                    windowManager.addView(overlayView, params)
                }
            } catch (e: Exception) {
                overlayView = null
                e.printStackTrace()
            }
        }
    }

    private fun createOverlayView(packageName: String): View {
        val config = prefsManager.getBlockScreenConfig()

        val bgColor = parseColorSafe(config["backgroundColor"], "#F44336")
        val tColor  = parseColorSafe(config["titleColor"],      "#FFFFFF")
        val dColor  = parseColorSafe(config["descriptionColor"],"#EEEEEE")

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(bgColor)
            setPadding(80, 80, 80, 80)
            isClickable = true
            isFocusable  = true
        }

        val titleView = TextView(this).apply {
            text = config["title"] ?: "App Blocked"
            setTextColor(tColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 32f)
            setTypeface(null, android.graphics.Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }

        val descView = TextView(this).apply {
            text = config["description"] ?: "This app is blocked."
            setTextColor(dColor)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            gravity = Gravity.CENTER
            setLineSpacing(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 4f, resources.displayMetrics), 1.0f)
            setPadding(0, 0, 0, 64)
        }

        val btn = android.widget.Button(this).apply {
            text = "Exit"
            setTextColor(bgColor)
            setBackgroundColor(tColor)
            isAllCaps = false
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(null, android.graphics.Typeface.BOLD)
            setPadding(64, 32, 64, 32)
            elevation = 8f
            setOnClickListener {
                onUserDismissedBlock(packageName)
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        val pm = packageManager
        var appIcon: android.graphics.drawable.Drawable? = null
        try {
            appIcon = pm.getApplicationIcon(packageName)
        } catch (e: Exception) {}

        if (appIcon != null) {
            val iconSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 72f, resources.displayMetrics).toInt()
            val marginBottom = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, 24f, resources.displayMetrics).toInt()

            val iconView = android.widget.ImageView(this).apply {
                setImageDrawable(appIcon)
                layoutParams = LinearLayout.LayoutParams(iconSize, iconSize).apply {
                    setMargins(0, 0, 0, marginBottom)
                }
            }
            layout.addView(iconView)
        }

        layout.addView(titleView)
        layout.addView(descView)
        layout.addView(btn)
        return layout
    }

    private fun parseColorSafe(colorStr: String?, defaultColor: String): Int {
        if (colorStr.isNullOrEmpty()) return Color.parseColor(defaultColor)
        return try {
            Color.parseColor(colorStr)
        } catch (e: Exception) {
            try {
                if (colorStr.startsWith("0x", ignoreCase = true)) {
                    colorStr.substring(2).toLong(16).toInt()
                } else {
                    colorStr.toLong().toInt()
                }
            } catch (e2: Exception) {
                Color.parseColor(defaultColor)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Dismiss-state persistence
    // Survives service restarts (START_STICKY) so the overlay doesn't
    // re-appear immediately after the user taps "Go Back".
    // -------------------------------------------------------------------------

    private fun dismissPrefs() =
        getSharedPreferences("zo_blocker_dismiss", Context.MODE_PRIVATE)

    private fun persistDismissState(packageName: String, wallMs: Long) {
        dismissPrefs().edit()
            .putString("dismissed_pkg", packageName)
            .putLong("dismissed_at_ms", wallMs)
            .apply()
    }

    private fun clearPersistedDismissState() {
        dismissPrefs().edit()
            .remove("dismissed_pkg")
            .remove("dismissed_at_ms")
            .apply()
    }

    /**
     * Restores [userDismissedPackage] and [userDismissedAtWallMs] from SharedPreferences.
     *
     * A grace window of [DISMISS_GRACE_MS] is applied — if the dismiss happened more than
     * that many ms ago (e.g. the user left the blocked app open for hours, came back,
     * and we restarted), we ignore the stale record so blocking resumes normally.
     */
    private fun restorePersistedDismissState() {
        val prefs = dismissPrefs()
        val pkg = prefs.getString("dismissed_pkg", null) ?: return
        val atMs = prefs.getLong("dismissed_at_ms", 0L)
        if (atMs == 0L) return
        val age = System.currentTimeMillis() - atMs
        if (age < DISMISS_GRACE_MS) {
            userDismissedPackage = pkg
            userDismissedAtWallMs = atMs
        } else {
            // Stale record — clean it up.
            clearPersistedDismissState()
        }
    }

    private fun isLauncherPackage(packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_MAIN)
        intent.addCategory(Intent.CATEGORY_HOME)
        val res = packageManager.resolveActivity(intent, 0)
        return res?.activityInfo?.packageName == packageName
    }

    // -------------------------------------------------------------------------
    // Session flushing
    // -------------------------------------------------------------------------

    private fun flushActiveSession() {
        val pkg = activeTimedPackage ?: return
        val elapsed = (System.currentTimeMillis() - sessionStartMs) / 1000L
        if (elapsed > 0L) {
            PreferencesManager(this).addUsedSeconds(pkg, elapsed)
        }
        activeTimedPackage = null
        sessionStartMs = 0L
    }

    private fun flushActiveSessionTo(prefsManager: PreferencesManager) {
        val pkg = activeTimedPackage ?: return
        val elapsed = (System.currentTimeMillis() - sessionStartMs) / 1000L
        if (elapsed > 0L) {
            prefsManager.addUsedSeconds(pkg, elapsed)
        }
        activeTimedPackage = null
        sessionStartMs = 0L
    }

    private fun ensureAppIsBlocked(packageName: String, prefsManager: PreferencesManager) {
        val blocked = prefsManager.getBlockedApps()
        if (!blocked.contains(packageName)) {
            val updated = blocked.toMutableSet().apply { add(packageName) }
            prefsManager.saveBlockedApps(updated)
        }
        checkCurrentForegroundApp()
    }

    private fun handleMidnightReset(prefsManager: PreferencesManager, today: String) {
        lastCheckedDate = today
        flushActiveSessionTo(prefsManager)
        prefsManager.resetAllDailyUsage()

        val timeLimitedPackages = prefsManager.getTimeLimitedPackages()
        if (timeLimitedPackages.isNotEmpty()) {
            val currentBlocked = prefsManager.getBlockedApps().toMutableSet()
            val wasModified = currentBlocked.removeAll(timeLimitedPackages)
            if (wasModified) {
                prefsManager.saveBlockedApps(currentBlocked)
                checkCurrentForegroundApp()
            }
        }
    }

    // -------------------------------------------------------------------------
    // Notification
    // -------------------------------------------------------------------------

    private fun getAppName(packageName: String): String {
        return try {
            val info = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun formatRemainingTime(seconds: Long): String {
        val mins = seconds / 60
        val secs = seconds % 60
        return if (mins > 0) {
            "$mins min ${secs} sec"
        } else {
            "${secs} sec"
        }
    }

    private fun updateNotificationCountdown(appName: String, remainingSeconds: Long) {
        val timeStr = formatRemainingTime(remainingSeconds)
        val warning = if (remainingSeconds <= 60) " ⚠️" else ""
        val notification = buildNotification(
            title = "$appName — Time Limit",
            text = "$timeStr remaining today$warning"
        )
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun updateNotificationDefault(prefsManager: PreferencesManager) {
        val notification = buildNotification(null, null)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(title: String?, text: String?): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        val pm = packageManager
        val appName = try {
            applicationInfo.loadLabel(pm).toString()
        } catch (e: Exception) { "App" }

        val prefsManager = PreferencesManager(this)
        val config = prefsManager.getBlockScreenConfig()

        // Resolve notification icon: prefer the custom icon set via setNotificationConfig,
        // fall back to the app launcher icon.
        val notifConfig = prefsManager.getNotificationConfig()
        val customIconName = notifConfig["notificationIcon"]
        val finalIcon: Int = if (!customIconName.isNullOrEmpty()) {
            val resId = resources.getIdentifier(customIconName, "drawable", packageName)
            if (resId != 0) resId else applicationInfo.icon
        } else {
            applicationInfo.icon
        }

        val notifTitle = title ?: (config["notificationTitle"] ?: "$appName Blocker Active")
        val notifDesc = text ?: (config["notificationDescription"] ?: "Monitoring and blocking restricted apps.")

        return builder
            .setContentTitle(notifTitle)
            .setContentText(notifDesc)
            .setSmallIcon(finalIcon)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the app blocker running in the background."
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}

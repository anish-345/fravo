package com.example.zo_app_blocker

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.CountDownTimer
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Event-driven Accessibility Service for app blocking.
 * Listens for TYPE_WINDOW_STATE_CHANGED events natively provided by Android OS
 * without requiring any continuous polling foreground service or FOREGROUND_SERVICE permissions.
 */
class AppBlockerAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "AppBlockerAccessService"
        private const val TIMER_NOTIFICATION_CHANNEL_ID = "zo_app_timer_channel"
        private const val TIMER_NOTIFICATION_ID = 202

        @Volatile var instance: AppBlockerAccessibilityService? = null
            private set

        // Uses DatabaseHelper.todayString() so the day boundary is always
        // consistent across both the native and Flutter layers (including
        // any testing-mode shift, e.g. 3:10 PM instead of midnight).
        fun todayString(): String = DatabaseHelper.todayString()

        /**
         * Checks if this AccessibilityService is enabled in System Settings.
         */
        fun isAccessibilityPermissionGranted(context: Context): Boolean {
            val serviceName = "${context.packageName}/${AppBlockerAccessibilityService::class.java.canonicalName}"
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(enabledServices)
            while (colonSplitter.hasNext()) {
                val componentName = colonSplitter.next()
                if (componentName.equals(serviceName, ignoreCase = true) ||
                    componentName.equals("${context.packageName}/.AppBlockerAccessibilityService", ignoreCase = true)) {
                    return true
                }
            }
            return false
        }

        /**
         * Opens System Accessibility Settings page.
         */
        fun openAccessibilitySettings(context: Context) {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var prefsManager: PreferencesManager
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    internal lateinit var flutterOverlayManager: FlutterOverlayManager

    // Package name of the currently unblocked session app
    private var currentUnblockedSessionApp: String? = null

    @Volatile var lastPackage: String = ""
        private set

    // Time-limit tracking state
    internal var activeTimedPackage: String? = null
    internal var sessionStartMs: Long = 0L
    private var sessionElapsedSeconds: Long = 0L
    private var lastCheckedDate: String = todayString()

    /**
     * Clears in-memory session state WITHOUT flushing elapsed seconds to SQLite.
     * Called immediately after a daily reset so accumulated in-memory time from
     * the previous day is discarded and cannot be written back to the freshly
     * zeroed database.
     */
    fun resetSessionState() {
        cancelActiveCountdown()
        cancelTimerNotification()
        activeTimedPackage = null
        sessionStartMs = 0L
        sessionElapsedSeconds = 0L
        Log.i(TAG, "resetSessionState: in-memory session cleared (daily reset).")
    }

    // ── Event-driven countdown timer ──────────────────────────────────────────
    // Uses Android's CountDownTimer for a clean, event-driven countdown instead
    // of a manual 1-second polling loop. The timer is created once when a timed
    // app opens, ticks natively via onTick, and self-destructs on finish — no
    // manual re-scheduling, no handler overhead, zero CPU burn between ticks.
    private var activeCountDownTimer: CountDownTimer? = null

    // ── Screen state receiver (Screen Lock / Screen Off handling) ─────────────
    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    Log.i(TAG, "Screen turned OFF / Locked — flushing active session and pausing timer.")
                    flushActiveSessionTo(prefsManager)
                }
                Intent.ACTION_USER_PRESENT, Intent.ACTION_SCREEN_ON -> {
                    Log.i(TAG, "Screen turned ON / Unlocked — re-checking foreground app.")
                    handler.postDelayed({
                        checkCurrentForegroundApp()
                    }, 300)
                }
            }
        }
    }

    private fun isScreenInteractive(): Boolean {
        return try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) {
                pm?.isInteractive == true
            } else {
                @Suppress("DEPRECATION")
                pm?.isScreenOn == true
            }
        } catch (_: Exception) {
            true
        }
    }

    /**
     * Starts an event-driven countdown for [packageName].
     * Reads remaining budget from SQLite, creates a CountDownTimer, and
     * updates the notification on each tick. When the timer finishes, the
     * app is blocked and the overlay is shown.
     */
    private fun startCountdownForApp(packageName: String) {
        cancelActiveCountdown()
        if (!isScreenInteractive()) {
            Log.i(TAG, "startCountdownForApp: screen is off/locked — skipping timer start for $packageName.")
            return
        }
        val timeLimitInfo = prefsManager.getAppTimeLimit(packageName) ?: return
        val limitSeconds = timeLimitInfo["dailyLimitSeconds"] as? Long ?: return
        val usedSeconds = timeLimitInfo["usedSeconds"] as? Long ?: return
        val elapsedSec = ((System.currentTimeMillis() - sessionStartMs) / 1000L).coerceAtLeast(0L)
        val remainingMs = ((limitSeconds - usedSeconds - elapsedSec) * 1000L).coerceAtLeast(0L)

        if (remainingMs <= 0L) {
            // Already exhausted at the moment of opening — block immediately
            Log.i(TAG, "startCountdownForApp: $packageName already exhausted, blocking now.")
            flushActiveSessionTo(prefsManager)
            ensureAppIsBlocked(packageName, prefsManager)
            showOverlayForPackage(packageName)
            return
        }

        activeCountDownTimer = object : CountDownTimer(remainingMs, 1000L) {
            override fun onTick(millisUntilFinished: Long) {
                val remainingSec = (millisUntilFinished / 1000L).coerceAtLeast(0L)
                updateActiveTimerNotification(packageName, remainingSec)
            }

            override fun onFinish() {
                // Time's up — flush session, enforce block, show overlay
                Log.i(TAG, "CountDownTimer finished for $packageName — budget exhausted.")
                flushActiveSessionTo(prefsManager)
                ensureAppIsBlocked(packageName, prefsManager)
                showOverlayForPackage(packageName)
                cancelTimerNotification()
            }
        }.start()

        // Show initial notification immediately (don't wait for first tick)
        updateActiveTimerNotification(packageName, (remainingMs / 1000L))
    }

    private fun cancelActiveCountdown() {
        activeCountDownTimer?.cancel()
        activeCountDownTimer = null
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        prefsManager = PreferencesManager(this)
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        flutterOverlayManager = FlutterOverlayManager(this)
        // NOTE: The Flutter block-screen engine is intentionally NOT pre-warmed
        // here. The engine starts lazily on the first block event instead, so
        // the app doesn't sit in the background with a full Flutter isolate running.

        Log.i(TAG, "AppBlockerAccessibilityService connected successfully.")

        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        this.serviceInfo = info

        // Register screen lock / screen off receiver
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        try {
            registerReceiver(screenStateReceiver, filter)
        } catch (e: Exception) {
            Log.e(TAG, "Error registering screenStateReceiver: ${e.message}")
        }

        // Re-evaluate and enforce any exhausted time-limit apps immediately on boot,
        // without requiring Flutter to be opened. The SQLite database persists all
        // blocked apps and time limits, so this is entirely native.
        handler.post { reapplyTimeLimitsOnBoot() }
    }

    /**
     * Called once when the service starts (including on device reboot).
     * Reads time-limit records from SQLite: if any app's daily usage has already
     * hit or exceeded its limit, that app is added to the blocked list so the
     * Accessibility Service enforces the block the moment it is opened —
     * even before Flutter runs.
     */
    private fun reapplyTimeLimitsOnBoot() {
        try {
            val limits = prefsManager.getAppTimeLimits()
            val currentBlocked = prefsManager.getBlockedApps().toMutableSet()
            var changed = false

            for (row in limits) {
                val pkg = row["packageName"] as? String ?: continue
                val limitSec = (row["dailyLimitSeconds"] as? Long) ?: continue
                val usedSec = (row["usedSeconds"] as? Long) ?: 0L
                if (usedSec >= limitSec) {
                    if (currentBlocked.add(pkg)) {
                        changed = true
                        Log.i(TAG, "reapplyTimeLimitsOnBoot: blocking exhausted app: $pkg ($usedSec/$limitSec sec used)")
                    }
                }
            }

            if (changed) {
                prefsManager.saveBlockedApps(currentBlocked)
                Log.i(TAG, "reapplyTimeLimitsOnBoot: blocked apps updated in SQLite.")
            } else {
                Log.i(TAG, "reapplyTimeLimitsOnBoot: no changes needed — blocked apps state is current.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "reapplyTimeLimitsOnBoot error: ${e.message}")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val pkgNameObj = event.packageName ?: return
        val currentPkg = pkgNameObj.toString()
        if (currentPkg.isEmpty()) return

        val today = todayString()
        if (today != lastCheckedDate) {
            handleMidnightReset(prefsManager, today)
        }

        // Transient system windows (Status Bar, Notification Shade, Keyboard, Permission Dialogs, Fravo)
        // should NEVER flush an active timed app session or cancel timer notifications when they appear!
        if (isTransientSystemPackage(currentPkg)) {
            if (currentPkg != this.packageName) {
                lastPackage = currentPkg
            }
            return
        }

        // If user went Home (launcher), end the active timed session
        if (isLauncherPackage(currentPkg)) {
            if (activeTimedPackage != null) {
                flushActiveSessionTo(prefsManager)
            }
            lastPackage = currentPkg
            return
        }

        // If the foreground app changes, end current session unblock if applicable
        if (currentUnblockedSessionApp != null && currentPkg != currentUnblockedSessionApp) {
            currentUnblockedSessionApp = null
        }

        if (currentPkg == currentUnblockedSessionApp) {
            lastPackage = currentPkg
            return
        }

        lastPackage = currentPkg

        // Explicit block check MUST take precedence over time-limit countdowns.
        // If the app is in the blocked set (e.g. earned = 0 or budget exhausted),
        // enforce the block immediately and do NOT run any native countdown timer.
        val isExplicitlyBlocked = if (prefsManager.isBlockAll()) true
                                  else prefsManager.getBlockedApps().contains(currentPkg)
        if (isExplicitlyBlocked) {
            flushActiveSessionTo(prefsManager)
            showOverlayForPackage(currentPkg)
            return
        }

        // Evaluate Time Limit
        val timeLimitInfo = prefsManager.getAppTimeLimit(currentPkg)
        if (timeLimitInfo != null) {
            val limitSeconds = timeLimitInfo["dailyLimitSeconds"] as? Long ?: 0L
            val usedSeconds = timeLimitInfo["usedSeconds"] as? Long ?: 0L
            val remaining = (limitSeconds - usedSeconds).coerceAtLeast(0L)

            if (remaining <= 0L) {
                flushActiveSessionTo(prefsManager)
                ensureAppIsBlocked(currentPkg, prefsManager)
                showOverlayForPackage(currentPkg)
                return
            }

            if (activeTimedPackage != currentPkg) {
                flushActiveSessionTo(prefsManager)
                activeTimedPackage = currentPkg
                sessionStartMs = System.currentTimeMillis()
                sessionElapsedSeconds = 0L
                // Start event-driven countdown — no polling loop needed
                startCountdownForApp(currentPkg)
                // Instantly notify Flutter to sync steps + usage
                ZoAppBlockerPlugin.onAppOpened(currentPkg)
            }
        } else {
            // Package is not in time limits.
            // Only flush active session if currentPkg is an actual launchable main app,
            // NOT an unmonitored system helper component or sub-activity.
            if (activeTimedPackage != null && isLaunchableApp(currentPkg)) {
                flushActiveSessionTo(prefsManager)
            }
            checkCurrentForegroundApp(currentPkg)
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AccessibilityService interrupted")
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenStateReceiver)
        } catch (_: Exception) {}
        cancelActiveCountdown()
        flushActiveSessionTo(prefsManager)
        removeOverlay()
        flutterOverlayManager.destroy()
        instance = null
        super.onDestroy()
    }

    // ── Blocking Logic ───────────────────────────────────────────────────────

    fun checkCurrentForegroundApp(pkg: String = lastPackage) {
        if (flutterOverlayManager.isOverlayVisible || overlayView != null) {
            val blockedPkg = flutterOverlayManager.currentBlockedPackage ?: return
            val stillBlocked = if (prefsManager.isBlockAll()) true
                               else prefsManager.getBlockedApps().contains(blockedPkg)
            if (!stillBlocked) {
                removeOverlay()
            }
            return
        }

        if (pkg.isEmpty() || pkg == "com.android.systemui" || isLauncherPackage(pkg)) return
        if (pkg == currentUnblockedSessionApp) return

        val shouldBlock = if (prefsManager.isBlockAll()) true
                          else prefsManager.getBlockedApps().contains(pkg)
        if (shouldBlock) {
            showOverlayForPackage(pkg)
        }
    }

    fun showOverlayForPackage(packageName: String) {
        if ((flutterOverlayManager.isOverlayVisible || overlayView != null) &&
            flutterOverlayManager.currentBlockedPackage == packageName) return

        goHome()
        // Actively kill the blocked app if it is currently in the foreground
        if (packageName == lastPackage && packageName.isNotEmpty()) {
            killForegroundApp()
        }
        prefsManager.logBlockEvent(packageName)

        if (prefsManager.hasBlockScreenCallback()) {
            flutterOverlayManager.showOverlay(packageName, null, null)

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

    fun killForegroundApp() {
        try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            activityManager.killBackgroundProcesses(lastPackage)
        } catch (e: Exception) {
            Log.e(TAG, "killForegroundApp error: ${e.message}")
        }
    }

    fun temporarySessionUnlock(packageName: String) {
        currentUnblockedSessionApp = packageName
        if (lastPackage == packageName) {
            lastPackage = ""
        }
        removeOverlay()
    }

    private fun goHome() {
        val startMain = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(startMain)
    }

    private fun removeOverlay() {
        flutterOverlayManager.hideOverlay()
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
                    overlayView = createOverlayView(packageName)
                    val params = WindowManager.LayoutParams(
                        WindowManager.LayoutParams.MATCH_PARENT,
                        WindowManager.LayoutParams.MATCH_PARENT,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            WindowManager.LayoutParams.TYPE_PHONE
                        },
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
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
                goHome()
                removeOverlay()
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
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
            Color.parseColor(defaultColor)
        }
    }

    /**
     * Called when Flutter updates the daily time limit for [packageName] while
     * the user is actively using that app. Seamlessly updates the active countdown
     * with the new budget.
     */
    fun refreshActiveCountdown(packageName: String) {
        if (activeTimedPackage == packageName) {
            Log.i(TAG, "refreshActiveCountdown: updating active countdown for $packageName")
            sessionStartMs = System.currentTimeMillis()
            sessionElapsedSeconds = 0L
            startCountdownForApp(packageName)
        }
    }

    private fun isLauncherPackage(packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val res = packageManager.resolveActivity(intent, 0)
        return res?.activityInfo?.packageName == packageName
    }

    private fun isLaunchableApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            intent != null
        } catch (_: Exception) {
            false
        }
    }

    private fun isTransientSystemPackage(pkg: String): Boolean {
        if (pkg.isEmpty()) return true
        if (pkg == "com.android.systemui" || pkg == "android" || pkg == this.packageName) return true
        if (pkg.startsWith("com.android.systemui") || pkg.startsWith("com.android.intentresolver") || pkg.startsWith("com.android.chooser")) return true
        if (pkg.contains("permissioncontroller") || pkg.contains("inputmethod") || pkg.contains("keyboard") ||
            pkg.contains("ime") || pkg.contains("chooser") || pkg.contains("intentresolver") ||
            pkg.contains("media") || pkg.contains("photopicker") || pkg.contains("documentsui") ||
            pkg.contains("biometrics") || pkg.contains("gms") || pkg.contains("packageinstaller")) {
            return true
        }
        return false
    }

    private fun flushActiveSessionTo(prefsManager: PreferencesManager) {
        cancelActiveCountdown()
        cancelTimerNotification()
        val pkg = activeTimedPackage ?: return
        val elapsed = ((System.currentTimeMillis() - sessionStartMs) / 1000L).coerceAtLeast(0L)
        if (elapsed > 0L) {
            prefsManager.addUsedSeconds(pkg, elapsed)
        }
        activeTimedPackage = null
        sessionStartMs = 0L
        sessionElapsedSeconds = 0L
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                TIMER_NOTIFICATION_CHANNEL_ID,
                "Fravo App Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live remaining screen time for active apps"
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun updateActiveTimerNotification(packageName: String, remainingSeconds: Long) {
        try {
            createNotificationChannel()
            val pm = packageManager
            val appName = try {
                val info = pm.getApplicationInfo(packageName, 0)
                pm.getApplicationLabel(info).toString()
            } catch (e: Exception) { packageName }

            val mins = remainingSeconds / 60
            val secs = remainingSeconds % 60
            val timeStr = if (mins > 0) "$mins min ${secs}s" else "${secs}s"
            val warning = if (remainingSeconds <= 60) " ⚠️" else ""

            val smallIconRes: Int = run {
                val hostPkg = applicationContext.packageName
                try {
                    val id = pm.getResourcesForApplication(hostPkg).getIdentifier("ic_notification", "drawable", hostPkg)
                    if (id != 0) return@run id
                    val mipId = pm.getResourcesForApplication(hostPkg).getIdentifier("ic_launcher", "mipmap", hostPkg)
                    if (mipId != 0) return@run mipId
                } catch (_: Exception) {}
                android.R.drawable.ic_dialog_info
            }

            // Tap action: open Fravo so the user can check their budget
            val launchIntent = packageManager.getLaunchIntentForPackage(this.packageName)
            val pendingIntent = if (launchIntent != null) {
                android.app.PendingIntent.getActivity(
                    this, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
            } else null

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationCompat.Builder(this, TIMER_NOTIFICATION_CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                NotificationCompat.Builder(this)
            }

            // Read the full daily limit to compute progress
            val timeLimitInfo = prefsManager.getAppTimeLimit(packageName)
            val totalDailySeconds = timeLimitInfo?.get("dailyLimitSeconds") as? Long ?: 1L
            val usedSeconds = totalDailySeconds - remainingSeconds

            val notification = builder
                .setSmallIcon(smallIconRes)
                .setContentTitle("$appName — Screen Time")
                .setContentText("$timeStr remaining today$warning")
                .setProgress(totalDailySeconds.toInt(), usedSeconds.toInt(), false)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .apply { pendingIntent?.let { setContentIntent(it) } }
                .build()

            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(TIMER_NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.e(TAG, "updateActiveTimerNotification error: ${e.message}")
        }
    }

    private fun cancelTimerNotification() {
        try {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(TIMER_NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    private fun ensureAppIsBlocked(packageName: String, prefsManager: PreferencesManager) {
        val blocked = prefsManager.getBlockedApps()
        if (!blocked.contains(packageName)) {
            val updated = blocked.toMutableSet().apply { add(packageName) }
            prefsManager.saveBlockedApps(updated)
        }
        checkCurrentForegroundApp(packageName)
    }

    private fun handleMidnightReset(prefsManager: PreferencesManager, today: String) {
        lastCheckedDate = today
        // Discard in-memory session WITHOUT writing stale elapsed seconds back to
        // the DB — the DB is about to be zeroed so flushing would immediately
        // restore yesterday's seconds into the fresh record.
        resetSessionState()
        prefsManager.resetAllDailyUsage()

        // In Fravo, apps must NEVER be automatically unblocked at midnight.
        // Users earn screen time exclusively by walking steps on the new day.
        // Ensure all monitored apps remain explicitly blocked at midnight.
        val configuredApps = prefsManager.getBlockedApps()
        val timeLimitedPackages = prefsManager.getTimeLimitedPackages()
        val allMonitored = (configuredApps + timeLimitedPackages).toMutableSet()
        if (allMonitored.isNotEmpty()) {
            prefsManager.saveBlockedApps(allMonitored)
        }
        checkCurrentForegroundApp()
    }
}

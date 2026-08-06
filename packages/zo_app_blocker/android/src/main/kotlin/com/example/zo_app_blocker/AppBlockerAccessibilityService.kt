package com.example.zo_app_blocker

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
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

        @Volatile var instance: AppBlockerAccessibilityService? = null
            private set

        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        fun todayString(): String = DATE_FORMAT.format(Date())

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
    private var activeTimedPackage: String? = null
    private var sessionStartMs: Long = 0L
    private var sessionElapsedSeconds: Long = 0L
    private var lastCheckedDate: String = todayString()

    private val timedCheckRunnable = object : Runnable {
        override fun run() {
            val pkg = activeTimedPackage ?: return
            val timeLimitInfo = prefsManager.getAppTimeLimit(pkg)
            if (timeLimitInfo != null) {
                val limitSeconds = timeLimitInfo["dailyLimitSeconds"] as? Long ?: 0L
                val usedSeconds = timeLimitInfo["usedSeconds"] as? Long ?: 0L
                val elapsedSec = ((System.currentTimeMillis() - sessionStartMs) / 1000L).coerceAtLeast(0L)
                val totalUsed = usedSeconds + elapsedSec
                if (totalUsed >= limitSeconds) {
                    flushActiveSessionTo(prefsManager)
                    ensureAppIsBlocked(pkg, prefsManager)
                    showOverlayForPackage(pkg)
                    return
                }
            }
            handler.postDelayed(this, 2000L)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        prefsManager = PreferencesManager(this)
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        flutterOverlayManager = FlutterOverlayManager(this)
        flutterOverlayManager.preWarmEngine()

        Log.i(TAG, "AppBlockerAccessibilityService connected successfully.")

        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        this.serviceInfo = info

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

        // Ignore system packages, launcher, or our own app
        if (currentPkg == "com.android.systemui" || currentPkg == this.packageName || isLauncherPackage(currentPkg)) {
            if (activeTimedPackage != null && currentPkg != activeTimedPackage) {
                flushActiveSessionTo(prefsManager)
            }
            if (currentPkg != this.packageName) {
                lastPackage = currentPkg
            }
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

        // Evaluate Time Limit
        val timeLimitInfo = prefsManager.getAppTimeLimit(currentPkg)
        if (timeLimitInfo != null) {
            val limitSeconds = timeLimitInfo["dailyLimitSeconds"] as? Long ?: 0L
            val usedSeconds = timeLimitInfo["usedSeconds"] as? Long ?: 0L
            val remaining = (limitSeconds - usedSeconds).coerceAtLeast(0L)

            if (remaining <= 0L) {
                flushActiveSessionTo(prefsManager)
                ensureAppIsBlocked(currentPkg, prefsManager)
                // Actively kill the app if it is in the foreground
                if (currentPkg == lastPackage && currentPkg.isNotEmpty()) {
                    killForegroundApp()
                }
                return
            }

            if (activeTimedPackage != currentPkg) {
                flushActiveSessionTo(prefsManager)
                activeTimedPackage = currentPkg
                sessionStartMs = System.currentTimeMillis()
                sessionElapsedSeconds = 0L
                handler.removeCallbacks(timedCheckRunnable)
                handler.postDelayed(timedCheckRunnable, 2000L)
                // Instantly notify Flutter to sync steps + usage
                ZoAppBlockerPlugin.onAppOpened(currentPkg)
            }
        } else {
            if (activeTimedPackage != null) {
                flushActiveSessionTo(prefsManager)
            }
            checkCurrentForegroundApp(currentPkg)
        }
    }

    override fun onInterrupt() {
        Log.w(TAG, "AccessibilityService interrupted")
    }

    override fun onDestroy() {
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

    private fun isLauncherPackage(packageName: String): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val res = packageManager.resolveActivity(intent, 0)
        return res?.activityInfo?.packageName == packageName
    }

    private fun flushActiveSessionTo(prefsManager: PreferencesManager) {
        handler.removeCallbacks(timedCheckRunnable)
        val pkg = activeTimedPackage ?: return
        val elapsed = ((System.currentTimeMillis() - sessionStartMs) / 1000L).coerceAtLeast(0L)
        if (elapsed > 0L) {
            prefsManager.addUsedSeconds(pkg, elapsed)
        }
        activeTimedPackage = null
        sessionStartMs = 0L
        sessionElapsedSeconds = 0L
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
}

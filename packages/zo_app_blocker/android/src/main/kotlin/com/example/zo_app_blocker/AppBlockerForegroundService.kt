package com.example.zo_app_blocker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
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

        // When screen is on: poll every 1.5 s (vs 1 s before).
        // Saves ~33% CPU cycles with no perceptible latency difference.
        private const val POLL_INTERVAL_MS = 1500L

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

    // ── Screen-state receiver ────────────────────────────────────────────────
    // Pauses the poll loop the instant the screen turns off (no app can be
    // opened with the screen off) and resumes it when the screen turns back on.
    // This is the single biggest battery saving: zero CPU wakeups during standby.
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> pausePolling()
                Intent.ACTION_SCREEN_ON  -> resumePolling()
            }
        }
    }

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

    // ── Polling runnable ─────────────────────────────────────────────────────

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!isPolling) return
            poll()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    // ── Service lifecycle ────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefsManager = PreferencesManager(this)
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        flutterOverlayManager = FlutterOverlayManager(this)

        createNotificationChannel()
        flutterOverlayManager.preWarmEngine()

        // Register screen on/off receiver.
        // These are not sticky — must be registered dynamically, not in manifest.
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        registerReceiver(screenReceiver, filter)
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

        // Only start the poll loop if the screen is currently on.
        // If the service is (re)started while the screen is off, we wait for
        // the ACTION_SCREEN_ON broadcast before burning any CPU.
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (pm.isInteractive) {
            startPolling()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        flushActiveSession()
        stopPolling()
        removeOverlay()
        flutterOverlayManager.destroy()
        try { unregisterReceiver(screenReceiver) } catch (_: Exception) {}
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Polling control ──────────────────────────────────────────────────────

    private fun startPolling() {
        if (isPolling) return
        isPolling = true
        handler.post(pollRunnable)
    }

    private fun stopPolling() {
        isPolling = false
        handler.removeCallbacks(pollRunnable)
    }

    /** Called when screen turns off — stops the loop entirely. */
    private fun pausePolling() {
        if (!isPolling) return
        isPolling = false
        handler.removeCallbacks(pollRunnable)
        // Flush any active timed session so usage is persisted while idle.
        flushActiveSessionTo(prefsManager)
    }

    /** Called when screen turns on — resumes the loop. */
    private fun resumePolling() {
        startPolling()
    }

    // ── Poll body ────────────────────────────────────────────────────────────

    private fun poll() {
        val today = todayString()
        if (today != lastCheckedDate) {
            handleMidnightReset(prefsManager, today)
        }

        val currentPkg = getForegroundAppFromUsageStats()
        if (currentPkg.isNullOrEmpty()) {
            flushActiveSessionTo(prefsManager)
            return
        }

        // ── Early exit: same package, no time limit active ───────────────────
        // If the foreground app hasn't changed since the last poll AND we're not
        // tracking a timed session, there is nothing to evaluate. Skip all the
        // blocking logic to avoid redundant SharedPreferences / SQLite reads.
        if (currentPkg == lastPackage &&
            activeTimedPackage == null &&
            currentPkg != "com.android.systemui" &&
            !isLauncherPackage(currentPkg)) {
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
            return
        }

        lastPackage = currentPkg

        val timeLimitInfo = prefsManager.getAppTimeLimit(currentPkg)

        if (timeLimitInfo != null) {
            val limitSeconds = timeLimitInfo["dailyLimitSeconds"] as? Long ?: 0L
            val usedSeconds = timeLimitInfo["usedSeconds"] as? Long ?: 0L
            val remaining = (limitSeconds - usedSeconds).coerceAtLeast(0L)

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
                sessionElapsedSeconds = 0L
            }

            val sessionElapsedSec = (System.currentTimeMillis() - sessionStartMs) / 1000L
            val liveRemaining = (remaining - sessionElapsedSec).coerceAtLeast(0L)
            sessionElapsedSeconds = sessionElapsedSec

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
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        // Query a slightly wider window (3× poll interval) so we never miss
        // a fast app switch that happened between two polls.
        val events = usm.queryEvents(time - POLL_INTERVAL_MS * 3, time) ?: return lastPackage

        var foregroundApp: String? = null
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                foregroundApp = event.packageName
            }
        }
        return foregroundApp ?: lastPackage
    }

    // -------------------------------------------------------------------------
    // Blocking Logic
    // -------------------------------------------------------------------------

    fun checkCurrentForegroundApp() {
        if (flutterOverlayManager.isOverlayVisible || overlayView != null) {
            val blockedPkg = flutterOverlayManager.currentBlockedPackage
                ?: return
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

    fun temporarySessionUnlock(packageName: String) {
        // We use a strict foreground session instead
        currentUnblockedSessionApp = packageName
        if (lastPackage == packageName) {
            lastPackage = ""
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
        val elapsed = ((System.currentTimeMillis() - sessionStartMs) / 1000L).coerceAtLeast(0L)
        if (elapsed > 0L) {
            PreferencesManager(this).addUsedSeconds(pkg, elapsed)
        }
        activeTimedPackage = null
        sessionStartMs = 0L
        sessionElapsedSeconds = 0L
    }

    private fun flushActiveSessionTo(prefsManager: PreferencesManager) {
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
            NotificationCompat.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            NotificationCompat.Builder(this)
        }

        val pm = packageManager
        val appName = try {
            applicationInfo.loadLabel(pm).toString()
        } catch (e: Exception) { "App" }

        val prefsManager = PreferencesManager(this)
        val hostPackageName = applicationContext.packageName

        // ── Small icon (status bar) ──────────────────────────────────────────
        // MUST be a flat single-colour drawable — never an adaptive icon or PNG
        // with colour, or Android renders it blank / invisible.
        // Priority: custom name from config → "ic_launcher" → "ic_notification" → application icon → system fallback.
        val savedIconName = prefsManager.getNotificationConfig()["notificationIcon"]
        val smallIconRes: Int = run {
            val candidates = mutableListOf<String>()
            if (!savedIconName.isNullOrBlank()) candidates += savedIconName
            candidates += "ic_launcher"
            candidates += "ic_notification"

            android.util.Log.d("AppBlockerService", "Looking for notification icon. Host package: $hostPackageName")
            android.util.Log.d("AppBlockerService", "Icon candidates: $candidates")

            try {
                val hostRes = packageManager.getResourcesForApplication(hostPackageName)
                for (name in candidates) {
                    // Try drawable first
                    var id = hostRes.getIdentifier(name, "drawable", hostPackageName)
                    if (id != 0) {
                        android.util.Log.d("AppBlockerService", "Found drawable: $name with id: $id")
                        return@run id
                    }
                    // Try mipmap as fallback (for launcher icons)
                    id = hostRes.getIdentifier(name, "mipmap", hostPackageName)
                    if (id != 0) {
                        android.util.Log.d("AppBlockerService", "Found mipmap: $name with id: $id")
                        return@run id
                    }
                    android.util.Log.d("AppBlockerService", "Not found: $name")
                }
            } catch (e: Exception) {
                android.util.Log.e("AppBlockerService", "Exception in host resource lookup: ${e.message}")
                for (name in candidates) {
                    var id = resources.getIdentifier(name, "drawable", hostPackageName)
                    if (id != 0) {
                        android.util.Log.d("AppBlockerService", "Found drawable in fallback: $name with id: $id")
                        return@run id
                    }
                    id = resources.getIdentifier(name, "mipmap", hostPackageName)
                    if (id != 0) {
                        android.util.Log.d("AppBlockerService", "Found mipmap in fallback: $name with id: $id")
                        return@run id
                    }
                }
            }
            
            // Final fallback: try to get the application icon directly
            try {
                val appInfo = packageManager.getApplicationInfo(hostPackageName, 0)
                val appIcon = appInfo.icon
                if (appIcon != 0) {
                    android.util.Log.d("AppBlockerService", "Using application icon: $appIcon")
                    return@run appIcon
                }
            } catch (e: Exception) {
                android.util.Log.e("AppBlockerService", "Exception getting application icon: ${e.message}")
            }
            
            android.util.Log.w("AppBlockerService", "No custom icon found, using system default")
            android.R.drawable.ic_dialog_info
        }

        // ── Large icon (notification card) ───────────────────────────────────
        // Try to load a specific notification icon file to avoid adaptive icon issues
        val largeIconBitmap = try {
            android.util.Log.d("AppBlockerService", "Generating large icon for host package: $hostPackageName")
            
            var largeIconRes: android.graphics.Bitmap? = null
            
            // Try loading notification_large_icon.png from host app first
            try {
                val hostRes = packageManager.getResourcesForApplication(hostPackageName)
                val id = hostRes.getIdentifier("notification_large_icon", "drawable", hostPackageName)
                android.util.Log.d("AppBlockerService", "Looking for notification_large_icon in host package: $id")
                if (id != 0) {
                    largeIconRes = android.graphics.BitmapFactory.decodeResource(hostRes, id)
                    if (largeIconRes != null) {
                        android.util.Log.d("AppBlockerService", "Successfully loaded notification_large_icon from host package")
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("AppBlockerService", "Failed to load notification_large_icon from host: ${e.message}")
            }
            
            // If that didn't work, try from our own package
            if (largeIconRes == null) {
                try {
                    val id = resources.getIdentifier("notification_large_icon", "drawable", packageName)
                    android.util.Log.d("AppBlockerService", "Looking for notification_large_icon in our package: $id")
                    if (id != 0) {
                        largeIconRes = android.graphics.BitmapFactory.decodeResource(resources, id)
                        if (largeIconRes != null) {
                            android.util.Log.d("AppBlockerService", "Successfully loaded notification_large_icon from our package")
                        }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("AppBlockerService", "Failed to load notification_large_icon from our package: ${e.message}")
                }
            }
            
            if (largeIconRes != null) {
                android.util.Log.d("AppBlockerService", "Large icon loaded successfully, size: ${largeIconRes.width}x${largeIconRes.height}")
                // Scale to notification size if needed
                val targetSize = 192
                if (largeIconRes.width != targetSize || largeIconRes.height != targetSize) {
                    val scaledBitmap = android.graphics.Bitmap.createScaledBitmap(largeIconRes, targetSize, targetSize, true)
                    android.util.Log.d("AppBlockerService", "Scaled icon to ${targetSize}x${targetSize}")
                    scaledBitmap
                } else {
                    largeIconRes
                }
            } else {
                android.util.Log.w("AppBlockerService", "Could not load custom notification icon, using fallback")
                null
            }
        } catch (e: Exception) {
            android.util.Log.e("AppBlockerService", "Failed to generate large icon: ${e.message}")
            null
        }

        val config = prefsManager.getBlockScreenConfig()
        val notifTitle = title ?: (config["notificationTitle"] ?: "$appName Blocker Active")
        val notifDesc  = text  ?: (config["notificationDescription"] ?: "Monitoring and blocking restricted apps.")

        android.util.Log.d("AppBlockerService", "Building notification with largeIconBitmap: ${largeIconBitmap != null}")
        android.util.Log.d("AppBlockerService", "Small icon resource ID: $smallIconRes")
        if (largeIconBitmap != null) {
            android.util.Log.d("AppBlockerService", "Large icon bitmap size: ${largeIconBitmap.width}x${largeIconBitmap.height}")
        }

        val notification = builder
            .setContentTitle(notifTitle)
            .setContentText(notifDesc)
            .setSmallIcon(smallIconRes)
            .apply { 
                android.util.Log.d("AppBlockerService", "Setting large icon in builder")
                largeIconBitmap?.let { 
                    android.util.Log.d("AppBlockerService", "Large icon being set: ${it.width}x${it.height}")
                    setLargeIcon(it) 
                } ?: android.util.Log.w("AppBlockerService", "Large icon bitmap is null, not setting")
            }
            .setOngoing(true)
            .build()
        
        return notification
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Delete existing channel to force refresh with new icon
            try {
                manager.deleteNotificationChannel(CHANNEL_ID)
                android.util.Log.d("AppBlockerService", "Deleted existing notification channel")
            } catch (e: Exception) {
                android.util.Log.d("AppBlockerService", "No existing channel to delete: ${e.message}")
            }
            
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocker Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the app blocker running in the background."
            }
            manager.createNotificationChannel(channel)
            android.util.Log.d("AppBlockerService", "Created new notification channel")
        }
    }
}

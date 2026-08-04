package com.example.zo_app_blocker

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.util.GeneratedPluginRegister
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.FlutterCallbackInformation
import io.flutter.embedding.android.FlutterView

/**
 * Manages the FlutterEngine and FlutterView used for rendering the customizable
 * block screen over other apps.
 *
 * Design principles:
 * - Single source of truth: [isOverlayVisible] is THE authoritative flag for overlay state.
 * - No stale view reuse: FlutterView is always freshly created on each show, while the
 *   engine is kept alive between shows for fast re-display.
 * - Instant display: overlay is shown immediately; app icon is sent asynchronously.
 * - Thread-safe: all WindowManager operations happen on the main thread via [handler].
 */
class FlutterOverlayManager(private val context: Context) {
    private var engine: FlutterEngine? = null
    private var flutterView: FlutterView? = null
    private var channel: MethodChannel? = null
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val prefsManager = PreferencesManager(context)
    private val handler = Handler(Looper.getMainLooper())

    /**
     * The single, authoritative flag for whether the overlay is currently on screen.
     * AppBlockerForegroundService must read this
     * instead of maintaining their own copies.
     */
    @Volatile
    var isOverlayVisible = false
        private set

    private var isEngineReady = false

    /** The package name currently being blocked. Readable by the foreground service. */
    @Volatile
    var currentBlockedPackage: String? = null
        private set

    // Pending block data queued if the engine hasn't signalled ready yet.
    private var pendingBlockData: Map<String, Any?>? = null

    /** Incremented on every hide to cancel in-flight show operations. */
    private var overlayGeneration = 0

    // ------------------------------------------------------------------------
    // Engine lifecycle
    // ------------------------------------------------------------------------

    /**
     * Pre-warm the FlutterEngine so it's ready when the first block event fires.
     * Call this from onServiceConnected, NOT from showOverlay, to eliminate startup lag.
     */
    fun preWarmEngine() {
        if (engine == null && prefsManager.hasBlockScreenCallback()) {
            handler.post { startEngine() }
        }
    }

    /**
     * Start the FlutterEngine using the saved Dart callback handle.
     * Must be called on the main thread.
     */
    private fun startEngine() {
        if (engine != null) return

        val callbackHandle = prefsManager.getBlockScreenCallbackHandle()
        if (callbackHandle == -1L) return

        val callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle)
            ?: return

        engine = FlutterEngine(context.applicationContext)
        GeneratedPluginRegister.registerGeneratedPlugins(engine!!)

        channel = MethodChannel(engine!!.dartExecutor.binaryMessenger, "zo_app_blocker_block_screen")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "blockScreenReady" -> {
                    isEngineReady = true
                    // Drain any pending block event now that Dart is listening.
                    pendingBlockData?.let {
                        sendBlockEvent(it)
                        pendingBlockData = null
                    }
                    result.success(null)
                }
                "dismissBlockScreen" -> {
                    val pkg = currentBlockedPackage
                    AppBlockerForegroundService.instance?.onUserDismissedBlock(pkg)
                    result.success(null)
                }
                "temporarySessionUnlock" -> {
                    currentBlockedPackage?.let { pkg ->
                        AppBlockerForegroundService.instance?.temporarySessionUnlock(pkg)
                        val launchIntent = context.packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(launchIntent)
                        }
                    }
                    hideOverlay()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val dartEntrypoint = DartExecutor.DartEntrypoint(
            FlutterInjector.instance().flutterLoader().findAppBundlePath(),
            callbackInfo.callbackLibraryPath,
            callbackInfo.callbackName
        )
        engine!!.dartExecutor.executeDartEntrypoint(dartEntrypoint)
    }

    // ------------------------------------------------------------------------
    // Overlay show / hide
    // ------------------------------------------------------------------------

    /**
     * Show the Flutter overlay for the given blocked app.
     *
     * The overlay is displayed immediately (no waiting for the icon).
     * [appName] and [appIcon] are sent asynchronously to the Dart layer.
     *
     * This method is idempotent if already showing for the SAME package.
     * If called for a DIFFERENT package while showing, the overlay is
     * refreshed with the new package's data.
     */
    fun showOverlay(
        packageName: String,
        appName: String?,
        appIcon: ByteArray?,
        onEngineUnavailable: (() -> Unit)? = null,
        onWindowAddFailed: (() -> Unit)? = null
    ) {
        // If already showing for this exact package, nothing to do.
        if (isOverlayVisible && currentBlockedPackage == packageName) return

        val generation = ++overlayGeneration
        currentBlockedPackage = packageName

        handler.post {
            // A dismiss arrived while this show was queued — abort.
            if (generation != overlayGeneration) return@post

            // Ensure engine is started (no-op if already running).
            if (engine == null) startEngine()

            // Fall back to native overlay if the Flutter engine can't start.
            if (engine == null) {
                currentBlockedPackage = null
                onEngineUnavailable?.invoke()
                return@post
            }

            // Remove any existing view cleanly before adding a new one.
            removeFlutterViewFromWindow()

            // Always create a fresh FlutterView to avoid stale render state.
            val newView = FlutterView(context.applicationContext)
            newView.attachToFlutterEngine(engine!!)
            flutterView = newView

            val params = buildWindowParams()

            try {
                windowManager.addView(flutterView, params)
                // Mark visible only AFTER a successful add.
                if (generation != overlayGeneration) {
                    removeFlutterViewFromWindow()
                    return@post
                }
                isOverlayVisible = true
                engine?.lifecycleChannel?.appIsResumed()
            } catch (e: Exception) {
                // Window add failed — fall back to native overlay.
                e.printStackTrace()
                flutterView?.detachFromFlutterEngine()
                flutterView = null
                currentBlockedPackage = null
                onWindowAddFailed?.invoke()
                return@post
            }

            val eventData = mapOf(
                "packageName" to packageName,
                "appName" to appName,
                "appIcon" to appIcon
            )

            if (isEngineReady) {
                sendBlockEvent(eventData)
            } else {
                // Queue it — blockScreenReady will drain it.
                pendingBlockData = eventData
            }
        }
    }

    /**
     * Hide and remove the Flutter overlay.
     * Safe to call from any thread; work is posted to the main thread.
     */
    fun hideOverlay() {
        // Invalidate any in-flight showOverlay posts.
        overlayGeneration++
        isOverlayVisible = false
        currentBlockedPackage = null
        pendingBlockData = null

        handler.post {
            removeFlutterViewFromWindow()
            engine?.lifecycleChannel?.appIsPaused()
        }
    }

    // ------------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------------

    /**
     * Detach and remove the FlutterView from the WindowManager.
     * Always detaches from engine first to avoid orphaned renderer state.
     */
    private fun removeFlutterViewFromWindow() {
        val view = flutterView ?: return
        try {
            // Detach from engine FIRST so it can clean up rendering resources.
            view.detachFromFlutterEngine()
            if (view.parent != null) {
                windowManager.removeView(view)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            flutterView = null
        }
    }

    private fun buildWindowParams(): WindowManager.LayoutParams {
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            PixelFormat.TRANSLUCENT
        )
    }

    /**
     * Send updated app name/icon data to an overlay that is already visible.
     * This avoids recreating the FlutterView — it just sends a new block event
     * to the already-running Dart isolate.
     *
     * Only acts if the overlay is currently visible for [packageName].
     */
    fun updateBlockedAppData(packageName: String, appName: String?, appIcon: ByteArray?) {
        if (currentBlockedPackage != packageName) return
        val eventData = mapOf(
            "packageName" to packageName,
            "appName" to appName,
            "appIcon" to appIcon
        )
        handler.post {
            if (currentBlockedPackage != packageName) return@post
            if (isEngineReady) {
                sendBlockEvent(eventData)
            } else {
                // Will be picked up by the blockScreenReady drain path.
                pendingBlockData = eventData
            }
        }
    }

    private fun sendBlockEvent(data: Map<String, Any?>) {
        channel?.invokeMethod("onAppBlocked", data)
    }

    // ------------------------------------------------------------------------
    // Cleanup
    // ------------------------------------------------------------------------

    /**
     * Release all resources. Call when the accessibility service is destroyed.
     */
    fun destroy() {
        overlayGeneration++
        isOverlayVisible = false
        currentBlockedPackage = null
        pendingBlockData = null
        handler.post {
            removeFlutterViewFromWindow()
            channel?.setMethodCallHandler(null)
            channel = null
            engine?.destroy()
            engine = null
            isEngineReady = false
        }
    }
}

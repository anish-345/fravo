package avionti.fravo

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Registers "fravo/navigation" on every Flutter engine, including the
 * separate isolate engine that zo_app_blocker uses for the block screen.
 *
 * Works without an Activity reference — uses applicationContext only —
 * so ACTION_MAIN / CATEGORY_HOME can be fired from any isolate.
 */
class GoHomePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "fravo/navigation")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "goHome" -> {
                val ctx = appContext
                if (ctx == null) {
                    result.error("NO_CONTEXT", "Application context is null", null)
                    return
                }
                try {
                    ctx.startActivity(
                        Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("GO_HOME_FAILED", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }
}

package avionti.fravo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class FravoWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)

        // Read values stored by Flutter HomeWidget package
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.fravo_widget_layout).apply {
                val steps = widgetData.getString("fravo_steps", "0") ?: "0"
                val goal = widgetData.getString("fravo_step_goal", "10,000") ?: "10,000"
                val remaining = widgetData.getString("fravo_time_remaining", "0m") ?: "0m"
                val streakDays = widgetData.getInt("fravo_streak_days", 1)
                val dialogue = widgetData.getString(
                    "fravo_companion_dialogue",
                    "🌱 A gentle stroll will awaken your screen time!"
                ) ?: "🌱 A gentle stroll will awaken your screen time!"

                // Set Text Content
                setTextViewText(R.id.widget_speech_bubble, dialogue)
                setTextViewText(R.id.widget_time_remaining, "$remaining left")
                setTextViewText(R.id.widget_steps, "$steps / $goal")
                setTextViewText(R.id.widget_streak_chip, "🔥 ${streakDays}d")

                // PendingIntent to launch Fravo app cleanly on tapping ANY part of the widget
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                    setOnClickPendingIntent(R.id.widget_stage, pendingIntent)
                    setOnClickPendingIntent(R.id.widget_speech_bubble, pendingIntent)
                    setOnClickPendingIntent(R.id.widget_stat_container, pendingIntent)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

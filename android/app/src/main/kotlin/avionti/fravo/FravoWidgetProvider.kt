package avionti.fravo

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.view.View
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
                val earned = widgetData.getString("fravo_time_earned", "0m") ?: "0m"
                val used = widgetData.getString("fravo_time_used", "0m") ?: "0m"
                val remaining = widgetData.getString("fravo_time_remaining", "0m") ?: "0m"
                
                val progressPercent = widgetData.getInt("fravo_time_progress", 0)
                val isPremium = widgetData.getBoolean("fravo_is_premium", false)
                
                val appPackage = widgetData.getString("fravo_selected_app_package", "") ?: ""
                val appName = widgetData.getString("fravo_selected_app_name", "Blocked App") ?: "Blocked App"

                // Update Steps Card
                setTextViewText(R.id.fravo_steps, steps)
                setTextViewText(R.id.fravo_step_goal, "Goal: $goal")

                // Extract installed app logo from Android PackageManager
                val appBitmap = loadAppIconBitmap(context, appPackage)

                if (isPremium) {
                    // PREMIUM USER LAYOUT: Horizontal Bar Chart + App Logo
                    setViewVisibility(R.id.widget_premium_container, View.VISIBLE)
                    setViewVisibility(R.id.widget_free_container, View.GONE)
                    setTextViewText(R.id.widget_status, "⭐ PREMIUM")

                    setTextViewText(R.id.widget_app_name_premium, appName)
                    setTextViewText(R.id.fravo_premium_remaining, "$remaining left")
                    setProgressBar(R.id.widget_horizontal_progress, 100, progressPercent, false)
                    setTextViewText(R.id.fravo_premium_used, "Used: $used of $earned")

                    if (appBitmap != null) {
                        setImageViewBitmap(R.id.widget_app_logo_premium, appBitmap)
                    } else {
                        setImageViewResource(R.id.widget_app_logo_premium, R.mipmap.ic_launcher)
                    }
                } else {
                    // FREE USER LAYOUT: Circular Progress Chart with App Logo in Center
                    setViewVisibility(R.id.widget_free_container, View.VISIBLE)
                    setViewVisibility(R.id.widget_premium_container, View.GONE)
                    setTextViewText(R.id.widget_status, "ACTIVE")

                    setProgressBar(R.id.widget_circular_progress, 100, progressPercent, false)
                    setTextViewText(R.id.fravo_used_text, "Used $used / $earned")

                    if (appBitmap != null) {
                        setImageViewBitmap(R.id.widget_app_logo_center, appBitmap)
                    } else {
                        setImageViewResource(R.id.widget_app_logo_center, R.mipmap.ic_launcher)
                    }
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun loadAppIconBitmap(context: Context, packageName: String): Bitmap? {
        if (packageName.isEmpty()) return null
        return try {
            val drawable: Drawable = context.packageManager.getApplicationIcon(packageName)
            val bitmap = Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtLeast(48),
                drawable.intrinsicHeight.coerceAtLeast(48),
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bitmap
        } catch (e: Exception) {
            null
        }
    }
}

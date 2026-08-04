package com.example.zo_app_blocker

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

class AppResolver(private val context: Context) {
    suspend fun getInstalledApps(): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        val pm = context.packageManager
        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfoList = pm.queryIntentActivities(launcherIntent, 0)
        
        val launcherPackage = pm.resolveActivity(
            Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) },
            PackageManager.MATCH_DEFAULT_ONLY
        )?.activityInfo?.packageName

        resolveInfoList
            .filter { info ->
                val pkg = info.activityInfo.packageName
                pkg != context.packageName && pkg != launcherPackage && pkg != "com.android.launcher"
            }
            .mapNotNull { info ->
                try {
                    val pkg = info.activityInfo.packageName
                    val label = info.loadLabel(pm).toString()
                    val icon = info.loadIcon(pm)
                    val isSystem = (info.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                    if (isSystem) return@mapNotNull null

                    mapOf(
                        "packageName" to pkg,
                        "appName" to label,
                        "icon" to drawableToByteArray(icon),
                        "isSystemApp" to isSystem,
                    )
                } catch (_: Exception) {
                    null
                }
            }
            .sortedBy { (it["appName"] as? String)?.lowercase() }
    }

    suspend fun getAppIcon(packageName: String): ByteArray? = withContext(Dispatchers.IO) {
        getAppIconSync(packageName)
    }

    fun getAppIconSync(packageName: String): ByteArray? {
        return try {
            val pm = context.packageManager
            val info = pm.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
            val icon = info.loadIcon(pm)
            drawableToByteArray(icon)
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToByteArray(drawable: Drawable): ByteArray {
        val width = drawable.intrinsicWidth.coerceAtLeast(1)
        val height = drawable.intrinsicHeight.coerceAtLeast(1)

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
        bitmap.recycle()

        return stream.toByteArray()
    }
}

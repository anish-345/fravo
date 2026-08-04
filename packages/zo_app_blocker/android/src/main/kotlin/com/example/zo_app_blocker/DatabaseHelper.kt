package com.example.zo_app_blocker

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_VERSION = 2
        private const val DATABASE_NAME = "zo_app_blocker.db"

        // Preferences Table
        const val TABLE_PREFERENCES = "preferences"
        const val COLUMN_PREF_KEY = "key"
        const val COLUMN_PREF_VALUE = "value"

        // Blocked Apps Table
        const val TABLE_BLOCKED_APPS = "blocked_apps"
        const val COLUMN_BLOCKED_PACKAGE = "package_name"

        // Block Activity Log Table
        const val TABLE_BLOCK_ACTIVITY = "block_activity"
        const val COLUMN_ACTIVITY_ID = "id"
        const val COLUMN_ACTIVITY_PACKAGE = "package_name"
        const val COLUMN_ACTIVITY_TIMESTAMP = "timestamp"

        // App Time Limits Table
        const val TABLE_TIME_LIMITS = "app_time_limits"
        const val COLUMN_TL_PACKAGE = "package_name"
        const val COLUMN_TL_LIMIT_SECONDS = "daily_limit_seconds"
        const val COLUMN_TL_USED_SECONDS = "used_seconds"
        const val COLUMN_TL_LAST_RESET = "last_reset_date"

        private val DATE_FORMAT = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        fun todayString(): String = DATE_FORMAT.format(Date())
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            "CREATE TABLE $TABLE_PREFERENCES(" +
                "$COLUMN_PREF_KEY TEXT PRIMARY KEY," +
                "$COLUMN_PREF_VALUE TEXT)"
        )
        db.execSQL(
            "CREATE TABLE $TABLE_BLOCKED_APPS(" +
                "$COLUMN_BLOCKED_PACKAGE TEXT PRIMARY KEY)"
        )
        db.execSQL(
            "CREATE TABLE $TABLE_BLOCK_ACTIVITY(" +
                "$COLUMN_ACTIVITY_ID INTEGER PRIMARY KEY AUTOINCREMENT," +
                "$COLUMN_ACTIVITY_PACKAGE TEXT," +
                "$COLUMN_ACTIVITY_TIMESTAMP INTEGER)"
        )
        db.execSQL(
            "CREATE TABLE $TABLE_TIME_LIMITS(" +
                "$COLUMN_TL_PACKAGE TEXT PRIMARY KEY," +
                "$COLUMN_TL_LIMIT_SECONDS INTEGER NOT NULL," +
                "$COLUMN_TL_USED_SECONDS INTEGER NOT NULL DEFAULT 0," +
                "$COLUMN_TL_LAST_RESET TEXT NOT NULL)"
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            // Migrate v1 → v2: just add the new table, preserve existing data.
            db.execSQL(
                "CREATE TABLE IF NOT EXISTS $TABLE_TIME_LIMITS(" +
                    "$COLUMN_TL_PACKAGE TEXT PRIMARY KEY," +
                    "$COLUMN_TL_LIMIT_SECONDS INTEGER NOT NULL," +
                    "$COLUMN_TL_USED_SECONDS INTEGER NOT NULL DEFAULT 0," +
                    "$COLUMN_TL_LAST_RESET TEXT NOT NULL)"
            )
        }
    }

    // --- Preference Methods ---

    fun setPreference(key: String, value: String) {
        val db = this.writableDatabase
        val values = ContentValues()
        values.put(COLUMN_PREF_KEY, key)
        values.put(COLUMN_PREF_VALUE, value)
        db.replace(TABLE_PREFERENCES, null, values)
    }

    fun getPreference(key: String, defaultValue: String?): String? {
        val db = this.readableDatabase
        val cursor = db.query(
            TABLE_PREFERENCES, arrayOf(COLUMN_PREF_VALUE),
            "$COLUMN_PREF_KEY=?", arrayOf(key), null, null, null, null
        )
        var result: String? = defaultValue
        if (cursor.moveToFirst()) {
            result = cursor.getString(0)
        }
        cursor.close()
        return result
    }

    fun deletePreference(key: String) {
        val db = this.writableDatabase
        db.delete(TABLE_PREFERENCES, "$COLUMN_PREF_KEY=?", arrayOf(key))
    }

    // --- Blocked Apps Methods ---

    fun saveBlockedApps(apps: Set<String>) {
        val db = this.writableDatabase
        db.beginTransaction()
        try {
            db.delete(TABLE_BLOCKED_APPS, null, null)
            for (app in apps) {
                val values = ContentValues()
                values.put(COLUMN_BLOCKED_PACKAGE, app)
                db.insert(TABLE_BLOCKED_APPS, null, values)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun getBlockedApps(): Set<String> {
        val apps = mutableSetOf<String>()
        val db = this.readableDatabase
        val cursor = db.rawQuery("SELECT $COLUMN_BLOCKED_PACKAGE FROM $TABLE_BLOCKED_APPS", null)
        if (cursor.moveToFirst()) {
            do {
                apps.add(cursor.getString(0))
            } while (cursor.moveToNext())
        }
        cursor.close()
        return apps
    }

    // --- Block Activity Methods ---

    fun logBlockEvent(packageName: String) {
        val db = this.writableDatabase
        val values = ContentValues()
        values.put(COLUMN_ACTIVITY_PACKAGE, packageName)
        values.put(COLUMN_ACTIVITY_TIMESTAMP, System.currentTimeMillis())
        db.insert(TABLE_BLOCK_ACTIVITY, null, values)
    }

    fun getBlockActivityLog(): List<Map<String, Any>> {
        val log = mutableListOf<Map<String, Any>>()
        val db = this.readableDatabase
        val cursor = db.rawQuery(
            "SELECT $COLUMN_ACTIVITY_PACKAGE, $COLUMN_ACTIVITY_TIMESTAMP FROM $TABLE_BLOCK_ACTIVITY ORDER BY $COLUMN_ACTIVITY_TIMESTAMP DESC",
            null
        )
        if (cursor.moveToFirst()) {
            do {
                val map = mapOf<String, Any>(
                    "packageName" to cursor.getString(0),
                    "timestamp" to cursor.getLong(1)
                )
                log.add(map)
            } while (cursor.moveToNext())
        }
        cursor.close()
        return log
    }

    fun clearBlockActivityLog() {
        val db = this.writableDatabase
        db.delete(TABLE_BLOCK_ACTIVITY, null, null)
    }

    // --- App Time Limit Methods ---

    /**
     * Sets (or replaces) a daily time limit for [packageName].
     * Resets used seconds to 0 and stamps today's date.
     */
    fun setAppTimeLimit(packageName: String, limitSeconds: Long) {
        val db = this.writableDatabase
        val values = ContentValues().apply {
            put(COLUMN_TL_PACKAGE, packageName)
            put(COLUMN_TL_LIMIT_SECONDS, limitSeconds)
            put(COLUMN_TL_USED_SECONDS, 0L)
            put(COLUMN_TL_LAST_RESET, todayString())
        }
        db.replace(TABLE_TIME_LIMITS, null, values)
    }

    /**
     * Returns all configured time limits after performing a midnight reset for each
     * entry whose last_reset_date is not today.
     */
    fun getAppTimeLimits(): List<Map<String, Any>> {
        val today = todayString()
        val db = this.writableDatabase  // writable because we may reset rows
        val result = mutableListOf<Map<String, Any>>()

        val cursor = db.rawQuery(
            "SELECT $COLUMN_TL_PACKAGE, $COLUMN_TL_LIMIT_SECONDS, $COLUMN_TL_USED_SECONDS, $COLUMN_TL_LAST_RESET FROM $TABLE_TIME_LIMITS",
            null
        )
        if (cursor.moveToFirst()) {
            do {
                val pkg = cursor.getString(0)
                val limitSec = cursor.getLong(1)
                var usedSec = cursor.getLong(2)
                val lastReset = cursor.getString(3)

                // Midnight reset
                if (lastReset != today) {
                    usedSec = 0L
                    val cv = ContentValues().apply {
                        put(COLUMN_TL_USED_SECONDS, 0L)
                        put(COLUMN_TL_LAST_RESET, today)
                    }
                    db.update(TABLE_TIME_LIMITS, cv, "$COLUMN_TL_PACKAGE=?", arrayOf(pkg))
                }

                val remaining = (limitSec - usedSec).coerceAtLeast(0L)
                result.add(
                    mapOf(
                        "packageName" to pkg,
                        "dailyLimitSeconds" to limitSec,
                        "usedSeconds" to usedSec,
                        "remainingSeconds" to remaining
                    )
                )
            } while (cursor.moveToNext())
        }
        cursor.close()
        return result
    }

    /**
     * Returns the time limit row for [packageName], with a midnight reset applied
     * if the date has changed. Returns null if no limit is configured.
     */
    fun getAppTimeLimit(packageName: String): Map<String, Any>? {
        val today = todayString()
        val db = this.writableDatabase
        val cursor = db.query(
            TABLE_TIME_LIMITS,
            arrayOf(COLUMN_TL_LIMIT_SECONDS, COLUMN_TL_USED_SECONDS, COLUMN_TL_LAST_RESET),
            "$COLUMN_TL_PACKAGE=?", arrayOf(packageName),
            null, null, null
        )
        if (!cursor.moveToFirst()) {
            cursor.close()
                return null
        }

        val limitSec = cursor.getLong(0)
        var usedSec = cursor.getLong(1)
        val lastReset = cursor.getString(2)
        cursor.close()

        if (lastReset != today) {
            usedSec = 0L
            val cv = ContentValues().apply {
                put(COLUMN_TL_USED_SECONDS, 0L)
                put(COLUMN_TL_LAST_RESET, today)
            }
            db.update(TABLE_TIME_LIMITS, cv, "$COLUMN_TL_PACKAGE=?", arrayOf(packageName))
        }

        val remaining = (limitSec - usedSec).coerceAtLeast(0L)
        return mapOf(
            "packageName" to packageName,
            "dailyLimitSeconds" to limitSec,
            "usedSeconds" to usedSec,
            "remainingSeconds" to remaining
        )
    }

    /**
     * Adds [seconds] to the used counter for [packageName].
     * Handles midnight reset if the date has rolled over.
     * Returns the remaining seconds after this addition.
     */
    fun addUsedSeconds(packageName: String, seconds: Long): Long {
        val today = todayString()
        val db = this.writableDatabase

        val cursor = db.query(
            TABLE_TIME_LIMITS,
            arrayOf(COLUMN_TL_LIMIT_SECONDS, COLUMN_TL_USED_SECONDS, COLUMN_TL_LAST_RESET),
            "$COLUMN_TL_PACKAGE=?", arrayOf(packageName),
            null, null, null
        )
        if (!cursor.moveToFirst()) {
            cursor.close()
                return Long.MAX_VALUE // No limit configured
        }

        val limitSec = cursor.getLong(0)
        var usedSec = cursor.getLong(1)
        val lastReset = cursor.getString(2)
        cursor.close()

        // Midnight reset
        if (lastReset != today) {
            usedSec = 0L
        }

        val newUsed = (usedSec + seconds).coerceAtMost(limitSec + 1)
        val cv = ContentValues().apply {
            put(COLUMN_TL_USED_SECONDS, newUsed)
            put(COLUMN_TL_LAST_RESET, today)
        }
        db.update(TABLE_TIME_LIMITS, cv, "$COLUMN_TL_PACKAGE=?", arrayOf(packageName))

        return (limitSec - newUsed).coerceAtLeast(0L)
    }

    /**
     * Resets today's used seconds to 0 for [packageName].
     */
    fun resetAppUsage(packageName: String) {
        val db = this.writableDatabase
        val cv = ContentValues().apply {
            put(COLUMN_TL_USED_SECONDS, 0L)
            put(COLUMN_TL_LAST_RESET, todayString())
        }
        db.update(TABLE_TIME_LIMITS, cv, "$COLUMN_TL_PACKAGE=?", arrayOf(packageName))
    }

    /**
     * Resets today's used seconds to 0 for ALL configured time-limit apps.
     * Called at midnight.
     */
    fun resetAllDailyUsage() {
        val db = this.writableDatabase
        val cv = ContentValues().apply {
            put(COLUMN_TL_USED_SECONDS, 0L)
            put(COLUMN_TL_LAST_RESET, todayString())
        }
        db.update(TABLE_TIME_LIMITS, cv, null, null)
    }

    /**
     * Removes a time limit entry entirely.
     */
    fun removeAppTimeLimit(packageName: String) {
        val db = this.writableDatabase
        db.delete(TABLE_TIME_LIMITS, "$COLUMN_TL_PACKAGE=?", arrayOf(packageName))
    }

    /**
     * Returns the set of package names that have time limits configured.
     */
    fun getTimeLimitedPackages(): Set<String> {
        val packages = mutableSetOf<String>()
        val db = this.readableDatabase
        val cursor = db.rawQuery("SELECT $COLUMN_TL_PACKAGE FROM $TABLE_TIME_LIMITS", null)
        if (cursor.moveToFirst()) {
            do { packages.add(cursor.getString(0)) } while (cursor.moveToNext())
        }
        cursor.close()
        return packages
    }
}

package com.example.zo_app_blocker

import android.content.Context

class PreferencesManager(context: Context) {
    private val dbHelper = DatabaseHelper(context)

    fun saveBlockedApps(apps: Set<String>) {
        dbHelper.saveBlockedApps(apps)
    }

    fun getBlockedApps(): Set<String> {
        return dbHelper.getBlockedApps()
    }

    fun setBlockAll(blockAll: Boolean) {
        dbHelper.setPreference("block_all", blockAll.toString())
    }

    fun isBlockAll(): Boolean {
        val value = dbHelper.getPreference("block_all", "false")
        return value == "true"
    }

    fun setNotificationConfig(config: Map<String, String>) {
        config.forEach { (key, value) ->
            dbHelper.setPreference("config_$key", value)
        }
    }

    fun getNotificationConfig(): Map<String, String?> {
        return mapOf(
            "notificationBannerTitle" to dbHelper.getPreference("config_notificationBannerTitle", null),
            "notificationBannerDescription" to dbHelper.getPreference("config_notificationBannerDescription", null),
            "notificationIcon" to dbHelper.getPreference("config_notificationIcon", null)
        )
    }

    fun getBlockScreenConfig(): Map<String, String?> {
        return mapOf(
            "backgroundColor"       to dbHelper.getPreference("config_backgroundColor", null),
            "titleColor"            to dbHelper.getPreference("config_titleColor", null),
            "descriptionColor"      to dbHelper.getPreference("config_descriptionColor", null),
            "title"                 to dbHelper.getPreference("config_title", null),
            "description"           to dbHelper.getPreference("config_description", null),
            "notificationTitle"     to dbHelper.getPreference("config_notificationTitle", null),
            "notificationDescription" to dbHelper.getPreference("config_notificationDescription", null)
        )
    }

    fun saveBlockScreenCallbackHandle(rawHandle: Long) {
        dbHelper.setPreference("block_screen_callback_handle", rawHandle.toString())
    }

    fun getBlockScreenCallbackHandle(): Long {
        val value = dbHelper.getPreference("block_screen_callback_handle", "-1")
        return value?.toLongOrNull() ?: -1L
    }

    fun hasBlockScreenCallback(): Boolean {
        return getBlockScreenCallbackHandle() != -1L
    }

    fun logBlockEvent(packageName: String) {
        dbHelper.logBlockEvent(packageName)
    }

    fun getBlockActivityLog(): List<Map<String, Any>> {
        return dbHelper.getBlockActivityLog()
    }

    fun clearBlockActivityLog() {
        dbHelper.clearBlockActivityLog()
    }

    // -------------------------------------------------------------------------
    // Time Limit API
    // -------------------------------------------------------------------------

    /**
     * Sets a daily time limit (in seconds) for [packageName].
     * Resets usage to 0 immediately.
     */
    fun setAppTimeLimit(packageName: String, limitSeconds: Long) {
        dbHelper.setAppTimeLimit(packageName, limitSeconds)
    }

    /**
     * Returns all configured time limits with current-day usage stats.
     * Each map contains: packageName, dailyLimitSeconds, usedSeconds, remainingSeconds.
     */
    fun getAppTimeLimits(): List<Map<String, Any>> {
        return dbHelper.getAppTimeLimits()
    }

    /**
     * Returns the time limit info for a single package, or null if none is set.
     */
    fun getAppTimeLimit(packageName: String): Map<String, Any>? {
        return dbHelper.getAppTimeLimit(packageName)
    }

    /**
     * Records [seconds] of active foreground usage for [packageName].
     * Returns remaining seconds (0 means the budget is exhausted).
     */
    fun addUsedSeconds(packageName: String, seconds: Long): Long {
        return dbHelper.addUsedSeconds(packageName, seconds)
    }

    /**
     * Resets today's usage counter for [packageName] to 0.
     */
    fun resetAppUsage(packageName: String) {
        dbHelper.resetAppUsage(packageName)
    }

    /**
     * Resets daily usage counters for ALL time-limited apps. Called at midnight.
     */
    fun resetAllDailyUsage() {
        dbHelper.resetAllDailyUsage()
    }

    /**
     * Permanently removes the time limit for [packageName].
     */
    fun removeAppTimeLimit(packageName: String) {
        dbHelper.removeAppTimeLimit(packageName)
    }

    /**
     * Returns true if [packageName] has a time limit and today's usage has
     * reached or exceeded that limit.
     */
    fun isTimeLimitExhausted(packageName: String): Boolean {
        val info = dbHelper.getAppTimeLimit(packageName) ?: return false
        val remaining = info["remainingSeconds"] as? Long ?: return false
        return remaining <= 0L
    }

    /**
     * Returns remaining seconds for [packageName], or Long.MAX_VALUE if no limit.
     */
    fun getRemainingSeconds(packageName: String): Long {
        val info = dbHelper.getAppTimeLimit(packageName) ?: return Long.MAX_VALUE
        return (info["remainingSeconds"] as? Long) ?: Long.MAX_VALUE
    }

    /**
     * Returns the set of package names that have a time limit configured.
     */
    fun getTimeLimitedPackages(): Set<String> {
        return dbHelper.getTimeLimitedPackages()
    }
}

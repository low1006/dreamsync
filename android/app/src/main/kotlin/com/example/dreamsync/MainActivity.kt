package com.example.dreamsync

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.dreamsync/screentime"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getScreenTime" -> {
                    if (!hasUsageStatsPermission()) {
                        result.error("PERMISSION_DENIED", "Usage Access Permission is not granted", null)
                    } else {
                        val screenTime = getScreenTimeForToday()
                        result.success(screenTime)
                    }
                }
                "requestUsagePermission" -> {
                    // Opens the settings page for the user to grant the Usage Access permission
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }
                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // Checks if the user has granted the special "Usage Access" permission
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    // Calculates the total foreground screen time for all apps today
    private fun getScreenTimeForToday(): Long {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        // Start time: Midnight of the current day
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        val startTime = calendar.timeInMillis

        // End time: Now
        val endTime = System.currentTimeMillis()

        // Query daily usage stats
        val usageStatsList = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )

        var totalScreenTime = 0L
        if (usageStatsList != null) {
            for (usageStats in usageStatsList) {
                // Add up the time each app spent in the foreground
                totalScreenTime += usageStats.totalTimeInForeground
            }
        }

        // Returns the screen time in milliseconds
        return totalScreenTime
    }
}
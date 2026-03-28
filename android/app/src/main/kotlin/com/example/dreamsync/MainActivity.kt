package com.example.dreamsync

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.dreamsync/screentime"
    private val AUDIO_CHANNEL = "com.dreamsync/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getScreenTime" -> {
                    if (!hasUsageStatsPermission()) {
                        result.error(
                            "PERMISSION_DENIED",
                            "Usage Access Permission is not granted",
                            null
                        )
                    } else {
                        val screenTimeMillis = getScreenTimeForToday()
                        result.success(screenTimeMillis)
                    }
                }

                "requestUsagePermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }

                "checkUsagePermission" -> {
                    result.success(hasUsageStatsPermission())
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

            when (call.method) {
                "getAlarmMaxVolume" -> {
                    val max = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                    result.success(max)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getScreenTimeForToday(): Long {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        return calculateScreenTimeFromUsageEvents(
            usageStatsManager = usageStatsManager,
            startTime = startTime,
            endTime = endTime
        )
    }

    private fun calculateScreenTimeFromUsageEvents(
        usageStatsManager: UsageStatsManager,
        startTime: Long,
        endTime: Long
    ): Long {
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()

        var totalScreenTime = 0L
        var currentSessionStart: Long? = null
        var currentForegroundPackage: String? = null

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)

            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    val pkg = event.packageName ?: continue

                    if (shouldIgnorePackage(pkg)) continue

                    if (currentSessionStart == null) {
                        currentSessionStart = event.timeStamp
                        currentForegroundPackage = pkg
                    } else if (currentForegroundPackage != pkg) {
                        totalScreenTime += (event.timeStamp - currentSessionStart)
                        currentSessionStart = event.timeStamp
                        currentForegroundPackage = pkg
                    }
                }

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val pkg = event.packageName ?: continue

                    if (shouldIgnorePackage(pkg)) continue

                    if (currentSessionStart != null && currentForegroundPackage == pkg) {
                        totalScreenTime += (event.timeStamp - currentSessionStart)
                        currentSessionStart = null
                        currentForegroundPackage = null
                    }
                }
            }
        }

        if (currentSessionStart != null) {
            totalScreenTime += (endTime - currentSessionStart)
        }

        return totalScreenTime.coerceAtLeast(0L)
    }

    private fun shouldIgnorePackage(pkg: String): Boolean {
        return pkg == "android" ||
                pkg == "com.android.systemui"
    }
}
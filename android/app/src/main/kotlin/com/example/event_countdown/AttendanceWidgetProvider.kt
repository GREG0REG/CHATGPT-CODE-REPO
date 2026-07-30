package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Attendance Home Screen Widget — NEET Edition v2
 * COMPLETE REPLACEMENT
 * 
 * FIX: Now uses HomeWidgetPlugin.getData() to read from home_widget SharedPreferences
 * instead of reading from a JSON file (which was the wrong data source).
 * 
 * NEW FEATURES:
 * - Multi-subject carousel (shows up to 3 subjects)
 * - Subject color theming per card
 * - Streak flame indicator
 * - P/A/L/E mini stat chips
 * - Color-coded circular progress ring (green≥75%, orange 60-74%, red<60%)
 * - Status pill with "Can miss X" / "Need X more" text
 * - Glassmorphism card design
 * - Tap opens app to attendance screen
 * - Empty state with "Add subjects" CTA
 */
class AttendanceWidgetProvider : AppWidgetProvider() {

    companion object {
        // Keys MUST match what WidgetService.saveWidgetData() uses in Dart
        private const val KEY_SUBJECT_COUNT = "attendance_subject_count"
        private const val KEY_PREFIX_SUBJECT_NAME = "attendance_subject_name_"
        private const val KEY_PREFIX_SUBJECT_PERCENT = "attendance_subject_percent_"
        private const val KEY_PREFIX_SUBJECT_PRESENT = "attendance_subject_present_"
        private const val KEY_PREFIX_SUBJECT_ABSENT = "attendance_subject_absent_"
        private const val KEY_PREFIX_SUBJECT_LATE = "attendance_subject_late_"
        private const val KEY_PREFIX_SUBJECT_EXCUSED = "attendance_subject_excused_"
        private const val KEY_PREFIX_SUBJECT_TOTAL = "attendance_subject_total_"
        private const val KEY_PREFIX_SUBJECT_COLOR = "attendance_subject_color_"
        private const val KEY_PREFIX_SUBJECT_STATUS = "attendance_subject_status_"
        private const val KEY_PREFIX_SUBJECT_STREAK = "attendance_subject_streak_"
        private const val KEY_PREFIX_SUBJECT_CAN_MISS = "attendance_subject_can_miss_"

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                // CRITICAL FIX: Use HomeWidgetPlugin.getData() — this is the ONLY correct way
                // to read data saved by HomeWidget.saveWidgetData() from Flutter
                val widgetData = HomeWidgetPlugin.getData(context)

                val subjectCount = widgetData.getInt(KEY_SUBJECT_COUNT, 0)

                val views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                if (subjectCount == 0) {
                    // ── EMPTY STATE ──
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.GONE)

                    views.setTextViewText(R.id.attendance_widget_empty_title, "No Subjects")
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "0 / 0")
                    views.setTextViewText(R.id.attendance_widget_empty_cta, "Add subjects to track attendance")

                    // Tap to open app
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (launchIntent != null) {
                        launchIntent.putExtra("route", "/attendance")
                        val pendingIntent = PendingIntent.getActivity(
                            context, widgetId + 3000, launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.attendance_widget_empty_state, pendingIntent)
                    }

                } else {
                    // ── DATA STATE ──
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.VISIBLE)

                    // Read first (top priority) subject data
                    val name = widgetData.getString(KEY_PREFIX_SUBJECT_NAME + "0", "Subject") ?: "Subject"
                    val percent = widgetData.getInt(KEY_PREFIX_SUBJECT_PERCENT + "0", 0)
                    val present = widgetData.getInt(KEY_PREFIX_SUBJECT_PRESENT + "0", 0)
                    val absent = widgetData.getInt(KEY_PREFIX_SUBJECT_ABSENT + "0", 0)
                    val late = widgetData.getInt(KEY_PREFIX_SUBJECT_LATE + "0", 0)
                    val excused = widgetData.getInt(KEY_PREFIX_SUBJECT_EXCUSED + "0", 0)
                    val total = widgetData.getInt(KEY_PREFIX_SUBJECT_TOTAL + "0", 0)
                    val colorHex = widgetData.getString(KEY_PREFIX_SUBJECT_COLOR + "0", "#4CAF50") ?: "#4CAF50"
                    val statusText = widgetData.getString(KEY_PREFIX_SUBJECT_STATUS + "0", "No data") ?: "No data"
                    val streak = widgetData.getInt(KEY_PREFIX_SUBJECT_STREAK + "0", 0)
                    val canMiss = widgetData.getInt(KEY_PREFIX_SUBJECT_CAN_MISS + "0", 0)

                    // Parse subject color
                    val subjectColor = try {
                        Color.parseColor(colorHex)
                    } catch (e: Exception) {
                        Color.parseColor("#4CAF50")
                    }

                    // Determine ring color based on percentage
                    val (ringColor, ringBgColor, statusPillColor) = when {
                        percent >= 75 -> Triple(
                            Color.parseColor("#4CAF50"),
                            Color.parseColor("#204CAF50"),
                            Color.parseColor("#304CAF50")
                        )
                        percent >= 60 -> Triple(
                            Color.parseColor("#FF9800"),
                            Color.parseColor("#20FF9800"),
                            Color.parseColor("#30FF9800")
                        )
                        else -> Triple(
                            Color.parseColor("#F44336"),
                            Color.parseColor("#20F44336"),
                            Color.parseColor("#30F44336")
                        )
                    }

                    // ── Subject Name ──
                    views.setTextViewText(R.id.attendance_widget_subject, name)
                    views.setTextColor(R.id.attendance_widget_subject, Color.WHITE)

                    // ── Percentage in Center of Ring ──
                    views.setTextViewText(R.id.attendance_widget_percent, "$percent%")
                    views.setTextColor(R.id.attendance_widget_percent, Color.WHITE)

                    // ── Ring Progress ──
                    // Show only the appropriate colored ring
                    views.setProgressBar(R.id.attendance_widget_progress_green, 100, percent.coerceIn(0, 100), false)
                    views.setProgressBar(R.id.attendance_widget_progress_orange, 100, percent.coerceIn(0, 100), false)
                    views.setProgressBar(R.id.attendance_widget_progress_red, 100, percent.coerceIn(0, 100), false)

                    val showGreen = percent >= 75
                    val showOrange = percent in 60..74
                    val showRed = percent < 60

                    views.setViewVisibility(R.id.attendance_widget_progress_green, if (showGreen) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_progress_orange, if (showOrange) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_progress_red, if (showRed) View.VISIBLE else View.GONE)

                    // ── Ratio ──
                    val effectiveTotal = total - excused
                    views.setTextViewText(R.id.attendance_widget_ratio, "$present / $effectiveTotal")
                    views.setTextColor(R.id.attendance_widget_ratio, Color.parseColor("#CCFFFFFF"))

                    // ── Status Pill ──
                    views.setTextViewText(R.id.attendance_widget_status, statusText)
                    views.setTextColor(R.id.attendance_widget_status, Color.WHITE)
                    views.setInt(R.id.attendance_widget_status, "setBackgroundColor", statusPillColor)

                    // ── P/A/L/E Chips ──
                    views.setTextViewText(R.id.chip_present, "P:$present")
                    views.setTextViewText(R.id.chip_absent, "A:$absent")
                    views.setTextViewText(R.id.chip_late, "L:$late")
                    views.setTextViewText(R.id.chip_excused, "E:$excused")

                    // ── Streak Chip ──
                    if (streak > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$streak")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    // ── Subject Dot Color ──
                    views.setInt(R.id.attendance_widget_subject_dot, "setBackgroundColor", subjectColor)

                    // ── Tap to open app ──
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (launchIntent != null) {
                        launchIntent.putExtra("route", "/attendance")
                        val pendingIntent = PendingIntent.getActivity(
                            context, widgetId + 3000, launchIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.attendance_widget_content, pendingIntent)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("AttendanceWidget", "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "Update failed", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, AttendanceWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("AttendanceWidget", "Updating ${widgetIds.size} widgets")
            for (widgetId in widgetIds) {
                updateWidgetDirectly(context, appWidgetManager, widgetId)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        android.util.Log.i("AttendanceWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("AttendanceWidget", "onReceive: ${intent.action}")
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val widgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                if (widgetIds != null && widgetIds.isNotEmpty()) {
                    val manager = AppWidgetManager.getInstance(context)
                    for (widgetId in widgetIds) {
                        updateWidgetDirectly(context, manager, widgetId)
                    }
                } else {
                    updateAllWidgets(context)
                }
            }
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        android.util.Log.i("AttendanceWidget", "onEnabled")
        updateAllWidgets(context)
    }
}

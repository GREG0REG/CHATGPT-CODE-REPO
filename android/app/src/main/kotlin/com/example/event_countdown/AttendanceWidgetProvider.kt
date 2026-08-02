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
import es.antonborri.home_widget.HomeWidgetPlugin

class AttendanceWidgetProvider : AppWidgetProvider() {

    companion object {
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

        private const val MAX_SUBJECTS = 4

        // FIXED: Added R.id.subject_row_0 to index 0 for consistency
        private val ROW_IDS = intArrayOf(
            R.id.subject_row_0,
            R.id.subject_row_1,
            R.id.subject_row_2,
            R.id.subject_row_3
        )
        private val DIVIDER_IDS = intArrayOf(
            R.id.divider_0,
            R.id.divider_1,
            R.id.divider_2,
            0
        )
        private val DOT_IDS = intArrayOf(
            R.id.attendance_widget_subject_dot,
            R.id.dot_1,
            R.id.dot_2,
            R.id.dot_3
        )
        private val NAME_IDS = intArrayOf(
            R.id.attendance_widget_subject,
            R.id.name_1,
            R.id.name_2,
            R.id.name_3
        )
        private val PCT_IDS = intArrayOf(
            R.id.attendance_widget_percent,
            R.id.pct_1,
            R.id.pct_2,
            R.id.pct_3
        )
        private val RATIO_IDS = intArrayOf(
            R.id.attendance_widget_ratio,
            R.id.ratio_1,
            R.id.ratio_2,
            R.id.ratio_3
        )
        private val P_IDS = intArrayOf(
            R.id.chip_present,
            R.id.p1,
            R.id.p2,
            R.id.p3
        )
        private val A_IDS = intArrayOf(
            R.id.chip_absent,
            R.id.a1,
            R.id.a2,
            R.id.a3
        )
        private val L_IDS = intArrayOf(
            R.id.chip_late,
            R.id.l1,
            R.id.l2,
            R.id.l3
        )
        private val E_IDS = intArrayOf(
            R.id.chip_excused,
            R.id.e1,
            R.id.e2,
            R.id.e3
        )
        private val STATUS_IDS = intArrayOf(
            R.id.attendance_widget_status,
            R.id.status_1,
            R.id.status_2,
            R.id.status_3
        )

        private fun safeParseColor(hex: String?, fallback: String): Int {
            return try {
                Color.parseColor(hex ?: fallback)
            } catch (e: Exception) {
                try {
                    Color.parseColor(fallback)
                } catch (e2: Exception) {
                    Color.parseColor("#4CAF50")
                }
            }
        }

        private fun getPercentColor(percent: Int): Int {
            return when {
                percent >= 75 -> Color.parseColor("#4CAF50")
                percent >= 60 -> Color.parseColor("#FF9800")
                else -> Color.parseColor("#F44336")
            }
        }

        private fun createLaunchPendingIntent(context: Context, widgetId: Int): PendingIntent? {
            return try {
                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("route", "/attendance")
                    launchIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                    PendingIntent.getActivity(
                        context,
                        widgetId + 3000,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                } else {
                    null
                }
            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "Failed to create PendingIntent", e)
                null
            }
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            var views: RemoteViews? = null
            try {
                // FIXED: Wrap HomeWidgetPlugin access in try-catch
                val widgetData = try {
                    HomeWidgetPlugin.getData(context)
                } catch (e: Exception) {
                    android.util.Log.e("AttendanceWidget", "HomeWidgetPlugin.getData failed", e)
                    null
                }

                views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                if (widgetData == null) {
                    // Data not available yet — show empty state gracefully
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.GONE)
                    views.setTextViewText(R.id.attendance_widget_empty_title, "Attendance")
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "Loading...")
                    views.setTextViewText(R.id.attendance_widget_empty_cta, "Open app to sync data")

                    createLaunchPendingIntent(context, widgetId)?.let { pi ->
                        views.setOnClickPendingIntent(R.id.attendance_widget_empty_state, pi)
                    }

                    appWidgetManager.updateAppWidget(widgetId, views)
                    return
                }

                val subjectCount = widgetData.getInt(KEY_SUBJECT_COUNT, 0)

                if (subjectCount == 0) {
                    // EMPTY STATE
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.GONE)

                    views.setTextViewText(R.id.attendance_widget_empty_title, "No Subjects")
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "0 / 0")
                    views.setTextViewText(
                        R.id.attendance_widget_empty_cta,
                        "Add subjects to track attendance"
                    )

                    createLaunchPendingIntent(context, widgetId)?.let { pi ->
                        views.setOnClickPendingIntent(R.id.attendance_widget_empty_state, pi)
                    }

                } else {
                    // CONTENT STATE
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.VISIBLE)

                    val displayCount = subjectCount.coerceAtMost(MAX_SUBJECTS)

                    // Update all subject rows (0 through 3)
                    for (i in 0 until MAX_SUBJECTS) {
                        val visible = i < displayCount
                        views.setViewVisibility(ROW_IDS[i], if (visible) View.VISIBLE else View.GONE)

                        // Handle dividers: show divider after row i if row i is visible AND there's a next row
                        if (i < MAX_SUBJECTS - 1 && DIVIDER_IDS[i] != 0) {
                            val showDivider = visible && (i < displayCount - 1)
                            views.setViewVisibility(DIVIDER_IDS[i], if (showDivider) View.VISIBLE else View.GONE)
                        }

                        if (visible) {
                            val name = widgetData.getString(KEY_PREFIX_SUBJECT_NAME + "$i", "Subject") ?: "Subject"
                            val percent = widgetData.getInt(KEY_PREFIX_SUBJECT_PERCENT + "$i", 0)
                            val present = widgetData.getInt(KEY_PREFIX_SUBJECT_PRESENT + "$i", 0)
                            val absent = widgetData.getInt(KEY_PREFIX_SUBJECT_ABSENT + "$i", 0)
                            val late = widgetData.getInt(KEY_PREFIX_SUBJECT_LATE + "$i", 0)
                            val excused = widgetData.getInt(KEY_PREFIX_SUBJECT_EXCUSED + "$i", 0)
                            val total = widgetData.getInt(KEY_PREFIX_SUBJECT_TOTAL + "$i", 0)
                            val colorHex = widgetData.getString(KEY_PREFIX_SUBJECT_COLOR + "$i", "#4CAF50") ?: "#4CAF50"
                            val statusText = widgetData.getString(KEY_PREFIX_SUBJECT_STATUS + "$i", "No data") ?: "No data"

                            val percentColor = getPercentColor(percent)
                            val effectiveTotal = total - excused
                            val subjectColor = safeParseColor(colorHex, "#4CAF50")

                            // Percent text (large left side for i=0, smaller for others)
                            views.setTextViewText(PCT_IDS[i], "$percent%")
                            views.setTextColor(PCT_IDS[i], percentColor)

                            // Name and dot
                            views.setTextViewText(NAME_IDS[i], name)
                            views.setTextColor(NAME_IDS[i], Color.WHITE)
                            views.setTextColor(DOT_IDS[i], subjectColor)

                            // Ratio
                            views.setTextViewText(RATIO_IDS[i], "$present / $effectiveTotal")
                            views.setTextColor(RATIO_IDS[i], Color.parseColor("#CCFFFFFF"))

                            // Chips
                            views.setTextViewText(P_IDS[i], "P:$present")
                            views.setTextViewText(A_IDS[i], "A:$absent")
                            views.setTextViewText(L_IDS[i], "L:$late")
                            views.setTextViewText(E_IDS[i], "E:$excused")

                            // Status
                            views.setTextViewText(STATUS_IDS[i], statusText)
                            views.setTextColor(STATUS_IDS[i], Color.WHITE)
                        }
                    }

                    // Streak chip (only show if subject 0 has streak)
                    val streak = widgetData.getInt(KEY_PREFIX_SUBJECT_STREAK + "0", 0)
                    if (streak > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$streak")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    // Click to open app
                    createLaunchPendingIntent(context, widgetId)?.let { pi ->
                        views.setOnClickPendingIntent(R.id.attendance_widget_content, pi)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("AttendanceWidget", "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "Update failed for widget $widgetId", e)
                try {
                    val fallbackViews = RemoteViews(context.packageName, R.layout.attendance_widget_layout)
                    fallbackViews.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    fallbackViews.setViewVisibility(R.id.attendance_widget_content, View.GONE)
                    fallbackViews.setTextViewText(R.id.attendance_widget_empty_title, "Attendance")
                    fallbackViews.setTextViewText(R.id.attendance_widget_empty_subtitle, "Tap to open")
                    fallbackViews.setTextViewText(R.id.attendance_widget_empty_cta, "Track your attendance")
                    appWidgetManager.updateAppWidget(widgetId, fallbackViews)
                } catch (e2: Exception) {
                    android.util.Log.e("AttendanceWidget", "Fallback also failed", e2)
                }
            }
        }

        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = ComponentName(context, AttendanceWidgetProvider::class.java)
                val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                android.util.Log.i("AttendanceWidget", "Updating ${widgetIds.size} widgets")
                for (widgetId in widgetIds) {
                    updateWidgetDirectly(context, appWidgetManager, widgetId)
                }
            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "updateAllWidgets failed", e)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
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
        updateAllWidgets(context)
    }
}

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
        private const val TAG = "AttendanceWidget"
        private const val MAX_SUBJECTS = 4

        // Keys matching WidgetService.dart
        private const val KEY_SUBJECT_COUNT = "attendance_subject_count"
        private const val KEY_PREFIX_NAME = "attendance_subject_name_"
        private const val KEY_PREFIX_PERCENT = "attendance_subject_percent_"
        private const val KEY_PREFIX_PRESENT = "attendance_subject_present_"
        private const val KEY_PREFIX_ABSENT = "attendance_subject_absent_"
        private const val KEY_PREFIX_LATE = "attendance_subject_late_"
        private const val KEY_PREFIX_EXCUSED = "attendance_subject_excused_"
        private const val KEY_PREFIX_TOTAL = "attendance_subject_total_"
        private const val KEY_PREFIX_COLOR = "attendance_subject_color_"
        private const val KEY_PREFIX_STATUS = "attendance_subject_status_"
        private const val KEY_PREFIX_STREAK = "attendance_subject_streak_"

        // Row IDs (0-3)
        private val ROW_IDS = intArrayOf(
            R.id.subject_row_0,
            R.id.subject_row_1,
            R.id.subject_row_2,
            R.id.subject_row_3
        )

        // Divider IDs (0-2, between rows)
        private val DIVIDER_IDS = intArrayOf(
            R.id.divider_0,
            R.id.divider_1,
            R.id.divider_2
        )

        // Percent text IDs
        private val PCT_IDS = intArrayOf(
            R.id.pct_0,
            R.id.pct_1,
            R.id.pct_2,
            R.id.pct_3
        )

        // Dot IDs
        private val DOT_IDS = intArrayOf(
            R.id.dot_0,
            R.id.dot_1,
            R.id.dot_2,
            R.id.dot_3
        )

        // Name IDs
        private val NAME_IDS = intArrayOf(
            R.id.name_0,
            R.id.name_1,
            R.id.name_2,
            R.id.name_3
        )

        // ProgressBar IDs
        private val PROGRESS_IDS = intArrayOf(
            R.id.progress_0,
            R.id.progress_1,
            R.id.progress_2,
            R.id.progress_3
        )

        // Ratio text IDs
        private val RATIO_IDS = intArrayOf(
            R.id.ratio_0,
            R.id.ratio_1,
            R.id.ratio_2,
            R.id.ratio_3
        )

        // Present chip IDs
        private val P_IDS = intArrayOf(
            R.id.p0,
            R.id.p1,
            R.id.p2,
            R.id.p3
        )

        // Absent chip IDs
        private val A_IDS = intArrayOf(
            R.id.a0,
            R.id.a1,
            R.id.a2,
            R.id.a3
        )

        // Late chip IDs
        private val L_IDS = intArrayOf(
            R.id.l0,
            R.id.l1,
            R.id.l2,
            R.id.l3
        )

        // Excused chip IDs
        private val E_IDS = intArrayOf(
            R.id.e0,
            R.id.e1,
            R.id.e2,
            R.id.e3
        )

        // Status text IDs
        private val STATUS_IDS = intArrayOf(
            R.id.status_0,
            R.id.status_1,
            R.id.status_2,
            R.id.status_3
        )

        @JvmStatic
        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val subjectCount = widgetData.getInt(KEY_SUBJECT_COUNT, 0)

                val views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                if (subjectCount <= 0) {
                    // Show empty state
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.GONE)

                    views.setTextViewText(R.id.attendance_widget_empty_title, "Attendance")
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "No subjects yet")
                    views.setTextViewText(R.id.attendance_widget_empty_cta, "Tap to add subjects")

                    setLaunchPendingIntent(context, widgetId, views, R.id.attendance_widget_empty_state)

                } else {
                    // Show content
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.VISIBLE)

                    val displayCount = subjectCount.coerceAtMost(MAX_SUBJECTS)

                    // Update streak chip for subject 0
                    val streak = widgetData.getInt(KEY_PREFIX_STREAK + "0", 0)
                    if (streak > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$streak")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    // Update all subject rows
                    for (i in 0 until MAX_SUBJECTS) {
                        val visible = i < displayCount
                        views.setViewVisibility(ROW_IDS[i], if (visible) View.VISIBLE else View.GONE)

                        // Show divider after this row if visible and not the last visible row
                        if (i < MAX_SUBJECTS - 1) {
                            val showDivider = visible && (i < displayCount - 1)
                            views.setViewVisibility(DIVIDER_IDS[i], if (showDivider) View.VISIBLE else View.GONE)
                        }

                        if (visible) {
                            updateSubjectRow(views, widgetData, i)
                        }
                    }

                    setLaunchPendingIntent(context, widgetId, views, R.id.attendance_widget_content)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i(TAG, "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e(TAG, "Update failed for widget $widgetId", e)
                // Try fallback
                try {
                    val fallback = RemoteViews(context.packageName, R.layout.attendance_widget_layout)
                    fallback.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    fallback.setViewVisibility(R.id.attendance_widget_content, View.GONE)
                    fallback.setTextViewText(R.id.attendance_widget_empty_title, "Attendance")
                    fallback.setTextViewText(R.id.attendance_widget_empty_subtitle, "Loading...")
                    fallback.setTextViewText(R.id.attendance_widget_empty_cta, "Tap to refresh")
                    appWidgetManager.updateAppWidget(widgetId, fallback)
                } catch (e2: Exception) {
                    android.util.Log.e(TAG, "Fallback also failed", e2)
                }
            }
        }

        private fun updateSubjectRow(views: RemoteViews, widgetData: HomeWidgetPlugin.HomeWidgetData, index: Int) {
            val name = widgetData.getString(KEY_PREFIX_NAME + "$index", "Subject") ?: "Subject"
            val percent = widgetData.getInt(KEY_PREFIX_PERCENT + "$index", 0)
            val present = widgetData.getInt(KEY_PREFIX_PRESENT + "$index", 0)
            val absent = widgetData.getInt(KEY_PREFIX_ABSENT + "$index", 0)
            val late = widgetData.getInt(KEY_PREFIX_LATE + "$index", 0)
            val excused = widgetData.getInt(KEY_PREFIX_EXCUSED + "$index", 0)
            val total = widgetData.getInt(KEY_PREFIX_TOTAL + "$index", 0)
            val colorHex = widgetData.getString(KEY_PREFIX_COLOR + "$index", "#4CAF50") ?: "#4CAF50"
            val status = widgetData.getString(KEY_PREFIX_STATUS + "$index", "No data") ?: "No data"

            val percentColor = getPercentColor(percent)
            val effectiveTotal = (total - excused).coerceAtLeast(0)
            val subjectColor = parseColorSafe(colorHex, "#4CAF50")

            views.setTextViewText(NAME_IDS[index], name)
            views.setTextColor(NAME_IDS[index], Color.WHITE)

            views.setTextViewText(PCT_IDS[index], "$percent%")
            views.setTextColor(PCT_IDS[index], percentColor)

            views.setInt(DOT_IDS[index], "setBackgroundColor", subjectColor)
            views.setProgressBar(PROGRESS_IDS[index], 100, percent.coerceIn(0, 100), false)

            val ratioText = if (index == 0) "$present / $effectiveTotal sessions" else "$present / $effectiveTotal"
            views.setTextViewText(RATIO_IDS[index], ratioText)
            views.setTextColor(RATIO_IDS[index], Color.parseColor("#B0FFFFFF"))

            views.setTextViewText(P_IDS[index], "P:$present")
            views.setTextViewText(A_IDS[index], "A:$absent")
            views.setTextViewText(L_IDS[index], "L:$late")
            views.setTextViewText(E_IDS[index], "E:$excused")

            views.setTextViewText(STATUS_IDS[index], status)
            views.setTextColor(STATUS_IDS[index], Color.WHITE)
        }

        private fun getPercentColor(percent: Int): Int {
            return when {
                percent >= 75 -> Color.parseColor("#4CAF50")
                percent >= 60 -> Color.parseColor("#FF9800")
                else -> Color.parseColor("#F44336")
            }
        }

        private fun parseColorSafe(hex: String, fallback: String): Int {
            return try {
                Color.parseColor(hex)
            } catch (e: Exception) {
                try {
                    Color.parseColor(fallback)
                } catch (e2: Exception) {
                    Color.parseColor("#4CAF50")
                }
            }
        }

        private fun setLaunchPendingIntent(context: Context, widgetId: Int, views: RemoteViews, viewId: Int) {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.putExtra("route", "/attendance")
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId + 3000,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(viewId, pendingIntent)
            }
        }

        @JvmStatic
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, AttendanceWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i(TAG, "Updating ${widgetIds.size} widgets")
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
            "com.example.event_countdown.ATTENDANCE_WIDGET_REFRESH" -> updateAllWidgets(context)
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAllWidgets(context)
    }
}

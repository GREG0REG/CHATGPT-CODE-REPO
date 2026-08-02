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

        // Subject 0 IDs (always visible when data exists)
        private val S0_PERCENT = R.id.attendance_widget_percent
        private val S0_DOT = R.id.attendance_widget_subject_dot
        private val S0_NAME = R.id.attendance_widget_subject
        private val S0_RATIO = R.id.attendance_widget_ratio
        private val S0_PROGRESS = R.id.attendance_widget_progress
        private val S0_P = R.id.chip_present
        private val S0_A = R.id.chip_absent
        private val S0_L = R.id.chip_late
        private val S0_E = R.id.chip_excused
        private val S0_STATUS = R.id.attendance_widget_status

        // Subject 1-3 IDs
        private val ROW_IDS = intArrayOf(
            R.id.subject_row_1,
            R.id.subject_row_2,
            R.id.subject_row_3
        )
        private val DIVIDER_IDS = intArrayOf(
            R.id.divider_0,
            R.id.divider_1,
            R.id.divider_2
        )
        private val PCT_IDS = intArrayOf(
            R.id.pct_1,
            R.id.pct_2,
            R.id.pct_3
        )
        private val DOT_IDS = intArrayOf(
            R.id.dot_1,
            R.id.dot_2,
            R.id.dot_3
        )
        private val NAME_IDS = intArrayOf(
            R.id.name_1,
            R.id.name_2,
            R.id.name_3
        )
        private val PROGRESS_IDS = intArrayOf(
            R.id.progress_1,
            R.id.progress_2,
            R.id.progress_3
        )
        private val RATIO_IDS = intArrayOf(
            R.id.ratio_1,
            R.id.ratio_2,
            R.id.ratio_3
        )
        private val P_IDS = intArrayOf(
            R.id.p1,
            R.id.p2,
            R.id.p3
        )
        private val A_IDS = intArrayOf(
            R.id.a1,
            R.id.a2,
            R.id.a3
        )
        private val L_IDS = intArrayOf(
            R.id.l1,
            R.id.l2,
            R.id.l3
        )
        private val E_IDS = intArrayOf(
            R.id.e1,
            R.id.e2,
            R.id.e3
        )
        private val STATUS_IDS = intArrayOf(
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

                    // Update Subject 0 (always shown if we have data)
                    updateSubject0(views, widgetData)

                    // Update streak chip for subject 0
                    val streak = widgetData.getInt(KEY_PREFIX_STREAK + "0", 0)
                    if (streak > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$streak")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    // Update Subjects 1-3
                    for (i in 1 until MAX_SUBJECTS) {
                        val visible = i < displayCount
                        views.setViewVisibility(ROW_IDS[i - 1], if (visible) View.VISIBLE else View.GONE)

                        // Show divider before this row if visible and not the last one
                        val showDivider = visible && (i < displayCount - 1)
                        views.setViewVisibility(DIVIDER_IDS[i - 1], if (showDivider) View.VISIBLE else View.GONE)

                        if (visible) {
                            updateSubjectN(views, widgetData, i)
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

        private fun updateSubject0(views: RemoteViews, widgetData: HomeWidgetPlugin.HomeWidgetData) {
            val name = widgetData.getString(KEY_PREFIX_NAME + "0", "Subject") ?: "Subject"
            val percent = widgetData.getInt(KEY_PREFIX_PERCENT + "0", 0)
            val present = widgetData.getInt(KEY_PREFIX_PRESENT + "0", 0)
            val absent = widgetData.getInt(KEY_PREFIX_ABSENT + "0", 0)
            val late = widgetData.getInt(KEY_PREFIX_LATE + "0", 0)
            val excused = widgetData.getInt(KEY_PREFIX_EXCUSED + "0", 0)
            val total = widgetData.getInt(KEY_PREFIX_TOTAL + "0", 0)
            val colorHex = widgetData.getString(KEY_PREFIX_COLOR + "0", "#4CAF50") ?: "#4CAF50"
            val status = widgetData.getString(KEY_PREFIX_STATUS + "0", "No data") ?: "No data"

            val percentColor = getPercentColor(percent)
            val effectiveTotal = (total - excused).coerceAtLeast(0)
            val subjectColor = parseColorSafe(colorHex, "#4CAF50")

            views.setTextViewText(S0_NAME, name)
            views.setTextColor(S0_NAME, Color.WHITE)

            views.setTextViewText(S0_PERCENT, "$percent%")
            views.setTextColor(S0_PERCENT, percentColor)

            views.setInt(S0_DOT, "setBackgroundColor", subjectColor)
            views.setProgressBar(S0_PROGRESS, 100, percent.coerceIn(0, 100), false)
            views.setProgressBar(S0_PROGRESS, 100, percent.coerceIn(0, 100), false)

            views.setTextViewText(S0_RATIO, "$present / $effectiveTotal sessions")
            views.setTextColor(S0_RATIO, Color.parseColor("#B0FFFFFF"))

            views.setTextViewText(S0_P, "P:$present")
            views.setTextViewText(S0_A, "A:$absent")
            views.setTextViewText(S0_L, "L:$late")
            views.setTextViewText(S0_E, "E:$excused")

            views.setTextViewText(S0_STATUS, status)
            views.setTextColor(S0_STATUS, Color.WHITE)
        }

        private fun updateSubjectN(views: RemoteViews, widgetData: HomeWidgetPlugin.HomeWidgetData, index: Int) {
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

            val arrIndex = index - 1

            views.setTextViewText(NAME_IDS[arrIndex], name)
            views.setTextColor(NAME_IDS[arrIndex], Color.WHITE)

            views.setTextViewText(PCT_IDS[arrIndex], "$percent%")
            views.setTextColor(PCT_IDS[arrIndex], percentColor)

            views.setInt(DOT_IDS[arrIndex], "setBackgroundColor", subjectColor)
            views.setProgressBar(PROGRESS_IDS[arrIndex], 100, percent.coerceIn(0, 100), false)

            views.setTextViewText(RATIO_IDS[arrIndex], "$present / $effectiveTotal")
            views.setTextColor(RATIO_IDS[arrIndex], Color.parseColor("#B0FFFFFF"))

            views.setTextViewText(P_IDS[arrIndex], "P:$present")
            views.setTextViewText(A_IDS[arrIndex], "A:$absent")
            views.setTextViewText(L_IDS[arrIndex], "L:$late")
            views.setTextViewText(E_IDS[arrIndex], "E:$excused")

            views.setTextViewText(STATUS_IDS[arrIndex], status)
            views.setTextColor(STATUS_IDS[arrIndex], Color.WHITE)
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
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAllWidgets(context)
    }
}

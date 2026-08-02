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

        private val ROW_IDS = intArrayOf(
            R.id.subject_row_0, R.id.subject_row_1, R.id.subject_row_2, R.id.subject_row_3
        )
        private val DIVIDER_IDS = intArrayOf(
            R.id.divider_0, R.id.divider_1, R.id.divider_2
        )
        private val PCT_IDS = intArrayOf(
            R.id.pct_0, R.id.pct_1, R.id.pct_2, R.id.pct_3
        )
        private val DOT_IDS = intArrayOf(
            R.id.dot_0, R.id.dot_1, R.id.dot_2, R.id.dot_3
        )
        private val NAME_IDS = intArrayOf(
            R.id.name_0, R.id.name_1, R.id.name_2, R.id.name_3
        )
        private val PROGRESS_IDS = intArrayOf(
            R.id.progress_0, R.id.progress_1, R.id.progress_2, R.id.progress_3
        )
        private val RATIO_IDS = intArrayOf(
            R.id.ratio_0, R.id.ratio_1, R.id.ratio_2, R.id.ratio_3
        )
        private val P_IDS = intArrayOf(
            R.id.p0, R.id.p1, R.id.p2, R.id.p3
        )
        private val A_IDS = intArrayOf(
            R.id.a0, R.id.a1, R.id.a2, R.id.a3
        )
        private val L_IDS = intArrayOf(
            R.id.l0, R.id.l1, R.id.l2, R.id.l3
        )
        private val E_IDS = intArrayOf(
            R.id.e0, R.id.e1, R.id.e2, R.id.e3
        )
        private val STATUS_IDS = intArrayOf(
            R.id.status_0, R.id.status_1, R.id.status_2, R.id.status_3
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
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.GONE)

                    views.setTextViewText(R.id.attendance_widget_empty_title, "Attendance")
                    views.setTextViewText(R.id.attendance_widget_empty_subtitle, "No subjects yet")
                    views.setTextViewText(R.id.attendance_widget_empty_cta, "Tap to add subjects")

                    setLaunchPendingIntent(context, widgetId, views, R.id.attendance_widget_empty_state)

                } else {
                    views.setViewVisibility(R.id.attendance_widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.attendance_widget_content, View.VISIBLE)

                    val displayCount = subjectCount.coerceAtMost(MAX_SUBJECTS)

                    val streak = widgetData.getInt(KEY_PREFIX_STREAK + "0", 0)
                    if (streak > 0) {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.VISIBLE)
                        views.setTextViewText(R.id.attendance_widget_streak_text, "$streak")
                    } else {
                        views.setViewVisibility(R.id.attendance_widget_streak_chip, View.GONE)
                    }

                    for (i in 0 until MAX_SUBJECTS) {
                        val visible = i < displayCount
                        views.setViewVisibility(ROW_IDS[i], if (visible) View.VISIBLE else View.GONE)

                        if (i < MAX_SUBJECTS - 1) {
                            val showDivider = visible && (i < displayCount - 1)
                            views.setViewVisibility(DIVIDER_IDS[i], if (showDivider) View.VISIBLE else View.GONE)
                        }

                        if (visible) {
                            val name = widgetData.getString(KEY_PREFIX_NAME + "$i", "Subject") ?: "Subject"
                            val percent = widgetData.getInt(KEY_PREFIX_PERCENT + "$i", 0)
                            val present = widgetData.getInt(KEY_PREFIX_PRESENT + "$i", 0)
                            val absent = widgetData.getInt(KEY_PREFIX_ABSENT + "$i", 0)
                            val late = widgetData.getInt(KEY_PREFIX_LATE + "$i", 0)
                            val excused = widgetData.getInt(KEY_PREFIX_EXCUSED + "$i", 0)
                            val total = widgetData.getInt(KEY_PREFIX_TOTAL + "$i", 0)
                            val colorHex = widgetData.getString(KEY_PREFIX_COLOR + "$i", "#4CAF50") ?: "#4CAF50"
                            val status = widgetData.getString(KEY_PREFIX_STATUS + "$i", "No data") ?: "No data"

                            val percentColor = when {
                                percent >= 75 -> Color.parseColor("#4CAF50")
                                percent >= 60 -> Color.parseColor("#FF9800")
                                else -> Color.parseColor("#F44336")
                            }

                            val effectiveTotal = (total - excused).coerceAtLeast(0)
                            val subjectColor = try {
                                Color.parseColor(colorHex)
                            } catch (e: Exception) {
                                Color.parseColor("#4CAF50")
                            }

                            views.setTextViewText(NAME_IDS[i], name)
                            views.setTextColor(NAME_IDS[i], Color.WHITE)

                            views.setTextViewText(PCT_IDS[i], "$percent%")
                            views.setTextColor(PCT_IDS[i], percentColor)

                            views.setInt(DOT_IDS[i], "setBackgroundColor", subjectColor)
                            views.setProgressBar(PROGRESS_IDS[i], 100, percent.coerceIn(0, 100), false)

                            val ratioText = if (i == 0) "$present / $effectiveTotal sessions" else "$present / $effectiveTotal"
                            views.setTextViewText(RATIO_IDS[i], ratioText)
                            views.setTextColor(RATIO_IDS[i], Color.parseColor("#B0FFFFFF"))

                            views.setTextViewText(P_IDS[i], "P:$present")
                            views.setTextViewText(A_IDS[i], "A:$absent")
                            views.setTextViewText(L_IDS[i], "L:$late")
                            views.setTextViewText(E_IDS[i], "E:$excused")

                            views.setTextViewText(STATUS_IDS[i], status)
                            views.setTextColor(STATUS_IDS[i], Color.WHITE)
                        }
                    }

                    setLaunchPendingIntent(context, widgetId, views, R.id.attendance_widget_content)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i(TAG, "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e(TAG, "Update failed for widget $widgetId", e)
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

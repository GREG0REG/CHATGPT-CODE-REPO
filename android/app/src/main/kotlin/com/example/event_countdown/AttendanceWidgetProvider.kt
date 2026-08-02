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

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val subjectCount = widgetData.getInt(KEY_SUBJECT_COUNT, 0)

                val views = RemoteViews(context.packageName, R.layout.attendance_widget_layout)

                val displayCount = subjectCount.coerceAtMost(MAX_SUBJECTS)

                for (i in 0 until MAX_SUBJECTS) {
                    val visible = i < displayCount
                    views.setViewVisibility(ROW_IDS[i], if (visible) View.VISIBLE else View.GONE)

                    if (i < MAX_SUBJECTS - 1 && DIVIDER_IDS[i] != 0) {
                        val showDivider = visible && (i < displayCount - 1)
                        views.setViewVisibility(DIVIDER_IDS[i], if (showDivider) View.VISIBLE else View.GONE)
                    }

                    if (visible) {
                        val sName = widgetData.getString(KEY_PREFIX_SUBJECT_NAME + "$i", "Subject") ?: "Subject"
                        val sPercent = widgetData.getInt(KEY_PREFIX_SUBJECT_PERCENT + "$i", 0)
                        val sPresent = widgetData.getInt(KEY_PREFIX_SUBJECT_PRESENT + "$i", 0)
                        val sAbsent = widgetData.getInt(KEY_PREFIX_SUBJECT_ABSENT + "$i", 0)
                        val sLate = widgetData.getInt(KEY_PREFIX_SUBJECT_LATE + "$i", 0)
                        val sExcused = widgetData.getInt(KEY_PREFIX_SUBJECT_EXCUSED + "$i", 0)
                        val sTotal = widgetData.getInt(KEY_PREFIX_SUBJECT_TOTAL + "$i", 0)
                        val sColorHex = widgetData.getString(KEY_PREFIX_SUBJECT_COLOR + "$i", "#4CAF50") ?: "#4CAF50"
                        val sStatus = widgetData.getString(KEY_PREFIX_SUBJECT_STATUS + "$i", "No data") ?: "No data"

                        val sPercentColor = when {
                            sPercent >= 75 -> Color.parseColor("#4CAF50")
                            sPercent >= 60 -> Color.parseColor("#FF9800")
                            else -> Color.parseColor("#F44336")
                        }

                        val sEffectiveTotal = sTotal - sExcused

                        views.setTextViewText(NAME_IDS[i], sName)
                        views.setTextColor(NAME_IDS[i], Color.WHITE)
                        views.setTextViewText(PCT_IDS[i], "$sPercent%")
                        views.setTextColor(PCT_IDS[i], sPercentColor)
                        views.setTextViewText(RATIO_IDS[i], "$sPresent / $sEffectiveTotal")
                        views.setTextColor(RATIO_IDS[i], Color.parseColor("#CCFFFFFF"))

                        val sSubjectColor = try {
                            Color.parseColor(sColorHex)
                        } catch (e: Exception) {
                            Color.parseColor("#4CAF50")
                        }
                        views.setTextColor(DOT_IDS[i], sSubjectColor)

                        views.setTextViewText(P_IDS[i], "P:$sPresent")
                        views.setTextViewText(A_IDS[i], "A:$sAbsent")
                        views.setTextViewText(L_IDS[i], "L:$sLate")
                        views.setTextViewText(E_IDS[i], "E:$sExcused")
                        views.setTextViewText(STATUS_IDS[i], sStatus)
                        views.setTextColor(STATUS_IDS[i], Color.WHITE)
                    }
                }

                val streak = widgetData.getInt(KEY_PREFIX_SUBJECT_STREAK + "0", 0)
                if (streak > 0) {
                    views.setViewVisibility(R.id.attendance_widget_streak_text, View.VISIBLE)
                    views.setTextViewText(R.id.attendance_widget_streak_text, "$streak")
                } else {
                    views.setViewVisibility(R.id.attendance_widget_streak_text, View.GONE)
                }

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    launchIntent.putExtra("route", "/attendance")
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId + 3000, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.attendance_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("AttendanceWidget", "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e("AttendanceWidget", "Update failed for widget $widgetId", e)
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

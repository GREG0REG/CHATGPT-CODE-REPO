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

class SyllabusWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "SyllabusWidget"
        private const val MAX_SUBJECTS = 5

        private const val KEY_SUBJECT_COUNT = "syllabus_subject_count"
        private const val KEY_PREFIX_NAME = "syllabus_subject_name_"
        private const val KEY_PREFIX_PROGRESS = "syllabus_subject_progress_"
        private const val KEY_PREFIX_COLOR = "syllabus_subject_color_"

        private val NAME_IDS = intArrayOf(
            R.id.syllabus_name_0, R.id.syllabus_name_1, R.id.syllabus_name_2,
            R.id.syllabus_name_3, R.id.syllabus_name_4
        )
        private val PROGRESS_IDS = intArrayOf(
            R.id.syllabus_progress_0, R.id.syllabus_progress_1, R.id.syllabus_progress_2,
            R.id.syllabus_progress_3, R.id.syllabus_progress_4
        )
        private val PCT_IDS = intArrayOf(
            R.id.syllabus_pct_0, R.id.syllabus_pct_1, R.id.syllabus_pct_2,
            R.id.syllabus_pct_3, R.id.syllabus_pct_4
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

                val views = RemoteViews(context.packageName, R.layout.syllabus_widget_layout)

                if (subjectCount <= 0) {
                    views.setViewVisibility(R.id.syllabus_widget_empty_state, View.VISIBLE)
                    views.setViewVisibility(R.id.syllabus_widget_content, View.GONE)
                    views.setTextViewText(R.id.syllabus_widget_empty_title, "Syllabus")
                    views.setTextViewText(R.id.syllabus_widget_empty_subtitle, "No subjects yet")
                    setLaunchPendingIntent(context, widgetId, views, R.id.syllabus_widget_empty_state)
                } else {
                    views.setViewVisibility(R.id.syllabus_widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.syllabus_widget_content, View.VISIBLE)

                    val displayCount = subjectCount.coerceAtMost(MAX_SUBJECTS)

                    for (i in 0 until MAX_SUBJECTS) {
                        val visible = i < displayCount
                        if (visible) {
                            val name = widgetData.getString(KEY_PREFIX_NAME + "$i", "Subject") ?: "Subject"
                            val progress = widgetData.getFloat(KEY_PREFIX_PROGRESS + "$i", 0f)
                            val colorHex = widgetData.getString(KEY_PREFIX_COLOR + "$i", "#2196F3") ?: "#2196F3"

                            val percent = (progress * 100).toInt().coerceIn(0, 100)
                            val color = try { Color.parseColor(colorHex) } catch (e: Exception) { Color.parseColor("#2196F3") }

                            views.setTextViewText(NAME_IDS[i], name)
                            views.setTextColor(NAME_IDS[i], Color.WHITE)

                            views.setTextViewText(PCT_IDS[i], "$percent%")
                            views.setTextColor(PCT_IDS[i], color)

                            views.setProgressBar(PROGRESS_IDS[i], 100, percent, false)
                        } else {
                            views.setTextViewText(NAME_IDS[i], "")
                            views.setTextViewText(PCT_IDS[i], "")
                            views.setProgressBar(PROGRESS_IDS[i], 100, 0, false)
                        }
                    }

                    setLaunchPendingIntent(context, widgetId, views, R.id.syllabus_widget_content)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i(TAG, "Widget $widgetId updated: subjects=$subjectCount")

            } catch (e: Exception) {
                android.util.Log.e(TAG, "Update failed for widget $widgetId", e)
            }
        }

        private fun setLaunchPendingIntent(context: Context, widgetId: Int, views: RemoteViews, viewId: Int) {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                launchIntent.putExtra("route", "/syllabus")
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId + 4000,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(viewId, pendingIntent)
            }
        }

        @JvmStatic
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, SyllabusWidgetProvider::class.java)
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
            "com.example.event_countdown.SYLLABUS_WIDGET_REFRESH" -> updateAllWidgets(context)
            Intent.ACTION_BOOT_COMPLETED -> updateAllWidgets(context)
            Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAllWidgets(context)
    }
}

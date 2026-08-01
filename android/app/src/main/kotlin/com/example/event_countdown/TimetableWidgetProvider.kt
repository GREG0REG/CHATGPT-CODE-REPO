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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TimetableWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val KEY_CLASS_COUNT = "timetable_class_count"
        private const val KEY_PREFIX_SUBJECT = "timetable_subject_"
        private const val KEY_PREFIX_TIME = "timetable_time_"
        private const val KEY_PREFIX_ROOM = "timetable_room_"
        private const val KEY_PREFIX_COLOR = "timetable_color_"

        private val ROW_IDS = listOf(
            R.id.timetable_class_row_1,
            R.id.timetable_class_row_2,
            R.id.timetable_class_row_3
        )
        private val DOT_IDS = listOf(
            R.id.timetable_class_dot_1,
            R.id.timetable_class_dot_2,
            R.id.timetable_class_dot_3
        )
        private val SUBJECT_IDS = listOf(
            R.id.timetable_class_subject_1,
            R.id.timetable_class_subject_2,
            R.id.timetable_class_subject_3
        )
        private val INFO_IDS = listOf(
            R.id.timetable_class_info_1,
            R.id.timetable_class_info_2,
            R.id.timetable_class_info_3
        )

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                val classCount = widgetData.getInt(KEY_CLASS_COUNT, 0)

                val views = RemoteViews(context.packageName, R.layout.timetable_widget_layout)

                // Compute day name and date locally
                val now = Date()
                val dayFormat = SimpleDateFormat("EEEE", Locale.getDefault())
                val dateFormat = SimpleDateFormat("MMM d", Locale.getDefault())
                views.setTextViewText(R.id.timetable_widget_day, dayFormat.format(now))
                views.setTextViewText(R.id.timetable_widget_date, dateFormat.format(now))

                if (classCount == 0) {
                    views.setViewVisibility(R.id.timetable_widget_empty, View.VISIBLE)
                    for (rowId in ROW_IDS) {
                        views.setViewVisibility(rowId, View.GONE)
                    }
                } else {
                    views.setViewVisibility(R.id.timetable_widget_empty, View.GONE)

                    for (i in 0 until 3) {
                        if (i < classCount) {
                            val subject = widgetData.getString(KEY_PREFIX_SUBJECT + "$i", "Class") ?: "Class"
                            val timeStr = widgetData.getString(KEY_PREFIX_TIME + "$i", "") ?: ""
                            val room = widgetData.getString(KEY_PREFIX_ROOM + "$i", "") ?: ""
                            val colorHex = widgetData.getString(KEY_PREFIX_COLOR + "$i", "#2196F3") ?: "#2196F3"

                            val color = try {
                                Color.parseColor(colorHex)
                            } catch (e: Exception) {
                                Color.parseColor("#2196F3")
                            }

                            val infoText = if (room.isNotEmpty()) "$timeStr  •  $room" else timeStr

                            views.setViewVisibility(ROW_IDS[i], View.VISIBLE)
                            views.setTextViewText(DOT_IDS[i], "●")
                            views.setTextColor(DOT_IDS[i], color)
                            views.setTextViewText(SUBJECT_IDS[i], subject)
                            views.setTextColor(SUBJECT_IDS[i], color)
                            views.setTextViewText(INFO_IDS[i], infoText)
                        } else {
                            views.setViewVisibility(ROW_IDS[i], View.GONE)
                        }
                    }
                }

                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launchIntent ->
                    launchIntent.putExtra("route", "/timetable")
                    val pendingIntent = PendingIntent.getActivity(
                        context, widgetId + 2000, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.timetable_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("TimetableWidget", "Widget $widgetId updated: $classCount classes")

            } catch (e: Exception) {
                android.util.Log.e("TimetableWidget", "Update failed", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, TimetableWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("TimetableWidget", "Updating ${widgetIds.size} widgets")
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

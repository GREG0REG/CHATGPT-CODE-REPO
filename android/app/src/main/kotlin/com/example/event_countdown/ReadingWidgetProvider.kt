package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

class ReadingWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val READING_DATA_FILE = "reading_widget_data.json"

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.reading_widget_layout)

                // Read JSON data written by Flutter
                var bookTitle = "No Books"
                var currentPage = 0
                var totalPages = 0
                var progressPercent = 0
                var statusColor = "#2196F3"
                var reminderText = "Add a book to start tracking"
                var minutesReadToday = 0

                try {
                    // CRITICAL FIX: Use getApplicationSupportDirectory path
                    val dir = context.getDir("flutter", Context.MODE_PRIVATE)
                    val file = File(dir.parentFile, "app_flutter/reading_widget_data.json")
                    
                    // Fallback to filesDir for compatibility
                    val fallbackFile = File(context.filesDir, READING_DATA_FILE)
                    
                    val targetFile = if (file.exists()) file else fallbackFile

                    if (targetFile.exists()) {
                        val json = JSONObject(targetFile.readText())
                        bookTitle = json.optString("bookTitle", bookTitle)
                        currentPage = json.optInt("currentPage", 0)
                        totalPages = json.optInt("totalPages", 0)
                        progressPercent = json.optInt("progressPercent", 0)
                        statusColor = json.optString("statusColor", statusColor)
                        reminderText = json.optString("message", reminderText)
                        minutesReadToday = json.optInt("minutesReadToday", 0)
                    } else {
                        android.util.Log.w("ReadingWidget", "Data file not found at: ${targetFile.absolutePath}")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("ReadingWidget", "JSON read failed", e)
                }

                // Set book title
                views.setTextViewText(R.id.reading_widget_title, "📖 $bookTitle")

                // Set page info
                views.setTextViewText(
                    R.id.reading_widget_pages,
                    "Page $currentPage/$totalPages • $progressPercent%"
                )

                // Parse accent color
                val accentColor = try {
                    Color.parseColor(statusColor)
                } catch (e: Exception) {
                    Color.parseColor("#2196F3")
                }

                // Set progress bar color and value
                views.setProgressBar(R.id.reading_widget_progress_bar, 100, progressPercent, false)

                // Apply progress tint color
                views.setInt(R.id.reading_widget_progress_bar, "setProgressTintList", accentColor)

                // Show reminder based on reading status
                if (minutesReadToday == 0 && totalPages > 0 && currentPage < totalPages) {
                    views.setViewVisibility(R.id.reading_widget_reminder, View.VISIBLE)
                    views.setTextViewText(R.id.reading_widget_reminder, "⏰ $reminderText")
                } else if (minutesReadToday > 0) {
                    views.setViewVisibility(R.id.reading_widget_reminder, View.VISIBLE)
                    views.setTextViewText(R.id.reading_widget_reminder, "✅ Read ${minutesReadToday}m today")
                } else {
                    views.setViewVisibility(R.id.reading_widget_reminder, View.VISIBLE)
                    views.setTextViewText(R.id.reading_widget_reminder, reminderText)
                }

                // Tap opens app
                val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                openAppIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    widgetId + 4000,
                    openAppIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.reading_widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("ReadingWidget", "Widget $widgetId updated: $bookTitle ($progressPercent%)")

            } catch (e: Exception) {
                android.util.Log.e("ReadingWidget", "Update failed", e)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, ReadingWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
            android.util.Log.i("ReadingWidget", "Updating ${widgetIds.size} widgets")
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
        android.util.Log.i("ReadingWidget", "onUpdate: ${appWidgetIds.size} widgets")
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        android.util.Log.i("ReadingWidget", "onReceive: ${intent.action}")
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
        }
    }
}

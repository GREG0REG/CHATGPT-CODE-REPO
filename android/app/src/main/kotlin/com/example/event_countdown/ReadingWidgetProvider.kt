package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class ReadingWidgetProvider : AppWidgetProvider() {

    companion object {

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.reading_widget_layout)

                // ── Read data from home_widget SharedPreferences ──
                val widgetData = HomeWidgetPlugin.getData(context)

                val bookCount = widgetData.getInt("reading_book_count", 0)

                // Safe defaults
                var bookTitle = "No Books"
                var currentPage = 0
                var totalPages = 0
                var progressPercent = 0
                var statusColor = "#2196F3"
                var reminderText = "Add a book to start tracking"
                var minutesReadToday = 0

                if (bookCount > 0) {
                    // Use the first book (highest progress)
                    bookTitle = widgetData.getString("reading_title_0", bookTitle) ?: bookTitle
                    progressPercent = widgetData.getInt("reading_progress_0", 0)
                    val pagesStr = widgetData.getString("reading_pages_0", "0 / 1") ?: "0 / 1"
                    statusColor = widgetData.getString("reading_color_0", statusColor) ?: statusColor

                    // Parse "current / total" from pages string
                    val parts = pagesStr.split("/").map { it.trim() }
                    if (parts.size == 2) {
                        currentPage = parts[0].toIntOrNull() ?: 0
                        totalPages = parts[1].toIntOrNull() ?: 1
                    }
                }

                // Set book title
                views.setTextViewText(R.id.reading_widget_title, "📖 $bookTitle")

                // Set page info
                views.setTextViewText(
                    R.id.reading_widget_pages,
                    "Page $currentPage/$totalPages • $progressPercent%"
                )

                // Set progress bar value
                views.setProgressBar(R.id.reading_widget_progress_bar, 100, progressPercent, false)

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

                // Null-safe PendingIntent using ?.let
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { openAppIntent ->
                    openAppIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId + 4000,
                        openAppIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.reading_widget_root, pendingIntent)
                }

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

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

class ReadingWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val MAX_BOOKS = 10
        private const val REQUEST_CODE_BASE = 5000

        // Subject color mapping for NEET
        private val SUBJECT_COLORS = mapOf(
            "physics" to "#2196F3",
            "chemistry" to "#4CAF50",
            "biology" to "#F44336",
            "zoology" to "#E91E63",
            "botany" to "#009688",
            "math" to "#FF9800",
            "mathematics" to "#FF9800",
            "organic chemistry" to "#4CAF50",
            "physical chemistry" to "#8BC34A",
            "inorganic chemistry" to "#CDDC39",
            "general" to "#607D8B"
        )

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.reading_widget_layout)
                val widgetData = HomeWidgetPlugin.getData(context)

                val bookCount = widgetData.getInt("reading_book_count", 0)
                val totalBooksAdded = widgetData.getInt("reading_total_books_added", 0)
                val totalPagesToday = widgetData.getInt("reading_total_pages_today", 0)
                val totalMinutesToday = widgetData.getInt("reading_total_minutes_today", 0)
                val streakDays = widgetData.getInt("reading_streak_days", 0)
                val readToday = widgetData.getBoolean("reading_read_today", false)

                // Clear previous book items
                views.removeAllViews(R.id.reading_widget_books_container)

                if (bookCount <= 0) {
                    // Show empty state
                    views.setViewVisibility(R.id.reading_widget_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.reading_widget_books_container, View.GONE)
                    views.setViewVisibility(R.id.reading_widget_footer, View.GONE)
                    views.setViewVisibility(R.id.reading_widget_footer_stats, View.GONE)
                    views.setViewVisibility(R.id.reading_widget_streak, View.GONE)

                    views.setTextViewText(R.id.reading_widget_empty_title, "📖 No Books")
                    views.setTextViewText(R.id.reading_widget_empty_subtitle, "Page 0/0 • 0%")
                    views.setProgressBar(R.id.reading_widget_empty_progress, 100, 0, false)
                    views.setTextViewText(R.id.reading_widget_empty_hint, "Add a book to start tracking")

                } else {
                    // Hide empty state, show books
                    views.setViewVisibility(R.id.reading_widget_empty, View.GONE)
                    views.setViewVisibility(R.id.reading_widget_books_container, View.VISIBLE)
                    views.setViewVisibility(R.id.reading_widget_footer, View.VISIBLE)
                    views.setViewVisibility(R.id.reading_widget_footer_stats, View.VISIBLE)

                    // Streak badge
                    if (streakDays > 0) {
                        views.setViewVisibility(R.id.reading_widget_streak, View.VISIBLE)
                        val streakText = if (readToday) "🔥 $streakDays" else "⚠️ $streakDays"
                        views.setTextViewText(R.id.reading_widget_streak, streakText)
                    } else {
                        views.setViewVisibility(R.id.reading_widget_streak, View.GONE)
                    }

                    // Build each book row
                    for (i in 0 until bookCount.coerceAtMost(MAX_BOOKS)) {
                        val bookViews = RemoteViews(context.packageName, R.layout.reading_widget_book_item)

                        val title = widgetData.getString("reading_title_$i", "Book $i") ?: "Book $i"
                        val progressPercent = widgetData.getInt("reading_progress_$i", 0)
                        val pagesStr = widgetData.getString("reading_pages_$i", "0 / 1") ?: "0 / 1"
                        val colorHex = widgetData.getString("reading_color_$i", "#2196F3") ?: "#2196F3"
                        val subject = widgetData.getString("reading_subject_$i", "") ?: ""
                        val status = widgetData.getString("reading_status_$i", "On Track") ?: "On Track"
                        val pagesPerDayNeeded = widgetData.getInt("reading_pages_per_day_$i", 0)
                        val estCompletionDate = widgetData.getString("reading_est_date_$i", "") ?: ""
                        val readTodayThisBook = widgetData.getBoolean("reading_read_today_$i", false)
                        val isUrgent = widgetData.getBoolean("reading_is_urgent_$i", false)

                        // Parse current/total pages
                        val parts = pagesStr.split("/").map { it.trim() }
                        val currentPage = parts.getOrNull(0)?.toIntOrNull() ?: 0
                        val totalPages = parts.getOrNull(1)?.toIntOrNull() ?: 1

                        // Determine display color based on subject or fallback
                        val displayColor = getSubjectColor(subject, colorHex)

                        // Title with subject emoji
                        val emoji = getSubjectEmoji(subject)
                        bookViews.setTextViewText(R.id.book_item_title, "$emoji $title")

                        // Status badge
                        val statusColor = when {
                            status.contains("Behind") -> Color.parseColor("#FF5252")
                            status.contains("Urgent") -> Color.parseColor("#FF1744")
                            status.contains("Goal") || status.contains("met") -> Color.parseColor("#69F0AE")
                            else -> Color.parseColor("#69F0AE")
                        }
                        bookViews.setTextViewText(R.id.book_item_status, status)
                        bookViews.setTextColor(R.id.book_item_status, statusColor)

                        // Pages line
                        bookViews.setTextViewText(R.id.book_item_pages, "Page $currentPage/$totalPages • $progressPercent%")

                        // NEET info line (pages/day needed OR completion date)
                        val neetInfo = when {
                            pagesPerDayNeeded > 50 -> "🔥 Need $pagesPerDayNeeded pgs/day — URGENT!"
                            pagesPerDayNeeded > 0 -> "📈 Need $pagesPerDayNeeded pgs/day"
                            estCompletionDate.isNotEmpty() -> "✅ Done by $estCompletionDate"
                            else -> ""
                        }
                        if (neetInfo.isNotEmpty()) {
                            bookViews.setViewVisibility(R.id.book_item_neet_info, View.VISIBLE)
                            bookViews.setTextViewText(R.id.book_item_neet_info, neetInfo)
                        } else {
                            bookViews.setViewVisibility(R.id.book_item_neet_info, View.GONE)
                        }

                        // Progress bar with subject color
                        bookViews.setProgressBar(R.id.book_item_progress, 100, progressPercent, false)

                        // Apply colored border based on urgency
                        if (isUrgent || pagesPerDayNeeded > 50) {
                            bookViews.setInt(R.id.book_item_root, "setBackgroundResource", R.drawable.widget_book_item_urgent)
                        } else if (!readTodayThisBook && progressPercent < 100) {
                            bookViews.setInt(R.id.book_item_root, "setBackgroundResource", R.drawable.widget_book_item_warning)
                        } else {
                            bookViews.setInt(R.id.book_item_root, "setBackgroundResource", R.drawable.widget_book_item_background)
                        }

                        views.addView(R.id.reading_widget_books_container, bookViews)
                    }

                    // Footer stats
                    val hours = totalMinutesToday / 60
                    val mins = totalMinutesToday % 60
                    val timeStr = if (hours > 0) "${hours}h ${mins}m" else "${mins}m"

                    views.setTextViewText(R.id.reading_widget_footer_books, "📊 $bookCount/${totalBooksAdded.coerceAtLeast(bookCount)} books")
                    views.setTextViewText(R.id.reading_widget_footer_pages, "📄 $totalPagesToday pages today")
                    views.setTextViewText(R.id.reading_widget_footer_time, "⏱️ $timeStr")
                }

                // Tap to open app — use READING_SCREEN action
                context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { openAppIntent ->
                    openAppIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    openAppIntent.putExtra("screen", "reading")
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        widgetId + REQUEST_CODE_BASE,
                        openAppIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.reading_widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                android.util.Log.i("ReadingWidget", "Widget $widgetId updated with $bookCount books")

            } catch (e: Exception) {
                android.util.Log.e("ReadingWidget", "Update failed for widget $widgetId", e)
                // Fallback: show empty state to prevent "can't load widget"
                try {
                    val fallbackViews = RemoteViews(context.packageName, R.layout.reading_widget_layout)
                    fallbackViews.setViewVisibility(R.id.reading_widget_empty, View.VISIBLE)
                    fallbackViews.setViewVisibility(R.id.reading_widget_books_container, View.GONE)
                    fallbackViews.setViewVisibility(R.id.reading_widget_footer, View.GONE)
                    fallbackViews.setTextViewText(R.id.reading_widget_empty_title, "📖 Reading Tracker")
                    fallbackViews.setTextViewText(R.id.reading_widget_empty_subtitle, "Tap to open app")
                    fallbackViews.setTextViewText(R.id.reading_widget_empty_hint, "Add books to track progress")
                    appWidgetManager.updateAppWidget(widgetId, fallbackViews)
                } catch (e2: Exception) {
                    android.util.Log.e("ReadingWidget", "Fallback also failed", e2)
                }
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

        private fun getSubjectColor(subject: String, fallbackHex: String): String {
            val key = subject.lowercase().trim()
            return SUBJECT_COLORS[key] ?: fallbackHex
        }

        private fun getSubjectEmoji(subject: String): String {
            return when (subject.lowercase().trim()) {
                "physics" -> "⚛️"
                "chemistry", "organic chemistry", "physical chemistry", "inorganic chemistry" -> "🧪"
                "biology" -> "🧬"
                "zoology" -> "🐾"
                "botany" -> "🌿"
                "math", "mathematics" -> "📐"
                "computer science" -> "💻"
                else -> "📘"
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

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        android.util.Log.i("ReadingWidget", "Widget enabled")
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        android.util.Log.i("ReadingWidget", "Widget disabled")
    }
}

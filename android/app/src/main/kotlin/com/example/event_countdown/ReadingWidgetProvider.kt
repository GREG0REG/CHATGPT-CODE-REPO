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

        // Keep your existing maps
        private val SUBJECT_COLORS = mapOf(
            "physics" to Color.parseColor("#2196F3"),
            "chemistry" to Color.parseColor("#4CAF50"),
            "biology" to Color.parseColor("#F44336"),
            "zoology" to Color.parseColor("#E91E63"),
            "botany" to Color.parseColor("#009688"),
            "math" to Color.parseColor("#FF9800"),
            "mathematics" to Color.parseColor("#FF9800"),
            "organic chemistry" to Color.parseColor("#4CAF50"),
            "physical chemistry" to Color.parseColor("#8BC34A"),
            "inorganic chemistry" to Color.parseColor("#CDDC39"),
            "general" to Color.parseColor("#607D8B")
        )

        private val SUBJECT_PROGRESS_COLORS = mapOf(
            "physics" to "reading_progress_blue",
            "chemistry" to "reading_progress_green",
            "biology" to "reading_progress_red",
            "zoology" to "reading_progress_pink",
            "botany" to "reading_progress_teal",
            "math" to "reading_progress_orange",
            "mathematics" to "reading_progress_orange",
            "organic chemistry" to "reading_progress_green",
            "physical chemistry" to "reading_progress_light_green",
            "inorganic chemistry" to "reading_progress_lime",
            "general" to "reading_progress_gray"
        )

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

        @JvmStatic
        fun updateWidgetDirectly(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                val views = RemoteViews(context.packageName, R.layout.reading_widget_layout)
                
                val widgetData = HomeWidgetPlugin.getData(context)
                val bookCount = widgetData.getInt("reading_book_count", 0)
                val totalBooksAdded = widgetData.getInt("reading_total_books_added", 0)
                val totalPagesToday = widgetData.getInt("reading_total_pages_today", 0)
                val totalMinutesToday = widgetData.getInt("reading_total_minutes_today", 0)
                val streakDays = widgetData.getInt("reading_streak_days", 0)
                val readToday = widgetData.getBoolean("reading_read_today", false)

                views.removeAllViews(R.id.reading_widget_books_container)

                if (bookCount <= 0) {
                    views.setViewVisibility(R.id.reading_widget_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.reading_widget_books_container, View.GONE)
                    views.setViewVisibility(R.id.reading_widget_footer, View.GONE)
                    views.setViewVisibility(R.id.reading_widget_streak, View.GONE)
                    
                    views.setTextViewText(R.id.reading_widget_empty_title, "No Books")
                    views.setTextViewText(R.id.reading_widget_empty_subtitle, "Page 0/0 • 0%")
                    views.setProgressBar(R.id.reading_widget_empty_progress, 100, 0, false)
                    views.setTextViewText(R.id.reading_widget_empty_hint, "Add a book to start tracking")
                } else {
                    views.setViewVisibility(R.id.reading_widget_empty, View.GONE)
                    views.setViewVisibility(R.id.reading_widget_books_container, View.VISIBLE)
                    views.setViewVisibility(R.id.reading_widget_footer, View.VISIBLE)

                    if (streakDays > 0) {
                        views.setViewVisibility(R.id.reading_widget_streak, View.VISIBLE)
                        val streakText = if (readToday) "🔥 $streakDays day streak" else "⚠️ $streakDays day streak"
                        views.setTextViewText(R.id.reading_widget_streak, streakText)
                    } else {
                        views.setViewVisibility(R.id.reading_widget_streak, View.GONE)
                    }

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

                        val parts = pagesStr.split("/").map { it.trim() }
                        val currentPage = parts.getOrNull(0)?.toIntOrNull() ?: 0
                        val totalPages = parts.getOrNull(1)?.toIntOrNull() ?: 1

                        val accentColor = SUBJECT_COLORS[subject.lowercase()] ?: Color.parseColor(colorHex)
                        bookViews.setInt(R.id.book_item_accent_bar, "setBackgroundColor", accentColor)

                        val progressDrawableName = SUBJECT_PROGRESS_COLORS[subject.lowercase()] ?: "reading_progress_blue"
                        val progressDrawableId = context.resources.getIdentifier(progressDrawableName, "drawable", context.packageName)
                        if (progressDrawableId != 0) {
                            try {
                                bookViews.setInt(R.id.book_item_progress, "setProgressDrawable", progressDrawableId)
                            } catch (e: Exception) {
                                // Fallback silently
                            }
                        }

                        val emoji = getSubjectEmoji(subject)
                        bookViews.setTextViewText(R.id.book_item_title, "$emoji $title")

                        val (statusText, statusColor) = when {
                            status.contains("Behind", ignoreCase = true) -> "⚠️ Behind" to Color.parseColor("#FFB74D")
                            status.contains("Goal", ignoreCase = true) || status.contains("met", ignoreCase = true) -> "✅ Goal met" to Color.parseColor("#69F0AE")
                            status.contains("Completed", ignoreCase = true) -> "✅ Done" to Color.parseColor("#69F0AE")
                            status.contains("Not Started", ignoreCase = true) -> "⏳ Not started" to Color.parseColor("#B0BEC5")
                            else -> "✅ On track" to Color.parseColor("#69F0AE")
                        }
                        bookViews.setTextViewText(R.id.book_item_status, statusText)
                        bookViews.setTextColor(R.id.book_item_status, statusColor)

                        val pagesInfo = buildString {
                            append("Page $currentPage/$totalPages")
                            append(" • $progressPercent%")
                            if (pagesPerDayNeeded > 0 && !status.contains("Completed", ignoreCase = true)) {
                                append(" • Need $pagesPerDayNeeded pgs/day")
                            } else if (estCompletionDate.isNotEmpty() && !status.contains("Completed", ignoreCase = true)) {
                                append(" • Done by $estCompletionDate")
                            }
                        }
                        bookViews.setTextViewText(R.id.book_item_pages, pagesInfo)

                        bookViews.setProgressBar(R.id.book_item_progress, 100, progressPercent, false)

                        val titleColor = when {
                            isUrgent || pagesPerDayNeeded > 50 -> Color.parseColor("#FF8A80")
                            !readTodayThisBook && progressPercent < 100 -> Color.parseColor("#FFE082")
                            else -> Color.WHITE
                        }
                        bookViews.setTextColor(R.id.book_item_title, titleColor)

                        views.addView(R.id.reading_widget_books_container, bookViews)
                    }

                    val hours = totalMinutesToday / 60
                    val mins = totalMinutesToday % 60
                    val timeStr = when {
                        hours > 0 && mins > 0 -> "${hours}h ${mins}m"
                        hours > 0 -> "${hours}h"
                        else -> "${mins}m"
                    }
                    val activeBooks = bookCount.coerceAtMost(MAX_BOOKS)
                    val totalBooks = totalBooksAdded.coerceAtLeast(activeBooks)
                    
                    views.setTextViewText(R.id.reading_widget_footer_books, "$activeBooks/$totalBooks books active")
                    views.setTextViewText(R.id.reading_widget_footer_pages, "$totalPagesToday pages today")
                    views.setTextViewText(R.id.reading_widget_footer_time, timeStr)
                }

                val openAppIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("screen", "reading")
                }
                val pendingIntent = PendingIntent.getActivity(context, appWidgetId + REQUEST_CODE_BASE, openAppIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                views.setOnClickPendingIntent(R.id.reading_widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                // Log the error for debugging
                android.util.Log.e("ReadingWidget", "Failed to update widget", e)
                // Fallback to empty state
                val fallbackViews = RemoteViews(context.packageName, R.layout.reading_widget_layout)
                fallbackViews.setViewVisibility(R.id.reading_widget_empty, View.VISIBLE)
                fallbackViews.setViewVisibility(R.id.reading_widget_books_container, View.GONE)
                fallbackViews.setViewVisibility(R.id.reading_widget_footer, View.GONE)
                fallbackViews.setViewVisibility(R.id.reading_widget_streak, View.GONE)
                fallbackViews.setTextViewText(R.id.reading_widget_empty_title, "Loading...")
                fallbackViews.setTextViewText(R.id.reading_widget_empty_hint, "Try refreshing from app")
                appWidgetManager.updateAppWidget(appWidgetId, fallbackViews)
            }
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, ReadingWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (appWidgetId in appWidgetIds) {
                updateWidgetDirectly(context, appWidgetManager, appWidgetId)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            "com.example.event_countdown.READING_WIDGET_REFRESH" -> updateAllWidgets(context)
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> updateAllWidgets(context)
        }
    }
}

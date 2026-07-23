package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.util.Log
import android.widget.RemoteViews
import android.database.sqlite.SQLiteDatabase
import android.database.Cursor

class EventCountdownWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "EventWidget"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TITLE = "event_title"
        private const val KEY_COUNTDOWN = "countdown_text"
        private const val KEY_BG_COLOR = "widget_bg_color"
        private const val KEY_TEXT_COLOR = "widget_text_color"
        private const val KEY_PROGRESS = "widget_progress_percent"
        private const val KEY_URGENCY_COLOR = "widget_urgency_color"
        private const val KEY_SMART_FORMAT = "smart_countdown_format"
        private const val KEY_EVENT_DATE = "widget_event_date_millis"
        private const val KEY_EVENT_START = "widget_event_start_millis"
        private const val KEY_EVENT_DEADLINE = "widget_event_deadline_millis"
        private const val KEY_EVENT_COMPLETED = "widget_event_is_completed"
        private const val KEY_GRADE_CURRENT = "grade_current"
        private const val KEY_GRADE_LETTER = "grade_letter"
        private const val KEY_TASKS_URGENT = "tasks_urgent_count"
        private const val KEY_TASKS_TOTAL = "tasks_total_count"

        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else Color.parseColor(colorStr)
            } catch (e: Exception) {
                defaultColor
            }
        }

        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            title: String,
            countdown: String,
            bgColorStr: String?,
            textColorStr: String?,
            progressPercent: Int = 65,
            urgencyColorName: String? = null,
            smartFormat: Boolean = false
        ) {
            try {
                val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

                views.setTextViewText(R.id.widget_title, title)
                views.setTextViewText(R.id.widget_countdown, countdown)
                views.setProgressBar(R.id.widget_progress_ring, 100, progressPercent.coerceIn(0, 100), false)

                val themeColor = parseColorOrDefault(bgColorStr, Color.parseColor("#00BFA5"))
                val textColor = parseColorOrDefault(textColorStr, Color.WHITE)

                views.setInt(R.id.widget_root, "setBackgroundColor", themeColor)
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)

                val showUrgency = urgencyColorName != null &&
                    urgencyColorName != "green" &&
                    urgencyColorName != "grey"

                if (showUrgency) {
                    views.setViewVisibility(R.id.widget_urgency_row, android.view.View.VISIBLE)
                    val urgencyColor = when (urgencyColorName) {
                        "red" -> Color.parseColor("#F44336")
                        "deepOrange" -> Color.parseColor("#FF5722")
                        "orange" -> Color.parseColor("#FF9800")
                        else -> Color.parseColor("#FF9800")
                    }
                    views.setTextColor(R.id.widget_urgency_dot, urgencyColor)
                    val urgencyLabel = when (urgencyColorName) {
                        "red" -> "URGENT"
                        "deepOrange" -> "Soon"
                        "orange" -> "Upcoming"
                        else -> ""
                    }
                    views.setTextViewText(R.id.widget_urgency_label, urgencyLabel)
                    views.setTextColor(R.id.widget_urgency_label, urgencyColor)
                } else {
                    views.setViewVisibility(R.id.widget_urgency_row, android.view.View.GONE)
                }

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                }

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Update failed", e)
            }
        }

        private fun computeNativeCountdown(
            nowMillis: Long,
            dateMillis: Long,
            startTimeMillis: Long?,
            deadlineMillis: Long?,
            smartFormat: Boolean
        ): String {
            val targetMillis = when {
                startTimeMillis != null && nowMillis < startTimeMillis -> startTimeMillis
                deadlineMillis != null -> deadlineMillis
                else -> {
                    val cal = java.util.Calendar.getInstance()
                    cal.timeInMillis = dateMillis
                    cal.set(java.util.Calendar.HOUR_OF_DAY, 23)
                    cal.set(java.util.Calendar.MINUTE, 59)
                    cal.set(java.util.Calendar.SECOND, 59)
                    cal.timeInMillis
                }
            }

            val diffMs = targetMillis - nowMillis
            if (diffMs <= 0) return "Completed"

            val diff = java.util.concurrent.TimeUnit.MILLISECONDS
            val days = diff.toDays(diffMs)
            val hours = diff.toHours(diffMs) % 24
            val minutes = diff.toMinutes(diffMs) % 60

            val isBeforeStart = startTimeMillis != null && nowMillis < startTimeMillis
            val suffix = if (isBeforeStart) " until start" else " left"

            return if (smartFormat) {
                when {
                    days > 0 -> {
                        val h = hours
                        val m = minutes
                        if (h > 0 || m > 0) {
                            "$days day${if (days == 1L) "" else "s"}, $h hour${if (h == 1L) "" else "s"}, $m minute${if (m == 1L) "" else "s"}$suffix"
                        } else {
                            "$days day${if (days == 1L) "" else "s"}$suffix"
                        }
                    }
                    hours > 0 -> {
                        val m = minutes
                        if (m > 0) {
                            "$hours hour${if (hours == 1L) "" else "s"}, $m minute${if (m == 1L) "" else "s"}$suffix"
                        } else {
                            "$hours hour${if (hours == 1L) "" else "s"}$suffix"
                        }
                    }
                    else -> {
                        val m = if (minutes < 1) 1 else minutes
                        "$m minute${if (m == 1L) "" else "s"}$suffix"
                    }
                }
            } else {
                when {
                    days > 0 -> "$days day${if (days == 1L) "" else "s"}$suffix"
                    hours > 0 -> "$hours hour${if (hours == 1L) "" else "s"}$suffix"
                    else -> {
                        val m = if (minutes < 1) 1 else minutes
                        "$m minute${if (m == 1L) "" else "s"}$suffix"
                    }
                }
            }
        }

        private fun queryNextEventFromDatabase(context: Context): Map<String, Any?>? {
            var db: SQLiteDatabase? = null
            var cursor: Cursor? = null
            try {
                val dbPath = context.getDatabasePath("event_countdown.db")
                if (!dbPath.exists()) {
                    Log.d(TAG, "Database not found at ${dbPath.absolutePath}")
                    return null
                }

                db = SQLiteDatabase.openDatabase(dbPath.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
                val now = System.currentTimeMillis()

                cursor = db.query(
                    "events",
                    arrayOf("title", "dateMillis", "startTimeMillis", "deadlineMillis", "isCompleted"),
                    "isCompleted = 0 AND dateMillis > ?",
                    arrayOf(now.toString()),
                    null,
                    null,
                    "dateMillis ASC",
                    "1"
                )

                if (cursor != null && cursor.moveToFirst()) {
                    val title = cursor.getString(cursor.getColumnIndexOrThrow("title"))
                    val dateMillis = cursor.getLong(cursor.getColumnIndexOrThrow("dateMillis"))
                    val startTimeMillis = if (cursor.isNull(cursor.getColumnIndexOrThrow("startTimeMillis"))) null
                        else cursor.getLong(cursor.getColumnIndexOrThrow("startTimeMillis"))
                    val deadlineMillis = if (cursor.isNull(cursor.getColumnIndexOrThrow("deadlineMillis"))) null
                        else cursor.getLong(cursor.getColumnIndexOrThrow("deadlineMillis"))

                    return mapOf(
                        "title" to title,
                        "dateMillis" to dateMillis,
                        "startTimeMillis" to startTimeMillis,
                        "deadlineMillis" to deadlineMillis
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Database query failed", e)
            } finally {
                cursor?.close()
                db?.close()
            }
            return null
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()

            var title = prefs.getString(KEY_TITLE, "No upcoming events") ?: "No upcoming events"
            var countdown = prefs.getString(KEY_COUNTDOWN, "") ?: ""
            val bgColorStr = prefs.getString(KEY_BG_COLOR, null)
            val textColorStr = prefs.getString(KEY_TEXT_COLOR, null)
            var progressPercent = prefs.getInt(KEY_PROGRESS, 65)
            var urgencyColorName = prefs.getString(KEY_URGENCY_COLOR, null)
            val smartFormat = prefs.getBoolean(KEY_SMART_FORMAT, false)

            val eventDate = prefs.getLong(KEY_EVENT_DATE, -1L)
            val eventStart = if (prefs.contains(KEY_EVENT_START)) prefs.getLong(KEY_EVENT_START, -1L) else null
            val eventDeadline = if (prefs.contains(KEY_EVENT_DEADLINE)) prefs.getLong(KEY_EVENT_DEADLINE, -1L) else null
            val eventCompleted = prefs.getBoolean(KEY_EVENT_COMPLETED, false)

            val shouldRecompute = countdown.isEmpty() || eventCompleted ||
                (eventDate > 0 && eventDate < now && (eventDeadline == null || eventDeadline < now))

            if (shouldRecompute) {
                val dbEvent = queryNextEventFromDatabase(context)
                if (dbEvent != null) {
                    title = dbEvent["title"] as String
                    val dateMillis = dbEvent["dateMillis"] as Long
                    val startTimeMillis = dbEvent["startTimeMillis"] as? Long
                    val deadlineMillis = dbEvent["deadlineMillis"] as? Long

                    countdown = computeNativeCountdown(
                        now, dateMillis, startTimeMillis, deadlineMillis, smartFormat
                    )

                    val targetMillis = when {
                        startTimeMillis != null && now < startTimeMillis -> startTimeMillis
                        deadlineMillis != null -> deadlineMillis
                        else -> dateMillis
                    }
                    val diffDays = java.util.concurrent.TimeUnit.MILLISECONDS.toDays(targetMillis - now)
                    urgencyColorName = when {
                        diffDays < 0 -> "grey"
                        diffDays > 7 -> "green"
                        diffDays >= 3 -> "orange"
                        else -> "red"
                    }

                    progressPercent = 65
                }
            } else if (eventDate > 0 && !eventCompleted) {
                countdown = computeNativeCountdown(
                    now, eventDate, eventStart, eventDeadline, smartFormat
                )
            }

            val gradeCurrent = prefs.getFloat(KEY_GRADE_CURRENT, 0f)
            val gradeLetter = prefs.getString(KEY_GRADE_LETTER, "N/A") ?: "N/A"
            val tasksUrgent = prefs.getInt(KEY_TASKS_URGENT, 0)
            val tasksTotal = prefs.getInt(KEY_TASKS_TOTAL, 0)

            Log.d(TAG, "Grade: $gradeCurrent ($gradeLetter), Tasks: $tasksUrgent urgent / $tasksTotal total, SmartFormat: $smartFormat")

            for (widgetId in appWidgetIds) {
                updateWidgetDirectly(
                    context, appWidgetManager, widgetId,
                    title, countdown, bgColorStr, textColorStr,
                    progressPercent, urgencyColorName, smartFormat
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "onUpdate failed", e)
        }
    }
}

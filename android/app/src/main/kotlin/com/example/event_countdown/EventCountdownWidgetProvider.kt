package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews

class EventCountdownWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TITLE = "event_title"
        private const val KEY_COUNTDOWN = "countdown_text"
        private const val KEY_BG_TYPE = "widget_bg_type"
        private const val KEY_BG_COLOR = "widget_bg_color"
        private const val KEY_TEXT_COLOR = "widget_text_color"
        private const val KEY_IMAGE_PATH = "widget_image_path"
        private const val KEY_PROGRESS_PERCENT = "widget_progress_percent"
        private const val KEY_PULSE_ENABLED = "widget_pulse_enabled"
        private const val KEY_IS_URGENT = "widget_is_urgent"
        
        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else colorStr.toLong().toInt()
            } catch (e: NumberFormatException) {
                defaultColor
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        val title = prefs.getString(KEY_TITLE, "No upcoming events") ?: "No upcoming events"
        val countdown = prefs.getString(KEY_COUNTDOWN, "") ?: ""
        val bgType = prefs.getString(KEY_BG_TYPE, "theme") ?: "theme"
        val bgColorStr = prefs.getString(KEY_BG_COLOR, null)
        val textColorStr = prefs.getString(KEY_TEXT_COLOR, null)
        val progressPercent = prefs.getInt(KEY_PROGRESS_PERCENT, -1)
        val pulseEnabled = prefs.getBoolean(KEY_PULSE_ENABLED, false)
        val isUrgent = prefs.getBoolean(KEY_IS_URGENT, false)
        
        for (widgetId in appWidgetIds) {
            updateWidget(
                context,
                appWidgetManager,
                widgetId,
                title,
                countdown,
                bgType,
                bgColorStr,
                textColorStr,
                progressPercent,
                pulseEnabled,
                isUrgent
            )
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        title: String,
        countdown: String,
        bgType: String,
        bgColorStr: String?,
        textColorStr: String?,
        progressPercent: Int,
        pulseEnabled: Boolean,
        isUrgent: Boolean
    ) {
        val views = RemoteViews(context.packageName, R.layout.event_widget_layout)
        
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_countdown, countdown)
        
        // Progress bar
        if (progressPercent >= 0) {
            views.setViewVisibility(R.id.widget_progress_container, View.VISIBLE)
            views.setTextViewText(R.id.widget_progress_text, "$progressPercent%")
        } else {
            views.setViewVisibility(R.id.widget_progress_container, View.GONE)
        }
        
        // Pulse overlay
        if (pulseEnabled && isUrgent) {
            views.setViewVisibility(R.id.widget_pulse_overlay, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_pulse_overlay, View.GONE)
        }
        
        // Background color - SAFE: use setInt with background color, no bitmaps
        val themeColor = parseColorOrDefault(bgColorStr, Color.parseColor("#2196F3"))
        val textColor = parseColorOrDefault(textColorStr, Color.WHITE)
        
        views.setInt(R.id.widget_background_color, "setBackgroundColor", themeColor)
        views.setTextColor(R.id.widget_title, textColor)
        views.setTextColor(R.id.widget_countdown, textColor)
        views.setTextColor(R.id.widget_progress_text, textColor)
        
        // Open app on tap
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        
        appWidgetManager.updateAppWidget(widgetId, views)
    }
}

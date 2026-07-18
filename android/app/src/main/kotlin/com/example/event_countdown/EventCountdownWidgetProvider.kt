package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

class EventCountdownWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val KEY_TITLE = "event_title"
        private const val KEY_COUNTDOWN = "countdown_text"
        private const val KEY_BG_COLOR = "widget_bg_color"
        private const val KEY_TEXT_COLOR = "widget_text_color"
        
        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else Color.parseColor(colorStr)
            } catch (e: Exception) {
                defaultColor
            }
        }

        // Called directly from MainActivity so the widget updates instantly
        fun updateWidgetDirectly(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            title: String,
            countdown: String,
            bgColorStr: String?,
            textColorStr: String?
        ) {
            val views = RemoteViews(context.packageName, R.layout.event_widget_layout)
            
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_countdown, countdown)
            
            val themeColor = parseColorOrDefault(bgColorStr, Color.parseColor("#2196F3"))
            val textColor = parseColorOrDefault(textColorStr, Color.WHITE)
            
            views.setInt(R.id.widget_root, "setBackgroundColor", themeColor)
            views.setTextColor(R.id.widget_title, textColor)
            views.setTextColor(R.id.widget_countdown, textColor)
            
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

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        val title = prefs.getString(KEY_TITLE, "No upcoming events") ?: "No upcoming events"
        val countdown = prefs.getString(KEY_COUNTDOWN, "") ?: ""
        val bgColorStr = prefs.getString(KEY_BG_COLOR, null)
        val textColorStr = prefs.getString(KEY_TEXT_COLOR, null)
        
        for (widgetId in appWidgetIds) {
            updateWidgetDirectly(context, appWidgetManager, widgetId, title, countdown, bgColorStr, textColorStr)
        }
    }
}

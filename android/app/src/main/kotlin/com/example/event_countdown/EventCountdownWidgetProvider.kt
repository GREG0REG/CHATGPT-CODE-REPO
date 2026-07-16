package com.example.event_countdown

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Shader
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Renders the "active" event's title + countdown text onto the home screen
 * widget. All data is pre-computed on the Dart side (WidgetService) and
 * simply read here from the home_widget shared preferences file.
 *
 * SESSION 3 ENHANCEMENTS:
 * - Progress bar showing % time elapsed with percentage text
 * - Long-press menu: Widget Settings, Mark Done, Open App
 */
class EventCountdownWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.event_widget_layout)

            val title = widgetData.getString("event_title", "No upcoming events") ?: "No upcoming events"
            val countdown = widgetData.getString("countdown_text", "") ?: ""
            val bgType = widgetData.getString("widget_bg_type", "theme") ?: "theme"
            val bgColorStr = widgetData.getString("widget_bg_color", null)
            val textColorStr = widgetData.getString("widget_text_color", null)
            val imagePath = widgetData.getString("widget_image_path", null)
            val progressPercent = widgetData.getInt("widget_progress_percent", -1)

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_countdown, countdown)

            // SESSION 3: Progress bar with percentage text
            if (progressPercent >= 0) {
                views.setViewVisibility(R.id.widget_progress, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_progress_text, android.view.View.VISIBLE)
                views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
                views.setTextViewText(R.id.widget_progress_text, "$progressPercent%")
            } else {
                views.setViewVisibility(R.id.widget_progress, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_progress_text, android.view.View.GONE)
            }

            val useImage = bgType == "image" && !imagePath.isNullOrEmpty() && File(imagePath).exists()

            if (useImage) {
                val bitmap = buildImageBackground(imagePath!!)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_background, bitmap)
                } else {
                    val fallbackColor = parseColorOrDefault(bgColorStr, DEFAULT_COLOR)
                    views.setImageViewBitmap(R.id.widget_background, buildGradientBackground(fallbackColor))
                }
                views.setTextColor(R.id.widget_title, Color.WHITE)
                views.setTextColor(R.id.widget_countdown, Color.WHITE)
                views.setTextColor(R.id.widget_progress_text, Color.WHITE)
            } else {
                val themeColor = parseColorOrDefault(bgColorStr, DEFAULT_COLOR)
                val textColor = parseColorOrDefault(textColorStr, Color.WHITE)
                views.setImageViewBitmap(R.id.widget_background, buildGradientBackground(themeColor))
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)
                views.setTextColor(R.id.widget_progress_text, textColor)
            }

            // SESSION 3: Long-press menu actions
            // 1. Open App (tap on widget root)
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val openAppPending = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppPending)

            // 2. Widget Settings (tap on title)
            val settingsIntent = Intent(context, WidgetSettingsActivity::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val settingsPending = PendingIntent.getActivity(
                context,
                widgetId + 100,
                settingsIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
EventCountdownWidgetProvider.kt

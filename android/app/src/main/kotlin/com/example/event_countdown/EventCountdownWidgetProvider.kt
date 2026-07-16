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
import android.graphics.RectF
import android.graphics.Shader
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class EventCountdownWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val DEFAULT_COLOR = -0x1

        fun parseColorOrDefault(colorStr: String?, defaultColor: Int): Int {
            return try {
                if (colorStr.isNullOrEmpty()) defaultColor else colorStr.toInt()
            } catch (e: NumberFormatException) {
                defaultColor
            }
        }

        fun buildGradientBackground(color: Int): Bitmap {
            val width = 400
            val height = 200
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val darkerColor = darkenColor(color, 0.7f)
            val gradient = LinearGradient(
                0f, 0f, width.toFloat(), height.toFloat(),
                color, darkerColor,
                Shader.TileMode.CLAMP
            )
            val paint = Paint().apply { shader = gradient }
            canvas.drawRect(RectF(0f, 0f, width.toFloat(), height.toFloat()), paint)
            return bitmap
        }

        fun buildImageBackground(imagePath: String): Bitmap? {
            return try {
                val file = File(imagePath)
                if (!file.exists()) return null
                BitmapFactory.decodeFile(file.absolutePath)
            } catch (e: Exception) {
                null
            }
        }

        private fun darkenColor(color: Int, factor: Float): Int {
            val a = Color.alpha(color)
            val r = (Color.red(color) * factor).toInt().coerceIn(0, 255)
            val g = (Color.green(color) * factor).toInt().coerceIn(0, 255)
            val b = (Color.blue(color) * factor).toInt().coerceIn(0, 255)
            return Color.argb(a, r, g, b)
        }
    }

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
            val pulseEnabled = widgetData.getBoolean("widget_pulse_enabled", false)
            val isUrgent = widgetData.getBoolean("widget_is_urgent", false)

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_countdown, countdown)

            // Progress bar
            if (progressPercent >= 0) {
                views.setViewVisibility(R.id.widget_progress_container, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widget_progress_text, "$progressPercent%")
            } else {
                views.setViewVisibility(R.id.widget_progress_container, android.view.View.GONE)
            }

            // Pulse overlay
            if (pulseEnabled && isUrgent) {
                views.setViewVisibility(R.id.widget_pulse_overlay, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_pulse_overlay, android.view.View.GONE)
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

            // Open app on tap
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val openAppPending = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

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
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * Renders the "active" event's title + countdown text onto the home screen
 * widget. All data is pre-computed on the Dart side (WidgetService) and
 * simply read here from the home_widget shared preferences file.
 *
 * SESSION 3 ENHANCEMENTS:
 * - Progress bar showing % time elapsed
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

            // SESSION 3: Progress bar
            if (progressPercent >= 0) {
                views.setViewVisibility(R.id.widget_progress, android.view.View.VISIBLE)
                views.setProgressBar(R.id.widget_progress, 100, progressPercent, false)
            } else {
                views.setViewVisibility(R.id.widget_progress, android.view.View.GONE)
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
            } else {
                val themeColor = parseColorOrDefault(bgColorStr, DEFAULT_COLOR)
                val textColor = parseColorOrDefault(textColorStr, Color.WHITE)
                views.setImageViewBitmap(R.id.widget_background, buildGradientBackground(themeColor))
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)
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
            )
            views.setOnClickPendingIntent(R.id.widget_title, settingsPending)

            // 3. Mark Done (tap on countdown text)
            val markDoneIntent = Intent(context, EventCountdownWidgetProvider::class.java).apply {
                action = ACTION_MARK_DONE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }
            val markDonePending = PendingIntent.getBroadcast(
                context,
                widgetId + 200,
                markDoneIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_countdown, markDonePending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_MARK_DONE) {
            // Send broadcast to Flutter side via home_widget
            val markDoneIntent = Intent(context, HomeWidgetPlugin::class.java).apply {
                action = HomeWidgetPlugin.ACTION_WIDGET_CLICKED
                putExtra("action", "mark_done")
            }
            context.sendBroadcast(markDoneIntent)
        }
    }

    private fun parseColorOrDefault(value: String?, default: Int): Int {
        if (value == null) return default
        return try {
            value.toLong().toInt()
        } catch (e: Exception) {
            default
        }
    }

    private fun buildGradientBackground(baseColor: Int): Bitmap {
        val width = 400
        val height = 200
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val lighter = adjustBrightness(baseColor, 1.15f)
        val darker = adjustBrightness(baseColor, 0.75f)

        val paint = Paint()
        paint.shader = LinearGradient(
            0f, 0f, 0f, height.toFloat(),
            lighter, darker,
            Shader.TileMode.CLAMP
        )
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        return bitmap
    }

    private fun buildImageBackground(path: String): Bitmap? {
        return try {
            val original = BitmapFactory.decodeFile(path) ?: return null
            val targetWidth = 400
            val targetHeight = 200

            val targetAspect = targetWidth.toFloat() / targetHeight.toFloat()
            val sourceAspect = original.width.toFloat() / original.height.toFloat()

            val cropRect: android.graphics.Rect
            if (sourceAspect > targetAspect) {
                val cropWidth = (original.height * targetAspect).toInt()
                val left = (original.width - cropWidth) / 2
                cropRect = android.graphics.Rect(left, 0, left + cropWidth, original.height)
            } else {
                val cropHeight = (original.width / targetAspect).toInt()
                val top = (original.height - cropHeight) / 2
                cropRect = android.graphics.Rect(0, top, original.width, top + cropHeight)
            }

            val result = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(result)
            val destRect = android.graphics.Rect(0, 0, targetWidth, targetHeight)
            canvas.drawBitmap(original, cropRect, destRect, null)

            val overlayPaint = Paint()
            overlayPaint.color = Color.argb(120, 0, 0, 0)
            canvas.drawRect(0f, 0f, targetWidth.toFloat(), targetHeight.toFloat(), overlayPaint)

            result
        } catch (e: Exception) {
            null
        }
    }

    private fun adjustBrightness(color: Int, factor: Float): Int {
        val a = Color.alpha(color)
        val r = (Color.red(color) * factor).coerceIn(0f, 255f).toInt()
        val g = (Color.green(color) * factor).coerceIn(0f, 255f).toInt()
        val b = (Color.blue(color) * factor).coerceIn(0f, 255f).toInt()
        return Color.argb(a, r, g, b)
    }

    companion object {
        private val DEFAULT_COLOR = Color.parseColor("#2196F3")
        const val ACTION_MARK_DONE = "com.example.event_countdown.ACTION_MARK_DONE"
    }
}

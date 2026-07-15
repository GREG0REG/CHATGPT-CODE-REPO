package com.example.event_countdown

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
 * simply read here from the home_widget shared preferences file - this
 * class does no countdown math itself, only rendering.
 *
 * Background is EITHER:
 *   - a gradient built from the selected theme color (default), OR
 *   - a user-picked gallery image with a dark overlay for text readability
 * Never both at once.
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

            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_countdown, countdown)

            val useImage = bgType == "image" && !imagePath.isNullOrEmpty() && File(imagePath).exists()

            if (useImage) {
                val bitmap = buildImageBackground(imagePath!!)
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_background, bitmap)
                } else {
                    // Fallback to theme color if the image failed to load.
                    val fallbackColor = parseColorOrDefault(bgColorStr, DEFAULT_COLOR)
                    views.setImageViewBitmap(R.id.widget_background, buildGradientBackground(fallbackColor))
                }
                // Dark overlay is baked into the bitmap, so text is always white on images.
                views.setTextColor(R.id.widget_title, Color.WHITE)
                views.setTextColor(R.id.widget_countdown, Color.WHITE)
            } else {
                val themeColor = parseColorOrDefault(bgColorStr, DEFAULT_COLOR)
                val textColor = parseColorOrDefault(textColorStr, Color.WHITE)
                views.setImageViewBitmap(R.id.widget_background, buildGradientBackground(themeColor))
                views.setTextColor(R.id.widget_title, textColor)
                views.setTextColor(R.id.widget_countdown, textColor)
            }

            // Tapping the widget opens the app.
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = android.app.PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
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

    /** Builds a simple vertical gradient bitmap from a solid theme color. */
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

    /** Loads the user's chosen gallery image, center-crops it (preserving aspect
     *  ratio, matching the ImageView's centerCrop scaleType) instead of
     *  stretching it, then darkens it for readable text. */
    private fun buildImageBackground(path: String): Bitmap? {
        return try {
            val original = BitmapFactory.decodeFile(path) ?: return null
            val targetWidth = 400
            val targetHeight = 200

            // Scale so the image COVERS the target box (preserving aspect ratio),
            // then crop the centered region - this is what centerCrop does, and
            // must happen here too since we bake the overlay into the bitmap.
            val targetAspect = targetWidth.toFloat() / targetHeight.toFloat()
            val sourceAspect = original.width.toFloat() / original.height.toFloat()

            val cropRect: android.graphics.Rect
            if (sourceAspect > targetAspect) {
                // Source is wider than target: crop left/right, keep full height.
                val cropWidth = (original.height * targetAspect).toInt()
                val left = (original.width - cropWidth) / 2
                cropRect = android.graphics.Rect(left, 0, left + cropWidth, original.height)
            } else {
                // Source is taller than target: crop top/bottom, keep full width.
                val cropHeight = (original.width / targetAspect).toInt()
                val top = (original.height - cropHeight) / 2
                cropRect = android.graphics.Rect(0, top, original.width, top + cropHeight)
            }

            val result = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(result)
            val destRect = android.graphics.Rect(0, 0, targetWidth, targetHeight)
            canvas.drawBitmap(original, cropRect, destRect, null)

            // Dark overlay scrim so white text stays readable on any photo.
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
        // Default Blue #2196F3, used only if no saved color is found yet.
        private val DEFAULT_COLOR = Color.parseColor("#2196F3")
    }
}

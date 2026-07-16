package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

/**
 * Activity launched when user taps "Widget Settings" from the widget's
 * long-press menu. Opens the Flutter app and navigates to the widget
 * settings screen via a deep-link style intent extra.
 */
class WidgetSettingsActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            // Pass widget ID to Flutter via intent extras
            intent.putExtra("route", "/widget_settings")
            intent.putExtra("widget_id", widgetId)
        }
    }
}

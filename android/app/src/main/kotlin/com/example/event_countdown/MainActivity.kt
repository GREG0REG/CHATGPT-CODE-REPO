package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private val CHANNEL = "com.example.event_countdown/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            android.util.Log.i("MainActivity", "Method: ${call.method}")
            when (call.method) {
                "updateWidget" -> {
                    try {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        val componentName = ComponentName(this, EventCountdownWidgetProvider::class.java)
                        val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                        
                        sendBroadcast(Intent(this, EventCountdownWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                        })
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        val appWidgetManager = AppWidgetManager.getInstance(this)
                        val componentName = ComponentName(this, PomodoroWidgetProvider::class.java)
                        val widgetIds = appWidgetManager.getAppWidgetIds(componentName)
                        
                        sendBroadcast(Intent(this, PomodoroWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
                        })
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

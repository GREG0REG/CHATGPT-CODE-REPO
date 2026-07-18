package com.example.event_countdown

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.event_countdown/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                val appWidgetManager = AppWidgetManager.getInstance(this)
                val componentName = ComponentName(this, EventCountdownWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                
                // Get the data Flutter just sent us
                val title = call.argument<String>("title") ?: "No upcoming events"
                val countdown = call.argument<String>("countdown") ?: ""
                val bgColorStr = call.argument<String>("bgColor")
                val textColorStr = call.argument<String>("textColor")
                
                // Update every widget instance immediately
                for (widgetId in appWidgetIds) {
                    EventCountdownWidgetProvider.updateWidgetDirectly(
                        this,
                        appWidgetManager,
                        widgetId,
                        title,
                        countdown,
                        bgColorStr,
                        textColorStr
                    )
                }
                
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}

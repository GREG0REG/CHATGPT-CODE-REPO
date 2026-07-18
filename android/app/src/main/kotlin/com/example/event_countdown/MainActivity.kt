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
            when (call.method) {
                "updateWidget" -> {
                    val appWidgetManager = AppWidgetManager.getInstance(this)
                    val componentName = ComponentName(this, EventCountdownWidgetProvider::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

                    val title = call.argument<String>("title") ?: "No upcoming events"
                    val countdown = call.argument<String>("countdown") ?: ""
                    val bgColorStr = call.argument<String>("bgColor")
                    val textColorStr = call.argument<String>("textColor")

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
                }
                "updatePomodoroWidget" -> {
                    val appWidgetManager = AppWidgetManager.getInstance(this)
                    val componentName = ComponentName(this, PomodoroWidgetProvider::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

                    val subject = call.argument<String>("subject") ?: "Ready to Focus"
                    val timerText = call.argument<String>("timerText") ?: "Tap to start"
                    val status = call.argument<String>("status") ?: "Focus"
                    val bgColorStr = call.argument<String>("bgColor")

                    for (widgetId in appWidgetIds) {
                        PomodoroWidgetProvider.updateWidgetDirectly(
                            this,
                            appWidgetManager,
                            widgetId,
                            subject,
                            timerText,
                            status,
                            bgColorStr
                        )
                    }

                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

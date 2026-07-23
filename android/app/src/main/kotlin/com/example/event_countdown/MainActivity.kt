package com.example.event_countdown

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
                        sendBroadcast(Intent(this, EventCountdownWidgetProvider::class.java).apply {
                            action = "android.appwidget.action.APPWIDGET_UPDATE"
                        })
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        sendBroadcast(Intent(this, PomodoroWidgetProvider::class.java).apply {
                            action = "android.appwidget.action.APPWIDGET_UPDATE"
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

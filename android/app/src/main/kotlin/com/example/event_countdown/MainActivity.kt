package com.example.event_countdown

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
                        // CRITICAL FIX: Direct static call instead of unreliable broadcast.
                        // Broadcasts sent from the app to its own widget are often swallowed
                        // by the system. Calling the companion object method directly is
                        // guaranteed to execute in the same process.
                        EventCountdownWidgetProvider.updateAllWidgets(this)
                        result.success("ok")
                    } catch (e: Exception) {
                        result.error("ERR", e.message, null)
                    }
                }
                "updatePomodoroWidget" -> {
                    try {
                        // CRITICAL FIX: Direct static call instead of broadcast.
                        PomodoroWidgetProvider.updateAllWidgets(this)
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

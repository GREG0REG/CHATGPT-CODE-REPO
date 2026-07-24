package com.example.event_countdown

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

class EventCountdownWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_TICK = "com.example.event_countdown.EVENT_WIDGET_TICK"
        private const val TICK_INTERVAL_MS = 30_000L // 30 seconds

        fun readWidgetData(context: Context): Map<String, Any?> {
            return try {
                val file = File(context.filesDir, "widget_data.json")
                if (!file.exists()) {
                    android.util.Log.w("EventWidget", "File not found: ${file.absolutePath}")
                    return emptyMap()
                }

                val jsonString = file.readText()
                if (jsonString.isBlank()) {
                    android.util.Log.w("EventWidget", "File is empty")
                    return emptyMap()
                }

                android.util.Log.d("EventWidget", "File content: $jsonString")

                val json = JSONObject(jsonString)
                val result = mutableMapOf<String, Any?>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    result[key] = json.opt(key)
                }
                result
            } catch (e: Exception) {
                android.util.Log.e("EventWidget", "Read error", e)
                emptyMap()
            }
       

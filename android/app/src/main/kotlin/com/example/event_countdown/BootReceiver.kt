package com.example.event_countdown

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receiver that handles device boot completion.
 * Restores pomodoro widget updates if a timer was active when device was shut down.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            android.util.Log.d("BootReceiver", "Device booted - checking for active pomodoro timer")

            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val phase = prefs.getString("pomodoro_phase", "idle") ?: "idle"
            val endTimeMillis = prefs.getLong("pomodoro_end_time_millis", 0L).takeIf { it > 0 }

            if (phase != "idle" && endTimeMillis != null) {
                val remainingSeconds = PomodoroWidgetProvider.calculateRemainingTime(endTimeMillis)

                if (remainingSeconds > 0) {
                    android.util.Log.d("BootReceiver", "Restoring pomodoro timer with $remainingSeconds seconds remaining")

                    // Update widget immediately
                    PomodoroWidgetProvider.updateAllWidgets(context)

                    // Resume live updates
                    PomodoroWidgetProvider.scheduleWidgetUpdate(context)
                } else {
                    android.util.Log.d("BootReceiver", "Timer expired during shutdown - clearing state")
                    // Clear expired state
                    prefs.edit().apply {
                        remove("pomodoro_phase")
                        remove("pomodoro_end_time_millis")
                        remove("pomodoro_remaining_seconds")
                        remove("pomodoro_status")
                        apply()
                    }
                    PomodoroWidgetProvider.updateAllWidgets(context)
                }
            }
        }
    }
}

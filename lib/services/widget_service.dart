// In lib/services/widget_service.dart - add or update this method:

static Future<void> refreshPomodoroWidget() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current pomodoro state from prefs
    final subject = prefs.getString('pomodoro_subject') ?? 'Ready to Focus';
    final timerText = prefs.getString('pomodoro_timer_text') ?? 'Tap to start';
    final status = prefs.getString('pomodoro_status') ?? 'Focus';
    final bgColor = prefs.getString('pomodoro_bg_color');
    final progress = prefs.getInt('pomodoro_progress_percent') ?? 0;
    final sessions = prefs.getInt('pomodoro_completed_sessions') ?? 0;

    // Save to widget-accessible prefs with correct keys
    await prefs.setString('pomodoro_subject', subject);
    await prefs.setString('pomodoro_timer_text', timerText);
    await prefs.setString('pomodoro_status', status);
    if (bgColor != null) {
      await prefs.setString('pomodoro_bg_color', bgColor);
    }
    await prefs.setInt('pomodoro_progress_percent', progress);
    await prefs.setInt('pomodoro_completed_sessions', sessions);

    // Trigger native widget update
    const platform = MethodChannel('com.example.event_countdown/widget');
    await platform.invokeMethod('updatePomodoroWidget', {
      'subject': subject,
      'timerText': timerText,
      'status': status,
      'bgColor': bgColor,
      'progressPercent': progress,
      'completedSessions': sessions,
    });
  } catch (e) {
    debugPrint('Pomodoro widget refresh error: $e');
  }
}

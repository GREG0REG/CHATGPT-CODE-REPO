import 'package:shared_preferences/shared_preferences.dart';

/// Dedicated settings service for the Pomodoro / Focus module.
/// Uses the same SharedPreferences keys as the legacy SettingsService
/// for overlapping settings so user preferences are preserved.
class FocusSettingsService {
  FocusSettingsService._();
  static final FocusSettingsService instance = FocusSettingsService._();

  // Legacy keys (keep in sync with SettingsService for backward compatibility)
  static const _kPomodoroPreset = 'pomodoro_preset';
  static const _kDailyGoalMinutes = 'daily_goal_minutes';
  static const _kDailyGoalPomodoros = 'daily_goal_pomodoros';
  static const _kAutoStartBreak = 'auto_start_break';
  static const _kTimerSoundEnabled = 'timer_sound_enabled';

  // New keys (Focus-module only)
  static const _kCustomFocusMinutes = 'focus_custom_focus_min';
  static const _kCustomShortBreakMinutes = 'focus_custom_short_break';
  static const _kCustomLongBreakMinutes = 'focus_custom_long_break';
  static const _kCustomSessionsBeforeLongBreak = 'focus_custom_sessions_before_long';
  static const _kLastSubjectId = 'focus_last_subject_id';
  static const _kLastSubjectName = 'focus_last_subject_name';
  static const _kSessionNotesEnabled = 'focus_session_notes_enabled';
  static const _kKeepScreenAwake = 'focus_keep_screen_awake';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  // ── Preset ──
  Future<String> getDefaultPreset() async {
    final p = await _prefs;
    return p.getString(_kPomodoroPreset) ?? 'classic';
  }

  Future<void> setDefaultPreset(String preset) async {
    final p = await _prefs;
    await p.setString(_kPomodoroPreset, preset);
  }

  // ── Custom Durations ──
  Future<int> getCustomFocusMinutes() async {
    final p = await _prefs;
    return p.getInt(_kCustomFocusMinutes) ?? 25;
  }

  Future<void> setCustomFocusMinutes(int v) async {
    final p = await _prefs;
    await p.setInt(_kCustomFocusMinutes, v);
  }

  Future<int> getCustomShortBreakMinutes() async {
    final p = await _prefs;
    return p.getInt(_kCustomShortBreakMinutes) ?? 5;
  }

  Future<void> setCustomShortBreakMinutes(int v) async {
    final p = await _prefs;
    await p.setInt(_kCustomShortBreakMinutes, v);
  }

  Future<int> getCustomLongBreakMinutes() async {
    final p = await _prefs;
    return p.getInt(_kCustomLongBreakMinutes) ?? 15;
  }

  Future<void> setCustomLongBreakMinutes(int v) async {
    final p = await _prefs;
    await p.setInt(_kCustomLongBreakMinutes, v);
  }

  Future<int> getCustomSessionsBeforeLongBreak() async {
    final p = await _prefs;
    return p.getInt(_kCustomSessionsBeforeLongBreak) ?? 4;
  }

  Future<void> setCustomSessionsBeforeLongBreak(int v) async {
    final p = await _prefs;
    await p.setInt(_kCustomSessionsBeforeLongBreak, v);
  }

  // ── Daily Goals ──
  Future<int> getDailyGoalMinutes() async {
    final p = await _prefs;
    return p.getInt(_kDailyGoalMinutes) ?? 120;
  }

  Future<void> setDailyGoalMinutes(int v) async {
    final p = await _prefs;
    await p.setInt(_kDailyGoalMinutes, v);
  }

  Future<int> getDailyGoalPomodoros() async {
    final p = await _prefs;
    return p.getInt(_kDailyGoalPomodoros) ?? 4;
  }

  Future<void> setDailyGoalPomodoros(int v) async {
    final p = await _prefs;
    await p.setInt(_kDailyGoalPomodoros, v);
  }

  // ── Toggles ──
  Future<bool> getAutoStartBreak() async {
    final p = await _prefs;
    return p.getBool(_kAutoStartBreak) ?? false;
  }

  Future<void> setAutoStartBreak(bool v) async {
    final p = await _prefs;
    await p.setBool(_kAutoStartBreak, v);
  }

  Future<bool> getTimerSoundEnabled() async {
    final p = await _prefs;
    return p.getBool(_kTimerSoundEnabled) ?? true;
  }

  Future<void> setTimerSoundEnabled(bool v) async {
    final p = await _prefs;
    await p.setBool(_kTimerSoundEnabled, v);
  }

  Future<bool> getSessionNotesEnabled() async {
    final p = await _prefs;
    return p.getBool(_kSessionNotesEnabled) ?? false;
  }

  Future<void> setSessionNotesEnabled(bool v) async {
    final p = await _prefs;
    await p.setBool(_kSessionNotesEnabled, v);
  }

  Future<bool> getKeepScreenAwake() async {
    final p = await _prefs;
    return p.getBool(_kKeepScreenAwake) ?? true;
  }

  Future<void> setKeepScreenAwake(bool v) async {
    final p = await _prefs;
    await p.setBool(_kKeepScreenAwake, v);
  }

  // ── Last Selected Subject ──
  Future<int?> getLastSubjectId() async {
    final p = await _prefs;
    final id = p.getInt(_kLastSubjectId);
    return (id == null || id < 0) ? null : id;
  }

  Future<void> setLastSubjectId(int? id) async {
    final p = await _prefs;
    if (id == null) {
      await p.remove(_kLastSubjectId);
    } else {
      await p.setInt(_kLastSubjectId, id);
    }
  }

  Future<String?> getLastSubjectName() async {
    final p = await _prefs;
    return p.getString(_kLastSubjectName);
  }

  Future<void> setLastSubjectName(String? name) async {
    final p = await _prefs;
    if (name == null) {
      await p.remove(_kLastSubjectName);
    } else {
      await p.setString(_kLastSubjectName, name);
    }
  }
}

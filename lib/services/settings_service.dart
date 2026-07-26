import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) await init();
    return _prefs!;
  }

  // ============================================
  // THEME SETTINGS
  // ============================================
  Future<bool> getDarkMode() async {
    final prefs = await _preferences;
    return prefs.getBool('darkMode') ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('darkMode', value);
  }

  Future<bool> getUseSystemTheme() async {
    final prefs = await _preferences;
    return prefs.getBool('useSystemTheme') ?? true;
  }

  Future<void> setUseSystemTheme(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('useSystemTheme', value);
  }

  // ============================================
  // NOTIFICATION SETTINGS
  // ============================================
  Future<bool> getNotificationsEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('notificationsEnabled') ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('notificationsEnabled', value);
  }

  Future<bool> getSoundEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('soundEnabled') ?? true;
  }

  Future<void> setSoundEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('soundEnabled', value);
  }

  // ============================================
  // STUDY GOAL SETTINGS (NEW - for stats screen)
  // ============================================
  Future<int> getDailyStudyGoal() async {
    final prefs = await _preferences;
    return prefs.getInt('dailyStudyGoal') ?? 120; // Default 120 min (2 hours)
  }

  Future<void> setDailyStudyGoal(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('dailyStudyGoal', minutes);
  }

  Future<int> getWeeklyStudyGoal() async {
    final prefs = await _preferences;
    return prefs.getInt('weeklyStudyGoal') ?? 600; // Default 600 min (10 hours)
  }

  Future<void> setWeeklyStudyGoal(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('weeklyStudyGoal', minutes);
  }

  Future<int> getPomodoroDuration() async {
    final prefs = await _preferences;
    return prefs.getInt('pomodoroDuration') ?? 25;
  }

  Future<void> setPomodoroDuration(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('pomodoroDuration', minutes);
  }

  Future<int> getShortBreakDuration() async {
    final prefs = await _preferences;
    return prefs.getInt('shortBreakDuration') ?? 5;
  }

  Future<void> setShortBreakDuration(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('shortBreakDuration', minutes);
  }

  Future<int> getLongBreakDuration() async {
    final prefs = await _preferences;
    return prefs.getInt('longBreakDuration') ?? 15;
  }

  Future<void> setLongBreakDuration(int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('longBreakDuration', minutes);
  }

  // ============================================
  // SUBJECT GOAL SETTINGS (NEW - for progress rings)
  // ============================================
  Future<int> getSubjectWeeklyGoal(String subject) async {
    final prefs = await _preferences;
    return prefs.getInt('subjectGoal_$subject') ?? 120; // Default 120 min/week
  }

  Future<void> setSubjectWeeklyGoal(String subject, int minutes) async {
    final prefs = await _preferences;
    await prefs.setInt('subjectGoal_$subject', minutes);
  }

  Future<void> removeSubjectGoal(String subject) async {
    final prefs = await _preferences;
    await prefs.remove('subjectGoal_$subject');
  }

  // ============================================
  // WIDGET SETTINGS
  // ============================================
  Future<bool> getHomeWidgetEnabled() async {
    final prefs = await _preferences;
    return prefs.getBool('homeWidgetEnabled') ?? true;
  }

  Future<void> setHomeWidgetEnabled(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('homeWidgetEnabled', value);
  }

  // ============================================
  // EXPORT/IMPORT SETTINGS
  // ============================================
  Future<bool> getAutoBackup() async {
    final prefs = await _preferences;
    return prefs.getBool('autoBackup') ?? false;
  }

  Future<void> setAutoBackup(bool value) async {
    final prefs = await _preferences;
    await prefs.setBool('autoBackup', value);
  }

  // ============================================
  // RESET ALL SETTINGS
  // ============================================
  Future<void> resetAll() async {
    final prefs = await _preferences;
    await prefs.clear();
  }
}

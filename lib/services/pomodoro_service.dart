import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database_helper.dart';
import '../models/study_session.dart';
import 'settings_service.dart';

/// Session presets for the Pomodoro timer.
class PomodoroPreset {
  final String name;
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;

  const PomodoroPreset({
    required this.name,
    required this.focusMinutes,
    required this.shortBreakMinutes,
    required this.longBreakMinutes,
    required this.sessionsBeforeLongBreak,
  });

  static const classic = PomodoroPreset(
    name: 'Classic',
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  static const deepWork = PomodoroPreset(
    name: 'Deep Work',
    focusMinutes: 45,
    shortBreakMinutes: 10,
    longBreakMinutes: 30,
    sessionsBeforeLongBreak: 3,
  );

  static const examCrunch = PomodoroPreset(
    name: 'Exam Crunch',
    focusMinutes: 60,
    shortBreakMinutes: 10,
    longBreakMinutes: 30,
    sessionsBeforeLongBreak: 2,
  );

  static const custom = PomodoroPreset(
    name: 'Custom',
    focusMinutes: 25,
    shortBreakMinutes: 5,
    longBreakMinutes: 15,
    sessionsBeforeLongBreak: 4,
  );

  static const List<PomodoroPreset> all = [classic, deepWork, examCrunch, custom];
}

enum PomodoroPhase { idle, focusing, shortBreak, longBreak, paused }

/// Central service for the Pomodoro focus timer.
/// Survives app restart via SharedPreferences and restores state automatically.
class PomodoroService extends ChangeNotifier {
  PomodoroService._();
  static final PomodoroService instance = PomodoroService._();

  // ── State ──
  PomodoroPhase _phase = PomodoroPhase.idle;
  PomodoroPhase? _phaseBeforePause;
  PomodoroPreset _preset = PomodoroPreset.classic;
  int _completedFocusSessions = 0;
  int _remainingSeconds = 0;
  DateTime? _endTime;

  String? _subjectTag;
  int? _linkedEventId;

  Timer? _tickTimer;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _notifInit = false;

  // ── ValueNotifiers for granular UI updates ──
  final ValueNotifier<PomodoroPhase> phaseNotifier = ValueNotifier(PomodoroPhase.idle);
  final ValueNotifier<int> remainingSecondsNotifier = ValueNotifier(0);
  final ValueNotifier<int> completedSessionsNotifier = ValueNotifier(0);

  // ── Getters ──
  PomodoroPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  PomodoroPreset get preset => _preset;
  int get completedFocusSessions => _completedFocusSessions;
  String? get subjectTag => _subjectTag;
  int? get linkedEventId => _linkedEventId;

  bool get isRunning =>
      _phase == PomodoroPhase.focusing ||
      _phase == PomodoroPhase.shortBreak ||
      _phase == PomodoroPhase.longBreak;

  String get formattedTime {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Init ──
  Future<void> init() async {
    await _initNotifications();
    await _restoreState();
  }

  Future<void> _initNotifications() async {
    if (_notifInit) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
    _notifInit = true;
  }

  // ── Persistence ──
  Future<void> _saveState() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pomodoro_phase', _phase.name);
    if (_phaseBeforePause != null) {
      await p.setString('pomodoro_phase_before_pause', _phaseBeforePause!.name);
    } else {
      await p.remove('pomodoro_phase_before_pause');
    }
    await p.setInt('pomodoro_end_time', _endTime?.millisecondsSinceEpoch ?? 0);
    await p.setInt('pomodoro_remaining_seconds', _remainingSeconds);
    await p.setInt('pomodoro_completed_sessions', _completedFocusSessions);
    await p.setString('pomodoro_preset_name', _preset.name);
    await p.setString('pomodoro_subject', _subjectTag ?? '');
    await p.setInt('pomodoro_event_id', _linkedEventId ?? -1);
  }

  Future<void> _clearSavedState() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('pomodoro_phase');
    await p.remove('pomodoro_phase_before_pause');
    await p.remove('pomodoro_end_time');
    await p.remove('pomodoro_remaining_seconds');
    await p.remove('pomodoro_completed_sessions');
    await p.remove('pomodoro_preset_name');
    await p.remove('pomodoro_subject');
    await p.remove('pomodoro_event_id');
  }

  Future<void> _restoreState() async {
    final p = await SharedPreferences.getInstance();
    final phaseName = p.getString('pomodoro_phase');
    final presetName = p.getString('pomodoro_preset_name');

    if (phaseName == null || presetName == null) return;

    _preset = PomodoroPreset.all.firstWhere(
      (c) => c.name == presetName,
      orElse: () => PomodoroPreset.classic,
    );

    _completedFocusSessions = p.getInt('pomodoro_completed_sessions') ?? 0;
    _subjectTag = p.getString('pomodoro_subject');
    if (_subjectTag?.isEmpty ?? false) _subjectTag = null;
    final eid = p.getInt('pomodoro_event_id');
    _linkedEventId = (eid == null || eid < 0) ? null : eid;

    final prev = p.getString('pomodoro_phase_before_pause');
    if (prev != null) {
      _phaseBeforePause = PomodoroPhase.values.firstWhere(
        (e) => e.name == prev,
        orElse: () => PomodoroPhase.focusing,
      );
    }

    _phase = PomodoroPhase.values.firstWhere(
      (e) => e.name == phaseName,
      orElse: () => PomodoroPhase.idle,
    );

    if (_phase == PomodoroPhase.paused) {
      _remainingSeconds = p.getInt('pomodoro_remaining_seconds') ?? 0;
      _syncNotifiers();
      notifyListeners();
      return;
    }

    final endMillis = p.getInt('pomodoro_end_time');
    if (endMillis == null || endMillis <= 0) {
      await _clearSavedState();
      return;
    }

    final end = DateTime.fromMillisecondsSinceEpoch(endMillis);
    final now = DateTime.now();

    if (end.isAfter(now)) {
      _endTime = end;
      _remainingSeconds = end.difference(now).inSeconds;
      _startTickTimer();
    } else {
      // Expired while app was closed — clear stale state.
      await _clearSavedState();
      return;
    }

    _syncNotifiers();
    notifyListeners();
  }

  void _syncNotifiers() {
    phaseNotifier.value = _phase;
    remainingSecondsNotifier.value = _remainingSeconds;
    completedSessionsNotifier.value = _completedFocusSessions;
  }

  // ── Timer Engine ──
  void _startTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_endTime == null) return;
      final now = DateTime.now();
      if (_endTime!.isAfter(now)) {
        _remainingSeconds = _endTime!.difference(now).inSeconds;
        remainingSecondsNotifier.value = _remainingSeconds;
        notifyListeners();
      } else {
        _onTimerComplete();
      }
    });
  }

  // ── Controls ──
  Future<void> start({
    required PomodoroPreset preset,
    String? subjectTag,
    int? eventId,
  }) async {
    _preset = preset;
    _subjectTag = subjectTag;
    _linkedEventId = eventId;
    _completedFocusSessions = 0;
    _phaseBeforePause = null;

    _transitionTo(PomodoroPhase.focusing, minutes: preset.focusMinutes);
    await _saveState();
  }

  Future<void> pause() async {
    if (!isRunning) return;
    _tickTimer?.cancel();
    _phaseBeforePause = _phase;
    _remainingSeconds = _endTime?.difference(DateTime.now()).inSeconds ?? 0;
    _phase = PomodoroPhase.paused;
    await _saveState();
    _syncNotifiers();
    notifyListeners();
  }

  Future<void> resume() async {
    if (_phase != PomodoroPhase.paused || _phaseBeforePause == null) return;
    _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds.clamp(1, 99999)));
    _phase = _phaseBeforePause!;
    _phaseBeforePause = null;
    _startTickTimer();
    await _saveState();
    _syncNotifiers();
    notifyListeners();
  }

  Future<void> stop() async {
    _tickTimer?.cancel();
    _phase = PomodoroPhase.idle;
    _phaseBeforePause = null;
    _endTime = null;
    _remainingSeconds = 0;
    _completedFocusSessions = 0;
    await _clearSavedState();
    await _notifications.cancel(9999);
    _syncNotifiers();
    notifyListeners();
  }

  Future<void> skipBreak() async {
    if (_phase != PomodoroPhase.shortBreak && _phase != PomodoroPhase.longBreak) return;
    _tickTimer?.cancel();
    _transitionTo(PomodoroPhase.focusing, minutes: _preset.focusMinutes);
    await _saveState();
  }

  void _transitionTo(PomodoroPhase newPhase, {required int minutes}) {
    _phase = newPhase;
    _endTime = DateTime.now().add(Duration(minutes: minutes));
    _remainingSeconds = minutes * 60;
    _startTickTimer();
    _syncNotifiers();
    notifyListeners();
  }

  // ── Completion Handler ──
  Future<void> _onTimerComplete() async {
    _tickTimer?.cancel();

    if (_phase == PomodoroPhase.focusing) {
      _completedFocusSessions++;
      await _logSession(_preset.focusMinutes);
      await _notify(
        'Focus Complete! 🎉',
        'Take a break. Great job${subjectTag != null ? ' on $subjectTag' : ''}.',
      );

      if (_completedFocusSessions % _preset.sessionsBeforeLongBreak == 0) {
        _transitionTo(PomodoroPhase.longBreak, minutes: _preset.longBreakMinutes);
      } else {
        _transitionTo(PomodoroPhase.shortBreak, minutes: _preset.shortBreakMinutes);
      }
    } else if (_phase == PomodoroPhase.shortBreak || _phase == PomodoroPhase.longBreak) {
      await _notify(
        'Break Over!',
        'Time to focus${subjectTag != null ? ' on $subjectTag' : ''}.',
      );
      _transitionTo(PomodoroPhase.focusing, minutes: _preset.focusMinutes);
    }

    await _saveState();
  }

  // ── Database & Goals ──
  Future<void> _logSession(int minutes) async {
    final session = StudySession(
      eventId: _linkedEventId,
      subjectTag: _subjectTag,
      durationMinutes: minutes,
      completedAtMillis: DateTime.now().millisecondsSinceEpoch,
      sessionType: _preset.name.toLowerCase().replaceAll(' ', '_'),
    );
    await DatabaseHelper.instance.insertStudySession(session);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    await DatabaseHelper.instance.addAchievedMinutes(startOfDay, minutes);
    await DatabaseHelper.instance.addAchievedPomodoro(startOfDay);
  }

  // ── Notifications ──
  Future<void> _notify(String title, String body) async {
    // Respect existing Quiet Hours setting
    final quiet = await SettingsService.instance.isInQuietHours(DateTime.now());
    if (quiet) return;

    const androidDetails = AndroidNotificationDetails(
      'pomodoro_channel',
      'Pomodoro Timer',
      channelDescription: 'Focus timer alerts',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    await _notifications.show(
      9999,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    phaseNotifier.dispose();
    remainingSecondsNotifier.dispose();
    completedSessionsNotifier.dispose();
    super.dispose();
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database_helper.dart';
import '../models/study_session.dart';
import 'settings_service.dart';
import 'focus_settings_service.dart';
import 'widget_service.dart';

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

  // Break-pending state (when auto-start break is OFF)
  bool _breakPending = false;
  int _pendingBreakMinutes = 0;

  // Session note prompt
  int? _pendingSessionNoteId;

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
  bool get isBreakPending => _breakPending;
  int? get pendingSessionNoteId => _pendingSessionNoteId;

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

  // ── Custom Preset Resolver ──
  Future<PomodoroPreset> _resolvePreset(PomodoroPreset preset) async {
    if (preset.name != 'Custom') return preset;
    final fs = FocusSettingsService.instance;
    return PomodoroPreset(
      name: 'Custom',
      focusMinutes: await fs.getCustomFocusMinutes(),
      shortBreakMinutes: await fs.getCustomShortBreakMinutes(),
      longBreakMinutes: await fs.getCustomLongBreakMinutes(),
      sessionsBeforeLongBreak: await fs.getCustomSessionsBeforeLongBreak(),
    );
  }

  // ── Widget Sync ──
  /// Writes current timer state to SharedPreferences and triggers a native
  /// widget update so the home-screen widget shows live data.
  Future<void> _syncWidgetState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String subject = _subjectTag ?? 'Ready to Focus';
      String timerText = formattedTime;
      String status;

      switch (_phase) {
        case PomodoroPhase.focusing:
          status = 'Focus';
          break;
        case PomodoroPhase.shortBreak:
          status = 'Short Break';
          break;
        case PomodoroPhase.longBreak:
          status = 'Long Break';
          break;
        case PomodoroPhase.paused:
          status = 'Paused';
          break;
        case PomodoroPhase.idle:
          status = 'Ready to Focus';
          timerText = 'Tap to start';
          break;
      }

      await prefs.setString('pomodoro_subject', subject);
      await prefs.setString('pomodoro_timer_text', timerText);
      await prefs.setString('pomodoro_status', status);

      await WidgetService.refreshPomodoroWidget();
    } catch (e) {
      debugPrint('Pomodoro widget sync error: $e');
    }
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

    // New fields
    await p.setBool('pomodoro_break_pending', _breakPending);
    await p.setInt('pomodoro_pending_break_minutes', _pendingBreakMinutes);
    await p.setInt('pomodoro_pending_note_id', _pendingSessionNoteId ?? -1);
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

    await p.remove('pomodoro_break_pending');
    await p.remove('pomodoro_pending_break_minutes');
    await p.remove('pomodoro_pending_note_id');
  }

  Future<void> _restoreState() async {
    final p = await SharedPreferences.getInstance();
    final phaseName = p.getString('pomodoro_phase');
    final presetName = p.getString('pomodoro_preset_name');

    if (phaseName == null || presetName == null) {
      await _syncWidgetState();
      return;
    }

    _preset = PomodoroPreset.all.firstWhere(
      (c) => c.name == presetName,
      orElse: () => PomodoroPreset.classic,
    );
    _preset = await _resolvePreset(_preset);

    _completedFocusSessions = p.getInt('pomodoro_completed_sessions') ?? 0;
    _subjectTag = p.getString('pomodoro_subject');
    if (_subjectTag?.isEmpty ?? false) _subjectTag = null;
    final eid = p.getInt('pomodoro_event_id');
    _linkedEventId = (eid == null || eid < 0) ? null : eid;

    // Restore break-pending state
    _breakPending = p.getBool('pomodoro_break_pending') ?? false;
    _pendingBreakMinutes = p.getInt('pomodoro_pending_break_minutes') ?? 0;
    final noteId = p.getInt('pomodoro_pending_note_id');
    _pendingSessionNoteId = (noteId == null || noteId < 0) ? null : noteId;

    // Restore last subject from FocusSettingsService if none saved
    if (_subjectTag == null || _subjectTag!.isEmpty) {
      final lastId = await FocusSettingsService.instance.getLastSubjectId();
      if (lastId != null) {
        final subj = await DatabaseHelper.instance.getStudySubject(lastId);
        if (subj != null) _subjectTag = subj.name;
      }
      if (_subjectTag == null) {
        final lastName = await FocusSettingsService.instance.getLastSubjectName();
        if (lastName != null && lastName.isNotEmpty) _subjectTag = lastName;
      }
    }

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
      await _syncWidgetState();
      return;
    }

    if (_phase == PomodoroPhase.idle) {
      _remainingSeconds = 0;
      _syncNotifiers();
      notifyListeners();
      await _syncWidgetState();
      return;
    }

    final endMillis = p.getInt('pomodoro_end_time');
    if (endMillis == null || endMillis <= 0) {
      await _clearSavedState();
      await _syncWidgetState();
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
      await _syncWidgetState();
      return;
    }

    _syncNotifiers();
    notifyListeners();
    await _syncWidgetState();
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
        _syncWidgetState();
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
    _preset = await _resolvePreset(preset);
    _subjectTag = subjectTag;
    _linkedEventId = eventId;
    _completedFocusSessions = 0;
    _phaseBeforePause = null;
    _breakPending = false;
    _pendingBreakMinutes = 0;
    _pendingSessionNoteId = null;

    // Persist last subject for next launch
    if (subjectTag != null && subjectTag.isNotEmpty) {
      await FocusSettingsService.instance.setLastSubjectName(subjectTag);
      final subjects = await DatabaseHelper.instance.getAllStudySubjects();
      final match = subjects.where((s) => s.name == subjectTag).firstOrNull;
      if (match != null) {
        await FocusSettingsService.instance.setLastSubjectId(match.id);
      }
    }

    _transitionTo(PomodoroPhase.focusing, minutes: _preset.focusMinutes);
    await _saveState();
  }

  Future<void> startBreak() async {
    if (!_breakPending) return;
    final isLongBreak = _pendingBreakMinutes == _preset.longBreakMinutes;
    _breakPending = false;
    _transitionTo(
      isLongBreak ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak,
      minutes: _pendingBreakMinutes,
    );
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
    await _syncWidgetState();
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
    await _syncWidgetState();
  }

  Future<void> stop() async {
    _tickTimer?.cancel();
    _phase = PomodoroPhase.idle;
    _phaseBeforePause = null;
    _endTime = null;
    _remainingSeconds = 0;
    _completedFocusSessions = 0;
    _breakPending = false;
    _pendingBreakMinutes = 0;
    _pendingSessionNoteId = null;
    await _clearSavedState();
    await _notifications.cancel(9999);
    _syncNotifiers();
    notifyListeners();
    await _syncWidgetState();
  }

  Future<void> skipBreak() async {
    if (_phase != PomodoroPhase.shortBreak && _phase != PomodoroPhase.longBreak) return;
    _tickTimer?.cancel();
    _transitionTo(PomodoroPhase.focusing, minutes: _preset.focusMinutes);
    await _saveState();
  }

  void dismissSessionNote() {
    _pendingSessionNoteId = null;
    notifyListeners();
  }

  void _transitionTo(PomodoroPhase newPhase, {required int minutes}) {
    _phase = newPhase;
    _endTime = DateTime.now().add(Duration(minutes: minutes));
    _remainingSeconds = minutes * 60;
    _startTickTimer();
    _syncNotifiers();
    notifyListeners();
    _syncWidgetState();
  }

  // ── Completion Handler ──
  Future<void> _onTimerComplete() async {
    _tickTimer?.cancel();

    if (_phase == PomodoroPhase.focusing) {
      _completedFocusSessions++;
      final sessionId = await _logSession(_preset.focusMinutes);

      final autoStart = await FocusSettingsService.instance.getAutoStartBreak();
      final isLongBreak = _completedFocusSessions % _preset.sessionsBeforeLongBreak == 0;
      final breakMinutes = isLongBreak ? _preset.longBreakMinutes : _preset.shortBreakMinutes;

      if (autoStart) {
        await _notify(
          isLongBreak ? 'Long Break! ☕' : 'Short Break! 🍵',
          'Take a ${breakMinutes}-minute break.',
        );
        _transitionTo(
          isLongBreak ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak,
          minutes: breakMinutes,
        );
      } else {
        _phase = PomodoroPhase.idle;
        _breakPending = true;
        _pendingBreakMinutes = breakMinutes;
        _endTime = null;
        _remainingSeconds = 0;
        await _notify(
          'Focus Complete! 🎉',
          'Great job${subjectTag != null ? ' on $subjectTag' : ''}. Open the app to start your break.',
        );
        await _saveState();
        _syncNotifiers();
        notifyListeners();
        await _syncWidgetState();
        return;
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
  Future<int> _logSession(int minutes) async {
    final session = StudySession(
      eventId: _linkedEventId,
      subjectTag: _subjectTag,
      durationMinutes: minutes,
      completedAtMillis: DateTime.now().millisecondsSinceEpoch,
      sessionType: _preset.name.toLowerCase().replaceAll(' ', '_'),
    );
    final id = await DatabaseHelper.instance.insertStudySession(session);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    await DatabaseHelper.instance.addAchievedMinutes(startOfDay, minutes);
    await DatabaseHelper.instance.addAchievedPomodoro(startOfDay);

    // Update subject total focus time
    if (_subjectTag != null && _subjectTag!.isNotEmpty) {
      final subjects = await DatabaseHelper.instance.getAllStudySubjects();
      final match = subjects.where((s) => s.name == _subjectTag).firstOrNull;
      if (match != null && match.id != null) {
        await DatabaseHelper.instance.addSubjectFocusMinutes(match.id!, minutes);
      }
    }

    // Session notes prompt
    if (await FocusSettingsService.instance.getSessionNotesEnabled()) {
      _pendingSessionNoteId = id;
    }

    return id;
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

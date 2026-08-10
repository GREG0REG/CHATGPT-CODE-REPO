// lib/screens/alarm_ring_screen.dart
// Full-screen alarm UI that appears when a study alarm fires
// Even if app is killed, Android launches this via fullScreenIntent

import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/event.dart';
import '../database_helper.dart';

class AlarmRingScreen extends StatefulWidget {
  final Map<String, String>? payload;

  const AlarmRingScreen({super.key, this.payload});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  bool _isSnoozed = false;

  String get _title => widget.payload?['eventTitle'] ?? 'Study Alarm';
  String get _subject => widget.payload?['subjectName'] ?? '';
  String get _reminderType => widget.payload?['reminderType'] ?? 'study_alarm';

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen on

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    // Cancel the notification
    final eventIdStr = widget.payload?['eventId'];
    if (eventIdStr != null) {
      final eventId = int.tryParse(eventIdStr);
      if (eventId != null) {
        await AwesomeNotifications().cancel(eventId);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _snoozeAlarm() async {
    if (_isSnoozed) return;
    setState(() => _isSnoozed = true);

    final snoozeTime = DateTime.now().add(const Duration(minutes: 10));

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 900000 + DateTime.now().millisecond,
        channelKey: 'study_alarms',
        title: '⏳ (Snoozed) $_title',
        body: 'Snoozed until ${_formatTime(snoozeTime)}',
        payload: widget.payload,
        fullScreenIntent: true,
        wakeUpScreen: true,
        criticalAlert: true,
      ),
      schedule: NotificationCalendar.fromDate(
        date: snoozeTime,
        preciseAlarm: true,
        allowWhileIdle: true,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snoozed for 10 minutes'),
          duration: Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _markStudyDone() async {
    // Log a study session
    final eventIdStr = widget.payload?['eventId'];
    if (eventIdStr != null) {
      final eventId = int.tryParse(eventIdStr);
      if (eventId != null) {
        final event = await DatabaseHelper.instance.getEvent(eventId);
        if (event != null) {
          await DatabaseHelper.instance.insertStudySessionFromMap({
            'eventId': eventId,
            'subjectTag': event.subjectTag,
            'durationMinutes': 25, // Default pomodoro
            'completedAtMillis': DateTime.now().millisecondsSinceEpoch,
            'sessionType': 'alarm_session',
            'notes': 'Started from alarm: $_title',
            'topicTag': event.subjectTag,
          });
        }
      }
    }
    await _stopAlarm();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm, color: Colors.red, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'ALARM',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Animated alarm icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.15),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.5 + (_pulseController.value * 0.5)),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.alarm,
                      size: 64,
                      color: Colors.red,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Title
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (_subject.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _subject,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 18,
                ),
              ),
            ],

            const SizedBox(height: 8),

            Text(
              'Time to study!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),

            const Spacer(flex: 2),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // Stop Alarm button (big red)
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _stopAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stop_circle, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'STOP ALARM',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Row: Snooze + Start Studying
                  Row(
                    children: [
                      // Snooze button
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isSnoozed ? null : _snoozeAlarm,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isSnoozed ? Icons.check : Icons.snooze,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isSnoozed ? 'SNOOZED' : 'SNOOZE 10M',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Start Studying button
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _markStudyDone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow, size: 20),
                                SizedBox(width: 4),
                                Text(
                                  'START',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

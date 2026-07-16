import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/custom_reminder.dart';
import '../models/event.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';

class AddEditEventScreen extends StatefulWidget {
  final Event? existing;

  const AddEditEventScreen({super.key, this.existing});

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _deadlineTime;
  DateTime? _deadlineDate;
  bool _use24Hour = true;
  bool _isSaving = false;

  // SESSION 5
  RecurrenceType _recurrence = RecurrenceType.none;

  // SESSION 4
  List<CustomReminder> _customReminders = [];

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadExistingReminders();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _notesController.text = e.notes ?? '';
      _date = DateTime.fromMillisecondsSinceEpoch(e.dateMillis);
      _recurrence = e.recurrence;
      if (e.startTimeMillis != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.startTimeMillis!);
        _startTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
      if (e.deadlineMillis != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(e.deadlineMillis!);
        _deadlineDate = DateTime(dt.year, dt.month, dt.day);
        _deadlineTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }
  }

  Future<void> _loadSettings() async {
    final use24 = await SettingsService.instance.getUse24HourFormat();
    if (mounted) setState(() => _use24Hour = use24);
  }

  Future<void> _loadExistingReminders() async {
    if (widget.existing?.id != null) {
      final reminders = await DatabaseHelper.instance
          .getCustomRemindersForEvent(widget.existing!.id!);
      if (mounted) setState(() => _customReminders = reminders);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: _use24Hour),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadlineDate = picked);
  }

  Future<void> _pickDeadlineTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deadlineTime ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: _use24Hour),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadlineTime = picked);
  }

  String _formatTime(TimeOfDay t) {
    final hour = _use24Hour
        ? t.hour.toString().padLeft(2, '0')
        : (t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod).toString();
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = _use24Hour ? '' : (t.period == DayPeriod.am ? ' AM' : ' PM');
    return '$hour:$minute$suffix';
  }

  int? _combine(DateTime date, TimeOfDay? time) {
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute)
        .millisecondsSinceEpoch;
  }

  // ============================================
  // SESSION 4: Custom reminder management
  // ============================================
  Future<void> _addCustomReminder() async {
    final defaultMinutes = await SettingsService.instance.getDefaultReminderMinutes();
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _ReminderDialog(defaultMinutes: defaultMinutes),
    );
    if (result == null) return;

    final reminder = CustomReminder(
      eventId: widget.existing?.id ?? 0,
      minutesBefore: result['minutes'] as int,
      type: result['alarm'] == true ? 'alarm' : 'notification',
      soundUri: result['sound'] as String?,
    );

    if (_isEditing && widget.existing?.id != null) {
      final id = await DatabaseHelper.instance.insertCustomReminder(
        reminder.copyWith(eventId: widget.existing!.id!),
      );
      setState(() {
        _customReminders.add(reminder.copyWith(id: id, eventId: widget.existing!.id!));
      });
    } else {
      setState(() => _customReminders.add(reminder));
    }
  }

  Future<void> _pickReminderSound(CustomReminder reminder) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result?.files.single.path == null) return;

    final soundPath = result!.files.single.path;
    final updated = reminder.copyWith(soundUri: soundPath);

    if (reminder.id != null) {
      await DatabaseHelper.instance.updateCustomReminder(updated);
    }
    setState(() {
      final idx = _customReminders.indexWhere((r) => r.id == reminder.id);
      if (idx >= 0) _customReminders[idx] = updated;
    });
  }

  Future<void> _deleteReminder(CustomReminder reminder) async {
    if (reminder.id != null) {
      await DatabaseHelper.instance.deleteCustomReminder(reminder.id!);
    }
    setState(() => _customReminders.removeWhere((r) => r.id == reminder.id));
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final startMillis = _combine(_date, _startTime);
      final deadlineMillis = _deadlineTime == null
          ? null
          : _combine(_deadlineDate ?? _date, _deadlineTime);

      final dateOnly = DateTime(_date.year, _date.month, _date.day);

      final event = Event(
        id: widget.existing?.id,
        title: _titleController.text.trim(),
        dateMillis: dateOnly.millisecondsSinceEpoch,
        startTimeMillis: startMillis,
        deadlineMillis: deadlineMillis,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        recurrence: _recurrence,
      );

      int id;
      if (_isEditing) {
        await DatabaseHelper.instance.updateEvent(event);
        id = event.id!;
      } else {
        id = await DatabaseHelper.instance.insertEvent(event);
      }

      final savedEvent = event.copyWith(id: id);

      // Save custom reminders for new events
      if (!_isEditing) {
        for (final r in _customReminders) {
          await DatabaseHelper.instance.insertCustomReminder(
            r.copyWith(eventId: id),
          );
        }
      }

      try {
        await NotificationService.instance.scheduleForEvent(savedEvent);
      } catch (e) {
        debugPrint('Notification error: $e');
      }

      await WidgetService.refreshWidget();
      HapticFeedback.lightImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: widget.existing != null
              ? 'event_title_${widget.existing!.id}'
              : 'event_title_new',
          child: Material(
            color: Colors.transparent,
            child: Text(_isEditing ? 'Edit Event' : 'Add Event'),
          ),
        ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: _save,
                ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Hero(
              tag: widget.existing != null
                  ? 'event_avatar_${widget.existing!.id}'
                  : 'event_avatar_new',
              child: Material(
                color: Colors.transparent,
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Event Date'),
              subtitle: Text('${_date.month}/${_date.day}/${_date.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const Divider(),

            // ============================================
            // SESSION 5: Recurrence
            // ============================================
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Text(
                'Recurrence',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            SegmentedButton<RecurrenceType>(
              segments: const [
                ButtonSegment(value: RecurrenceType.none, label: Text('None')),
                ButtonSegment(value: RecurrenceType.daily, label: Text('Daily')),
                ButtonSegment(value: RecurrenceType.weekly, label: Text('Weekly')),
                ButtonSegment(value: RecurrenceType.monthly, label: Text('Monthly')),
                ButtonSegment(value: RecurrenceType.yearly, label: Text('Yearly')),
              ],
              selected: {_recurrence},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) {
                  setState(() => _recurrence = selected.first);
                }
              },
            ),
            const Divider(),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set start time'),
              value: _startTime != null,
              onChanged: (v) => setState(() => _startTime = v ? TimeOfDay.now() : null),
            ),
            if (_startTime != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start time'),
                subtitle: Text(_formatTime(_startTime!)),
                trailing: const Icon(Icons.access_time),
                onTap: _pickStartTime,
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set deadline / end time'),
              value: _deadlineTime != null,
              onChanged: (v) => setState(() {
                if (v) {
                  _deadlineTime = TimeOfDay.now();
                  _deadlineDate ??= _date;
                } else {
                  _deadlineTime = null;
                  _deadlineDate = null;
                }
              }),
            ),
            if (_deadlineTime != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deadline date'),
                subtitle: Text(
                  '${(_deadlineDate ?? _date).month}/${(_deadlineDate ?? _date).day}/${(_deadlineDate ?? _date).year}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDeadlineDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deadline time'),
                subtitle: Text(_formatTime(_deadlineTime!)),
                trailing: const Icon(Icons.access_time),
                onTap: _pickDeadlineTime,
              ),
            ],
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // ============================================
            // SESSION 4: Custom reminders
            // ============================================
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Text(
                'Custom Reminders',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            ..._customReminders.map((r) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  r.isAlarm ? Icons.alarm : Icons.notifications,
                  color: r.isAlarm ? Colors.red : null,
                ),
                title: Text('${r.minutesBefore} minutes before'),
                subtitle: r.soundUri != null ? const Text('Custom sound') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (r.soundUri == null)
                      IconButton(
                        icon: const Icon(Icons.music_note, size: 20),
                        onPressed: () => _pickReminderSound(r),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _deleteReminder(r),
                    ),
                  ],
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addCustomReminder,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Add reminder'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Saving...'),
                      ],
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Event'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// SESSION 4: Reminder dialog with manual input
// ============================================
class _ReminderDialog extends StatefulWidget {
  final int defaultMinutes;
  const _ReminderDialog({required this.defaultMinutes});

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late int _hours;
  late int _minutes;
  bool _isAlarm = false;

  @override
  void initState() {
    super.initState();
    _hours = widget.defaultMinutes ~/ 60;
    _minutes = widget.defaultMinutes % 60;
  }

  int get _totalMinutes => _hours * 60 + _minutes;

  void _setPreset(int hours, int minutes) {
    setState(() {
      _hours = hours;
      _minutes = minutes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hours and Minutes input
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _hours.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _hours = int.tryParse(v) ?? 0;
                      if (_hours < 0) _hours = 0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _minutes.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _minutes = int.tryParse(v) ?? 0;
                      if (_minutes < 0) _minutes = 0;
                      if (_minutes > 59) _minutes = 59;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Total display
          Center(
            child: Text(
              '$_totalMinutes minutes before event',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Quick presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _PresetChip(label: '5m', onTap: () => _setPreset(0, 5)),
              _PresetChip(label: '15m', onTap: () => _setPreset(0, 15)),
              _PresetChip(label: '30m', onTap: () => _setPreset(0, 30)),
              _PresetChip(label: '1h', onTap: () => _setPreset(1, 0)),
              _PresetChip(label: '2h', onTap: () => _setPreset(2, 0)),
              _PresetChip(label: '1d', onTap: () => _setPreset(24, 0)),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Full-screen alarm'),
            value: _isAlarm,
            onChanged: (v) => setState(() => _isAlarm = v),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'minutes': _totalMinutes,
            'alarm': _isAlarm,
            'sound': null,
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
    );
  }
}

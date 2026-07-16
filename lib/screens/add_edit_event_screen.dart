import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/database_helper.dart';
import '../models/event.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/widget_service.dart';
import '../models/custom_reminder.dart';

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

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _notesController.text = e.notes ?? '';
      _date = DateTime.fromMillisecondsSinceEpoch(e.dateMillis);
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
      );

      int id;
      if (_isEditing) {
        await DatabaseHelper.instance.updateEvent(event);
        id = event.id!;
      } else {
        id = await DatabaseHelper.instance.insertEvent(event);
      }

      final savedEvent = event.copyWith(id: id);

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
        // SESSION 2: Hero animation on title
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
            // SESSION 2: Hero animation on title field
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

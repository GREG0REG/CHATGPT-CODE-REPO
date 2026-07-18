import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database_helper.dart';
import '../models/custom_reminder.dart';
import '../models/event.dart';
import '../models/subtask.dart';
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
  final _subjectController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _deadlineTime;
  DateTime? _deadlineDate;
  bool _use24Hour = true;
  bool _isSaving = false;

  RecurrenceType _recurrence = RecurrenceType.none;
  int _recurrenceInterval = 1;
  bool _yearlyUseSpecificDates = false;
  List<YearlySpecificDate> _yearlySpecificDates = [];

  List<CustomReminder> _customReminders = [];

  // Student Study Pack
  String? _iconName;
  int _priority = 2;
  bool _isCompleted = false;

  // Subtasks
  List<Subtask> _subtasks = [];
  final Set<int> _originalSubtaskIds = {};

  bool get _isEditing => widget.existing != null && widget.existing!.id != null && widget.existing!.id! > 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadExistingReminders();
    _loadExistingSubtasks();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _notesController.text = e.notes ?? '';
      _date = DateTime.fromMillisecondsSinceEpoch(e.dateMillis);
      _recurrence = e.recurrence;
      _recurrenceInterval = e.recurrenceInterval;
      _yearlyUseSpecificDates = e.yearlyUseSpecificDates;
      _yearlySpecificDates = List.from(e.yearlySpecificDates);
      _iconName = e.iconName;
      _priority = e.priority;
      _subjectController.text = e.subjectTag ?? '';
      _isCompleted = e.isCompleted;
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
    if (widget.existing?.id != null && widget.existing!.id! > 0) {
      final reminders = await DatabaseHelper.instance.getCustomRemindersForEvent(widget.existing!.id!);
      if (mounted) setState(() => _customReminders = reminders);
    }
  }

  Future<void> _loadExistingSubtasks() async {
    if (widget.existing?.id != null && widget.existing!.id! > 0) {
      final list = await DatabaseHelper.instance.getSubtasksForEvent(widget.existing!.id!);
      if (mounted) {
        setState(() {
          _subtasks = list;
          _originalSubtaskIds.addAll(list.where((s) => s.id != null).map((s) => s.id!));
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _startTime ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: _use24Hour),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _deadlineDate ?? _date,
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadlineDate = picked);
  }

  Future<void> _pickDeadlineTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _deadlineTime ?? TimeOfDay.now(),
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
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).millisecondsSinceEpoch;
  }

  String _getIntervalLabel() {
    switch (_recurrence) {
      case RecurrenceType.daily: return _recurrenceInterval == 1 ? 'day' : 'days';
      case RecurrenceType.weekly: return _recurrenceInterval == 1 ? 'week' : 'weeks';
      case RecurrenceType.monthly: return _recurrenceInterval == 1 ? 'month' : 'months';
      case RecurrenceType.yearly: return _recurrenceInterval == 1 ? 'year' : 'years';
      case RecurrenceType.none: return '';
    }
  }

  String _getRecurrenceSummary() {
    if (_recurrence == RecurrenceType.none) return 'Does not repeat';
    if (_recurrence == RecurrenceType.yearly && _yearlyUseSpecificDates) {
      if (_yearlySpecificDates.isEmpty) return 'Yearly on specific dates (none selected)';
      final dates = _yearlySpecificDates.map((d) => '${d.month}/${d.day}').join(', ');
      return 'Yearly on: $dates';
    }
    final interval = _recurrenceInterval == 1 ? '' : ' $_recurrenceInterval';
    return 'Repeats every$interval ${_getIntervalLabel()}';
  }

  Future<void> _pickSpecificDates() async {
    final result = await showDialog<List<YearlySpecificDate>>(
      context: context,
      builder: (ctx) => _SpecificDatesPickerDialog(
        initialDates: _yearlySpecificDates,
        baseStartTime: _startTime,
        baseDeadlineTime: _deadlineTime,
      ),
    );
    if (result != null) setState(() => _yearlySpecificDates = result);
  }

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
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: false);
    if (result?.files.single.path == null) return;
    final soundPath = result!.files.single.path;
    final updated = reminder.copyWith(soundUri: soundPath);
    if (reminder.id != null) await DatabaseHelper.instance.updateCustomReminder(updated);
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
        id: _isEditing ? widget.existing!.id : null,
        title: _titleController.text.trim(),
        dateMillis: dateOnly.millisecondsSinceEpoch,
        startTimeMillis: startMillis,
        deadlineMillis: deadlineMillis,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        recurrence: _recurrence,
        recurrenceInterval: _recurrenceInterval.clamp(1, 50),
        yearlyUseSpecificDates: _recurrence == RecurrenceType.yearly && _yearlyUseSpecificDates,
        yearlySpecificDatesJson: _yearlySpecificDates.isNotEmpty
            ? jsonEncode(_yearlySpecificDates.map((d) => d.toJson()).toList())
            : null,
        iconName: _iconName,
        priority: _priority,
        subjectTag: _subjectController.text.trim().isEmpty ? null : _subjectController.text.trim(),
        isCompleted: _isCompleted,
      );

      int id;
      if (_isEditing) {
        await DatabaseHelper.instance.updateEvent(event);
        id = event.id!;
      } else {
        id = await DatabaseHelper.instance.insertEvent(event);
      }

      final savedEvent = event.copyWith(id: id);

      if (!_isEditing) {
        for (final r in _customReminders) {
          await DatabaseHelper.instance.insertCustomReminder(r.copyWith(eventId: id));
        }
      }

      // Sync subtasks
      final currentSubtaskIds = _subtasks.where((s) => s.id != null).map((s) => s.id!).toSet();
      for (final oldId in _originalSubtaskIds) {
        if (!currentSubtaskIds.contains(oldId)) {
          await DatabaseHelper.instance.deleteSubtask(oldId);
        }
      }
      for (var i = 0; i < _subtasks.length; i++) {
        final st = _subtasks[i].copyWith(eventId: id, orderIndex: i);
        if (st.title.trim().isEmpty) continue;
        if (st.id == null) {
          await DatabaseHelper.instance.insertSubtask(st);
        } else {
          await DatabaseHelper.instance.updateSubtask(st);
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
          const SnackBar(content: Text('Event saved!'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
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

  Widget _buildIconPicker() {
    final icons = EventIcons.icons.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Text('Icon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: icons.map((entry) {
            final isSelected = _iconName == entry.key;
            return InkWell(
              onTap: () => setState(() => _iconName = entry.key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                      : null,
                ),
                child: Icon(
                  entry.value,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Low')),
            ButtonSegment(value: 2, label: Text('Normal')),
            ButtonSegment(value: 3, label: Text('High')),
            ButtonSegment(value: 4, label: Text('Urgent')),
          ],
          selected: {_priority},
          onSelectionChanged: (selected) {
            if (selected.isNotEmpty) setState(() => _priority = selected.first);
          },
        ),
      ],
    );
  }

  Widget _buildSubtaskEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
          child: Text('Subtasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        ..._subtasks.asMap().entries.map((entry) {
          final idx = entry.key;
          final st = entry.value;
          return Row(
            children: [
              Checkbox(
                value: st.isCompleted,
                onChanged: (v) => setState(() => _subtasks[idx] = st.copyWith(isCompleted: v!)),
              ),
              Expanded(
                child: TextFormField(
                  initialValue: st.title,
                  decoration: const InputDecoration(
                    hintText: 'Subtask',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => _subtasks[idx] = st.copyWith(title: v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => setState(() => _subtasks.removeAt(idx)),
              ),
            ],
          );
        }),
        OutlinedButton.icon(
          onPressed: () => setState(() => _subtasks.add(Subtask(
            eventId: widget.existing?.id ?? 0,
            title: '',
            orderIndex: _subtasks.length,
          ))),
          icon: const Icon(Icons.add),
          label: const Text('Add subtask'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: _isEditing ? 'event_title_${widget.existing!.id}' : 'event_title_new',
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
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Hero(
              tag: _isEditing ? 'event_avatar_${widget.existing!.id}' : 'event_avatar_new',
              child: Material(
                color: Colors.transparent,
                child: TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject (e.g. Math, Physics, History)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bookmark_outline),
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

            const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Text('Recurrence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                  setState(() {
                    _recurrence = selected.first;
                    if (_recurrence != RecurrenceType.yearly) _yearlyUseSpecificDates = false;
                  });
                }
              },
            ),

            if (_recurrence != RecurrenceType.none) ...[
              const SizedBox(height: 16),
              if (_recurrence == RecurrenceType.yearly) ...[
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Every X years'),
                        selected: !_yearlyUseSpecificDates,
                        onSelected: (v) => setState(() => _yearlyUseSpecificDates = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Specific dates'),
                        selected: _yearlyUseSpecificDates,
                        onSelected: (v) => setState(() => _yearlyUseSpecificDates = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              if (!(_recurrence == RecurrenceType.yearly && _yearlyUseSpecificDates)) ...[
                Row(
                  children: [
                    const Text('Repeat every: ', style: TextStyle(fontSize: 14)),
                    Text(
                      '$_recurrenceInterval',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(_getIntervalLabel(), style: const TextStyle(fontSize: 14)),
                  ],
                ),
                Slider(
                  value: _recurrenceInterval.toDouble(),
                  min: 1, max: 50, divisions: 49,
                  label: '$_recurrenceInterval',
                  onChanged: (v) => setState(() => _recurrenceInterval = v.round()),
                ),
              ],

              if (_recurrence == RecurrenceType.yearly && _yearlyUseSpecificDates) ...[
                OutlinedButton.icon(
                  onPressed: _pickSpecificDates,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(_yearlySpecificDates.isEmpty
                      ? 'Select specific dates'
                      : 'Edit specific dates (${_yearlySpecificDates.length} selected)'),
                ),
                if (_yearlySpecificDates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _yearlySpecificDates.map((d) {
                      return Chip(
                        label: Text('${d.month}/${d.day}'),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => setState(() => _yearlySpecificDates.removeWhere(
                            (item) => item.month == d.month && item.day == d.day)),
                      );
                    }).toList(),
                  ),
                ],
              ],

              const SizedBox(height: 8),
              Text(
                _getRecurrenceSummary(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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
                if (v) { _deadlineTime = TimeOfDay.now(); _deadlineDate ??= _date; }
                else { _deadlineTime = null; _deadlineDate = null; }
              }),
            ),
            if (_deadlineTime != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Deadline date'),
                subtitle: Text('${(_deadlineDate ?? _date).month}/${(_deadlineDate ?? _date).day}/${(_deadlineDate ?? _date).year}'),
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

            _buildSubtaskEditor(),
            const SizedBox(height: 16),

            _buildIconPicker(),
            const SizedBox(height: 16),
            _buildPrioritySelector(),

            if (_isEditing) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as completed'),
                subtitle: const Text('Done with this assignment? It will be greyed out.'),
                value: _isCompleted,
                onChanged: (v) => setState(() => _isCompleted = v),
              ),
            ],

            const Divider(),
            const SizedBox(height: 8),

            const Padding(
              padding: EdgeInsets.fromLTRB(0, 8, 0, 4),
              child: Text('Custom Reminders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            ..._customReminders.map((r) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(r.isAlarm ? Icons.alarm : Icons.notifications, color: r.isAlarm ? Colors.red : null),
                title: Text('${r.minutesBefore} minutes before'),
                subtitle: r.soundUri != null ? const Text('Custom sound') : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (r.soundUri == null)
                      IconButton(icon: const Icon(Icons.music_note, size: 20), onPressed: () => _pickReminderSound(r)),
                    IconButton(icon: const Icon(Icons.delete, size: 20), onPressed: () => _deleteReminder(r)),
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
                        SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
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

class _SpecificDatesPickerDialog extends StatefulWidget {
  final List<YearlySpecificDate> initialDates;
  final TimeOfDay? baseStartTime;
  final TimeOfDay? baseDeadlineTime;

  const _SpecificDatesPickerDialog({
    required this.initialDates,
    this.baseStartTime,
    this.baseDeadlineTime,
  });

  @override
  State<_SpecificDatesPickerDialog> createState() => _SpecificDatesPickerDialogState();
}

class _SpecificDatesPickerDialogState extends State<_SpecificDatesPickerDialog> {
  late Set<DateTime> _selectedDates;
  late Map<String, YearlySpecificDate> _dateDetails;
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDates = widget.initialDates.map((d) {
      final now = DateTime.now();
      return DateTime(now.year, d.month, d.day);
    }).toSet();
    _dateDetails = {
      for (final d in widget.initialDates)
        '${d.month}-${d.day}': d,
    };
  }

  void _toggleDate(DateTime date) {
    final key = '${date.month}-${date.day}';
    setState(() {
      if (_selectedDates.any((d) => d.month == date.month && d.day == date.day)) {
        _selectedDates.removeWhere((d) => d.month == date.month && d.day == date.day);
        _dateDetails.remove(key);
      } else {
        _selectedDates.add(date);
        _dateDetails[key] = YearlySpecificDate(month: date.month, day: date.day);
      }
    });
  }

  Future<void> _editDateTimes(DateTime date) async {
    final key = '${date.month}-${date.day}';
    final existing = _dateDetails[key];

    final result = await showDialog<_DateTimeOverrides>(
      context: context,
      builder: (ctx) => _DateTimeEditDialog(
        date: date,
        startTime: existing?.customStartTimeMillis != null
            ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(existing!.customStartTimeMillis!))
            : widget.baseStartTime,
        deadlineTime: existing?.customDeadlineMillis != null
            ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(existing!.customDeadlineMillis!))
            : widget.baseDeadlineTime,
      ),
    );

    if (result != null) {
      setState(() {
        _dateDetails[key] = YearlySpecificDate(
          month: date.month,
          day: date.day,
          customStartTimeMillis: result.startTime != null
              ? DateTime(date.year, date.month, date.day, result.startTime!.hour, result.startTime!.minute).millisecondsSinceEpoch
              : null,
          customDeadlineMillis: result.deadlineTime != null
              ? DateTime(date.year, date.month, date.day, result.deadlineTime!.hour, result.deadlineTime!.minute).millisecondsSinceEpoch
              : null,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;

    return AlertDialog(
      title: const Text('Select Yearly Dates'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                  }),
                ),
                Text(
                  '${_monthName(_currentMonth.month)} ${_currentMonth.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                  .map((d) => SizedBox(
                        width: 36,
                        child: Text(d, textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 280,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, childAspectRatio: 1,
                ),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (ctx, index) {
                  if (index < firstWeekday) return const SizedBox.shrink();
                  final day = index - firstWeekday + 1;
                  final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                  final isSelected = _selectedDates.any((d) => d.month == date.month && d.day == date.day);
                  final hasCustomTimes = _dateDetails['${date.month}-${date.day}']?.customStartTimeMillis != null ||
                      _dateDetails['${date.month}-${date.day}']?.customDeadlineMillis != null;

                  return InkWell(
                    onTap: () => _toggleDate(date),
                    onLongPress: isSelected ? () => _editDateTimes(date) : null,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        borderRadius: BorderRadius.circular(8),
                        border: hasCustomTimes
                            ? Border.all(color: Theme.of(context).colorScheme.secondary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedDates.length} date(s) selected',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
            if (_selectedDates.isNotEmpty)
              Text(
                'Long-press a date to set custom times',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final result = _selectedDates.map((d) {
              final key = '${d.month}-${d.day}';
              return _dateDetails[key] ?? YearlySpecificDate(month: d.month, day: d.day);
            }).toList();
            result.sort((a, b) {
              if (a.month != b.month) return a.month.compareTo(b.month);
              return a.day.compareTo(b.day);
            });
            Navigator.pop(context, result);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month];
  }
}

class _DateTimeOverrides {
  final TimeOfDay? startTime;
  final TimeOfDay? deadlineTime;
  _DateTimeOverrides({this.startTime, this.deadlineTime});
}

class _DateTimeEditDialog extends StatefulWidget {
  final DateTime date;
  final TimeOfDay? startTime;
  final TimeOfDay? deadlineTime;

  const _DateTimeEditDialog({
    required this.date,
    this.startTime,
    this.deadlineTime,
  });

  @override
  State<_DateTimeEditDialog> createState() => _DateTimeEditDialogState();
}

class _DateTimeEditDialogState extends State<_DateTimeEditDialog> {
  late TimeOfDay? _startTime;
  late TimeOfDay? _deadlineTime;

  @override
  void initState() {
    super.initState();
    _startTime = widget.startTime;
    _deadlineTime = widget.deadlineTime;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit times for ${widget.date.month}/${widget.date.day}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Custom start time'),
            subtitle: Text(_startTime != null
                ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                : 'Use default'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_startTime != null)
                  IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => setState(() => _startTime = null)),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                    if (picked != null) setState(() => _startTime = picked);
                  },
                ),
              ],
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Custom deadline time'),
            subtitle: Text(_deadlineTime != null
                ? '${_deadlineTime!.hour.toString().padLeft(2, '0')}:${_deadlineTime!.minute.toString().padLeft(2, '0')}'
                : 'Use default'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_deadlineTime != null)
                  IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () => setState(() => _deadlineTime = null)),
                IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () async {
                    final picked = await showTimePicker(context: context, initialTime: _deadlineTime ?? TimeOfDay.now());
                    if (picked != null) setState(() => _deadlineTime = picked);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, _DateTimeOverrides(startTime: _startTime, deadlineTime: _deadlineTime)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

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
    setState(() { _hours = hours; _minutes = minutes; });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _hours.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hours', border: OutlineInputBorder()),
                  onChanged: (v) { setState(() { _hours = int.tryParse(v) ?? 0; if (_hours < 0) _hours = 0; }); },
                ),
              ),
              const SizedBox(width: 12),
              const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: _minutes.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Minutes', border: OutlineInputBorder()),
                  onChanged: (v) { setState(() { _minutes = int.tryParse(v) ?? 0; if (_minutes < 0) _minutes = 0; if (_minutes > 59) _minutes = 59; }); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '$_totalMinutes minutes before event',
              style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, {'minutes': _totalMinutes, 'alarm': _isAlarm, 'sound': null}),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

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

import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/syllabus_subject.dart';
import '../models/syllabus_unit.dart';
import '../models/syllabus_topic.dart';
import '../models/syllabus_subtopic.dart';

class SyllabusAddEditScreen extends StatefulWidget {
  final dynamic existing;
  final int? parentSubjectId;
  final int? parentUnitId;
  final int? parentTopicId;
  final String level;

  const SyllabusAddEditScreen({
    super.key,
    this.existing,
    this.parentSubjectId,
    this.parentUnitId,
    this.parentTopicId,
    required this.level,
  });

  @override
  State<SyllabusAddEditScreen> createState() => _SyllabusAddEditScreenState();
}

class _SyllabusAddEditScreenState extends State<SyllabusAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedColor;
  int? _weightage;
  int? _estimatedMinutes;
  String? _difficulty;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing.name;
      if (widget.existing is SyllabusSubject) {
        _selectedColor = widget.existing.colorHex;
        if (widget.existing.targetCompletionDateMillis != null) {
          _targetDate = DateTime.fromMillisecondsSinceEpoch(
            widget.existing.targetCompletionDateMillis!,
          );
        }
      }
      if (widget.existing is SyllabusUnit) {
        _weightage = widget.existing.weightage;
      }
      if (widget.existing is SyllabusTopic) {
        _estimatedMinutes = widget.existing.estimatedMinutes;
        _difficulty = widget.existing.difficulty;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = widget.existing == null
        ? 'Add ${widget.level.capitalize()}'
        : 'Edit ${widget.level.capitalize()}';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              if (widget.level == 'subject') ...[
                DropdownButtonFormField<String>(
                  value: _selectedColor,
                  decoration: const InputDecoration(
                    labelText: 'Color',
                    prefixIcon: Icon(Icons.color_lens_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: '#2196F3', child: _ColorOption('Blue', Color(0xFF2196F3))),
                    DropdownMenuItem(value: '#4CAF50', child: _ColorOption('Green', Color(0xFF4CAF50))),
                    DropdownMenuItem(value: '#F44336', child: _ColorOption('Red', Color(0xFFF44336))),
                    DropdownMenuItem(value: '#FF9800', child: _ColorOption('Orange', Color(0xFFFF9800))),
                    DropdownMenuItem(value: '#9C27B0', child: _ColorOption('Purple', Color(0xFF9C27B0))),
                    DropdownMenuItem(value: '#00BCD4', child: _ColorOption('Cyan', Color(0xFF00BCD4))),
                    DropdownMenuItem(value: '#E91E63', child: _ColorOption('Pink', Color(0xFFE91E63))),
                  ],
                  onChanged: (v) => setState(() => _selectedColor = v),
                  validator: (v) => v == null ? 'Select a color' : null,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Target Completion Date'),
                  subtitle: Text(
                    _targetDate != null
                        ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                        : 'Not set (optional)',
                  ),
                  trailing: _targetDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _targetDate = null),
                        )
                      : null,
                  onTap: _pickTargetDate,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                ),
              ],
              if (widget.level == 'unit') ...[
                TextFormField(
                  initialValue: _weightage?.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Weightage % (optional)',
                    prefixIcon: Icon(Icons.balance),
                    hintText: 'e.g. 25',
                  ),
                  onChanged: (v) => _weightage = int.tryParse(v),
                ),
              ],
              if (widget.level == 'topic') ...[
                TextFormField(
                  initialValue: _estimatedMinutes?.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Minutes',
                    prefixIcon: Icon(Icons.timer_outlined),
                    hintText: 'e.g. 60',
                  ),
                  onChanged: (v) => _estimatedMinutes = int.tryParse(v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    prefixIcon: Icon(Icons.signal_cellular_alt),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                  onChanged: (v) => setState(() => _difficulty = v),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = DatabaseHelper.instance;

    switch (widget.level) {
      case 'subject':
        final subject = SyllabusSubject(
          id: widget.existing?.id,
          name: name,
          colorHex: _selectedColor ?? '#2196F3',
          targetCompletionDateMillis: _targetDate?.millisecondsSinceEpoch,
          createdAtMillis: widget.existing?.createdAtMillis ?? now,
        );
        if (widget.existing == null) {
          await db.insertSyllabusSubject(subject);
        } else {
          await db.updateSyllabusSubject(subject);
        }
        break;

      case 'unit':
        final unit = SyllabusUnit(
          id: widget.existing?.id,
          subjectId: widget.parentSubjectId ?? widget.existing.subjectId,
          name: name,
          orderIndex: 0,
          weightage: _weightage,
          createdAtMillis: widget.existing?.createdAtMillis ?? now,
        );
        if (widget.existing == null) {
          await db.insertSyllabusUnit(unit);
        } else {
          await db.updateSyllabusUnit(unit);
        }
        break;

      case 'topic':
        final topic = SyllabusTopic(
          id: widget.existing?.id,
          unitId: widget.parentUnitId ?? widget.existing.unitId,
          name: name,
          orderIndex: 0,
          status: widget.existing?.status ?? 'notStarted',
          difficulty: _difficulty,
          estimatedMinutes: _estimatedMinutes,
          createdAtMillis: widget.existing?.createdAtMillis ?? now,
        );
        if (widget.existing == null) {
          await db.insertSyllabusTopic(topic);
        } else {
          await db.updateSyllabusTopic(topic);
        }
        break;

      case 'subtopic':
        final subtopic = SyllabusSubtopic(
          id: widget.existing?.id,
          topicId: widget.parentTopicId ?? widget.existing.topicId,
          name: name,
          orderIndex: 0,
          status: widget.existing?.status ?? 'notStarted',
          notes: widget.existing?.notes,
          createdAtMillis: widget.existing?.createdAtMillis ?? now,
        );
        if (widget.existing == null) {
          await db.insertSyllabusSubtopic(subtopic);
        } else {
          await db.updateSyllabusSubtopic(subtopic);
        }
        break;
    }

    if (mounted) Navigator.pop(context, true);
  }
}

class _ColorOption extends StatelessWidget {
  final String label;
  final Color color;
  const _ColorOption(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

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

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing.name;
      if (widget.existing is SyllabusSubject) {
        _selectedColor = widget.existing.colorHex;
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
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              if (widget.level == 'subject') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedColor,
                  items: const [
                    DropdownMenuItem(value: '#2196F3', child: Text('Blue')),
                    DropdownMenuItem(value: '#4CAF50', child: Text('Green')),
                    DropdownMenuItem(value: '#F44336', child: Text('Red')),
                    DropdownMenuItem(value: '#FF9800', child: Text('Orange')),
                    DropdownMenuItem(value: '#9C27B0', child: Text('Purple')),
                  ],
                  onChanged: (v) => setState(() => _selectedColor = v),
                  decoration: const InputDecoration(labelText: 'Color'),
                ),
              ],
              if (widget.level == 'unit') ...[
                const SizedBox(height: 12),
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weightage (optional)'),
                  onChanged: (v) => _weightage = int.tryParse(v),
                ),
              ],
              if (widget.level == 'topic') ...[
                const SizedBox(height: 12),
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Estimated Minutes'),
                  onChanged: (v) => _estimatedMinutes = int.tryParse(v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _difficulty,
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('Easy')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'hard', child: Text('Hard')),
                  ],
                  onChanged: (v) => setState(() => _difficulty = v),
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                ),
              ],
              const Spacer(),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
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
          targetCompletionDateMillis: null,
          createdAtMillis: now,
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
          createdAtMillis: now,
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
          status: 'notStarted',
          difficulty: _difficulty,
          estimatedMinutes: _estimatedMinutes,
          createdAtMillis: now,
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
          status: 'notStarted',
          notes: null,
          createdAtMillis: now,
        );
        if (widget.existing == null) {
          await db.insertSyllabusSubtopic(subtopic);
        } else {
          await db.updateSyllabusSubtopic(subtopic);
        }
        break;
    }

    Navigator.pop(context, true);
  }
}

extension StringExtension on String {
  String capitalize() => '${this[0].toUpperCase()}${substring(1)}';
}

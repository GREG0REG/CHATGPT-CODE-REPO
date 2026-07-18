import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';
import '../models/study_subject.dart';
import '../WIDGET/simple_color_picker.dart';

/// Bottom sheet for picking or managing study subjects.
/// Subjects are independent from Event tags.
class SubjectPickerSheet extends StatefulWidget {
  final String? selectedSubjectName;
  final ValueChanged<String?> onSubjectSelected;

  const SubjectPickerSheet({
    super.key,
    this.selectedSubjectName,
    required this.onSubjectSelected,
  });

  @override
  State<SubjectPickerSheet> createState() => _SubjectPickerSheetState();
}

class _SubjectPickerSheetState extends State<SubjectPickerSheet> {
  List<StudySubject> _subjects = [];
  bool _loading = true;
  final _newNameController = TextEditingController();
  Color _newColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    final list = await DatabaseHelper.instance.getAllStudySubjects();
    if (mounted) {
      setState(() {
        _subjects = list;
        _loading = false;
      });
    }
  }

  Future<void> _addSubject() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;

    final existing = await DatabaseHelper.instance.getStudySubjectByName(name);
    if (existing != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subject already exists')),
        );
      }
      return;
    }

    final subject = StudySubject(
      name: name,
      colorHex: '#${_newColor.value.toRadixString(16).substring(2).toUpperCase()}',
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );

    await DatabaseHelper.instance.insertStudySubject(subject);
    _newNameController.clear();
    HapticFeedback.lightImpact();
    await _loadSubjects();
  }

  Future<void> _deleteSubject(StudySubject subject) async {
    if (subject.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('Delete "${subject.name}"? Focus history will remain.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteStudySubject(subject.id!);
      if (widget.selectedSubjectName == subject.name) {
        widget.onSubjectSelected(null);
      }
      await _loadSubjects();
    }
  }

  Future<void> _pickColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (ctx) => SimpleColorPickerDialog(initialColor: _newColor),
    );
    if (color != null) setState(() => _newColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Select Subject',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ),

            // Add new
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  InkWell(
                    onTap: _pickColor,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _newColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _newNameController,
                      decoration: InputDecoration(
                        hintText: 'New subject name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_circle),
                          onPressed: _addSubject,
                        ),
                      ),
                      onSubmitted: (_) => _addSubject(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // List
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _subjects.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No subjects yet.\nAdd one above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: cs.outline),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _subjects.length,
                          itemBuilder: (context, index) {
                            final s = _subjects[index];
                            final isSelected = widget.selectedSubjectName == s.name;

                            return ListTile(
                              leading: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: s.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(s.name),
                              subtitle: Text(
                                '${s.totalFocusMinutes} min focused',
                                style: TextStyle(fontSize: 12, color: cs.outline),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    Icon(Icons.check_circle, color: cs.primary, size: 22),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        size: 20, color: cs.error),
                                    onPressed: () => _deleteSubject(s),
                                  ),
                                ],
                              ),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onSubjectSelected(s.name);
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),

            // General Study option
            ListTile(
              leading: Icon(Icons.school_outlined, color: cs.primary),
              title: const Text('General Study'),
              subtitle: const Text('No specific subject'),
              trailing: widget.selectedSubjectName == null
                  ? Icon(Icons.check_circle, color: cs.primary, size: 22)
                  : null,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onSubjectSelected(null);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

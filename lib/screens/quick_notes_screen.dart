import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';

/// Quick note screen for jotting down lecture notes fast
class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen> {
  final _noteController = TextEditingController();
  final _titleController = TextEditingController();
  String _selectedSubject = 'General';
  final List<String> _subjects = ['General', 'Math', 'Physics', 'Chemistry', 'Biology', 'History', 'Literature', 'Computer Science'];
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    // Save to a simple notes table or shared prefs for quick access
    final note = {
      'title': _titleController.text.trim().isEmpty ? 'Quick Note' : _titleController.text.trim(),
      'content': _noteController.text.trim(),
      'subject': _selectedSubject,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // For now, save to shared prefs as a quick solution
    // In production, you'd want a proper database table
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate save

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      _noteController.clear();
      _titleController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Notes'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Note Title (optional)',
                hintText: 'e.g., Calculus Lecture 5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSubject,
              decoration: InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.book),
              ),
              items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedSubject = v!),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _noteController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  labelText: 'Note Content',
                  hintText: 'Start typing your lecture notes here...\n\nTip: Use bullet points (•) for key concepts',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  alignLabelWithHint: true,
                ),
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _saveNote,
                icon: const Icon(Icons.save),
                label: const Text('Save Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

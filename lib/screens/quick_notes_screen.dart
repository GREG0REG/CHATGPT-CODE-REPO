import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';

/// Quick note screen for jotting down lecture notes fast
/// NOW PERSISTED TO DATABASE - survives app restarts
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
  bool _loading = true;
  List<Map<String, dynamic>> _notes = [];
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    final notes = await DatabaseHelper.instance.getAllQuickNotes();
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final noteData = {
      'title': _titleController.text.trim().isEmpty ? 'Quick Note' : _titleController.text.trim(),
      'content': _noteController.text.trim(),
      'subject': _selectedSubject,
    };

    if (_editingId != null) {
      await DatabaseHelper.instance.updateQuickNote(_editingId!, noteData);
    } else {
      await DatabaseHelper.instance.insertQuickNote(noteData);
    }

    _noteController.clear();
    _titleController.clear();
    _editingId = null;
    
    await _loadNotes();

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note saved!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteQuickNote(id);
      await _loadNotes();
    }
  }

  void _editNote(Map<String, dynamic> note) {
    setState(() {
      _editingId = note['id'] as int;
      _titleController.text = note['title'] as String;
      _noteController.text = note['content'] as String;
      _selectedSubject = note['subject'] as String? ?? 'General';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _titleController.clear();
      _noteController.clear();
      _selectedSubject = 'General';
    });
  }

  String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingId != null ? 'Edit Note' : 'Quick Notes'),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Input form
                Padding(
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
                          suffixIcon: _editingId != null
                              ? IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _cancelEdit,
                                )
                              : null,
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
                      TextField(
                        controller: _noteController,
                        maxLines: 5,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          labelText: 'Note Content',
                          hintText: 'Start typing your lecture notes here...\n\nTip: Use bullet points (•) for key concepts',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          alignLabelWithHint: true,
                        ),
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveNote,
                          icon: Icon(_editingId != null ? Icons.update : Icons.save),
                          label: Text(_editingId != null ? 'Update Note' : 'Save Note'),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Saved notes list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Saved Notes (${_notes.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: _notes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_alt_outlined, size: 64, color: cs.outline),
                              const SizedBox(height: 16),
                              Text(
                                'No notes yet',
                                style: TextStyle(color: cs.outline, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your saved notes will appear here',
                                style: TextStyle(color: cs.outline, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _notes.length,
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  note['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note['content'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: cs.outline),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            note['subject'] as String? ?? 'General',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: cs.onPrimaryContainer,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTime(note['createdAtMillis'] as int),
                                          style: TextStyle(fontSize: 11, color: cs.outline),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 20, color: cs.primary),
                                      onPressed: () => _editNote(note),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      onPressed: () => _deleteNote(note['id'] as int),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

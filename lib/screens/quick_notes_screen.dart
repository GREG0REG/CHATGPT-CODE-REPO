// FILE: lib/screens/quick_notes_screen.dart
// COMPLETE REPLACEMENT — v2 Redesigned with all features
// Features: Search, Pin, Archive, Tags, Colors, Sort, Export JSON, Swipe actions,
//           Rich preview cards, Subject filter chips, Note stats, Templates

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../database_helper.dart';
import 'main_screen.dart';

class QuickNotesScreen extends StatefulWidget {
  const QuickNotesScreen({super.key});

  @override
  State<QuickNotesScreen> createState() => _QuickNotesScreenState();
}

class _QuickNotesScreenState extends State<QuickNotesScreen>
    with SingleTickerProviderStateMixin {
  final _noteController = TextEditingController();
  final _titleController = TextEditingController();
  final _tagController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedSubject = 'General';
  final List<String> _subjects = [
    'General', 'Math', 'Physics', 'Chemistry', 'Biology',
    'History', 'Literature', 'Computer Science', 'NEET', 'JEE'
  ];

  final List<String> _noteColors = [
    '#2D2D2D', '#1B3A4B', '#2D1B3A', '#3A2D1B', '#1B3A2D',
    '#3A1B1B', '#1B1B3A', '#2D3A1B', '#3A3A1B', '#1B3A3A'
  ];
  String _selectedColor = '#2D2D2D';

  final List<String> _templates = [
    'Blank',
    'Lecture Notes',
    'Formula Sheet',
    'Assignment Tracker',
    'Flashcard Prep',
    'Revision Checklist',
  ];
  String _selectedTemplate = 'Blank';

  bool _isSaving = false;
  bool _loading = true;
  List<Map<String, dynamic>> _notes = [];
  int? _editingId;
  bool _showArchived = false;

  // Search & Filter
  String _searchQuery = '';
  String _sortBy = 'newest';
  String? _subjectFilter;

  // Tags
  final List<String> _currentTags = [];

  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    final notes = await DatabaseHelper.instance.getAllQuickNotes(
      subjectFilter: _subjectFilter,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      includeArchived: _showArchived,
      sortBy: _sortBy,
    );
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  String _getTemplateContent(String template) {
    switch (template) {
      case 'Lecture Notes':
        return '📚 Topic:\n\n🎯 Key Points:\n• \n• \n• \n\n❓ Doubts:\n\n✅ Summary:';
      case 'Formula Sheet':
        return '📐 Formula Name:\n\n🔢 Formula:\n\n📖 Variables:\n• \n\n📝 Example:';
      case 'Assignment Tracker':
        return '📋 Assignment:\n\n📅 Due Date:\n\n✅ Tasks:\n□ \n□ \n□ \n\n📝 Notes:';
      case 'Flashcard Prep':
        return '🎴 Q:\n\n💡 A:\n\n📝 Source:\n\n🏷️ Tags:';
      case 'Revision Checklist':
        return '🔄 Revision Round:\n\n📋 Checklist:\n□ Concept 1\n□ Concept 2\n□ Concept 3\n\n📝 Notes:';
      default:
        return '';
    }
  }

  void _applyTemplate(String template) {
    setState(() {
      _selectedTemplate = template;
      if (template != 'Blank') {
        _noteController.text = _getTemplateContent(template);
      }
    });
  }

  Future<void> _saveNote() async {
    if (_noteController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final noteData = {
      'title': _titleController.text.trim().isEmpty
          ? 'Quick Note'
          : _titleController.text.trim(),
      'content': _noteController.text.trim(),
      'subject': _selectedSubject,
      'tagsJson': jsonEncode(_currentTags),
      'noteColor': _selectedColor,
      'isPinned': 0,
      'isArchived': 0,
    };

    if (_editingId != null) {
      final existing = await DatabaseHelper.instance.getQuickNote(_editingId!);
      if (existing != null) {
        noteData['isPinned'] = existing['isPinned'];
        noteData['isArchived'] = existing['isArchived'];
      }
      await DatabaseHelper.instance.updateQuickNote(_editingId!, noteData);
    } else {
      await DatabaseHelper.instance.insertQuickNote(noteData);
    }

    _clearForm();
    await _loadNotes();

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingId != null ? 'Note updated!' : 'Note saved!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _titleController.clear();
      _noteController.clear();
      _tagController.clear();
      _currentTags.clear();
      _selectedSubject = 'General';
      _selectedColor = '#2D2D2D';
      _selectedTemplate = 'Blank';
    });
  }

  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete note?'),
          ],
        ),
        content: const Text('This cannot be undone. The note will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteQuickNote(id);
      await _loadNotes();
    }
  }

  Future<void> _archiveNote(int id, bool archive) async {
    await DatabaseHelper.instance.archiveQuickNote(id, archive);
    await _loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archive ? 'Note archived' : 'Note restored'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pinNote(int id, bool pin) async {
    await DatabaseHelper.instance.pinQuickNote(id, pin);
    await _loadNotes();
  }

  void _editNote(Map<String, dynamic> note) {
    setState(() {
      _editingId = note['id'] as int;
      _titleController.text = note['title'] as String;
      _noteController.text = note['content'] as String;
      _selectedSubject = note['subject'] as String? ?? 'General';
      _selectedColor = note['noteColor'] as String? ?? '#2D2D2D';
      final tagsJson = note['tagsJson'] as String? ?? '[]';
      try {
        _currentTags = List<String>.from(jsonDecode(tagsJson));
      } catch (_) {
        _currentTags = [];
      }
    });
    _scrollToEditor();
  }

  void _duplicateNote(Map<String, dynamic> note) async {
    final data = {
      'title': '${note['title']} (Copy)',
      'content': note['content'],
      'subject': note['subject'],
      'tagsJson': note['tagsJson'],
      'noteColor': note['noteColor'],
    };
    await DatabaseHelper.instance.insertQuickNote(data);
    await _loadNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note duplicated!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToEditor() {
    // Auto-scroll to top when editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Scroll handled by UI focus
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_currentTags.contains(tag)) {
      setState(() {
        _currentTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _currentTags.remove(tag));
  }

  Future<void> _exportNotesToJson() async {
    final notes = await DatabaseHelper.instance.getAllQuickNotes(includeArchived: true);
    final exportData = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'StudyMania',
      'version': '1.0',
      'notes': notes,
    };
    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: jsonString));

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Exported!'),
            ],
          ),
          content: const Text(
            'All notes exported as JSON and copied to clipboard.\n\nYou can paste it anywhere — file, chat, cloud storage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _formatTime(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF2D2D2D);
    }
  }

  String _getNotePreview(String content) {
    return content.replaceAll(RegExp(r'[#*□✅❓📚🎯📐🔢📖📝🎴💡🏷️🔄📋📅]'), '').trim();
  }

  List<String> _parseTags(String? tagsJson) {
    if (tagsJson == null || tagsJson == '[]') return [];
    try {
      return List<String>.from(jsonDecode(tagsJson));
    } catch (_) {
      return [];
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _titleController.dispose();
    _tagController.dispose();
    _searchController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : cs.surface,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F1419) : cs.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _showArchived ? 'Archived Notes' : 'Quick Notes',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_showArchived) ...[
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export JSON',
              onPressed: _exportNotesToJson,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: (value) {
                setState(() => _sortBy = value);
                _loadNotes();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'newest', child: Text('Newest first')),
                const PopupMenuItem(value: 'oldest', child: Text('Oldest first')),
                const PopupMenuItem(value: 'az', child: Text('A → Z')),
                const PopupMenuItem(value: 'za', child: Text('Z → A')),
                const PopupMenuItem(value: 'subject', child: Text('By Subject')),
              ],
            ),
          ],
          IconButton(
            icon: Icon(_showArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            tooltip: _showArchived ? 'Show active' : 'Show archived',
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _loadNotes();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Search Bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _loadNotes();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1A1D24) : cs.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),

                // ── Subject Filter Chips ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _subjects.length + 1,
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final subject = isAll ? 'All' : _subjects[index - 1];
                        final isSelected = isAll
                            ? _subjectFilter == null
                            : _subjectFilter == subject;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FilterChip(
                            selected: isSelected,
                            showCheckmark: false,
                            label: Text(subject),
                            selectedColor: cs.primaryContainer,
                            backgroundColor: isDark ? const Color(0xFF1A1D24) : cs.surfaceContainerHighest,
                            onSelected: (_) {
                              setState(() => _subjectFilter = isAll ? null : subject);
                              _loadNotes();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // ── Editor Card ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title row
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _titleController,
                                    decoration: InputDecoration(
                                      hintText: 'Note Title (optional)',
                                      hintStyle: TextStyle(color: cs.outline),
                                      border: InputBorder.none,
                                      prefixIcon: const Icon(Icons.title, size: 20),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (_editingId != null)
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: _clearForm,
                                    tooltip: 'Cancel edit',
                                  ),
                              ],
                            ),

                            const Divider(height: 16),

                            // Template selector
                            SizedBox(
                              height: 36,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _templates.length,
                                itemBuilder: (context, index) {
                                  final template = _templates[index];
                                  final isSelected = _selectedTemplate == template;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActionChip(
                                      avatar: isSelected
                                          ? const Icon(Icons.check, size: 16)
                                          : null,
                                      label: Text(template, style: const TextStyle(fontSize: 12)),
                                      backgroundColor: isSelected
                                          ? cs.primaryContainer
                                          : (isDark ? const Color(0xFF1A1D24) : cs.surfaceContainerHighest),
                                      onPressed: () => _applyTemplate(template),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Subject & Color
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedSubject,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: 'Subject',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    items: _subjects
                                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                        .toList(),
                                    onChanged: (v) => setState(() => _selectedSubject = v!),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Color picker
                                PopupMenuButton<String>(
                                  tooltip: 'Note color',
                                  onSelected: (color) => setState(() => _selectedColor = color),
                                  itemBuilder: (_) => _noteColors.map((color) {
                                    return PopupMenuItem(
                                      value: color,
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: _hexToColor(color),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: cs.outline.withOpacity(0.3)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(color),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _hexToColor(_selectedColor),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cs.outline.withOpacity(0.3)),
                                    ),
                                    child: const Icon(Icons.color_lens, size: 18, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Content
                            TextField(
                              controller: _noteController,
                              maxLines: 6,
                              minLines: 4,
                              textAlignVertical: TextAlignVertical.top,
                              decoration: InputDecoration(
                                hintText: 'Start typing your notes...\n\nTip: Use templates above for structured notes!',
                                hintStyle: TextStyle(
                                  color: cs.outline,
                                  height: 1.5,
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                alignLabelWithHint: true,
                                filled: true,
                                fillColor: isDark ? const Color(0xFF14161B) : cs.surfaceContainerLowest,
                              ),
                              style: const TextStyle(fontSize: 15, height: 1.6),
                            ),

                            const SizedBox(height: 12),

                            // Tags
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ..._currentTags.map((tag) => Chip(
                                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                                      deleteIcon: const Icon(Icons.close, size: 16),
                                      onDeleted: () => _removeTag(tag),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: cs.primaryContainer.withOpacity(0.5),
                                    )),
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: _tagController,
                                    decoration: InputDecoration(
                                      hintText: '+ Add tag',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                    onSubmitted: (_) => _addTag(),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSaving ? null : _saveNote,
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(_editingId != null ? Icons.update : Icons.save),
                                label: Text(
                                  _editingId != null ? 'Update Note' : 'Save Note',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Stats Bar ──
                if (!_showArchived && _searchQuery.isEmpty)
                  SliverToBoxAdapter(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: DatabaseHelper.instance.getQuickNoteStats(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final stats = snapshot.data!;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              _StatChip(
                                icon: Icons.note,
                                label: '${stats['total']} notes',
                                color: cs.primary,
                              ),
                              const SizedBox(width: 8),
                              _StatChip(
                                icon: Icons.push_pin,
                                label: '${stats['pinned']} pinned',
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              _StatChip(
                                icon: Icons.archive,
                                label: '${stats['archived']} archived',
                                color: cs.outline,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // ── Notes List ──
                if (_notes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      isDark: isDark,
                      isArchived: _showArchived,
                      isSearch: _searchQuery.isNotEmpty,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = _notes[index];
                          final isPinned = (note['isPinned'] as int?) == 1;
                          final isArchived = (note['isArchived'] as int?) == 1;
                          final noteColor = _hexToColor(note['noteColor'] as String? ?? '#2D2D2D');
                          final tags = _parseTags(note['tagsJson'] as String?);
                          final preview = _getNotePreview(note['content'] as String);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Slidable(
                              key: ValueKey(note['id']),
                              startActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                extentRatio: 0.25,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => _pinNote(note['id'] as int, !isPinned),
                                    backgroundColor: Colors.amber,
                                    foregroundColor: Colors.white,
                                    icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                    label: isPinned ? 'Unpin' : 'Pin',
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ],
                              ),
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                extentRatio: 0.5,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => _duplicateNote(note),
                                    backgroundColor: cs.primary,
                                    foregroundColor: Colors.white,
                                    icon: Icons.copy,
                                    label: 'Copy',
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                  ),
                                  SlidableAction(
                                    onPressed: (_) => _archiveNote(note['id'] as int, !isArchived),
                                    backgroundColor: isArchived ? Colors.green : Colors.grey,
                                    foregroundColor: Colors.white,
                                    icon: isArchived ? Icons.unarchive : Icons.archive,
                                    label: isArchived ? 'Restore' : 'Archive',
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                ],
                              ),
                              child: Card(
                                elevation: 2,
                                color: noteColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: isPinned
                                      ? BorderSide(color: Colors.amber.shade400, width: 1.5)
                                      : BorderSide.none,
                                ),
                                child: InkWell(
                                  onTap: () => _editNote(note),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            if (isPinned)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 6),
                                                child: Icon(Icons.push_pin, size: 16, color: Colors.amber),
                                              ),
                                            Expanded(
                                              child: Text(
                                                note['title'] as String,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            PopupMenuButton<String>(
                                              icon: const Icon(Icons.more_vert, size: 18, color: Colors.white70),
                                              color: const Color(0xFF1A1D24),
                                              onSelected: (value) {
                                                switch (value) {
                                                  case 'edit':
                                                    _editNote(note);
                                                    break;
                                                  case 'duplicate':
                                                    _duplicateNote(note);
                                                    break;
                                                  case 'pin':
                                                    _pinNote(note['id'] as int, !isPinned);
                                                    break;
                                                  case 'archive':
                                                    _archiveNote(note['id'] as int, !isArchived);
                                                    break;
                                                  case 'delete':
                                                    _deleteNote(note['id'] as int);
                                                    break;
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                                const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                                                PopupMenuItem(
                                                  value: 'pin',
                                                  child: Text(isPinned ? 'Unpin' : 'Pin'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'archive',
                                                  child: Text(isArchived ? 'Restore' : 'Archive'),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          preview,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(0.7),
                                            height: 1.4,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                note['subject'] as String? ?? 'General',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatTime(note['createdAtMillis'] as int),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white.withOpacity(0.5),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (tags.isNotEmpty)
                                              Row(
                                                children: tags.take(2).map((tag) => Padding(
                                                  padding: const EdgeInsets.only(left: 4),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      tag,
                                                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                                                    ),
                                                  ),
                                                )).toList(),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: _notes.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// =============================================================================
// WIDGETS
// =============================================================================

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final bool isArchived;
  final bool isSearch;

  const _EmptyState({
    required this.isDark,
    required this.isArchived,
    required this.isSearch,
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    IconData icon;

    if (isSearch) {
      title = 'No matches';
      subtitle = 'Try a different search term';
      icon = Icons.search_off;
    } else if (isArchived) {
      title = 'No archived notes';
      subtitle = 'Archive notes to see them here';
      icon = Icons.archive_outlined;
    } else {
      title = 'No notes yet';
      subtitle = 'Your saved notes will appear here';
      icon = Icons.note_alt_outlined;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 36, color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

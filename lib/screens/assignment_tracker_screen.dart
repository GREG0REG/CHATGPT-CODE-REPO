// FILE: lib/screens/assignment_tracker_screen.dart
// COMPLETE REPLACEMENT — Assignment Tracker v2.1
// FIXED: Edit assignments, delete works, completed history, clearer progress
// Uses existing events + subtasks tables (v17 with assignmentType column)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../db/database_helper.dart';
import '../models/event.dart';
import '../models/subtask.dart';
import 'main_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════

enum AssignmentSort { deadline, priority, progress, title }
enum AssignmentType { essay, exam, project, homework, lab, reading, presentation, other }

extension AssignmentTypeExt on AssignmentType {
  String get label {
    switch (this) {
      case AssignmentType.essay: return 'Essay';
      case AssignmentType.exam: return 'Exam';
      case AssignmentType.project: return 'Project';
      case AssignmentType.homework: return 'Homework';
      case AssignmentType.lab: return 'Lab';
      case AssignmentType.reading: return 'Reading';
      case AssignmentType.presentation: return 'Presentation';
      case AssignmentType.other: return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case AssignmentType.essay: return Icons.article_outlined;
      case AssignmentType.exam: return Icons.quiz_outlined;
      case AssignmentType.project: return Icons.folder_open_outlined;
      case AssignmentType.homework: return Icons.assignment_outlined;
      case AssignmentType.lab: return Icons.science_outlined;
      case AssignmentType.reading: return Icons.menu_book_outlined;
      case AssignmentType.presentation: return Icons.slideshow_outlined;
      case AssignmentType.other: return Icons.note_outlined;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// COURSE COLORS
// ═══════════════════════════════════════════════════════════════════

final Map<String, Color> _courseColorMap = {};
final List<Color> _coursePalette = [
  const Color(0xFF388BFD), // Blue
  const Color(0xFF3FB950), // Green
  const Color(0xFFF0883E), // Orange
  const Color(0xFFA371F7), // Purple
  const Color(0xFFF778BA), // Pink
  const Color(0xFF58A6FF), // Light Blue
  const Color(0xFFDA3633), // Red
  const Color(0xFFD29922), // Yellow
];

Color _getCourseColor(String course) {
  if (_courseColorMap.containsKey(course)) return _courseColorMap[course]!;
  final index = _courseColorMap.length % _coursePalette.length;
  _courseColorMap[course] = _coursePalette[index];
  return _coursePalette[index];
}

// ═══════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════

class AssignmentTrackerScreen extends StatefulWidget {
  const AssignmentTrackerScreen({super.key});

  @override
  State<AssignmentTrackerScreen> createState() => _AssignmentTrackerScreenState();
}

class _AssignmentTrackerScreenState extends State<AssignmentTrackerScreen> {
  // ── Data ──
  List<Event> _allAssignments = []; // All assignments (including completed)
  List<Event> _filteredAssignments = []; // Currently visible
  List<Subtask> _subtasks = [];
  List<String> _courses = [];
  bool _loading = true;

  // ── Filters ──
  String _searchQuery = '';
  String? _selectedCourse;
  AssignmentSort _sortBy = AssignmentSort.deadline;
  String _quickFilter = 'active'; // active | overdue | urgent | thisweek | completed

  // ── Quick Add ──
  final _titleController = TextEditingController();
  final _courseController = TextEditingController();
  final _subtaskController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _priority = 2;
  AssignmentType _assignmentType = AssignmentType.homework;
  final List<String> _quickSubtasks = [];
  bool _isQuickAddExpanded = false;

  // ── Edit ──
  Event? _editingEvent;
  final _editTitleController = TextEditingController();
  final _editCourseController = TextEditingController();
  DateTime _editDueDate = DateTime.now();
  int _editPriority = 2;
  AssignmentType _editType = AssignmentType.homework;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ═══════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final events = await DatabaseHelper.instance.getAllEventsSorted();
    final now = DateTime.now();

    // Get ALL assignments (has deadline)
    final allAssignments = events.where((e) {
      final hasDeadline = e.deadlineMillis != null && e.deadlineMillis! > 0;
      return hasDeadline;
    }).toList();

    // Extract unique courses from ALL assignments
    final courseSet = <String>{};
    for (final e in allAssignments) {
      courseSet.add(e.subjectTag ?? 'General');
    }
    final courses = courseSet.toList()..sort();

    // Load subtasks for all assignments
    final allSubtasks = <Subtask>[];
    for (final a in allAssignments) {
      if (a.id != null) {
        final sts = await DatabaseHelper.instance.getSubtasksForEvent(a.id!);
        allSubtasks.addAll(sts);
      }
    }

    // Apply filters to create visible list
    var visible = List<Event>.from(allAssignments);

    // Quick filter
    if (_quickFilter == 'active') {
      visible.retainWhere((e) => !e.isCompleted);
    } else if (_quickFilter == 'completed') {
      visible.retainWhere((e) => e.isCompleted);
    } else if (_quickFilter == 'overdue') {
      visible.retainWhere((e) => _isOverdue(e.deadlineMillis ?? 0) && !e.isCompleted);
    } else if (_quickFilter == 'urgent') {
      visible.retainWhere((e) => e.priority == 4 && !e.isCompleted);
    } else if (_quickFilter == 'thisweek') {
      final weekEnd = now.add(const Duration(days: 7)).millisecondsSinceEpoch;
      visible.retainWhere((e) => (e.deadlineMillis ?? 0) <= weekEnd && !e.isCompleted);
    }

    // Course filter
    if (_selectedCourse != null && _selectedCourse != 'All') {
      visible.retainWhere((e) => (e.subjectTag ?? 'General') == _selectedCourse);
    }

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      visible.retainWhere((e) =>
          e.title.toLowerCase().contains(q) ||
          (e.subjectTag ?? '').toLowerCase().contains(q) ||
          (e.notes ?? '').toLowerCase().contains(q));
    }

    // Sort
    switch (_sortBy) {
      case AssignmentSort.deadline:
        visible.sort((a, b) => (a.deadlineMillis ?? 0).compareTo(b.deadlineMillis ?? 0));
      case AssignmentSort.priority:
        visible.sort((a, b) => b.priority.compareTo(a.priority));
      case AssignmentSort.progress:
        visible.sort((a, b) => _getEffectiveProgress(b).compareTo(_getEffectiveProgress(a)));
      case AssignmentSort.title:
        visible.sort((a, b) => a.title.compareTo(b.title));
    }

    setState(() {
      _allAssignments = allAssignments;
      _filteredAssignments = visible;
      _courses = courses;
      _subtasks = allSubtasks;
      _loading = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _addAssignment() async {
    if (_titleController.text.trim().isEmpty) return;

    final title = _titleController.text.trim();
    final course = _courseController.text.trim().isEmpty ? 'General' : _courseController.text.trim();

    final dueDateStart = DateTime(_dueDate.year, _dueDate.month, _dueDate.day).millisecondsSinceEpoch;
    final deadlineEnd = DateTime(_dueDate.year, _dueDate.month, _dueDate.day, 23, 59).millisecondsSinceEpoch;

    final event = Event(
      title: title,
      dateMillis: dueDateStart,
      deadlineMillis: deadlineEnd,
      priority: _priority,
      subjectTag: course,
      notes: 'PROGRESS:0%\nTYPE:${_assignmentType.name}',
    );

    final id = await DatabaseHelper.instance.insertEvent(event);

    // Insert subtasks
    for (int i = 0; i < _quickSubtasks.length; i++) {
      await DatabaseHelper.instance.insertSubtask(Subtask(
        eventId: id,
        title: _quickSubtasks[i],
        orderIndex: i,
      ));
    }

    HapticFeedback.lightImpact();
    _resetQuickAdd();
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Assignment saved!'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _updateAssignment() async {
    if (_editingEvent == null || _editTitleController.text.trim().isEmpty) return;

    final title = _editTitleController.text.trim();
    final course = _editCourseController.text.trim().isEmpty ? 'General' : _editCourseController.text.trim();

    final dueDateStart = DateTime(_editDueDate.year, _editDueDate.month, _editDueDate.day).millisecondsSinceEpoch;
    final deadlineEnd = DateTime(_editDueDate.year, _editDueDate.month, _editDueDate.day, 23, 59).millisecondsSinceEpoch;

    // Preserve existing progress and type from notes
    final existingNotes = _editingEvent!.notes ?? '';
    final progressMatch = RegExp(r'PROGRESS:\d+%').firstMatch(existingNotes);
    final typeMatch = RegExp(r'TYPE:(\w+)').firstMatch(existingNotes);
    final progressStr = progressMatch?.group(0) ?? 'PROGRESS:0%';
    final typeStr = typeMatch != null ? 'TYPE:${_editType.name}' : 'TYPE:${_editType.name}';

    final updated = _editingEvent!.copyWith(
      title: title,
      dateMillis: dueDateStart,
      deadlineMillis: deadlineEnd,
      priority: _editPriority,
      subjectTag: course,
      notes: '$progressStr\n$typeStr',
    );

    await DatabaseHelper.instance.updateEvent(updated);
    _closeEditSheet();
    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Assignment updated!'),
          backgroundColor: const Color(0xFF388BFD),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _resetQuickAdd() {
    _titleController.clear();
    _courseController.clear();
    _subtaskController.clear();
    _quickSubtasks.clear();
    _priority = 2;
    _assignmentType = AssignmentType.homework;
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _isQuickAddExpanded = false;
  }

  void _openEditSheet(Event event) {
    _editingEvent = event;
    _editTitleController.text = event.title;
    _editCourseController.text = event.subjectTag ?? '';
    _editDueDate = event.deadlineMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(event.deadlineMillis!)
        : DateTime.now();
    _editPriority = event.priority;
    _editType = _getAssignmentType(event);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _buildEditSheet(),
    );
  }

  void _closeEditSheet() {
    _editingEvent = null;
    _editTitleController.clear();
    _editCourseController.clear();
    Navigator.pop(context);
  }

  Future<void> _updateProgress(Event event, double value) async {
    if (event.id == null) return;
    final updatedNotes = _setProgressInNotes(event.notes, value);
    final updated = event.copyWith(
      notes: updatedNotes,
      isCompleted: value >= 1.0 ? true : event.isCompleted,
    );
    await DatabaseHelper.instance.updateEvent(updated);
    if (mounted) setState(() {
      final idx = _allAssignments.indexWhere((e) => e.id == event.id);
      if (idx >= 0) _allAssignments[idx] = updated;
    });
    await _loadData();
  }

  Future<void> _toggleSubtask(Subtask subtask) async {
    await DatabaseHelper.instance.toggleSubtaskComplete(subtask.id!, !subtask.isCompleted);
    // Update event progress based on subtasks
    final event = _allAssignments.firstWhere((e) => e.id == subtask.eventId);
    final sts = _getSubtasksForEvent(event.id!);
    final completed = sts.where((s) => s.isCompleted).length;
    final progress = sts.isEmpty ? 0 : completed / sts.length;
    await _updateProgress(event, progress);
    await _loadData();
  }

  Future<void> _toggleComplete(Event event) async {
    if (event.id == null) return;
    final updated = event.copyWith(isCompleted: !event.isCompleted);
    await DatabaseHelper.instance.updateEvent(updated);
    HapticFeedback.mediumImpact();
    await _loadData();
  }

  Future<void> _deleteAssignment(Event event) async {
    if (event.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Assignment?', style: TextStyle(color: Color(0xFFE6EDF3))),
        content: Text(
          'Delete "${event.title}"?\n\nThis cannot be undone.',
          style: const TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDA3633), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.instance.deleteEvent(event.id!);
    HapticFeedback.mediumImpact();
    await _loadData();
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  String _setProgressInNotes(String? existingNotes, double progress) {
    final progressText = 'PROGRESS:${(progress * 100).toInt()}%';
    if (existingNotes == null || existingNotes.isEmpty) return progressText;
    final cleaned = existingNotes.replaceAll(RegExp(r'PROGRESS:\d+%'), '').trim();
    if (cleaned.isEmpty) return progressText;
    return '$cleaned\n$progressText';
  }

  double _getProgressFromNotes(Event event) {
    if (event.notes == null || event.notes!.isEmpty) return 0;
    final match = RegExp(r'PROGRESS:(\d+)%').firstMatch(event.notes!);
    if (match != null) return int.parse(match.group(1)!) / 100;
    return 0;
  }

  double _getEffectiveProgress(Event event) {
    final sts = _getSubtasksForEvent(event.id ?? 0);
    if (sts.isNotEmpty) {
      final completed = sts.where((s) => s.isCompleted).length;
      return completed / sts.length;
    }
    return _getProgressFromNotes(event);
  }

  AssignmentType _getAssignmentType(Event event) {
    if (event.notes == null) return AssignmentType.other;
    final match = RegExp(r'TYPE:(\w+)').firstMatch(event.notes!);
    if (match != null) {
      try {
        return AssignmentType.values.byName(match.group(1)!);
      } catch (_) {}
    }
    return AssignmentType.other;
  }

  bool _isOverdue(int deadlineMillis) {
    return DateTime.now().millisecondsSinceEpoch > deadlineMillis;
  }

  String _timeRemaining(int deadlineMillis) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(deadlineMillis);
    final diff = due.difference(now);
    if (diff.isNegative) {
      final daysOverdue = diff.inDays.abs();
      return daysOverdue > 0 ? '$daysOverdue days overdue' : 'Overdue!';
    }
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    return '${diff.inMinutes}m left';
  }

  Color _urgencyColor(int deadlineMillis) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(deadlineMillis);
    final diff = due.difference(now);
    if (diff.isNegative) return const Color(0xFFDA3633);
    if (diff.inDays > 7) return const Color(0xFF3FB950);
    if (diff.inDays > 3) return const Color(0xFFF0883E);
    return const Color(0xFFDA3633);
  }

  String _formatDate(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  List<Subtask> _getSubtasksForEvent(int eventId) {
    return _subtasks.where((s) => s.eventId == eventId).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final activeCount = _allAssignments.where((a) => !a.isCompleted).length;
    final doneCount = _allAssignments.where((a) => a.isCompleted).length;
    final urgentCount = _allAssignments.where((a) => a.priority == 4 && !a.isCompleted).length;
    final overdueCount = _allAssignments.where((a) => _isOverdue(a.deadlineMillis ?? 0) && !a.isCompleted).length;

    // Dashboard progress = % of ALL assignments done
    final totalProgress = _allAssignments.isEmpty
        ? 0.0
        : doneCount / _allAssignments.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFFE6EDF3)),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Assignments',
          style: TextStyle(
            color: Color(0xFFE6EDF3),
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          PopupMenuButton<AssignmentSort>(
            icon: const Icon(Icons.sort, color: Color(0xFF8B949E)),
            tooltip: 'Sort by',
            color: const Color(0xFF161B22),
            onSelected: (sort) {
              setState(() => _sortBy = sort);
              _loadData();
            },
            itemBuilder: (context) => [
              _sortItem(AssignmentSort.deadline, 'Deadline', Icons.calendar_today),
              _sortItem(AssignmentSort.priority, 'Priority', Icons.flag),
              _sortItem(AssignmentSort.progress, 'Progress', Icons.percent),
              _sortItem(AssignmentSort.title, 'Title', Icons.sort_by_alpha),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF388BFD)))
          : CustomScrollView(
              slivers: [
                // Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      onChanged: (v) {
                        setState(() => _searchQuery = v);
                        _loadData();
                      },
                      style: const TextStyle(color: Color(0xFFE6EDF3)),
                      decoration: InputDecoration(
                        hintText: 'Search assignments...',
                        hintStyle: const TextStyle(color: Color(0xFF6E7681)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF8B949E)),
                        filled: true,
                        fillColor: const Color(0xFF161B22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),

                // Dashboard Ring
                SliverToBoxAdapter(
                  child: _buildDashboard(totalProgress, activeCount, doneCount, urgentCount, overdueCount),
                ),

                // Course Chips
                if (_courses.isNotEmpty)
                  SliverToBoxAdapter(child: _buildCourseChips()),

                // Quick Filters
                SliverToBoxAdapter(child: _buildQuickFilters(overdueCount, urgentCount, doneCount)),

                // Quick Add
                SliverToBoxAdapter(child: _buildQuickAdd()),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Assignment List
                _filteredAssignments.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildAssignmentCard(_filteredAssignments[index]),
                          childCount: _filteredAssignments.length,
                        ),
                      ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() => _isQuickAddExpanded = !_isQuickAddExpanded);
        },
        backgroundColor: const Color(0xFF388BFD),
        elevation: 4,
        child: AnimatedRotation(
          turns: _isQuickAddExpanded ? 0.125 : 0,
          duration: const Duration(milliseconds: 300),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDashboard(double progress, int active, int done, int urgent, int overdue) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF388BFD).withOpacity(0.08),
              const Color(0xFF8B949E).withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFF8B949E).withOpacity(0.12)),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Circular progress
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 5,
                        backgroundColor: const Color(0xFF8B949E).withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF388BFD)),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF388BFD),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$done of ${_allAssignments.length} done',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE6EDF3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$active active • $urgent urgent • $overdue overdue',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              children: [
                _legendDot(const Color(0xFF388BFD), 'Done: $done'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFF0883E), 'Urgent: $urgent'),
                const SizedBox(width: 12),
                _legendDot(const Color(0xFFDA3633), 'Overdue: $overdue'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildCourseChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _courseChip('All', _selectedCourse == 'All' || _selectedCourse == null, const Color(0xFF388BFD)),
            ..._courses.map((c) {
              final color = _getCourseColor(c);
              return _courseChip(c, _selectedCourse == c, color);
            }),
          ],
        ),
      ),
    );
  }

  Widget _courseChip(String label, bool selected, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCourse = selected ? null : label);
          _loadData();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : const Color(0xFF8B949E).withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!selected)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF8B949E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilters(int overdueCount, int urgentCount, int doneCount) {
    final filters = [
      ('active', 'Active', null as Color?),
      ('overdue', 'Overdue ($overdueCount)', const Color(0xFFDA3633)),
      ('urgent', 'Urgent ($urgentCount)', const Color(0xFFF0883E)),
      ('thisweek', 'This Week', const Color(0xFF388BFD)),
      ('completed', 'Completed ($doneCount)', const Color(0xFF3FB950)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((f) {
          final isActive = _quickFilter == f.$1;
          final color = f.$3 ?? const Color(0xFF8B949E);
          return GestureDetector(
            onTap: () {
              setState(() => _quickFilter = f.$1);
              _loadData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.15) : const Color(0xFF8B949E).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.3) : const Color(0xFF8B949E).withOpacity(0.1),
                ),
              ),
              child: Text(
                f.$2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isActive ? color : const Color(0xFF8B949E),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickAdd() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8B949E).withOpacity(0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add_circle, color: Color(0xFF388BFD)),
              title: const Text(
                'Quick Add Assignment',
                style: TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.w600),
              ),
              trailing: AnimatedRotation(
                turns: _isQuickAddExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8B949E)),
              ),
              onTap: () => setState(() => _isQuickAddExpanded = !_isQuickAddExpanded),
            ),
            if (_isQuickAddExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _field('Assignment Title', _titleController, hint: 'e.g., Essay on Climate Change'),
                    const SizedBox(height: 10),
                    _field('Course/Subject', _courseController, hint: 'e.g., Environmental Science'),
                    const SizedBox(height: 10),

                    const Text('Type', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: AssignmentType.values.map((t) {
                        final selected = _assignmentType == t;
                        return ChoiceChip(
                          label: Text(t.label),
                          selected: selected,
                          avatar: Icon(t.icon, size: 16),
                          selectedColor: const Color(0xFF388BFD).withOpacity(0.2),
                          backgroundColor: const Color(0xFF0D1117),
                          labelStyle: TextStyle(
                            color: selected ? const Color(0xFF388BFD) : const Color(0xFF8B949E),
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: selected ? const Color(0xFF388BFD) : const Color(0xFF8B949E).withOpacity(0.2),
                            ),
                          ),
                          onSelected: (_) => setState(() => _assignmentType = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),

                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Due Date', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                      subtitle: Text(
                        '${_dueDate.month}/${_dueDate.day}/${_dueDate.year}',
                        style: const TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.w600),
                      ),
                      trailing: const Icon(Icons.calendar_today, color: Color(0xFF8B949E)),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: Color(0xFF388BFD),
                                surface: Color(0xFF161B22),
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                    ),

                    const Text('Priority', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                    const SizedBox(height: 6),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Low', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 2, label: Text('Norm', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 3, label: Text('High', style: TextStyle(fontSize: 11))),
                        ButtonSegment(value: 4, label: Text('URG', style: TextStyle(fontSize: 11))),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (sel) {
                        if (sel.isNotEmpty) setState(() => _priority = sel.first);
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF388BFD).withOpacity(0.2);
                          }
                          return const Color(0xFF0D1117);
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF388BFD);
                          }
                          return const Color(0xFF8B949E);
                        }),
                        side: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const BorderSide(color: Color(0xFF388BFD));
                          }
                          return BorderSide(color: const Color(0xFF8B949E).withOpacity(0.2));
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),

                    const Text('Subtasks (optional)', style: TextStyle(fontSize: 12, color: Color(0xFF8B949E))),
                    const SizedBox(height: 6),
                    ..._quickSubtasks.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF8B949E)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _quickSubtasks.removeAt(e.key)),
                                child: const Icon(Icons.close, size: 16, color: Color(0xFF8B949E)),
                              ),
                            ],
                          ),
                        )),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _subtaskController,
                            style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add subtask...',
                              hintStyle: const TextStyle(color: Color(0xFF6E7681), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFF0D1117),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (v) {
                              if (v.trim().isNotEmpty) {
                                setState(() => _quickSubtasks.add(v.trim()));
                                _subtaskController.clear();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Color(0xFF388BFD)),
                          onPressed: () {
                            if (_subtaskController.text.trim().isNotEmpty) {
                              setState(() => _quickSubtasks.add(_subtaskController.text.trim()));
                              _subtaskController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _addAssignment,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Assignment'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF388BFD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF161B22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B949E).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Edit Assignment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE6EDF3),
                ),
              ),
              const SizedBox(height: 20),

              _field('Title', _editTitleController),
              const SizedBox(height: 12),
              _field('Course/Subject', _editCourseController),
              const SizedBox(height: 16),

              const Text('Type', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AssignmentType.values.map((t) {
                  final selected = _editType == t;
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: selected,
                    avatar: Icon(t.icon, size: 16),
                    selectedColor: const Color(0xFF388BFD).withOpacity(0.2),
                    backgroundColor: const Color(0xFF0D1117),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFF388BFD) : const Color(0xFF8B949E),
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: selected ? const Color(0xFF388BFD) : const Color(0xFF8B949E).withOpacity(0.2),
                      ),
                    ),
                    onSelected: (_) => setState(() => _editType = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due Date', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                subtitle: Text(
                  '${_editDueDate.month}/${_editDueDate.day}/${_editDueDate.year}',
                  style: const TextStyle(color: Color(0xFFE6EDF3), fontWeight: FontWeight.w600, fontSize: 15),
                ),
                trailing: const Icon(Icons.calendar_today, color: Color(0xFF8B949E)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _editDueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF388BFD),
                          surface: Color(0xFF161B22),
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _editDueDate = picked);
                },
              ),

              const SizedBox(height: 12),
              const Text('Priority', style: TextStyle(fontSize: 13, color: Color(0xFF8B949E))),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Low')),
                  ButtonSegment(value: 2, label: Text('Normal')),
                  ButtonSegment(value: 3, label: Text('High')),
                  ButtonSegment(value: 4, label: Text('URGENT')),
                ],
                selected: {_editPriority},
                onSelectionChanged: (sel) {
                  if (sel.isNotEmpty) setState(() => _editPriority = sel.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF388BFD).withOpacity(0.2);
                    }
                    return const Color(0xFF0D1117);
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF388BFD);
                    }
                    return const Color(0xFF8B949E);
                  }),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closeEditSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8B949E),
                        side: BorderSide(color: const Color(0xFF8B949E).withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _updateAssignment,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF388BFD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Color(0xFFE6EDF3)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6E7681)),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildAssignmentCard(Event event) {
    final progress = _getEffectiveProgress(event);
    final isOverdue = _isOverdue(event.deadlineMillis ?? 0);
    final course = event.subjectTag ?? 'General';
    final courseColor = _getCourseColor(course);
    final type = _getAssignmentType(event);
    final sts = _getSubtasksForEvent(event.id ?? 0);
    final isCompleted = event.isCompleted;

    Color borderColor;
    if (isCompleted) {
      borderColor = const Color(0xFF3FB950).withOpacity(0.2);
    } else if (isOverdue) {
      borderColor = const Color(0xFFDA3633).withOpacity(0.3);
    } else {
      borderColor = courseColor.withOpacity(0.2);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            if (isOverdue && !isCompleted) const Color(0xFFDA3633).withOpacity(0.04),
            if (!isOverdue || isCompleted) courseColor.withOpacity(0.04),
            const Color(0xFF0D1117).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                color: isCompleted
                    ? const Color(0xFF3FB950)
                    : isOverdue
                        ? const Color(0xFFDA3633)
                        : courseColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: courseColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(type.icon, color: courseColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isCompleted ? const Color(0xFF6E7681) : const Color(0xFFE6EDF3),
                                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (isOverdue && !isCompleted)
                                      _badge('OVERDUE', const Color(0xFFFF7B72), const Color(0xFFDA3633)),
                                    if (!isCompleted && event.priority == 4 && !isOverdue)
                                      _badge('URGENT', const Color(0xFFF0883E), const Color(0xFFF0883E)),
                                    if (isCompleted)
                                      _badge('DONE', const Color(0xFF3FB950), const Color(0xFF3FB950)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$course • ${_timeRemaining(event.deadlineMillis ?? 0)}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                                ),
                                Text(
                                  'Due: ${_formatDate(event.deadlineMillis ?? 0)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6E7681)),
                                ),
                              ],
                            ),
                          ),
                          // Checkbox
                          Transform.scale(
                            scale: 1.1,
                            child: Checkbox(
                              value: isCompleted,
                              onChanged: (_) => _toggleComplete(event),
                              activeColor: const Color(0xFF3FB950),
                              side: const BorderSide(color: Color(0xFF8B949E)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ),

                      // Subtasks
                      if (sts.isNotEmpty && !isCompleted) ...[
                        const SizedBox(height: 10),
                        ...sts.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: GestureDetector(
                                onTap: () => _toggleSubtask(s),
                                child: Row(
                                  children: [
                                    Icon(
                                      s.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                                      size: 16,
                                      color: s.isCompleted ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      s.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: s.isCompleted ? const Color(0xFF6E7681) : const Color(0xFFE6EDF3),
                                        decoration: s.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                      ],

                      // Progress segments (only if no subtasks, or show both)
                      if (!isCompleted) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [0.0, 0.25, 0.5, 0.75].map((segment) {
                                  final isFilled = progress >= segment + 0.25;
                                  final isCurrent = progress >= segment && progress < segment + 0.25;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () => _updateProgress(event, segment + 0.25),
                                      child: Container(
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: isFilled
                                              ? _urgencyColor(event.deadlineMillis ?? 0)
                                              : isCurrent
                                                  ? _urgencyColor(event.deadlineMillis ?? 0).withOpacity(0.4)
                                                  : const Color(0xFF8B949E).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: progress >= 1.0
                                    ? const Color(0xFF3FB950).withOpacity(0.15)
                                    : const Color(0xFF388BFD).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: progress >= 1.0 ? const Color(0xFF3FB950) : const Color(0xFF388BFD),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Actions
                      if (!isCompleted) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _actionButton('Edit', const Color(0xFF388BFD), () => _openEditSheet(event)),
                            const SizedBox(width: 8),
                            _actionButton('Delete', const Color(0xFFDA3633), () => _deleteAssignment(event)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color textColor, Color borderColor) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: borderColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isCompletedFilter = _quickFilter == 'completed';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF388BFD).withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              isCompletedFilter ? Icons.check_circle_outline : Icons.assignment_outlined,
              size: 40,
              color: const Color(0xFF388BFD),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isCompletedFilter ? 'No completed assignments' : 'No assignments yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE6EDF3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompletedFilter
                ? 'Complete some assignments to see them here'
                : 'Tap the + button to add your first assignment',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8B949E), height: 1.5),
          ),
          if (!isCompletedFilter) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => setState(() => _isQuickAddExpanded = true),
              icon: const Icon(Icons.add),
              label: const Text('Add Assignment'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF388BFD),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<AssignmentSort> _sortItem(AssignmentSort value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF8B949E), size: 20),
        title: Text(label, style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 14)),
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _courseController.dispose();
    _subtaskController.dispose();
    _editTitleController.dispose();
    _editCourseController.dispose();
    super.dispose();
  }
}

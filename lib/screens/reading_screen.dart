// FILE: lib/screens/reading_screen.dart
// COMPLETE REPLACEMENT — Academic Reading System with Note Integration
// FEATURES: Book list, progress tracking, reading schedule, notes, citation generator,
//           reading stats, consistency graph, today widget, color picker, subject picker
// FIXED: Inlined color picker & subject picker to avoid missing imports
// FIXED: Consistency graph now pulls real data from reading_sessions table
// NEET-ENHANCED: PCB subject presets, med-prep branding touches

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:event_countdown/database_helper.dart';

// ═══════════════════════════════════════════════════════════════
// READING SCREEN — Main Book List
// ═══════════════════════════════════════════════════════════════

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _completedBooks = [];
  Map<String, dynamic>? _overallStats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final allBooks = await DatabaseHelper.instance.getAllReadingBooks(includeCompleted: true);
    final active = allBooks.where((b) => (b['isCompleted'] as int? ?? 0) == 0).toList();
    final completed = allBooks.where((b) => (b['isCompleted'] as int? ?? 0) == 1).toList();
    final stats = await DatabaseHelper.instance.getOverallReadingStats();
    if (mounted) {
      setState(() {
        _books = active;
        _completedBooks = completed;
        _overallStats = stats;
        _loading = false;
      });
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2196F3);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  Color _subjectColor(String? subject) {
    final colors = {
      'Physics': const Color(0xFF1565C0),
      'Chemistry': const Color(0xFF2E7D32),
      'Biology': const Color(0xFFC62828),
      'Zoology': const Color(0xFFAD1457),
      'Botany': const Color(0xFF00695C),
      'Math': const Color(0xFF2196F3),
      'Computer Science': const Color(0xFF00BCD4),
      'Economics': const Color(0xFF795548),
    };
    return colors[subject] ?? const Color(0xFF607D8B);
  }

  String _statusText(Map<String, dynamic> book, Map<String, dynamic>? progress) {
    if ((book['isCompleted'] as int? ?? 0) == 1) return 'Completed';
    final currentPage = (book['currentPage'] as int? ?? 0);
    if (currentPage == 0) return 'Not Started';
    if (progress == null) return 'In Progress';
    final onTrack = progress['onTrack'] as bool? ?? true;
    return onTrack ? 'On Track' : 'Behind';
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'Completed': return Colors.green;
      case 'On Track': return Colors.green.shade600;
      case 'Behind': return Colors.orange;
      case 'Not Started': return cs.outline;
      default: return cs.primary;
    }
  }

  Future<void> _showAddBookSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddBookSheet(),
    );
    if (result != null) {
      await DatabaseHelper.instance.insertReadingBook(result);
      HapticFeedback.mediumImpact();
      await _loadData();
    }
  }

  Future<void> _deleteBook(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Book?'),
        content: const Text('All reading progress and notes will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteReadingBook(id);
      await _loadData();
    }
  }

  void _openBookDetail(int bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailScreen(
          bookId: bookId,
          onUpdate: _loadData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Tracker'),
        actions: [
          if (_overallStats != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_overallStats!['completedBooks']}/${_overallStats!['totalBooks']} 📚',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  if (_books.isNotEmpty)
                    SliverToBoxAdapter(child: _ReadingScheduleWidget(books: _books)),
                  SliverToBoxAdapter(child: _TodayWidget(books: _books, onLogSession: _loadData)),
                  if (_overallStats != null)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [cs.primaryContainer, cs.secondaryContainer]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _statColumn('${_overallStats!['totalBooks']}', 'Books', Icons.menu_book, cs)),
                            Container(width: 1, height: 40, color: cs.outline.withOpacity(0.3)),
                            Expanded(child: _statColumn('${_overallStats!['totalPagesRead']}', 'Pages Read', Icons.auto_stories, cs)),
                            Container(width: 1, height: 40, color: cs.outline.withOpacity(0.3)),
                            Expanded(child: _statColumn('${(_overallStats!['totalMinutesRead'] as int? ?? 0) ~/ 60}h', 'Time Read', Icons.timer, cs)),
                          ],
                        ),
                      ),
                    ),
                  if (_books.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text('Currently Reading', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildBookCard(_books[index], cs),
                          childCount: _books.length,
                        ),
                      ),
                    ),
                  ],
                  if (_books.isEmpty && _completedBooks.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book_outlined, size: 72, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No books yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('Tap + to start tracking a book', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  if (_completedBooks.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Text('Completed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildBookCard(_completedBooks[index], cs, isCompleted: true),
                          childCount: _completedBooks.length,
                        ),
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
    );
  }

  Widget _statColumn(String value, String label, IconData icon, ColorScheme cs) {
    return Column(
      children: [
        Icon(icon, size: 20, color: cs.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, ColorScheme cs, {bool isCompleted = false}) {
    final bookId = book['id'] as int;
    final title = (book['title'] as String?) ?? 'Untitled';
    final author = (book['author'] as String?) ?? 'Unknown Author';
    final totalPages = (book['totalPages'] as int?) ?? 1;
    final currentPage = (book['currentPage'] as int?) ?? 0;
    final subject = book['subjectName'] as String?;
    final color = subject != null ? _subjectColor(subject) : _parseColor(book['colorHex'] as String?);
    final progress = totalPages > 0 ? currentPage / totalPages : 0.0;
    final percent = (progress * 100).round();
    final totalMinutes = (book['totalMinutesRead'] as int?) ?? 0;
    final pagesPerMin = totalMinutes > 0 ? (currentPage / totalMinutes).toStringAsFixed(2) : '—';

    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getReadingProgress(bookId),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final daysLeft = stats?['daysLeft'] as int? ?? 0;
        final pagesPerDayNeeded = stats?['pagesPerDayNeeded'] as int? ?? 0;
        final status = _statusText(book, stats);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outline.withOpacity(0.15)),
          ),
          child: InkWell(
            onTap: () => _openBookDetail(bookId),
            onLongPress: () => _deleteBook(bookId),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.7), color],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))],
                        ),
                        child: Center(
                          child: Text(
                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(author, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                            if (subject != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                child: Text(subject, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _statusColor(status, cs).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _statusColor(status, cs).withOpacity(0.4)),
                            ),
                            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _statusColor(status, cs))),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
                            child: Text('$percent%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(isCompleted ? Colors.green : color),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Page $currentPage of $totalPages', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                      if (!isCompleted) ...[
                        Text('$pagesPerMin pgs/min', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        if (daysLeft > 0) Text('$daysLeft days left', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                  if (!isCompleted && pagesPerDayNeeded > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pagesPerDayNeeded > 50 ? Colors.red.withOpacity(0.1) : cs.secondaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$pagesPerDayNeeded pages/day to finish on time',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pagesPerDayNeeded > 50 ? Colors.red : cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReadingScheduleWidget extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  const _ReadingScheduleWidget({required this.books});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    int totalPagesNeeded = 0;
    int totalDays = 0;

    for (final book in books) {
      final targetEnd = book['targetEndDateMillis'] as int?;
      if (targetEnd == null) continue;
      final targetDate = DateTime.fromMillisecondsSinceEpoch(targetEnd);
      final daysLeft = targetDate.difference(now).inDays;
      if (daysLeft <= 0) continue;
      final pagesLeft = (book['totalPages'] as int? ?? 0) - (book['currentPage'] as int? ?? 0);
      if (pagesLeft > 0) {
        totalPagesNeeded += pagesLeft;
        totalDays += daysLeft;
      }
    }

    if (totalPagesNeeded == 0 || totalDays == 0) return const SizedBox.shrink();

    final avgPerDay = (totalPagesNeeded / totalDays).ceil();
    final isUnrealistic = avgPerDay > 50;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnrealistic ? Colors.red.withOpacity(0.08) : cs.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnrealistic ? Colors.red.withOpacity(0.3) : cs.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(isUnrealistic ? Icons.warning_amber_rounded : Icons.schedule, color: isUnrealistic ? Colors.red : cs.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text('You need to read $avgPerDay pages/day across ${books.length} book(s)', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                if (isUnrealistic)
                  Text('⚠️ This goal may be unrealistic. Consider extending deadlines.', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayWidget extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  final VoidCallback onLogSession;
  const _TodayWidget({required this.books, required this.onLogSession});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    bool hasReadingToday = false;
    int dailyGoal = 20;
    for (final book in books) {
      final minutesToday = (book['minutesReadToday'] as int?) ?? 0;
      if (minutesToday > 0) hasReadingToday = true;
      final goal = (book['dailyPageGoal'] as int?) ?? 20;
      if (goal > dailyGoal) dailyGoal = goal;
    }
    if (hasReadingToday || books.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.tertiary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.today, color: cs.tertiary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No reading logged today', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
                Text('Daily goal: $dailyGoal pages', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () async {
              if (books.isNotEmpty) {
                final firstBook = books.first;
                final bookId = firstBook['id'] as int;
                final currentPage = (firstBook['currentPage'] as int?) ?? 0;
                final totalPages = (firstBook['totalPages'] as int?) ?? 1;
                final newPage = math.min(currentPage + dailyGoal, totalPages);
                await DatabaseHelper.instance.updateReadingProgress(bookId, newPage, 20);
                HapticFeedback.lightImpact();
                onLogSession();
              }
            },
            child: const Text('Log 20 min'),
          ),
        ],
      ),
    );
  }
}

class _AddBookSheet extends StatefulWidget {
  const _AddBookSheet();
  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _pagesController = TextEditingController();
  String? _selectedSubject;
  DateTime? _targetDate;
  int _dailyGoal = 20;
  Color _selectedColor = Colors.blue;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  void _pickColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (ctx) => SimpleColorPickerDialog(initialColor: _selectedColor),
    );
    if (color != null && mounted) setState(() => _selectedColor = color);
  }

  void _pickSubject() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SubjectPickerSheet(selectedSubjectName: _selectedSubject),
    );
    if (result != null && mounted) setState(() => _selectedSubject = result);
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null && mounted) setState(() => _targetDate = picked);
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    final pages = int.tryParse(_pagesController.text.trim());
    if (pages == null || pages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valid page count is required')));
      return;
    }
    final colorHex = '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
    Navigator.pop(context, {
      'title': _titleController.text.trim(),
      'author': _authorController.text.trim().isEmpty ? null : _authorController.text.trim(),
      'totalPages': pages,
      'subjectName': _selectedSubject,
      'colorHex': colorHex,
      'targetEndDateMillis': _targetDate != null ? DateTime(_targetDate!.year, _targetDate!.month, _targetDate!.day).millisecondsSinceEpoch : null,
      'dailyPageGoal': _dailyGoal,
      'startDateMillis': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Add New Book', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Book Title *', prefixIcon: Icon(Icons.menu_book))),
                  const SizedBox(height: 12),
                  TextField(controller: _authorController, decoration: const InputDecoration(labelText: 'Author', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pagesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Total Pages *', prefixIcon: Icon(Icons.format_list_numbered)),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Subject', style: TextStyle(fontSize: 12)),
                    subtitle: Text(_selectedSubject ?? 'None selected', style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _pickSubject,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Book Color', style: TextStyle(fontSize: 12)),
                    trailing: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: _selectedColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outline)),
                    ),
                    onTap: _pickColor,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Target Finish Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      _targetDate != null ? '${_targetDate!.month}/${_targetDate!.day}/${_targetDate!.year}' : 'Not set (auto-calculated)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _dailyGoal,
                    decoration: const InputDecoration(labelText: 'Daily Page Goal', prefixIcon: Icon(Icons.timer)),
                    items: [10, 15, 20, 25, 30, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n pages/day'))).toList(),
                    onChanged: (v) => setState(() => _dailyGoal = v!),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.add), label: const Text('Add Book'))),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  final VoidCallback onUpdate;
  const BookDetailScreen({super.key, required this.bookId, required this.onUpdate});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  Map<String, dynamic>? _book;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final book = await DatabaseHelper.instance.getReadingBookById(widget.bookId);
    final progress = await DatabaseHelper.instance.getReadingProgress(widget.bookId);
    final notes = await _loadNotes();
    if (mounted) {
      setState(() {
        _book = book;
        _progress = progress;
        _notes = notes;
        _currentPage = (book?['currentPage'] as int?) ?? 0;
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadNotes() async {
    final allNotes = await DatabaseHelper.instance.getAllQuickNotes();
    return allNotes.where((n) {
      final subject = n['subject'] as String? ?? '';
      return subject == 'Reading:${widget.bookId}';
    }).toList();
  }

  Color _bookColor() {
    final subject = _book?['subjectName'] as String?;
    if (subject != null) {
      final colors = {
        'Physics': const Color(0xFF1565C0),
        'Chemistry': const Color(0xFF2E7D32),
        'Biology': const Color(0xFFC62828),
        'Zoology': const Color(0xFFAD1457),
        'Botany': const Color(0xFF00695C),
        'Math': const Color(0xFF2196F3),
        'Computer Science': const Color(0xFF00BCD4),
        'Economics': const Color(0xFF795548),
      };
      return colors[subject] ?? const Color(0xFF607D8B);
    }
    final hex = _book?['colorHex'] as String?;
    if (hex != null && hex.isNotEmpty) {
      try {
        return Color(int.parse(hex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return const Color(0xFF2196F3);
  }

  Future<void> _updatePage(int newPage) async {
    final totalPages = (_book?['totalPages'] as int?) ?? 1;
    final clamped = newPage.clamp(0, totalPages);
    if (clamped == _currentPage) return;
    setState(() => _currentPage = clamped);
  }

  Future<void> _savePage() async {
    if (_book == null) return;
    final oldPage = (_book?['currentPage'] as int?) ?? 0;
    if (_currentPage == oldPage) return;
    await DatabaseHelper.instance.updateReadingBook(widget.bookId, {..._book!, 'currentPage': _currentPage});
    HapticFeedback.lightImpact();
    await _loadData();
    widget.onUpdate();
  }

  Future<void> _logSession() async {
    final result = await showDialog<Map<String, dynamic>?>(context: context, builder: (ctx) => const _LogSessionDialog());
    if (result == null) return;
    final minutes = result['minutes'] as int;
    final pagesRead = result['pagesRead'] as int;
    final newPage = _currentPage + pagesRead;
    final totalPages = (_book?['totalPages'] as int?) ?? 1;
    final clampedPage = newPage.clamp(0, totalPages);
    await DatabaseHelper.instance.updateReadingProgress(widget.bookId, clampedPage, minutes);
    HapticFeedback.lightImpact();
    await _loadData();
    widget.onUpdate();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session saved! $pagesRead pages in $minutes min')));
    }
  }

  Future<void> _addNote() async {
    final result = await showDialog<Map<String, dynamic>?>(context: context, builder: (ctx) => _AddNoteDialog(currentPage: _currentPage));
    if (result == null) return;
    await DatabaseHelper.instance.insertQuickNote({
      'title': result['title'],
      'content': result['content'],
      'subject': 'Reading:${widget.bookId}',
    });
    HapticFeedback.lightImpact();
    await _loadData();
  }

  Future<void> _deleteNote(int noteId) async {
    await DatabaseHelper.instance.deleteQuickNote(noteId);
    await _loadData();
  }

  Future<void> _showCitationDialog() async {
    await showDialog(context: context, builder: (ctx) => _CitationDialog(book: _book!, currentPage: _currentPage));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_book == null) return const Scaffold(body: Center(child: Text('Book not found')));

    final title = (_book?['title'] as String?) ?? 'Unknown';
    final author = (_book?['author'] as String?) ?? 'Unknown Author';
    final totalPages = (_book?['totalPages'] as int?) ?? 1;
    final totalMinutes = (_book?['totalMinutesRead'] as int?) ?? 0;
    final progress = totalPages > 0 ? _currentPage / totalPages : 0.0;
    final percent = (progress * 100).round();
    final color = _bookColor();
    final pagesPerMin = totalMinutes > 0 ? (_currentPage / totalMinutes).toStringAsFixed(2) : '0.00';
    final pagesLeft = totalPages - _currentPage;
    final estMinutesLeft = double.tryParse(pagesPerMin) != null && double.parse(pagesPerMin) > 0 ? (pagesLeft / double.parse(pagesPerMin)).ceil() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [IconButton(icon: const Icon(Icons.format_quote), tooltip: 'Citation', onPressed: _showCitationDialog)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$percent%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: cs.onSurface)),
                      Text('$totalPages pages', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(author, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Current Page', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pageButton(-25, cs),
                        _pageButton(-10, cs),
                        _pageButton(-5, cs),
                        Container(
                          width: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            controller: TextEditingController(text: '$_currentPage'),
                            onSubmitted: (v) {
                              final newPage = int.tryParse(v) ?? _currentPage;
                              _updatePage(newPage);
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        _pageButton(5, cs),
                        _pageButton(10, cs),
                        _pageButton(25, cs),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _savePage, icon: const Icon(Icons.save), label: const Text('Update Page'))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: _logSession, icon: const Icon(Icons.timer), label: const Text('Log Reading Session'))),
            const SizedBox(height: 24),
            _buildStatsSection(cs, totalMinutes, pagesPerMin, estMinutesLeft, pagesLeft),
            const SizedBox(height: 24),
            _buildConsistencyGraph(cs),
            const SizedBox(height: 24),
            _buildNotesSection(cs),
          ],
        ),
      ),
    );
  }

  Widget _pageButton(int delta, ColorScheme cs) {
    return IconButton(
      onPressed: () => _updatePage(_currentPage + delta),
      icon: Text(delta > 0 ? '+$delta' : '$delta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
      style: IconButton.styleFrom(backgroundColor: cs.primaryContainer.withOpacity(0.5)),
    );
  }

  Widget _buildStatsSection(ColorScheme cs, int totalMinutes, String pagesPerMin, int estMinutesLeft, int pagesLeft) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reading Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _statBox('${totalMinutes ~/ 60}h ${totalMinutes % 60}m', 'Total Time', Icons.timer, cs)),
                const SizedBox(width: 12),
                Expanded(child: _statBox(pagesPerMin, 'Pages/Min', Icons.speed, cs)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statBox('$pagesLeft', 'Pages Left', Icons.menu_book, cs)),
                const SizedBox(width: 12),
                Expanded(child: _statBox(estMinutesLeft > 0 ? '${estMinutesLeft ~/ 60}h ${estMinutesLeft % 60}m' : '—', 'Est. Time Left', Icons.hourglass_empty, cs)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String value, String label, IconData icon, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildConsistencyGraph(ColorScheme cs) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getPagesPerDayHistory(widget.bookId, 14),
      builder: (context, snapshot) {
        final days = snapshot.data ?? [];
        if (days.isEmpty || days.every((d) => (d['pages'] as int) == 0)) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading Consistency (Last 14 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 24),
                  Center(child: Text('No session data yet. Log a reading session to see your graph!', style: TextStyle(color: cs.outline, fontSize: 13))),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }

        final maxPages = days.map((d) => d['pages'] as int).fold(0, math.max);
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reading Consistency (Last 14 Days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: days.map((day) {
                      final pages = day['pages'] as int;
                      final height = maxPages > 0 ? (pages / maxPages) * 100 : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: height,
                                decoration: BoxDecoration(color: cs.primary.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                              ),
                              const SizedBox(height: 4),
                              Text(day['date'] as String, style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesSection(ColorScheme cs) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reading Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                FilledButton.tonalIcon(onPressed: _addNote, icon: const Icon(Icons.add, size: 16), label: const Text('Add', style: TextStyle(fontSize: 12))),
              ],
            ),
            const SizedBox(height: 12),
            if (_notes.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('No notes yet. Add one!', style: TextStyle(color: cs.outline))))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  final title = (note['title'] as String?) ?? 'Note';
                  final content = (note['content'] as String?) ?? '';
                  final createdAt = note['createdAtMillis'] as int?;
                  final dateStr = createdAt != null ? DateTime.fromMillisecondsSinceEpoch(createdAt).toString().substring(0, 16) : '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('$content\n$dateStr', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    isThreeLine: true,
                    trailing: IconButton(icon: Icon(Icons.delete_outline, size: 18, color: cs.error), onPressed: () => _deleteNote(note['id'] as int)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LogSessionDialog extends StatefulWidget {
  const _LogSessionDialog();
  @override
  State<_LogSessionDialog> createState() => _LogSessionDialogState();
}

class _LogSessionDialogState extends State<_LogSessionDialog> {
  final _minutesController = TextEditingController(text: '20');
  final _pagesController = TextEditingController();
  @override
  void dispose() {
    _minutesController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log Reading Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutes Read *', prefixIcon: Icon(Icons.timer)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pagesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pages Read *', prefixIcon: Icon(Icons.menu_book)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final minutes = int.tryParse(_minutesController.text.trim());
            final pages = int.tryParse(_pagesController.text.trim());
            if (minutes == null || minutes <= 0 || pages == null || pages <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid numbers')));
              return;
            }
            Navigator.pop(context, {'minutes': minutes, 'pagesRead': pages});
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  final int currentPage;
  const _AddNoteDialog({required this.currentPage});
  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Note at Page ${widget.currentPage}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Note Title', prefixIcon: Icon(Icons.title))),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note Content', prefixIcon: Icon(Icons.notes), alignLabelWithHint: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
              return;
            }
            Navigator.pop(context, {'title': _titleController.text.trim(), 'content': _contentController.text.trim()});
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CitationDialog extends StatefulWidget {
  final Map<String, dynamic> book;
  final int currentPage;
  const _CitationDialog({required this.book, required this.currentPage});
  @override
  State<_CitationDialog> createState() => _CitationDialogState();
}

class _CitationDialogState extends State<_CitationDialog> {
  CitationFormat _format = CitationFormat.apa;

  String _generateCitation() {
    final author = (widget.book['author'] as String?) ?? 'Unknown Author';
    final title = (widget.book['title'] as String?) ?? 'Untitled';
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startPage = math.max(1, widget.currentPage - 20);
    final pageRange = '$startPage-${widget.currentPage}';
    switch (_format) {
      case CitationFormat.apa:
        return '$author. (${now.year}). _${title}_. (pp. $pageRange). Retrieved $dateStr.';
      case CitationFormat.mla:
        return '$author. _${title}_. ${now.year}, pp. $pageRange.';
      case CitationFormat.chicago:
        return '$author, _${title}_ (${now.year}), $pageRange.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final citation = _generateCitation();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Citation Generator'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<CitationFormat>(
            segments: const [
              ButtonSegment(value: CitationFormat.apa, label: Text('APA')),
              ButtonSegment(value: CitationFormat.mla, label: Text('MLA')),
              ButtonSegment(value: CitationFormat.chicago, label: Text('Chicago')),
            ],
            selected: {_format},
            onSelectionChanged: (sel) {
              if (sel.isNotEmpty && mounted) setState(() => _format = sel.first);
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withOpacity(0.3)),
            ),
            child: SelectableText(
              citation,
              style: TextStyle(fontSize: 14, color: cs.onSurface, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(
          onPressed: () => Share.share(citation, subject: 'Citation for ${widget.book['title']}'),
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
      ],
    );
  }
}

enum CitationFormat { apa, mla, chicago }

// ═══════════════════════════════════════════════════════════════
// INLINED WIDGETS — No external imports needed
// ═══════════════════════════════════════════════════════════════

class SimpleColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  const SimpleColorPickerDialog({super.key, required this.initialColor});

  @override
  State<SimpleColorPickerDialog> createState() => _SimpleColorPickerDialogState();
}

class _SimpleColorPickerDialogState extends State<SimpleColorPickerDialog> {
  late Color _selected;

  final List<Color> _colors = [
    Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
    Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan,
    Colors.teal, Colors.green, Colors.lightGreen, Colors.lime,
    Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange,
    Colors.brown, Colors.grey, Colors.blueGrey, Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a Color'),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _colors.map((color) {
          final isSelected = color.value == _selected.value;
          return GestureDetector(
            onTap: () => setState(() => _selected = color),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)] : null,
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Select')),
      ],
    );
  }
}

class SubjectPickerSheet extends StatelessWidget {
  final String? selectedSubjectName;
  const SubjectPickerSheet({super.key, this.selectedSubjectName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subjects = [
      'Physics',
      'Chemistry',
      'Biology',
      'Zoology',
      'Botany',
      'Math',
      'Computer Science',
      'Economics',
      'History',
      'Literature',
      'General',
    ];

    return Container(
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Select Subject', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  final isSelected = subject == selectedSubjectName;
                  return ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _subjectColor(subject),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(subject),
                    trailing: isSelected ? Icon(Icons.check, color: cs.primary) : null,
                    onTap: () => Navigator.pop(context, subject),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _subjectColor(String subject) {
    final colors = {
      'Physics': const Color(0xFF1565C0),
      'Chemistry': const Color(0xFF2E7D32),
      'Biology': const Color(0xFFC62828),
      'Zoology': const Color(0xFFAD1457),
      'Botany': const Color(0xFF00695C),
      'Math': const Color(0xFF2196F3),
      'Computer Science': const Color(0xFF00BCD4),
      'Economics': const Color(0xFF795548),
      'History': const Color(0xFFFF9800),
      'Literature': const Color(0xFFE91E63),
      'General': const Color(0xFF607D8B),
    };
    return colors[subject] ?? const Color(0xFF607D8B);
  }
}

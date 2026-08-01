// FILE: lib/screens/reading_screen.dart
// COMPLETE REPLACEMENT — Academic Reading System v2.1
// FIXED: BookDetailScreen loading hang, widget refresh triggers, null-safety in DB calls

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:event_countdown/database_helper.dart';
import '../services/widget_service.dart';

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
  List<Map<String, dynamic>> _filteredBooks = [];
  Map<String, dynamic>? _overallStats;
  bool _loading = true;
  String _searchQuery = '';
  String? _filterSubject;
  SortMode _sortMode = SortMode.recent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final allBooks = await DatabaseHelper.instance.getAllReadingBooks(includeCompleted: true);
      final active = allBooks.where((b) => (b['isCompleted'] as int? ?? 0) == 0).toList();
      final completed = allBooks.where((b) => (b['isCompleted'] as int? ?? 0) == 1).toList();
      final stats = await DatabaseHelper.instance.getOverallReadingStats();
      if (mounted) {
        setState(() {
          _books = active;
          _completedBooks = completed;
          _overallStats = stats;
          _applyFilters();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ReadingScreen._loadData error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_books);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((b) {
        final title = ((b['title'] as String?) ?? '').toLowerCase();
        final author = ((b['author'] as String?) ?? '').toLowerCase();
        final subject = ((b['subjectName'] as String?) ?? '').toLowerCase();
        return title.contains(q) || author.contains(q) || subject.contains(q);
      }).toList();
    }
    if (_filterSubject != null && _filterSubject != 'All') {
      result = result.where((b) => (b['subjectName'] as String?) == _filterSubject).toList();
    }
    switch (_sortMode) {
      case SortMode.recent:
        result.sort((a, b) => (b['createdAtMillis'] as int? ?? 0).compareTo(a['createdAtMillis'] as int? ?? 0));
      case SortMode.progress:
        result.sort((a, b) {
          final pa = ((a['currentPage'] as int? ?? 0) / (a['totalPages'] as int? ?? 1));
          final pb = ((b['currentPage'] as int? ?? 0) / (b['totalPages'] as int? ?? 1));
          return pb.compareTo(pa);
        });
      case SortMode.title:
        result.sort((a, b) => ((a['title'] as String?) ?? '').compareTo((b['title'] as String?) ?? ''));
      case SortMode.subject:
        result.sort((a, b) => ((a['subjectName'] as String?) ?? '').compareTo((b['subjectName'] as String?) ?? ''));
      case SortMode.pagesLeft:
        result.sort((a, b) {
          final la = ((a['totalPages'] as int? ?? 0) - (a['currentPage'] as int? ?? 0));
          final lb = ((b['totalPages'] as int? ?? 0) - (b['currentPage'] as int? ?? 0));
          return la.compareTo(lb);
        });
    }
    _filteredBooks = result;
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF2196F3);
    try {
      String h = hex.trim();
      if (h.startsWith('#')) h = h.substring(1);
      if (h.length == 3) h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
      if (h.length == 6) return Color(int.parse('0xFF$h'));
      if (h.length == 8) return Color(int.parse('0x$h'));
      return const Color(0xFF2196F3);
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
      'History': const Color(0xFFFF9800),
      'Literature': const Color(0xFFE91E63),
      'General': const Color(0xFF607D8B),
    };
    return colors[subject] ?? const Color(0xFF607D8B);
  }

  List<String> _getAllSubjects() {
    final subjects = <String>{'All'};
    for (final b in [..._books, ..._completedBooks]) {
      final s = b['subjectName'] as String?;
      if (s != null && s.isNotEmpty) subjects.add(s);
    }
    return subjects.toList()..sort();
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

  Future<void> _showAddBookSheet({Map<String, dynamic>? existingBook}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddBookSheet(existingBook: existingBook),
    );
    if (result != null) {
      try {
        if (existingBook != null) {
          await DatabaseHelper.instance.updateReadingBook(existingBook['id'] as int, result);
        } else {
          await DatabaseHelper.instance.insertReadingBook(result);
        }
        HapticFeedback.mediumImpact();
        await _loadData();
        await WidgetService.refreshReadingWidget();
      } catch (e) {
        debugPrint('Error saving book: $e');
      }
    }
  }

  Future<void> _deleteBook(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Book?'),
        content: const Text('All reading progress, sessions, and notes will be permanently lost.'),
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
      try {
        await DatabaseHelper.instance.deleteReadingBook(id);
        await _loadData();
        await WidgetService.refreshReadingWidget();
      } catch (e) {
        debugPrint('Error deleting book: $e');
      }
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

  Future<void> _resetDailyStats() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset Daily Stats?'),
        content: const Text('This will reset "minutes read today" for all books.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DatabaseHelper.instance.resetDailyReadingStats();
        await _loadData();
      } catch (e) {
        debugPrint('Error resetting stats: $e');
      }
    }
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
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_overallStats!['completedBooks']}/${_overallStats!['totalBooks']} 📚',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') _resetDailyStats();
              if (value == 'sort') _showSortDialog();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'sort', child: Row(children: [Icon(Icons.sort), SizedBox(width: 8), Text('Sort Books')])),
              const PopupMenuItem(value: 'reset', child: Row(children: [Icon(Icons.refresh), SizedBox(width: 8), Text('Reset Daily Stats')])),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (v) {
                              setState(() {
                                _searchQuery = v;
                                _applyFilters();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search books, authors, subjects...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = '';
                                          _applyFilters();
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _getAllSubjects().map((subject) {
                                final isSelected = _filterSubject == subject || (subject == 'All' && _filterSubject == null);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    selected: isSelected,
                                    label: Text(subject),
                                    onSelected: (_) {
                                      setState(() {
                                        _filterSubject = subject == 'All' ? null : subject;
                                        _applyFilters();
                                      });
                                    },
                                    backgroundColor: cs.surfaceContainerHighest,
                                    selectedColor: cs.primaryContainer,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
                            Expanded(child: _statColumn(_formatDuration(_overallStats!['totalMinutesRead'] as int? ?? 0), 'Time Read', Icons.timer, cs)),
                          ],
                        ),
                      ),
                    ),
                  if (_filteredBooks.isNotEmpty) ...[
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
                          (context, index) => _buildBookCard(_filteredBooks[index], cs),
                          childCount: _filteredBooks.length,
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
                  if (_books.isNotEmpty && _filteredBooks.isEmpty && _searchQuery.isNotEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No books match your search', style: TextStyle(fontSize: 16, color: Colors.grey)),
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
        onPressed: () => _showAddBookSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
    );
  }

  String _formatDuration(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  Future<void> _showSortDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sort Books'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SortMode.values.map((mode) {
            return RadioListTile<SortMode>(
              title: Text(_sortLabel(mode)),
              value: mode,
              groupValue: _sortMode,
              onChanged: (v) {
                Navigator.pop(ctx);
                setState(() {
                  _sortMode = v!;
                  _applyFilters();
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _sortLabel(SortMode mode) {
    switch (mode) {
      case SortMode.recent: return 'Recently Added';
      case SortMode.progress: return 'Most Progress';
      case SortMode.title: return 'Title (A-Z)';
      case SortMode.subject: return 'Subject';
      case SortMode.pagesLeft: return 'Pages Left';
    }
  }

  Widget _statColumn(String value, String label, IconData icon, ColorScheme cs) {
    return Column(
      children: [
        Icon(icon, size: 20, color: cs.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

    // FIXED: Remove FutureBuilder from card — compute simple stats inline to avoid hangs
    final daysLeft = book['targetEndDateMillis'] != null
        ? DateTime.fromMillisecondsSinceEpoch(book['targetEndDateMillis'] as int).difference(DateTime.now()).inDays
        : 0;
    final pagesLeft = totalPages - currentPage;
    final pagesPerDayNeeded = daysLeft > 0 && pagesLeft > 0 ? (pagesLeft / daysLeft).ceil() : 0;
    final status = _statusText(book, null);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withOpacity(0.15)),
      ),
      child: InkWell(
        onTap: () => _openBookDetail(bookId),
        onLongPress: () => _showBookOptions(bookId, book),
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
  }

  Future<void> _showBookOptions(int bookId, Map<String, dynamic> book) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 12, bottom: 16), width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
              ListTile(leading: const Icon(Icons.edit), title: const Text('Edit Book'), onTap: () => Navigator.pop(ctx, 'edit')),
              ListTile(leading: Icon(Icons.delete, color: Colors.red), title: const Text('Delete Book', style: TextStyle(color: Colors.red)), onTap: () => Navigator.pop(ctx, 'delete')),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (result == 'edit') {
      await _showAddBookSheet(existingBook: book);
    } else if (result == 'delete') {
      await _deleteBook(bookId);
    }
  }
}

enum SortMode { recent, progress, title, subject, pagesLeft }

class _ReadingScheduleWidget extends StatelessWidget {
  final List<Map<String, dynamic>> books;
  const _ReadingScheduleWidget({required this.books});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    int totalPagesNeeded = 0;
    int totalDays = 0;
    int booksWithDeadline = 0;

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
        booksWithDeadline++;
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
                Text('You need to read $avgPerDay pages/day across $booksWithDeadline book(s)', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
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
                try {
                  await DatabaseHelper.instance.updateReadingProgress(bookId, newPage, 20);
                  HapticFeedback.lightImpact();
                  onLogSession();
                  await WidgetService.refreshReadingWidget();
                } catch (e) {
                  debugPrint('Error logging session: $e');
                }
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
  final Map<String, dynamic>? existingBook;
  const _AddBookSheet({this.existingBook});
  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _pagesController;
  String? _selectedSubject;
  DateTime? _targetDate;
  int _dailyGoal = 20;
  Color _selectedColor = Colors.blue;
  bool get _isEditing => widget.existingBook != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final b = widget.existingBook!;
      _titleController = TextEditingController(text: b['title'] as String? ?? '');
      _authorController = TextEditingController(text: b['author'] as String? ?? '');
      _pagesController = TextEditingController(text: '${b['totalPages'] as int? ?? 0}');
      _selectedSubject = b['subjectName'] as String?;
      _dailyGoal = b['dailyPageGoal'] as int? ?? 20;
      final targetMillis = b['targetEndDateMillis'] as int?;
      if (targetMillis != null) _targetDate = DateTime.fromMillisecondsSinceEpoch(targetMillis);
      final hex = b['colorHex'] as String?;
      if (hex != null && hex.isNotEmpty) {
        try {
          _selectedColor = Color(int.parse(hex.replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
    } else {
      _titleController = TextEditingController();
      _authorController = TextEditingController();
      _pagesController = TextEditingController();
    }
  }

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
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
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
      'startDateMillis': _isEditing
          ? widget.existingBook!['startDateMillis']
          : DateTime.now().millisecondsSinceEpoch,
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
              child: Text(_isEditing ? 'Edit Book' : 'Add New Book', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
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
                  SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _save, icon: Icon(_isEditing ? Icons.save : Icons.add), label: Text(_isEditing ? 'Save Changes' : 'Add Book'))),
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

// ═══════════════════════════════════════════════════════════════
// BOOK DETAIL SCREEN — FIXED: No hanging, all DB calls wrapped
// ═══════════════════════════════════════════════════════════════

class BookDetailScreen extends StatefulWidget {
  final int bookId;
  final VoidCallback onUpdate;
  const BookDetailScreen({super.key, required this.bookId, required this.onUpdate});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _book;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  late TabController _tabController;
  late TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pageController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Use raw query fallback if methods don't exist
      Map<String, dynamic>? book;
      try {
        book = await DatabaseHelper.instance.getReadingBookById(widget.bookId);
      } catch (e) {
        debugPrint('getReadingBookById failed: $e');
        // Fallback: query directly
        final db = await DatabaseHelper.instance.database;
        final rows = await db.query('reading_books', where: 'id = ?', whereArgs: [widget.bookId]);
        if (rows.isNotEmpty) book = rows.first;
      }

      Map<String, dynamic>? progress;
      try {
        progress = await DatabaseHelper.instance.getReadingProgress(widget.bookId);
      } catch (e) {
        debugPrint('getReadingProgress failed: $e');
        // Compute simple progress locally
        if (book != null) {
          final totalPages = (book['totalPages'] as int?) ?? 1;
          final currentPage = (book['currentPage'] as int?) ?? 0;
          final pagesLeft = totalPages - currentPage;
          progress = {
            'onTrack': true,
            'daysLeft': book['targetEndDateMillis'] != null
                ? DateTime.fromMillisecondsSinceEpoch(book['targetEndDateMillis'] as int).difference(DateTime.now()).inDays
                : 0,
            'pagesPerDayNeeded': pagesLeft > 0 ? (pagesLeft / 30).ceil() : 0,
          };
        }
      }

      List<Map<String, dynamic>> notes = [];
      try {
        notes = await _loadNotes();
      } catch (e) {
        debugPrint('_loadNotes failed: $e');
      }

      List<Map<String, dynamic>> sessions = [];
      try {
        sessions = await DatabaseHelper.instance.getReadingSessionsForBook(widget.bookId, limit: 50);
      } catch (e) {
        debugPrint('getReadingSessionsForBook failed: $e');
      }

      if (mounted) {
        setState(() {
          _book = book;
          _progress = progress;
          _notes = notes;
          _sessions = sessions;
          _loading = false;
          final currentPage = (book?['currentPage'] as int?) ?? 0;
          _pageController.text = '$currentPage';
        });
      }
    } catch (e) {
      debugPrint('BookDetailScreen._loadData error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load book: $e';
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadNotes() async {
    try {
      final allNotes = await DatabaseHelper.instance.getAllQuickNotes();
      return allNotes.where((n) {
        final subject = n['subject'] as String? ?? '';
        return subject == 'Reading:${widget.bookId}';
      }).toList();
    } catch (e) {
      debugPrint('_loadNotes error: $e');
      return [];
    }
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
        'History': const Color(0xFFFF9800),
        'Literature': const Color(0xFFE91E63),
        'General': const Color(0xFF607D8B),
      };
      return colors[subject] ?? const Color(0xFF607D8B);
    }
    final hex = _book?['colorHex'] as String?;
    if (hex != null && hex.isNotEmpty) {
      try {
        String h = hex.trim();
        if (h.startsWith('#')) h = h.substring(1);
        if (h.length == 3) h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
        if (h.length == 6) return Color(int.parse('0xFF$h'));
        if (h.length == 8) return Color(int.parse('0x$h'));
      } catch (_) {}
    }
    return const Color(0xFF2196F3);
  }

  void _updatePage(int newPage) {
    final totalPages = (_book?['totalPages'] as int?) ?? 1;
    final clamped = newPage.clamp(0, totalPages);
    if (clamped.toString() == _pageController.text) return;
    _pageController.text = '$clamped';
    setState(() {});
  }

  Future<void> _savePage() async {
    if (_book == null) return;
    final newPage = int.tryParse(_pageController.text) ?? 0;
    final oldPage = (_book?['currentPage'] as int?) ?? 0;
    if (newPage == oldPage) return;
    try {
      await DatabaseHelper.instance.updateReadingBook(widget.bookId, {..._book!, 'currentPage': newPage});
      HapticFeedback.lightImpact();
      await _loadData();
      widget.onUpdate();
      await WidgetService.refreshReadingWidget();
    } catch (e) {
      debugPrint('Error saving page: $e');
    }
  }

  Future<void> _logSession() async {
    final result = await showDialog<Map<String, dynamic>?>(context: context, builder: (ctx) => const _LogSessionDialog());
    if (result == null) return;
    final minutes = result['minutes'] as int;
    final pagesRead = result['pagesRead'] as int;
    final currentPage = int.tryParse(_pageController.text) ?? 0;
    final newPage = currentPage + pagesRead;
    final totalPages = (_book?['totalPages'] as int?) ?? 1;
    final clampedPage = newPage.clamp(0, totalPages);
    try {
      await DatabaseHelper.instance.updateReadingProgress(widget.bookId, clampedPage, minutes);
      HapticFeedback.lightImpact();
      await _loadData();
      widget.onUpdate();
      await WidgetService.refreshReadingWidget();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Session saved! $pagesRead pages in $minutes min')));
      }
    } catch (e) {
      debugPrint('Error logging session: $e');
    }
  }

  Future<void> _addNote() async {
    final result = await showDialog<Map<String, dynamic>?>(context: context, builder: (ctx) => _AddNoteDialog(currentPage: int.tryParse(_pageController.text) ?? 0));
    if (result == null) return;
    try {
      await DatabaseHelper.instance.insertQuickNote({
        'title': result['title'],
        'content': result['content'],
        'subject': 'Reading:${widget.bookId}',
      });
      HapticFeedback.lightImpact();
      await _loadData();
    } catch (e) {
      debugPrint('Error adding note: $e');
    }
  }

  Future<void> _deleteNote(int noteId) async {
    try {
      await DatabaseHelper.instance.deleteQuickNote(noteId);
      await _loadData();
    } catch (e) {
      debugPrint('Error deleting note: $e');
    }
  }

  Future<void> _deleteSession(int sessionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Session?'),
        content: const Text('This will remove the session from your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteReadingSession(sessionId);
        await _loadData();
        widget.onUpdate();
        await WidgetService.refreshReadingWidget();
      } catch (e) {
        debugPrint('Error deleting session: $e');
      }
    }
  }

  Future<void> _showCitationDialog() async {
    if (_book == null) return;
    await showDialog(context: context, builder: (ctx) => _CitationDialog(book: _book!, currentPage: int.tryParse(_pageController.text) ?? 0));
  }

  Future<void> _showReadingTimer() async {
    await showDialog(
      context: context,
      builder: (ctx) => _ReadingTimerDialog(
        bookId: widget.bookId,
        currentPage: int.tryParse(_pageController.text) ?? 0,
        totalPages: (_book?['totalPages'] as int?) ?? 1,
        onSessionComplete: () async {
          await _loadData();
          widget.onUpdate();
          await WidgetService.refreshReadingWidget();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        )),
      );
    }
    if (_book == null) return const Scaffold(body: Center(child: Text('Book not found')));

    final title = (_book?['title'] as String?) ?? 'Unknown';
    final author = (_book?['author'] as String?) ?? 'Unknown Author';
    final totalPages = (_book?['totalPages'] as int?) ?? 1;
    final totalMinutes = (_book?['totalMinutesRead'] as int?) ?? 0;
    final currentPage = int.tryParse(_pageController.text) ?? 0;
    final progress = totalPages > 0 ? currentPage / totalPages : 0.0;
    final percent = (progress * 100).round();
    final color = _bookColor();
    final pagesPerMin = totalMinutes > 0 ? (currentPage / totalMinutes).toStringAsFixed(2) : '0.00';
    final pagesLeft = totalPages - currentPage;
    final estMinutesLeft = double.tryParse(pagesPerMin) != null && double.parse(pagesPerMin) > 0 ? (pagesLeft / double.parse(pagesPerMin)).ceil() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.timer), tooltip: 'Reading Timer', onPressed: _showReadingTimer),
          IconButton(icon: const Icon(Icons.format_quote), tooltip: 'Citation', onPressed: _showCitationDialog),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Progress'),
            Tab(icon: Icon(Icons.history), text: 'Sessions'),
            Tab(icon: Icon(Icons.note), text: 'Notes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Progress
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProgressRing(cs, progress, percent, totalPages, color),
                const SizedBox(height: 16),
                Text(author, style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                if ((_book?['subjectName'] as String?) != null)
                  Chip(
                    label: Text(_book!['subjectName']),
                    backgroundColor: color.withOpacity(0.15),
                    side: BorderSide.none,
                  ),
                const SizedBox(height: 24),
                _buildPageUpdater(cs, totalPages),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: _logSession, icon: const Icon(Icons.timer), label: const Text('Log Reading Session'))),
                const SizedBox(height: 24),
                _buildStatsSection(cs, totalMinutes, pagesPerMin, estMinutesLeft, pagesLeft),
                const SizedBox(height: 24),
                _buildConsistencyGraph(cs),
                const SizedBox(height: 24),
                _buildStreakAndEstimation(cs),
                const SizedBox(height: 24),
                _buildSpeedTrend(cs),
              ],
            ),
          ),
          // Tab 2: Sessions
          _buildSessionsTab(cs),
          // Tab 3: Notes
          _buildNotesTab(cs),
        ],
      ),
    );
  }

  Widget _buildProgressRing(ColorScheme cs, double progress, int percent, int totalPages, Color color) {
    return SizedBox(
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
    );
  }

  Widget _buildPageUpdater(ColorScheme cs, int totalPages) {
    return Card(
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
                    controller: _pageController,
                    onSubmitted: (v) {
                      final newPage = int.tryParse(v) ?? 0;
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
    );
  }

  Widget _pageButton(int delta, ColorScheme cs) {
    return IconButton(
      onPressed: () => _updatePage((int.tryParse(_pageController.text) ?? 0) + delta),
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
        if (snapshot.hasError) {
          return _emptyCard(cs, 'Reading Consistency', 'Error loading data');
        }
        final days = snapshot.data ?? [];
        // Only show days up to today
        final now = DateTime.now();
        final filteredDays = days.where((d) {
          final parts = (d['date'] as String).split('/');
          if (parts.length != 2) return false;
          final month = int.tryParse(parts[0]) ?? 0;
          final day = int.tryParse(parts[1]) ?? 0;
          final date = DateTime(now.year, month, day);
          return !date.isAfter(now);
        }).toList();

        if (filteredDays.isEmpty || filteredDays.every((d) => (d['pages'] as int) == 0)) {
          return _emptyCard(cs, 'Reading Consistency (Last 14 Days)', 'No session data yet. Log a reading session to see your graph!');
        }

        final maxPages = filteredDays.map((d) => d['pages'] as int).fold(0, math.max);
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
                    children: filteredDays.map((day) {
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

  Widget _buildStreakAndEstimation(ColorScheme cs) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadStreakAndEst(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final streak = data?['streak'] as int? ?? 0;
        final consistency = data?['consistency'] as int? ?? 0;
        final estDate = data?['estDate'] as String?;
        final bestDay = data?['bestDay'] as Map<String, dynamic>?;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Milestones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _statBox('$streak', 'Day Streak', Icons.local_fire_department, cs)),
                    const SizedBox(width: 12),
                    Expanded(child: _statBox('$consistency%', 'Consistency', Icons.track_changes, cs)),
                  ],
                ),
                const SizedBox(height: 12),
                if (estDate != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.secondaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.event_available, color: cs.onSecondaryContainer),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Estimated completion: $estDate', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSecondaryContainer))),
                      ],
                    ),
                  ),
                if (bestDay != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: cs.tertiaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                                                Icon(Icons.emoji_events, color: cs.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Best day: ${bestDay['date']} — ${bestDay['pages']} pages', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onTertiaryContainer))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _loadStreakAndEst() async {
    try {
      final streak = await DatabaseHelper.instance.getReadingStreak(widget.bookId);
      final consistency = await DatabaseHelper.instance.getReadingConsistencyScore(widget.bookId);
      final estDateTime = await DatabaseHelper.instance.getEstimatedCompletionDate(widget.bookId);
      final bestDay = await DatabaseHelper.instance.getBestReadingDay(widget.bookId);
      return {
        'streak': streak,
        'consistency': consistency,
        'estDate': estDateTime != null ? '${estDateTime.month}/${estDateTime.day}/${estDateTime.year}' : null,
        'bestDay': bestDay,
      };
    } catch (e) {
      debugPrint('_loadStreakAndEst error: $e');
      return {
        'streak': 0,
        'consistency': 0,
        'estDate': null,
        'bestDay': null,
      };
    }
  }

  Widget _buildSpeedTrend(ColorScheme cs) {
    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getReadingSessionTotals(widget.bookId),
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null || (data['sessionCount'] as int? ?? 0) == 0) {
          return const SizedBox.shrink();
        }
        final avgSpeed = (data['avgSpeed'] as double? ?? 0.0).toStringAsFixed(2);
        final totalSessions = data['sessionCount'] as int? ?? 0;
        final totalPages = data['totalPages'] as int? ?? 0;
        final totalMinutes = data['totalMinutes'] as int? ?? 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _miniStat('$totalSessions', 'Sessions', cs),
                    _miniStat('$totalPages', 'Total Pages', cs),
                    _miniStat('$totalMinutes', 'Total Min', cs),
                    _miniStat(avgSpeed, 'Avg Spd', cs),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _miniStat(String value, String label, ColorScheme cs) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.primary)),
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSessionsTab(ColorScheme cs) {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text('No sessions yet', style: TextStyle(color: cs.outline, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Log your first reading session!', style: TextStyle(color: cs.outline, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final date = DateTime.fromMillisecondsSinceEpoch(session['sessionDateMillis'] as int);
        final dateStr = '${date.month}/${date.day}/${date.year}';
        final pages = session['pagesRead'] as int? ?? 0;
        final minutes = session['minutesRead'] as int? ?? 0;
        final ppm = session['pagesPerMinute'] as double?;
        final note = session['note'] as String?;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outline.withOpacity(0.15))),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: cs.primaryContainer,
              child: Text('${index + 1}', style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12)),
            ),
            title: Text('$pages pages · $minutes min', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (ppm != null) Text('${ppm.toStringAsFixed(2)} pgs/min', style: TextStyle(fontSize: 11, color: cs.primary)),
                if (note != null && note.isNotEmpty) Text('Note: $note', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
              onPressed: () => _deleteSession(session['id'] as int),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotesTab(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(onPressed: _addNote, icon: const Icon(Icons.add), label: const Text('Add Note')),
          ),
        ),
        Expanded(
          child: _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notes, size: 64, color: cs.outline),
                      const SizedBox(height: 16),
                      Text('No notes yet', style: TextStyle(color: cs.outline, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Jot down insights, quotes, or summaries', style: TextStyle(color: cs.outline, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final title = (note['title'] as String?) ?? 'Note';
                    final content = (note['content'] as String?) ?? '';
                    final createdAt = note['createdAtMillis'] as int?;
                    final dateStr = createdAt != null ? DateTime.fromMillisecondsSinceEpoch(createdAt).toString().substring(0, 16) : '';
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outline.withOpacity(0.15))),
                      child: ListTile(
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('$content\n$dateStr', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        isThreeLine: true,
                        trailing: IconButton(icon: Icon(Icons.delete_outline, size: 18, color: cs.error), onPressed: () => _deleteNote(note['id'] as int)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _emptyCard(ColorScheme cs, String title, String message) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outline.withOpacity(0.15))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 24),
            Center(child: Text(message, style: TextStyle(color: cs.outline, fontSize: 13))),
            const SizedBox(height: 24),
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
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _minutesController.dispose();
    _pagesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Log Reading Session'),
      content: SingleChildScrollView(
        child: Column(
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
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Session Note (optional)', prefixIcon: Icon(Icons.notes)),
            ),
          ],
        ),
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
            Navigator.pop(context, {
              'minutes': minutes,
              'pagesRead': pages,
              'note': _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            });
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
            maxLines: 4,
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
            Navigator.pop(context, {
              'title': _titleController.text.trim(),
              'content': _contentController.text.trim(),
            });
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
// READING TIMER DIALOG — Built-in stopwatch for live sessions
// ═══════════════════════════════════════════════════════════════

class _ReadingTimerDialog extends StatefulWidget {
  final int bookId;
  final int currentPage;
  final int totalPages;
  final VoidCallback onSessionComplete;

  const _ReadingTimerDialog({
    required this.bookId,
    required this.currentPage,
    required this.totalPages,
    required this.onSessionComplete,
  });

  @override
  State<_ReadingTimerDialog> createState() => _ReadingTimerDialogState();
}

class _ReadingTimerDialogState extends State<_ReadingTimerDialog> {
  Timer? _timer;
  int _seconds = 0;
  bool _isRunning = false;
  final _pagesController = TextEditingController();
  final _noteController = TextEditingController();

  String get _timeDisplay {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _seconds++);
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 0;
      _isRunning = false;
    });
  }

  Future<void> _saveSession() async {
    final pages = int.tryParse(_pagesController.text.trim());
    if (pages == null || pages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter pages read')));
      return;
    }
    final minutes = (_seconds / 60).ceil();
    if (minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Session too short')));
      return;
    }
    final newPage = widget.currentPage + pages;
    final clampedPage = newPage.clamp(0, widget.totalPages);
    try {
      await DatabaseHelper.instance.updateReadingProgress(widget.bookId, clampedPage, minutes);
      HapticFeedback.mediumImpact();
      _timer?.cancel();
      if (mounted) {
        Navigator.pop(context);
        widget.onSessionComplete();
      }
    } catch (e) {
      debugPrint('Error saving timer session: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pagesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Reading Timer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
              ),
              child: Text(
                _timeDisplay,
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: _toggleTimer,
                  child: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.replay),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pagesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pages Read *', prefixIcon: Icon(Icons.menu_book)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Note (optional)', prefixIcon: Icon(Icons.notes)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () {
          _timer?.cancel();
          Navigator.pop(context);
        }, child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _isRunning || _seconds > 0 ? _saveSession : null,
          icon: const Icon(Icons.save),
          label: const Text('Save Session'),
        ),
      ],
    );
  }
}

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

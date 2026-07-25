import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';

class ReadingScreen extends StatefulWidget {
  const ReadingScreen({super.key});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _completedBooks = [];
  bool _loading = true;
  Map<String, dynamic>? _overallStats;

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
    setState(() {
      _books = active;
      _completedBooks = completed;
      _overallStats = stats;
      _loading = false;
    });
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
      'Math': const Color(0xFF2196F3),
      'Physics': const Color(0xFF9C27B0),
      'Chemistry': const Color(0xFF4CAF50),
      'Biology': const Color(0xFF8BC34A),
      'History': const Color(0xFFFF9800),
      'Literature': const Color(0xFFE91E63),
      'Computer Science': const Color(0xFF00BCD4),
      'Economics': const Color(0xFF795548),
    };
    return colors[subject] ?? const Color(0xFF607D8B);
  }

  Future<void> _showAddBookDialog() async {
    final titleController = TextEditingController();
    final authorController = TextEditingController();
    final pagesController = TextEditingController();
    final subjectController = TextEditingController();
    DateTime? targetDate;
    int dailyGoal = 20;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add New Book'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Book Title *',
                      prefixIcon: Icon(Icons.menu_book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pagesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Pages *',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject (optional)',
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Target Finish Date', style: TextStyle(fontSize: 12)),
                    subtitle: Text(
                      targetDate != null ? '${targetDate!.day}/${targetDate!.month}/${targetDate!.year}' : 'Not set',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.calendar_today, size: 20),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) setDialogState(() => targetDate = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: dailyGoal,
                    decoration: const InputDecoration(
                      labelText: 'Daily Page Goal',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    items: [10, 15, 20, 25, 30, 50, 100].map((n) => DropdownMenuItem(
                      value: n,
                      child: Text('$n pages/day'),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => dailyGoal = v!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Title is required')),
                    );
                    return;
                  }
                  final pages = int.tryParse(pagesController.text.trim());
                  if (pages == null || pages <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Valid page count is required')),
                    );
                    return;
                  }
                  Navigator.pop(ctx, {
                    'title': titleController.text.trim(),
                    'author': authorController.text.trim().isEmpty ? null : authorController.text.trim(),
                    'totalPages': pages,
                    'subjectName': subjectController.text.trim().isEmpty ? null : subjectController.text.trim(),
                    'targetEndDateMillis': targetDate != null
                        ? DateTime(targetDate!.year, targetDate!.month, targetDate!.day).millisecondsSinceEpoch
                        : null,
                    'dailyPageGoal': dailyGoal,
                  });
                },
                child: const Text('Add Book'),
              ),
            ],
          );
        },
      ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Book?'),
        content: const Text('All reading progress will be lost.'),
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

  void _openSession(int bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingSessionScreen(
          bookId: bookId,
          onSessionComplete: _loadData,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Stats header
                if (_overallStats != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primaryContainer, cs.secondaryContainer],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statColumn(
                              '${_overallStats!['totalBooks']}',
                              'Books',
                              Icons.menu_book,
                            ),
                          ),
                          Container(width: 1, height: 40, color: cs.outline.withOpacity(0.3)),
                          Expanded(
                            child: _statColumn(
                              '${_overallStats!['totalPagesRead']}',
                              'Pages Read',
                              Icons.auto_stories,
                            ),
                          ),
                          Container(width: 1, height: 40, color: cs.outline.withOpacity(0.3)),
                          Expanded(
                            child: _statColumn(
                              '${(_overallStats!['totalMinutesRead'] as int) ~/ 60}h',
                              'Time Read',
                              Icons.timer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Active books
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
                        (context, index) => _buildBookCard(_books[index], cs, isCompleted: false),
                        childCount: _books.length,
                      ),
                    ),
                  ),
                ],

                // Empty state
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

                // Completed books
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddBookDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
    );
  }

  Widget _statColumn(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, ColorScheme cs, {required bool isCompleted}) {
    final bookId = book['id'] as int;
    final title = book['title'] as String;
    final author = (book['author'] as String?) ?? 'Unknown Author';
    final totalPages = (book['totalPages'] as int?) ?? 1;
    final currentPage = (book['currentPage'] as int?) ?? 0;
    final subject = book['subjectName'] as String?;
    final color = subject != null ? _subjectColor(subject) : const Color(0xFF607D8B);
    final progress = totalPages > 0 ? currentPage / totalPages : 0.0;
    final percent = (progress * 100).round();

    return FutureBuilder<Map<String, dynamic>>(
      future: DatabaseHelper.instance.getReadingProgress(bookId),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final daysLeft = stats?['daysLeft'] as int? ?? 0;
        final onTrack = stats?['onTrack'] as bool? ?? true;
        final pagesPerDayNeeded = stats?['pagesPerDayNeeded'] as int? ?? 0;

        String paceText;
        if (isCompleted) {
          paceText = 'Completed! 🎉';
        } else if (daysLeft > 0 && pagesPerDayNeeded > 0) {
          paceText = 'At this pace, finish in $daysLeft days ($pagesPerDayNeeded pgs/day)';
        } else if (daysLeft <= 0 && !onTrack) {
          paceText = 'Behind schedule — speed up!';
        } else {
          paceText = 'Keep reading!';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outline.withOpacity(0.15)),
          ),
          child: InkWell(
            onTap: isCompleted ? null : () => _openSession(bookId),
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
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              author,
                              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                            if (subject != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  subject,
                                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isCompleted)
                        const Icon(Icons.check_circle, color: Colors.green, size: 28)
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$percent%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
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
                      Text(
                        'Page $currentPage of $totalPages',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        paceText,
                        style: TextStyle(
                          fontSize: 11,
                          color: isCompleted
                              ? Colors.green.shade700
                              : onTrack
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// READING SESSION SCREEN
// ═══════════════════════════════════════════════════════════════

class ReadingSessionScreen extends StatefulWidget {
  final int bookId;
  final VoidCallback onSessionComplete;

  const ReadingSessionScreen({
    super.key,
    required this.bookId,
    required this.onSessionComplete,
  });

  @override
  State<ReadingSessionScreen> createState() => _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends State<ReadingSessionScreen> {
  Map<String, dynamic>? _book;
  int _currentPage = 0;
  int _sessionStartPage = 0;
  int _sessionMinutes = 0;
  Timer? _timer;
  bool _isRunning = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBook() async {
    final book = await DatabaseHelper.instance.getReadingBookById(widget.bookId);
    if (book != null) {
      setState(() {
        _book = book;
        _currentPage = (book['currentPage'] as int?) ?? 0;
        _sessionStartPage = _currentPage;
        _loading = false;
      });
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _sessionMinutes++);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  Future<void> _finishSession() async {
    _timer?.cancel();
    final pagesRead = _currentPage - _sessionStartPage;
    if (pagesRead < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current page cannot be less than start page')),
      );
      return;
    }
    await DatabaseHelper.instance.updateReadingProgress(
      widget.bookId,
      _currentPage,
      _sessionMinutes,
    );
    widget.onSessionComplete();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session saved! $pagesRead pages in $_sessionMinutes min')),
      );
    }
  }

  String _formatTime(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final title = _book?['title'] as String? ?? 'Unknown';
    final totalPages = (_book?['totalPages'] as int?) ?? 1;
    final author = (_book?['author'] as String?) ?? 'Unknown Author';
    final progress = totalPages > 0 ? _currentPage / totalPages : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Author
            Text(
              author,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            // Timer display
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer.withOpacity(0.3),
                border: Border.all(color: cs.primary.withOpacity(0.3), width: 4),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRunning ? Icons.timer : Icons.timer_off,
                      size: 32,
                      color: cs.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(_sessionMinutes),
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'Reading time',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Timer controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _isRunning ? _pauseTimer : _startTimer,
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_isRunning ? 'Pause' : 'Start'),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Page slider
            Text(
              'Current Page',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _currentPage > 0
                      ? () => setState(() => _currentPage--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_currentPage',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'of $totalPages pages',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),

            // Progress bar
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).round()}% complete',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),

            const Spacer(),

            // Finish button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _finishSession,
                icon: const Icon(Icons.check),
                label: const Text('Finish Session'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

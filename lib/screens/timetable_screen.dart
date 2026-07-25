// FILE: lib/screens/timetable_screen.dart
// NEW FILE — Weekly Timetable with day columns and time slots

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database_helper.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  int _selectedDayIndex = DateTime.now().weekday - 1;
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;

  // Time slots from 7 AM to 9 PM
  final List<String> _timeSlots = List.generate(
    15,
    (i) {
      final hour = 7 + i;
      final displayHour = hour > 12 ? hour - 12 : hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      return '$displayHour $ampm';
    },
  );

  @override
  void initState() {
    super.initState();
    if (_selectedDayIndex < 0 || _selectedDayIndex > 6) {
      _selectedDayIndex = 0;
    }
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    // For now, classes are stored in a simple in-memory structure
    // In a full implementation, you'd have a dedicated timetable_classes table
    // Using quick_notes as a temporary storage with subject prefix
    final notes = await DatabaseHelper.instance.getAllQuickNotes();
    final dayPrefix = _days[_selectedDayIndex];
    
    final classes = notes
        .where((n) => (n['subject'] as String).startsWith('TT_$dayPrefix'))
        .map((n) {
          final subjectParts = (n['subject'] as String).split('_');
          return {
            'id': n['id'],
            'subject': subjectParts.length > 2 ? subjectParts.sublist(2).join('_') : 'Unknown',
            'timeSlot': n['title'],
            'note': n['content'],
            'colorHex': subjectParts.length > 3 ? subjectParts[3] : '#2196F3',
          };
        })
        .toList();

    // Sort by time slot
    classes.sort((a, b) => (a['timeSlot'] as String).compareTo(b['timeSlot'] as String));

    if (mounted) {
      setState(() {
        _classes = classes;
        _loading = false;
      });
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF2196F3);
    }
  }

  Future<void> _addClass() async {
    final subjectController = TextEditingController();
    final noteController = TextEditingController();
    String selectedSlot = _timeSlots.first;
    Color selectedColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Class'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      hintText: 'e.g. Mathematics',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedSlot,
                    decoration: const InputDecoration(
                      labelText: 'Time Slot',
                      border: OutlineInputBorder(),
                    ),
                    items: _timeSlots.map((slot) {
                      return DropdownMenuItem(
                        value: slot,
                        child: Text(slot),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedSlot = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Room / Notes',
                      hintText: 'e.g. Room 301',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: Colors.primaries.map((color) {
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selectedColor == color
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: selectedColor == color
                                ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && subjectController.text.trim().isNotEmpty) {
      final dayPrefix = _days[_selectedDayIndex];
      final colorHex = '#${selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
      
      await DatabaseHelper.instance.insertQuickNote({
        'title': selectedSlot,
        'content': noteController.text.trim(),
        'subject': 'TT_${dayPrefix}_${subjectController.text.trim()}_$colorHex',
      });
      
      HapticFeedback.lightImpact();
      await _loadClasses();
    }
  }

  Future<void> _deleteClass(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Class?'),
        content: const Text('Remove this class from the timetable?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteQuickNote(id);
      await _loadClasses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          // Day selector
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.5),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: _days.asMap().entries.map((entry) {
                  final index = entry.key;
                  final day = entry.value;
                  final isSelected = index == _selectedDayIndex;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Material(
                      color: isSelected ? cs.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = index;
                            _loading = true;
                          });
                          _loadClasses();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                day,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? cs.onPrimary : cs.onSurface,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cs.onPrimary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),
          // Classes list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _classes.isEmpty
                    ? _buildEmptyState(cs)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _classes.length,
                        itemBuilder: (context, index) {
                          final cls = _classes[index];
                          final color = _parseColor(cls['colorHex'] as String);

                          return Dismissible(
                            key: ValueKey(cls['id']),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: cs.error,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.delete, color: cs.onError),
                            ),
                            onDismissed: (_) => _deleteClass(cls['id'] as int),
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: color.withOpacity(0.3)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cls['subject'] as String,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            cls['timeSlot'] as String,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: cs.outline,
                                            ),
                                          ),
                                          if ((cls['note'] as String).isNotEmpty)
                                            Text(
                                              cls['note'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: cs.outline.withOpacity(0.7),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: cs.outline),
                                      onPressed: () => _deleteClass(cls['id'] as int),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClass,
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cs.primary.withOpacity(0.2),
                    cs.secondary.withOpacity(0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.schedule_outlined,
                size: 36,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No classes on ${_days[_selectedDayIndex]}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add your first class',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline),
            ),
          ],
        ),
      ),
    );
  }
}

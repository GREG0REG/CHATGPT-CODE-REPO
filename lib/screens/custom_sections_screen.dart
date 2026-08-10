// lib/screens/custom_sections_screen.dart
// Manage custom notification sections

import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/event.dart';

class CustomSectionsScreen extends StatefulWidget {
  const CustomSectionsScreen({super.key});

  @override
  State<CustomSectionsScreen> createState() => _CustomSectionsScreenState();
}

class _CustomSectionsScreenState extends State<CustomSectionsScreen> {
  List<Map<String, dynamic>> _sections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() => _isLoading = true);
    final sections = await DatabaseHelper.instance.getAllCustomSections();
    setState(() {
      _sections = sections;
      _isLoading = false;
    });
  }

  Future<void> _addSection() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddSectionDialog(),
    );

    if (result != null) {
      await DatabaseHelper.instance.insertCustomSection(result);
      await _loadSections();
    }
  }

  Future<void> _deleteSection(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: const Text('Events in this section will use default notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteCustomSection(id);
      await _loadSections();
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.blue;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Sections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSection,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _sections.length,
                  itemBuilder: (context, index) {
                    final section = _sections[index];
                    final color = _parseColor(section['colorHex'] as String?);
                    final isAlarm = (section['isAlarmEnabled'] as int?) == 1;
                    final isFullScreen = (section['isFullScreen'] as int?) == 1;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color,
                          child: Icon(
                            EventIcons.getIcon(section['iconName'] as String?) ?? Icons.folder,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(section['name'] as String? ?? 'Unnamed'),
                        subtitle: Wrap(
                          spacing: 8,
                          children: [
                            if (isAlarm)
                              Chip(
                                label: const Text('ALARM', style: TextStyle(fontSize: 10)),
                                backgroundColor: Colors.red.withOpacity(0.2),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            if (isFullScreen)
                              Chip(
                                label: const Text('FULL SCREEN', style: TextStyle(fontSize: 10)),
                                backgroundColor: Colors.purple.withOpacity(0.2),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteSection(section['id'] as int),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No custom sections yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create sections to group events with custom notifications',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addSection,
            icon: const Icon(Icons.add),
            label: const Text('Create Section'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD SECTION DIALOG
// ============================================================================

class _AddSectionDialog extends StatefulWidget {
  const _AddSectionDialog();

  @override
  State<_AddSectionDialog> createState() => _AddSectionDialogState();
}

class _AddSectionDialogState extends State<_AddSectionDialog> {
  final _nameController = TextEditingController();
  bool _isAlarmEnabled = false;
  bool _isFullScreen = false;
  String _selectedColor = '#2196F3';
  String _selectedIcon = 'event';

  final List<Map<String, dynamic>> _colors = [
    {'name': 'Blue', 'hex': '#2196F3'},
    {'name': 'Red', 'hex': '#F44336'},
    {'name': 'Green', 'hex': '#4CAF50'},
    {'name': 'Orange', 'hex': '#FF9800'},
    {'name': 'Purple', 'hex': '#9C27B0'},
    {'name': 'Cyan', 'hex': '#00BCD4'},
    {'name': 'Pink', 'hex': '#E91E63'},
    {'name': 'Teal', 'hex': '#009688'},
  ];

  final List<String> _icons = [
    'event', 'school', 'book', 'science', 'alarm',
    'timer', 'emoji_events', 'self_improvement',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Custom Section'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Section Name',
                hintText: 'e.g., Physics Revision',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _colors.map((c) {
                final isSelected = _selectedColor == c['hex'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c['hex']!),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(int.parse(c['hex']!.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: Colors.black26, blurRadius: 4)]
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _icons.map((iconName) {
                final isSelected = _selectedIcon == iconName;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = iconName),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      EventIcons.getIcon(iconName) ?? Icons.event,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Alarm Mode'),
              subtitle: const Text('Wake up screen, play sound even on silent'),
              value: _isAlarmEnabled,
              onChanged: (v) => setState(() => _isAlarmEnabled = v),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Full Screen'),
              subtitle: const Text('Show full-screen alarm when fired'),
              value: _isFullScreen,
              onChanged: (v) => setState(() => _isFullScreen = v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'name': _nameController.text.trim(),
              'colorHex': _selectedColor,
              'iconName': _selectedIcon,
              'isAlarmEnabled': _isAlarmEnabled ? 1 : 0,
              'isFullScreen': _isFullScreen ? 1 : 0,
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

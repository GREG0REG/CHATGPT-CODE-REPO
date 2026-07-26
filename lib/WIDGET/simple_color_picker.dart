import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A simple preset-color picker dialog with Material 3 tonal palettes,
/// hex input, and recent colors memory.
class SimpleColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final List<Color>? recentColors;

  const SimpleColorPickerDialog({
    super.key,
    required this.initialColor,
    this.recentColors,
  });

  @override
  State<SimpleColorPickerDialog> createState() =>
      _SimpleColorPickerDialogState();
}

class _SimpleColorPickerDialogState extends State<SimpleColorPickerDialog>
    with SingleTickerProviderStateMixin {
  late Color _selected;
  late TabController _tabController;
  final _hexController = TextEditingController();

  // Material 3 tonal palettes
  static const List<Color> _primaryTones = [
    Color(0xFFB3261E), Color(0xFF984061), Color(0xFF6750A4),
    Color(0xFF4A4458), Color(0xFF1D192B), Color(0xFF005BC0),
    Color(0xFF00639B), Color(0xFF006780), Color(0xFF006E1C),
    Color(0xFF386A20),
  ];

  static const List<Color> _secondaryTones = [
    Color(0xFFE46962), Color(0xFFFFB4AB), Color(0xFFFFD8E4),
    Color(0xFFE8DEF8), Color(0xFFD0BCFF), Color(0xFFCCC2DC),
    Color(0xFF9CCAFF), Color(0xFF7D5260), Color(0xFF625B71),
    Color(0xFF49454F),
  ];

  static const List<Color> _accentTones = [
    Color(0xFFFF00FF), Color(0xFF00FFFF), Color(0xFF9D00FF),
    Color(0xFFFF6B6B), Color(0xFFFFE66D), Color(0xFFFF8E53),
    Color(0xFF00BFA5), Color(0xFF00E5FF), Color(0xFF76FF03),
    Color(0xFFFFEA00),
  ];

  static const List<Color> _classicPresets = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.initialColor;
    _tabController = TabController(length: 4, vsync: this);
    _updateHexField();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _updateHexField() {
    final hex = '#${_selected.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    _hexController.text = hex;
  }

  void _onHexSubmitted(String value) {
    try {
      String hex = value.trim();
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.length == 6) hex = 'FF$hex';
      if (hex.length == 8) {
        final color = Color(int.parse(hex, radix: 16));
        setState(() {
          _selected = color;
        });
      }
    } catch (_) {
      // Invalid hex, ignore
    }
  }

  Widget _buildColorGrid(List<Color> colors) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: colors.map((color) {
        final isSel = color.value == _selected.value;
        return InkWell(
          onTap: () {
            setState(() => _selected = color);
            _updateHexField();
          },
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSel
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 3,
                    )
                  : Border.all(color: Colors.transparent, width: 3),
              boxShadow: isSel
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: isSel
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Pick Custom Color'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                color: _selected,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  'Preview',
                  style: TextStyle(
                    color: _selected.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hex input
            TextField(
              controller: _hexController,
              decoration: InputDecoration(
                labelText: 'Hex Color',
                hintText: '#FF5733',
                prefixIcon: const Icon(Icons.colorize),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle),
                  onPressed: () => _onHexSubmitted(_hexController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: _onHexSubmitted,
            ),
            const SizedBox(height: 16),

            // Recent colors
            if (widget.recentColors != null && widget.recentColors!.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildColorGrid(widget.recentColors!),
              const SizedBox(height: 16),
            ],

            // Tabs
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Primary'),
                Tab(text: 'Secondary'),
                Tab(text: 'Accent'),
                Tab(text: 'Classic'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(child: _buildColorGrid(_primaryTones)),
                  SingleChildScrollView(child: _buildColorGrid(_secondaryTones)),
                  SingleChildScrollView(child: _buildColorGrid(_accentTones)),
                  SingleChildScrollScrollView(child: _buildColorGrid(_classicPresets)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

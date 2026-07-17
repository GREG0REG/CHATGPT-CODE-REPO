import 'package:flutter/material.dart';

/// A simple preset-color picker dialog.
/// Used by SettingsScreen > Custom Color.
class SimpleColorPickerDialog extends StatefulWidget {
  final Color initialColor;

  const SimpleColorPickerDialog({
    super.key,
    required this.initialColor,
  });

  @override
  State<SimpleColorPickerDialog> createState() =>
      _SimpleColorPickerDialogState();
}

class _SimpleColorPickerDialogState extends State<SimpleColorPickerDialog> {
  late Color _selected;

  static const List<Color> _presets = [
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
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick Custom Color'),
      content: SizedBox(
        width: 300,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _presets.map((color) {
            final isSel = color.value == _selected.value;
            return InkWell(
              onTap: () => setState(() => _selected = color),
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSel
                      ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                      : Border.all(color: Colors.transparent, width: 3),
                  boxShadow: isSel
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 2)]
                      : null,
                ),
                child: isSel
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

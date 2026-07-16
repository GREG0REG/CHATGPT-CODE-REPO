import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/widget_service.dart';

/// Dedicated widget configuration screen.
/// Accessed from Settings > Advanced Widget Settings or from widget long-press menu.
class WidgetSettingsScreen extends StatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  bool _progressBar = false;
  bool _pulseAnimation = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = SettingsService.instance;
    final progress = await s.getWidgetProgressBar();
    final pulse = await s.getWidgetPulseAnimation();
    if (!mounted) return;
    setState(() {
      _progressBar = progress;
      _pulseAnimation = pulse;
      _loading = false;
    });
  }

  Future<void> _setProgressBar(bool value) async {
    await SettingsService.instance.setWidgetProgressBar(value);
    setState(() => _progressBar = value);
    await WidgetService.refreshWidget();
  }

  Future<void> _setPulseAnimation(bool value) async {
    await SettingsService.instance.setWidgetPulseAnimation(value);
    setState(() => _pulseAnimation = value);
    await WidgetService.refreshWidget();
  }

  Future<void> _forceRefresh() async {
    await WidgetService.refreshWidget();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Widget refreshed!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Settings'),
      ),
      body: ListView(
        children: [
          const _SectionHeader('Display Options'),
          SwitchListTile(
            secondary: const Icon(Icons.linear_scale),
            title: const Text('Progress Bar'),
            subtitle: const Text('Show percentage of time elapsed between start and deadline'),
            value: _progressBar,
            onChanged: _setProgressBar,
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.animation),
            title: const Text('Pulse Animation'),
            subtitle: const Text('Gentle scale pulse when event is under 24 hours away'),
            value: _pulseAnimation,
            onChanged: _setPulseAnimation,
          ),
          const Divider(),
          const _SectionHeader('Actions'),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Force Refresh Widget'),
            subtitle: const Text('Immediately update widget with latest data'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _forceRefresh,
          ),
          const Divider(),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Widget Size'),
            subtitle: Text('Resize the widget on your home screen by long-pressing and dragging the handles. Supports 2x1 to 4x1.'),
          ),
          const ListTile(
            leading: Icon(Icons.touch_app),
            title: Text('Widget Interactions'),
            subtitle: Text('Tap title: Widget Settings\nTap countdown: Mark Done\nTap background: Open App'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:battery_plus/battery_plus.dart';

/// Provides battery state for adaptive refresh and UI monitoring.
/// Enhanced with caching and real-time stream support for SettingsScreen.
class BatteryService {
  BatteryService._();
  static final BatteryService instance = BatteryService._();

  final Battery _battery = Battery();

  int? _cachedLevel;
  BatteryState? _cachedState;
  StreamSubscription<BatteryState>? _stateSubscription;

  /// Initialize the service and start listening to battery changes.
  /// Call once in main.dart before runApp.
  Future<void> initialize() async {
    try {
      _cachedLevel = await _battery.batteryLevel;
      _cachedState = await _battery.batteryState;
      _stateSubscription = _battery.onBatteryStateChanged.listen((state) {
        _cachedState = state;
        // Refresh level on state change too
        _battery.batteryLevel.then((level) => _cachedLevel = level);
      });
    } catch (_) {
      _cachedLevel = null;
      _cachedState = null;
    }
  }

  /// Dispose the subscription. Call on app shutdown if needed.
  void dispose() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
  }

  /// Current battery level 0-100. Uses cache if available.
  Future<int> getBatteryLevel() async {
    if (_cachedLevel != null) return _cachedLevel!;
    try {
      _cachedLevel = await _battery.batteryLevel;
      return _cachedLevel!;
    } catch (e) {
      return 100;
    }
  }

  /// Synchronous access to cached level (null if not initialized).
  int? get cachedLevel => _cachedLevel;

  /// Synchronous access to cached state (null if not initialized).
  BatteryState? get cachedState => _cachedState;

  /// Whether the device is currently charging or full.
  Future<bool> isCharging() async {
    try {
      final state = _cachedState ?? await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (e) {
      return false;
    }
  }

  /// Returns true if battery is considered low (< 20%).
  Future<bool> isLowBattery() async {
    final level = await getBatteryLevel();
    return level < 20;
  }

  /// Returns true if adaptive refresh should be reduced due to low battery.
  /// This is the key integration point for the SettingsScreen toggle.
  Future<bool> shouldReduceRefresh() async {
    final level = await getBatteryLevel();
    final charging = await isCharging();
    // Reduce refresh when battery is low AND not charging
    return level < 20 && !charging;
  }

  /// Stream of battery state changes.
  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;

  /// Human-readable battery status for UI display.
  String get statusText {
    if (_cachedLevel == null || _cachedState == null) return 'Unknown';
    final level = _cachedLevel!;
    final state = _cachedState!;
    final stateStr = switch (state) {
      BatteryState.charging => 'Charging',
      BatteryState.discharging => 'On battery',
      BatteryState.full => 'Full',
      BatteryState.unknown => 'Unknown',
      BatteryState.connected => 'Plugged in',
    };
    return '$stateStr • $level%';
  }
}

import 'package:battery_plus/battery_plus.dart';

/// Provides battery state for adaptive refresh and UI monitoring.
class BatteryService {
  BatteryService._();
  static final BatteryService instance = BatteryService._();

  final Battery _battery = Battery();

  /// Current battery level 0-100.
  Future<int> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      return 100;
    }
  }

  /// Whether the device is currently charging.
  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
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

  /// Stream of battery state changes.
  Stream<BatteryState> get onBatteryStateChanged => _battery.onBatteryStateChanged;
}

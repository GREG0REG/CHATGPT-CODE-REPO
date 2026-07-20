import 'package:shared_preferences/shared_preferences.dart';

/// Tracks daily study streaks for motivational gamification
class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  static const String _kStreakCount = 'study_streak_count';
  static const String _kLastStudyDate = 'last_study_date';
  static const String _kBestStreak = 'best_streak_ever';
  static const String _kTotalStudyDays = 'total_study_days';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  /// Record a study session today and update streak
  Future<StreakInfo> recordStudySession() async {
    final p = await _prefs;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayMillis = today.millisecondsSinceEpoch;

    final lastStudyMillis = p.getInt(_kLastStudyDate) ?? 0;
    final lastStudyDate = DateTime.fromMillisecondsSinceEpoch(lastStudyMillis);
    final lastStudyDay = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);

    int currentStreak = p.getInt(_kStreakCount) ?? 0;
    int bestStreak = p.getInt(_kBestStreak) ?? 0;
    int totalDays = p.getInt(_kTotalStudyDays) ?? 0;

    final difference = today.difference(lastStudyDay).inDays;

    if (difference == 0) {
      // Already studied today, just return current info
    } else if (difference == 1) {
      // Consecutive day - increment streak
      currentStreak++;
      totalDays++;
      if (currentStreak > bestStreak) {
        bestStreak = currentStreak;
      }
    } else {
      // Streak broken - reset
      currentStreak = 1;
      totalDays++;
    }

    // Save updated values
    await p.setInt(_kStreakCount, currentStreak);
    await p.setInt(_kLastStudyDate, todayMillis);
    await p.setInt(_kBestStreak, bestStreak);
    await p.setInt(_kTotalStudyDays, totalDays);

    return StreakInfo(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalStudyDays: totalDays,
      studiedToday: difference == 0,
    );
  }

  /// Get current streak info without modifying
  Future<StreakInfo> getStreakInfo() async {
    final p = await _prefs;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastStudyMillis = p.getInt(_kLastStudyDate) ?? 0;
    final lastStudyDate = DateTime.fromMillisecondsSinceEpoch(lastStudyMillis);
    final lastStudyDay = DateTime(lastStudyDate.year, lastStudyDate.month, lastStudyDate.day);

    int currentStreak = p.getInt(_kStreakCount) ?? 0;
    int bestStreak = p.getInt(_kBestStreak) ?? 0;
    int totalDays = p.getInt(_kTotalStudyDays) ?? 0;

    final difference = today.difference(lastStudyDay).inDays;

    // If missed a day, streak is broken
    if (difference > 1) {
      currentStreak = 0;
    }

    return StreakInfo(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalStudyDays: totalDays,
      studiedToday: difference == 0,
    );
  }

  /// Reset all streak data
  Future<void> resetStreak() async {
    final p = await _prefs;
    await p.remove(_kStreakCount);
    await p.remove(_kLastStudyDate);
    await p.remove(_kBestStreak);
    await p.remove(_kTotalStudyDays);
  }
}

class StreakInfo {
  final int currentStreak;
  final int bestStreak;
  final int totalStudyDays;
  final bool studiedToday;

  const StreakInfo({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalStudyDays,
    required this.studiedToday,
  });
}

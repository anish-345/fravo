/// Represents the daily time limit configuration and current usage for a single app.
///
/// Returned by [ZoAppBlocker.getAppTimeLimits].
class AppTimeLimit {
  const AppTimeLimit({
    required this.packageName,
    required this.dailyLimitMinutes,
    required this.usedMinutes,
    required this.remainingMinutes,
    required this.dailyLimitSeconds,
    required this.usedSeconds,
    required this.remainingSeconds,
  });

  /// The package name of the app (e.g. 'com.instagram.android').
  final String packageName;

  /// The configured daily cap, in whole minutes.
  final int dailyLimitMinutes;

  /// How many whole minutes the user has already spent in this app today.
  final int usedMinutes;

  /// How many whole minutes remain in today's budget.
  final int remainingMinutes;

  /// The configured daily cap, in seconds (higher precision).
  final int dailyLimitSeconds;

  /// Seconds of usage recorded today.
  final int usedSeconds;

  /// Seconds remaining in today's budget.
  final int remainingSeconds;

  /// Whether today's budget has been fully consumed.
  bool get isExhausted => remainingSeconds <= 0;

  /// Usage as a fraction between 0.0 (none used) and 1.0 (fully used).
  double get usageRatio =>
      dailyLimitSeconds > 0 ? (usedSeconds / dailyLimitSeconds).clamp(0.0, 1.0) : 0.0;

  factory AppTimeLimit.fromMap(Map<String, dynamic> map) {
    return AppTimeLimit(
      packageName: map['packageName'] as String,
      dailyLimitMinutes: map['dailyLimitMinutes'] as int,
      usedMinutes: map['usedMinutes'] as int,
      remainingMinutes: map['remainingMinutes'] as int,
      dailyLimitSeconds: map['dailyLimitSeconds'] as int,
      usedSeconds: map['usedSeconds'] as int,
      remainingSeconds: map['remainingSeconds'] as int,
    );
  }

  @override
  String toString() =>
      'AppTimeLimit($packageName: ${usedMinutes}m used / ${dailyLimitMinutes}m limit)';
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// App preset definition for popular applications
class PresetApp {
  final String name;
  final String packageName;
  final String category;

  const PresetApp({
    required this.name,
    required this.packageName,
    required this.category,
  });
}

/// A single day's recorded totals for history tracking.
class DailyRecord {
  final String date; // 'yyyy-MM-dd'
  final int steps;
  final int earnedMinutes;
  final int usedMinutes;

  const DailyRecord({
    required this.date,
    required this.steps,
    required this.earnedMinutes,
    required this.usedMinutes,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'steps': steps,
        'earnedMinutes': earnedMinutes,
        'usedMinutes': usedMinutes,
      };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        date: json['date'] as String,
        steps: (json['steps'] as num).toInt(),
        earnedMinutes: (json['earnedMinutes'] as num).toInt(),
        usedMinutes: (json['usedMinutes'] as num).toInt(),
      );
}

/// Persists step count and consumed screen time across multiple blocked apps.
///
/// Reward formula: 1,000 steps walked = [minutesPer1kSteps] minutes of screen
/// time (configurable, default 30 min, range 5–60 min).
///
/// Used-time tracking uses a delta approach:
///   usedMinutes = persisted_base + (current_native_total - native_baseline)
/// so that relaunching the app never resets previously consumed time.
class TimeBankService {
  TimeBankService._();

  static final TimeBankService instance = TimeBankService._();

  static const String _boxName = 'time_bank';

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const String _totalStepsKey = 'totalStepsWalked';
  static const String _usedMinutesKey = 'usedMinutes';

  /// New: minutes rewarded per 1,000 steps (default 30).
  static const String _minutesPer1kStepsKey = 'minutesPer1kSteps';

  /// Legacy single-app keys — kept for migration only.
  static const String _legacyBlockedAppPackageNameKey = 'blockedAppPackageName';
  static const String _legacyBlockedAppNameKey = 'blockedAppName';

  /// Multi-app: JSON-encoded `List<String>` of package names.
  static const String _blockedPackageNamesKey = 'blockedPackageNames';

  /// Multi-app: JSON-encoded `Map<String, String>` (packageName → displayName).
  static const String _blockedPackageDisplayNamesKey = 'blockedPackageDisplayNames';

  /// Native usage baseline: JSON-encoded `Map<String, int>`
  /// (packageName → nativeUsageMinutes at the time we last synced).
  /// Used to compute deltas so relaunch doesn't reset usedMinutes.
  static const String _nativeUsageBaselineKey = 'nativeUsageBaseline';

  /// Per-app used minutes: JSON-encoded `Map<String, int>` (packageName → usedMinutes).
  static const String _perAppUsedMinutesKey = 'perAppUsedMinutes';

  static const String _lastResetDayKey = 'lastResetDay';
  static const String _lastClockCheckKey = 'lastClockCheckTimestamp';
  static const String _selectedGoalKey = 'selectedGoal';

  /// 7-day history: JSON-encoded `List<DailyRecord>` (newest last).
  static const String _dailyHistoryKey = 'dailyHistory';

  /// Custom step goal: default 10000.
  static const String _customStepGoalKey = 'customStepGoal';

  /// Emergency snooze: tracks active emergency pass expiry timestamp (ms).
  static const String _emergencyPassExpiryKey = 'emergencyPassExpiry';

  Box<dynamic>? _box;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _migrateLegacySingleApp();
    validateDeviceClock();
  }

  /// Detects if system clock was rewound or manually manipulated.
  bool validateDeviceClock() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastCheck = (_box?.get(_lastClockCheckKey) as int?) ?? now;

    // If device time is more than 5 minutes in the past compared to last recorded check
    if (now < lastCheck - (5 * 60 * 1000)) {
      debugPrint('⚠️ Clock Tampering Detected: System time was set backwards!');
      return false;
    }

    _box?.put(_lastClockCheckKey, now);
    return true;
  }

  /// Selected user motivation goal from onboarding
  String get selectedGoal => (_box?.get(_selectedGoalKey) as String?) ?? 'Beat Doomscrolling';

  Future<void> setSelectedGoal(String goal) async {
    await _box?.put(_selectedGoalKey, goal);
  }

  /// Migrates the old single-app key to the new multi-app list if needed.
  void _migrateLegacySingleApp() {
    final legacy = _box?.get(_legacyBlockedAppPackageNameKey) as String?;
    if (legacy == null || legacy.isEmpty) return;

    // Only migrate if no multi-app data exists yet.
    final existing = _box?.get(_blockedPackageNamesKey);
    if (existing != null) return;

    final legacyName =
        (_box?.get(_legacyBlockedAppNameKey) as String?) ?? _formatPackageName(legacy);

    _box?.put(_blockedPackageNamesKey, jsonEncode([legacy]));
    _box?.put(_blockedPackageDisplayNamesKey, jsonEncode({legacy: legacyName}));
  }

  /// Key for the day the current totalStepsWalked value was written.
  /// Prevents pre-midnight (stale) values from being accepted after a daily
  /// reset: the first update of a new day is trusted even if it is lower than
  /// the stored (yesterday's) value.
  static const String _lastStepsDayKey = 'lastStepsDay';

  // ── Steps ─────────────────────────────────────────────────────────────────

  int get totalStepsWalked => (_box?.get(_totalStepsKey) as num?)?.toInt() ?? 0;

  Future<void> updateSteps(int newTotalSteps) async {
    if (!validateDeviceClock()) return;
    final today = _todayString;
    final lastStepsDay = (_box?.get(_lastStepsDayKey) as String?) ?? today;
    // First update of the day (or after a reset) is trusted as-is — it may be
    // a lower/zero value that legitimately replaces yesterday's total.
    // Subsequent same-day updates stay monotonic.
    if (lastStepsDay != today || newTotalSteps > totalStepsWalked) {
      await _box?.put(_totalStepsKey, newTotalSteps);
      await _box?.put(_lastStepsDayKey, today);
    }
  }

  // ── Custom Step Goal ──────────────────────────────────────────────────────

  /// User's chosen daily step goal (default 10,000).
  int get customStepGoal => (_box?.get(_customStepGoalKey) as int?) ?? 10000;

  Future<void> setCustomStepGoal(int goal) async {
    await _box?.put(_customStepGoalKey, goal.clamp(1000, 50000));
  }

  // ── Reward formula ────────────────────────────────────────────────────────

  /// Minutes rewarded per 1,000 steps. Default 30, range 5–60.
  int get minutesPer1kSteps => (_box?.get(_minutesPer1kStepsKey) as int?) ?? 30;

  Future<void> setMinutesPer1kSteps(int value) async {
    await _box?.put(_minutesPer1kStepsKey, value.clamp(5, 60));
  }

  /// Total minutes earned based on steps walked.
  /// Formula: (steps / 1000) * minutesPer1kSteps  (floating-point, then floor).
  int get earnedMinutes =>
      ((totalStepsWalked / 1000) * minutesPer1kSteps).floor();

  // ── Used time ─────────────────────────────────────────────────────────────

  static const String _usedSecondsKey = 'usedSecondsTotal';

  /// Total seconds consumed from the budget today.
  int get usedSecondsTotal =>
      (_box?.get(_usedSecondsKey) as int?) ??
      ((_box?.get(_usedMinutesKey) as int?) ?? 0) * 60;

  /// Total minutes consumed from the budget today.
  int get usedMinutes => (usedSecondsTotal / 60).floor();

  /// Remaining screen time, clamped to [0, earnedMinutes].
  int get remainingScreenTime {
    final emergencyBonus = _emergencyPassActiveMinutes;
    return (earnedMinutes - usedMinutes + emergencyBonus).clamp(
        0, (earnedMinutes + emergencyBonus) > 0 ? (earnedMinutes + emergencyBonus) : 0);
  }

  /// Map of packageName -> usedMinutes consumed per blocked application today.
  Map<String, int> get perAppUsedMinutes {
    final raw = _box?.get(_perAppUsedMinutesKey) as String?;
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Returns used minutes for a specific blocked package.
  int getUsedMinutesForApp(String packageName) =>
      perAppUsedMinutes[packageName] ?? 0;

  /// After calling [setAppTimeLimit] (which resets the native counter to 0),
  /// zero out our stored baseline for those packages so the next delta-sync
  /// correctly treats native usage as measured from 0.
  Future<void> resetNativeBaseline(List<String> packageNames) async {
    final baseline = Map<String, int>.from(_nativeBaseline);
    for (final pkg in packageNames) {
      baseline[pkg] = 0;
    }
    await _saveNativeBaseline(baseline);
  }

  /// Returns the stored native-usage baseline map (pkg → seconds).
  Map<String, int> get _nativeBaseline {
    final raw = _box?.get(_nativeUsageBaselineKey) as String?;
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveNativeBaseline(Map<String, int> baseline) async {
    await _box?.put(_nativeUsageBaselineKey, jsonEncode(baseline));
  }

  /// Delta-sync: called by BlockerService with the current raw native usage
  /// map (packageName → seconds).
  Future<void> syncNativeUsageDelta(Map<String, int> currentNativeUsage) async {
    final baseline = Map<String, int>.from(_nativeBaseline);
    final perApp = Map<String, int>.from(perAppUsedMinutes);
    int totalDeltaSeconds = 0;
    final newBaseline = <String, int>{};

    for (final entry in currentNativeUsage.entries) {
      final pkg = entry.key;
      final currentSec = entry.value;
      int baselineSec = baseline[pkg] ?? 0;

      // If the native counter was reset (e.g. after setAppTimeLimit or OS
      // midnight rollover), current < baseline.  Treat the entire current
      // value as fresh usage since the reset (baseline effectively = 0).
      if (currentSec < baselineSec) {
        debugPrint(
          'TimeBankService: native counter reset for $pkg '
          '(was $baselineSec sec, now $currentSec sec) — treating as delta from 0.',
        );
        baselineSec = 0;
      }

      final pkgDeltaSec = currentSec - baselineSec;
      if (pkgDeltaSec > 0) {
        totalDeltaSeconds += pkgDeltaSec;
        final deltaMin = (pkgDeltaSec / 60).floor();
        if (deltaMin > 0) {
          perApp[pkg] = (perApp[pkg] ?? 0) + deltaMin;
        }
      }

      // Always record current value as the new baseline for this package.
      newBaseline[pkg] = currentSec;
    }

    // Preserve baseline entries for packages not present in this sync cycle
    for (final entry in baseline.entries) {
      if (!newBaseline.containsKey(entry.key)) {
        newBaseline[entry.key] = entry.value;
      }
    }

    if (totalDeltaSeconds > 0) {
      final newUsedSeconds = usedSecondsTotal + totalDeltaSeconds;
      final newUsedMinutes = (newUsedSeconds / 60).floor();
      await _box?.put(_usedSecondsKey, newUsedSeconds);
      await _box?.put(_usedMinutesKey, newUsedMinutes);
      await _box?.put(_perAppUsedMinutesKey, jsonEncode(perApp));
      debugPrint(
        'TimeBankService: +$totalDeltaSeconds sec delta → totalUsedSeconds=$newUsedSeconds ($newUsedMinutes min)',
      );
    }

    await _saveNativeBaseline(newBaseline);
  }

  // ── Multi-app management ──────────────────────────────────────────────────

  /// All blocked package names.
  List<String> get blockedPackageNames {
    final raw = _box?.get(_blockedPackageNamesKey) as String?;
    if (raw == null) return ['com.instagram.android'];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (_) {
      return ['com.instagram.android'];
    }
  }

  /// Display names map (packageName → displayName).
  Map<String, String> get blockedPackageDisplayNames {
    final raw = _box?.get(_blockedPackageDisplayNamesKey) as String?;
    if (raw == null) {
      return {'com.instagram.android': 'Instagram'};
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {'com.instagram.android': 'Instagram'};
    }
  }

  /// Returns display name for a single package (with fallback).
  String displayNameFor(String packageName) {
    final names = blockedPackageDisplayNames;
    if (names.containsKey(packageName)) return names[packageName]!;
    final preset = CommonApps.presets.firstWhere(
      (p) => p.packageName == packageName,
      orElse: () =>
          PresetApp(name: _formatPackageName(packageName), packageName: packageName, category: 'App'),
    );
    return preset.name;
  }

  /// Optional callback invoked when blocked apps configuration is modified.
  VoidCallback? _onBlockedAppsChanged;

  /// Register callback for blocked apps change.
  void setBlockedAppsChangedCallback(VoidCallback cb) => _onBlockedAppsChanged = cb;

  /// Saves the full set of blocked apps in one call.
  Future<void> setBlockedApps(
    List<String> packageNames,
    Map<String, String> displayNames,
  ) async {
    await _box?.put(_blockedPackageNamesKey, jsonEncode(packageNames));
    await _box?.put(_blockedPackageDisplayNamesKey, jsonEncode(displayNames));
    // Reset the native baseline when the app list changes so delta-sync
    // doesn't carry over usage from removed apps.
    await _saveNativeBaseline({});
    _onBlockedAppsChanged?.call();
  }

  // ── Legacy single-app shims (used by existing UI that hasn't been updated) ──

  String get currentAppBlockingTarget {
    final names = blockedPackageNames;
    return names.isNotEmpty ? names.first : 'com.instagram.android';
  }

  String get currentAppBlockingName => displayNameFor(currentAppBlockingTarget);

  // ── Emergency Snooze (3-minute pass) ──────────────────────────────────────

  /// Cost in steps for one emergency 3-minute pass.
  static const int emergencyPassCostSteps = 1000;

  /// Duration of one emergency pass in minutes.
  static const int emergencyPassDurationMinutes = 3;

  /// Returns remaining minutes on active emergency pass (0 if none).
  int get _emergencyPassActiveMinutes {
    final expiry = (_box?.get(_emergencyPassExpiryKey) as int?);
    if (expiry == null) return 0;
    final remaining = expiry - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) return 0;
    return (remaining / 60000).ceil();
  }

  /// Whether an emergency pass is currently active.
  bool get hasActiveEmergencyPass => _emergencyPassActiveMinutes > 0;

  /// Returns the emergency pass expiry time, or null if none active.
  DateTime? get emergencyPassExpiry {
    if (!hasActiveEmergencyPass) return null;
    final expiry = _box?.get(_emergencyPassExpiryKey) as int?;
    if (expiry == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiry);
  }

  /// Attempt to consume an emergency 3-minute pass.
  /// Returns true if successful (enough steps & no active pass).
  /// Deducts [emergencyPassCostSteps] from the total step balance.
  Future<bool> consumeEmergencyPass() async {
    if (hasActiveEmergencyPass) return false;
    if (totalStepsWalked < emergencyPassCostSteps) return false;

    final newSteps = totalStepsWalked - emergencyPassCostSteps;
    await _box?.put(_totalStepsKey, newSteps);

    final expiry = DateTime.now()
        .add(const Duration(minutes: emergencyPassDurationMinutes))
        .millisecondsSinceEpoch;
    await _box?.put(_emergencyPassExpiryKey, expiry);

    debugPrint(
      'TimeBankService: Emergency pass activated! '
      '-$emergencyPassCostSteps steps for ${emergencyPassDurationMinutes}min unlock.',
    );
    return true;
  }

  // ── 7-Day Daily History ────────────────────────────────────────────────────

  /// The last 7 days of history records (oldest first).
  List<DailyRecord> get dailyHistory {
    final raw = _box?.get(_dailyHistoryKey) as String?;
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DailyRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveDailyHistory(List<DailyRecord> history) async {
    await _box?.put(
        _dailyHistoryKey, jsonEncode(history.map((r) => r.toJson()).toList()));
  }

  // ── Daily Streak ───────────────────────────────────────────────────────────

  /// Number of consecutive days the user has met their step goal (including today).
  int get currentStreakDays {
    final history = dailyHistory;
    if (history.isEmpty) return 0;

    int streak = 0;
    final goal = customStepGoal;
    // Iterate from most recent backwards
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i].steps >= goal) {
        streak++;
      } else {
        break;
      }
    }
    // Also count today if we already hit the goal (today might not be in history yet)
    if (totalStepsWalked >= goal) {
      // Today's record is not yet persisted (happens at midnight reset).
      // Ensure we count today if last history entry is yesterday or we have none.
      final today = _todayString;
      if (history.isEmpty || history.last.date != today) {
        streak++;
      }
    }
    return streak;
  }

  String get _todayString {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── Daily reset ───────────────────────────────────────────────────────────

  Future<void> resetDailyIfNeeded() async {
    final now = DateTime.now();
    final lastReset = _box?.get(_lastResetDayKey) as String?;
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (lastReset != today) {
      // Before resetting, archive today's totals to history
      if (lastReset != null) {
        await _archiveDayToHistory(lastReset);
      }

      await _box?.put(_totalStepsKey, 0);
      // Force the next step update to be trusted on the fresh day (it may be
      // 0 until the user actually walks).
      await _box?.put(_lastStepsDayKey, '');
      await _box?.put(_usedMinutesKey, 0);
      await _box?.put(_perAppUsedMinutesKey, jsonEncode({}));
      await _saveNativeBaseline({});
      await _box?.put(_lastResetDayKey, today);
      // Reset the earned-minutes guard in BlockerService so that
      // setAppTimeLimit is re-programmed with the fresh budget on the new day.
      // Import is avoided via a late reference resolved at call-time.
      _onDailyReset?.call();
    }
  }

  /// Saves the given day's snapshot into the rolling 7-day history.
  Future<void> _archiveDayToHistory(String date) async {
    final record = DailyRecord(
      date: date,
      steps: totalStepsWalked,
      earnedMinutes: earnedMinutes,
      usedMinutes: usedMinutes,
    );

    var history = List<DailyRecord>.from(dailyHistory);
    // Remove existing record for same date (shouldn't happen but guard it)
    history.removeWhere((r) => r.date == date);
    history.add(record);
    // Keep only last 7 days
    if (history.length > 7) {
      history = history.sublist(history.length - 7);
    }
    await _saveDailyHistory(history);
    debugPrint(
        'TimeBankService: Archived $date → steps=${record.steps}, earned=${record.earnedMinutes}min');
  }

  /// Optional callback invoked after a daily reset.
  /// Wired up by BlockerService at startup to call resetLastSetEarned().
  VoidCallback? _onDailyReset;

  /// Register the daily-reset callback (called once from BlockerService.initialize).
  void setDailyResetCallback(VoidCallback cb) => _onDailyReset = cb;

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _formatPackageName(String pkg) {
    final parts = pkg.split('.');
    if (parts.length > 1) {
      final name = parts.last;
      return name[0].toUpperCase() + name.substring(1);
    }
    return pkg;
  }
}

/// Popular Android package names and preset app list
class CommonApps {
  static const List<PresetApp> presets = [
    PresetApp(name: 'Instagram', packageName: 'com.instagram.android', category: 'Social'),
    PresetApp(name: 'TikTok', packageName: 'com.zhiliaoapp.musically', category: 'Social'),
    PresetApp(name: 'YouTube', packageName: 'com.google.android.youtube', category: 'Video'),
    PresetApp(name: 'X (Twitter)', packageName: 'com.twitter.android', category: 'Social'),
    PresetApp(name: 'Facebook', packageName: 'com.facebook.katana', category: 'Social'),
    PresetApp(name: 'Snapchat', packageName: 'com.snapchat.android', category: 'Social'),
    PresetApp(name: 'Reddit', packageName: 'com.reddit.frontpage', category: 'Social'),
    PresetApp(name: 'Netflix', packageName: 'com.netflix.mediaclient', category: 'Video'),
    PresetApp(name: 'WhatsApp', packageName: 'com.whatsapp', category: 'Chat'),
    PresetApp(name: 'Chrome', packageName: 'com.android.chrome', category: 'Browser'),
    PresetApp(name: 'Spotify', packageName: 'com.spotify.music', category: 'Music'),
    PresetApp(name: 'Discord', packageName: 'com.discord', category: 'Chat'),
    PresetApp(name: 'Telegram', packageName: 'org.telegram.messenger', category: 'Chat'),
    PresetApp(name: 'Pinterest', packageName: 'com.pinterest', category: 'Social'),
    PresetApp(name: 'LinkedIn', packageName: 'com.linkedin.android', category: 'Social'),
  ];
}

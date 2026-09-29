import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zo_app_blocker/zo_app_blocker.dart';
import 'companion_service.dart';
import 'revenuecat_service.dart';
import 'widget_service.dart';

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



  /// Tracks the last remaining-minutes value we armed the native trip-wire to.
  /// -1 = never set (forces first-run setup). Used in BlockerService to avoid
  /// re-arming the native OS timer every 5s cycle.
  static const String lastSetRemainingMinutesKey = 'lastSetRemainingMinutes';

  Box<dynamic>? _rawBox;

  Box<dynamic>? get _box {
    if (_rawBox != null && _rawBox!.isOpen) return _rawBox;
    if (Hive.isBoxOpen(_boxName)) {
      _rawBox = Hive.box(_boxName);
      return _rawBox;
    }
    return null;
  }

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Returns true if a daily reset is due (i.e. midnight has passed since last reset).
  bool get isDailyResetDue {
    final lastReset = _box?.get(_lastResetDayKey) as String?;
    return lastReset != null && lastReset != _todayString;
  }

  Timer? _midnightTimer;

  /// Schedules a one-shot timer for the next midnight (00:00:01) to automatically
  /// roll over the day, archive history, zero stats, and re-arm blocking.
  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final delay = nextMidnight.difference(now);

    _midnightTimer = Timer(delay, () async {
      debugPrint('TimeBankService: 🌙 Midnight timer triggered — executing daily reset.');
      await resetDailyIfNeeded();
      _scheduleMidnightTimer();
    });
  }

  Future<void> init() async {
    await Hive.initFlutter();
    _rawBox = await Hive.openBox(_boxName);
    _migrateLegacySingleApp();
    validateDeviceClock();
    await resetDailyIfNeeded();
    syncHomeWidget();
    _scheduleMidnightTimer();
  }

  /// Synchronize current step count and time bank balance to Android/iOS home screen widget.
  void syncHomeWidget() {
    final pkgs = blockedPackageNames;
    final selectedPkg = pkgs.isNotEmpty ? pkgs.first : 'com.instagram.android';
    final selectedName = displayNameFor(selectedPkg);

    final streak = CompanionService.instance.currentStreak;
    final dialogue = CompanionService.instance.getContextualDialogue(
      stepsToday: totalStepsWalked,
      remainingSeconds: remainingScreenTime * 60,
      permissionsHealthy: true,
    );

    WidgetService.instance.updateWidgetData(
      steps: totalStepsWalked,
      stepGoal: customStepGoal,
      earnedMinutes: earnedMinutes,
      usedMinutes: usedMinutes,
      remainingMinutes: remainingScreenTime,
      isPremium: RevenueCatService.instance.isPremium,
      streakDays: streak,
      dialogue: dialogue,
      selectedAppPackage: selectedPkg,
      selectedAppName: selectedName,
    );
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

  int get totalStepsWalked {
    if (isDailyResetDue) return 0;
    return (_box?.get(_totalStepsKey) as num?)?.toInt() ?? 0;
  }

  Future<void> updateSteps(int newTotalSteps) async {
    if (!validateDeviceClock()) return;
    await resetDailyIfNeeded();
    final today = _todayString;
    final lastStepsDay = (_box?.get(_lastStepsDayKey) as String?) ?? today;
    // First update of the day (or after a reset) is trusted as-is — it may be
    // a lower/zero value that legitimately replaces yesterday's total.
    // Subsequent same-day updates stay monotonic.
    if (lastStepsDay != today || newTotalSteps > totalStepsWalked) {
      await _box?.put(_totalStepsKey, newTotalSteps);
      await _box?.put(_lastStepsDayKey, today);
      _invalidateCalculatedCaches();
      syncHomeWidget();
    }
  }

  // ── Custom Step Goal ──────────────────────────────────────────────────────

  /// User's chosen daily step goal (default 10,000).
  int get customStepGoal => (_box?.get(_customStepGoalKey) as int?) ?? 10000;

  Future<void> setCustomStepGoal(int goal) async {
    await _box?.put(_customStepGoalKey, goal.clamp(1000, 50000));
    syncHomeWidget();
  }

  // ── Reward formula ────────────────────────────────────────────────────────

  /// Minutes rewarded per 1,000 steps.
  /// Free tier can access rates from 25 to 60 mins (rates below 25 min are locked for Pro strict mode).
  /// Fravo Pro users can unlock all custom rates from 5 to 60 mins.
  int get minutesPer1kSteps {
    final raw = (_box?.get(_minutesPer1kStepsKey) as int?) ?? 30;
    if (!RevenueCatService.instance.isPremium) {
      return raw.clamp(25, 60);
    }
    return raw.clamp(5, 60);
  }

  int? _cachedEarnedMinutes;
  int? _cachedUsedSecondsTotal;
  int? _cachedRemainingScreenTime;
  int? _cachedRemainingScreenTimeSeconds;
  Map<String, int>? _cachedPerAppUsedSeconds;

  void _invalidateCalculatedCaches() {
    _cachedEarnedMinutes = null;
    _cachedUsedSecondsTotal = null;
    _cachedRemainingScreenTime = null;
    _cachedRemainingScreenTimeSeconds = null;
    _cachedPerAppUsedSeconds = null;
  }

  Future<void> setMinutesPer1kSteps(int value) async {
    final isPremium = RevenueCatService.instance.isPremium;
    final minAllowed = isPremium ? 5 : 25;
    await _box?.put(_minutesPer1kStepsKey, value.clamp(minAllowed, 60));
    _invalidateCalculatedCaches();
  }

  /// Emergency pass bonus minutes added to earned time today.
  int get emergencyPassBonusMinutes {
    if (isDailyResetDue) return 0;
    return (_box?.get(_emergencyPassBonusMinutesKey) as int?) ?? 0;
  }

  /// Total minutes earned based on steps walked + emergency pass bonus minutes.
  /// Formula: (steps / 1000) * minutesPer1kSteps + emergencyPassBonusMinutes.
  int get earnedMinutes {
    if (isDailyResetDue) return 0;
    if (_cachedEarnedMinutes != null) return _cachedEarnedMinutes!;
    _cachedEarnedMinutes =
        ((totalStepsWalked / 1000) * minutesPer1kSteps).floor() +
        emergencyPassBonusMinutes;
    return _cachedEarnedMinutes!;
  }

  // ── Used time ─────────────────────────────────────────────────────────────

  static const String _usedSecondsKey = 'usedSecondsTotal';

  /// Total seconds consumed from the budget today.
  int get usedSecondsTotal {
    if (isDailyResetDue) return 0;
    if (_cachedUsedSecondsTotal != null) return _cachedUsedSecondsTotal!;
    _cachedUsedSecondsTotal = (_box?.get(_usedSecondsKey) as int?) ??
        ((_box?.get(_usedMinutesKey) as int?) ?? 0) * 60;
    return _cachedUsedSecondsTotal!;
  }

  /// Total minutes consumed from the budget today.
  int get usedMinutes => (usedSecondsTotal / 60).floor();

  /// Remaining screen time, clamped to [0, earnedMinutes].
  int get remainingScreenTime {
    if (isDailyResetDue) return 0;
    if (_cachedRemainingScreenTime != null) return _cachedRemainingScreenTime!;
    _cachedRemainingScreenTime = (earnedMinutes - usedMinutes).clamp(0, 999999);
    return _cachedRemainingScreenTime!;
  }

  /// Remaining screen time in **seconds** — more precise than [remainingScreenTime].
  /// Used by the dashboard countdown to show sub-minute resolution.
  int get remainingScreenTimeSeconds {
    if (isDailyResetDue) return 0;
    if (_cachedRemainingScreenTimeSeconds != null) {
      return _cachedRemainingScreenTimeSeconds!;
    }
    final earnedSec = earnedMinutes * 60;
    _cachedRemainingScreenTimeSeconds =
        (earnedSec - usedSecondsTotal).clamp(0, 999999);
    return _cachedRemainingScreenTimeSeconds!;
  }

  static const String _perAppUsedSecondsKey = 'perAppUsedSecondsTotal';

  /// Map of packageName -> usedSeconds consumed per blocked application today.
  Map<String, int> get perAppUsedSeconds {
    if (isDailyResetDue) return {};
    if (_cachedPerAppUsedSeconds != null) return _cachedPerAppUsedSeconds!;
    final raw = _box?.get(_perAppUsedSecondsKey) as String?;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _cachedPerAppUsedSeconds =
            decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
        return _cachedPerAppUsedSeconds!;
      } catch (_) {}
    }
    // Backward-compatibility fallback: migrate perAppUsedMinutes if seconds key missing
    final rawMin = _box?.get(_perAppUsedMinutesKey) as String?;
    if (rawMin != null) {
      try {
        final decoded = jsonDecode(rawMin) as Map<String, dynamic>;
        _cachedPerAppUsedSeconds =
            decoded.map((k, v) => MapEntry(k, (v as num).toInt() * 60));
        return _cachedPerAppUsedSeconds!;
      } catch (_) {}
    }
    _cachedPerAppUsedSeconds = {};
    return _cachedPerAppUsedSeconds!;
  }

  /// Map of packageName -> usedMinutes consumed per blocked application today.
  Map<String, int> get perAppUsedMinutes {
    return perAppUsedSeconds
        .map((k, seconds) => MapEntry(k, (seconds / 60).floor()));
  }

  /// Returns used seconds for a specific blocked package.
  int getUsedSecondsForApp(String packageName) =>
      perAppUsedSeconds[packageName] ?? 0;

  /// Returns used minutes for a specific blocked package.
  int getUsedMinutesForApp(String packageName) =>
      (getUsedSecondsForApp(packageName) / 60).floor();

  /// Returns a clean formatted string for app usage (e.g. "45s", "2m", "4m 15s").
  String getFormattedUsedTimeForApp(String packageName) {
    final totalSec = getUsedSecondsForApp(packageName);
    if (totalSec <= 0) return '0m';
    if (totalSec < 60) return '${totalSec}s';
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }

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

  static const String _isFreshResetPendingKey = 'isFreshResetPending';

  /// Delta-sync: called by BlockerService with the current raw native usage
  /// map (packageName → seconds).
  Future<void> syncNativeUsageDelta(Map<String, int> currentNativeUsage) async {
    final bool isFreshReset =
        (_box?.get(_isFreshResetPendingKey) as bool?) ?? false;
    if (isFreshReset) {
      // On a fresh day reset: seed baseline with current native values (or 0)
      // WITHOUT treating yesterday's remaining native counts as new usage!
      await _saveNativeBaseline(currentNativeUsage);
      await _box?.put(_isFreshResetPendingKey, false);
      debugPrint(
        'TimeBankService: Fresh day reset pending cleared — seeded native baseline for ${currentNativeUsage.length} app(s).',
      );
      return;
    }

    final baseline = Map<String, int>.from(_nativeBaseline);
    final perAppSec = Map<String, int>.from(perAppUsedSeconds);
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
        // Accumulate exact seconds per application
        perAppSec[pkg] = (perAppSec[pkg] ?? 0) + pkgDeltaSec;
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
      await _box?.put(_perAppUsedSecondsKey, jsonEncode(perAppSec));
      // Keep perAppUsedMinutes updated for backward compatibility
      final perAppMin =
          perAppSec.map((k, v) => MapEntry(k, (v / 60).floor()));
      await _box?.put(_perAppUsedMinutesKey, jsonEncode(perAppMin));
      _invalidateCalculatedCaches();
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
    
    final existingNames = blockedPackageDisplayNames;
    existingNames.addAll(displayNames);
    await _box?.put(_blockedPackageDisplayNamesKey, jsonEncode(existingNames));

    // Preserve existing native baselines for remaining packages
    // so delta-sync doesn't misinterpret existing native stats as new deltas.
    final oldBaseline = _nativeBaseline;
    final newBaseline = <String, int>{};
    for (final pkg in packageNames) {
      if (oldBaseline.containsKey(pkg)) {
        newBaseline[pkg] = oldBaseline[pkg]!;
      }
    }
    await _saveNativeBaseline(newBaseline);

    _onBlockedAppsChanged?.call();
  }

  // ── Legacy single-app shims (used by existing UI that hasn't been updated) ──

  String get currentAppBlockingTarget {
    final names = blockedPackageNames;
    return names.isNotEmpty ? names.first : 'com.instagram.android';
  }

  String get currentAppBlockingName => displayNameFor(currentAppBlockingTarget);

  // ── Tier Limits (Free vs Premium) ──────────────────────────────────────────

  /// Maximum allowed apps for blocking (1 for Free, Unlimited for Premium).
  int get maxAllowedBlockedApps =>
      RevenueCatService.instance.isPremium ? 999 : 1;

  /// Maximum emergency passes allowed per day (1 for Free, 3 for Premium).
  int get maxAllowedEmergencyPasses =>
      RevenueCatService.instance.isPremium ? 3 : 1;

  // ── Emergency Snooze (3-minute pass) ──────────────────────────────────────

  static const String _emergencyPassBonusMinutesKey = 'emergencyPassBonusMinutes';
  static const String _hasUsedEmergencyPassTodayKey = 'hasUsedEmergencyPassToday';
  static const String _emergencyPassCountTodayKey = 'emergencyPassCountToday';

  /// Duration of one emergency pass in minutes.
  static const int emergencyPassDurationMinutes = 3;

  /// Legacy shim maintained for compatibility.
  static const int emergencyPassCostSteps = 0;

  /// Total emergency passes used today.
  int get emergencyPassCountToday {
    if (isDailyResetDue) return 0;
    final count = _box?.get(_emergencyPassCountTodayKey) as int?;
    if (count != null) return count;
    final legacyUsed = (_box?.get(_hasUsedEmergencyPassTodayKey) as bool?) ?? false;
    return legacyUsed ? 1 : 0;
  }

  /// Whether the user has used all emergency passes allowed today.
  bool get hasUsedEmergencyPassToday =>
      emergencyPassCountToday >= maxAllowedEmergencyPasses;

  /// Remaining emergency passes available today.
  int get remainingEmergencyPassesToday =>
      (maxAllowedEmergencyPasses - emergencyPassCountToday).clamp(0, 3);

  /// Whether an emergency pass is available today.
  bool get canUseEmergencyPass =>
      emergencyPassCountToday < maxAllowedEmergencyPasses;

  /// Legacy shims maintained for UI compatibility.
  bool get hasActiveEmergencyPass => false;
  DateTime? get emergencyPassExpiry => null;

  /// Activates a 3-minute emergency pass.
  /// Adds +3 minutes directly to earnedMinutes balance.
  /// Returns true if successfully activated.
  Future<bool> activateEmergencyPass() async {
    if (!canUseEmergencyPass) return false;

    final newCount = emergencyPassCountToday + 1;
    await _box?.put(_emergencyPassCountTodayKey, newCount);
    await _box?.put(
      _hasUsedEmergencyPassTodayKey,
      newCount >= maxAllowedEmergencyPasses,
    );

    final currentBonus = emergencyPassBonusMinutes;
    await _box?.put(
      _emergencyPassBonusMinutesKey,
      currentBonus + emergencyPassDurationMinutes,
    );
    _invalidateCalculatedCaches();

    debugPrint(
      'TimeBankService: Emergency pass activated! '
      '+${emergencyPassDurationMinutes}min added. Pass $newCount of $maxAllowedEmergencyPasses used today.',
    );
    return true;
  }

  /// Alias for activateEmergencyPass
  Future<bool> consumeEmergencyPass() => activateEmergencyPass();

  // ── 7-Day Daily History ────────────────────────────────────────────────────

  /// The last 7 days of history records (oldest first).
  List<DailyRecord> get dailyHistory {
    final raw = _box?.get(_dailyHistoryKey) as String?;
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((item) => DailyRecord.fromJson(item as Map<String, dynamic>)).toList();
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
    final today = _todayString;
    final lastReset = _box?.get(_lastResetDayKey) as String?;
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
      // Also clear second-precision key so yesterday's seconds don't bleed in.
      await _box?.put(_usedSecondsKey, 0);
      await _box?.put(_emergencyPassBonusMinutesKey, 0);
      await _box?.put(_hasUsedEmergencyPassTodayKey, false);
      await _box?.put(_emergencyPassCountTodayKey, 0);
      await _box?.put(_perAppUsedMinutesKey, jsonEncode({}));
      await _box?.put(_perAppUsedSecondsKey, jsonEncode({}));
      await _box?.put(_lastResetDayKey, today);
      await _box?.put(_isFreshResetPendingKey, true);
      _invalidateCalculatedCaches();

      // Reset native SQLite usage counters for all monitored apps
      try {
        await ZoAppBlocker.instance.resetAllDailyUsage();
      } catch (e) {
        debugPrint('ZoAppBlocker.resetAllDailyUsage error: $e');
      }

      // Reset native-limit tracking keys so BlockerService re-arms fresh.
      await _box?.put(lastSetRemainingMinutesKey, -1);
      // Reset the earned-minutes guard in BlockerService so that
      // setAppTimeLimit is re-programmed with the fresh budget on the new day.
      _onDailyReset?.call();
      _onBlockedAppsChanged?.call();
    }
  }

  /// Forces an immediate daily reset for manual testing.
  Future<void> forceDailyResetNow() async {
    _invalidateCalculatedCaches();
    await _box?.put(_lastResetDayKey, 'FORCE_TEST_RESET');
    await resetDailyIfNeeded();
  }

  /// Saves the given day's snapshot into the rolling 7-day history.
  Future<void> _archiveDayToHistory(String date) async {
    final rawSteps = (_box?.get(_totalStepsKey) as num?)?.toInt() ?? 0;
    final rawUsedSeconds = (_box?.get(_usedSecondsKey) as int?) ??
        ((_box?.get(_usedMinutesKey) as int?) ?? 0) * 60;
    final rawUsedMinutes = (rawUsedSeconds / 60).floor();
    final rawPassBonus = (_box?.get(_emergencyPassBonusMinutesKey) as int?) ?? 0;
    final rawEarnedMinutes =
        ((rawSteps / 1000) * minutesPer1kSteps).floor() + rawPassBonus;

    final record = DailyRecord(
      date: date,
      steps: rawSteps,
      earnedMinutes: rawEarnedMinutes,
      usedMinutes: rawUsedMinutes,
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
        'TimeBankService: Archived $date → steps=${record.steps}, earned=${record.earnedMinutes}min, used=${record.usedMinutes}min');
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

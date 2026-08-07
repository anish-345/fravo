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

  // (limit-set tracking keys removed — now using resetNativeBaseline instead)

  static const String _lastResetDayKey = 'lastResetDay';

  Box<dynamic>? _box;

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    _migrateLegacySingleApp();
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

  // ── Steps ─────────────────────────────────────────────────────────────────

  int get totalStepsWalked => (_box?.get(_totalStepsKey) as num?)?.toInt() ?? 0;

  Future<void> updateSteps(int newTotalSteps) async {
    if (newTotalSteps > totalStepsWalked) {
      await _box?.put(_totalStepsKey, newTotalSteps);
    }
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

  /// Total minutes consumed from the budget today.
  int get usedMinutes => (_box?.get(_usedMinutesKey) as int?) ?? 0;

  /// Remaining screen time, clamped to [0, earnedMinutes].
  int get remainingScreenTime =>
      (earnedMinutes - usedMinutes).clamp(0, earnedMinutes > 0 ? earnedMinutes : 0);

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

  /// Returns the stored native-usage baseline map (pkg → minutes).
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
  /// map (packageName → minutes).
  Future<void> syncNativeUsageDelta(Map<String, int> currentNativeUsage) async {
    final baseline = Map<String, int>.from(_nativeBaseline);
    final perApp = Map<String, int>.from(perAppUsedMinutes);
    int totalDelta = 0;
    final newBaseline = <String, int>{};

    for (final entry in currentNativeUsage.entries) {
      final pkg = entry.key;
      final currentMinutes = entry.value;
      int baselineMinutes = baseline[pkg] ?? 0;

      // If the native counter was reset (e.g. after setAppTimeLimit or OS
      // midnight rollover), current < baseline.  Treat the entire current
      // value as fresh usage since the reset (baseline effectively = 0).
      if (currentMinutes < baselineMinutes) {
        debugPrint(
          'TimeBankService: native counter reset for $pkg '
          '(was $baselineMinutes, now $currentMinutes) — treating as delta from 0.',
        );
        baselineMinutes = 0;
      }

      final pkgDelta = currentMinutes - baselineMinutes;
      if (pkgDelta > 0) {
        totalDelta += pkgDelta;
        perApp[pkg] = (perApp[pkg] ?? 0) + pkgDelta;
      }

      // Always record current value as the new baseline for this package.
      newBaseline[pkg] = currentMinutes;
    }

    // Preserve baseline entries for packages not present in this sync cycle
    // (e.g. a package was temporarily unavailable from the native layer).
    for (final entry in baseline.entries) {
      if (!newBaseline.containsKey(entry.key)) {
        newBaseline[entry.key] = entry.value;
      }
    }

    if (totalDelta > 0) {
      // Do NOT clamp here — we want usedMinutes to exceed earnedMinutes when
      // the user has over-spent, so the blocker can detect remaining <= 0.
      final newUsed = usedMinutes + totalDelta;
      await _box?.put(_usedMinutesKey, newUsed);
      await _box?.put(_perAppUsedMinutesKey, jsonEncode(perApp));
      debugPrint(
        'TimeBankService: +$totalDelta min delta → usedMinutes=$newUsed',
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

  // ── Daily reset ───────────────────────────────────────────────────────────

  Future<void> resetDailyIfNeeded() async {
    final now = DateTime.now();
    final lastReset = _box?.get(_lastResetDayKey) as String?;
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (lastReset != today) {
      await _box?.put(_totalStepsKey, 0);
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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zo_app_blocker/zo_app_blocker.dart';

import 'time_bank.dart';

class BlockerService {
  BlockerService._();

  static final BlockerService instance = BlockerService._();

  final ZoAppBlocker _blocker = ZoAppBlocker.instance;

  // ── App list cache ────────────────────────────────────────────────────────
  /// In-memory cache: avoids re-querying the package manager (which is slow)
  /// every time the selector sheet opens. Invalidated after [_cacheTtl].
  static List<Map<String, dynamic>>? _appCache;
  static DateTime? _appCacheTimestamp;
  static const Duration _cacheTtl = Duration(hours: 1);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Initialises the blocker. Safe to call at startup — errors are caught.
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    try {
      await _blocker.initialize(blockScreenCallback: onBlockScreenRequested);
    } catch (e) {
      debugPrint('BlockerService.initialize error: $e');
    }
    try {
      await _blocker.setNotificationConfig(
        notificationBannerTitle: 'Fravo Active',
        notificationBannerDescription: 'Monitoring screen time limits.',
      );
    } catch (e) {
      debugPrint('BlockerService.setNotificationConfig error: $e');
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _blocker.requestUsageStatsPermission();
    } catch (e) {
      debugPrint('BlockerService.requestUsageStatsPermission error: $e');
    }
  }

  Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _blocker.requestOverlayPermission();
    } catch (e) {
      debugPrint('BlockerService.requestOverlayPermission error: $e');
    }
  }

  Future<void> requestAllPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      await _blocker.requestNotificationPermission();
    } catch (e) {
      debugPrint('BlockerService.requestNotificationPermission error: $e');
    }
    await requestUsageStatsPermission();
    await requestOverlayPermission();
  }

  Future<Map<String, bool>> checkPermissionsStatus() async {
    if (!Platform.isAndroid) {
      return {'usageStats': false, 'overlay': false, 'notification': false};
    }
    try {
      final usage = await _blocker.checkUsageStatsPermission();
      final overlay = await _blocker.checkOverlayPermission();
      final notification = await _blocker.checkNotificationPermission();
      return {
        'usageStats': usage == 'granted',
        'overlay': overlay == 'granted',
        'notification': notification == 'granted',
      };
    } catch (e) {
      debugPrint('checkPermissionsStatus error: $e');
      return {'usageStats': false, 'overlay': false, 'notification': false};
    }
  }

  // ── Block-state evaluation ────────────────────────────────────────────────

  /// Tracks whether the native time limit has been set for each package.
  /// setAppTimeLimit RESETS the native usage counter, so we call it ONCE per
  /// package (when earned minutes first becomes > 0). After that we only
  /// toggle block/unblock — never call setAppTimeLimit again.
  final Map<String, bool> _limitSet = {};

  /// Sets/removes the native time limit for every blocked app and enforces
  /// the block state. Handles the full list of blocked packages.
  ///
  /// CRITICAL: Calling [ZoAppBlocker.setAppTimeLimit] resets the native
  /// usage counter to 0. We therefore set the limit ONLY once per package
  /// (the first time earned > 0), then only toggle [blockApps]/[unblockAll].
  Future<void> evaluateBlockState() async {
    if (!Platform.isAndroid) return;

    final earned = TimeBankService.instance.earnedMinutes;
    final remaining = TimeBankService.instance.remainingScreenTime;
    final targets = TimeBankService.instance.blockedPackageNames;

    if (targets.isEmpty) return;

    try {
      if (remaining <= 0) {
        // Budget exhausted — block every target package immediately.
        try {
          await _blocker.unblockAll();
        } catch (_) {}
        try {
          await _blocker.blockApps(targets);
          debugPrint(
            'BlockerService: Blocked ${targets.length} package(s). Earned: $earned min, Used: ${TimeBankService.instance.usedMinutes} min.',
          );
        } catch (e) {
          debugPrint('BlockerService.blockApps error: $e');
        }
      } else if (earned > 0) {
        // Budget available — unblock and ensure the native limit is set.
        try {
          await _blocker.unblockAll();
        } catch (_) {}
        for (final pkg in targets) {
          if (!(_limitSet[pkg] ?? false)) {
            // First time seeing this package with earned > 0: set limit once.
            try {
              await _blocker.setAppTimeLimit(
                packageName: pkg,
                dailyLimitMinutes: earned,
              );
              _limitSet[pkg] = true;
              debugPrint(
                'BlockerService: Set initial limit for $pkg → $earned min.',
              );
            } catch (e) {
              debugPrint('BlockerService.setAppTimeLimit ($pkg) error: $e');
            }
          }
          // On subsequent calls with remaining > 0: skip setAppTimeLimit
          // to avoid resetting the native usage counter.
        }
      } else {
        // earned == 0: no screen time earned yet — ensure no limits are set.
        try {
          await _blocker.unblockAll();
        } catch (_) {}
        for (final pkg in targets) {
          try {
            await _blocker.removeAppTimeLimit(pkg);
          } catch (_) {}
        }
        _limitSet.clear();
      }
    } catch (e) {
      debugPrint('BlockerService.evaluateBlockState error: $e');
    }
  }

  // ── Usage sync (delta-based) ──────────────────────────────────────────────

  /// Reads native usage for every blocked package, then passes the raw map to
  /// [TimeBankService.syncNativeUsageDelta] which computes and stores only the
  /// increase since the last sync — preserving previously accumulated time
  /// across app relaunches.
  Future<void> syncUsageFromNative() async {
    if (!Platform.isAndroid) return;
    try {
      final limits = await _blocker.getAppTimeLimits();
      final targets = Set<String>.from(
        TimeBankService.instance.blockedPackageNames,
      );

      // Build a map of packageName → usedMinutes from the native layer.
      final Map<String, int> currentUsage = {};
      for (final limit in limits) {
        if (targets.contains(limit.packageName)) {
          currentUsage[limit.packageName] = limit.usedMinutes;
        }
      }

      // Hand off to TimeBankService for delta computation.
      await TimeBankService.instance.syncNativeUsageDelta(currentUsage);
    } catch (e) {
      debugPrint('BlockerService.syncUsageFromNative error: $e');
    }
  }

  // ── App listing / icons ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInstalledApps({
    bool forceRefresh = false,
  }) async {
    if (!Platform.isAndroid) return [];

    // Return cache if still fresh and not forcing a refresh.
    final cacheAge = _appCacheTimestamp == null
        ? null
        : DateTime.now().difference(_appCacheTimestamp!);
    if (!forceRefresh &&
        _appCache != null &&
        cacheAge != null &&
        cacheAge < _cacheTtl) {
      debugPrint(
        'BlockerService: returning cached app list (age: ${cacheAge.inMinutes}m).',
      );
      return _appCache!;
    }

    try {
      debugPrint(
        'BlockerService: fetching fresh app list from package manager...',
      );
      final apps = await _blocker.getApps();
      _appCache = apps;
      _appCacheTimestamp = DateTime.now();
      return apps;
    } catch (e) {
      debugPrint('BlockerService.getInstalledApps error: $e');
      // Return stale cache rather than empty list on error.
      return _appCache ?? [];
    }
  }

  /// Clears the in-memory app list cache. Call this if you need fresh data
  /// (e.g. the user installs/uninstalls an app during a session).
  void clearAppCache() {
    _appCache = null;
    _appCacheTimestamp = null;
    debugPrint('BlockerService: app list cache cleared.');
  }

  /// Fetches the PNG bytes of an app icon. Returns null if unavailable.
  Future<Uint8List?> getAppIcon(String packageName) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _blocker.getAppIcon(packageName);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> getConfiguration() {
    return {
      'blockedApps': TimeBankService.instance.blockedPackageNames,
      'minutesPer1kSteps': TimeBankService.instance.minutesPer1kSteps,
      'totalStepsWalked': TimeBankService.instance.totalStepsWalked,
      'earnedMinutes': TimeBankService.instance.earnedMinutes,
      'usedMinutes': TimeBankService.instance.usedMinutes,
      'remainingScreenTime': TimeBankService.instance.remainingScreenTime,
    };
  }
}

// ── Block-screen overlay (runs in its own isolate) ────────────────────────────

@pragma('vm:entry-point')
void onBlockScreenRequested() {
  ZoBlockScreenRunner.run(
    builder: (blockCtx) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.redAccent.withAlpha(80),
                          width: 2,
                        ),
                      ),
                      child: blockCtx.appIcon != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                blockCtx.appIcon!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(
                              Icons.lock_rounded,
                              size: 48,
                              color: Colors.redAccent,
                            ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      blockCtx.appName ?? 'Restricted App',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Screen Time Limit Reached',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Walk to Earn Access',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1,000 steps = 30 minutes of screen time.\nWalk around with your phone to earn more access!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: blockCtx.onDismiss,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text(
                          'Close App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

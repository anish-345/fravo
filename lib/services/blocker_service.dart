import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zo_app_blocker/zo_app_blocker.dart';

import 'time_bank.dart';
import 'health_service.dart';

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
    // Wire the daily-reset callback so the earned-minutes guard is cleared
    // whenever TimeBankService.resetDailyIfNeeded() triggers a new-day reset.
    TimeBankService.instance.setDailyResetCallback(resetLastSetEarned);
    // Wire the blocked-apps-changed callback to clear native trip-wire record.
    TimeBankService.instance.setBlockedAppsChangedCallback(resetLastSetEarned);

    if (!Platform.isAndroid) return;
    try {
      await _blocker.initialize(blockScreenCallback: onBlockScreenRequested);
    } catch (e) {
      debugPrint('BlockerService.initialize error: $e');
    }
    try {
      await _blocker.setNotificationConfig(
        notificationBannerTitle: 'Fravo Blocker Active',
        notificationBannerDescription: 'Monitoring screen time limits.',
        notificationIcon: 'ic_notification',
      );
    } catch (e) {
      debugPrint('BlockerService.setNotificationConfig error: $e');
    }

    try {
      await evaluateBlockState(forceRearm: true);
    } catch (e) {
      debugPrint('BlockerService.initialize evaluateBlockState error: $e');
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

  Future<void> requestAccessibilityPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _blocker.requestAccessibilityPermission();
    } catch (e) {
      debugPrint('BlockerService.requestAccessibilityPermission error: $e');
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

  Future<void> requestAllPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return;
    try {
      await _blocker.requestNotificationPermission();
    } catch (e) {
      debugPrint('BlockerService.requestNotificationPermission error: $e');
    }
    if (!context.mounted) return;
    await requestAccessibilityPermission();
    await requestOverlayPermission();
  }

  /// Returns whether the Accessibility Service permission is currently granted.
  Future<bool> checkAccessibilityStatus() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _blocker.checkAccessibilityPermission();
      return result == 'granted';
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, bool>> checkPermissionsStatus() async {
    if (!Platform.isAndroid) {
      return {
        'usageStats': false,
        'accessibility': false,
        'overlay': false,
        'notification': false,
        'activityRecognition': false,
        'healthConnect': false,
      };
    }
    try {
      final usage = await _blocker.checkUsageStatsPermission();
      final accessibility = await _blocker.checkAccessibilityPermission();
      final overlay = await _blocker.checkOverlayPermission();
      final notification = await _blocker.checkNotificationPermission();
      final activity = await HealthService.instance
          .checkActivityRecognitionPermission();
      final healthConnect = await HealthService.instance
          .checkHealthConnectPermission();
      return {
        'usageStats': usage == 'granted',
        'accessibility': accessibility == 'granted',
        'overlay': overlay == 'granted',
        'notification': notification == 'granted',
        'activityRecognition': activity,
        'healthConnect': healthConnect,
      };
    } catch (e) {
      debugPrint('checkPermissionsStatus error: $e');
      return {
        'usageStats': false,
        'accessibility': false,
        'overlay': false,
        'notification': false,
        'activityRecognition': false,
        'healthConnect': false,
      };
    }
  }

  // ── Concurrency guard + native limit tracking ────────────────────────────
  /// Prevents concurrent evaluations from double-counting usage.
  bool _isEvaluating = false;

  /// Tracks which earned-minutes value we last programmed into the native
  /// trip-wire. Persisted in Hive so app restarts don't re-arm the timer.
  /// -1 = never set (forces first-run setup).
  static const String _lastSetEarnedKey = 'lastSetEarnedMinutes';

  static bool shouldArmNativeLimit({
    required int earnedMinutes,
    required int lastSetEarnedMinutes,
    required bool forceRearm,
  }) {
    if (forceRearm) return true;
    return earnedMinutes != lastSetEarnedMinutes;
  }

  int get _lastSetEarnedMinutes {
    final box = Hive.box('time_bank');
    return (box.get(_lastSetEarnedKey) as int?) ?? -1;
  }

  Future<void> _saveLastSetEarned(int value) async {
    final box = Hive.box('time_bank');
    await box.put(_lastSetEarnedKey, value);
  }

  /// Call this whenever the blocked-app list changes or a daily reset happens,
  /// so the new apps receive proper native limits on the next evaluation.
  void resetLastSetEarned() {
    Hive.box('time_bank').put(_lastSetEarnedKey, -1);
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// Core enforcement loop.
  ///
  /// Called every 30 s by the usage timer and whenever earned minutes change.
  ///
  /// Design:
  /// • [syncUsageFromNative] runs first so [TimeBankService.usedMinutes] is
  ///   current before any decision is made.
  /// • [blockApps] is the PRIMARY enforcer — it fires every cycle when the
  ///   budget is exhausted.
  /// • [setAppTimeLimit] is a BACKGROUND fallback.  It is called only once
  ///   per new earned-minutes value so the OS timer starts at the correct
  ///   remaining time and counts down naturally without being reset every 30 s.
  ///   After each call the native counter resets to 0, so we also zero our
  ///   stored baseline via [TimeBankService.resetNativeBaseline].
  Future<void> evaluateBlockState({bool forceRearm = false}) async {
    if (!Platform.isAndroid) return;
    if (_isEvaluating) {
      debugPrint('BlockerService: skipped — already evaluating.');
      return;
    }
    _isEvaluating = true;
    try {
      // ── Step 0: daily reset check ───────────────────────────────────────────
      // Run this here (not only on app open) so a midnight crossing that
      // happens while the app is backgrounded is caught on the next enforcement
      // cycle driven by the native service.
      await TimeBankService.instance.resetDailyIfNeeded();

      // ── Step 1: sync native usage → update usedMinutes in Hive ─────────────
      await syncUsageFromNative();

      final earned = TimeBankService.instance.earnedMinutes;
      final used = TimeBankService.instance.usedMinutes;
      final targets = TimeBankService.instance.blockedPackageNames;

      debugPrint(
        'BlockerService: earned=$earned | used=$used | remaining=${earned - used} | apps=${targets.length}',
      );

      if (targets.isEmpty) {
        debugPrint('BlockerService: no blocked apps configured — skipping.');
        return;
      }

      // ── Step 2: decide block vs. allow ──────────────────────────────────────
      //
      // Block when:
      //   • earned == 0  → user hasn't walked at all today, no budget granted
      //   • used >= earned > 0 → budget fully consumed
      //
      // Allow when:
      //   • earned > 0 && used < earned → budget available

      final bool shouldBlock = (earned == 0) || (earned > 0 && used >= earned);

      if (shouldBlock) {
        // ── PRIMARY enforcer: blockApps ────────────────────────────────────────
        final reason = earned == 0
            ? 'no budget earned yet'
            : 'budget exhausted ($used/$earned min)';
        debugPrint(
          'BlockerService: 🚫 Blocking ${targets.length} app(s) — $reason.',
        );
        try {
          await _blocker.blockApps(targets);
          debugPrint('BlockerService: ✅ blockApps() called successfully.');
        } catch (e) {
          debugPrint('blockApps error: $e');
        }
        // Clear the trip-wire record so that when the user earns new minutes
        // (budget goes from exhausted → positive), setAppTimeLimit is re-armed
        // from the correct remaining value at that moment.
        await _saveLastSetEarned(-1);
      } else {
        // ── Budget available: unblock and arm the native trip-wire ─────────────
        debugPrint(
          'BlockerService: ✅ Budget available ($used/$earned min used) — unblocking.',
        );
        try {
          await _blocker.unblockAll();
        } catch (e) {
          debugPrint('unblockAll error: $e');
        }

        // Update native trip-wire ONLY when earned budget changes or forced (e.g. at startup/app changes).
        // This prevents resetting the OS countdown timer every 30 s cycle.
        //
        // The trip-wire is set to (earned - used) at this exact moment so
        // the OS timer starts from the correct remaining time — not from
        // the full earned budget or any other random value.
        if (shouldArmNativeLimit(
          earnedMinutes: earned,
          lastSetEarnedMinutes: _lastSetEarnedMinutes,
          forceRearm: forceRearm,
        )) {
          // Snapshot used NOW so the timer starts from the correct remaining
          // value at this exact moment (not a stale value from a prior cycle).
          final remaining = (earned - used).clamp(1, earned);
          debugPrint(
            'BlockerService: earned changed $earned min '
            '(was $_lastSetEarnedMinutes) '
            '→ setting native trip-wire to $remaining min '
            '(used=$used at set time).',
          );

          final List<String> updatedPkgs = [];
          for (final pkg in targets) {
            try {
              await _blocker.setAppTimeLimit(
                packageName: pkg,
                dailyLimitMinutes: remaining,
              );
              updatedPkgs.add(pkg);
              debugPrint(
                'BlockerService: trip-wire set → $pkg = $remaining min',
              );
            } catch (e) {
              debugPrint('setAppTimeLimit ($pkg) error: $e');
            }
          }

          if (updatedPkgs.isNotEmpty) {
            // setAppTimeLimit resets the native counter to 0.
            // Zero our baseline so the next delta-sync starts from 0.
            await TimeBankService.instance.resetNativeBaseline(updatedPkgs);
          }
          // Record the earned value so we don't re-arm on every 30s tick.
          await _saveLastSetEarned(earned);
        }
      }
    } catch (e) {
      debugPrint('BlockerService.evaluateBlockState error: $e');
    } finally {
      _isEvaluating = false;
    }
  }

  // ── Usage sync (delta-based) ──────────────────────────────────────────────

  /// Reads native usage for every blocked package, then passes the raw map to
  /// [TimeBankService.syncNativeUsageDelta] which computes and stores only the
  /// increase since the last sync.
  Future<void> syncUsageFromNative() async {
    if (!Platform.isAndroid) return;
    try {
      final limits = await _blocker.getAppTimeLimits();
      final targets = Set<String>.from(
        TimeBankService.instance.blockedPackageNames,
      );

      debugPrint(
        'BlockerService.syncUsageFromNative: ${limits.length} native entries, '
        'watching ${targets.length} package(s).',
      );

      // Build a map of packageName → usedMinutes from the native layer.
      final Map<String, int> currentUsage = {};
      for (final limit in limits) {
        if (targets.contains(limit.packageName)) {
          currentUsage[limit.packageName] = limit.usedMinutes;
          debugPrint(
            '  native: ${limit.packageName} → used=${limit.usedMinutes} min',
          );
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

  static final Map<String, Uint8List?> _iconMemoryCache = {};

  /// Fetches the PNG bytes of an app icon. Cached in memory for speed.
  Future<Uint8List?> getAppIcon(String packageName) async {
    if (!Platform.isAndroid) return null;
    if (_iconMemoryCache.containsKey(packageName)) {
      return _iconMemoryCache[packageName];
    }
    try {
      final icon = await _blocker.getAppIcon(packageName);
      _iconMemoryCache[packageName] = icon;
      return icon;
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
        // Light theme mirrors Android's native Digital Wellbeing pause screen
        theme: ThemeData(
          brightness: Brightness.light,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        ),
        home: _BlockScreen(blockCtx: blockCtx),
      );
    },
  );
}

class _BlockScreen extends StatefulWidget {
  final dynamic blockCtx;
  const _BlockScreen({required this.blockCtx});

  @override
  State<_BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<_BlockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  int _minutesPer1k = 30;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox('time_bank');
      final v = (box.get('minutesPer1kSteps') as int?) ?? 30;
      if (mounted) setState(() => _minutesPer1k = v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  static const _blockChannel = MethodChannel('zo_app_blocker_block_screen');

  /// Sends the user home and dismisses the overlay via the native service.
  /// Native handles HOME intent, overlay removal, and dismiss-state tracking.
  Future<void> _goHome() async {
    try {
      await _blockChannel.invokeMethod<void>('dismissBlockScreen');
    } catch (e) {
      debugPrint('_goHome dismiss error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appName = widget.blockCtx.appName as String? ?? 'This App';
    final appIcon = widget.blockCtx.appIcon as Uint8List?;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideUp,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── App icon ──────────────────────────────────────────────
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: appIcon != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.memory(appIcon, fit: BoxFit.cover),
                          )
                        : const Icon(
                            Icons.phone_android_rounded,
                            size: 44,
                            color: Color(0xFF9E9E9E),
                          ),
                  ),
                  const SizedBox(height: 20),

                  // ── Headline ──────────────────────────────────────────────
                  Text(
                    appName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You've used your screen time for today",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF757575),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Divider ───────────────────────────────────────────────
                  const Divider(color: Color(0xFFE0E0E0)),
                  const SizedBox(height: 24),

                  // ── Earn more tip ─────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_walk_rounded,
                          color: Color(0xFF2E7D32),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Walk to earn more time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '1,000 steps = $_minutesPer1k min of screen time',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // ── Go home button ────────────────────────────────────────
                  // Full-width, neutral — matches Android system dialog style.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _goHome,
                      child: const Text(
                        'Go Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

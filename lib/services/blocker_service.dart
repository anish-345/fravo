import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zo_app_blocker/zo_app_blocker.dart';

import '../widgets/ambient_aurora_background.dart';
import '../widgets/pippy_avatar_widget.dart';
import '../widgets/premium_glass_system.dart';
import 'companion_service.dart';
import 'health_service.dart';
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

  /// Requests notification permission only (iOS-style, progressive flow).
  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _blocker.requestNotificationPermission();
    } catch (e) {
      debugPrint('BlockerService.requestNotificationPermission error: $e');
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
      final isUsageGranted = usage == 'granted';
      final isAccessibilityGranted = accessibility == 'granted';
      final isOverlayGranted = overlay == 'granted';
      final isNotificationGranted = notification == 'granted';

      return {
        'usageStats': isUsageGranted,
        'usage_stats': isUsageGranted,
        'accessibility': isAccessibilityGranted,
        'overlay': isOverlayGranted,
        'notification': isNotificationGranted,
        'activityRecognition': activity,
        'healthConnect': healthConnect,
      };
    } catch (e) {
      debugPrint('checkPermissionsStatus error: $e');
      return {
        'usageStats': false,
        'usage_stats': false,
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

  /// Tracks which *remaining-minutes* value we last programmed into the native
  /// trip-wire. Persisted in Hive so app restarts don't re-arm unnecessarily.
  /// -1 = never set (forces first-run setup).
  ///
  /// Using *remaining* (not earned) catches the common case where the user
  /// has been using a blocked app between poll cycles — the earned budget
  /// hasn't changed, but the remaining window has shrunk, so we need to
  /// re-arm with the correct new remaining value.
  static const String _lastSetEarnedKey = 'lastSetEarnedMinutes'; // kept for compat

  int get _lastSetRemainingMinutes {
    final box = Hive.box('time_bank');
    // Prefer new key; fall back to old earned key for upgrade path.
    final v = box.get(TimeBankService.lastSetRemainingMinutesKey) as int?;
    if (v != null) return v;
    return (box.get(_lastSetEarnedKey) as int?) ?? -1;
  }

  Future<void> _saveLastSetRemaining(int value) async {
    final box = Hive.box('time_bank');
    await box.put(TimeBankService.lastSetRemainingMinutesKey, value);
  }

  static bool shouldArmNativeLimit({
    required int remaining,
    required int lastSetRemainingMinutes,
    required bool forceRearm,
  }) {
    if (forceRearm) return true;
    if (lastSetRemainingMinutes < 0) return true; // never set
    // Re-arm if remaining has changed by ≥1 minute since we last set it.
    // This covers:
    //   • User walked more → earned more → remaining grew
    //   • User used apps between cycles → remaining shrank
    //   • App list changed or daily reset
    return (remaining - lastSetRemainingMinutes).abs() >= 1;
  }

  /// Call this whenever the blocked-app list changes or a daily reset happens,
  /// so the new apps receive proper native limits on the next evaluation.
  void resetLastSetEarned() {
    Hive.box('time_bank').put(_lastSetEarnedKey, -1);
    Hive.box('time_bank').put(TimeBankService.lastSetRemainingMinutesKey, -1);
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
        // No apps configured → clear native state too, otherwise previously
        // blocked apps keep their exhausted time-limit rows and the native
        // enforcer re-blocks them on launch even though they were removed.
        debugPrint('BlockerService: no blocked apps configured — clearing native state.');
        try {
          await _blocker.unblockAll();
        } catch (e) {
          debugPrint('unblockAll error: $e');
        }
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
        await _saveLastSetRemaining(-1);
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

        // Update native trip-wire ONLY when remaining budget changes significantly
        // (≥1 min). Using *remaining* rather than *earned* catches the case where
        // the user used apps between cycles without us knowing (earned stays the
        // same but remaining has shrunk).
        final remaining = (earned - used).clamp(1, earned);
        if (shouldArmNativeLimit(
          remaining: remaining,
          lastSetRemainingMinutes: _lastSetRemainingMinutes,
          forceRearm: forceRearm,
        )) {
          debugPrint(
            'BlockerService: remaining changed $remaining min '
            '(was $_lastSetRemainingMinutes) → setting native trip-wire.',
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
          // Record remaining so we don't re-arm on every 5s tick.
          await _saveLastSetRemaining(remaining);

          // ── Update foreground-service notification with accurate remaining ──
          // This keeps the persistent notification's description in sync with
          // the actual budget, not just the initial "Monitoring screen time" text.
          try {
            final hrs = remaining ~/ 60;
            final mins = remaining % 60;
            final timeStr = hrs > 0 ? '${hrs}h ${mins}m left today' : '${mins}m left today';
            await _blocker.setNotificationConfig(
              notificationBannerTitle: 'Fravo — Screen Time Active',
              notificationBannerDescription:
                  '${targets.length} app${targets.length == 1 ? '' : 's'} monitored · $timeStr',
              notificationIcon: 'ic_notification',
            );
          } catch (e) {
            debugPrint('setNotificationConfig update error: $e');
          }
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

      // Build a map of packageName → usedSeconds from the native layer.
      final Map<String, int> currentUsageSeconds = {};
      for (final limit in limits) {
        if (targets.contains(limit.packageName)) {
          currentUsageSeconds[limit.packageName] = limit.usedSeconds;
          debugPrint(
            '  native: ${limit.packageName} → used=${limit.usedSeconds} sec (${limit.usedMinutes} min)',
          );
        }
      }

      // Hand off to TimeBankService for delta computation.
      await TimeBankService.instance.syncNativeUsageDelta(currentUsageSeconds);
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
  CompanionAura _aura = CompanionAura.mint;
  CompanionAccessory _accessory = CompanionAccessory.sprout;
  CompanionPersonality _personality = CompanionPersonality.zen;
  String _companionName = 'Pippy';
  String _userName = 'Friend';
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
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
      final name = (box.get('companion_name') as String?) ?? 'Pippy';
      final userNick = (box.get('user_display_name') as String?) ?? 'Friend';
      final streak = (box.get('currentStreakDays') as int?) ?? 0;

      final isPremium = (box.get('is_premium_cached', defaultValue: false) as bool);

      final auraStr = box.get('companion_aura') as String?;
      CompanionAura aura = CompanionAura.mint;
      if (auraStr != null && isPremium) {
        aura = CompanionAura.values.firstWhere(
          (e) => e.name == auraStr,
          orElse: () => CompanionAura.mint,
        );
      }

      final accStr = box.get('companion_accessory') as String?;
      CompanionAccessory acc = CompanionAccessory.sprout;
      if (accStr != null) {
        acc = CompanionAccessory.values.firstWhere(
          (e) => e.name == accStr,
          orElse: () => CompanionAccessory.sprout,
        );
      }

      final persStr = box.get('companion_personality') as String?;
      CompanionPersonality pers = CompanionPersonality.zen;
      if (persStr != null && isPremium) {
        pers = CompanionPersonality.values.firstWhere(
          (e) => e.name == persStr,
          orElse: () => CompanionPersonality.zen,
        );
      }

      if (mounted) {
        setState(() {
          _minutesPer1k = v;
          _companionName = name;
          _userName = userNick;
          _streakDays = streak;
          _aura = aura;
          _accessory = acc;
          _personality = pers;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  static const _blockChannel = MethodChannel('zo_app_blocker_block_screen');

  /// Sends the user home and dismisses the overlay via the native service.
  Future<void> _goHome() async {
    try {
      await _blockChannel.invokeMethod<void>('dismissBlockScreen');
    } catch (e) {
      debugPrint('_goHome dismiss error: $e');
    }
  }

  Future<void> _openFravo() async {
    try {
      // 1. Direct native launch (dismisses overlay and brings Fravo to foreground)
      await _blockChannel.invokeMethod<void>('openParentApp');
    } catch (_) {
      try {
        // 2. Fallback to OS-level deep link
        await _blockChannel.invokeMethod<void>('dismissBlockScreen');
        final uri = Uri.parse('fravo://screen_time');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('_openFravo deep link error: $e');
        await _goHome();
      }
    }
  }

  String _getBlockerDialogue(String appName) {
    switch (_personality) {
      case CompanionPersonality.zen:
        return '🧘 "Inhale calm, $_userName. A gentle stroll will awaken $appName."';
      case CompanionPersonality.hype:
        return '⚡ "Focus Bank is empty! Knock out a quick walk to unlock $appName!"';
      case CompanionPersonality.coach:
        return '🎯 "$_userName, focus protocol active. 1,000 steps = $_minutesPer1k min screen time."';
      case CompanionPersonality.cozy:
        return '🧸 "$_companionName is taking a cozy nap until we take a stroll together!"';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appName = widget.blockCtx.appName as String? ?? 'This App';
    final appIcon = widget.blockCtx.appIcon as Uint8List?;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: AmbientAuroraBackground(
        primaryGlow: _aura.deepColor,
        secondaryGlow: const Color(0xFF10B981),
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const Spacer(flex: 1),

                    // ── Central Mascot Stage with Blocked App Icon ───────────
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomRight,
                      children: [
                        PuffyGlassContainer(
                          borderRadius: 36,
                          tintColor: _aura.topColor,
                          padding: const EdgeInsets.all(16),
                          child: PippyAvatarWidget(
                            size: 130,
                            mood: PippyMood.sleepy,
                            aura: _aura,
                            accessory: _accessory,
                            streakDays: _streakDays,
                          ),
                        ),
                        if (appIcon != null)
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.memory(appIcon, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── Mascot Streak / Status Pill ──────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _streakDays >= 3
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _streakDays >= 3
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                              : const Color(0xFF10B981).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        _streakDays >= 3
                            ? '🔥 $_companionName · ${StreakTier.fromStreak(_streakDays).title.split(' ')[0]} Streak'
                            : '🌱 $_companionName · Focus Guardian',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _streakDays >= 3 ? const Color(0xFFD97706) : const Color(0xFF047857),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Headline ──────────────────────────────────────────────
                    Text(
                      appName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Daily screen time limit reached",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Pippy Guidance Glass Card ─────────────────────────────
                    PuffyGlassContainer(
                      borderRadius: 22,
                      tintColor: _aura.midColor,
                      tintAlpha: 0.65,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Column(
                        children: [
                          Text(
                            _getBlockerDialogue(appName),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.directions_walk_rounded, size: 16, color: Color(0xFF059669)),
                              const SizedBox(width: 6),
                              Text(
                                '1,000 steps = $_minutesPer1k min screen time',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // ── Earn Extra Time in Fravo Button ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: PuffyGlassPillButton(
                        label: 'Earn Screen Time in Fravo 🚀',
                        icon: Icons.bolt_rounded,
                        gradient: GlassPalette.mint,
                        onPressed: _openFravo,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Go back button ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _goHome,
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

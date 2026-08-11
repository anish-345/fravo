import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/blocker_service.dart';
import 'services/health_service.dart';
import 'services/time_bank.dart';
import 'widgets/app_selector_sheet.dart';
import 'widgets/blocking_permission_flow.dart';
import 'widgets/dashboard_cards.dart';
import 'widgets/premium_glass_system.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TimeBankService.instance.init();
  await BlockerService.instance.initialize();
  await HealthService.instance.initPedometerListener();
  await BlockerService.instance.evaluateBlockState();

  runApp(const FravoApp());
}

class FravoApp extends StatefulWidget {
  const FravoApp({super.key});

  @override
  State<FravoApp> createState() => _FravoAppState();
}

class _FravoAppState extends State<FravoApp> {
  bool _completedOnboarding = false;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('time_bank');
    _completedOnboarding =
        box.get('completedOnboarding', defaultValue: false) as bool;
  }

  void _onOnboardingComplete() {
    setState(() {
      _completedOnboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fravo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFECF0F5), // Ultra-light gray
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF4A90E2),
          secondary: const Color(0xFF10B981),
          surface: const Color(0xFFF8FAFB),
          error: const Color(0xFFEF4444),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1A202C)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A202C),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        useMaterial3: true,
        fontFamily: 'System',
      ),
      home: _completedOnboarding
          ? const FravoDashboard()
          : OnboardingScreen(onOnboardingComplete: _onOnboardingComplete),
    );
  }
}

class FravoDashboard extends StatefulWidget {
  const FravoDashboard({super.key});

  @override
  State<FravoDashboard> createState() => _FravoDashboardState();
}

class _FravoDashboardState extends State<FravoDashboard>
    with WidgetsBindingObserver {
  final _timeBank = TimeBankService.instance;
  final _healthService = HealthService.instance;
  final _blockerService = BlockerService.instance;

  String? _statusMessage;
  Timer? _usageTimer;

  // ── Local 1-second countdown ────────────────────────────────────────────
  // Event-driven: ticks every second ONLY while the budget is active and
  // a timed app could be running. This prevents stale "X min left" display
  // between the 5s native poll cycles.
  Timer? _countdownTimer;

  /// Snapshotted remaining seconds from the last native sync. The local
  /// countdown subtracts 1 each second until the next native sync corrects it.
  int _localRemainingSeconds = 0;

  /// Wall-clock timestamp when [_localRemainingSeconds] was last set from
  /// a real native sync. Used to detect drift and re-snap on next sync.
  DateTime? _remainingSetAt;

  /// How many consecutive 5s cycles have passed with the same permission
  /// result — used to throttle expensive IPC permission checks.
  int _permCheckCycle = 0;
  static const int _permCheckEveryNCycles = 6; // every 6×5s = 30s

  /// Cached permission status — computed once and reused to avoid
  /// re-rendering the disclosure banner on every rebuild.
  Map<String, bool>? _permissionsCache;

  /// Headline pill state — amber while nothing earned yet, green while
  /// budget remains, red when the budget is exhausted (blocked).
  Color get _headlineColor {
    if (_timeBank.earnedMinutes == 0) return const Color(0xFFF59E0B);
    return _timeBank.remainingScreenTime > 0
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
  }

  String get _headlineText {
    if (_timeBank.earnedMinutes == 0) {
      return 'Walk to earn your first minutes';
    }
    return _timeBank.remainingScreenTime > 0
        ? 'Move your body • Earn your screen time'
        : 'Move your body to unlock your screen';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
      _startUsageTimer();
      _startCountdown();
      _checkFirstWalkWelcome();
    });
  }

  void _checkFirstWalkWelcome() {
    try {
      final box = Hive.box('time_bank');
      final shown =
          box.get('hasShownFirstWalkWelcome', defaultValue: false) as bool;
      if (!shown && mounted) {
        box.put('hasShownFirstWalkWelcome', true);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: Colors.white,
            title: const Row(
              children: [
                Text('🎉 ', style: TextStyle(fontSize: 24)),
                Expanded(
                  child: Text(
                    'Welcome to Fravo!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your daily screen time economy is now active! Walk to earn minutes for your selected apps.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '💡 Tip: Take 50 steps right now with your phone in hand to see your live step counter update!',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Let\'s Walk! 🚶‍♂️',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing first walk dialog: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Re-syncs native usage when the app resumes from background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately sync usage when app resumes (don't wait for 5s timer)
      _pullUsageAndRefresh();
      // Restart the polling timer (was cancelled on pause).
      _startUsageTimer();
      _startCountdown();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Stop both timers — no need to poll while invisible.
      _usageTimer?.cancel();
      _usageTimer = null;
      _countdownTimer?.cancel();
      _countdownTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      // Correct drift: subtract elapsed time since last snap so the ring
      // doesn't show a stale value while the app was backgrounded.
      if (_remainingSetAt != null && _localRemainingSeconds > 0) {
        final elapsed = DateTime.now().difference(_remainingSetAt!).inSeconds;
        if (elapsed > 0 && mounted) {
          setState(() {
            _localRemainingSeconds =
                (_localRemainingSeconds - elapsed).clamp(0, _localRemainingSeconds);
          });
        }
      }
    }
  }

  Future<void> _checkPermissions() async {
    final status = await _blockerService.checkPermissionsStatus();
    if (mounted) {
      setState(() {
        _permissionsCache = status;
      });
    }
  }

  Future<void> _pullUsageAndRefresh() async {
    // 1. Refresh steps
    final steps = await _healthService.fetchTodaySteps();
    if (steps > 0) {
      await _timeBank.updateSteps(steps);
    }

    // 2. Evaluate block state — this syncs native usage internally first,
    //    then decides whether to block or update the native trip-wire limit.
    await _blockerService.evaluateBlockState();

    // 3. Snap the local countdown to the accurate value from native sync.
    if (mounted) {
      final newRemaining = _timeBank.remainingScreenTimeSeconds;
      setState(() {
        _localRemainingSeconds = newRemaining;
        _remainingSetAt = DateTime.now();
      });
    }

    // 4. Start / stop the 1-second countdown based on budget state.
    _startCountdown();
  }

  /// Starts the local 1-second countdown timer.
  ///
  /// Active only while [_localRemainingSeconds] > 0 (budget available).
  /// Stops itself when it hits zero (lets the next native poll handle blocking).
  void _startCountdown() {
    // Don't double-start.
    if (_countdownTimer != null && _countdownTimer!.isActive) return;
    // Only run if there's budget to count down.
    if (_localRemainingSeconds <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        if (_localRemainingSeconds > 0) {
          _localRemainingSeconds--;
        }
      });
      if (_localRemainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        // Budget just hit zero locally — trigger a native sync to apply blocking.
        _pullUsageAndRefresh();
      }
    });
  }

  void _startUsageTimer() {
    if (_usageTimer != null && _usageTimer!.isActive) return;
    _healthService.startAutoHealthSync();
    _permCheckCycle = 0;
    _usageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Only check permissions every 30s (6×5s cycles) — it's an expensive IPC.
      _permCheckCycle++;
      if (_permCheckCycle >= _permCheckEveryNCycles) {
        _permCheckCycle = 0;
        _checkPermissions();
      }
      _pullUsageAndRefresh();
    });
  }

  Future<void> _refresh() async {
    await _timeBank.resetDailyIfNeeded();
    await _checkPermissions();
    await _pullUsageAndRefresh();
  }

  /// Opens the app selector. The FIRST time the user tries to block an app,
  /// we gate it behind the progressive blocking-permission flow
  /// (Accessibility / Overlay / Usage) — never during onboarding.
  Future<void> _openAppSelector() async {
    final perms = await _blockerService.checkPermissionsStatus();
    final blockingMissing =
        !(perms['accessibility'] ?? false) ||
        !(perms['overlay'] ?? false) ||
        !(perms['usageStats'] ?? false);
    if (blockingMissing && mounted) {
      // Progressive gate: show one-at-a-time blocking permissions with
      // micro-explanations. The flow is skippable — the user can proceed
      // to pick apps regardless (permissions can be granted later).
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const BlockingPermissionsSheet(),
      );
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSelectorSheet(
        selectedPackageNames: Set<String>.from(_timeBank.blockedPackageNames),
        onAppsSelected: (packageNames, displayNames) async {
          await _timeBank.setBlockedApps(packageNames, displayNames);
          await _blockerService.evaluateBlockState();
          if (mounted) {
            setState(() {
              final count = packageNames.length;
              _statusMessage = count == 0
                  ? 'No apps selected.'
                  : '$count app${count == 1 ? '' : 's'} set for blocking.';
            });
          }
        },
      ),
    );
  }

  /// Opens the full settings screen (version / privacy / rewards / blocked
  /// apps / required permissions). Refreshes the dashboard when returning,
  /// in case the reward rate or step goal changed.
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          timeBank: _timeBank,
          blockerService: _blockerService,
          healthService: _healthService,
          onManageApps: () {
            Navigator.pop(context);
            _openAppSelector();
          },
        ),
      ),
    ).then((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _showEmergencySnooze() async {
    if (!_timeBank.canUseEmergencyPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'You have already used your 1 Emergency Pass today. Resets at midnight!',
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Color(0xFFEF4444), size: 22),
            Text(
              'Emergency 3-Min Pass',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need a quick urgent access?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use an Emergency Pass for 3 minutes of temporary access.\n\nThis costs 1,000 steps from your balance. Use wisely!',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${TimeBankService.emergencyPassDurationMinutes} minutes added to your earned time',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              final success = await _timeBank.consumeEmergencyPass();
              await _blockerService.evaluateBlockState();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                await _pullUsageAndRefresh();
              }
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '+3 minutes added to your earned screen time!'
                          : 'Could not activate pass. Check your steps balance.',
                    ),
                    backgroundColor: success
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            child: const Text('Use Emergency Pass'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _timeBank.remainingScreenTime;
    final totalSteps = _timeBank.totalStepsWalked;
    final earned = _timeBank.earnedMinutes;
    final used = _timeBank.usedMinutes;
    final minutesPer1kSteps = _timeBank.minutesPer1kSteps;
    final blockedApps = _timeBank.blockedPackageNames;
    final streak = _timeBank.currentStreakDays;
    final hasEmergencyPass = _timeBank.hasActiveEmergencyPass;
    final emergencyExpiry = _timeBank.emergencyPassExpiry;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fravo'),
            if (streak > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFF59E0B),
                      size: 15,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          // Stats button - glass icon
          GlassIconButton(
            icon: Icons.analytics_rounded,
            iconColor: const Color(0xFF4A90E2),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          // Settings button - glass icon → full SettingsScreen
          GlassIconButton(
            icon: Icons.settings_outlined,
            onPressed: _openSettings,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Date chip ───────────────────────────────────────────
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF1F2937).withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: Color(0xFF4B5563),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Headline pill ───────────────────────────────────────
              // Color/icon reflect the current state: blocked (no budget),
              // no budget earned yet, or budget remaining.
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _headlineColor.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _headlineColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        earned == 0
                            ? Icons.self_improvement_rounded
                            : remaining > 0
                            ? Icons.directions_walk_rounded
                            : Icons.lock_clock_rounded,
                        size: 16,
                        color: _headlineColor,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          _headlineText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _headlineColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Active Emergency Pass Banner ────────────────────────
              if (hasEmergencyPass && emergencyExpiry != null) ...[
                EmergencyPassBanner(
                  expiry: emergencyExpiry,
                  onExpired: () {
                    // Pass just expired — immediately sync and re-block.
                    _pullUsageAndRefresh();
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── Beautiful Permissions Setup Banner ─────────────────
              if (_permissionsCache != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: MissingPermissionsBanner(
                    permissions: _permissionsCache!,
                    onRefresh: _checkPermissions,
                  ),
                ),

              // ── Hero: Screen-Time Ring ──────────────────────────────────────
              TimeHeroCard(
                remaining: remaining,
                remainingSeconds: _localRemainingSeconds,
                earned: earned,
                used: used,
                steps: totalSteps,
              ),
              const SizedBox(height: 16),

              // ── Walk to Earn (live step → reward loop) ────────────────
              WalkToEarnCard(
                steps: totalSteps,
                earned: earned,
                used: used,
                remaining: remaining,
                minutesPer1kSteps: minutesPer1kSteps,
              ),

              const SizedBox(height: 16),

              // ── Blocked Apps ──────────────────────────────────────────
              BlockedAppsCard(
                apps: blockedApps,
                timeBank: _timeBank,
                onManage: _openAppSelector,
              ),

              const SizedBox(height: 24),

              // ── Emergency 3-Min Pass ──────────────────────────────────
              EmergencySnoozeCard(
                isAvailable: _timeBank.canUseEmergencyPass,
                onTap: _showEmergencySnooze,
              ),

              const SizedBox(height: 24),

              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF8FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBEE3F8)),
                    ),
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF2B6CB0),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              Text(
                '1,000 steps = $minutesPer1kSteps min screen time • Walk to earn access',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

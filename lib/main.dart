import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Cached permission status — computed once and reused to avoid
  /// re-rendering the disclosure banner on every rebuild.
  Map<String, bool>? _permissionsCache;

  /// Event channel: native → Flutter for instant sync on app open.
  static const _syncChannel = MethodChannel('zo_app_blocker_sync_events');
  StreamSubscription<dynamic>? _syncStreamSubscription;

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

    // Subscribe to native sync events for instant updates when apps are opened
    _syncChannel.setMethodCallHandler((call) async {
      debugPrint('Sync event received: ${call.method}');
      if (call.method == 'onAppResumed' || call.method == 'onAppOpened') {
        // Immediately sync usage when app is opened
        await _pullUsageAndRefresh();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
      _startUsageTimer();
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
    _syncStreamSubscription?.cancel();
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
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Stop the periodic timer — no need to poll while invisible.
      _usageTimer?.cancel();
      _usageTimer = null;
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

    if (mounted) setState(() {});
  }

  void _startUsageTimer() {
    if (_usageTimer != null && _usageTimer!.isActive) return;
    _healthService.startAutoHealthSync();
    _usageTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPermissions();
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
    final steps = _timeBank.totalStepsWalked;
    if (steps < TimeBankService.emergencyPassCostSteps) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need at least ${TimeBankService.emergencyPassCostSteps} steps to use an emergency pass. Walk more first!',
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
                    'Cost: ${TimeBankService.emergencyPassCostSteps} steps → ${TimeBankService.emergencyPassDurationMinutes} minutes',
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
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '3-minute pass active! Use it wisely.'
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
                EmergencyPassBanner(expiry: emergencyExpiry),
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
              if (!hasEmergencyPass)
                EmergencySnoozeCard(
                  totalSteps: totalSteps,
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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'screens/stats_screen.dart';
import 'services/blocker_service.dart';
import 'services/health_service.dart';
import 'services/time_bank.dart';
import 'widgets/app_selector_sheet.dart';
import 'widgets/premium_glass_system.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TimeBankService.instance.init();
  await BlockerService.instance.initialize();
  await HealthService.instance.initPedometerListener();
  await BlockerService.instance.evaluateBlockState();

  runApp(const FravoApp());
}

class FravoApp extends StatelessWidget {
  const FravoApp({super.key});

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
      home: const FravoDashboard(),
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

  /// Periodic timer that refreshes usage from the native layer every 2 min.
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _refresh();
      _startUsageTimer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usageTimer?.cancel();
    super.dispose();
  }

  /// Re-syncs native usage when the app resumes from background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Restart the polling timer (was cancelled on pause).
      _startUsageTimer();
      // Catch any midnight crossing that happened while backgrounded.
      _refresh();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Stop the periodic timer — no need to poll while invisible.
      _usageTimer?.cancel();
      _usageTimer = null;
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
    // Guard: don't create a second timer if one is already running.
    if (_usageTimer != null && _usageTimer!.isActive) return;
    _healthService.startAutoHealthSync();
    _usageTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pullUsageAndRefresh();
    });
  }

  Future<void> _refresh() async {
    await _timeBank.resetDailyIfNeeded();
    await _pullUsageAndRefresh();
  }

  void _openAppSelector() {
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

  void _showSettingsDialog() {
    int currentMinutesPer1kSteps = _timeBank.minutesPer1kSteps;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.settings_rounded, color: Color(0xFF2D3748)),
                SizedBox(width: 8),
                Text('App Settings'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blocked apps summary
                const Text(
                  'Blocked Apps',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _openAppSelector();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.apps_rounded,
                          color: Color(0xFF2D3748),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _timeBank.blockedPackageNames.isEmpty
                                ? 'No apps selected'
                                : _timeBank.blockedPackageNames
                                      .map((p) => _timeBank.displayNameFor(p))
                                      .join(', '),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.swap_horiz_rounded,
                          color: Color(0xFF2D3748),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Permissions
                const Text(
                  'Required Android Permissions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, bool>>(
                  future: _blockerService.checkPermissionsStatus(),
                  builder: (context, snapshot) {
                    final status = snapshot.data ?? {};
                    final accessOk = status['accessibility'] ?? false;
                    final overlayOk = status['overlay'] ?? false;
                    final notifOk = status['notification'] ?? false;

                    return Column(
                      children: [
                        _PermissionStatusTile(
                          label: 'Accessibility Service (Required)',
                          isGranted: accessOk,
                          onTap: () async {
                            await _blockerService.requestAccessibilityPermissionWithDisclosure(context);
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 6),
                        _PermissionStatusTile(
                          label: 'Display Over Apps',
                          isGranted: overlayOk,
                          onTap: () async {
                            await _blockerService.requestOverlayPermission();
                            setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 6),
                        _PermissionStatusTile(
                          label: 'Notifications',
                          isGranted: notifOk,
                          onTap: () async {
                            await _blockerService.requestAllPermissions(context);
                            setDialogState(() {});
                          },
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Reward rate slider: 5–60 min per 1k steps
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text(
                        'Mins per 1,000 Steps',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D3748),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$currentMinutesPer1kSteps min',
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Slider(
                  value: currentMinutesPer1kSteps.toDouble(),
                  min: 5,
                  max: 60,
                  divisions: 11, // 5, 10, 15, … 60
                  activeColor: const Color(0xFF2D3748),
                  label: '$currentMinutesPer1kSteps mins / 1k steps',
                  onChanged: (val) {
                    // Snap to nearest multiple of 5
                    final snapped = (val / 5).round() * 5;
                    setDialogState(() {
                      currentMinutesPer1kSteps = snapped.clamp(5, 60);
                    });
                  },
                ),
                Text(
                  '1,000 steps = $currentMinutesPer1kSteps min of screen time',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
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
                  backgroundColor: const Color(0xFF2D3748),
                ),
                onPressed: () async {
                  await _timeBank.setMinutesPer1kSteps(
                    currentMinutesPer1kSteps,
                  );
                  await _blockerService.evaluateBlockState();
                  if (ctx.mounted) {
                    setState(() {});
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Settings'),
              ),
            ],
          );
        },
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fravo'),
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
          // Settings button - glass icon
          GlassIconButton(
            icon: Icons.settings_outlined,
            onPressed: _showSettingsDialog,
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
              // Date Header
              Text(
                DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 28),

              // ── Permissions Setup Banner (for New / Unpermitted Users) ─────────────────
              FutureBuilder<Map<String, bool>>(
                future: _blockerService.checkPermissionsStatus(),
                builder: (context, snapshot) {
                  final status = snapshot.data ?? {};
                  final usageOk = status['usageStats'] ?? false;
                  final overlayOk = status['overlay'] ?? false;
                  final notifOk = status['notification'] ?? false;

                  if (usageOk && overlayOk && notifOk) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: UltraGlassContainer(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'PERMISSIONS REQUIRED',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFEF4444),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Fravo needs Accessibility Service & Overlay permissions to enforce app limits.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _PermissionStatusTile(
                            label: 'Accessibility Service',
                            isGranted: status['accessibility'] ?? false,
                            onTap: () async {
                              await _blockerService
                                  .requestAccessibilityPermissionWithDisclosure(context);
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 6),
                          _PermissionStatusTile(
                            label: 'Display Over Apps',
                            isGranted: overlayOk,
                            onTap: () async {
                              await _blockerService.requestOverlayPermission();
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(height: 6),
                          _PermissionStatusTile(
                            label: 'Notifications',
                            isGranted: notifOk,
                            onTap: () async {
                              await _blockerService.requestAllPermissions(context);
                              if (mounted) setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Main Hero Row (Screen Time Left & Blocked Apps side-by-side) ──
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left: Screen Time Left Card
                    Expanded(
                      flex: 5,
                      child: GlassHeroCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SCREEN TIME LEFT',
                              style: TextStyle(
                                color: const Color(
                                  0xFF64748B,
                                ).withValues(alpha: 0.8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$remaining',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF1A202C),
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'minutes',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (earned > 0) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 6,
                                  child: LinearProgressIndicator(
                                    value: (used / earned).clamp(0.0, 1.0),
                                    backgroundColor: const Color(
                                      0xFF64748B,
                                    ).withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      remaining > 0
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$used used · $earned earned',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: remaining > 0
                                    ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.12)
                                    : const Color(
                                        0xFFEF4444,
                                      ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: remaining > 0
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.3)
                                      : const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                remaining > 0 ? 'ACTIVE' : 'BLOCKED',
                                style: TextStyle(
                                  color: remaining > 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right: Blocked Apps Card (with app icons)
                    Expanded(
                      flex: 5,
                      child: GlassHeroCard(
                        child: InkWell(
                          onTap: _openAppSelector,
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFEF4444,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.block_rounded,
                                      color: Color(0xFFEF4444),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFEF4444,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${blockedApps.length} Apps',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'BLOCKED APPS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (blockedApps.isEmpty)
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'Tap to add apps',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: blockedApps.take(3).map((pkg) {
                                      final name = _timeBank.displayNameFor(
                                        pkg,
                                      );
                                      final usedMins = _timeBank
                                          .getUsedMinutesForApp(pkg);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            _AppIconWidget(
                                              packageName: pkg,
                                              blockerService: _blockerService,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1A202C),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${usedMins}m',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: _openAppSelector,
                                    child: const Text(
                                      'Manage →',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF4A90E2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Metric Cards (Glass) ──────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GlassMetricCard(
                        value: totalSteps >= 1000
                            ? '${(totalSteps / 1000).toStringAsFixed(1)}k'
                            : '$totalSteps',
                        label: 'Steps Walked',
                        unit: 'steps',
                        subtitle:
                            '${((totalSteps * 0.762) / 1000).toStringAsFixed(2)} km today',
                        subtitleIcon: Icons.straighten_rounded,
                        subtitleColor: const Color(0xFF4A90E2),
                        icon: Icons.directions_walk_rounded,
                        iconColor: const Color(0xFF4A90E2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassMetricCard(
                        value: '$earned',
                        label: 'Earned Time',
                        unit: 'mins',
                        subtitle: '-${used}m used',
                        subtitleIcon: Icons.remove_circle_outline_rounded,
                        subtitleColor: const Color(0xFFEF4444),
                        icon: Icons.timer_rounded,
                        iconColor: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
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
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Permission Status Tile ────────────────────────────────────────────────────

/// A compact tile that shows whether a specific Android permission is granted.
/// Tapping it calls [onTap] to open the relevant settings page.
class _PermissionStatusTile extends StatelessWidget {
  const _PermissionStatusTile({
    required this.label,
    required this.isGranted,
    required this.onTap,
  });

  final String label;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isGranted ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isGranted ? const Color(0xFFE6FFED) : const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isGranted
                ? const Color(0xFF68D391)
                : const Color(0xFFFC8181),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isGranted ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: isGranted
                  ? const Color(0xFF38A169)
                  : const Color(0xFFE53E3E),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isGranted
                      ? const Color(0xFF276749)
                      : const Color(0xFF9B2C2C),
                ),
              ),
            ),
            if (!isGranted)
              const Text(
                'Tap to grant →',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFE53E3E),
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (isGranted)
              const Text(
                'Granted ✓',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF38A169),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── App Icon Component ───────────────────────────────────────────────────────

/// Asynchronously fetches and renders native PNG app icon with fallback.
class _AppIconWidget extends StatelessWidget {
  final String packageName;
  final BlockerService blockerService;
  final double size;

  const _AppIconWidget({
    required this.packageName,
    required this.blockerService,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: blockerService.getAppIcon(packageName),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.3),
            child: Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(
            Icons.phone_android_rounded,
            size: size * 0.6,
            color: const Color(0xFFEF4444),
          ),
        );
      },
    );
  }
}

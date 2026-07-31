import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services/blocker_service.dart';
import 'services/health_service.dart';
import 'services/time_bank.dart';
import 'widgets/app_selector_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TimeBankService.instance.init();
  await BlockerService.instance.initialize();
  await HealthService.instance.initPedometerListener();

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
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2D3748),
          secondary: Color(0xFF4A5568),
          surface: Colors.white,
        ),
        useMaterial3: true,
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

  bool _syncing = false;
  String? _statusMessage;

  /// Periodic timer that refreshes usage from the native layer every 2 min.
  Timer? _usageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay first refresh by 2 s so the native service has time to start.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      _refresh();
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
      _pullUsageAndRefresh();
    }
  }

  Future<void> _pullUsageAndRefresh() async {
    final steps = await _healthService.fetchTodaySteps();
    if (steps > 0) {
      await _timeBank.updateSteps(steps);
    }
    await _blockerService.syncUsageFromNative();
    await _blockerService.evaluateBlockState();
    if (mounted) setState(() {});
  }

  void _startUsageTimer() {
    _healthService.startAutoHealthSync();
    _usageTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _pullUsageAndRefresh();
      }
    });
  }

  Future<void> _refresh() async {
    await _timeBank.resetDailyIfNeeded();
    await _pullUsageAndRefresh();
  }

  Future<void> _syncWorkouts() async {
    setState(() {
      _syncing = true;
      _statusMessage = null;
    });

    try {
      await _blockerService.requestAllPermissions();

      final granted = await _healthService.requestPermissions();
      if (!granted) {
        setState(() {
          _statusMessage = 'Health Connect permissions required.';
        });
        return;
      }

      final steps = await _healthService.fetchTodaySteps();
      await _timeBank.updateSteps(steps);

      // After step update, sync usage and re-apply the new time limit.
      await _blockerService.syncUsageFromNative();
      await _blockerService.evaluateBlockState();

      if (steps == 0) {
        setState(() {
          _statusMessage =
              '0 steps recorded today.\n'
              'Walk around with your phone or grant Physical Activity permission to track steps!';
        });
      } else {
        setState(() {
          _statusMessage = 'Synced ${_formatSteps(steps)} steps successfully!';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Sync failed: $e';
      });
    } finally {
      setState(() => _syncing = false);
    }
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return steps.toString();
  }

  void _openAppSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppSelectorSheet(
        selectedPackageNames:
            Set<String>.from(_timeBank.blockedPackageNames),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDF2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apps_rounded,
                            color: Color(0xFF2D3748), size: 20),
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
                        const Icon(Icons.swap_horiz_rounded,
                            color: Color(0xFF2D3748)),
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
                    final usageOk = status['usageStats'] ?? false;
                    final overlayOk = status['overlay'] ?? false;
                    final notifOk = status['notification'] ?? false;

                    return Column(
                      children: [
                        _PermissionStatusTile(
                          label: 'Usage Access',
                          isGranted: usageOk,
                          onTap: () async {
                            await _blockerService.requestUsageStatsPermission();
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
                            await _blockerService.requestAllPermissions();
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Mins per 1,000 Steps',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D3748),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$currentMinutesPer1kSteps min',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
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
                  await _timeBank.setMinutesPer1kSteps(currentMinutesPer1kSteps);
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
        title:
            const Text('Fravo', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
          ),
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
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // ── Main Screen Time Card ──────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'SCREEN TIME LEFT',
                      style: TextStyle(
                        color: Color(0xFFA0AEC0),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$remaining',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 84,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'minutes',
                      style:
                          TextStyle(color: Color(0xFF718096), fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    // Progress bar: used / earned
                    if (earned > 0) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (used / earned).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            remaining > 0
                                ? Colors.greenAccent
                                : Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$used used · $earned earned',
                        style: const TextStyle(
                          color: Color(0xFF718096),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: remaining > 0
                            ? Colors.green.withAlpha(40)
                            : Colors.red.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: remaining > 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        remaining > 0
                            ? 'ACTIVE • MINUTES REMAINING'
                            : 'BLOCKED • WALK TO UNLOCK',
                        style: TextStyle(
                          color: remaining > 0
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Blocked Apps Tile ──────────────────────────────────────
              InkWell(
                onTap: _openAppSelector,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF2F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_outlined,
                            color: Color(0xFF2D3748)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'BLOCKED APPS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF718096),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2D3748),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${blockedApps.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (blockedApps.isEmpty)
                              const Text(
                                'No apps selected — tap to choose',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: blockedApps.map((pkg) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDF2F7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _timeBank.displayNameFor(pkg),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D3748),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit_rounded,
                          color: Color(0xFFA0AEC0), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Metric Cards ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Steps Walked',
                      value: totalSteps >= 1000
                          ? '${(totalSteps / 1000).toStringAsFixed(1)}k'
                          : '$totalSteps',
                      unit: 'steps',
                      icon: Icons.directions_walk_rounded,
                      color: const Color(0xFF3182CE),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _MetricCard(
                      label: 'Earned Time',
                      value: '$earned',
                      unit: 'mins',
                      icon: Icons.timer_rounded,
                      color: const Color(0xFF38A169),
                    ),
                  ),
                ],
              ),

              // Steps-to-next-reward progress
              const SizedBox(height: 16),
              _StepsProgressCard(
                totalSteps: totalSteps,
                minutesPer1kSteps: minutesPer1kSteps,
              ),
              const SizedBox(height: 24),

              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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

              // ── Sync Button ───────────────────────────────────────────
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3748),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                onPressed: _syncing ? null : _syncWorkouts,
                icon: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  _syncing ? 'SYNCING HEALTH DATA...' : 'SYNC WORKOUTS NOW',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                '1,000 steps = $minutesPer1kSteps min screen time • Walk to earn access',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFA0AEC0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Steps Progress Card ───────────────────────────────────────────────────────

/// Shows progress toward the next 1,000-step milestone.
class _StepsProgressCard extends StatelessWidget {
  final int totalSteps;
  final int minutesPer1kSteps;

  const _StepsProgressCard({
    required this.totalSteps,
    required this.minutesPer1kSteps,
  });

  @override
  Widget build(BuildContext context) {
    final completedK = totalSteps ~/ 1000;
    final remainder = totalSteps % 1000;
    final progress = remainder / 1000.0;
    final stepsToNext = 1000 - remainder;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF38A169).withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFF38A169), size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Next Reward',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Text(
                '$stepsToNext steps away',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF718096),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF38A169)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$remainder / 1,000 steps  •  ${completedK}k completed  •  +$minutesPer1kSteps min reward',
            style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
          ),
        ],
      ),
    );
  }
}

// ── Metric Card ───────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF718096),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
        ],
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
          color: isGranted
              ? const Color(0xFFE6FFED)
              : const Color(0xFFFFF5F5),
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
              isGranted
                  ? Icons.check_circle_rounded
                  : Icons.warning_rounded,
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

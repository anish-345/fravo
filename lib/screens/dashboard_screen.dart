import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'paywall_screen.dart';
import 'pet_screen.dart';
import '../services/admob_service.dart';
import '../services/blocker_service.dart';
import '../services/companion_service.dart';
import '../services/health_service.dart';
import '../services/onesignal_service.dart';
import '../services/revenuecat_service.dart';
import '../services/time_bank.dart';
import '../widgets/ambient_aurora_background.dart';
import '../widgets/app_selector_sheet.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/permission_recovery_banner.dart';
import '../widgets/pippy_avatar_widget.dart';
import '../widgets/premium_glass_system.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Main Dashboard Screen of Fravo with Pippy Mascot, Screen-Time Economy, and Fabulous Rituals.
class FravoDashboard extends StatefulWidget {
  const FravoDashboard({super.key});

  @override
  State<FravoDashboard> createState() => _FravoDashboardState();
}

class _FravoDashboardState extends State<FravoDashboard>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _timeBank = TimeBankService.instance;
  final _healthService = HealthService.instance;
  final _blockerService = BlockerService.instance;

  String? _statusMessage;
  Timer? _usageTimer;
  Timer? _countdownTimer;
  bool _isRefreshing = false;

  final ValueNotifier<int> _secondsRemainingNotifier = ValueNotifier<int>(0);
  int _localRemainingSeconds = 0;

  Map<String, bool>? _permissionsCache;

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

    OneSignalService.instance.setScreenTrigger('dashboard');

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
    _countdownTimer?.cancel();
    _secondsRemainingNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pullUsageAndRefresh();
      _startUsageTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _usageTimer?.cancel();
      _usageTimer = null;
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  Future<void> _checkPermissions() async {
    final status = await _blockerService.checkPermissionsStatus();
    if (status['activityRecognition'] == true) {
      await _healthService.initPedometerListener();
    }
    if (mounted) {
      setState(() {
        _permissionsCache = status;
      });
    }
  }

  /// 1 Hz countdown timer ticking down the live seconds displayed in the hero card.
  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_secondsRemainingNotifier.value <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      final current = _secondsRemainingNotifier.value;
      if (current > 0) {
        final next = current - 1;
        _secondsRemainingNotifier.value = next;
        _localRemainingSeconds = next;
      } else {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        // Hit zero locally — trigger authoritative refresh to enforce blocking
        _pullUsageAndRefresh();
      }
    });
  }

  Future<void> _pullUsageAndRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      // 0. Ensure day reset occurs before fetching/updating today's steps
      await _timeBank.resetDailyIfNeeded();

      final steps = await _healthService.fetchTodaySteps();
      await _timeBank.updateSteps(steps);

      await _blockerService.evaluateBlockState();

      final newRemaining = _timeBank.remainingScreenTimeSeconds;
      _secondsRemainingNotifier.value = newRemaining;
      if (mounted && _localRemainingSeconds != newRemaining) {
        setState(() {
          _localRemainingSeconds = newRemaining;
        });
      }

      if (newRemaining > 0) {
        _startCountdown();
      } else {
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _startUsageTimer() {
    _usageTimer?.cancel();
    // 30-second interval prevents UI thread contention while maintaining accurate step syncing
    _usageTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      await _pullUsageAndRefresh();
    });
  }

  Future<void> _refresh() async {
    await _timeBank.resetDailyIfNeeded();
    await _pullUsageAndRefresh();
    await _checkPermissions();
  }

  void _openAppSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppSelectorSheet(
        selectedPackageNames: _timeBank.blockedPackageNames.toSet(),
        onAppsSelected: (packageNames, displayNames) async {
          await _timeBank.setBlockedApps(packageNames, displayNames);
          await _refresh();
          if (mounted) {
            final count = packageNames.length;
            setState(() {
              _statusMessage = count == 0
                  ? 'No apps selected.'
                  : '$count app${count == 1 ? '' : 's'} set for blocking.';
            });
          }
        },
      ),
    );
  }



  Future<void> _showEmergencySnooze() async {
    final companion = CompanionService.instance;
    final isPremium = RevenueCatService.instance.isPremium;
    final maxPasses = _timeBank.maxAllowedEmergencyPasses;
    final usedToday = _timeBank.emergencyPassCountToday;

    if (!_timeBank.canUseEmergencyPass) {
      final msg = companion.getEmergencyLimitReachedDialogue(isPremium: isPremium);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PippyAvatarWidget(
              size: 64,
              mood: PippyMood.celebrate,
              aura: companion.aura,
              accessory: companion.accessory,
              streakDays: companion.currentStreak,
            ),
            const SizedBox(height: 12),
            Text(
              "${companion.name}'s Quick 3-Min Boost ✨",
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                fontFamily: 'Outfit',
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '⚡ Boost ${usedToday + 1} of $maxPasses Available Today',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              companion.getEmergencyBoostDialogue(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Maybe later', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _handleWatchAdForPass(isPremium);
            },
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: const Text('Watch & Unlock ✨', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _grantEmergencyPass() async {
    final success = await _timeBank.consumeEmergencyPass();
    await _blockerService.evaluateBlockState();
    if (mounted) {
      await _pullUsageAndRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '+3 minutes emergency screen time granted!'
                : 'Could not activate pass. Daily limit reached.',
          ),
          backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _handleWatchAdForPass(bool isPremium) {
    AdMobService.instance.showEmergencyPassAd(
      isPremium: isPremium,
      onRewardEarned: () async {
        await _grantEmergencyPass();
      },
      onAdUnavailable: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Ad is loading or unavailable. Please check your connection and try again in a few seconds.',
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final remaining = _timeBank.remainingScreenTime;
    final totalSteps = _timeBank.totalStepsWalked;
    final earned = _timeBank.earnedMinutes;
    final used = _timeBank.usedMinutes;
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFF59E0B), size: 15),
                    const SizedBox(width: 3),
                    Text(
                      '$streak',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: RevenueCatService.instance.isPremiumNotifier,
            builder: (context, isPremium, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GlassIconButton(
                  icon: isPremium ? Icons.star_rounded : Icons.workspace_premium_rounded,
                  iconColor: isPremium ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PaywallScreen(source: 'appbar')),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),

      body: AmbientAuroraBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Streamlined Glanceable Header (Date + Live Status) ─────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _headlineColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _headlineColor.withValues(alpha: 0.22)),
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
                          size: 14,
                          color: _headlineColor,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '${DateFormat('EEE, MMM d').format(DateTime.now())} • $_headlineText',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
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
                const SizedBox(height: 14),

                // Active Permission Health Recovery Banner
                PermissionRecoveryBanner(onFixed: _checkPermissions),
                const SizedBox(height: 12),

                // Emergency Pass Active Banner (if currently running)
                if (hasEmergencyPass && emergencyExpiry != null) ...[
                  EmergencyPassBanner(
                    expiry: emergencyExpiry,
                    onExpired: () async {
                      await _refresh();
                      await BlockerService.instance.evaluateBlockState();
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Hero: Screen-Time Ring (Primary Focus)
                TimeHeroCard(
                  remaining: remaining,
                  remainingSeconds: _localRemainingSeconds,
                  remainingSecondsListenable: _secondsRemainingNotifier,
                  earned: earned,
                  used: used,
                  steps: totalSteps,
                ),
                const SizedBox(height: 16),

                // Pippy Cosy Companion Spotlight Card
                _buildCompanionSpotlightCard(context, totalSteps, remaining),
                const SizedBox(height: 16),

                // Blocked Apps Hub
                BlockedAppsCard(
                  apps: blockedApps,
                  timeBank: _timeBank,
                  onManage: _openAppSelector,
                ),
                const SizedBox(height: 16),

                // Emergency 3-Min Pass
                if (_timeBank.canUseEmergencyPass) ...[
                  EmergencySnoozeCard(
                    isAvailable: true,
                    onTap: _showEmergencySnooze,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompanionSpotlightCard(
    BuildContext context,
    int steps,
    int remainingMinutes,
  ) {
    final companion = CompanionService.instance;

    return AnimatedBuilder(
      animation: companion,
      builder: (context, _) {
        final mood = remainingMinutes <= 0
            ? PippyMood.sleepy
            : steps > 3000
                ? PippyMood.celebrate
                : PippyMood.idle;

        Color auraTint;
        switch (companion.aura) {
          case CompanionAura.mint:
            auraTint = const Color(0xFFB8F2D8);
            break;
          case CompanionAura.lavender:
            auraTint = const Color(0xFFD9CFFF);
            break;
          case CompanionAura.peach:
            auraTint = const Color(0xFFFFE0C2);
            break;
          case CompanionAura.rose:
            auraTint = const Color(0xFFFFD0D0);
            break;
          case CompanionAura.sky:
            auraTint = const Color(0xFFBFE5FF);
            break;
        }

        final dialogue = companion.getContextualDialogue(
          stepsToday: steps,
          remainingSeconds: _localRemainingSeconds,
          permissionsHealthy: _permissionsCache == null ||
              (_permissionsCache!['accessibility'] == true &&
                  ((_permissionsCache!['usage_stats'] == true) ||
                   (_permissionsCache!['usageStats'] == true))),
        );

        return PuffyGlassContainer(
          tintColor: auraTint,
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PippyAvatarWidget(
                size: 78,
                mood: mood,
                aura: companion.aura,
                accessory: companion.accessory,
                streakDays: companion.currentStreak,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => _showRenameCompanionDialog(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Text(
                                  companion.name,
                                  style: const TextStyle(
                                    color: Color(0xFF1A202C),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: companion.hasActiveStreakEffect
                                        ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: companion.hasActiveStreakEffect
                                        ? Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))
                                        : null,
                                  ),
                                  child: Text(
                                    companion.hasActiveStreakEffect
                                        ? '${companion.streakTier.levelLabel} ${companion.streakTier.title.split(' ')[0]}'
                                        : 'Lvl 1 🌱',
                                    style: TextStyle(
                                      color: companion.hasActiveStreakEffect
                                          ? const Color(0xFFD97706)
                                          : companion.aura.deepColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PetScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                            ),
                            child: const Row(
                              children: [
                                Text('🎨 ', style: TextStyle(fontSize: 11)),
                                Text(
                                  'Wardrobe',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A202C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: auraTint.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: auraTint),
                      ),
                      child: Text(
                        dialogue,
                        style: const TextStyle(
                          color: Color(0xFF2D3748),
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameCompanionDialog(BuildContext context) async {
    final companion = CompanionService.instance;
    final controller = TextEditingController(text: companion.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_rounded, color: Color(0xFF10B981), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Rename Companion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give your walking companion a custom name:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Fravo, Pippy, Sparky',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: const Icon(Icons.pets_rounded, color: Color(0xFF10B981)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await companion.setName(newName);
    }
  }
}

import 'package:flutter/material.dart';
import '../services/admob_service.dart';
import '../services/blocker_service.dart';
import '../services/companion_service.dart';
import '../services/growth_service.dart';
import '../services/health_service.dart';
import '../services/onesignal_service.dart';
import '../services/revenuecat_service.dart';
import '../services/time_bank.dart';
import '../widgets/ambient_aurora_background.dart';
import '../widgets/permission_status_tile.dart';
import '../widgets/pippy_avatar_widget.dart';
import '../widgets/premium_glass_system.dart';
import '../widgets/referral_reward_card.dart';
import 'paywall_screen.dart';

/// App version — production release.
const String kFravoAppVersion = '1.0.2';

enum PermissionKind {
  activity,
  accessibility,
  overlay,
  notification,
}

/// Decluttered, premium settings screen.
class SettingsScreen extends StatefulWidget {
  final TimeBankService timeBank;
  final BlockerService blockerService;
  final HealthService healthService;
  final VoidCallback onManageApps;

  const SettingsScreen({
    super.key,
    required this.timeBank,
    required this.blockerService,
    required this.healthService,
    required this.onManageApps,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _minutesPer1k = widget.timeBank.minutesPer1kSteps;
  late int _stepGoal = widget.timeBank.customStepGoal;

  Map<String, bool> _permissions = {};
  bool _permissionsLoaded = false;

  static const _goalOptions = [5000, 6000, 8000, 10000, 12000, 15000];

  @override
  void initState() {
    super.initState();
    OneSignalService.instance.setScreenTrigger('settings');
    _reloadPermissions();
  }

  Future<void> _reloadPermissions() async {
    final status = await widget.blockerService.checkPermissionsStatus();
    if (mounted) {
      setState(() {
        _permissions = status;
        _permissionsLoaded = true;
      });
    }
  }

  Future<void> _saveRewardRate() async {
    // If rate has not changed compared to saved value in timeBank, do nothing
    if (_minutesPer1k == widget.timeBank.minutesPer1kSteps) {
      return;
    }

    // AdMob Policy: Rewarded ads must be opt-in with explicit disclosure of reward
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 8),
            Text(
              'Update Reward Rate',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change your step-to-time ratio to $_minutesPer1k minutes per 1,000 steps?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: Color(0xFF047857),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Watch a short video ad to apply and save this new rate.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
            label: const Text('Watch & Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      if (mounted) {
        setState(() {
          _minutesPer1k = widget.timeBank.minutesPer1kSteps;
        });
      }
      return;
    }

    bool rewardEarned = false;
    AdMobService.instance.showRewardRateChangeRewardedAd(
      onRewardEarned: () async {
        rewardEarned = true;
        await widget.timeBank.setMinutesPer1kSteps(_minutesPer1k);
        await widget.blockerService.evaluateBlockState();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reward rate updated to $_minutesPer1k min / 1k steps!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      onAdDismissed: () {
        if (!rewardEarned && mounted) {
          setState(() {
            _minutesPer1k = widget.timeBank.minutesPer1kSteps;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ad was closed early. Reward rate was not updated.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      onAdFailed: () {
        if (mounted) {
          setState(() {
            _minutesPer1k = widget.timeBank.minutesPer1kSteps;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Ad is loading or unavailable. Please check your connection and try again.'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
    );
  }

  Future<void> _pickStepGoal() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(
          'Daily Step Goal',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        children: _goalOptions
            .map(
              (g) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, g),
                child: Row(
                  children: [
                    Icon(
                      g == _stepGoal
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 20,
                      color: g == _stepGoal
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      g >= 1000
                          ? '${(g / 1000).toStringAsFixed(0)},000 steps / day'
                          : '$g steps / day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: g == _stepGoal ? FontWeight.bold : FontWeight.w500,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null) return;
    setState(() => _stepGoal = picked);
    await widget.timeBank.setCustomStepGoal(picked);
  }

  void _showProRateLockDialog() {
    final companion = CompanionService.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PippyAvatarWidget(
              size: 60,
              mood: PippyMood.celebrate,
              aura: companion.aura,
              accessory: companion.accessory,
              streakDays: companion.currentStreak,
            ),
            const SizedBox(height: 12),
            const Text(
              'Custom Strict Rates with Pro 🎯',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
                fontFamily: 'Outfit',
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              companion.getStrictRateLockDialogue(),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaywallScreen(source: 'rate_lock'),
                ),
              );
            },
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Unlock Pro ⭐', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPermission(PermissionKind kind) async {
    switch (kind) {
      case PermissionKind.activity:
        await widget.healthService.requestPermissions();
        break;
      case PermissionKind.accessibility:
        if (_permissions['accessibility'] != true) {
          await _showAccessibilityGuideDialog();
        } else {
          await widget.blockerService.requestAccessibilityPermission();
        }
        break;
      case PermissionKind.overlay:
        await widget.blockerService.requestOverlayPermission();
        break;
      case PermissionKind.notification:
        await widget.blockerService.requestAllPermissions(context);
        break;
    }
    await _reloadPermissions();
  }

  Future<void> _showAccessibilityGuideDialog() async {
    final companion = CompanionService.instance;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PippyAvatarWidget(
              size: 64,
              mood: PippyMood.alert,
              aura: companion.aura,
              accessory: companion.accessory,
              streakDays: companion.currentStreak,
            ),
            const SizedBox(height: 12),
            const Text(
              'Enable Fravo Blocker Engine',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. In Settings, tap "Downloaded apps" / "Installed services"',
                    style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '2. Select ',
                        style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                      ),
                      Text(
                        'Fravo App Blocker Engine',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '3. Toggle switch ON & tap Allow',
                    style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.blockerService.requestAccessibilityPermission();
            },
            child: const Text('Open Settings ⚙️'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AmbientAuroraBackground(
        primaryGlow: const Color(0xFF3B82F6),
        secondaryGlow: const Color(0xFF10B981),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              // 1. Membership & Referral
              _buildSectionLabel('PRO MEMBERSHIP', Icons.stars_rounded, const Color(0xFF3B82F6)),
              const SizedBox(height: 8),
              _buildPremiumCard(),
              const SizedBox(height: 14),

              _buildSectionLabel('INVITE FRIENDS & EARN PRO', Icons.card_giftcard_rounded, const Color(0xFF10B981)),
              const SizedBox(height: 8),
              _buildReferralGrowthCard(),
              const SizedBox(height: 20),

              // 2. Walking & Focus Budget
              _buildSectionLabel('FOCUS & WALKING CONTROLS', Icons.tune_rounded, const Color(0xFF10B981)),
              const SizedBox(height: 8),
              _buildFocusControlsCard(),
              const SizedBox(height: 20),

              // 3. System & Permissions
              _buildSectionLabel('SYSTEM PERMISSIONS', Icons.security_rounded, const Color(0xFF6366F1)),
              const SizedBox(height: 8),
              _buildPermissionsCard(),
              const SizedBox(height: 20),

              // 4. Support & Privacy
              _buildSectionLabel('SUPPORT & LEGAL', Icons.info_outline_rounded, const Color(0xFF64748B)),
              const SizedBox(height: 8),
              _buildSupportCard(),
              const SizedBox(height: 20),

              // Footer Version
              Center(
                child: Text(
                  'Fravo v$kFravoAppVersion • Mindful Screen Time Economy',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Premium Subscription Card ──────────────────────────────────────────────

  Widget _buildPremiumCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: RevenueCatService.instance.isPremiumNotifier,
      builder: (context, isPremium, _) {
        return PuffyGlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          tintColor: isPremium ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
          tintAlpha: 0.95,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isPremium ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPremium ? 'Fravo Pro Active 🏆' : 'Fravo Pro',
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPremium
                              ? 'All premium features unlocked.'
                              : 'Unlimited apps, custom auras & strict rates.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPremium ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaywallScreen(source: 'settings'),
                      ),
                    );
                  },
                  child: Text(
                    isPremium ? 'Manage Subscription' : 'View Plans (7 Days Free)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Viral Referral Growth Card ──────────────────────────────────────────

  Widget _buildReferralGrowthCard() {
    return const ReferralRewardCard(
      tintColor: Color(0xFFE8FDF3),
    );
  }

  // ── Unified Focus & Step Controls Card ─────────────────────────────────────

  Widget _buildFocusControlsCard() {
    final apps = widget.timeBank.blockedPackageNames;
    final isPremium = RevenueCatService.instance.isPremium;

    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      tintColor: const Color(0xFFF0FDF4),
      tintAlpha: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mins per 1k steps
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Step-to-Time Ratio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_minutesPer1k min / 1k steps',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: _minutesPer1k.toDouble().clamp(5, 60),
            min: 5,
            max: 60,
            divisions: 11,
            activeColor: const Color(0xFF10B981),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (val) {
              final snapped = (val / 5).round() * 5;
              if (!isPremium && snapped < 25) {
                setState(() => _minutesPer1k = 25);
                _showProRateLockDialog();
                return;
              }
              setState(() => _minutesPer1k = snapped.clamp(5, 60));
            },
            onChangeEnd: (_) => _saveRewardRate(),
          ),
          Center(
            child: Text(
              isPremium
                  ? '1,000 steps walked = $_minutesPer1k minutes earned'
                  : 'Free tier: 25–60 min / 1k steps (Pro: unlock strict 5–20 min)',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
          const Divider(height: 24),

          // Daily Step Goal
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _pickStepGoal,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.flag_rounded, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Daily Goal: ${_stepGoal >= 1000 ? "${(_stepGoal / 1000).toStringAsFixed(0)},000 steps" : "$_stepGoal steps"}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Blocked Apps Shortcut
          Material(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onManageApps,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.apps_rounded, size: 18, color: Color(0xFF3B82F6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Blocked Distraction Apps (${apps.length} locked)',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Permissions Card ───────────────────────────────────────────────────────

  Widget _buildPermissionsCard() {
    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      tintColor: const Color(0xFFF1F5F9),
      tintAlpha: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_permissionsLoaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else ...[
            PermissionStatusTile(
              label: 'Physical Step Tracking',
              isGranted: _permissions['activityRecognition'] ?? false,
              onTap: () => _requestPermission(PermissionKind.activity),
            ),
            const SizedBox(height: 8),
            PermissionStatusTile(
              label: 'Fravo Blocker Engine',
              isGranted: _permissions['accessibility'] ?? false,
              onTap: () => _requestPermission(PermissionKind.accessibility),
            ),
            const SizedBox(height: 8),
            PermissionStatusTile(
              label: 'Display Over Other Apps',
              isGranted: _permissions['overlay'] ?? false,
              onTap: () => _requestPermission(PermissionKind.overlay),
            ),
            const SizedBox(height: 8),
            PermissionStatusTile(
              label: 'Usage Stats & Notifications',
              isGranted: _permissions['notification'] ?? false,
              onTap: () => _requestPermission(PermissionKind.notification),
            ),
          ],
        ],
      ),
    );
  }

  // ── Support & Legal Card ───────────────────────────────────────────────────

  Widget _buildSupportCard() {
    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      tintColor: const Color(0xFFFAF5FF),
      tintAlpha: 0.9,
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
            title: const Text('Rate Fravo on Google Play', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF94A3B8)),
            onTap: () => GrowthService.instance.openPlayStoreReview(),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.shield_outlined, color: Color(0xFF10B981)),
            title: const Text('Privacy Policy & Safe Storage', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Privacy & Security', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text(
                    'Fravo stores all your step counts and app blocking preferences locally on your device. No personal browsing or screen data is ever sold or shared.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF4B5563)),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

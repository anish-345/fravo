import 'package:flutter/material.dart';
import '../services/blocker_service.dart';
import '../services/growth_service.dart';
import '../services/health_service.dart';
import '../services/onesignal_service.dart';
import '../services/revenuecat_service.dart';
import '../services/time_bank.dart';
import '../widgets/permission_status_tile.dart';
import '../widgets/premium_glass_system.dart';
import 'paywall_screen.dart';

/// App version — production release.
const String kFravoAppVersion = '1.0.0';

/// Full settings screen reached from the home gear icon.
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
    await widget.timeBank.setMinutesPer1kSteps(_minutesPer1k);
    await widget.blockerService.evaluateBlockState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Reward rate updated!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
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

  Future<void> _requestPermission(PermissionKind kind) async {
    switch (kind) {
      case PermissionKind.activity:
        await widget.healthService.requestActivityRecognitionPermission();
      case PermissionKind.accessibility:
        await widget.blockerService.requestAccessibilityPermission();
      case PermissionKind.overlay:
        await widget.blockerService.requestOverlayPermission();
      case PermissionKind.notification:
        await widget.blockerService.requestAllPermissions(context);
    }
    await _reloadPermissions();
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // 1. Membership & Referral
            _buildSectionLabel('MEMBERSHIP & GROWTH', Icons.stars_rounded, const Color(0xFF3B82F6)),
            const SizedBox(height: 8),
            _buildPremiumCard(),
            const SizedBox(height: 12),
            _buildReferralGrowthCard(),
            const SizedBox(height: 24),

            // 2. Walking & Focus Budget
            _buildSectionLabel('WALKING & FOCUS BUDGET', Icons.directions_walk_rounded, const Color(0xFF10B981)),
            const SizedBox(height: 8),
            _buildRewardsCard(),
            const SizedBox(height: 12),
            _buildBlockedAppsCard(),
            const SizedBox(height: 24),

            // 3. System & Permissions
            _buildSectionLabel('SYSTEM & PERMISSIONS', Icons.security_rounded, const Color(0xFF6366F1)),
            const SizedBox(height: 8),
            _buildPermissionsCard(),
            const SizedBox(height: 24),

            // 4. Support & Privacy
            _buildSectionLabel('SUPPORT & LEGAL', Icons.info_outline_rounded, const Color(0xFF64748B)),
            const SizedBox(height: 8),
            _buildRateAppCard(),
            const SizedBox(height: 12),
            _buildPrivacyCard(),
            const SizedBox(height: 24),

            // Footer Version
            Center(
              child: Text(
                'Fravo v$kFravoAppVersion • Made for mindful focus',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
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
          padding: const EdgeInsets.all(18),
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
                          isPremium ? 'Fravo Pro Active 🏆' : 'Upgrade to Fravo Pro',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPremium
                              ? 'Unlimited apps, custom reward rates & zero video ads unlocked.'
                              : 'Block unlimited distraction apps and earn guilt-free screen time.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPremium ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    isPremium ? 'View Commitment Plan' : 'View Commitment Plans (7 Days Free)',
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
    final code = GrowthService.instance.referralCode;

    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      tintColor: const Color(0xFFF0FDF4),
      tintAlpha: 0.95,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Give 7 Days, Get 7 Days Pro',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Share your invite code for 7 days free Fravo Pro.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR INVITE CODE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () => GrowthService.instance.showReferralSheet(context),
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Rewards settings ───────────────────────────────────────────────────────

  Widget _buildRewardsCard() {
    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      tintColor: Colors.white,
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
          const SizedBox(height: 8),
          Slider(
            value: _minutesPer1k.toDouble().clamp(5, 60),
            min: 5,
            max: 60,
            divisions: 11,
            activeColor: const Color(0xFF10B981),
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (val) {
              final isPremium = RevenueCatService.instance.isPremium;
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
              RevenueCatService.instance.isPremium
                  ? '1,000 steps walked = $_minutesPer1k minutes earned (All rates unlocked)'
                  : '1,000 steps = $_minutesPer1k min • Free tier: 25–60 min (Pro: unlock strict 5–20 min)',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const Divider(height: 24),
          // Daily step goal
          Material(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickStepGoal,
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
        ],
      ),
    );
  }

  // ── Blocked apps quick link ────────────────────────────────────────────────

  Widget _buildBlockedAppsCard() {
    final apps = widget.timeBank.blockedPackageNames;
    final summary = apps.isEmpty
        ? 'No apps selected'
        : apps.take(3).map((p) => widget.timeBank.displayNameFor(p)).join(', ');

    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      tintColor: Colors.white,
      tintAlpha: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Blocked Distraction Apps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${apps.length} locked',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            apps.isEmpty
                ? 'Nothing locked yet. Pick apps to earn screen time with steps.'
                : summary + (apps.length > 3 ? ' +${apps.length - 3} more' : ''),
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.onManageApps,
              icon: const Icon(Icons.apps_rounded, size: 16, color: Color(0xFF3B82F6)),
              label: const Text(
                'Manage Blocked Apps',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Required Android permissions ───────────────────────────────────────────

  Widget _buildPermissionsCard() {
    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      tintColor: Colors.white,
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
              label: 'Step Tracking & Activity',
              isGranted: _permissions['activityRecognition'] ?? false,
              onTap: () => _requestPermission(PermissionKind.activity),
            ),
            const SizedBox(height: 8),
            PermissionStatusTile(
              label: 'App Blocker Accessibility',
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
              label: 'Notifications & Usage Access',
              isGranted: _permissions['notification'] ?? false,
              onTap: () => _requestPermission(PermissionKind.notification),
            ),
          ],
        ],
      ),
    );
  }

  // ── Rate on Google Play Card ─────────────────────────────────────────────

  Widget _buildRateAppCard() {
    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      tintColor: Colors.white,
      tintAlpha: 0.9,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFF3B82F6), size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rate Fravo on Google Play',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Enjoying the app? Leave a review!',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF3B82F6), size: 20),
            onPressed: () => GrowthService.instance.openPlayStoreReview(),
          ),
        ],
      ),
    );
  }

  // ── Privacy policy ─────────────────────────────────────────────────────────

  Widget _buildPrivacyCard() {
    return PuffyGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      tintColor: Colors.white,
      tintAlpha: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Privacy & Data Protection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your step counts and app blocking preferences are processed and stored strictly on your device. We never sell your personal data.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  void _showProRateLockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 8),
            Text('Strict Focus Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Hardcore reward rates below 25 minutes per 1,000 steps (5–20 min / 1k steps) require Fravo Pro.\n\nUpgrade to Pro to lock in strict digital detox rates, unlimited app blocking, and ad-free emergency passes!',
          style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen(source: 'strict_rate_limit')),
              );
            },
            child: const Text('Unlock Pro (7 Days Free)'),
          ),
        ],
      ),
    );
  }
}

enum PermissionKind { activity, accessibility, overlay, notification }

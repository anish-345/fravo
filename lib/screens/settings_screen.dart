import 'package:flutter/material.dart';

import '../services/blocker_service.dart';
import '../services/health_service.dart';
import '../services/time_bank.dart';
import '../widgets/permission_status_tile.dart';
import '../widgets/premium_glass_system.dart';

/// App version — kept in sync with `pubspec.yaml` (1.0.0+4). Hardcoded to
/// avoid pulling in `package_info_plus`.
const String kFravoAppVersion = '1.0.0+4';

/// Full settings screen reached from the home gear icon.
///
/// Sections: About (version), Rewards (mins-per-1k rate + daily step goal),
/// Blocked apps management, Privacy policy, and the required Android
/// permissions status. Replaces the old `_showSettingsDialog` dialog.
class SettingsScreen extends StatefulWidget {
  final TimeBankService timeBank;
  final BlockerService blockerService;
  final HealthService healthService;

  /// Called when the user taps "Manage apps" — the dashboard pops this screen
  /// and opens the app selector so the user lands back on the home dashboard.
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
        content: const Text('Reward rate updated'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickStepGoal() async {
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Daily step goal'),
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
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      g >= 1000
                          ? '${(g / 1000).toStringAsFixed(0)}k steps'
                          : '$g steps',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A202C),
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
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildAboutCard(),
            const SizedBox(height: 16),
            _buildRewardsCard(),
            const SizedBox(height: 16),
            _buildBlockedAppsCard(),
            const SizedBox(height: 16),
            _buildPrivacyCard(),
            const SizedBox(height: 16),
            _buildPermissionsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── About / version ────────────────────────────────────────────────────────

  Widget _buildAboutCard() {
    return UltraGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A90E2), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_walk_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fravo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version $kFravoAppVersion',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
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
    return UltraGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.redeem_rounded,
            color: Color(0xFFF59E0B),
            title: 'REWARDS',
          ),
          const SizedBox(height: 16),
          // ── Mins per 1k steps ──
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mins per 1,000 Steps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D3748),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_minutesPer1k min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _minutesPer1k.toDouble(),
            min: 5,
            max: 60,
            divisions: 11, // 5, 10, 15, … 60
            activeColor: const Color(0xFF2D3748),
            label: '$_minutesPer1k mins / 1k steps',
            onChanged: (val) {
              final snapped = (val / 5).round() * 5;
              setState(() => _minutesPer1k = snapped.clamp(5, 60));
            },
            onChangeEnd: (_) => _saveRewardRate(),
          ),
          Text(
            '1,000 steps = $_minutesPer1k min of screen time',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
            textAlign: TextAlign.center,
          ),
          const Divider(height: 28),
          // ── Daily step goal ──
          Material(
            color: const Color(0xFF1F2937).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _pickStepGoal,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 20,
                      color: Color(0xFF4A90E2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily step goal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _stepGoal >= 1000
                                ? '${(_stepGoal / 1000).toStringAsFixed(0)}k steps'
                                : '$_stepGoal steps',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Color(0xFF4A90E2),
                    ),
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

    return UltraGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.block_rounded,
            color: Color(0xFFEF4444),
            title: 'BLOCKED APPS',
          ),
          const SizedBox(height: 12),
          Text(
            apps.isEmpty
                ? 'Nothing blocked yet. Pick apps to lock behind your step budget.'
                : summary +
                      (apps.length > 3 ? ' +${apps.length - 3} more' : ''),
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onManageApps,
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: Color(0xFF4A90E2),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Manage Apps',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Privacy policy ─────────────────────────────────────────────────────────

  Widget _buildPrivacyCard() {
    return UltraGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.privacy_tip_rounded,
            color: Color(0xFF10B981),
            title: 'PRIVACY POLICY',
          ),
          const SizedBox(height: 12),
          const Text(
            'Fravo is privacy-first. All your data — steps, screen time, blocked apps and settings — is stored only on this device. Nothing leaves your phone.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),
          _privacyBullet(
            'It is used to measure your steps and enforce your screen-time budget.',
          ),
          const SizedBox(height: 6),
          _privacyBullet(
            'The accessibility, display-over-apps, usage-access and notification permissions are used solely for blocking restricted apps — never for data collection.',
          ),
          const SizedBox(height: 6),
          _privacyBullet(
            'No account, no analytics, no ads, no tracking. Clearing the app data deletes everything.',
          ),
        ],
      ),
    );
  }

  Widget _privacyBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
      ],
    );
  }

  // ── Required Android permissions ───────────────────────────────────────────

  Widget _buildPermissionsCard() {
    return UltraGlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.security_rounded,
            color: Color(0xFF4A90E2),
            title: 'REQUIRED PERMISSIONS',
          ),
          const SizedBox(height: 12),
          if (!_permissionsLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else ...[
            PermissionStatusTile(
              label: 'Physical Activity / Step Tracking',
              isGranted: _permissions['activityRecognition'] ?? false,
              onTap: () => _requestPermission(PermissionKind.activity),
            ),
            const SizedBox(height: 8),
            PermissionStatusTile(
              label: 'Accessibility Service (Required)',
              isGranted: _permissions['accessibility'] ?? false,
              onTap: () => _requestPermission(PermissionKind.accessibility),
            ),
            const SizedBox(height: 8),
            PermissionStatusTile(
              label: 'Display Over Apps',
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
}

enum PermissionKind { activity, accessibility, overlay, notification }

/// Small section label used on top of settings cards.
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}

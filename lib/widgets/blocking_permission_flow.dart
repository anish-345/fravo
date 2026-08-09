import 'dart:async';

import 'package:flutter/material.dart';

import '../services/blocker_service.dart';
import '../services/health_service.dart';
import 'premium_glass_system.dart';

/// Progressive permission gate shown when setup or app blocking permissions
/// are requested.
///
/// • Asks for required permissions (Physical Activity, Accessibility, Overlay, Usage Stats)
///   one at a time, each with a micro-explanation.
/// • Every request is skippable: the flow never hard-blocks the user.
class BlockingPermissionsSheet extends StatefulWidget {
  /// Optional callback invoked after the user grants (or skips) a permission.
  final VoidCallback? onChanged;

  const BlockingPermissionsSheet({super.key, this.onChanged});

  @override
  State<BlockingPermissionsSheet> createState() =>
      _BlockingPermissionsSheetState();
}

class _BlockingPermissionsSheetState extends State<BlockingPermissionsSheet>
    with WidgetsBindingObserver {
  final _blocker = BlockerService.instance;

  Map<String, bool> _permissions = {
    'usageStats': false,
    'accessibility': false,
    'overlay': false,
    'notification': false,
    'activityRecognition': false,
    'healthConnect': false,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Users return from Android Settings after granting — refresh immediately.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    final status = await _blocker.checkPermissionsStatus();
    if (!mounted) return;
    setState(() {
      _permissions = status;
      _loading = false;
    });
    widget.onChanged?.call();
  }

  Future<void> _grant(Future<void> Function() request) async {
    await request();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final missing = !(_permissions['activityRecognition'] ?? false) ||
        !(_permissions['accessibility'] ?? false) ||
        !(_permissions['overlay'] ?? false) ||
        !(_permissions['usageStats'] ?? false);

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF8B5CF6),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable app blocking & tracking',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'A few quick permissions, one at a time',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
                        _PermissionFlowTile(
                          icon: Icons.directions_walk_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Physical Activity / Step Tracking',
                          microExplanation:
                              'Measures your steps so you earn screen time for your chosen apps.',
                          granted: _permissions['activityRecognition'] ?? false,
                          onGrant: () => _grant(
                            _requestActivityRecognition,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PermissionFlowTile(
                          icon: Icons.accessibility_new_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Accessibility Service',
                          microExplanation:
                              'This lets us pause selected apps when your time runs out.',
                          granted: _permissions['accessibility'] ?? false,
                          onGrant: () => _grant(
                            _blocker.requestAccessibilityPermission,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PermissionFlowTile(
                          icon: Icons.layers_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Display Over Other Apps',
                          microExplanation:
                              'Shows the lock overlay over caught apps when your budget ends.',
                          granted: _permissions['overlay'] ?? false,
                          onGrant: () => _grant(
                            _blocker.requestOverlayPermission,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PermissionFlowTile(
                          icon: Icons.analytics_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'Usage Stats Access',
                          microExplanation:
                              'Counts time spent in each app so we deduct it '
                              'from your earned screen time.',
                          granted: _permissions['usageStats'] ?? false,
                          onGrant: () => _grant(
                            _blocker.requestUsageStatsPermission,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PermissionFlowTile(
                          icon: Icons.notifications_active_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: 'Notifications',
                          microExplanation:
                              'Shows your live remaining minutes at a glance.',
                          granted: _permissions['notification'] ?? false,
                          onGrant: () => _grant(
                            _requestNotification,
                          ),
                          optional: true,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1F2937),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      missing
                          ? 'Continue (I\'ll do these later)'
                          : 'Done — everything enabled!',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    missing
                        ? 'You can still pick apps now — we\'ll ask again when needed.'
                        : 'You\'re all set to start blocking. 🎉',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestNotification() async {
    await _blocker.requestNotificationPermission();
  }

  Future<void> _requestActivityRecognition() async {
    await HealthService.instance.requestActivityRecognitionPermission();
  }
}

class _PermissionFlowTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String microExplanation;
  final bool granted;
  final Future<void> Function() onGrant;
  final bool optional;

  const _PermissionFlowTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.microExplanation,
    required this.granted,
    required this.onGrant,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return UltraGlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.all(16),
      showIridescence: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (optional) ...[
                      const SizedBox(height: 1),
                      const Text(
                        'Optional',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (granted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF059669),
                        size: 15,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Granted',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onGrant,
                  child: const Text(
                    'Grant',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            microExplanation,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
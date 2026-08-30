import 'package:flutter/material.dart';
import '../services/blocker_service.dart';
import '../services/companion_service.dart';
import '../services/onesignal_service.dart';
import 'pippy_avatar_widget.dart';
import 'premium_glass_system.dart';

/// Empathetic Puffy Glass Banner alerting users if any crucial Android permission is disabled.
class PermissionRecoveryBanner extends StatefulWidget {
  final VoidCallback? onFixed;

  const PermissionRecoveryBanner({super.key, this.onFixed});

  @override
  State<PermissionRecoveryBanner> createState() =>
      _PermissionRecoveryBannerState();
}

class _PermissionRecoveryBannerState extends State<PermissionRecoveryBanner>
    with WidgetsBindingObserver {
  final _blockerService = BlockerService.instance;
  final _companionService = CompanionService.instance;

  bool _isChecking = false;
  String? _missingPermissionKey;
  String? _missingPermissionLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    setState(() => _isChecking = true);

    try {
      final perms = await _blockerService.checkPermissionsStatus();
      final isAccessibilityOk = perms['accessibility'] == true;
      final isUsageOk = (perms['usage_stats'] == true) || (perms['usageStats'] == true);
      final isOverlayOk = perms['overlay'] == true;
      final isBatteryOk = perms['battery_optimization'] ?? true;

      String? missingKey;
      String? missingLabel;

      if (!isAccessibilityOk) {
        missingKey = 'accessibility';
        missingLabel = 'Accessibility Service';
      } else if (!isUsageOk) {
        missingKey = 'usage_stats';
        missingLabel = 'Usage Access';
      } else if (!isOverlayOk) {
        missingKey = 'overlay';
        missingLabel = 'Display Over Other Apps';
      } else if (!isBatteryOk) {
        missingKey = 'battery';
        missingLabel = 'Background Battery Exemption';
      }

      if (mounted) {
        setState(() {
          _missingPermissionKey = missingKey;
          _missingPermissionLabel = missingLabel;
          _isChecking = false;
        });
      }

      // Sync OneSignal In-App triggers
      if (missingKey != null) {
        OneSignalService.instance.setPermissionsTrigger(
          healthy: false,
          missingKey: missingKey,
        );
      } else {
        OneSignalService.instance.setPermissionsTrigger(
          healthy: true,
          missingKey: 'none',
        );
        widget.onFixed?.call();
      }
    } catch (_) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _fixPermission() async {
    if (_missingPermissionKey == null) return;

    switch (_missingPermissionKey) {
      case 'accessibility':
        await _blockerService.requestAccessibilityPermission();
        break;
      case 'usage_stats':
        await _blockerService.requestUsageStatsPermission();
        break;
      case 'overlay':
        await _blockerService.requestOverlayPermission();
        break;
      case 'battery':
        await _blockerService.requestUsageStatsPermission();
        break;
    }

    // Proactively re-check after returning
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _checkPermissions();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_missingPermissionKey == null || _isChecking) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: PuffyGlassContainer(
        tintColor: const Color(0xFFFFD0D0),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Alert Mascot Avatar
            PippyAvatarWidget(
              size: 64,
              mood: PippyMood.alert,
              aura: _companionService.aura,
              accessory: _companionService.accessory,
            ),

            const SizedBox(width: 14),

            // Message & 1-Tap Fix
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('⚠️ ', style: TextStyle(fontSize: 13)),
                      Text(
                        '$_missingPermissionLabel is Off',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_companionService.name} needs $_missingPermissionLabel to count your screen time and reward your walking minutes.',
                    style: const TextStyle(
                      color: Color(0xFF7F1D1D),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.touch_app_rounded, size: 16),
                    label: const Text(
                      'Fix in 10s ⚙️',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: _fixPermission,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

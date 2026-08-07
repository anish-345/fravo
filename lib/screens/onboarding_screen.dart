import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/blocker_service.dart';
import '../services/health_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboardingComplete;

  const OnboardingScreen({super.key, required this.onOnboardingComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  final _blockerService = BlockerService.instance;
  final _healthService = HealthService.instance;

  Map<String, bool> _permissions = {
    'usageStats': false,
    'accessibility': false,
    'overlay': false,
    'notification': false,
    'activityRecognition': false,
  };

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _refreshPermissions() async {
    final status = await _blockerService.checkPermissionsStatus();
    if (mounted) {
      setState(() {
        _permissions = status;
        _loading = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final box = Hive.box('time_bank');
    await box.put('completedOnboarding', true);
    widget.onOnboardingComplete();
  }

  @override
  Widget build(BuildContext context) {
    final allEssentialGranted = _permissions['usageStats'] == true &&
        _permissions['accessibility'] == true &&
        _permissions['overlay'] == true &&
        _permissions['activityRecognition'] == true;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Beautiful App Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_walk_rounded,
                              size: 54,
                              color: Color(0xFF4A90E2),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Welcome to Fravo',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1F2937),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'Walk to earn screen time. We convert your physical activity steps into allowed minutes for your chosen apps.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 32, thickness: 1, color: Color(0xFFE5E7EB)),
                          const Text(
                            'Setup Required Permissions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Fravo strictly runs entirely offline and locally on your device to protect your personal privacy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Permission Cards
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. Physical Activity / Steps
                        _PermissionCard(
                          icon: Icons.directions_walk_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Physical Activity Tracking',
                          desc: 'Reads your hardware step counters so that every step you take adds minutes to your screen-time budget.',
                          beautifulMessage: '🚶‍♂️ Walk to earn! We securely access step counters solely to reward your physical efforts with screen allowance. No location is tracked.',
                          isGranted: _permissions['activityRecognition'] == true,
                          onGrant: () async {
                            await _healthService.requestActivityRecognitionPermission();
                            _refreshPermissions();
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. Accessibility Service
                        _PermissionCard(
                          icon: Icons.accessibility_new_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          title: 'Accessibility Service',
                          desc: 'Instantly locks restricted apps when your daily screen time runs out.',
                          beautifulMessage: '🔒 Built for safety. We never capture passwords, credit cards, or screens. It is only used offline to detect app switches and apply overlays.',
                          isGranted: _permissions['accessibility'] == true,
                          onGrant: () async {
                            await _blockerService.requestAccessibilityPermission();
                            _refreshPermissions();
                          },
                        ),
                        const SizedBox(height: 16),

                        // 3. Usage Access
                        _PermissionCard(
                          icon: Icons.analytics_rounded,
                          iconColor: const Color(0xFF3B82F6),
                          title: 'Usage Stats Access',
                          desc: 'Measures how much time you spend inside restricted apps today.',
                          beautifulMessage: '📊 Smarter control. We measure app usage durations locally to correctly deduct from your earned screen time budget. No data is sent or shared.',
                          isGranted: _permissions['usageStats'] == true,
                          onGrant: () async {
                            await _blockerService.requestUsageStatsPermission();
                            _refreshPermissions();
                          },
                        ),
                        const SizedBox(height: 16),

                        // 4. Overlay Permission
                        _PermissionCard(
                          icon: Icons.layers_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Display Over Other Apps',
                          desc: 'Shows the block overlay screen when a blocked app is opened.',
                          beautifulMessage: '💡 Friendly Reminder. Required to draw the elegant "Out of Time" screen blocker to prevent access to limited apps.',
                          isGranted: _permissions['overlay'] == true,
                          onGrant: () async {
                            await _blockerService.requestOverlayPermission();
                            _refreshPermissions();
                          },
                        ),
                        const SizedBox(height: 16),

                        // 5. Notifications
                        _PermissionCard(
                          icon: Icons.notifications_active_rounded,
                          iconColor: const Color(0xFFEF4444),
                          title: 'Notifications',
                          desc: 'Displays the persistent active status and live countdown budget in your notification bar.',
                          beautifulMessage: '🔔 Always Updated. Shows you exactly how much remaining time you have left at a glance so you are never surprised.',
                          isGranted: _permissions['notification'] == true,
                          onGrant: () async {
                            await _blockerService.requestAllPermissions(context);
                            _refreshPermissions();
                          },
                        ),
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),

                  // Bottom Start Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!allEssentialGranted)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Text(
                                '⚠️ Please grant the essential permissions (Steps, Accessibility, Usage, Overlay) to unlock the application.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: allEssentialGranted ? const Color(0xFF1F2937) : const Color(0xFF9CA3AF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: allEssentialGranted ? _completeOnboarding : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Let\'s Walk & Earn!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String desc;
  final String beautifulMessage;
  final bool isGranted;
  final VoidCallback onGrant;

  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.desc,
    required this.beautifulMessage,
    required this.isGranted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2937).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Beautiful Message Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    beautifulMessage,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isGranted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Granted',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: onGrant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text(
                    'Grant Access',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Shows a beautiful bottom sheet guide to help users enable the accessibility service.
/// Explains where to find the service ("Fravo App Blocker Engine") and how to bypass
/// the Android 13+ "Restricted Setting" greyed-out issue.
void showAccessibilityHelpSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AccessibilityHelpSheet(),
  );
}

class AccessibilityHelpSheet extends StatelessWidget {
  const AccessibilityHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              // Title
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
                        Icons.accessibility_new_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accessibility Guide',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Need help finding or enabling the service?',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // TabBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: const Color(0xFF0F172A),
                    unselectedLabelColor: const Color(0xFF64748B),
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: '1. Finding Service'),
                      Tab(text: '2. Greyed Out?'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // TabBarView
              Expanded(
                child: TabBarView(
                  children: [
                    _buildFindingServiceTab(),
                    _buildRestrictedSettingsTab(),
                  ],
                ),
              ),
              // Bottom CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Got it, let\'s try!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFindingServiceTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const Text(
          'On customized Android systems (Samsung, Xiaomi/HyperOS, OnePlus, etc.), follow these steps to find the service:',
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF334155),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildStepCard(
          stepNumber: '1',
          title: 'Tap "Grant Permission"',
          description: 'This will automatically open your phone\'s Accessibility settings page.',
          icon: Icons.open_in_new_rounded,
        ),
        _buildStepCard(
          stepNumber: '2',
          title: 'Look for Installed Apps / Services',
          description: 'Scroll down and tap on "Installed Apps", "Downloaded Services", "Installed Services", or "More Services".',
          icon: Icons.folder_open_rounded,
        ),
        _buildStepCard(
          stepNumber: '3',
          title: 'Select "Fravo App Blocker Engine"',
          description: 'Identify the service named "Fravo App Blocker Engine" in the list and tap it.',
          icon: Icons.toggle_on_rounded,
          isHighlight: true,
        ),
        _buildStepCard(
          stepNumber: '4',
          title: 'Enable the Switch',
          description: 'Toggle the switch to ON and confirm any system warnings to complete the setup.',
          icon: Icons.check_circle_outline_rounded,
        ),
      ],
    );
  }

  Widget _buildRestrictedSettingsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'If the switch is greyed out and displays "Restricted setting" (common on Android 13+ for sideloaded/debug apps), follow these steps to unlock it:',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF9A3412),
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildStepCard(
          stepNumber: '1',
          title: 'Open main phone Settings',
          description: 'Go to your device\'s home screen and open the main Settings app.',
          icon: Icons.settings_rounded,
        ),
        _buildStepCard(
          stepNumber: '2',
          title: 'Find Fravo in App settings',
          description: 'Navigate to "Apps" -> "See all apps" (or "App Management"), then select "Fravo".',
          icon: Icons.apps_rounded,
        ),
        _buildStepCard(
          stepNumber: '3',
          title: 'Tap the top-right three dots (⋮)',
          description: 'On Fravo\'s App Info screen, tap the vertical menu icon in the top right corner.',
          icon: Icons.more_vert_rounded,
        ),
        _buildStepCard(
          stepNumber: '4',
          title: 'Allow restricted settings',
          description: 'Tap "Allow restricted settings" and authenticate with your fingerprint or PIN.',
          icon: Icons.lock_open_rounded,
          isHighlight: true,
        ),
        _buildStepCard(
          stepNumber: '5',
          title: 'Enable permission in settings',
          description: 'Return to Fravo and tap "Grant Permission" again. You can now enable "Fravo App Blocker Engine" without restriction.',
          icon: Icons.check_circle_rounded,
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isHighlight ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHighlight
                ? const Color(0xFFDDD6FE)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isHighlight
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  stepNumber,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isHighlight ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isHighlight
                          ? const Color(0xFF5B21B6)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              size: 20,
              color: isHighlight
                  ? const Color(0xFF8B5CF6)
                  : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

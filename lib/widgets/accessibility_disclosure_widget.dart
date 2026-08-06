import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../services/blocker_service.dart';

/// A beautiful, friendly disclosure banner that appears **only when**
/// Accessibility permission has NOT been granted.
///
/// **Permission result handling:** After the user is sent to system settings,
/// this widget auto-polls (every 2 s) until the native check confirms the
/// permission was actually granted — then animates out and removes itself.
/// This solves the issue where a single check right after the user presses
/// back can miss the permission commit if the timing is tight.
///
/// The widget is hidden entirely on non-Android platforms.
class AccessibilityDisclosureWidget extends StatefulWidget {
  const AccessibilityDisclosureWidget({super.key});

  @override
  State<AccessibilityDisclosureWidget> createState() =>
      _AccessibilityDisclosureWidgetState();
}

class _AccessibilityDisclosureWidgetState
    extends State<AccessibilityDisclosureWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _show = false;
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _checkAndShow();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app comes back to foreground, re-check — catches cases where
    // the system hasn't fully committed the permission yet.
    if (state == AppLifecycleState.resumed && _show) {
      _checkGranted();
    }
  }

  Future<void> _checkAndShow() async {
    final granted = await BlockerService.instance.checkAccessibilityStatus();
    if (!mounted) return;
    setState(() {
      _show = !granted;
      _loading = false;
    });
    if (_show) _controller.forward();
  }

  /// Polls the native layer to see if permission was granted.
  /// If granted, stops polling and animates the widget out.
  Future<void> _checkGranted() async {
    final granted = await BlockerService.instance.checkAccessibilityStatus();
    if (!mounted) return;
    if (granted) {
      _pollTimer?.cancel();
      setState(() => _show = false);
    } else if (_show && mounted) {
      // Still denied — keep polling every 2 s
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (!mounted || !_show) return;
        final stillGranted =
            await BlockerService.instance.checkAccessibilityStatus();
        if (mounted && !stillGranted) return;
        if (mounted && stillGranted) {
          _pollTimer?.cancel();
          setState(() => _show = false);
        }
      });
    }
  }

  Future<void> _grantPermission() async {
    await BlockerService.instance.requestAccessibilityPermission();
    // Immediately start polling — don't wait for the single re-check.
    if (mounted) _checkGranted();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid || _loading || !_show) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _DisclosureCard(onGrant: _grantPermission),
        ),
      ),
    );
  }
}

/// The inner disclosure card shown to the user.
class _DisclosureCard extends StatelessWidget {
  final VoidCallback onGrant;

  const _DisclosureCard({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ShieldIcon(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Almost there!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'One quick permission to unlock full protection',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InfoRow(
              icon: Icons.visibility_off_rounded,
              title: 'We only see what app you open',
              desc: 'No screen content, messages, or personal data — just the app name.',
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.schedule_rounded,
              title: 'Enforces your daily limits',
              desc: 'Detects when you open a restricted app so your screen time goals stay on track.',
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.lock_rounded,
              title: 'Everything stays on your phone',
              desc: 'All processing is local — nothing is shared or uploaded anywhere.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onGrant,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Grant Permission',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
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

class _ShieldIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.shield_rounded, color: Color(0xFF1A1A2E), size: 26),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF4A90E2)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A202C),
              )),
              Text(desc, style: const TextStyle(
                fontSize: 12, color: Color(0xFF64748B), height: 1.4,
              )),
            ],
          ),
        ),
      ],
    );
  }
}

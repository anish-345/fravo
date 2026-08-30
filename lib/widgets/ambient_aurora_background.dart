import 'package:flutter/material.dart';

/// Ambient Aurora Background that infuses screens with subtle pastel glows,
/// replacing flat blinding white canvases with organic depth and atmosphere.
class AmbientAuroraBackground extends StatelessWidget {
  final Widget child;
  final Color primaryGlow;
  final Color secondaryGlow;

  const AmbientAuroraBackground({
    super.key,
    required this.child,
    this.primaryGlow = const Color(0xFF10B981),
    this.secondaryGlow = const Color(0xFF8B5CF6),
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base canvas gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF1F8F5), // Soothing soft mint-slate
                Color(0xFFF8FAFC), // Crisp slate
                Color(0xFFF5F3FF), // Dreamy soft lavender
              ],
            ),
          ),
        ),

        // Top-left organic glowing ambient orb
        Positioned(
          top: -60,
          left: -40,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primaryGlow.withValues(alpha: 0.22),
                  primaryGlow.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Top-right warm amber subtle glow
        Positioned(
          top: 100,
          right: -50,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFF59E0B).withValues(alpha: 0.18),
                  const Color(0xFFF59E0B).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Bottom-left secondary lavender ambient orb
        Positioned(
          bottom: 40,
          left: -30,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  secondaryGlow.withValues(alpha: 0.20),
                  secondaryGlow.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Screen contents
        child,
      ],
    );
  }
}

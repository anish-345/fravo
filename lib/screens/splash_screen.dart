import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/companion_service.dart';
import '../widgets/pippy_avatar_widget.dart';

/// Animated Launcher / Splash Screen for Fravo.
/// Features a lively animated Pippy mascot entrance, blooming aura,
/// glowing typography, and a seamless transition to the main app.
class FravoAnimatedLaunchScreen extends StatefulWidget {
  final Widget nextScreen;

  const FravoAnimatedLaunchScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<FravoAnimatedLaunchScreen> createState() => _FravoAnimatedLaunchScreenState();
}

class _FravoAnimatedLaunchScreenState extends State<FravoAnimatedLaunchScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _auraPulseController;
  late Animation<double> _dropAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _sparkleAnimation;

  bool _navigated = false;
  Timer? _autoTransitionTimer;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _auraPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Pippy drops in with an elastic spring
    _dropAnimation = Tween<double>(begin: -180.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // Title & subtitle reveal
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // Floating sparkles
    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();

    // Auto-transition after intro animation completes
    _autoTransitionTimer = Timer(const Duration(milliseconds: 1900), () {
      _proceedToApp();
    });
  }

  @override
  void dispose() {
    _autoTransitionTimer?.cancel();
    _entranceController.dispose();
    _auraPulseController.dispose();
    super.dispose();
  }

  void _proceedToApp() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final companion = CompanionService.instance;

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _proceedToApp, // Instant tap-to-skip
        child: Stack(
          children: [
            // Background Ambient Glow
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF0FDF4),
                      Color(0xFFDCFCE7),
                      Color(0xFFD1FAE5),
                    ],
                  ),
                ),
              ),
            ),

            // Pulsing Aura Ring
            Center(
              child: AnimatedBuilder(
                animation: _auraPulseController,
                builder: (context, _) {
                  final pulse = _auraPulseController.value * 0.18;
                  return Container(
                    width: 260 * (1.0 + pulse),
                    height: 260 * (1.0 + pulse),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF10B981).withValues(alpha: 0.25 - (pulse * 0.08)),
                          const Color(0xFF34D399).withValues(alpha: 0.10),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Center Content: Animated Pippy + Fravo Brand
            Center(
              child: AnimatedBuilder(
                animation: _entranceController,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pippy Bouncing Mascot
                      Transform.translate(
                        offset: Offset(0, _dropAnimation.value),
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Mascot Canvas
                                PippyAvatarWidget(
                                  size: 160,
                                  mood: PippyMood.celebrate,
                                  aura: companion.aura,
                                  accessory: companion.accessory,
                                  streakDays: companion.currentStreak,
                                ),

                                // Floating Sparkles
                                if (_sparkleAnimation.value > 0) ...[
                                  _buildSparkle(-60, -50, '✨', 0.8),
                                  _buildSparkle(65, -40, '⭐', 1.0),
                                  _buildSparkle(-55, 45, '🌱', 0.7),
                                  _buildSparkle(58, 40, '💚', 0.9),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Fravo Brand Title & Subtitle
                      Opacity(
                        opacity: _textFadeAnimation.value,
                        child: Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFF065F46),
                                  Color(0xFF059669),
                                  Color(0xFF10B981),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'FRAVO',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 6.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Text(
                                'WALK MORE  •  SCROLL LESS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2.0,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom subtle tap hint
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _textFadeAnimation,
                builder: (context, _) {
                  return Opacity(
                    opacity: (_textFadeAnimation.value * 0.5).clamp(0.0, 1.0),
                    child: const Text(
                      'Tap anywhere to start',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparkle(double dx, double dy, String emoji, double scale) {
    return Transform.translate(
      offset: Offset(
        dx * _sparkleAnimation.value,
        dy * _sparkleAnimation.value + (math.sin(_auraPulseController.value * math.pi) * 4),
      ),
      child: Transform.scale(
        scale: scale * _sparkleAnimation.value,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

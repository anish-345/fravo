import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/companion_service.dart';

enum PippyMood {
  idle,
  walking,
  sleepy,
  celebrate,
  alert,
}

/// 60fps Animated Vector Mascot matching Fravo's Puffy Soft Glass aesthetic.
/// Includes automated streak-based visual evolution (Flame Glow, Neon Halo, Wings, Cosmic Crown).
/// When streak breaks (0 days), all automated effects are instantly stripped!
class PippyAvatarWidget extends StatefulWidget {
  final double size;
  final PippyMood mood;
  final CompanionAura aura;
  final CompanionAccessory accessory;
  final int? streakDays;
  final VoidCallback? onTap;

  const PippyAvatarWidget({
    super.key,
    this.size = 140,
    this.mood = PippyMood.idle,
    this.aura = CompanionAura.mint,
    this.accessory = CompanionAccessory.sprout,
    this.streakDays,
    this.onTap,
  });

  @override
  State<PippyAvatarWidget> createState() => _PippyAvatarWidgetState();
}

class _PippyAvatarWidgetState extends State<PippyAvatarWidget>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late AnimationController _jumpController;
  final List<_FloatingHeart> _hearts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _jumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  int get _effectiveStreak =>
      widget.streakDays ?? CompanionService.instance.currentStreak;

  void _handlePet(TapDownDetails details) {
    widget.onTap?.call();
    CompanionService.instance.addBondingXp(2);

    _jumpController.forward(from: 0.0);

    setState(() {
      _hearts.add(
        _FloatingHeart(
          offset: details.localPosition,
          createdAt: DateTime.now(),
          dxSpread: (math.Random().nextDouble() * 50) - 25,
          emoji: ['💚', '✨', '🌱', '⭐', '💖'][math.Random().nextInt(5)],
        ),
      );
    });

    // Auto clean hearts
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _hearts.removeWhere(
            (h) => DateTime.now().difference(h.createdAt).inMilliseconds > 900,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final streak = _effectiveStreak;

    return GestureDetector(
      onTapDown: _handlePet,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Aura Background Glow (Amplified if streak is active)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final pulse = math.sin(_controller.value * math.pi * 2) * 0.18;
                final glowColor = streak >= 3
                    ? const Color(0xFFF59E0B) // Fiery streak glow
                    : widget.aura.coreColor;

                return Container(
                  width: widget.size * (0.85 + pulse),
                  height: widget.size * (0.85 + pulse),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glowColor.withValues(alpha: streak >= 7 ? 0.45 : 0.35),
                        glowColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Animated Mascot Canvas with interactive jump/squash
            AnimatedBuilder(
              animation: Listenable.merge([_controller, _jumpController]),
              builder: (context, _) {
                double jumpY = 0.0;
                double jumpSquashX = 1.0;
                double jumpSquashY = 1.0;

                if (_jumpController.isAnimating) {
                  final jv = _jumpController.value;
                  // Parabolic jump arc
                  jumpY = -math.sin(jv * math.pi) * 20.0;
                  if (jv < 0.2) {
                    jumpSquashX = 1.15;
                    jumpSquashY = 0.85;
                  } else if (jv > 0.8) {
                    jumpSquashX = 1.12;
                    jumpSquashY = 0.88;
                  } else {
                    jumpSquashX = 0.92;
                    jumpSquashY = 1.08;
                  }
                }

                return Transform.translate(
                  offset: Offset(0, jumpY),
                  child: Transform.scale(
                    scaleX: jumpSquashX,
                    scaleY: jumpSquashY,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _PippyPainter(
                        progress: _controller.value,
                        mood: widget.mood,
                        aura: widget.aura,
                        accessory: widget.accessory,
                        streakDays: streak,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Floating Tap Hearts & Sparkles
            ..._hearts.map((heart) {
              final age = DateTime.now().difference(heart.createdAt).inMilliseconds;
              final progress = (age / 900).clamp(0.0, 1.0);
              final y = heart.offset.dy - (progress * 70);
              final x = heart.offset.dx + (heart.dxSpread * progress);
              final opacity = (1.0 - progress).clamp(0.0, 1.0);
              final scale = 0.6 + (progress * 0.9);

              return Positioned(
                left: x - 12,
                top: y - 12,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Text(heart.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FloatingHeart {
  final Offset offset;
  final DateTime createdAt;
  final double dxSpread;
  final String emoji;

  _FloatingHeart({
    required this.offset,
    required this.createdAt,
    required this.dxSpread,
    this.emoji = '💚',
  });
}

class _PippyPainter extends CustomPainter {
  final double progress;
  final PippyMood mood;
  final CompanionAura aura;
  final CompanionAccessory accessory;
  final int streakDays;

  _PippyPainter({
    required this.progress,
    required this.mood,
    required this.aura,
    required this.accessory,
    required this.streakDays,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 200.0;
    canvas.save();
    canvas.scale(scale);

    // Dynamic animation parameters based on mood
    double bodyBobY = 0.0;
    double bodySquashX = 1.0;
    double bodySquashY = 1.0;
    double bodyTilt = 0.0;
    double leftLegAngle = 0.0;
    double rightLegAngle = 0.0;
    double leftArmAngle = 0.0;
    double rightArmAngle = 0.0;
    double sproutAngle = 0.0;

    switch (mood) {
      case PippyMood.idle:
        final t = math.sin(progress * math.pi * 2);
        bodyBobY = t * 6.0;
        bodySquashX = 1.0 + (t * 0.04);
        bodySquashY = 1.0 - (t * 0.04);
        bodyTilt = t * 0.04;
        leftArmAngle = math.sin(progress * math.pi * 2) * 0.22;
        rightArmAngle = -leftArmAngle;
        sproutAngle = math.sin(progress * math.pi * 2) * 0.16;
        break;

      case PippyMood.walking:
        final t = math.sin(progress * math.pi * 4);
        bodyBobY = -t.abs() * 12.0;
        bodySquashX = 1.0 - (t * 0.05);
        bodySquashY = 1.0 + (t * 0.05);
        bodyTilt = math.sin(progress * math.pi * 2) * 0.08;
        leftLegAngle = math.sin(progress * math.pi * 4) * 0.55;
        rightLegAngle = -leftLegAngle;
        leftArmAngle = -leftLegAngle * 0.7;
        rightArmAngle = leftLegAngle * 0.7;
        sproutAngle = math.sin(progress * math.pi * 4) * 0.28;
        break;

      case PippyMood.sleepy:
        final t = math.sin(progress * math.pi * 2);
        bodyBobY = 6.0 + (t * 2.5);
        bodySquashX = 1.04;
        bodySquashY = 0.96;
        sproutAngle = 0.45;
        break;

      case PippyMood.celebrate:
        final t = math.sin(progress * math.pi * 4);
        bodyBobY = -t.abs() * 22.0;
        bodySquashX = 1.0 + (t * 0.10);
        bodySquashY = 1.0 - (t * 0.10);
        bodyTilt = math.sin(progress * math.pi * 2) * 0.12;
        leftLegAngle = math.sin(progress * math.pi * 4) * 0.3;
        rightLegAngle = -leftLegAngle;
        leftArmAngle = -0.7 + (math.sin(progress * math.pi * 4) * 0.2);
        rightArmAngle = 0.7 - (math.sin(progress * math.pi * 4) * 0.2);
        sproutAngle = math.sin(progress * math.pi * 4) * 0.35;
        break;

      case PippyMood.alert:
        final t = math.sin(progress * math.pi * 6);
        bodyBobY = -t.abs() * 8.0;
        bodyTilt = math.sin(progress * math.pi * 6) * 0.06;
        leftArmAngle = -0.4;
        rightArmAngle = 0.4;
        sproutAngle = t * 0.22;
        break;
    }

    // ── STREAK EFFECT: Level 4 (14+ Days) Celestial Wings (Behind Mascot) ────────
    if (streakDays >= 14) {
      _drawCelestialWings(canvas, 100, 110 + bodyBobY, progress);
    }

    // 1. Cute Feet / Shoes (Palette matches selected Aura)
    final shoePaint = Paint()
      ..shader = LinearGradient(
        colors: [aura.midColor, aura.deepColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(60, 150, 80, 35));

    // Left Foot
    canvas.save();
    canvas.translate(76, 160 + bodyBobY);
    canvas.rotate(leftLegAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 0, 28, 18), const Radius.circular(9)),
      shoePaint,
    );
    canvas.restore();

    // Right Foot
    canvas.save();
    canvas.translate(124, 160 + bodyBobY);
    canvas.rotate(rightLegAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 0, 28, 18), const Radius.circular(9)),
      shoePaint,
    );
    canvas.restore();

    // 3. Puffy Body
    canvas.save();
    canvas.translate(100, 110 + bodyBobY);
    canvas.rotate(bodyTilt);
    canvas.scale(bodySquashX, bodySquashY);

    final bodyRect = const Rect.fromLTWH(-55, -60, 110, 115);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(55));

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [aura.topColor, aura.midColor, aura.deepColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bodyRect);
    canvas.drawRRect(bodyRRect, bodyPaint);

    // Inner Glass Specular Sheen
    final sheenPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(const Rect.fromLTWH(-45, -55, 90, 45));
    canvas.drawOval(const Rect.fromLTWH(-40, -52, 80, 36), sheenPaint);

    // 4. Arms
    final armPaint = Paint()
      ..color = aura.midColor
      ..style = PaintingStyle.fill;

    // Left Arm
    canvas.save();
    canvas.translate(-46, 0);
    canvas.rotate(leftArmAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -8, 16, 26), const Radius.circular(8)),
      armPaint,
    );
    canvas.restore();

    // Right Arm
    canvas.save();
    canvas.translate(46, 0);
    canvas.rotate(rightArmAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -8, 16, 26), const Radius.circular(8)),
      armPaint,
    );
    canvas.restore();

    // 5. Eyes & Expression
    final eyePaint = Paint()..color = const Color(0xFF1E293B);
    final shinePaint = Paint()..color = Colors.white;
    final blushPaint = Paint()..color = const Color(0xFFFF8BA7).withValues(alpha: 0.50);

    // Rosy Cheeks
    canvas.drawOval(const Rect.fromLTWH(-42, 2, 18, 10), blushPaint);
    canvas.drawOval(const Rect.fromLTWH(24, 2, 18, 10), blushPaint);

    // Dynamic Blinking (Occurs naturally during each animation cycle)
    final bool isBlinking = (progress > 0.86 && progress < 0.94) &&
        (mood == PippyMood.idle || mood == PippyMood.walking);

    if (mood == PippyMood.sleepy || isBlinking) {
      // Sleeping / Blinking curved happy eyes (^ ^)
      final sleepEye = Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(const Rect.fromLTWH(-28, -12, 18, 14), math.pi, math.pi, false, sleepEye);
      canvas.drawArc(const Rect.fromLTWH(10, -12, 18, 14), math.pi, math.pi, false, sleepEye);
    } else if (mood == PippyMood.celebrate) {
      // Happy star eyes (> <)
      final starEye = Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final pathL = Path()..moveTo(-28, -14)..lineTo(-18, -6)..lineTo(-28, 2);
      final pathR = Path()..moveTo(28, -14)..lineTo(18, -6)..lineTo(28, 2);
      canvas.drawPath(pathL, starEye);
      canvas.drawPath(pathR, starEye);
    } else {
      // Sparkling Big Eyes with reflection dots
      canvas.drawOval(const Rect.fromLTWH(-27, -15, 16, 22), eyePaint);
      canvas.drawOval(const Rect.fromLTWH(11, -15, 16, 22), eyePaint);
      canvas.drawCircle(const Offset(-22, -10), 4.5, shinePaint);
      canvas.drawCircle(const Offset(16, -10), 4.5, shinePaint);
      canvas.drawCircle(const Offset(-18, -4), 2.2, shinePaint);
      canvas.drawCircle(const Offset(20, -4), 2.2, shinePaint);
    }

    // Mouth
    final mouthPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (mood == PippyMood.celebrate) {
      final happyMouth = Paint()..color = const Color(0xFFF43F5E);
      final mouthPath = Path()
        ..moveTo(-10, 8)
        ..quadraticBezierTo(0, 22, 10, 8)
        ..close();
      canvas.drawPath(mouthPath, happyMouth);
    } else {
      canvas.drawArc(const Rect.fromLTWH(-8, 6, 16, 10), 0, math.pi, false, mouthPaint);
    }

    // 6. Wardrobe Accessories (Hats / Sprout / Crown)
    canvas.save();
    canvas.translate(0, -56);
    canvas.rotate(sproutAngle);

    switch (accessory) {
      case CompanionAccessory.sprout:
        final stemPaint = Paint()
          ..color = aura.deepColor
          ..strokeWidth = 4.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final stemPath = Path()..moveTo(0, 0)..quadraticBezierTo(2, -14, -4, -22);
        canvas.drawPath(stemPath, stemPaint);

        final leafPaint = Paint()
          ..shader = LinearGradient(
            colors: [aura.coreColor, aura.deepColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(const Rect.fromLTWH(-6, -36, 30, 36));
        final pathL = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(-6, -24, 8, -36)
          ..quadraticBezierTo(24, -36, 18, -18)
          ..close();
        canvas.drawPath(pathL, leafPaint);
        break;

      case CompanionAccessory.crown:
        final crownPaint = Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
          ).createShader(const Rect.fromLTWH(-24, -24, 48, 24));
        final crownPath = Path()
          ..moveTo(-24, 0)
          ..lineTo(-18, -22)
          ..lineTo(0, -10)
          ..lineTo(18, -22)
          ..lineTo(24, 0)
          ..close();
        canvas.drawPath(crownPath, crownPaint);
        canvas.drawCircle(const Offset(-18, -22), 3, Paint()..color = const Color(0xFFF43F5E));
        canvas.drawCircle(const Offset(0, -10), 3, Paint()..color = const Color(0xFF10B981));
        canvas.drawCircle(const Offset(18, -22), 3, Paint()..color = const Color(0xFF3B82F6));
        break;

      case CompanionAccessory.sakura:
        final petalPaint = Paint()..color = const Color(0xFFFFB7C5);
        canvas.drawCircle(const Offset(0, -6), 12, petalPaint);
        canvas.drawCircle(const Offset(-8, -10), 9, petalPaint);
        canvas.drawCircle(const Offset(8, -10), 9, petalPaint);
        canvas.drawCircle(const Offset(0, -18), 9, petalPaint);
        canvas.drawCircle(const Offset(0, -6), 4, Paint()..color = const Color(0xFFFBBF24));
        break;

      case CompanionAccessory.headphones:
        final bandPaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke;
        canvas.drawArc(const Rect.fromLTWH(-54, 10, 108, 60), math.pi, math.pi, false, bandPaint);

        final cupPaint = Paint()..color = const Color(0xFFF43F5E);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-60, 38, 14, 22), const Radius.circular(6)), cupPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(46, 38, 14, 22), const Radius.circular(6)), cupPaint);
        break;
    }

    canvas.restore();
    canvas.restore(); // Restore body scale

    // ── STREAK EFFECTS (Foreground / Ambient Sparks) ──────────────────────────
    // Level 2 (3+ Days): Ignited Flame Sparks
    if (streakDays >= 3) {
      _drawFlameParticles(canvas, 100, 110 + bodyBobY, progress);
    }

    // Level 3 (7+ Days): Electric Neon Halo
    if (streakDays >= 7) {
      _drawElectricHalo(canvas, 100, 48 + bodyBobY, progress);
    }

    // Level 5 (30+ Days): Cosmic Supernova Crown Crest
    if (streakDays >= 30) {
      _drawCosmicCrown(canvas, 100, 36 + bodyBobY, progress);
    }

    canvas.restore();
  }

  /// Level 2 Streak Effect (3+ Days): Floating Animated Flame Sparks
  void _drawFlameParticles(Canvas canvas, double cx, double cy, double t) {
    final flameColors = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFFFCD34D),
    ];

    for (int i = 0; i < 6; i++) {
      final angle = (i * (math.pi / 3)) + (t * math.pi * 2);
      final radius = 62.0 + (math.sin(t * math.pi * 4 + i) * 6.0);
      final px = cx + math.cos(angle) * radius;
      final py = cy + math.sin(angle) * (radius * 0.7) - (math.sin(t * math.pi * 2 + i) * 12);
      final sparkSize = 3.5 + (math.sin(t * math.pi * 3 + i).abs() * 3.0);

      final sparkPaint = Paint()
        ..color = flameColors[i % flameColors.length].withValues(alpha: 0.85)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);

      canvas.drawCircle(Offset(px, py), sparkSize, sparkPaint);
    }
  }

  /// Level 3 Streak Effect (7+ Days): Neon Electric Halo Ring
  void _drawElectricHalo(Canvas canvas, double cx, double cy, double t) {
    final haloRect = Rect.fromCenter(center: Offset(cx, cy), width: 70, height: 18);
    final haloPaint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFF38BDF8),
          Color(0xFF818CF8),
          Color(0xFF34D399),
          Color(0xFF38BDF8),
        ],
      ).createShader(haloRect)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawOval(haloRect, haloPaint);

    // Electric Sparkle
    final sparkX = cx + math.cos(t * math.pi * 4) * 35;
    final sparkY = cy + math.sin(t * math.pi * 4) * 9;
    canvas.drawCircle(Offset(sparkX, sparkY), 3.0, Paint()..color = Colors.white);
  }

  /// Level 4 Streak Effect (14+ Days): Radiant Celestial Wings
  void _drawCelestialWings(Canvas canvas, double cx, double cy, double t) {
    final flap = math.sin(t * math.pi * 2) * 6.0;
    final wingPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 160, height: 80));

    // Left Wing
    final pathL = Path()
      ..moveTo(cx - 30, cy - 10)
      ..quadraticBezierTo(cx - 75, cy - 45 - flap, cx - 80, cy - 20)
      ..quadraticBezierTo(cx - 70, cy + 10, cx - 30, cy + 15)
      ..close();
    canvas.drawPath(pathL, wingPaint);

    // Right Wing
    final pathR = Path()
      ..moveTo(cx + 30, cy - 10)
      ..quadraticBezierTo(cx + 75, cy - 45 - flap, cx + 80, cy - 20)
      ..quadraticBezierTo(cx + 70, cy + 10, cx + 30, cy + 15)
      ..close();
    canvas.drawPath(pathR, wingPaint);
  }

  /// Level 5 Streak Effect (30+ Days): Cosmic Supernova Crown Crest
  void _drawCosmicCrown(Canvas canvas, double cx, double cy, double t) {
    final cosmicPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFF43F5E), Color(0xFF8B5CF6), Colors.transparent],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: 40, height: 40));

    canvas.drawCircle(Offset(cx, cy), 14, cosmicPaint);
    canvas.drawCircle(
      Offset(cx, cy),
      3.5 + (math.sin(t * math.pi * 4).abs() * 2),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PippyPainter oldDelegate) => true;
}

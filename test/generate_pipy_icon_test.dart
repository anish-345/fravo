import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render Pippy App Icon & Notification Icons from code', () async {
    const int iconSize = 1024;

    // 1. Render Full Standard App Icon (for iOS, web, windows, and legacy Android)
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, iconSize.toDouble(), iconSize.toDouble()));
    _drawFullIcon(canvas, iconSize.toDouble());
    final picture = recorder.endRecording();
    final img = await picture.toImage(iconSize, iconSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final file = File('assets/icon/app_icon.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    debugPrint('Generated assets/icon/app_icon.png (${bytes.length} bytes)');

    // 2. Render Adaptive Foreground Icon (with Android adaptive safe margin)
    final fgRecorder = ui.PictureRecorder();
    final fgCanvas = Canvas(fgRecorder, Rect.fromLTWH(0, 0, iconSize.toDouble(), iconSize.toDouble()));
    _drawAdaptiveForeground(fgCanvas, iconSize.toDouble());
    final fgPicture = fgRecorder.endRecording();
    final fgImg = await fgPicture.toImage(iconSize, iconSize);
    final fgByteData = await fgImg.toByteData(format: ui.ImageByteFormat.png);
    final fgBytes = fgByteData!.buffer.asUint8List();

    final fgFile = File('assets/icon/app_icon_foreground.png');
    await fgFile.writeAsBytes(fgBytes);
    debugPrint('Generated assets/icon/app_icon_foreground.png (${fgBytes.length} bytes)');

    // 3. Render Large Notification Icon (Full color rich 512x512)
    final largeNotifFile = File('android/app/src/main/res/drawable/notification_large_icon.png');
    await largeNotifFile.parent.create(recursive: true);
    await largeNotifFile.writeAsBytes(bytes);
    debugPrint('Generated android/app/src/main/res/drawable/notification_large_icon.png');

    // 4. Render Small Notification Silhouette Icons across Android density buckets (white on transparent)
    final densities = {
      'mdpi': 24,
      'hdpi': 36,
      'xhdpi': 48,
      'xxhdpi': 72,
      'xxxhdpi': 96,
    };

    for (final entry in densities.entries) {
      final size = entry.value;
      final notifRecorder = ui.PictureRecorder();
      final notifCanvas = Canvas(notifRecorder, Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));
      _drawNotificationSilhouette(notifCanvas, size.toDouble());
      final notifPicture = notifRecorder.endRecording();
      final notifImg = await notifPicture.toImage(size, size);
      final notifByteData = await notifImg.toByteData(format: ui.ImageByteFormat.png);
      final notifBytes = notifByteData!.buffer.asUint8List();

      final notifFile = File('android/app/src/main/res/drawable-${entry.key}/ic_notification.png');
      await notifFile.parent.create(recursive: true);
      await notifFile.writeAsBytes(notifBytes);
      debugPrint('Generated ${notifFile.path} (${size}x$size)');
    }

    // Default drawable notification icon
    final defaultNotifFile = File('android/app/src/main/res/drawable/notification_icon.png');
    final notif48Recorder = ui.PictureRecorder();
    final notif48Canvas = Canvas(notif48Recorder, const Rect.fromLTWH(0, 0, 48, 48));
    _drawNotificationSilhouette(notif48Canvas, 48);
    final notif48Pic = notif48Recorder.endRecording();
    final notif48Img = await notif48Pic.toImage(48, 48);
    final notif48Data = await notif48Img.toByteData(format: ui.ImageByteFormat.png);
    await defaultNotifFile.writeAsBytes(notif48Data!.buffer.asUint8List());
    debugPrint('Generated android/app/src/main/res/drawable/notification_icon.png');
  });
}

void _drawFullIcon(Canvas canvas, double size) {
  // ── Background Gradient ────────────────────────────────────────────────────
  final bgRect = Rect.fromLTWH(0, 0, size, size);
  final bgPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF0FDF4), // Fresh mint tint
        Color(0xFFDCFCE7), // Soft pastel emerald
        Color(0xFFD1FAE5), // Smooth matcha base
      ],
    ).createShader(bgRect);
  canvas.drawRect(bgRect, bgPaint);

  // ── Outer Soft Mint Radiant Glow ───────────────────────────────────────────
  final glowPaint = Paint()
    ..shader = RadialGradient(
      colors: [
        const Color(0xFF10B981).withValues(alpha: 0.42),
        const Color(0xFF34D399).withValues(alpha: 0.18),
        Colors.transparent,
      ],
      stops: const [0.0, 0.60, 1.0],
    ).createShader(Rect.fromCircle(center: Offset(size * 0.5, size * 0.52), radius: size * 0.46));
  canvas.drawCircle(Offset(size * 0.5, size * 0.52), size * 0.46, glowPaint);

  // ── Pippy Mascot (Enlarged & Prominent) ───────────────────────────────────
  canvas.save();
  const double baseSize = 200.0;
  final double scale = (size * 0.82) / baseSize;
  canvas.translate(size * 0.5, size * 0.52);
  canvas.scale(scale);
  canvas.translate(-100, -110);

  _drawPippyMascot(canvas);

  canvas.restore();
}

void _drawAdaptiveForeground(Canvas canvas, double size) {
  canvas.save();
  const double baseSize = 200.0;
  final double scale = (size * 0.72) / baseSize;
  canvas.translate(size * 0.5, size * 0.52);
  canvas.scale(scale);
  canvas.translate(-100, -110);

  _drawPippyMascot(canvas);

  canvas.restore();
}

void _drawPippyMascot(Canvas canvas) {
  // Default Mint Aura Palette
  const topColor = Color(0xFFE8FDF3);
  const midColor = Color(0xFFB8F2D8);
  const deepColor = Color(0xFF10B981);

  // 1. Cute Feet / Shoes
  final shoePaint = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFF34D399), Color(0xFF059669)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(60, 156, 80, 24));

  // Left Foot
  canvas.save();
  canvas.translate(75, 162);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 0, 28, 16), const Radius.circular(8)),
    shoePaint,
  );
  canvas.restore();

  // Right Foot
  canvas.save();
  canvas.translate(125, 162);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 0, 28, 16), const Radius.circular(8)),
    shoePaint,
  );
  canvas.restore();

  // 3. Puffy Body
  canvas.save();
  canvas.translate(100, 110);

  const bodyRect = Rect.fromLTWH(-55, -60, 110, 115);
  final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(55));

  final bodyPaint = Paint()
    ..shader = const LinearGradient(
      colors: [topColor, midColor, deepColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(bodyRect);
  canvas.drawRRect(bodyRRect, bodyPaint);

  // Inner Glass Specular Sheen
  final sheenPaint = Paint()
    ..shader = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: 0.80),
        Colors.white.withValues(alpha: 0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(-45, -55, 90, 45));
  canvas.drawOval(const Rect.fromLTWH(-40, -52, 80, 36), sheenPaint);

  // 4. Arms
  final armPaint = Paint()
    ..shader = const LinearGradient(
      colors: [Color(0xFFB8F2D8), Color(0xFF10B981)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(const Rect.fromLTWH(-8, -8, 16, 26));

  // Left Arm
  canvas.save();
  canvas.translate(-46, 0);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -8, 16, 26), const Radius.circular(8)),
    armPaint,
  );
  canvas.restore();

  // Right Arm
  canvas.save();
  canvas.translate(46, 0);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -8, 16, 26), const Radius.circular(8)),
    armPaint,
  );
  canvas.restore();

  // 5. Eyes & Expression
  final eyePaint = Paint()..color = const Color(0xFF1E293B);
  final shinePaint = Paint()..color = Colors.white;
  final blushPaint = Paint()..color = const Color(0xFFFF8BA7).withValues(alpha: 0.55);

  // Rosy Cheeks
  canvas.drawOval(const Rect.fromLTWH(-42, 2, 18, 10), blushPaint);
  canvas.drawOval(const Rect.fromLTWH(24, 2, 18, 10), blushPaint);

  // Sparkling Big Eyes with reflection dots
  canvas.drawOval(const Rect.fromLTWH(-27, -15, 16, 22), eyePaint);
  canvas.drawOval(const Rect.fromLTWH(11, -15, 16, 22), eyePaint);
  canvas.drawCircle(const Offset(-22, -10), 4.5, shinePaint);
  canvas.drawCircle(const Offset(16, -10), 4.5, shinePaint);
  canvas.drawCircle(const Offset(-18, -4), 2.2, shinePaint);
  canvas.drawCircle(const Offset(20, -4), 2.2, shinePaint);

  // Mouth (Gentle, happy smile)
  final mouthPaint = Paint()
    ..color = const Color(0xFF1E293B)
    ..strokeWidth = 3.2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(const Rect.fromLTWH(-8, 6, 16, 10), 0, math.pi, false, mouthPaint);

  // 6. Sprout Accessory on Head
  canvas.save();
  canvas.translate(0, -56);

  final stemPaint = Paint()
    ..color = const Color(0xFF059669)
    ..strokeWidth = 4.8
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final stemPath = Path()..moveTo(0, 0)..quadraticBezierTo(2, -14, -4, -22);
  canvas.drawPath(stemPath, stemPaint);

  final leafPaint = Paint()..color = const Color(0xFF10B981);
  final pathL = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(-6, -24, 8, -36)
    ..quadraticBezierTo(24, -36, 18, -18)
    ..close();
  canvas.drawPath(pathL, leafPaint);

  // Leaf specular shine
  final leafShine = Paint()..color = const Color(0xFF6EE7B7);
  final leafShinePath = Path()
    ..moveTo(3, -6)
    ..quadraticBezierTo(0, -20, 10, -28)
    ..quadraticBezierTo(16, -28, 12, -16)
    ..close();
  canvas.drawPath(leafShinePath, leafShine);

  canvas.restore(); // Sprout
  canvas.restore(); // Body
}

/// Draws Android notification small icon: pure white silhouette with transparent cutouts
void _drawNotificationSilhouette(Canvas canvas, double size) {
  canvas.save();
  const double baseSize = 200.0;
  final double scale = (size * 0.88) / baseSize;
  canvas.translate(size * 0.5, size * 0.52);
  canvas.scale(scale);
  canvas.translate(-100, -110);

  final whitePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;

  // 1. Feet
  canvas.save();
  canvas.translate(75, 160);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 0, 28, 16), const Radius.circular(8)),
    whitePaint,
  );
  canvas.restore();

  canvas.save();
  canvas.translate(125, 160);
  canvas.drawRRect(
    RRect.fromRectAndRadius(const Rect.fromLTWH(-14, 0, 28, 16), const Radius.circular(8)),
    whitePaint,
  );
  canvas.restore();

  // 2. Body
  canvas.save();
  canvas.translate(100, 110);
  const bodyRect = Rect.fromLTWH(-55, -60, 110, 115);
  final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(55));
  canvas.drawRRect(bodyRRect, whitePaint);

  // 3. Sprout
  canvas.save();
  canvas.translate(0, -56);
  final stemPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 6.0
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final stemPath = Path()..moveTo(0, 0)..quadraticBezierTo(2, -14, -4, -22);
  canvas.drawPath(stemPath, stemPaint);

  final leafPath = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(-6, -24, 8, -36)
    ..quadraticBezierTo(24, -36, 18, -18)
    ..close();
  canvas.drawPath(leafPath, whitePaint);
  canvas.restore(); // Sprout

  // 4. Transparent Eye & Smile Cutouts
  final clearPaint = Paint()..blendMode = BlendMode.clear;

  // Eyes cutouts
  canvas.drawOval(const Rect.fromLTWH(-27, -15, 16, 22), clearPaint);
  canvas.drawOval(const Rect.fromLTWH(11, -15, 16, 22), clearPaint);

  // Smile cutout
  final smilePaint = Paint()
    ..blendMode = BlendMode.clear
    ..strokeWidth = 4.0
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(const Rect.fromLTWH(-8, 6, 16, 10), 0, math.pi, false, smilePaint);

  canvas.restore(); // Body
  canvas.restore();
}

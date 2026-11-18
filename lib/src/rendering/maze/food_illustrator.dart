import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/maze/food_item.dart';

/// Original 2D cartoon vector illustrator for all 8 fresh food products.
/// Never uses basic emojis; renders glossy shading, stems, leaves, seeds,
/// and bite marks when partially eaten.
class FoodIllustrator {
  FoodIllustrator._();

  static void drawFood(
    Canvas canvas,
    Offset center,
    double radius,
    FoodType type, {
    int conditionPercent = 100,
    bool showShadow = true,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    if (showShadow) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, radius * 0.78),
          width: radius * 1.45,
          height: radius * 0.48,
        ),
        Paint()..color = const Color(0x331F2A44),
      );
    }

    switch (type) {
      case FoodType.apple:
        _drawApple(canvas, radius);
        break;
      case FoodType.banana:
        _drawBanana(canvas, radius);
        break;
      case FoodType.mango:
        _drawMango(canvas, radius);
        break;
      case FoodType.strawberry:
        _drawStrawberry(canvas, radius);
        break;
      case FoodType.orange:
        _drawOrange(canvas, radius);
        break;
      case FoodType.watermelon:
        _drawWatermelon(canvas, radius);
        break;
      case FoodType.carrot:
        _drawCarrot(canvas, radius);
        break;
      case FoodType.tomato:
        _drawTomato(canvas, radius);
        break;
    }

    // Visual bite mark indicators when partially eaten
    if (conditionPercent < 100 && conditionPercent > 0) {
      _drawBiteMarks(canvas, radius, conditionPercent);
    }

    canvas.restore();
  }

  static void _drawApple(Canvas canvas, double r) {
    final body = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        radius: 0.9,
        colors: [Color(0xFFFF6B6B), Color(0xFFD92638)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r));

    // Rounded plump apple silhouette
    final path = Path()
      ..moveTo(0, -r * 0.55)
      ..cubicTo(r * 0.65, -r * 0.95, r * 1.08, -r * 0.15, r * 0.72, r * 0.68)
      ..cubicTo(r * 0.45, r * 0.95, r * 0.15, r * 0.85, 0, r * 0.72)
      ..cubicTo(-r * 0.15, r * 0.85, -r * 0.45, r * 0.95, -r * 0.72, r * 0.68)
      ..cubicTo(-r * 1.08, -r * 0.15, -r * 0.65, -r * 0.95, 0, -r * 0.55)
      ..close();

    canvas.drawPath(path, body);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8C1420)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1,
    );

    // Gloss highlight
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.34, -r * 0.2),
        width: r * 0.28,
        height: r * 0.44,
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );

    // Stem
    canvas.drawLine(
      Offset(0, -r * 0.52),
      Offset(r * 0.12, -r * 0.95),
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..strokeWidth = r * 0.15
        ..strokeCap = StrokeCap.round,
    );

    // Leaf
    final leaf = Path()
      ..moveTo(r * 0.08, -r * 0.78)
      ..quadraticBezierTo(r * 0.55, -r * 1.08, r * 0.62, -r * 0.65)
      ..quadraticBezierTo(r * 0.32, -r * 0.52, r * 0.08, -r * 0.78);
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF4CAF50));
  }

  static void _drawBanana(Canvas canvas, double r) {
    final path = Path()
      ..moveTo(-r * 0.68, -r * 0.55)
      ..quadraticBezierTo(-r * 0.88, r * 0.45, r * 0.22, r * 0.72)
      ..quadraticBezierTo(r * 0.82, r * 0.82, r * 0.92, r * 0.28)
      ..quadraticBezierTo(r * 0.42, r * 0.48, -r * 0.18, r * 0.16)
      ..quadraticBezierTo(-r * 0.45, -r * 0.08, -r * 0.44, -r * 0.62)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFEA61), Color(0xFFFFB703)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFA36A00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1,
    );

    // Brown stem & tip
    canvas.drawCircle(
      Offset(-r * 0.56, -r * 0.62),
      r * 0.14,
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.drawCircle(
      Offset(r * 0.90, r * 0.28),
      r * 0.09,
      Paint()..color = const Color(0xFF6D4C41),
    );

    // Shine arc
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r * 0.1, -r * 0.05), radius: r * 0.52),
      math.pi * 0.62,
      math.pi * 0.35,
      false,
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _drawMango(Canvas canvas, double r) {
    canvas.save();
    canvas.rotate(-0.25);

    final rect = Rect.fromCenter(center: Offset.zero, width: r * 1.45, height: r * 1.75);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF5E5B), Color(0xFFFFB703), Color(0xFF90BE6D)],
        stops: [0.0, 0.58, 1.0],
      ).createShader(rect);

    canvas.drawOval(rect, paint);
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFF9E4716)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    // Gloss
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.28, -r * 0.28), width: r * 0.24, height: r * 0.52),
      Paint()..color = const Color(0x66FFFFFF),
    );

    // Stem + leaf
    final leaf = Path()
      ..moveTo(0, -r * 0.85)
      ..quadraticBezierTo(r * 0.55, -r * 1.15, r * 0.58, -r * 0.65)
      ..quadraticBezierTo(r * 0.25, -r * 0.65, 0, -r * 0.85);
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF43AA8B));
    canvas.restore();
  }

  static void _drawStrawberry(Canvas canvas, double r) {
    final path = Path()
      ..moveTo(0, r * 0.9)
      ..cubicTo(r * 0.72, r * 0.55, r * 0.95, -r * 0.25, r * 0.55, -r * 0.62)
      ..quadraticBezierTo(0, -r * 0.76, -r * 0.55, -r * 0.62)
      ..cubicTo(-r * 0.95, -r * 0.25, -r * 0.72, r * 0.55, 0, r * 0.9)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFF6B8B), Color(0xFFE01E37)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8F0D22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    // Golden seeds
    final seedPaint = Paint()..color = const Color(0xFFFFE66D);
    for (final pt in [
      Offset(-r * 0.34, -r * 0.18),
      Offset(0, -r * 0.12),
      Offset(r * 0.34, -r * 0.18),
      Offset(-r * 0.22, r * 0.22),
      Offset(r * 0.22, r * 0.22),
      Offset(0, r * 0.5),
    ]) {
      canvas.drawCircle(pt, r * 0.075, seedPaint);
    }

    // Green crown leaves
    final crown = Path()
      ..moveTo(-r * 0.58, -r * 0.58)
      ..lineTo(-r * 0.2, -r * 0.45)
      ..lineTo(0, -r * 0.88)
      ..lineTo(r * 0.2, -r * 0.45)
      ..lineTo(r * 0.58, -r * 0.58)
      ..lineTo(r * 0.22, -r * 0.78)
      ..lineTo(-r * 0.22, -r * 0.78)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFF40916C));
  }

  static void _drawOrange(Canvas canvas, double r) {
    canvas.drawCircle(
      Offset.zero,
      r * 0.82,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xFFFFB703), Color(0xFFFB5607)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.82,
      Paint()
        ..color = const Color(0xFFA83E00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    // Subtle dimples + gloss
    final dimple = Paint()..color = const Color(0x44A83E00);
    canvas.drawCircle(Offset(r * 0.3, r * 0.28), r * 0.06, dimple);
    canvas.drawCircle(Offset(r * 0.44, r * 0.05), r * 0.05, dimple);
    canvas.drawCircle(Offset(r * 0.12, r * 0.42), r * 0.05, dimple);

    canvas.drawCircle(
      Offset(-r * 0.3, -r * 0.3),
      r * 0.2,
      Paint()..color = const Color(0x66FFFFFF),
    );

    // Leaf
    final leaf = Path()
      ..moveTo(0, -r * 0.78)
      ..quadraticBezierTo(r * 0.48, -r * 1.12, r * 0.55, -r * 0.65)
      ..quadraticBezierTo(r * 0.22, -r * 0.58, 0, -r * 0.78);
    canvas.drawPath(leaf, Paint()..color = const Color(0xFF52B788));
  }

  static void _drawWatermelon(Canvas canvas, double r) {
    // Classic bright melon wedge
    final outerRect = Rect.fromCircle(center: Offset(0, -r * 0.12), radius: r * 0.92);
    // Dark green rind
    canvas.drawArc(
      outerRect,
      0.08,
      math.pi - 0.16,
      true,
      Paint()..color = const Color(0xFF2D6A4F),
    );
    // Pale green inner rind
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -r * 0.12), radius: r * 0.78),
      0.1,
      math.pi - 0.2,
      true,
      Paint()..color = const Color(0xFFD8F3DC),
    );
    // Juicy pink-red flesh
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -r * 0.12), radius: r * 0.68),
      0.12,
      math.pi - 0.24,
      true,
      Paint()..color = const Color(0xFFFF4D6D),
    );
    // Seeds
    final seedPaint = Paint()..color = const Color(0xFF243447);
    for (final pt in [
      Offset(-r * 0.3, r * 0.12),
      Offset(0, r * 0.26),
      Offset(r * 0.3, r * 0.12),
    ]) {
      canvas.drawCircle(pt, r * 0.075, seedPaint);
    }
  }

  static void _drawCarrot(Canvas canvas, double r) {
    canvas.save();
    canvas.rotate(0.45);
    // Leafy green top
    final leaves = Paint()
      ..color = const Color(0xFF40916C)
      ..strokeWidth = r * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -r * 0.65), Offset(-r * 0.28, -r * 1.02), leaves);
    canvas.drawLine(Offset(0, -r * 0.65), Offset(0, -r * 1.08), leaves);
    canvas.drawLine(Offset(0, -r * 0.65), Offset(r * 0.28, -r * 1.02), leaves);

    // Tapered carrot body
    final body = Path()
      ..moveTo(-r * 0.45, -r * 0.58)
      ..quadraticBezierTo(0, -r * 0.78, r * 0.45, -r * 0.58)
      ..lineTo(0, r * 0.92)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF9F1C), Color(0xFFE85D04)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF9D3800)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    // Ridge lines
    final ridge = Paint()
      ..color = const Color(0x669D3800)
      ..strokeWidth = r * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-r * 0.22, -r * 0.2), Offset(r * 0.1, -r * 0.2), ridge);
    canvas.drawLine(Offset(-r * 0.1, r * 0.2), Offset(r * 0.15, r * 0.2), ridge);
    canvas.restore();
  }

  static void _drawTomato(Canvas canvas, double r) {
    final rect = Rect.fromCenter(center: Offset(0, r * 0.08), width: r * 1.65, height: r * 1.45);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFFF595E), Color(0xFFC1121F)],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0xFF780000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );
    // Gloss
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-r * 0.34, -r * 0.14), width: r * 0.25, height: r * 0.38),
      Paint()..color = const Color(0x66FFFFFF),
    );
    // Star calyx
    final calyx = Paint()
      ..color = const Color(0xFF2D6A4F)
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -r * 0.56), Offset(-r * 0.38, -r * 0.42), calyx);
    canvas.drawLine(Offset(0, -r * 0.56), Offset(r * 0.38, -r * 0.42), calyx);
    canvas.drawLine(Offset(0, -r * 0.56), Offset(0, -r * 0.88), calyx);
  }

  static void _drawBiteMarks(Canvas canvas, double r, int conditionPercent) {
    final bitePaint = Paint()..color = const Color(0xFFFFF5DF);
    final edgePaint = Paint()
      ..color = const Color(0xFF8D5B2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08;

    // First bite on top-right
    final b1 = Offset(r * 0.55, -r * 0.2);
    canvas.drawCircle(b1, r * 0.32, bitePaint);
    canvas.drawCircle(b1, r * 0.32, edgePaint);

    // Deeper second bite when <= 50%
    if (conditionPercent <= 55) {
      final b2 = Offset(r * 0.42, r * 0.32);
      canvas.drawCircle(b2, r * 0.32, bitePaint);
      canvas.drawCircle(b2, r * 0.32, edgePaint);
    }
  }
}

/// Reusable Flutter widget displaying an illustrated FoodItem with optional condition indicator.
class FoodIllustrationWidget extends StatelessWidget {
  final FoodType type;
  final double size;
  final int conditionPercent;

  const FoodIllustrationWidget({
    super.key,
    required this.type,
    this.size = 32,
    this.conditionPercent = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FoodWidgetPainter(
          type: type,
          conditionPercent: conditionPercent,
        ),
      ),
    );
  }
}

class _FoodWidgetPainter extends CustomPainter {
  final FoodType type;
  final int conditionPercent;

  _FoodWidgetPainter({required this.type, required this.conditionPercent});

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) * 0.42;
    FoodIllustrator.drawFood(
      canvas,
      Offset(size.width / 2, size.height / 2),
      r,
      type,
      conditionPercent: conditionPercent,
      showShadow: false,
    );
  }

  @override
  bool shouldRepaint(covariant _FoodWidgetPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.conditionPercent != conditionPercent;
}

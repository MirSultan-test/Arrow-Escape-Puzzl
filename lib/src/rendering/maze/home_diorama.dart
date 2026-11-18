import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/maze/delivery_state.dart';
import '../../models/maze/food_item.dart';
import 'character_illustrator.dart';
import 'food_illustrator.dart';

/// Illustrated animated miniature food-delivery world diorama displayed on the Home screen.
class HomeFoodDiorama extends StatefulWidget {
  final bool reducedMotion;

  const HomeFoodDiorama({super.key, this.reducedMotion = false});

  @override
  State<HomeFoodDiorama> createState() => _HomeFoodDioramaState();
}

class _HomeFoodDioramaState extends State<HomeFoodDiorama>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (!widget.reducedMotion) {
      _anim.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant HomeFoodDiorama oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reducedMotion && _anim.isAnimating) {
      _anim.stop();
    } else if (!widget.reducedMotion && !_anim.isAnimating) {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return CustomPaint(
          painter: _HomeDioramaPainter(progress: _anim.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HomeDioramaPainter extends CustomPainter {
  final double progress;

  _HomeDioramaPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
    );

    // Warm sunlit sky gradient
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF9BE0FA), Color(0xFFFFF7E8)],
          stops: [0.0, 0.72],
        ).createShader(Offset.zero & size),
    );

    // Cheerful sun
    canvas.drawCircle(
      Offset(w * 0.84, h * 0.22),
      h * 0.13,
      Paint()..color = const Color(0xFFFFD166),
    );
    canvas.drawCircle(
      Offset(w * 0.84, h * 0.22),
      h * 0.17,
      Paint()..color = const Color(0x44FFD166),
    );

    // Drifting soft clouds
    final cloudShift = progress * w * 0.35;
    _drawCloud(canvas, Offset((w * 0.18 + cloudShift) % (w + 60) - 30, h * 0.2), 18);
    _drawCloud(canvas, Offset((w * 0.62 + cloudShift * 0.6) % (w + 60) - 30, h * 0.15), 14);

    // Rolling sunny orchard hills
    final hillBack = Path()
      ..moveTo(0, h * 0.68)
      ..quadraticBezierTo(w * 0.28, h * 0.42, w * 0.56, h * 0.62)
      ..quadraticBezierTo(w * 0.82, h * 0.45, w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillBack, Paint()..color = const Color(0xFF7CD18F));

    final hillFront = Path()
      ..moveTo(0, h * 0.74)
      ..quadraticBezierTo(w * 0.4, h * 0.58, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillFront, Paint()..color = const Color(0xFF5DBB75));

    // Winding cobblestone delivery road
    final road = Path()
      ..moveTo(0, h * 0.84)
      ..quadraticBezierTo(w * 0.48, h * 0.76, w, h * 0.86)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFFF3DFC1));
    canvas.drawPath(
      Path()
        ..moveTo(0, h * 0.89)
        ..quadraticBezierTo(w * 0.48, h * 0.82, w, h * 0.91),
      Paint()
        ..color = const Color(0x88C88D4D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Fruit Market Stall on the left with red-and-cream striped awning
    _drawFruitStall(canvas, Offset(w * 0.22, h * 0.66), h * 0.34);

    // Orchard hedge & fruit tree on the right
    _drawOrchardTree(canvas, Offset(w * 0.86, h * 0.54), h * 0.22);

    // Animated Delivery Truck cruising along the winding road (visible right away on frame 0!)
    final truckT = ((progress + 0.56) * 1.35) % 1.35 - 0.18;
    final truckX = truckT * w;
    final truckY = h * 0.82 - math.sin(truckT.clamp(0.0, 1.0) * math.pi) * h * 0.04;
    CharacterIllustrator.drawDeliveryTruck(
      canvas,
      Offset(truckX, truckY),
      h * 0.16,
      state: TruckAnimState.waiting,
      driveOffset: 0,
      loadedFoods: [
        FoodItem(id: 'd1', type: FoodType.apple, spawnCol: 0, spawnRow: 0),
        FoodItem(id: 'd2', type: FoodType.banana, spawnCol: 0, spawnRow: 0),
        FoodItem(id: 'd3', type: FoodType.mango, spawnCol: 0, spawnRow: 0),
      ],
      elapsed: progress * 8.0,
    );

    // Friendly courier waving near the market stall holding an apple & strawberry
    CharacterIllustrator.drawCourier(
      canvas,
      Offset(w * 0.42, h * 0.72),
      h * 0.13,
      facingAngle: 0.2,
      walkPhase: progress * math.pi * 8,
      isMoving: false,
      carriedFoods: [
        FoodItem(id: 'c1', type: FoodType.apple, spawnCol: 0, spawnRow: 0),
        FoodItem(id: 'c2', type: FoodType.strawberry, spawnCol: 0, spawnRow: 0),
      ],
      isInvulnerable: false,
      isDamagedFlash: false,
      elapsed: progress * 8.0,
    );

    // Waiting collector on the right welcoming deliveries
    CharacterIllustrator.drawCollector(
      canvas,
      Offset(w * 0.72, h * 0.70),
      h * 0.125,
      state: CollectorAnimState.waiting,
      elapsed: progress * 8.0,
    );

    canvas.restore();
  }

  void _drawCloud(Canvas canvas, Offset c, double r) {
    final p = Paint()..color = const Color(0xDDFFFFFF);
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(c + Offset(r * 0.9, r * 0.12), r * 0.75, p);
    canvas.drawCircle(c + Offset(-r * 0.85, r * 0.15), r * 0.7, p);
  }

  void _drawFruitStall(Canvas canvas, Offset center, double scale) {
    final w = scale * 1.45;
    final h = scale * 0.95;

    // Wooden posts & counter
    canvas.drawRect(
      Rect.fromLTWH(center.dx - w * 0.44, center.dy - h * 0.25, w * 0.88, h * 0.52),
      Paint()..color = const Color(0xFFC88D4D),
    );
    canvas.drawRect(
      Rect.fromLTWH(center.dx - w * 0.48, center.dy - h * 0.28, w * 0.96, h * 0.14),
      Paint()..color = const Color(0xFF8D5B2B),
    );

    // Mini fruit crates on counter
    FoodIllustrator.drawFood(
      canvas,
      Offset(center.dx - w * 0.24, center.dy - h * 0.34),
      scale * 0.16,
      FoodType.apple,
      showShadow: false,
    );
    FoodIllustrator.drawFood(
      canvas,
      Offset(center.dx, center.dy - h * 0.34),
      scale * 0.16,
      FoodType.banana,
      showShadow: false,
    );
    FoodIllustrator.drawFood(
      canvas,
      Offset(center.dx + w * 0.24, center.dy - h * 0.34),
      scale * 0.16,
      FoodType.mango,
      showShadow: false,
    );

    // Striped coral & cream awning roof
    const stripes = 5;
    final sw = (w * 1.08) / stripes;
    for (int i = 0; i < stripes; i++) {
      final sx = center.dx - w * 0.54 + i * sw;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(sx, center.dy - h * 0.72, sw + 0.5, h * 0.26),
          const Radius.circular(4),
        ),
        Paint()
          ..color = i.isEven ? const Color(0xFFFF715B) : const Color(0xFFFFF7E8),
      );
    }
  }

  void _drawOrchardTree(Canvas canvas, Offset base, double scale) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(base.dx, base.dy + scale * 0.45), width: scale * 0.35, height: scale * 0.85),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF7A4A1C),
    );
    canvas.drawCircle(base, scale * 0.65, Paint()..color = const Color(0xFF3E8E53));
    canvas.drawCircle(base + Offset(-scale * 0.35, scale * 0.12), scale * 0.48, Paint()..color = const Color(0xFF5DBB75));
    canvas.drawCircle(base + Offset(scale * 0.32, scale * 0.14), scale * 0.46, Paint()..color = const Color(0xFF5DBB75));
    // Little apples in tree canopy
    canvas.drawCircle(base + Offset(-scale * 0.15, -scale * 0.1), scale * 0.11, Paint()..color = const Color(0xFFE63946));
    canvas.drawCircle(base + Offset(scale * 0.22, scale * 0.08), scale * 0.11, Paint()..color = const Color(0xFFE63946));
  }

  @override
  bool shouldRepaint(covariant _HomeDioramaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

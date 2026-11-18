import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/board_theme.dart';
import '../models/direction.dart';
import '../models/manifest_item.dart';
import '../models/parcel.dart';
import 'arrow_path_builder.dart';

/// CustomPainter rendering a delivery package with vector arrow, tape, gear badge, and manifest symbol.
class ParcelPainter extends CustomPainter {
  final Parcel parcel;
  final BoardTheme theme;
  final bool isHinted;
  final bool isPreviewRotated;

  ParcelPainter({
    required this.parcel,
    required this.theme,
    this.isHinted = false,
    this.isPreviewRotated = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * 0.18);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // 1. Drop shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    canvas.drawRRect(rrect.shift(const Offset(0, 3.0)), shadowPaint);

    // 2. Base parcel body
    Color baseColor = theme.parcelColorFor(parcel.colorType);
    if (parcel.manifestSymbol != null) {
      // Manifest parcel base has a subtle tint matching its category
      final symEnum = ManifestSymbolX.fromKey(parcel.manifestSymbol!);
      if (symEnum != null) {
        baseColor = Color.lerp(baseColor, symEnum.color, 0.22)!;
      }
    }

    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, basePaint);

    // 3. Subtle inner highlight (top edge)
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect.deflate(1.0), highlightPaint);

    // 4. Packaging tape accent
    final tapeColor = theme.defaultTape.withOpacity(0.85);
    final tapePaint = Paint()
      ..color = tapeColor
      ..style = PaintingStyle.fill;

    final tapeWidth = size.width * 0.20;
    final tapeRect = Rect.fromCenter(
      center: rect.center,
      width: parcel.direction == Direction.up || parcel.direction == Direction.down
          ? size.width * 0.95
          : tapeWidth,
      height: parcel.direction == Direction.up || parcel.direction == Direction.down
          ? tapeWidth
          : size.height * 0.95,
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(tapeRect, tapePaint);
    canvas.restore();

    // 5. Border
    final borderPaint = Paint()
      ..color = parcel.hasGear
          ? AppDesignTokens.gearBrass.withOpacity(0.9)
          : theme.defaultParcelBorder.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = parcel.hasGear ? 2.5 : 2.0;
    canvas.drawRRect(rrect, borderPaint);

    // 6. Vector Arrow (crisp path)
    final arrowPath = ArrowPathBuilder.buildArrowPath(
      size: size,
      direction: parcel.direction,
      scale: 0.50,
    );

    // Arrow shadow
    final arrowShadowPaint = Paint()
      ..color = theme.arrowShadow
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath.shift(const Offset(0, 1.5)), arrowShadowPaint);

    // Arrow main body
    final arrowPaint = Paint()
      ..color = theme.arrowColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);

    // Arrow crisp outline for maximum contrast
    final arrowOutline = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(arrowPath, arrowOutline);

    // 7. Gear Badge & Clockwise Curved Ring (if hasGear)
    if (parcel.hasGear) {
      _drawGearBadge(canvas, size);
    }

    // 8. Delivery Manifest Symbol Stamp (if manifestSymbol != null)
    if (parcel.manifestSymbol != null) {
      _drawManifestBadge(canvas, size, parcel.manifestSymbol!);
    }

    // 9. Hint / Preview glow if active
    if (isHinted) {
      final hintGlowPaint = Paint()
        ..color = theme.highlightGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawRRect(rrect.deflate(2.0), hintGlowPaint);
    } else if (isPreviewRotated) {
      final previewGlowPaint = Paint()
        ..color = AppDesignTokens.gearBrass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRRect(rrect.deflate(2.0), previewGlowPaint);
    }
  }

  void _drawGearBadge(Canvas canvas, Size size) {
    // Placed in top-right corner
    final badgeCenter = Offset(size.width * 0.80, size.height * 0.20);
    final badgeRadius = size.width * 0.14;

    // Badge background circle
    final bgPaint = Paint()
      ..color = AppDesignTokens.deepInk
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius + 2.0, bgPaint);

    final brassPaint = Paint()
      ..color = AppDesignTokens.gearBrass
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, brassPaint);

    // 6 gear cogs
    final cogPaint = Paint()
      ..color = AppDesignTokens.gearBrass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3);
      final p1 = badgeCenter + Offset(math.cos(angle) * (badgeRadius - 1), math.sin(angle) * (badgeRadius - 1));
      final p2 = badgeCenter + Offset(math.cos(angle) * (badgeRadius + 3.2), math.sin(angle) * (badgeRadius + 3.2));
      canvas.drawLine(p1, p2, cogPaint);
    }

    // Axle hole
    final axlePaint = Paint()
      ..color = AppDesignTokens.deepInk
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius * 0.35, axlePaint);

    // Clockwise arrow arc indicator around the badge
    final arcPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: badgeCenter, radius: badgeRadius + 4.5);
    canvas.drawArc(arcRect, -math.pi * 0.8, math.pi * 1.3, false, arcPaint);

    // Clockwise arrow head tip
    const arrowTipAngle = 0.5 * math.pi;
    final tipCenter = badgeCenter + Offset(math.cos(arrowTipAngle) * (badgeRadius + 4.5), math.sin(arrowTipAngle) * (badgeRadius + 4.5));
    final tipPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    final tipPath = Path()
      ..moveTo(tipCenter.dx, tipCenter.dy)
      ..lineTo(tipCenter.dx + 2.5, tipCenter.dy - 3.5)
      ..lineTo(tipCenter.dx - 3.0, tipCenter.dy - 2.0)
      ..close();
    canvas.drawPath(tipPath, tipPaint);
  }

  void _drawManifestBadge(Canvas canvas, Size size, String symbolKey) {
    // Placed in top-left corner
    final badgeCenter = Offset(size.width * 0.22, size.height * 0.22);
    final badgeRadius = size.width * 0.14;

    final symEnum = ManifestSymbolX.fromKey(symbolKey) ?? ManifestSymbol.star;

    // Dark badge rim
    final rimPaint = Paint()
      ..color = AppDesignTokens.deepInk
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius + 2.0, rimPaint);

    // Category colored badge
    final catPaint = Paint()
      ..color = symEnum.color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, catPaint);

    // White icon inside
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    switch (symEnum) {
      case ManifestSymbol.star:
        _drawStar(canvas, badgeCenter, badgeRadius * 0.65, iconPaint);
        break;
      case ManifestSymbol.moon:
        _drawMoon(canvas, badgeCenter, badgeRadius * 0.65, iconPaint);
        break;
      case ManifestSymbol.sun:
        _drawSun(canvas, badgeCenter, badgeRadius * 0.65, iconPaint);
        break;
      case ManifestSymbol.box:
        _drawBox(canvas, badgeCenter, badgeRadius * 0.60, iconPaint);
        break;
      case ManifestSymbol.diamond:
        _drawDiamond(canvas, badgeCenter, badgeRadius * 0.65, iconPaint);
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 4 * math.pi / 5) - (math.pi / 2);
      final point = center + Offset(math.cos(outerAngle) * r, math.sin(outerAngle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawMoon(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..addArc(Rect.fromCircle(center: center, radius: r), -math.pi * 0.4, math.pi * 1.5)
      ..arcTo(
        Rect.fromCircle(center: center.translate(r * 0.45, 0), radius: r * 0.75),
        math.pi * 0.8,
        -math.pi * 1.2,
        false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawSun(Canvas canvas, Offset center, double r, Paint paint) {
    canvas.drawCircle(center, r * 0.55, paint);
    final rayPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p1 = center + Offset(math.cos(a) * (r * 0.7), math.sin(a) * (r * 0.7));
      final p2 = center + Offset(math.cos(a) * (r * 1.05), math.sin(a) * (r * 1.05));
      canvas.drawLine(p1, p2, rayPaint);
    }
  }

  void _drawBox(Canvas canvas, Offset center, double r, Paint paint) {
    final rect = Rect.fromCenter(center: center, width: r * 1.6, height: r * 1.6);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.5)), paint);
  }

  void _drawDiamond(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..lineTo(center.dx + r, center.dy)
      ..lineTo(center.dx, center.dy + r)
      ..lineTo(center.dx - r, center.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ParcelPainter oldDelegate) {
    return oldDelegate.parcel != parcel ||
        oldDelegate.theme != theme ||
        oldDelegate.isHinted != isHinted ||
        oldDelegate.isPreviewRotated != isPreviewRotated;
  }
}

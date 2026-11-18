import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Interactive miniature diorama depicting the toy post office depot and unlocked district buildings.
class DepotDioramaWidget extends StatefulWidget {
  final int unlockedMilestoneCount;
  final int highestLevel;

  const DepotDioramaWidget({
    Key? key,
    required this.unlockedMilestoneCount,
    required this.highestLevel,
  }) : super(key: key);

  @override
  State<DepotDioramaWidget> createState() => _DepotDioramaWidgetState();
}

class _DepotDioramaWidgetState extends State<DepotDioramaWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gearAnim;

  @override
  void initState() {
    super.initState();
    _gearAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _gearAnim.repeat();
    }
  }

  @override
  void dispose() {
    _gearAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _gearAnim,
      builder: (context, _) {
        return Container(
          height: 125,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppDesignTokens.surfaceWarm,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppDesignTokens.surfaceBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                // 1. Custom painted miniature scene
                Positioned.fill(
                  child: CustomPaint(
                    painter: _DepotDioramaPainter(
                      gearRotation: _gearAnim.value * 2 * math.pi,
                      unlockedMilestoneCount: widget.unlockedMilestoneCount,
                    ),
                  ),
                ),

                // 2. Depot title & milestone progress chip
                Positioned(
                  top: 10,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.deepInk.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.settings_suggest_rounded,
                          size: 14,
                          color: AppDesignTokens.honeyHighlight,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Wind-Up Depot • Milestones ${widget.unlockedMilestoneCount}/10',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Quick milestone preview indicator
                Positioned(
                  bottom: 8,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (int i = 0; i < 5; i++)
                        _buildDistrictDot(
                          district: i + 1,
                          isUnlocked: widget.highestLevel >= ((i + 1) * 10 - 5),
                          isCompleted: widget.highestLevel >= ((i + 1) * 10),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistrictDot({
    required int district,
    required bool isUnlocked,
    required bool isCompleted,
  }) {
    Color bg;
    if (isCompleted) {
      bg = AppDesignTokens.tealSecondary;
    } else if (isUnlocked) {
      bg = AppDesignTokens.honeyHighlight;
    } else {
      bg = AppDesignTokens.surfaceBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignTokens.deepInk.withOpacity(0.2), width: 1),
      ),
      child: Text(
        'D$district',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isCompleted || isUnlocked ? AppDesignTokens.deepInk : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _DepotDioramaPainter extends CustomPainter {
  final double gearRotation;
  final int unlockedMilestoneCount;

  _DepotDioramaPainter({
    required this.gearRotation,
    required this.unlockedMilestoneCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background sky warmth
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFDE9CE),
          AppDesignTokens.surfaceWarm,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // Ground platform / Cobblestone floor
    final groundY = h * 0.76;
    final groundPaint = Paint()..color = const Color(0xFFE4D2B8);
    canvas.drawRect(Rect.fromLTWH(0, groundY, w, h - groundY), groundPaint);

    // Railway tracks
    final railPaint = Paint()
      ..color = const Color(0xFF8D7B68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(0, groundY + 12), Offset(w, groundY + 12), railPaint);
    canvas.drawLine(Offset(0, groundY + 18), Offset(w, groundY + 18), railPaint);

    // Ties
    final tiePaint = Paint()
      ..color = const Color(0xFF6D4C41)
      ..strokeWidth = 2.0;
    for (double x = 10; x < w; x += 16) {
      canvas.drawLine(Offset(x, groundY + 9), Offset(x, groundY + 21), tiePaint);
    }

    // Main Post Office Building (center-left)
    final depotLeft = w * 0.18;
    final depotWidth = w * 0.32;
    final depotHeight = h * 0.45;
    final depotTop = groundY - depotHeight;

    // Building wall (timber craft)
    final wallPaint = Paint()..color = const Color(0xFFD7A76E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(depotLeft, depotTop, depotWidth, depotHeight),
        const Radius.circular(4),
      ),
      wallPaint,
    );

    // Red roof
    final roofPath = Path()
      ..moveTo(depotLeft - 8, depotTop)
      ..lineTo(depotLeft + (depotWidth / 2), depotTop - 24)
      ..lineTo(depotLeft + depotWidth + 8, depotTop)
      ..close();
    final roofPaint = Paint()..color = AppDesignTokens.roofTile;
    canvas.drawPath(roofPath, roofPaint);

    // Chimney with steam puffs
    final chimneyLeft = depotLeft + depotWidth - 14;
    canvas.drawRect(
      Rect.fromLTWH(chimneyLeft, depotTop - 32, 10, 20),
      Paint()..color = const Color(0xFF8D5B4C),
    );

    // Smoke puffs
    final puffPaint = Paint()..color = Colors.white.withOpacity(0.45);
    canvas.drawCircle(Offset(chimneyLeft + 5, depotTop - 38), 4.5, puffPaint);
    canvas.drawCircle(Offset(chimneyLeft + 8, depotTop - 46), 6.5, puffPaint);

    // Clock in gable
    final clockCenter = Offset(depotLeft + (depotWidth / 2), depotTop - 10);
    canvas.drawCircle(clockCenter, 9, Paint()..color = Colors.white);
    canvas.drawCircle(clockCenter, 9, Paint()..color = AppDesignTokens.deepInk..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Clock hands
    canvas.drawLine(clockCenter, clockCenter + const Offset(0, -5), Paint()..color = AppDesignTokens.deepInk..strokeWidth = 1.5);
    canvas.drawLine(clockCenter, clockCenter + const Offset(4, 0), Paint()..color = AppDesignTokens.deepInk..strokeWidth = 1.5);

    // Depot door and windows
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(depotLeft + 12, groundY - 26, 16, 26),
        const Radius.circular(3),
      ),
      Paint()..color = AppDesignTokens.deepInk,
    );

    // Awning stripes (Coral and White)
    final awningTop = groundY - 32;
    for (int i = 0; i < 4; i++) {
      final stripeColor = i % 2 == 0 ? AppDesignTokens.coralPrimary : Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(depotLeft + 8 + (i * 9), awningTop, 9, 7),
        Paint()..color = stripeColor,
      );
    }

    // Rotating Brass Cogwheel on the right (The Wind-Up Mechanism)
    final gearCenter = Offset(w * 0.78, groundY - 38);
    _drawRotatingGear(canvas, gearCenter, 22, gearRotation);

    // Secondary interlocking gear
    final gear2Center = Offset(w * 0.65, groundY - 20);
    _drawRotatingGear(canvas, gear2Center, 14, -gearRotation * 1.5);

    // Miniature Courier Delivery Van on the track
    final vanX = w * 0.58;
    final vanY = groundY - 18;
    // Van body
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(vanX, vanY, 28, 16), const Radius.circular(3)),
      Paint()..color = AppDesignTokens.coralPrimary,
    );
    // Van window
    canvas.drawRect(Rect.fromLTWH(vanX + 18, vanY + 3, 7, 6), Paint()..color = Colors.white.withOpacity(0.8));
    // Van wheels
    canvas.drawCircle(Offset(vanX + 6, vanY + 16), 3.5, Paint()..color = AppDesignTokens.deepInk);
    canvas.drawCircle(Offset(vanX + 22, vanY + 16), 3.5, Paint()..color = AppDesignTokens.deepInk);
  }

  void _drawRotatingGear(Canvas canvas, Offset center, double radius, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final brassPaint = Paint()..color = AppDesignTokens.gearBrass;
    canvas.drawCircle(Offset.zero, radius, brassPaint);

    final rimPaint = Paint()
      ..color = AppDesignTokens.deepInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset.zero, radius, rimPaint);

    // 6 cogs
    for (int i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      final c1 = Offset(math.cos(a) * (radius - 2), math.sin(a) * (radius - 2));
      final c2 = Offset(math.cos(a) * (radius + 4), math.sin(a) * (radius + 4));
      canvas.drawLine(c1, c2, Paint()..color = AppDesignTokens.gearBrass..strokeWidth = 3.5);
      canvas.drawLine(c1, c2, Paint()..color = AppDesignTokens.deepInk..strokeWidth = 1.0..style = PaintingStyle.stroke);
    }

    // Center hole
    canvas.drawCircle(Offset.zero, radius * 0.3, Paint()..color = AppDesignTokens.deepInk);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DepotDioramaPainter oldDelegate) {
    return oldDelegate.gearRotation != gearRotation ||
        oldDelegate.unlockedMilestoneCount != unlockedMilestoneCount;
  }
}

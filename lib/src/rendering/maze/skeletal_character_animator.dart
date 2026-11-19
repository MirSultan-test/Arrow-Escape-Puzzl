import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/maze/character_animation_state.dart';
import '../../models/maze/combat_models.dart';
import '../../models/maze/monster_variants.dart';
import '../../models/maze/truck_defense_models.dart';
import 'food_illustrator.dart';
import 'unique_monster_illustrator.dart';

/// V3.4 Studio-Grade Articulated 2.5D Skeletal Character Animator.
/// Renders live, expressive, state-driven body-part animations for:
/// 1. Human Courier (8-way facing, alternating legs/arms, 9 facial expressions, real Bow draw & Blaster recoil)
/// 2. Dock Worker (distinct stocky foreman design, real 2-hand food loading, knife draw & 2-hit knife combo)
/// 3. Giant District Boss (5 distinct boss silhouettes, articulated legs/arms/claws/jaw, bomb-in-hand throw, slam, charge, recoil)
class SkeletalCharacterAnimator {
  SkeletalCharacterAnimator._();

  // ===========================================================================
  // 1. HUMAN COURIER — ARTICULATED 2.5D RIG
  // ===========================================================================

  static void drawCourierRig(
    Canvas canvas,
    Offset center,
    double r,
    CourierAnimSnapshot snap,
  ) {
    if (snap.isInvulnerable && ((snap.elapsed * 14).floor().isEven)) {
      canvas.saveLayer(
        Rect.fromCircle(center: center, radius: r * 2.8),
        Paint()..color = const Color(0x88FFFFFF),
      );
    } else {
      canvas.save();
    }

    final cosA = math.cos(snap.facingAngle);
    final sinA = math.sin(snap.facingAngle);
    final facingUp = sinA < -0.58;
    final facingLeft = cosA < -0.15;
    final faceDirX = facingLeft ? -1.0 : 1.0;

    final isMoving = snap.moveSpeedRatio > 0.05 &&
        snap.state != CourierAnimState.hurt &&
        snap.state != CourierAnimState.celebrate;

    // Hurt recoil displacement
    final recoilAmt = snap.state == CourierAnimState.hurt
        ? math.sin(snap.hurtRecoilProgress * math.pi) * r * 0.32
        : 0.0;
    final recoilOffset = Offset(
      snap.recoilDirX * recoilAmt,
      snap.recoilDirY * recoilAmt,
    );

    canvas.translate(center.dx + recoilOffset.dx, center.dy + recoilOffset.dy);

    // Status rings (healing / poison slow)
    if (snap.isHealing) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.32,
        Paint()..color = const Color(0x3C5DBB75),
      );
    } else if (snap.isPoisonSlowed) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.22,
        Paint()..color = const Color(0x449333EA),
      );
    }

    // Ground contact shadow (pulses slightly as feet lift during run!)
    final bob = snap.state == CourierAnimState.celebrate
        ? math.sin(snap.elapsed * 12).abs() * r * 0.36
        : (isMoving
            ? math.sin(snap.walkCyclePhase).abs() * r * (0.14 + 0.08 * snap.moveSpeedRatio)
            : math.sin(snap.elapsed * 3.0) * r * 0.03);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.90),
        width: r * (1.42 - bob / (r * 3.5)),
        height: r * 0.44,
      ),
      Paint()..color = const Color(0x3E1F2A44),
    );

    canvas.translate(0, -bob);

    // Dynamic body lean (leans forward when running, backward on hurt/bow-recoil!)
    double bodyLean = 0.0;
    if (snap.state == CourierAnimState.hurt) {
      bodyLean = -faceDirX * 0.24 * math.sin(snap.hurtRecoilProgress * math.pi);
    } else if (snap.state == CourierAnimState.releaseBow ||
        snap.state == CourierAnimState.fireBlaster) {
      bodyLean = -faceDirX * 0.12 * (1.0 - snap.stateProgress);
    } else if (isMoving) {
      bodyLean = faceDirX * (0.06 + snap.moveSpeedRatio * 0.09);
    }

    // --- A. ARTICULATED LEGS & BOOTS (zero leg motion when stationary!) ---
    final strideAmp = isMoving ? (0.28 + snap.moveSpeedRatio * 0.24) : 0.0;
    final legPhase = math.sin(snap.walkCyclePhase);
    final leftLegSwing = legPhase * strideAmp;
    final rightLegSwing = -legPhase * strideAmp;
    final leftLift = isMoving ? math.max(0.0, math.cos(snap.walkCyclePhase)) * r * 0.14 : 0.0;
    final rightLift = isMoving ? math.max(0.0, -math.cos(snap.walkCyclePhase)) * r * 0.14 : 0.0;

    _drawHumanLeg(
      canvas,
      hip: Offset(-r * 0.22, r * 0.36),
      r: r,
      swingAngle: leftLegSwing,
      liftY: leftLift,
      trouserColor: const Color(0xFF1E293B),
      bootColor: const Color(0xFF7A4424),
    );
    _drawHumanLeg(
      canvas,
      hip: Offset(r * 0.22, r * 0.36),
      r: r,
      swingAngle: rightLegSwing,
      liftY: rightLift,
      trouserColor: const Color(0xFF1E293B),
      bootColor: const Color(0xFF7A4424),
    );

    canvas.save();
    canvas.rotate(bodyLean);

    // --- B. ORANGE COURIER BACKPACK (behind torso when facing down/side) ---
    if (!facingUp) {
      final packShift = -faceDirX * r * 0.26;
      _drawCourierBackpack(canvas, Offset(packShift, r * 0.04), r);
    }

    // --- C. BACK ARM (swings opposite leg, or raises to draw bowstring / brace blaster!) ---
    final isCombatAction = snap.state == CourierAnimState.aimBow ||
        snap.state == CourierAnimState.releaseBow ||
        snap.state == CourierAnimState.fireBlaster ||
        snap.state == CourierAnimState.castOrb ||
        snap.state == CourierAnimState.meleeSlash;

    final armSwing = isMoving ? math.sin(snap.walkCyclePhase) * 0.55 * snap.moveSpeedRatio : 0.0;

    if (!isCombatAction) {
      _drawHumanArm(
        canvas,
        shoulder: Offset(-faceDirX * r * 0.44, -r * 0.08),
        r: r,
        angle: snap.state == CourierAnimState.celebrate
            ? -2.35
            : (snap.state == CourierAnimState.pickupFood
                ? -1.1
                : (-armSwing + 0.18 * faceDirX)),
        sleeveColor: _courierJacketColor(snap.equippedWeapon),
        handColor: const Color(0xFFFFD6B8),
      );
    }

    // --- D. TORSO (Expressive Adventure Tunic with Gold Trim & Breathing) ---
    final breath = 1.0 + math.sin(snap.elapsed * 3.5) * 0.025;
    final jacketColor = _courierJacketColor(snap.equippedWeapon);
    final torsoRect = Rect.fromCenter(
      center: Offset(0, r * 0.10),
      width: r * 0.96 * breath,
      height: r * 0.86,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(r * 0.30)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(jacketColor, Colors.white, 0.18)!,
            jacketColor,
            Color.lerp(jacketColor, const Color(0xFF0F172A), 0.25)!,
          ],
        ).createShader(torsoRect),
    );
    // Warm scarf / collar & golden center trim
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -r * 0.25), width: r * 0.72, height: r * 0.22),
        Radius.circular(r * 0.10),
      ),
      Paint()..color = const Color(0xFFFF9F1C),
    );
    // Belt + brass buckle
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, r * 0.36), width: r * 0.92, height: r * 0.14),
      Paint()..color = const Color(0xFF4A2C18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, r * 0.36), width: r * 0.24, height: r * 0.16),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFC857),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(r * 0.30)),
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.075),
    );

    // Backpack in front of torso ONLY when facing UP (shows back of adventurer!)
    if (facingUp) {
      _drawCourierBackpack(canvas, Offset(0, r * 0.08), r);
    }

    // --- E. EXPRESSIVE HUMAN HEAD, HAIRSTYLE & 9 FACIAL EXPRESSIONS ---
    _drawCourierHead(
      canvas,
      headCenter: Offset(faceDirX * r * 0.03, -r * 0.62),
      r: r,
      facingAngle: snap.facingAngle,
      facingUp: facingUp,
      faceDirX: faceDirX,
      expression: snap.expression,
      elapsed: snap.elapsed,
      isHurt: snap.state == CourierAnimState.hurt,
    );

    // --- F. FRONT ARM + TRUE ANIMATED WEAPON RIG (Bow draw/release, Blaster aim/recoil, Orb, Melee) ---
    if (isCombatAction || snap.equippedWeapon != null) {
      _drawCourierCombatArmsAndWeapon(
        canvas,
        r: r,
        snap: snap,
        faceDirX: faceDirX,
        armSwing: armSwing,
      );
    } else {
      _drawHumanArm(
        canvas,
        shoulder: Offset(faceDirX * r * 0.44, -r * 0.08),
        r: r,
        angle: snap.state == CourierAnimState.celebrate
            ? 2.35
            : (snap.state == CourierAnimState.pickupFood
                ? 1.1
                : (armSwing - 0.18 * faceDirX)),
        sleeveColor: jacketColor,
        handColor: const Color(0xFFFFD6B8),
      );
    }

    canvas.restore(); // End bodyLean

    // --- G. CARRIED FOOD BADGES FLOATING NEATLY ABOVE HEAD ---
    if (snap.carriedFoods.isNotEmpty) {
      final count = snap.carriedFoods.length;
      for (int i = 0; i < count; i++) {
        final f = snap.carriedFoods[i];
        final spreadX = (i - (count - 1) / 2.0) * r * 0.85;
        final foodOffset = Offset(spreadX, -r * 1.48);
        canvas.drawCircle(
          foodOffset,
          r * 0.36,
          Paint()..color = const Color(0xF2FFF7E8),
        );
        canvas.drawCircle(
          foodOffset,
          r * 0.36,
          Paint()
            ..color = f.conditionPercent < 100
                ? const Color(0xFFFF715B)
                : const Color(0xFF5DBB75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.08,
        );
        FoodIllustrator.drawFood(
          canvas,
          foodOffset,
          r * 0.27,
          f.type,
          conditionPercent: f.conditionPercent,
          showShadow: false,
        );
      }
    }

    // --- H. PROTECTIVE MAGICAL SHIELD BUBBLE ---
    if (snap.hasShield) {
      canvas.drawCircle(
        Offset(0, -r * 0.05),
        r * 1.32,
        Paint()..color = const Color(0x2838BDF8),
      );
      canvas.drawCircle(
        Offset(0, -r * 0.05),
        r * 1.32,
        Paint()
          ..color = const Color(0xCC38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.11,
      );
    }

    canvas.restore();
  }

  static Color _courierJacketColor(WeaponType? weapon) {
    if (weapon == WeaponType.energyBlaster) return const Color(0xFF6D28D9);
    if (weapon == WeaponType.bow) return const Color(0xFF0284C7);
    return const Color(0xFF0E9F8B);
  }

  static void _drawCourierBackpack(Canvas canvas, Offset center, double r) {
    final pack = Rect.fromCenter(center: center, width: r * 0.72, height: r * 0.74);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pack, Radius.circular(r * 0.20)),
      Paint()..color = const Color(0xFFE86A33),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pack.left + r * 0.08, pack.top + r * 0.06, pack.width - r * 0.16, r * 0.22),
        Radius.circular(r * 0.08),
      ),
      Paint()..color = const Color(0xFFFFA94D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pack, Radius.circular(r * 0.20)),
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.3, r * 0.065),
    );
  }

  static void _drawCourierHead(
    Canvas canvas, {
    required Offset headCenter,
    required double r,
    required double facingAngle,
    required bool facingUp,
    required double faceDirX,
    required CourierExpression expression,
    required double elapsed,
    required bool isHurt,
  }) {
    final headR = r * 0.56;
    final cosA = math.cos(facingAngle);
    final sinA = math.sin(facingAngle);

    // Soft shaded face circle
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: isHurt
              ? const [Color(0xFFFFC2C2), Color(0xFFFF9B9B)]
              : const [Color(0xFFFFE5CC), Color(0xFFF6C49D)],
        ).createShader(Rect.fromCircle(center: headCenter, radius: headR)),
    );
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, r * 0.07),
    );

    // Stylized Natural Spiky-Swept Chestnut Hair
    final hairPaint = Paint()..color = const Color(0xFF6B3F22);
    final hairHi = Paint()..color = const Color(0xFF9C6238);
    if (facingUp) {
      canvas.drawCircle(headCenter + Offset(0, -headR * 0.06), headR * 1.03, hairPaint);
      canvas.drawArc(
        Rect.fromCircle(center: headCenter, radius: headR * 0.72),
        -math.pi * 0.8,
        math.pi * 0.6,
        false,
        Paint()
          ..color = const Color(0xFF9C6238)
          ..style = PaintingStyle.stroke
          ..strokeWidth = headR * 0.16
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    // Hair cap + stylish windswept bangs
    canvas.drawArc(
      Rect.fromCenter(
        center: headCenter + Offset(0, -headR * 0.14),
        width: headR * 2.18,
        height: headR * 1.90,
      ),
      math.pi * 1.02,
      math.pi * 0.96,
      true,
      hairPaint,
    );
    final tuft = Path()
      ..moveTo(headCenter.dx - headR * 0.72, headCenter.dy - headR * 0.45)
      ..quadraticBezierTo(
        headCenter.dx - headR * 0.2,
        headCenter.dy - headR * 1.32,
        headCenter.dx + headR * 0.35,
        headCenter.dy - headR * 0.92,
      )
      ..quadraticBezierTo(
        headCenter.dx + headR * 0.78,
        headCenter.dy - headR * 1.12,
        headCenter.dx + headR * 0.86,
        headCenter.dy - headR * 0.42,
      )
      ..close();
    canvas.drawPath(tuft, hairPaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter + Offset(-headR * 0.18, -headR * 0.72),
        width: headR * 0.62,
        height: headR * 0.22,
      ),
      hairHi,
    );

    // --- 9 VISIBLY DISTINCT FACIAL EXPRESSIONS ---
    final lookX = cosA * headR * 0.16;
    final lookY = sinA * headR * 0.07;
    final eyeY = headCenter.dy + headR * 0.08 + lookY;
    final leftEye = Offset(headCenter.dx - headR * 0.33 + lookX, eyeY);
    final rightEye = Offset(headCenter.dx + headR * 0.33 + lookX, eyeY);
    final ink = Paint()
      ..color = const Color(0xFF1F2A44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, headR * 0.11)
      ..strokeCap = StrokeCap.round;

    final bool blinking =
        expression == CourierExpression.relaxed && ((elapsed % 3.8) > 3.64);

    if (expression == CourierExpression.pain) {
      // Winced '> <' eyes + open shock mouth!
      canvas.drawLine(leftEye + Offset(-headR * 0.14, -headR * 0.10), leftEye + Offset(headR * 0.10, 0), ink);
      canvas.drawLine(leftEye + Offset(-headR * 0.14, headR * 0.10), leftEye + Offset(headR * 0.10, 0), ink);
      canvas.drawLine(rightEye + Offset(headR * 0.14, -headR * 0.10), rightEye + Offset(-headR * 0.10, 0), ink);
      canvas.drawLine(rightEye + Offset(headR * 0.14, headR * 0.10), rightEye + Offset(-headR * 0.10, 0), ink);
      canvas.drawOval(
        Rect.fromCenter(center: headCenter + Offset(lookX * 0.5, headR * 0.45), width: headR * 0.36, height: headR * 0.28),
        Paint()..color = const Color(0xFFB91C1C),
      );
    } else if (expression == CourierExpression.happy) {
      // Cheerful '^ ^' crescent eyes + big grin!
      for (final e in [leftEye, rightEye]) {
        canvas.drawArc(
          Rect.fromCenter(center: e, width: headR * 0.30, height: headR * 0.24),
          math.pi * 1.1,
          math.pi * 0.8,
          false,
          ink,
        );
      }
      canvas.drawArc(
        Rect.fromCenter(center: headCenter + Offset(lookX * 0.5, headR * 0.36), width: headR * 0.52, height: headR * 0.34),
        0.1,
        math.pi - 0.2,
        true,
        Paint()..color = const Color(0xFFD9465F),
      );
    } else {
      // Open expressive eyes (or blink)
      for (final e in [leftEye, rightEye]) {
        if (blinking) {
          canvas.drawLine(e + Offset(-headR * 0.14, 0), e + Offset(headR * 0.14, 0), ink);
        } else {
          final eyeH = expression == CourierExpression.alert ? headR * 0.40 : headR * 0.34;
          canvas.drawOval(
            Rect.fromCenter(center: e, width: headR * 0.30, height: eyeH),
            Paint()..color = Colors.white,
          );
          canvas.drawCircle(
            e + Offset(cosA * headR * 0.05, 0),
            headR * 0.13,
            Paint()..color = const Color(0xFF1F2A44),
          );
          canvas.drawCircle(
            e + Offset(-headR * 0.05, -headR * 0.07),
            headR * 0.055,
            Paint()..color = Colors.white,
          );
        }
      }

      // Expressive Eyebrows
      final browPaint = Paint()
        ..color = const Color(0xFF4A2C18)
        ..strokeWidth = math.max(1.5, headR * 0.11)
        ..strokeCap = StrokeCap.round;
      if (expression == CourierExpression.determined) {
        // Sharp battle-ready furrowed V-brows!
        canvas.drawLine(leftEye + Offset(-headR * 0.18, -headR * 0.28), leftEye + Offset(headR * 0.16, -headR * 0.16), browPaint);
        canvas.drawLine(rightEye + Offset(headR * 0.18, -headR * 0.28), rightEye + Offset(-headR * 0.16, -headR * 0.16), browPaint);
      } else if (expression == CourierExpression.focused) {
        canvas.drawLine(leftEye + Offset(-headR * 0.16, -headR * 0.24), leftEye + Offset(headR * 0.14, -headR * 0.20), browPaint);
        canvas.drawLine(rightEye + Offset(headR * 0.16, -headR * 0.24), rightEye + Offset(-headR * 0.14, -headR * 0.20), browPaint);
      } else if (expression == CourierExpression.alert) {
        canvas.drawLine(leftEye + Offset(-headR * 0.15, -headR * 0.32), leftEye + Offset(headR * 0.15, -headR * 0.32), browPaint);
        canvas.drawLine(rightEye + Offset(-headR * 0.15, -headR * 0.32), rightEye + Offset(headR * 0.15, -headR * 0.32), browPaint);
      } else if (expression == CourierExpression.worried) {
        // Drooping worried brows + tiny cyan sweat drop!
        canvas.drawLine(leftEye + Offset(-headR * 0.16, -headR * 0.18), leftEye + Offset(headR * 0.14, -headR * 0.28), browPaint);
        canvas.drawLine(rightEye + Offset(headR * 0.16, -headR * 0.18), rightEye + Offset(-headR * 0.14, -headR * 0.28), browPaint);
        canvas.drawOval(
          Rect.fromCenter(center: headCenter + Offset(headR * 0.72, -headR * 0.18), width: headR * 0.16, height: headR * 0.24),
          Paint()..color = const Color(0xFF38BDF8),
        );
      }

      // Rosy cheeks for smiling/excited/relaxed
      if (expression == CourierExpression.relaxed ||
          expression == CourierExpression.smiling ||
          expression == CourierExpression.excited) {
        final cheek = Paint()..color = const Color(0x55FF6B6B);
        canvas.drawCircle(leftEye + Offset(-headR * 0.16, headR * 0.22), headR * 0.12, cheek);
        canvas.drawCircle(rightEye + Offset(headR * 0.16, headR * 0.22), headR * 0.12, cheek);
      }

      // Expressive Mouth
      final mouthCenter = headCenter + Offset(lookX * 0.6, headR * 0.44);
      if (expression == CourierExpression.determined) {
        // Determined clenched grin / battle line
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: mouthCenter, width: headR * 0.38, height: headR * 0.14),
            const Radius.circular(3),
          ),
          Paint()..color = Colors.white,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: mouthCenter, width: headR * 0.38, height: headR * 0.14),
            const Radius.circular(3),
          ),
          Paint()
            ..color = const Color(0xFF6B3A2A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else if (expression == CourierExpression.alert) {
        canvas.drawCircle(mouthCenter, headR * 0.12, Paint()..color = const Color(0xFF6B3A2A));
      } else if (expression == CourierExpression.worried) {
        canvas.drawArc(
          Rect.fromCenter(center: mouthCenter + Offset(0, headR * 0.10), width: headR * 0.34, height: headR * 0.20),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          ink,
        );
      } else if (expression == CourierExpression.excited) {
        canvas.drawArc(
          Rect.fromCenter(center: mouthCenter - Offset(0, headR * 0.05), width: headR * 0.48, height: headR * 0.36),
          0.08,
          math.pi - 0.16,
          true,
          Paint()..color = const Color(0xFFE63946),
        );
      } else {
        // Warm smile (relaxed / focused / smiling)
        canvas.drawArc(
          Rect.fromCenter(center: mouthCenter - Offset(0, headR * 0.04), width: headR * 0.42, height: headR * 0.24),
          0.18,
          math.pi - 0.36,
          false,
          ink,
        );
      }
    }
  }

  /// Renders the Courier's articulated combat arms + animated Bow string pull / Blaster recoil / Orb!
  static void _drawCourierCombatArmsAndWeapon(
    Canvas canvas, {
    required double r,
    required CourierAnimSnapshot snap,
    required double faceDirX,
    required double armSwing,
  }) {
    final weapon = snap.activeAttackWeapon ?? snap.equippedWeapon!;
    final jacketColor = _courierJacketColor(snap.equippedWeapon);
    final handPaint = Paint()..color = const Color(0xFFFFD6B8);
    final outline = Paint()
      ..color = const Color(0xFF1F2A44)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.3, r * 0.065);

    canvas.save();
    canvas.translate(0, -r * 0.02);
    canvas.rotate(snap.facingAngle);

    if (weapon == WeaponType.bow) {
      // True Bow Draw & Release Animation!
      // aimBow (progress 0..0.35): right hand pulls string taut with arrow nocked!
      // releaseBow (progress 0.35..1.0): string snaps forward + slight recoil!
      final bool isAiming = snap.state == CourierAnimState.aimBow;
      final bool isReleasing = snap.state == CourierAnimState.releaseBow;
      final double drawPull = isAiming
          ? (snap.stateProgress / 0.35).clamp(0.25, 1.0)
          : (isReleasing ? (1.0 - ((snap.stateProgress - 0.35) / 0.65).clamp(0.0, 1.0)) * 0.2 : 0.08);
      final double bowX = r * (isAiming || isReleasing ? 0.92 : 0.74);

      // Extended Front Bow Arm reaching to bow grip
      canvas.drawLine(
        Offset(r * 0.22, r * 0.14),
        Offset(bowX, 0),
        Paint()
          ..color = jacketColor
          ..strokeWidth = r * 0.24
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(bowX, 0), r * 0.14, handPaint);
      canvas.drawCircle(Offset(bowX, 0), r * 0.14, outline);

      // Curved Fantasy Wood & Gold Bow
      final bowRect = Rect.fromCenter(
        center: Offset(bowX - r * 0.16, 0),
        width: r * 0.66,
        height: r * 1.25,
      );
      canvas.drawArc(
        bowRect,
        -math.pi * 0.44,
        math.pi * 0.88,
        false,
        Paint()
          ..color = const Color(0xFF8D5524)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.6, r * 0.14)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        bowRect,
        -math.pi * 0.36,
        math.pi * 0.72,
        false,
        Paint()
          ..color = const Color(0xFFFFC857)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, r * 0.05),
      );

      // Animated Bowstring pulling backward with rear hand!
      final topTip = Offset(bowX - r * 0.12, -r * 0.58);
      final botTip = Offset(bowX - r * 0.12, r * 0.58);
      final stringPullX = bowX - r * (0.14 + drawPull * 0.48);
      final pullPoint = Offset(stringPullX, 0);

      final stringPaint = Paint()
        ..color = const Color(0xFFFFF8E8)
        ..strokeWidth = math.max(1.3, r * 0.06);
      canvas.drawLine(topTip, pullPoint, stringPaint);
      canvas.drawLine(botTip, pullPoint, stringPaint);

      // Rear Drawing Arm physically pulling the bowstring!
      canvas.drawLine(
        Offset(r * 0.06, -r * 0.18),
        pullPoint,
        Paint()
          ..color = jacketColor
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(pullPoint, r * 0.13, handPaint);
      canvas.drawCircle(pullPoint, r * 0.13, outline);

      // Nocked Arrow visibly loaded on bowstring during Aim!
      if (isAiming) {
        canvas.drawLine(
          pullPoint,
          Offset(bowX + r * 0.38, 0),
          Paint()
            ..color = const Color(0xFF7A4424)
            ..strokeWidth = math.max(2.2, r * 0.09)
            ..strokeCap = StrokeCap.round,
        );
        final tip = Path()
          ..moveTo(bowX + r * 0.50, 0)
          ..lineTo(bowX + r * 0.28, -r * 0.12)
          ..lineTo(bowX + r * 0.28, r * 0.12)
          ..close();
        canvas.drawPath(tip, Paint()..color = const Color(0xFFFFC857));
      }
    } else if (weapon == WeaponType.energyBlaster) {
      final firing = snap.state == CourierAnimState.fireBlaster;
      final kick = firing ? math.sin(snap.stateProgress * math.pi) * r * 0.22 : 0.0;
      final gunX = r * 0.74 - kick;

      // Two-handed braced blaster arms
      canvas.drawLine(
        Offset(r * 0.14, r * 0.18),
        Offset(gunX - r * 0.1, r * 0.04),
        Paint()
          ..color = jacketColor
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(r * 0.10, -r * 0.18),
        Offset(gunX - r * 0.22, -r * 0.04),
        Paint()
          ..color = jacketColor
          ..strokeWidth = r * 0.20
          ..strokeCap = StrokeCap.round,
      );
      // Arcane Energy Blaster body
      final gunRect = Rect.fromCenter(center: Offset(gunX, 0), width: r * 0.74, height: r * 0.34);
      canvas.drawRRect(
        RRect.fromRectAndRadius(gunRect, Radius.circular(r * 0.10)),
        Paint()..color = const Color(0xFF7C3AED),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(gunRect, Radius.circular(r * 0.10)),
        outline,
      );
      canvas.drawCircle(Offset(gunX + r * 0.36, 0), r * 0.14, Paint()..color = const Color(0xFF38BDF8));

      // Muzzle flash directly at barrel tip on fire!
      if (firing && snap.stateProgress < 0.45) {
        canvas.drawCircle(
          Offset(gunX + r * 0.50, 0),
          r * 0.32,
          Paint()..color = const Color(0x9938BDF8),
        );
        canvas.drawCircle(
          Offset(gunX + r * 0.50, 0),
          r * 0.16,
          Paint()..color = Colors.white,
        );
      }
    } else if (weapon == WeaponType.freezeOrb || snap.state == CourierAnimState.castOrb) {
      final reach = r * (snap.state == CourierAnimState.castOrb ? 0.92 : 0.68);
      canvas.drawLine(
        Offset(r * 0.16, r * 0.14),
        Offset(reach, 0),
        Paint()
          ..color = jacketColor
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(reach, 0), r * 0.28, Paint()..color = const Color(0x5538BDF8));
      canvas.drawCircle(Offset(reach, 0), r * 0.18, Paint()..color = const Color(0xFF0EA5E9));
      canvas.drawCircle(Offset(reach - r * 0.05, -r * 0.05), r * 0.07, Paint()..color = Colors.white);
    } else {
      // Melee Push Strike animated swinging arm!
      final swing = snap.state == CourierAnimState.meleeSlash
          ? math.sin(snap.stateProgress * math.pi) * 1.45 - 0.7
          : armSwing * 0.35;
      canvas.rotate(swing);
      canvas.drawLine(
        Offset(r * 0.14, r * 0.16),
        Offset(r * 0.78, 0),
        Paint()
          ..color = jacketColor
          ..strokeWidth = r * 0.24
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(r * 0.80, 0), r * 0.16, handPaint);
      canvas.drawCircle(Offset(r * 0.80, 0), r * 0.16, outline);
    }

    canvas.restore();
  }

  // ===========================================================================
  // 2. DOCK WORKER — DISTINCT FOREMAN RIG (PEACEFUL WORKER + KNIFE DEFENDER)
  // ===========================================================================

  static void drawDockWorkerRig(
    Canvas canvas,
    Offset center,
    double r,
    DockWorkerAnimSnapshot snap,
  ) {
    canvas.save();

    final isCombat = snap.hasKnifeDrawn;
    final cosA = math.cos(snap.facingAngle);
    final faceDirX = cosA < -0.15 ? -1.0 : 1.0;

    // Horizontal loading stride shift when physically carrying food to the truck!
    double workShiftX = 0.0;
    if (snap.state == DockWorkerAnimState.carryingToTruck ||
        snap.state == DockWorkerAnimState.loadingTruck) {
      workShiftX = snap.stateProgress * r * 1.05;
    }

    final hurtKick = snap.state == DockWorkerAnimState.hurtRecoil
        ? -faceDirX * math.sin(snap.hurtRecoilProgress * math.pi) * r * 0.28
        : 0.0;

    canvas.translate(center.dx + workShiftX + hurtKick, center.dy);

    final isWalking = snap.state == DockWorkerAnimState.carryingToTruck ||
        snap.state == DockWorkerAnimState.advancing;
    final bob = snap.state == DockWorkerAnimState.celebrating
        ? math.sin(snap.elapsed * 12).abs() * r * 0.30
        : (isWalking
            ? math.sin(snap.walkCyclePhase).abs() * r * 0.15
            : math.sin(snap.elapsed * 3.0) * r * 0.03);

    // Ground contact shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.90), width: r * 1.56, height: r * 0.46),
      Paint()..color = const Color(0x3E1F2A44),
    );
    canvas.translate(0, -bob);

    // Body posture: bends forward when receiving food, athletic wide crouch in defendStance, twists during knife swing!
    double torsoLean = 0.0;
    if (snap.state == DockWorkerAnimState.receivingFood) {
      torsoLean = -0.18 * math.sin(snap.stateProgress * math.pi);
    } else if (snap.state == DockWorkerAnimState.knifeHorizontalSwing ||
        snap.state == DockWorkerAnimState.knifeCounterSlash) {
      torsoLean = faceDirX * (snap.stateProgress < 0.32 ? -0.18 : 0.24);
    } else if (snap.state == DockWorkerAnimState.hurtRecoil) {
      torsoLean = -faceDirX * 0.26;
    } else if (snap.state == DockWorkerAnimState.defendStance) {
      torsoLean = faceDirX * 0.10;
    }

    // --- A. STOCKY WORK LEGS & HEAVY BOOTS ---
    final legSpread = snap.state == DockWorkerAnimState.defendStance ? 0.30 : 0.23;
    final legSwing = isWalking ? math.sin(snap.walkCyclePhase) * 0.42 : 0.0;
    _drawHumanLeg(
      canvas,
      hip: Offset(-r * legSpread, r * 0.36),
      r: r * 1.05,
      swingAngle: legSwing,
      liftY: isWalking ? math.max(0.0, math.cos(snap.walkCyclePhase)) * r * 0.12 : 0.0,
      trouserColor: const Color(0xFF334155),
      bootColor: const Color(0xFF3E2723),
    );
    _drawHumanLeg(
      canvas,
      hip: Offset(r * legSpread, r * 0.36),
      r: r * 1.05,
      swingAngle: -legSwing,
      liftY: isWalking ? math.max(0.0, -math.cos(snap.walkCyclePhase)) * r * 0.12 : 0.0,
      trouserColor: const Color(0xFF334155),
      bootColor: const Color(0xFF3E2723),
    );

    canvas.save();
    canvas.rotate(torsoLean);

    // --- B. BROADER FOREMAN TORSO: CREAM SHIRT + HEAVY LEATHER WORK APRON + KNIFE SHEATH ---
    final torsoRect = Rect.fromCenter(
      center: Offset(0, r * 0.08),
      width: r * 1.14,
      height: r * 0.90,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(r * 0.32)),
      Paint()..color = const Color(0xFFFFF1D6), // Rolled-sleeve cream utility shirt
    );
    // Heavy Chestnut-Brown Leather Work Apron (visibly distinct from Courier!)
    final apronRect = Rect.fromCenter(
      center: Offset(0, r * 0.22),
      width: r * 0.86,
      height: r * 0.66,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(apronRect, Radius.circular(r * 0.16)),
      Paint()..color = const Color(0xFFB4652A),
    );
    // Apron pocket & utility belt
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, r * 0.30), width: r * 0.44, height: r * 0.20),
      Paint()..color = const Color(0xFF8C4A1C),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(r * 0.32)),
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, r * 0.075),
    );

    // Hip Knife Sheath (knife hilt tucked safely inside BEFORE escape; empty sheath AFTER drawn!)
    final sheathPos = Offset(-faceDirX * r * 0.46, r * 0.36);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: sheathPos, width: r * 0.18, height: r * 0.34),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF3E2723),
    );
    if (!isCombat) {
      // Subtle sheathed brass pommel only — NEVER drawn as a weapon before escape!
      canvas.drawCircle(
        sheathPos + Offset(0, -r * 0.18),
        r * 0.06,
        Paint()..color = const Color(0xFFD99A55),
      );
    }

    // --- C. DISTINCT FOREMAN HEAD (OLIVE WORK CAP + CHESTNUT MUSTACHE + EXPRESSIONS) ---
    _drawDockWorkerHead(
      canvas,
      headCenter: Offset(0, -r * 0.60),
      r: r,
      faceDirX: faceDirX,
      expression: snap.expression,
      elapsed: snap.elapsed,
    );

    // --- D. ARTICULATED WORK ARMS / TWO-HAND FOOD LOADING / KNIFE FIGHTING COMBO ---
    if (!isCombat) {
      _drawDockWorkerPeacefulArms(canvas, r, snap);
    } else {
      _drawDockWorkerCombatKnifeArms(canvas, r, snap, faceDirX);
    }

    canvas.restore(); // End torsoLean

    // Surprised exclamation bubble when monster breaks cage!
    if (snap.state == DockWorkerAnimState.surprised ||
        snap.state == DockWorkerAnimState.drawingKnife) {
      final badgePos = Offset(0, -r * 1.48);
      canvas.drawCircle(badgePos, r * 0.36, Paint()..color = const Color(0xFFFF4D6D));
      final tp = TextPainter(
        text: TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: math.max(10.0, r * 0.55),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, badgePos - Offset(tp.width / 2, tp.height / 2));
    }

    canvas.restore();
  }

  static void _drawDockWorkerHead(
    Canvas canvas, {
    required Offset headCenter,
    required double r,
    required double faceDirX,
    required DockWorkerExpression expression,
    required double elapsed,
  }) {
    final headR = r * 0.55;
    // Warmer tanned skin circle
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()..color = const Color(0xFFF3C69F),
    );
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, r * 0.07),
    );

    // Distinct Olive-Green Depot Work Cap with Brim & Brass Emblem
    canvas.drawArc(
      Rect.fromCenter(
        center: headCenter + Offset(0, -headR * 0.24),
        width: headR * 2.1,
        height: headR * 1.55,
      ),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF3E7C59),
    );
    // Forward cap visor brim
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter + Offset(faceDirX * headR * 0.28, -headR * 0.28),
        width: headR * 1.75,
        height: headR * 0.36,
      ),
      Paint()..color = const Color(0xFF26523A),
    );
    // Brass depot emblem on cap front
    canvas.drawCircle(
      headCenter + Offset(faceDirX * headR * 0.14, -headR * 0.62),
      headR * 0.16,
      Paint()..color = const Color(0xFFFFC857),
    );

    // Eyes & Bushy Eyebrows
    final eyeY = headCenter.dy + headR * 0.04;
    final leftEye = Offset(headCenter.dx - headR * 0.30, eyeY);
    final rightEye = Offset(headCenter.dx + headR * 0.30, eyeY);
    final ink = Paint()..color = const Color(0xFF1F2A44);
    final brow = Paint()
      ..color = const Color(0xFF5C3A21)
      ..strokeWidth = math.max(1.8, headR * 0.14)
      ..strokeCap = StrokeCap.round;

    if (expression == DockWorkerExpression.hurt) {
      final wince = Paint()
        ..color = const Color(0xFF1F2A44)
        ..strokeWidth = 1.6;
      canvas.drawLine(leftEye + Offset(-headR * 0.12, -headR * 0.08), leftEye + Offset(headR * 0.08, 0), wince);
      canvas.drawLine(leftEye + Offset(-headR * 0.12, headR * 0.08), leftEye + Offset(headR * 0.08, 0), wince);
      canvas.drawLine(rightEye + Offset(headR * 0.12, -headR * 0.08), rightEye + Offset(-headR * 0.08, 0), wince);
      canvas.drawLine(rightEye + Offset(headR * 0.12, headR * 0.08), rightEye + Offset(-headR * 0.08, 0), wince);
    } else {
      final eyeR = expression == DockWorkerExpression.surprised ? headR * 0.18 : headR * 0.14;
      for (final e in [leftEye, rightEye]) {
        canvas.drawCircle(e, eyeR, Paint()..color = Colors.white);
        canvas.drawCircle(e + Offset(faceDirX * headR * 0.04, 0), eyeR * 0.62, ink);
      }
      if (expression == DockWorkerExpression.focusedCombat ||
          expression == DockWorkerExpression.determinedStrike) {
        // Fierce combat V-brows!
        canvas.drawLine(leftEye + Offset(-headR * 0.18, -headR * 0.26), leftEye + Offset(headR * 0.14, -headR * 0.14), brow);
        canvas.drawLine(rightEye + Offset(headR * 0.18, -headR * 0.26), rightEye + Offset(-headR * 0.14, -headR * 0.14), brow);
      } else if (expression == DockWorkerExpression.surprised) {
        canvas.drawLine(leftEye + Offset(-headR * 0.16, -headR * 0.30), leftEye + Offset(headR * 0.14, -headR * 0.30), brow);
        canvas.drawLine(rightEye + Offset(-headR * 0.14, -headR * 0.30), rightEye + Offset(headR * 0.16, -headR * 0.30), brow);
      } else {
        canvas.drawLine(leftEye + Offset(-headR * 0.16, -headR * 0.20), leftEye + Offset(headR * 0.14, -headR * 0.22), brow);
        canvas.drawLine(rightEye + Offset(-headR * 0.14, -headR * 0.22), rightEye + Offset(headR * 0.16, -headR * 0.20), brow);
      }
    }

    // Friendly Chestnut Handlebar Mustache (makes Dock Worker instantly distinguishable!)
    final stacheY = headCenter.dy + headR * 0.34;
    final stache = Path()
      ..moveTo(headCenter.dx, stacheY - headR * 0.05)
      ..quadraticBezierTo(headCenter.dx - headR * 0.26, stacheY - headR * 0.14, headCenter.dx - headR * 0.44, stacheY + headR * 0.08)
      ..quadraticBezierTo(headCenter.dx - headR * 0.20, stacheY + headR * 0.16, headCenter.dx, stacheY + headR * 0.05)
      ..quadraticBezierTo(headCenter.dx + headR * 0.20, stacheY + headR * 0.16, headCenter.dx + headR * 0.44, stacheY + headR * 0.08)
      ..quadraticBezierTo(headCenter.dx + headR * 0.26, stacheY - headR * 0.14, headCenter.dx, stacheY - headR * 0.05)
      ..close();
    canvas.drawPath(stache, Paint()..color = const Color(0xFF6B3F22));

    // Mouth beneath mustache
    if (expression == DockWorkerExpression.surprised ||
        expression == DockWorkerExpression.determinedStrike) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx, stacheY + headR * 0.18), width: headR * 0.30, height: headR * 0.22),
        Paint()..color = const Color(0xFFB91C1C),
      );
    } else if (expression == DockWorkerExpression.smiling ||
        expression == DockWorkerExpression.celebrating ||
        expression == DockWorkerExpression.friendly) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(headCenter.dx, stacheY + headR * 0.10), width: headR * 0.36, height: headR * 0.20),
        0.15,
        math.pi - 0.3,
        false,
        Paint()
          ..color = const Color(0xFF4A2C18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  /// Renders the Dock Worker's real 2-hand food receiving, carrying & loading movements!
  static void _drawDockWorkerPeacefulArms(
    Canvas canvas,
    double r,
    DockWorkerAnimSnapshot snap,
  ) {
    const sleeve = Color(0xFFFFF1D6);
    const hand = Color(0xFFF3C69F);

    if (snap.state == DockWorkerAnimState.waving) {
      final waveAngle = -2.25 + math.sin(snap.elapsed * 9.0) * 0.42;
      _drawHumanArm(canvas, shoulder: Offset(-r * 0.50, -r * 0.06), r: r, angle: 0.22, sleeveColor: sleeve, handColor: hand);
      _drawHumanArm(canvas, shoulder: Offset(r * 0.50, -r * 0.06), r: r, angle: waveAngle, sleeveColor: sleeve, handColor: hand);
    } else if (snap.state == DockWorkerAnimState.receivingFood ||
        snap.state == DockWorkerAnimState.carryingToTruck ||
        snap.state == DockWorkerAnimState.loadingTruck) {
      // BOTH arms extend forward/upward physically holding the delivered food item!
      final lift = snap.state == DockWorkerAnimState.loadingTruck
          ? -r * 0.42 * snap.stateProgress
          : (snap.state == DockWorkerAnimState.receivingFood ? r * 0.06 : -r * 0.08);
      final reachX = snap.state == DockWorkerAnimState.receivingFood ? 0.0 : r * 0.48;
      final holdCenter = Offset(reachX, r * 0.05 + lift);

      // Left & Right arms gripping the food
      final armPaint = Paint()
        ..color = sleeve
        ..strokeWidth = r * 0.24
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(-r * 0.46, -r * 0.06), holdCenter + Offset(-r * 0.20, 0), armPaint);
      canvas.drawLine(Offset(r * 0.46, -r * 0.06), holdCenter + Offset(r * 0.20, 0), armPaint);

      // Actual delivered Food Item physically held between both hands!
      if (snap.carriedFoodType != null) {
        FoodIllustrator.drawFood(
          canvas,
          holdCenter,
          r * 0.34,
          snap.carriedFoodType!,
          showShadow: false,
        );
      }
      canvas.drawCircle(holdCenter + Offset(-r * 0.22, 0), r * 0.13, Paint()..color = hand);
      canvas.drawCircle(holdCenter + Offset(r * 0.22, 0), r * 0.13, Paint()..color = hand);
    } else if (snap.state == DockWorkerAnimState.closingCargo) {
      // Reaches both hands up to close truck door!
      _drawHumanArm(canvas, shoulder: Offset(-r * 0.48, -r * 0.06), r: r, angle: -2.4, sleeveColor: sleeve, handColor: hand);
      _drawHumanArm(canvas, shoulder: Offset(r * 0.48, -r * 0.06), r: r, angle: -1.8, sleeveColor: sleeve, handColor: hand);
    } else if (snap.state == DockWorkerAnimState.smilingAfterLoad) {
      // Happy thumbs-up pose!
      _drawHumanArm(canvas, shoulder: Offset(-r * 0.48, -r * 0.06), r: r, angle: 0.2, sleeveColor: sleeve, handColor: hand);
      _drawHumanArm(canvas, shoulder: Offset(r * 0.48, -r * 0.06), r: r, angle: -1.8, sleeveColor: sleeve, handColor: hand);
    } else {
      // Relaxed idle standing arms
      _drawHumanArm(canvas, shoulder: Offset(-r * 0.50, -r * 0.06), r: r, angle: 0.18, sleeveColor: sleeve, handColor: hand);
      _drawHumanArm(canvas, shoulder: Offset(r * 0.50, -r * 0.06), r: r, angle: -0.18, sleeveColor: sleeve, handColor: hand);
    }
  }

  /// Renders the Dock Worker's defensive stance, knife drawing, and 2-hit melee combo!
  static void _drawDockWorkerCombatKnifeArms(
    Canvas canvas,
    double r,
    DockWorkerAnimSnapshot snap,
    double faceDirX,
  ) {
    const sleeve = Color(0xFFFFF1D6);
    const hand = Color(0xFFF3C69F);

    // Off-hand defensive guard arm
    _drawHumanArm(
      canvas,
      shoulder: Offset(-faceDirX * r * 0.46, -r * 0.06),
      r: r,
      angle: snap.state == DockWorkerAnimState.surprised ? -2.5 : (-0.85 * faceDirX),
      sleeveColor: sleeve,
      handColor: hand,
    );

    // Dominant Knife Arm + Gleaming Stylized Fantasy Combat Knife!
    canvas.save();
    canvas.translate(faceDirX * r * 0.36, -r * 0.04);

    double armAngle;
    double knifeExtraRot = 0.0;
    bool drawTrail = false;
    bool isCounter = snap.state == DockWorkerAnimState.knifeCounterSlash;

    if (snap.state == DockWorkerAnimState.drawingKnife) {
      // Sweeps arm from hip sheath up into forward combat grip!
      armAngle = snap.facingAngle + (1.0 - snap.stateProgress) * 1.9 * faceDirX;
    } else if (snap.state == DockWorkerAnimState.knifeHorizontalSwing ||
        snap.state == DockWorkerAnimState.knifeCounterSlash) {
      final p = snap.stateProgress;
      final dir = isCounter ? -1.0 : 1.0;
      if (p < 0.32) {
        // Wind-up: pull arm far back!
        final w = p / 0.32;
        armAngle = snap.facingAngle - dir * (0.4 + w * 1.25);
      } else if (p < 0.68) {
        // Active Fast Slash Sweep across target!
        final s = (p - 0.32) / 0.36;
        armAngle = snap.facingAngle - dir * 1.65 + dir * (s * 2.85);
        knifeExtraRot = dir * 0.32;
        drawTrail = true;
      } else {
        // Follow-through -> return smoothly to defensive guard!
        final rec = (p - 0.68) / 0.32;
        armAngle = snap.facingAngle + dir * 1.20 * (1.0 - rec);
      }
    } else if (snap.state == DockWorkerAnimState.celebrating) {
      armAngle = -math.pi * 0.5;
    } else {
      // Active Combat Guard Stance (subtle defensive breathing bob)
      armAngle = snap.facingAngle - 0.25 * faceDirX + math.sin(snap.elapsed * 5.0) * 0.08;
    }

    canvas.rotate(armAngle);

    // Muscular forearm reaching forward to knife hilt
    canvas.drawLine(
      Offset.zero,
      Offset(r * 0.62, 0),
      Paint()
        ..color = sleeve
        ..strokeWidth = r * 0.24
        ..strokeCap = StrokeCap.round,
    );
    final handPos = Offset(r * 0.64, 0);
    canvas.drawCircle(handPos, r * 0.14, Paint()..color = hand);
    canvas.drawCircle(
      handPos,
      r * 0.14,
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Stylized Cartoon Fantasy Combat Knife attached directly to hand!
    canvas.save();
    canvas.translate(handPos.dx, handPos.dy);
    canvas.rotate(knifeExtraRot);

    // Hilt & Golden Crossguard
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(-r * 0.06, 0), width: r * 0.28, height: r * 0.14),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF6B3F22),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(r * 0.08, 0), width: r * 0.11, height: r * 0.40),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFC857),
    );

    // Curved Gleaming Silver-Cyan Fantasy Blade
    final blade = Path()
      ..moveTo(r * 0.13, -r * 0.13)
      ..lineTo(r * 0.78, -r * 0.05)
      ..lineTo(r * 0.98, 0.0)
      ..lineTo(r * 0.72, r * 0.14)
      ..lineTo(r * 0.13, r * 0.12)
      ..close();
    canvas.drawPath(blade, Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawPath(
      blade,
      Paint()
        ..color = const Color(0xFF0284C7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(r * 0.20, -r * 0.05),
      Offset(r * 0.78, -r * 0.02),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // Crisp Steel Slash Trail Arc during active strike frames!
    if (drawTrail) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * 1.12),
        isCounter ? -0.2 : -1.25,
        1.45,
        false,
        Paint()
          ..color = (isCounter ? const Color(0xCCFFC857) : const Color(0xCC38BDF8))
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.26
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.restore();
    canvas.restore();
  }

  // ===========================================================================
  // 3. GIANT DISTRICT BOSS — ARTICULATED 2.5D LIVING MONSTER RIG
  // ===========================================================================

  static void drawGiantBossRig(
    Canvas canvas,
    Offset center,
    double r,
    BossAnimSnapshot snap, {
    String? nameLabel,
  }) {
    canvas.save();

    final faceRight = math.cos(snap.facingAngle) >= -0.1;
    final dirX = faceRight ? 1.0 : -1.0;

    // Hurt Recoil physical knockback jolt!
    final recoilAmt = snap.hurtRecoilProgress > 0
        ? math.sin(snap.hurtRecoilProgress * math.pi) * r * 0.34
        : 0.0;
    canvas.translate(
      center.dx + snap.recoilDirX * recoilAmt,
      center.dy + snap.recoilDirY * recoilAmt,
    );

    final spec = snap.appearance;
    final palette = spec != null
        ? _BossPalette(
            bodyLight: Color(spec.bodyLightHex),
            bodyMid: Color(spec.bodyMidHex),
            bodyDark: Color(spec.bodyDarkHex),
            belly: Color(spec.bellyHex),
            glow: Color(spec.glowHex),
            armor: Color(spec.armorHex),
            horn: Color(spec.hornHex),
            claw: Color(spec.clawHex),
          )
        : _BossPalette.forType(snap.bossType);
    final wRatio = spec?.widthRatio ?? 1.0;
    final hRatio = spec?.heightRatio ?? 1.0;
    final isHitFlash = snap.hurtRecoilProgress > 0.45;
    final isRunning = snap.state == BossAnimState.run ||
        snap.state == BossAnimState.charging ||
        snap.state == BossAnimState.tireStrike;
    final isWalking = snap.state == BossAnimState.walk ||
        snap.state == BossAnimState.retreating;
    final isMoving = isRunning || isWalking;

    // Ground Contact Shadow
    if (!snap.isCaged) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, r * 0.92), width: r * 2.15, height: r * 0.62),
        Paint()..color = const Color(0x481A1024),
      );
    }

    // Menacing Enraged Aura on Charge / Windup / Low HP
    if ((snap.state == BossAnimState.charging ||
            snap.state == BossAnimState.windupCharge ||
            snap.state == BossAnimState.windupSlam ||
            snap.hpRatio <= 0.35) &&
        !snap.isCaged &&
        snap.state != BossAnimState.defeated) {
      canvas.drawCircle(
        Offset.zero,
        r * (1.28 + math.sin(snap.elapsed * 9.0).abs() * 0.12),
        Paint()..color = palette.glow.withOpacity(0.24),
      );
    }

    // Dynamic vertical stride bounce (stops when stunned/frozen/defeated!)
    final double bob;
    if (snap.state == BossAnimState.stunned ||
        snap.state == BossAnimState.frozen ||
        snap.state == BossAnimState.defeated) {
      bob = 0.0;
    } else if (isRunning) {
      bob = math.sin(snap.walkCyclePhase).abs() * r * 0.22;
    } else if (isWalking) {
      bob = math.sin(snap.walkCyclePhase).abs() * r * 0.11;
    } else {
      bob = math.sin(snap.elapsed * 3.4) * r * 0.04;
    }

    // Defeat slump scale
    if (snap.state == BossAnimState.defeated) {
      canvas.translate(0, r * 0.32);
      canvas.scale(1.06, 0.72);
    } else {
      canvas.translate(0, -bob);
    }

    // Posture / Body Language Lean (Section 6)
    double bodyLean = 0.0;
    double crouchY = 0.0;
    if (snap.isCaged) {
      final shape = snap.appearance?.bodyShape ?? MonsterBodyShape.hulkingBrute;
      switch (shape) {
        case MonsterBodyShape.wingedFlier:
          crouchY = -r * 0.28;
          bodyLean = math.sin(snap.elapsed * 1.5) * 0.10;
          break;
        case MonsterBodyShape.hornedStalker:
        case MonsterBodyShape.spikyHopper:
          crouchY = r * 0.16;
          bodyLean = dirX * 0.14;
          break;
        case MonsterBodyShape.lowCrawler:
        case MonsterBodyShape.mushroomFiend:
          crouchY = r * 0.22;
          bodyLean = math.sin(snap.elapsed * 1.2) * 0.08;
          break;
        case MonsterBodyShape.phantomWraith:
          crouchY = r * 0.10;
          bodyLean = math.sin(snap.elapsed * 2.0) * 0.20;
          break;
        default:
          crouchY = r * 0.05;
          bodyLean = math.sin(snap.elapsed * 0.8) * 0.04;
          break;
      }
    } else if (snap.state == BossAnimState.windupCharge ||
        snap.state == BossAnimState.windupTireAttack) {
      bodyLean = dirX * 0.26;
      crouchY = r * 0.16;
    } else if (snap.state == BossAnimState.charging ||
        snap.state == BossAnimState.run) {
      bodyLean = dirX * 0.20;
    } else if (snap.state == BossAnimState.windupBomb) {
      bodyLean = -dirX * 0.22 * snap.stateProgress; // Cocking back to throw!
    } else if (snap.state == BossAnimState.throwBomb) {
      bodyLean = dirX * 0.26 * (1.0 - snap.stateProgress); // Throwing follow-through!
    } else if (snap.state == BossAnimState.stunned ||
        snap.state == BossAnimState.hurtRecoil) {
      bodyLean = -dirX * 0.24; // Reeling / leaning back!
    }

    canvas.translate(0, crouchY);

    // --- A. ARTICULATED MUSCULAR MONSTER LEGS & 3-CLAWED FEET ---
    final legAmp = isRunning ? 0.56 : (isWalking ? 0.30 : 0.0);
    final strideSin = math.sin(snap.walkCyclePhase);
    final leftLift = isMoving ? math.max(0.0, math.cos(snap.walkCyclePhase)) * r * (isRunning ? 0.22 : 0.11) : 0.0;
    final rightLift = isMoving ? math.max(0.0, -math.cos(snap.walkCyclePhase)) * r * (isRunning ? 0.22 : 0.11) : 0.0;

    _drawMonsterLeg(
      canvas,
      hip: Offset(-r * 0.36, r * 0.36),
      r: r,
      angle: strideSin * legAmp,
      liftY: leftLift,
      color: isHitFlash ? Colors.white : palette.bodyDark,
      clawColor: palette.claw,
    );
    _drawMonsterLeg(
      canvas,
      hip: Offset(r * 0.36, r * 0.36),
      r: r,
      angle: -strideSin * legAmp,
      liftY: rightLift,
      color: isHitFlash ? Colors.white : palette.bodyDark,
      clawColor: palette.claw,
    );

    canvas.save();
    canvas.rotate(bodyLean);

    // --- B. BACK ARM & GIANT CLAW ---
    final armAngles = _computeBossArmAngles(snap, dirX, isMoving, isRunning);
    _drawMonsterArm(
      canvas,
      shoulder: Offset(-dirX * r * 0.66, -r * 0.22),
      r: r,
      angle: armAngles.backArm,
      color: isHitFlash ? Colors.white : palette.bodyDark,
      accentColor: palette.armor,
      clawColor: palette.claw,
      holdBomb: false,
      elapsed: snap.elapsed,
    );

    // --- C. MUSCULAR CHEST / TORSO (distinct per-level silhouette + breathing!) ---
    final breathFreq = snap.hpRatio <= 0.35 ? 8.0 : 3.8;
    final breathScale = 1.0 + math.sin(snap.elapsed * breathFreq) * 0.05;
    final torsoRect = Rect.fromCenter(
      center: Offset(0, -r * 0.02),
      width: r * 1.48 * wRatio * breathScale,
      height: r * 1.18 * hRatio,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(r * 0.44)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isHitFlash
              ? const [Colors.white, Color(0xFFFFCDD2)]
              : [palette.bodyLight, palette.bodyMid, palette.bodyDark],
        ).createShader(torsoRect),
    );
    // Muscular chest plates / belly ridges
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.08),
        width: r * 0.88 * wRatio,
        height: r * 0.68 * hRatio,
      ),
      Paint()..color = palette.belly,
    );
    // Per-level distinct skin texture / armor / spines!
    if (spec != null) {
      UniqueMonsterIllustrator.drawSkinPattern(
        canvas,
        torsoRect,
        r,
        spec.skinPattern,
        palette.glow,
        palette.bodyDark,
      );
    } else {
      _drawBossDistrictArmor(canvas, r, snap.bossType, palette);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, Radius.circular(r * 0.44)),
      Paint()
        ..color = const Color(0xFF120C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.0, r * 0.08),
    );

    // --- D. EXPRESSIVE ARTICULATED MONSTER HEAD, HORNS, EYES & HINGED JAW ---
    _drawBossHead(
      canvas,
      headCenter: Offset(dirX * r * 0.06, -r * 0.66 * hRatio),
      r: r,
      dirX: dirX,
      snap: snap,
      palette: palette,
      isHitFlash: isHitFlash,
    );

    // --- E. FRONT ATTACKING ARM + GIANT CLAW (+ LIVE BOMB IN HAND DURING THROW WINDUP!) ---
    _drawMonsterArm(
      canvas,
      shoulder: Offset(dirX * r * 0.64, -r * 0.22),
      r: r,
      angle: armAngles.frontArm,
      color: isHitFlash ? Colors.white : palette.bodyMid,
      accentColor: palette.armor,
      clawColor: palette.claw,
      holdBomb: snap.isHoldingBomb,
      elapsed: snap.elapsed,
    );

    // Fiery claw slash streak during Claw Strike / Tire Strike!
    if (snap.state == BossAnimState.clawStrike ||
        snap.state == BossAnimState.tireStrike) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(dirX * r * 0.55, 0), radius: r * 0.95),
        faceRight ? -0.9 : math.pi - 0.9,
        1.8,
        false,
        Paint()
          ..color = palette.glow.withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18
          ..strokeCap = StrokeCap.round,
      );
    }

    // Boss Study Signature Tells:
    // 1. Thorn Ravager jagged bramble spines along back
    final isThorn = (snap.appearance?.title.toLowerCase().contains('thorn') ?? false) ||
        snap.bossType == DistrictBossType.orchardThornBeast;
    if (isThorn) {
      final thornPaint = Paint()..color = palette.claw;
      for (int i = 0; i < 3; i++) {
        final tx = -dirX * r * (0.35 + i * 0.16);
        final ty = -r * (0.30 + i * 0.12);
        final thornPath = Path()
          ..moveTo(tx, ty)
          ..lineTo(tx - dirX * r * 0.20, ty - r * 0.18)
          ..lineTo(tx - dirX * r * 0.08, ty + r * 0.08)
          ..close();
        canvas.drawPath(thornPath, thornPaint);
      }
    }

    // 2. Lantern Leviathan bioluminescent swaying lure
    final isLantern = (snap.appearance?.title.toLowerCase().contains('lantern') ?? false) ||
        (snap.appearance?.title.toLowerCase().contains('leviathan') ?? false);
    if (isLantern) {
      final stalkTip = Offset(dirX * r * 0.45, -r * 1.15 + math.sin(snap.elapsed * 3.0) * r * 0.08);
      canvas.drawLine(
        Offset(dirX * r * 0.10, -r * 0.85),
        stalkTip,
        Paint()
          ..color = palette.armor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(stalkTip, r * 0.22, Paint()..color = const Color(0x5500E5FF));
      canvas.drawCircle(stalkTip, r * 0.11, Paint()..color = const Color(0xFFE0F7FA));
    }

    // 3. Ironbell Colossus steam release puffing during recovery / idle
    final isIronbell = (snap.appearance?.title.toLowerCase().contains('iron') ?? false) ||
        (snap.appearance?.title.toLowerCase().contains('colossus') ?? false) ||
        snap.bossType == DistrictBossType.marketArmoredBrute;
    if (isIronbell && (snap.state == BossAnimState.idle || snap.hpRatio <= 0.35)) {
      final steamPaint = Paint()..color = const Color(0x66FFFFFF);
      for (int i = 0; i < 3; i++) {
        final steamPhase = (snap.elapsed * 3.5 + i * 0.33) % 1.0;
        final sy = -r * 0.45 - steamPhase * r * 0.75;
        final sx = dirX * r * 0.35 + (i - 1) * r * 0.15;
        final sRad = r * (0.12 + steamPhase * 0.22);
        canvas.drawCircle(Offset(sx, sy), sRad, steamPaint);
      }
    }

    canvas.restore(); // End bodyLean

    // --- F. STATUS OVERLAYS (BOSS SHIELD, FREEZE PRISM, STUN STARS, HP BAR) ---
    if (snap.hasShield) {
      canvas.drawCircle(Offset.zero, r * 1.42, Paint()..color = const Color(0x2EA855F7));
      canvas.drawCircle(
        Offset.zero,
        r * 1.42,
        Paint()
          ..color = const Color(0xDD9333EA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2,
      );
    }

    if (snap.state == BossAnimState.frozen) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 2.15, height: r * 2.25),
          Radius.circular(r * 0.34),
        ),
        Paint()..color = const Color(0x6638BDF8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 2.15, height: r * 2.25),
          Radius.circular(r * 0.34),
        ),
        Paint()
          ..color = const Color(0xEEBAE6FD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }

    if (snap.state == BossAnimState.stunned) {
      for (int i = 0; i < 3; i++) {
        final a = snap.elapsed * 5.2 + i * (math.pi * 2 / 3);
        final sx = math.cos(a) * r * 0.92;
        final sy = -r * 1.32 + math.sin(a) * r * 0.24;
        canvas.drawCircle(Offset(sx, sy), r * 0.15, Paint()..color = const Color(0xFFFFC857));
      }
    }

    // Floating Boss HP Bar & Name above head during Road Battle
    if (!snap.isCaged && snap.state != BossAnimState.defeated) {
      final barW = r * 2.45;
      final barH = math.max(5.5, r * 0.22);
      final barRect = Rect.fromCenter(
        center: Offset(0, -r * 1.56),
        width: barW,
        height: barH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        Paint()..color = const Color(0xDD1F2937),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            barRect.left + 1,
            barRect.top + 1,
            math.max(0.0, (barRect.width - 2) * snap.hpRatio.clamp(0.0, 1.0)),
            barRect.height - 2,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFFF4D6D),
      );
      if (nameLabel != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: nameLabel,
            style: TextStyle(
              color: const Color(0xFF1F2A44),
              fontSize: math.max(9.0, r * 0.32),
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.white, blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-tp.width / 2, barRect.top - tp.height - 1));
      }
    }

    canvas.restore();
  }

  static ({double backArm, double frontArm}) _computeBossArmAngles(
    BossAnimSnapshot snap,
    double dirX,
    bool isMoving,
    bool isRunning,
  ) {
    final p = snap.stateProgress;
    switch (snap.state) {
      case BossAnimState.windupSlam:
      case BossAnimState.specialCast:
        // Hoist BOTH giant arms high overhead!
        return (backArm: -2.45 - p * 0.35, frontArm: -0.68 + p * 0.35);
      case BossAnimState.groundSlam:
        // Slam BOTH arms violently downward!
        return (backArm: 1.95, frontArm: 1.20);
      case BossAnimState.windupBomb:
        // Cock throwing arm high & wide outward holding the live sparking bomb cleanly beside head!
        return (backArm: dirX > 0 ? 2.25 : 0.9, frontArm: dirX > 0 ? -0.72 : -2.42);
      case BossAnimState.throwBomb:
        // Whip throwing arm forward into follow-through!
        return (backArm: 1.8, frontArm: dirX > 0 ? 0.25 : math.pi - 0.25);
      case BossAnimState.windupClaw:
      case BossAnimState.windupTireAttack:
        return (backArm: 2.0, frontArm: dirX > 0 ? -1.45 : -1.7);
      case BossAnimState.clawStrike:
      case BossAnimState.tireStrike:
        return (backArm: 1.8, frontArm: dirX > 0 ? 0.72 : math.pi - 0.72);
      case BossAnimState.windupCharge:
        return (backArm: 2.3, frontArm: 0.85);
      case BossAnimState.hurtRecoil:
      case BossAnimState.stunned:
        return (backArm: -2.1, frontArm: -1.0);
      case BossAnimState.cagedIdle:
      case BossAnimState.breakingCage:
        final rattle = math.sin(snap.elapsed * 18.0) * 0.25;
        final shape = snap.appearance?.bodyShape ?? MonsterBodyShape.hulkingBrute;
        switch (shape) {
          case MonsterBodyShape.wingedFlier:
            final wingFlex = math.sin(snap.elapsed * 2.8) * 0.35;
            return (
              backArm: -1.95 + wingFlex + rattle * 0.4,
              frontArm: -1.95 - wingFlex - rattle * 0.4,
            );
          case MonsterBodyShape.lowCrawler:
            return (backArm: -2.25 + rattle * 0.35, frontArm: 0.45 - rattle);
          case MonsterBodyShape.phantomWraith:
            final coil = math.sin(snap.elapsed * 2.2) * 0.35;
            return (backArm: 0.25 + coil, frontArm: -0.65 - coil + rattle);
          case MonsterBodyShape.spikyHopper:
          case MonsterBodyShape.hornedStalker:
            final scratch = math.sin(snap.elapsed * 24.0) * 0.45;
            return (backArm: 0.95 + scratch, frontArm: 0.95 - scratch);
          case MonsterBodyShape.armoredJuggernaut:
          case MonsterBodyShape.hulkingBrute:
          case MonsterBodyShape.cyclopsOgre:
          default:
            return (backArm: 0.72 + rattle, frontArm: -0.72 - rattle);
        }
      default:
        if (isMoving) {
          final swing = math.sin(snap.walkCyclePhase) * (isRunning ? 0.85 : 0.45);
          return (backArm: 1.57 + swing, frontArm: 1.57 - swing);
        }
        final idleFlex = math.sin(snap.elapsed * 3.8) * 0.14;
        return (backArm: 1.92 + idleFlex, frontArm: 1.22 - idleFlex);
    }
  }

  static void _drawBossHead(
    Canvas canvas, {
    required Offset headCenter,
    required double r,
    required double dirX,
    required BossAnimSnapshot snap,
    required _BossPalette palette,
    required bool isHitFlash,
  }) {
    final headR = r * 0.56;
    final jawOpen = (snap.expression == BossExpression.furiousRoar ||
            snap.expression == BossExpression.attackRoar ||
            snap.expression == BossExpression.exhaustedLowHp ||
            snap.state == BossAnimState.breakingCage)
        ? 1.0
        : (snap.expression == BossExpression.painRecoil ? 0.65 : 0.22);

    // Cranium
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: headR * 2.15, height: headR * 1.75),
      Paint()..color = isHitFlash ? Colors.white : palette.bodyMid,
    );
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: headR * 2.15, height: headR * 1.75),
      Paint()
        ..color = const Color(0xFF120C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.8, r * 0.07),
    );

    // Distinct Per-Level Horns / Crown / Antlers / Rhino Horn / Blade Crest!
    final spec = snap.appearance;
    if (spec != null) {
      UniqueMonsterIllustrator.drawHornCrest(
        canvas,
        headCenter: headCenter,
        headR: headR,
        hornStyle: spec.hornStyle,
        hornColor: palette.horn,
        glowColor: palette.glow,
      );
      UniqueMonsterIllustrator.drawMonsterEyes(
        canvas,
        headCenter: headCenter + Offset(dirX * headR * 0.06, -headR * 0.08),
        headR: headR,
        eyeCount: spec.eyeCount,
        dirX: dirX,
        glowColor: palette.glow,
        isPain: snap.expression == BossExpression.painRecoil,
        isStunned: snap.expression == BossExpression.dizzyStunned,
        isAggressive: snap.expression != BossExpression.defeatedWeak,
      );
      UniqueMonsterIllustrator.drawMonsterMouth(
        canvas,
        mouthCenter: Offset(headCenter.dx + dirX * headR * 0.05, headCenter.dy + headR * 0.40),
        headR: headR,
        mouthStyle: spec.mouthStyle,
        jawOpen: jawOpen,
        clawColor: palette.claw,
      );
      return;
    }

    // Fallback: District Horns / Eyes / Fangs when spec is omitted
    _drawBossHeadCrest(canvas, headCenter, headR, snap.bossType, palette);

    // Expressive Glowing Monster Eyes
    final eyeY = headCenter.dy - headR * 0.12;
    final leftEye = Offset(headCenter.dx - headR * 0.42 + dirX * headR * 0.08, eyeY);
    final rightEye = Offset(headCenter.dx + headR * 0.42 + dirX * headR * 0.08, eyeY);

    if (snap.expression == BossExpression.dizzyStunned) {
      // Swirling Dizzy Spiral Eyes!
      final swirl = Paint()
        ..color = const Color(0xFFFFC857)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      for (final e in [leftEye, rightEye]) {
        canvas.drawCircle(e, headR * 0.22, Paint()..color = const Color(0xFF1F2937));
        canvas.drawCircle(e, headR * 0.16, swirl);
        canvas.drawCircle(e, headR * 0.07, swirl);
      }
    } else if (snap.expression == BossExpression.painRecoil) {
      // Winced Pain '> <' Eyes!
      final wince = Paint()
        ..color = palette.glow
        ..strokeWidth = math.max(2.2, headR * 0.16)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftEye + Offset(-headR * 0.18, -headR * 0.14), leftEye + Offset(headR * 0.14, 0), wince);
      canvas.drawLine(leftEye + Offset(-headR * 0.18, headR * 0.14), leftEye + Offset(headR * 0.14, 0), wince);
      canvas.drawLine(rightEye + Offset(headR * 0.18, -headR * 0.14), rightEye + Offset(-headR * 0.14, 0), wince);
      canvas.drawLine(rightEye + Offset(headR * 0.18, headR * 0.14), rightEye + Offset(-headR * 0.14, 0), wince);
    } else if (snap.expression == BossExpression.defeatedWeak) {
      final xPaint = Paint()
        ..color = const Color(0xFF94A3B8)
        ..strokeWidth = 2.2;
      for (final e in [leftEye, rightEye]) {
        canvas.drawLine(e + Offset(-headR * 0.14, -headR * 0.14), e + Offset(headR * 0.14, headR * 0.14), xPaint);
        canvas.drawLine(e + Offset(headR * 0.14, -headR * 0.14), e + Offset(-headR * 0.14, headR * 0.14), xPaint);
      }
    } else {
      // Fierce Glowing Eyes + Angry Angled Eyebrow Ridges!
      for (final e in [leftEye, rightEye]) {
        canvas.drawCircle(e, headR * 0.28, Paint()..color = palette.glow.withOpacity(0.35));
        canvas.drawOval(
          Rect.fromCenter(center: e, width: headR * 0.34, height: headR * 0.24),
          Paint()..color = palette.glow,
        );
        canvas.drawCircle(e + Offset(dirX * headR * 0.05, 0), headR * 0.08, Paint()..color = Colors.white);
      }
      final browPaint = Paint()
        ..color = const Color(0xFF120C1C)
        ..strokeWidth = math.max(2.4, headR * 0.18)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(leftEye + Offset(-headR * 0.22, -headR * 0.24), leftEye + Offset(headR * 0.20, -headR * 0.06), browPaint);
      canvas.drawLine(rightEye + Offset(headR * 0.22, -headR * 0.24), rightEye + Offset(-headR * 0.20, -headR * 0.06), browPaint);
    }

    // Hinged Lower Jaw & Sharp White Fangs!
    final mouthCenter = Offset(headCenter.dx + dirX * headR * 0.05, headCenter.dy + headR * 0.42);
    final mouthH = headR * (0.28 + jawOpen * 0.42);
    final mouthW = headR * (1.05 + jawOpen * 0.22);
    canvas.drawOval(
      Rect.fromCenter(center: mouthCenter, width: mouthW, height: mouthH),
      Paint()..color = const Color(0xFF3A0716),
    );
    // Crimson roaring throat inner glow
    if (jawOpen > 0.5) {
      canvas.drawOval(
        Rect.fromCenter(center: mouthCenter + Offset(0, mouthH * 0.08), width: mouthW * 0.65, height: mouthH * 0.55),
        Paint()..color = const Color(0xFFE63946),
      );
    }
    // Sharp upper & lower fangs!
    final fangPaint = Paint()..color = Colors.white;
    for (int f = -2; f <= 2; f++) {
      final fx = mouthCenter.dx + f * mouthW * 0.18;
      final upperFang = Path()
        ..moveTo(fx - headR * 0.08, mouthCenter.dy - mouthH * 0.42)
        ..lineTo(fx, mouthCenter.dy - mouthH * 0.08)
        ..lineTo(fx + headR * 0.08, mouthCenter.dy - mouthH * 0.42)
        ..close();
      canvas.drawPath(upperFang, fangPaint);
      if (jawOpen > 0.4 && f.abs() == 1) {
        final lowerFang = Path()
          ..moveTo(fx - headR * 0.08, mouthCenter.dy + mouthH * 0.44)
          ..lineTo(fx, mouthCenter.dy + mouthH * 0.10)
          ..lineTo(fx + headR * 0.08, mouthCenter.dy + mouthH * 0.44)
          ..close();
        canvas.drawPath(lowerFang, fangPaint);
      }
    }
  }

  static void _drawBossDistrictArmor(
    Canvas canvas,
    double r,
    DistrictBossType type,
    _BossPalette p,
  ) {
    if (type == DistrictBossType.marketArmoredBrute ||
        type == DistrictBossType.cityGrandGuardian) {
      // Heavy metallic shoulder pauldrons!
      for (final sx in const [-0.66, 0.66]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(sx * r, -r * 0.26), width: r * 0.52, height: r * 0.38),
          Paint()..color = p.armor,
        );
      }
    } else if (type == DistrictBossType.orchardThornBeast) {
      // Jagged crimson back thorns
      for (final sx in const [-0.52, 0.0, 0.52]) {
        final spike = Path()
          ..moveTo(sx * r - r * 0.14, -r * 0.46)
          ..lineTo(sx * r, -r * 0.88)
          ..lineTo(sx * r + r * 0.14, -r * 0.46)
          ..close();
        canvas.drawPath(spike, Paint()..color = p.glow);
      }
    }
  }

  static void _drawBossHeadCrest(
    Canvas canvas,
    Offset headCenter,
    double headR,
    DistrictBossType type,
    _BossPalette p,
  ) {
    if (type == DistrictBossType.cityGrandGuardian) {
      // Gleaming Golden Crown!
      final crown = Path()
        ..moveTo(headCenter.dx - headR * 0.65, headCenter.dy - headR * 0.65)
        ..lineTo(headCenter.dx - headR * 0.52, headCenter.dy - headR * 1.28)
        ..lineTo(headCenter.dx - headR * 0.18, headCenter.dy - headR * 0.90)
        ..lineTo(headCenter.dx, headCenter.dy - headR * 1.42)
        ..lineTo(headCenter.dx + headR * 0.18, headCenter.dy - headR * 0.90)
        ..lineTo(headCenter.dx + headR * 0.52, headCenter.dy - headR * 1.28)
        ..lineTo(headCenter.dx + headR * 0.65, headCenter.dy - headR * 0.65)
        ..close();
      canvas.drawPath(crown, Paint()..color = const Color(0xFFFFC857));
    } else {
      // Sweeping Horns (bigger on Valley Horned Titan!)
      final hornScale = type == DistrictBossType.valleyHornedTitan ? 1.35 : 1.0;
      final hornPaint = Paint()
        ..color = p.horn
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.0, headR * 0.24)
        ..strokeCap = StrokeCap.round;
      final lHorn = Path()
        ..moveTo(headCenter.dx - headR * 0.58, headCenter.dy - headR * 0.50)
        ..quadraticBezierTo(
          headCenter.dx - headR * 1.25 * hornScale,
          headCenter.dy - headR * 0.80,
          headCenter.dx - headR * 0.92 * hornScale,
          headCenter.dy - headR * 1.35 * hornScale,
        );
      final rHorn = Path()
        ..moveTo(headCenter.dx + headR * 0.58, headCenter.dy - headR * 0.50)
        ..quadraticBezierTo(
          headCenter.dx + headR * 1.25 * hornScale,
          headCenter.dy - headR * 0.80,
          headCenter.dx + headR * 0.92 * hornScale,
          headCenter.dy - headR * 1.35 * hornScale,
        );
      canvas.drawPath(lHorn, hornPaint);
      canvas.drawPath(rHorn, hornPaint);
    }
  }

  static void _drawMonsterLeg(
    Canvas canvas, {
    required Offset hip,
    required double r,
    required double angle,
    required double liftY,
    required Color color,
    required Color clawColor,
  }) {
    canvas.save();
    canvas.translate(hip.dx, hip.dy - liftY);
    canvas.rotate(angle);
    // Heavy muscular thigh + calf
    final legRect = Rect.fromLTWH(-r * 0.20, 0, r * 0.40, r * 0.54);
    canvas.drawRRect(
      RRect.fromRectAndRadius(legRect, Radius.circular(r * 0.16)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(legRect, Radius.circular(r * 0.16)),
      Paint()
        ..color = const Color(0xFF120C1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // 3 sharp foot claws
    for (final cx in const [-0.14, 0.0, 0.14]) {
      canvas.drawCircle(
        Offset(cx * r, r * 0.54),
        r * 0.075,
        Paint()..color = clawColor,
      );
    }
    canvas.restore();
  }

  static void _drawMonsterArm(
    Canvas canvas, {
    required Offset shoulder,
    required double r,
    required double angle,
    required Color color,
    required Color accentColor,
    required Color clawColor,
    required bool holdBomb,
    required double elapsed,
  }) {
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);

    // Muscular upper & forearm
    final armLen = r * 0.86;
    canvas.drawLine(
      Offset.zero,
      Offset(armLen, 0),
      Paint()
        ..color = color
        ..strokeWidth = r * 0.34
        ..strokeCap = StrokeCap.round,
    );
    // Forearm bracer band
    canvas.drawCircle(Offset(armLen * 0.65, 0), r * 0.17, Paint()..color = accentColor);

    // Giant clawed fist
    final fist = Offset(armLen, 0);
    canvas.drawCircle(fist, r * 0.22, Paint()..color = color);
    for (final off in const [-0.15, 0.0, 0.15]) {
      final claw = Path()
        ..moveTo(fist.dx + r * 0.12, off * r - r * 0.06)
        ..lineTo(fist.dx + r * 0.40, off * r)
        ..lineTo(fist.dx + r * 0.12, off * r + r * 0.06)
        ..close();
      canvas.drawPath(claw, Paint()..color = clawColor);
    }

    // LIVE SMOKING FANTASY BOMB VISIBLY HELD IN BOSS'S THROWING CLAW!
    if (holdBomb) {
      final bombPos = fist + Offset(r * 0.24, -r * 0.10);
      canvas.drawCircle(bombPos, r * 0.30, Paint()..color = const Color(0xFF1F2937));
      canvas.drawCircle(bombPos + Offset(-r * 0.08, -r * 0.08), r * 0.09, Paint()..color = const Color(0xFF64748B));
      final sparkPulse = 1.0 + math.sin(elapsed * 26.0) * 0.28;
      canvas.drawCircle(bombPos + Offset(r * 0.18, -r * 0.26), r * 0.14 * sparkPulse, Paint()..color = const Color(0xFFFFC857));
      canvas.drawCircle(bombPos + Offset(r * 0.18, -r * 0.26), r * 0.07, Paint()..color = const Color(0xFFFF4D6D));
    }

    canvas.restore();
  }

  // ===========================================================================
  // SHARED ARTICULATED HUMAN LIMB HELPERS
  // ===========================================================================

  static void _drawHumanLeg(
    Canvas canvas, {
    required Offset hip,
    required double r,
    required double swingAngle,
    required double liftY,
    required Color trouserColor,
    required Color bootColor,
  }) {
    canvas.save();
    canvas.translate(hip.dx, hip.dy - liftY);
    canvas.rotate(swingAngle);

    // Trouser leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-r * 0.14, 0, r * 0.28, r * 0.44),
        Radius.circular(r * 0.12),
      ),
      Paint()..color = trouserColor,
    );
    // Boot
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.48), width: r * 0.36, height: r * 0.22),
      Paint()..color = bootColor,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.48), width: r * 0.36, height: r * 0.22),
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  static void _drawHumanArm(
    Canvas canvas, {
    required Offset shoulder,
    required double r,
    required double angle,
    required Color sleeveColor,
    required Color handColor,
  }) {
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);

    canvas.drawLine(
      Offset.zero,
      Offset(0, r * 0.44),
      Paint()
        ..color = sleeveColor
        ..strokeWidth = r * 0.22
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(0, r * 0.48), r * 0.13, Paint()..color = handColor);
    canvas.drawCircle(
      Offset(0, r * 0.48),
      r * 0.13,
      Paint()
        ..color = const Color(0xFF1F2A44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }
}

class _BossPalette {
  final Color bodyLight;
  final Color bodyMid;
  final Color bodyDark;
  final Color belly;
  final Color glow;
  final Color armor;
  final Color horn;
  final Color claw;

  const _BossPalette({
    required this.bodyLight,
    required this.bodyMid,
    required this.bodyDark,
    required this.belly,
    required this.glow,
    required this.armor,
    required this.horn,
    required this.claw,
  });

  static _BossPalette forType(DistrictBossType type) {
    switch (type) {
      case DistrictBossType.orchardThornBeast:
        return const _BossPalette(
          bodyLight: Color(0xFF3A7D44),
          bodyMid: Color(0xFF23532B),
          bodyDark: Color(0xFF14331A),
          belly: Color(0xFF538D4E),
          glow: Color(0xFFFF595E),
          armor: Color(0xFF8D5524),
          horn: Color(0xFFFFC857),
          claw: Color(0xFFFFF3DA),
        );
      case DistrictBossType.marketArmoredBrute:
        return const _BossPalette(
          bodyLight: Color(0xFF7F1D1D),
          bodyMid: Color(0xFF450A0A),
          bodyDark: Color(0xFF1F1218),
          belly: Color(0xFF991B1B),
          glow: Color(0xFFFF9F1C),
          armor: Color(0xFF94A3B8),
          horn: Color(0xFFE2E8F0),
          claw: Color(0xFFFFE4B5),
        );
      case DistrictBossType.forestShadowBeast:
        return const _BossPalette(
          bodyLight: Color(0xFF2D4A3E),
          bodyMid: Color(0xFF182C25),
          bodyDark: Color(0xFF0D1B17),
          belly: Color(0xFF3E6B59),
          glow: Color(0xFF84CC16),
          armor: Color(0xFF4C1D95),
          horn: Color(0xFFA3E635),
          claw: Color(0xFFE2E8F0),
        );
      case DistrictBossType.valleyHornedTitan:
        return const _BossPalette(
          bodyLight: Color(0xFF581C87),
          bodyMid: Color(0xFF3B0764),
          bodyDark: Color(0xFF1E0836),
          belly: Color(0xFF6B21A8),
          glow: Color(0xFFF43F5E),
          armor: Color(0xFF475569),
          horn: Color(0xFFD946EF),
          claw: Color(0xFFFCE7F3),
        );
      case DistrictBossType.cityGrandGuardian:
        return const _BossPalette(
          bodyLight: Color(0xFF334155),
          bodyMid: Color(0xFF1E293B),
          bodyDark: Color(0xFF0F172A),
          belly: Color(0xFF475569),
          glow: Color(0xFFFFC857),
          armor: Color(0xFFD97706),
          horn: Color(0xFFFFC857),
          claw: Color(0xFFFFF8E8),
        );
    }
  }
}

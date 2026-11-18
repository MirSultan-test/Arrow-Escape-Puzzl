import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/maze/delivery_state.dart';
import '../../models/maze/monster.dart';
import '../../models/maze/truck_defense_models.dart';
import '../../services/sprite_atlas.dart';
import 'character_illustrator.dart';

/// Professional 2.5D fantasy illustrator for V3.3 Monster Cage,
/// 5 Distinct District Giant Bosses, Combat-Knife Dock Worker Ally,
/// and Smoothly Rotating Winding-Road Delivery Truck.
class BossCageIllustrator {
  BossCageIllustrator._();

  /// Renders the reinforced fantasy Monster Containment Cage beside the Dock
  /// (locked, rattling, lock-breaking, door-opening, or broken empty cage).
  static void drawMonsterCage(
    Canvas canvas,
    Rect cageRect, {
    required BossCageState cageState,
    required DistrictBossType bossType,
    required double shakeIntensity,
    required double animPhase,
    required double elapsed,
    bool showBossInside = true,
  }) {
    canvas.save();

    final shakeX = shakeIntensity != 0.0
        ? math.sin(elapsed * 45.0) * 3.5 * shakeIntensity.abs()
        : 0.0;
    final shakeY = shakeIntensity != 0.0
        ? math.cos(elapsed * 52.0) * 1.6 * shakeIntensity.abs()
        : 0.0;
    canvas.translate(shakeX, shakeY);

    final w = cageRect.width;
    final h = cageRect.height;

    // 1. Ground shadow & subtle warning red/amber containment glow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        cageRect.shift(const Offset(0, 4)),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0x381A1024),
    );

    if (cageState != BossCageState.escaped) {
      final glowPulse = 0.22 + math.sin(elapsed * 4.5).abs() * 0.22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(cageRect.inflate(3.5), const Radius.circular(12)),
        Paint()
          ..color = Color(bossType.accentColorHex).withOpacity(
            cageState == BossCageState.rattling ||
                    cageState == BossCageState.lockBreaking
                ? 0.55
                : glowPulse,
          ),
      );
    }

    // 2. Reinforced steel floor deck & dark interior recess
    canvas.drawRRect(
      RRect.fromRectAndRadius(cageRect, const Radius.circular(9)),
      Paint()..color = const Color(0xFF1F2633),
    );

    // Caution yellow-black warning stripe strip along the base
    final stripeRect = Rect.fromLTWH(
      cageRect.left + 3,
      cageRect.bottom - math.max(5.5, h * 0.14),
      w - 6,
      math.max(4.5, h * 0.11),
    );
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(stripeRect, const Radius.circular(3)),
    );
    canvas.drawRect(stripeRect, Paint()..color = const Color(0xFFFACC15));
    final stripePaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..strokeWidth = 4.0;
    for (double x = stripeRect.left - 10; x < stripeRect.right + 14; x += 10) {
      canvas.drawLine(
        Offset(x, stripeRect.bottom + 2),
        Offset(x + 6, stripeRect.top - 2),
        stripePaint,
      );
    }
    canvas.restore();

    // 3. Back interior iron bars
    final backBarPaint = Paint()
      ..color = const Color(0xFF374151)
      ..strokeWidth = math.max(1.8, w * 0.036);
    for (int i = 1; i <= 4; i++) {
      final bx = cageRect.left + w * (i / 5.0);
      canvas.drawLine(
        Offset(bx, cageRect.top + 4),
        Offset(bx, cageRect.bottom - 5),
        backBarPaint,
      );
    }

    // 4. Giant Boss visible INSIDE the cage (before escaping!)
    if (showBossInside &&
        cageState != BossCageState.escaped &&
        cageState != BossCageState.doorOpening) {
      final shiftX = math.sin(animPhase * 0.7) * w * 0.06;
      final shiftY = math.sin(animPhase * 1.3).abs() * h * 0.04;
      final bossCenter = Offset(
        cageRect.center.dx + shiftX,
        cageRect.center.dy + h * 0.04 - shiftY,
      );
      drawDistrictBoss(
        canvas,
        bossCenter,
        math.min(w, h) * 0.36,
        bossType: bossType,
        animPhase: animPhase,
        facingRight: true,
        isCaged: true,
        isEnraged: cageState == BossCageState.rattling ||
            cageState == BossCageState.lockBreaking,
      );
    }

    // 5. Front heavy iron bars (bent slightly outward when boss pushes/rattles!)
    final bool doorOpen =
        cageState == BossCageState.doorOpening || cageState == BossCageState.escaped;

    final frontBarPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = math.max(2.6, w * 0.055)
      ..strokeCap = StrokeCap.round;
    final barHighlight = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = math.max(1.0, w * 0.018);

    if (!doorOpen) {
      final bend = shakeIntensity * w * 0.045;
      for (int i = 1; i <= 4; i++) {
        final bx = cageRect.left + w * (i / 5.0);
        final localBend = (i == 2 || i == 3) ? bend * (i == 2 ? -1 : 1) : 0.0;
        final barPath = Path()
          ..moveTo(bx, cageRect.top + 3)
          ..quadraticBezierTo(
            bx + localBend,
            cageRect.center.dy,
            bx,
            cageRect.bottom - 5,
          );
        canvas.drawPath(barPath, frontBarPaint..style = PaintingStyle.stroke);
        canvas.drawPath(barPath.shift(const Offset(-0.8, 0)),
            barHighlight..style = PaintingStyle.stroke);
      }
      // Horizontal steel cross-bar & animated chain
      canvas.drawLine(
        Offset(cageRect.left + 3, cageRect.center.dy),
        Offset(cageRect.right - 3, cageRect.center.dy),
        Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = math.max(2.8, h * 0.065),
      );
    } else {
      // Swung-open broken gate door on left hinge!
      final openGate = Rect.fromLTWH(
        cageRect.left - w * 0.24,
        cageRect.top + 4,
        w * 0.26,
        h - 10,
      );
      canvas.drawRect(
        openGate,
        Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
      canvas.drawLine(
        Offset(openGate.center.dx, openGate.top),
        Offset(openGate.center.dx, openGate.bottom),
        frontBarPaint..style = PaintingStyle.stroke,
      );
    }

    // 6. Reinforced steel frame border & bolted corner plates
    canvas.drawRRect(
      RRect.fromRectAndRadius(cageRect, const Radius.circular(9)),
      Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.2, w * 0.06),
    );
    final rivetPaint = Paint()..color = const Color(0xFF94A3B8);
    for (final corner in [
      cageRect.topLeft + const Offset(5, 5),
      cageRect.topRight + const Offset(-5, 5),
      cageRect.bottomLeft + const Offset(5, -5),
      cageRect.bottomRight + const Offset(-5, -5),
    ]) {
      canvas.drawCircle(corner, math.max(1.8, w * 0.032), rivetPaint);
    }

    // 7. Heavy Fantasy Padlock (shatters with golden-red burst during lockBreaking!)
    if (cageState == BossCageState.locked || cageState == BossCageState.rattling) {
      final lockCenter = Offset(cageRect.center.dx, cageRect.center.dy + 1);
      final lr = math.max(5.5, w * 0.13);
      // Shackle
      canvas.drawArc(
        Rect.fromCenter(
          center: lockCenter + Offset(0, -lr * 0.55),
          width: lr * 1.15,
          height: lr * 1.15,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, lr * 0.28),
      );
      // Gold lock body
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: lockCenter, width: lr * 1.5, height: lr * 1.25),
          Radius.circular(lr * 0.28),
        ),
        Paint()..color = const Color(0xFFF59E0B),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: lockCenter, width: lr * 1.5, height: lr * 1.25),
          Radius.circular(lr * 0.28),
        ),
        Paint()
          ..color = const Color(0xFF78350F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(
        lockCenter,
        lr * 0.22,
        Paint()..color = const Color(0xFF1F2937),
      );
    } else if (cageState == BossCageState.lockBreaking) {
      // Shattering golden-red lock burst sparks!
      final lc = cageRect.center;
      for (int i = 0; i < 8; i++) {
        final a = (i / 8.0) * math.pi * 2 + elapsed * 4.0;
        final dist = w * 0.28;
        canvas.drawCircle(
          lc + Offset(math.cos(a) * dist, math.sin(a) * dist),
          math.max(2.2, w * 0.05),
          Paint()
            ..color = i.isEven
                ? const Color(0xFFFFC857)
                : const Color(0xFFFF4D6D),
        );
      }
    }

    // 8. Top tiny crimson warning beacon light
    final beaconPos = Offset(cageRect.center.dx, cageRect.top - 1.5);
    final beaconOn =
        cageState != BossCageState.escaped && (math.sin(elapsed * 8.0) > -0.2);
    canvas.drawCircle(
      beaconPos,
      math.max(3.0, w * 0.065),
      Paint()
        ..color = beaconOn ? const Color(0xFFFF1744) : const Color(0xFF64748B),
    );
    if (beaconOn) {
      canvas.drawCircle(
        beaconPos,
        math.max(5.5, w * 0.12),
        Paint()..color = const Color(0x44FF1744),
      );
    }

    canvas.restore();
  }

  /// Renders one of the 5 visually distinct Giant District Bosses using our
  /// high-resolution painted 2.5D sprites augmented with unique district silhouettes
  /// (thorns, market armor, forest aura, titan horns, guardian golden crown) + VFX.
  static void drawDistrictBoss(
    Canvas canvas,
    Offset center,
    double radius, {
    required DistrictBossType bossType,
    required double animPhase,
    required bool facingRight,
    bool isCaged = false,
    bool isEnraged = false,
    bool isHitFlash = false,
    bool isStunned = false,
    bool isFrozen = false,
    bool hasShield = false,
    double? hpRatio,
    String? nameLabel,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Shadow under giant boss
    if (!isCaged) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, radius * 0.85),
          width: radius * 2.1,
          height: radius * 0.62,
        ),
        Paint()..color = const Color(0x481A1024),
      );
    }

    // Menacing aura ring when enraged or charging
    if (isEnraged && !isFrozen && !isStunned) {
      canvas.drawCircle(
        Offset.zero,
        radius * 1.32,
        Paint()..color = Color(bossType.accentColorHex).withOpacity(0.28),
      );
    }

    final bounce = (isFrozen || isStunned || isCaged)
        ? 0.0
        : math.sin(animPhase).abs() * radius * 0.14;
    final breath = (isFrozen || isStunned) ? 0.0 : math.sin(animPhase) * 0.06;

    canvas.save();
    canvas.translate(0, -bounce);
    canvas.scale((facingRight ? 1.0 : -1.0) * (1.0 + breath), 1.0 - breath);

    // Pick matched high-res painted 2.5D sprite per district boss
    final MonsterType spriteKey;
    switch (bossType) {
      case DistrictBossType.orchardThornBeast:
        spriteKey = MonsterType.forestBrute;
        break;
      case DistrictBossType.marketArmoredBrute:
        spriteKey = MonsterType.redHunter;
        break;
      case DistrictBossType.forestShadowBeast:
        spriteKey = MonsterType.mushroomBeast;
        break;
      case DistrictBossType.valleyHornedTitan:
        spriteKey = MonsterType.shadowCrawler;
        break;
      case DistrictBossType.cityGrandGuardian:
        spriteKey = MonsterType.mazeGuardian;
        break;
    }

    final sprite = SpriteAtlas.instance.monsterSpriteFor(spriteKey);
    if (sprite != null) {
      final drawSize = radius * 2.65;
      final dst = Rect.fromCenter(
        center: Offset(0, -radius * 0.05),
        width: drawSize,
        height: drawSize,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        sprite.width.toDouble(),
        sprite.height.toDouble(),
      );
      final paint = Paint()..filterQuality = FilterQuality.high;
      if (isHitFlash) {
        paint.colorFilter = const ColorFilter.mode(
          Color(0xBBFFFFFF),
          BlendMode.srcATop,
        );
      }
      canvas.drawImageRect(sprite, src, dst, paint);
    } else {
      // Rich vector silhouette fallback (also crisp in headless tests)
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: radius * 1.9, height: radius * 1.85),
        Paint()
          ..color = isHitFlash
              ? Colors.white
              : Color(bossType.primaryColorHex),
      );
      // Glowing eyes & jagged fangs
      final eyePaint = Paint()..color = Color(bossType.accentColorHex);
      canvas.drawCircle(Offset(-radius * 0.32, -radius * 0.2), radius * 0.16, eyePaint);
      canvas.drawCircle(Offset(radius * 0.32, -radius * 0.2), radius * 0.16, eyePaint);
      final mouth = Rect.fromCenter(
        center: Offset(0, radius * 0.25),
        width: radius * 0.9,
        height: radius * 0.36,
      );
      canvas.drawOval(mouth, Paint()..color = const Color(0xFF1A0A14));
      for (int t = -2; t <= 2; t++) {
        canvas.drawCircle(
          Offset(t * radius * 0.15, radius * 0.16),
          radius * 0.06,
          Paint()..color = Colors.white,
        );
      }
    }

    // District-unique boss crown / horns / armor crest overlay so all 5 bosses look iconic!
    _drawDistrictBossCrest(canvas, radius, bossType);

    canvas.restore();

    // Defensive Boss Shield (Levels 31-50)
    if (hasShield) {
      canvas.drawCircle(
        Offset.zero,
        radius * 1.38,
        Paint()..color = const Color(0x2EA855F7),
      );
      canvas.drawCircle(
        Offset.zero,
        radius * 1.38,
        Paint()
          ..color = const Color(0xDD9333EA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2,
      );
    }

    // Frozen Ice Prism
    if (isFrozen) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: radius * 2.1, height: radius * 2.2),
          Radius.circular(radius * 0.35),
        ),
        Paint()..color = const Color(0x6638BDF8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: radius * 2.1, height: radius * 2.2),
          Radius.circular(radius * 0.35),
        ),
        Paint()
          ..color = const Color(0xEEBAE6FD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6,
      );
    }

    // Stunned orbiting stars
    if (isStunned) {
      for (int i = 0; i < 3; i++) {
        final a = animPhase * 2.5 + i * (math.pi * 2 / 3);
        final sx = math.cos(a) * radius * 0.85;
        final sy = -radius * 1.15 + math.sin(a) * radius * 0.22;
        canvas.drawCircle(Offset(sx, sy), radius * 0.15, Paint()..color = const Color(0xFFFFC857));
      }
    }

    // Boss HP Bar above head during Road Battle
    if (hpRatio != null && !isCaged) {
      final barW = radius * 2.35;
      final barH = math.max(5.5, radius * 0.22);
      final barRect = Rect.fromCenter(
        center: Offset(0, -radius * 1.38),
        width: barW,
        height: barH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        Paint()..color = const Color(0xCC1F2937),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            barRect.left + 1,
            barRect.top + 1,
            math.max(0.0, (barRect.width - 2) * hpRatio.clamp(0.0, 1.0)),
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
              fontSize: math.max(9.0, radius * 0.32),
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

  static void _drawDistrictBossCrest(
    Canvas canvas,
    double r,
    DistrictBossType type,
  ) {
    final accent = Paint()..color = Color(type.accentColorHex);
    switch (type) {
      case DistrictBossType.orchardThornBeast:
        // Spiky crimson thorns across shoulders/head
        for (final dx in const [-0.55, 0.0, 0.55]) {
          final thorn = Path()
            ..moveTo(dx * r - r * 0.14, -r * 0.85)
            ..lineTo(dx * r, -r * 1.24)
            ..lineTo(dx * r + r * 0.14, -r * 0.85)
            ..close();
          canvas.drawPath(thorn, accent);
        }
        break;
      case DistrictBossType.marketArmoredBrute:
        // Heavy iron-bronze shoulder pauldrons & horned helmet crest
        final armor = Paint()..color = const Color(0xFF94A3B8);
        canvas.drawArc(
          Rect.fromCenter(center: Offset(0, -r * 0.72), width: r * 1.3, height: r * 0.65),
          math.pi,
          math.pi,
          true,
          armor,
        );
        canvas.drawCircle(Offset(0, -r * 0.92), r * 0.13, accent);
        break;
      case DistrictBossType.forestShadowBeast:
        // Glowing toxic emerald wisps above head
        canvas.drawCircle(Offset(-r * 0.52, -r * 0.95), r * 0.12, accent);
        canvas.drawCircle(Offset(r * 0.52, -r * 0.95), r * 0.12, accent);
        break;
      case DistrictBossType.valleyHornedTitan:
        // Giant curved crimson-violet bull horns
        final hornPaint = Paint()
          ..color = const Color(0xFFD946EF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.6, r * 0.16)
          ..strokeCap = StrokeCap.round;
        final leftHorn = Path()
          ..moveTo(-r * 0.35, -r * 0.75)
          ..quadraticBezierTo(-r * 0.95, -r * 0.95, -r * 0.72, -r * 1.38);
        final rightHorn = Path()
          ..moveTo(r * 0.35, -r * 0.75)
          ..quadraticBezierTo(r * 0.95, -r * 0.95, r * 0.72, -r * 1.38);
        canvas.drawPath(leftHorn, hornPaint);
        canvas.drawPath(rightHorn, hornPaint);
        break;
      case DistrictBossType.cityGrandGuardian:
        // Gleaming Golden Crown Crest
        final crown = Path()
          ..moveTo(-r * 0.45, -r * 0.88)
          ..lineTo(-r * 0.38, -r * 1.28)
          ..lineTo(-r * 0.15, -r * 1.02)
          ..lineTo(0, -r * 1.36)
          ..lineTo(r * 0.15, -r * 1.02)
          ..lineTo(r * 0.38, -r * 1.28)
          ..lineTo(r * 0.45, -r * 0.88)
          ..close();
        canvas.drawPath(crown, accent);
        canvas.drawPath(
          crown,
          Paint()
            ..color = const Color(0xFF78350F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        break;
    }
  }

  /// Renders the Dock Worker Ally:
  /// - Peaceful waving/loading when [hasKnifeDrawn] is false
  /// - Alert defender wielding a stylized cartoon fantasy combat knife ONLY when [hasKnifeDrawn] is true!
  static void drawDockWorkerWithKnife(
    Canvas canvas,
    Offset center,
    double radius, {
    required bool hasKnifeDrawn,
    required double facingAngle,
    required double walkPhase,
    required double slashAnimTimer,
    required bool isSurprised,
    required bool isRecovering,
    required bool isCelebrating,
    required double elapsed,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Draw base Dock Worker character using existing charming collector illustrator
    final collectorState = isCelebrating
        ? CollectorAnimState.celebrating
        : (hasKnifeDrawn
            ? CollectorAnimState.combatReady
            : CollectorAnimState.waiting);

    if (isRecovering) {
      canvas.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: radius * 2.2),
        Paint()..color = const Color(0x99FFFFFF),
      );
    }

    CharacterIllustrator.drawCollector(
      canvas,
      Offset.zero,
      radius,
      state: collectorState,
      elapsed: elapsed,
    );

    if (isRecovering) {
      canvas.restore();
    }

    // Surprised exclamation mark when boss escapes!
    if (isSurprised) {
      final badgePos = Offset(0, -radius * 1.45);
      canvas.drawCircle(badgePos, radius * 0.38, Paint()..color = const Color(0xFFFF4D6D));
      final tp = TextPainter(
        text: TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: math.max(10.0, radius * 0.55),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, badgePos - Offset(tp.width / 2, tp.height / 2));
    }

    // Stylized Cartoon Fantasy Combat Knife — strictly drawn ONLY after boss escapes!
    if (hasKnifeDrawn) {
      canvas.save();
      final swingOffset = slashAnimTimer > 0
          ? math.sin((slashAnimTimer / 0.28) * math.pi) * 1.35
          : 0.0;
      canvas.rotate(facingAngle + swingOffset - 0.35);
      canvas.translate(radius * 0.78, radius * 0.08);

      // Hilt (warm brown leather grip)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-radius * 0.12, 0),
            width: radius * 0.32,
            height: radius * 0.15,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF7A4424),
      );
      // Golden crossguard
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(radius * 0.05, 0),
            width: radius * 0.11,
            height: radius * 0.38,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFFFC857),
      );
      // Gleaming silver fantasy knife blade
      final blade = Path()
        ..moveTo(radius * 0.1, -radius * 0.12)
        ..lineTo(radius * 0.72, -radius * 0.04)
        ..lineTo(radius * 0.88, 0.0)
        ..lineTo(radius * 0.68, radius * 0.11)
        ..lineTo(radius * 0.1, radius * 0.12)
        ..close();
      canvas.drawPath(blade, Paint()..color = const Color(0xFFE2E8F0));
      canvas.drawPath(
        blade,
        Paint()
          ..color = const Color(0xFF0284C7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Crisp white specular gleam along top edge
      canvas.drawLine(
        Offset(radius * 0.16, -radius * 0.05),
        Offset(radius * 0.72, -radius * 0.02),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );

      // Stylized cartoon slash arc when attacking!
      if (slashAnimTimer > 0) {
        final alpha = (slashAnimTimer / 0.28).clamp(0.0, 1.0);
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: radius * 1.15),
          -0.8,
          1.6,
          false,
          Paint()
            ..color = const Color(0xFF38BDF8).withOpacity(alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.24 * alpha
            ..strokeCap = StrokeCap.round,
        );
      }

      canvas.restore();
    }

    canvas.restore();
  }

  /// Renders the moving Delivery Truck rotating smoothly along the winding road,
  /// complete with spinning wheels, tire-damage flash/smoke, headlights, damage states,
  /// and compact floating HP bar!
  static void drawRoadTruck(
    Canvas canvas,
    Offset center,
    double scale, {
    required TruckDefenseVehicle truck,
    required double elapsed,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // 1. Rotating vehicle chassis aligned to road tangent angle
    canvas.save();
    canvas.rotate(truck.angle);

    final bodyW = scale * 1.75;
    final bodyH = scale * 1.02;

    // Ground drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 3.5), width: bodyW * 1.04, height: bodyH * 1.08),
        Radius.circular(scale * 0.22),
      ),
      Paint()..color = const Color(0x361F2A44),
    );

    // Headlight cones pointing forward along road
    if (!truck.isDestroyed) {
      final beam = Path()
        ..moveTo(bodyW * 0.48, -bodyH * 0.28)
        ..lineTo(bodyW * 1.18, -bodyH * 0.56)
        ..lineTo(bodyW * 1.18, bodyH * 0.56)
        ..lineTo(bodyW * 0.48, bodyH * 0.28)
        ..close();
      canvas.drawPath(beam, Paint()..color = const Color(0x28FFF3B0));
    }

    // 4 Rubber Tires (rear tires flash bright orange when damaged!)
    final tireFlash = truck.tireFlashTimer > 0 && ((elapsed * 16).floor().isEven);
    final wheelPositions = [
      Offset(-bodyW * 0.30, -bodyH * 0.50),
      Offset(-bodyW * 0.30, bodyH * 0.50),
      Offset(bodyW * 0.28, -bodyH * 0.50),
      Offset(bodyW * 0.28, bodyH * 0.50),
    ];
    for (int i = 0; i < wheelPositions.length; i++) {
      final isRear = i < 2;
      final wheelColor = (isRear && (tireFlash || truck.isTireDamaged))
          ? (tireFlash ? const Color(0xFFFF715B) : const Color(0xFFD97706))
          : const Color(0xFF1F2A44);
      final treadShift = math.sin(truck.wheelSpinPhase) * scale * 0.04;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: wheelPositions[i] + Offset(treadShift, 0),
            width: scale * 0.38,
            height: scale * 0.18,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = wheelColor,
      );
    }

    // Rear Cargo Box (warm cream-white with fresh green stripe)
    final cargoRect = Rect.fromLTWH(
      -bodyW * 0.50,
      -bodyH * 0.46,
      bodyW * 0.66,
      bodyH * 0.92,
    );
    final cargoColor = truck.hitFlashTimer > 0
        ? const Color(0xFFFFCDD2)
        : (truck.repairFlashTimer > 0
            ? const Color(0xFFD8F3DC)
            : const Color(0xFFFFF8E8));
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, Radius.circular(scale * 0.16)),
      Paint()..color = cargoColor,
    );
    // Green courier delivery racing stripes on roof
    canvas.drawRect(
      Rect.fromLTWH(
        cargoRect.left + scale * 0.12,
        -bodyH * 0.10,
        cargoRect.width - scale * 0.24,
        bodyH * 0.20,
      ),
      Paint()..color = const Color(0xFF5DBB75),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, Radius.circular(scale * 0.16)),
      Paint()
        ..color = const Color(0xFF243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Front Truck Cabin (bright coral-red cab with sky-blue windshield)
    final cabRect = Rect.fromLTWH(
      bodyW * 0.14,
      -bodyH * 0.42,
      bodyW * 0.36,
      bodyH * 0.84,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cabRect, Radius.circular(scale * 0.15)),
      Paint()..color = const Color(0xFFFF715B),
    );
    // Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cabRect.left + cabRect.width * 0.32,
          cabRect.top + cabRect.height * 0.12,
          cabRect.width * 0.44,
          cabRect.height * 0.76,
        ),
        Radius.circular(scale * 0.08),
      ),
      Paint()..color = const Color(0xFF80CFF2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cabRect, Radius.circular(scale * 0.15)),
      Paint()
        ..color = const Color(0xFF243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Damage smoke puffs when Damaged / Critical / Tire Damaged
    if (truck.damageState == TruckDamageState.damaged ||
        truck.damageState == TruckDamageState.critical ||
        truck.isTireDamaged) {
      final puffOffset = (elapsed * 1.8) % 1.0;
      canvas.drawCircle(
        Offset(-bodyW * 0.56 - puffOffset * scale * 0.45, -bodyH * 0.15),
        scale * (0.14 + puffOffset * 0.16),
        Paint()
          ..color = (truck.damageState == TruckDamageState.critical
                  ? const Color(0xFF475569)
                  : const Color(0xFF94A3B8))
              .withOpacity((1.0 - puffOffset) * 0.65),
      );
    }

    canvas.restore(); // End truck rotation

    // 2. Upright Floating Compact Truck HP Bar + Tire Warning Icon
    final hpRatio = (truck.hp / math.max(1, truck.maxHp)).clamp(0.0, 1.0);
    final barW = scale * 1.95;
    final barH = math.max(5.5, scale * 0.22);
    final barRect = Rect.fromCenter(
      center: Offset(0, -scale * 0.96),
      width: barW,
      height: barH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
      Paint()..color = const Color(0xDD1F2937),
    );
    final hpColor = hpRatio > 0.65
        ? const Color(0xFF5DBB75)
        : (hpRatio > 0.30 ? const Color(0xFFFF9F1C) : const Color(0xFFE63946));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          barRect.left + 1,
          barRect.top + 1,
          math.max(0.0, (barRect.width - 2) * hpRatio),
          barRect.height - 2,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = hpColor,
    );

    if (truck.isTireDamaged) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'SLOW!',
          style: TextStyle(
            color: const Color(0xFFD97706),
            fontSize: math.max(8.5, scale * 0.28),
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, barRect.top - tp.height - 1));
    }

    canvas.restore();
  }
}

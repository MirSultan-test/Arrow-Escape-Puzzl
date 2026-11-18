import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/maze/combat_models.dart';
import '../../models/maze/delivery_state.dart';
import '../../models/maze/food_item.dart';
import '../../models/maze/monster.dart';
import '../../services/sprite_atlas.dart';
import 'food_illustrator.dart';

/// Professional 2D/2.5D fantasy-cartoon character illustrator (V3.2):
/// - Stylized Human Delivery Adventurer with 4-direction animations & held weapons
/// - 6 Visually Frightening, Immediately Distinct Fantasy Monsters + HP/Freeze/Stun VFX
/// - Friendly Delivery Collector & Miniature Delivery Truck
class CharacterIllustrator {
  CharacterIllustrator._();

  /// Renders the stylized human delivery adventurer with expressive face, natural hair,
  /// teal-blue jacket with golden trim, dark trousers, orange backpack, visible arms/legs,
  /// carried weapons, shield bubble, and fluid 4-direction walk/combat animations.
  static void drawCourier(
    Canvas canvas,
    Offset center,
    double radius, {
    required double facingAngle,
    required double walkPhase,
    required bool isMoving,
    required List<FoodItem> carriedFoods,
    required bool isInvulnerable,
    required bool isDamagedFlash,
    required double elapsed,
    WeaponType? equippedWeapon,
    bool isAttacking = false,
    bool hasShield = false,
    bool isPoisonSlowed = false,
    bool isHealing = false,
    bool isCelebrating = false,
  }) {
    if (isInvulnerable && ((elapsed * 14).floor().isEven)) {
      canvas.saveLayer(
        Rect.fromCircle(center: center, radius: radius * 2.5),
        Paint()..color = const Color(0x88FFFFFF),
      );
    } else {
      canvas.save();
    }

    // Determine cardinal facing direction for rich 4-way human animation
    final cosA = math.cos(facingAngle);
    final sinA = math.sin(facingAngle);
    final facingUp = sinA < -0.55;
    final facingSide = cosA.abs() >= sinA.abs();
    final faceDirX = cosA >= 0 ? 1.0 : -1.0;

    final bob = isCelebrating
        ? math.sin(elapsed * 12).abs() * radius * 0.34
        : (isMoving
            ? math.sin(walkPhase).abs() * radius * 0.16
            : math.sin(walkPhase) * radius * 0.04);

    canvas.translate(center.dx, center.dy);

    // Healing aura or poison slow ring
    if (isHealing) {
      canvas.drawCircle(
        Offset.zero,
        radius * 1.28,
        Paint()..color = const Color(0x385DBB75),
      );
    } else if (isPoisonSlowed) {
      canvas.drawCircle(
        Offset.zero,
        radius * 1.16,
        Paint()..color = const Color(0x449333EA),
      );
    }

    // Ground contact shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, radius * 0.86),
        width: radius * 1.45,
        height: radius * 0.45,
      ),
      Paint()..color = const Color(0x3D1F2A44),
    );

    canvas.translate(0, -bob);

    final heroSprite = SpriteAtlas.instance.heroSpriteFor(
      equippedWeapon: equippedWeapon,
    );

    if (heroSprite != null) {
      // High-resolution painted 2.5D hero sprite with fluid walk squash/stretch & directional flip!
      canvas.save();
      final squash = isMoving ? math.sin(walkPhase) * 0.065 : math.sin(walkPhase) * 0.025;
      final attackScale = isAttacking ? 1.12 : 1.0;
      final tilt = isMoving ? faceDirX * math.sin(walkPhase) * 0.08 : 0.0;
      canvas.rotate(tilt);
      canvas.scale(faceDirX * (1.0 + squash) * attackScale, (1.0 - squash) * attackScale);

      final drawSize = radius * 2.55;
      final dst = Rect.fromCenter(
        center: Offset(0, -radius * 0.08),
        width: drawSize,
        height: drawSize,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        heroSprite.width.toDouble(),
        heroSprite.height.toDouble(),
      );
      final paint = Paint()..filterQuality = FilterQuality.high;
      if (isDamagedFlash) {
        paint.colorFilter = const ColorFilter.mode(
          Color(0xAAFF4D6D),
          BlendMode.srcATop,
        );
      }
      canvas.drawImageRect(heroSprite, src, dst, paint);
      canvas.restore();
      // Always render the equipped fantasy Bow / Energy Blaster / Freeze Orb cleanly aimed!
      if (equippedWeapon != null) {
        _drawHeldWeapon(canvas, radius * 1.15, facingAngle, equippedWeapon, isAttacking);
      }
    } else {
      final stride = isMoving ? math.sin(walkPhase) * radius * 0.25 : 0.0;
      final armSwing = isMoving ? math.sin(walkPhase) * radius * 0.22 : 0.0;

    // --- 1. LEGS & TRAVEL SHOES (dark trousers + brown boots) ---
    final trouserPaint = Paint()..color = const Color(0xFF1F2D3D);
    final bootPaint = Paint()..color = const Color(0xFF7A4424);

    // Left leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(-radius * 0.24, radius * 0.56 + stride * 0.5),
            width: radius * 0.32,
            height: radius * 0.44),
        Radius.circular(radius * 0.14),
      ),
      trouserPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-radius * 0.24, radius * 0.78 + stride * 0.6),
          width: radius * 0.36,
          height: radius * 0.22),
      bootPaint,
    );

    // Right leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(radius * 0.24, radius * 0.56 - stride * 0.5),
            width: radius * 0.32,
            height: radius * 0.44),
        Radius.circular(radius * 0.14),
      ),
      trouserPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(radius * 0.24, radius * 0.78 - stride * 0.6),
          width: radius * 0.36,
          height: radius * 0.22),
      bootPaint,
    );

    // --- 2. ORANGE COURIER BACKPACK (behind torso when facing down/side) ---
    if (!facingUp) {
      final packShift = facingSide ? -faceDirX * radius * 0.32 : 0.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(packShift, radius * 0.14),
            width: radius * 1.18,
            height: radius * 0.76,
          ),
          Radius.circular(radius * 0.24),
        ),
        Paint()..color = const Color(0xFFF97316),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(packShift, radius * 0.14),
            width: radius * 1.18,
            height: radius * 0.76,
          ),
          Radius.circular(radius * 0.24),
        ),
        Paint()
          ..color = const Color(0xFF9A3412)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.08,
      );
    }

    // --- 3. TORSO: TEAL ADVENTURE JACKET + GOLDEN ACCENTS + UTILITY BELT ---
    final jacketColor = isDamagedFlash
        ? const Color(0xFFFF4D6D)
        : const Color(0xFF0EA5A4);
    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, radius * 0.18),
        width: radius * 0.96,
        height: radius * 0.76,
      ),
      Radius.circular(radius * 0.3),
    );
    canvas.drawRRect(torsoRect, Paint()..color = jacketColor);
    canvas.drawRRect(
      torsoRect,
      Paint()
        ..color = const Color(0xFF134E4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08,
    );

    // Golden-yellow adventure collar & zipper stripe
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, radius * 0.14),
        width: radius * 0.16,
        height: radius * 0.62,
      ),
      Paint()..color = const Color(0xFFFFC857),
    );
    // Utility belt + golden buckle
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, radius * 0.44),
        width: radius * 0.96,
        height: radius * 0.16,
      ),
      Paint()..color = const Color(0xFF5C3A21),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, radius * 0.44),
          width: radius * 0.24,
          height: radius * 0.16,
        ),
        Radius.circular(radius * 0.04),
      ),
      Paint()..color = const Color(0xFFFFC857),
    );

    // Visible animated arms (sleeve + skin hand)
    final sleevePaint = Paint()..color = const Color(0xFF0D9488);
    final skinPaint = Paint()..color = const Color(0xFFFFD8B8);
    // Left arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-radius * 0.56, radius * 0.16 - armSwing * 0.5),
          width: radius * 0.26,
          height: radius * 0.52,
        ),
        Radius.circular(radius * 0.12),
      ),
      sleevePaint,
    );
    canvas.drawCircle(
        Offset(-radius * 0.56, radius * 0.42 - armSwing * 0.5), radius * 0.13, skinPaint);
    // Right arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(radius * 0.56, radius * 0.16 + armSwing * 0.5),
          width: radius * 0.26,
          height: radius * 0.52,
        ),
        Radius.circular(radius * 0.12),
      ),
      sleevePaint,
    );
    canvas.drawCircle(
        Offset(radius * 0.56, radius * 0.42 + armSwing * 0.5), radius * 0.13, skinPaint);

    // Orange backpack visible in FRONT of back when walking UP
    if (facingUp) {
      final pack = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, radius * 0.18),
            width: radius * 0.84,
            height: radius * 0.68),
        Radius.circular(radius * 0.2),
      );
      canvas.drawRRect(pack, Paint()..color = const Color(0xFFF97316));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(0, radius * 0.02),
              width: radius * 0.72,
              height: radius * 0.2),
          Radius.circular(radius * 0.08),
        ),
        Paint()..color = const Color(0xFFFFC857),
      );
    }

    // --- 4. HUMAN HEAD, NATURAL HAIRSTYLE & EXPRESSIVE FACE ---
    final headCenter = Offset(0, -radius * 0.42);
    final headR = radius * 0.54;

    // Back hair volume
    canvas.drawCircle(
      headCenter + Offset(0, -headR * 0.08),
      headR * 1.12,
      Paint()..color = const Color(0xFF4A2E1B),
    );

    // Face circle with subtle warm shading
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.3),
          colors: [Color(0xFFFFE5CC), Color(0xFFF5C29B)],
        ).createShader(Rect.fromCircle(center: headCenter, radius: headR)),
    );
    canvas.drawCircle(
      headCenter,
      headR,
      Paint()
        ..color = const Color(0xFF3E2723)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.07,
    );

    // Stylish layered front bangs + side locks
    final hairPaint = Paint()..color = const Color(0xFF5C3822);
    if (facingUp) {
      // Full back of hair
      canvas.drawCircle(headCenter, headR * 1.05, hairPaint);
      // Yellow adventure headband
      canvas.drawRect(
        Rect.fromCenter(
            center: headCenter + Offset(0, -headR * 0.15),
            width: headR * 2.0,
            height: headR * 0.22),
        Paint()..color = const Color(0xFFFFC857),
      );
    } else {
      // Top sculpted bangs + hair sweep
      final bangs = Path()
        ..moveTo(headCenter.dx - headR * 1.02, headCenter.dy - headR * 0.12)
        ..quadraticBezierTo(headCenter.dx - headR * 0.9, headCenter.dy - headR * 1.18,
            headCenter.dx, headCenter.dy - headR * 1.14)
        ..quadraticBezierTo(headCenter.dx + headR * 0.9, headCenter.dy - headR * 1.18,
            headCenter.dx + headR * 1.02, headCenter.dy - headR * 0.12)
        ..quadraticBezierTo(headCenter.dx + headR * 0.55, headCenter.dy - headR * 0.55,
            headCenter.dx + headR * 0.15, headCenter.dy - headR * 0.35)
        ..quadraticBezierTo(headCenter.dx - headR * 0.15, headCenter.dy - headR * 0.62,
            headCenter.dx - headR * 0.55, headCenter.dy - headR * 0.35)
        ..close();
      canvas.drawPath(bangs, hairPaint);

      // Adventure yellow headband stripe across hair
      canvas.drawArc(
        Rect.fromCircle(center: headCenter, radius: headR * 0.96),
        math.pi * 1.14,
        math.pi * 0.72,
        false,
        Paint()
          ..color = const Color(0xFFFFC857)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.1,
      );

      // Expressive human eyes with white shine + rosy cheeks + smile
      final lookX = cosA * headR * 0.18;
      final lookY = sinA * headR * 0.08;
      final eyeY = headCenter.dy + headR * 0.06 + lookY;
      final leftEyeX = headCenter.dx - headR * 0.32 + lookX;
      final rightEyeX = headCenter.dx + headR * 0.32 + lookX;

      final eyeInk = Paint()..color = const Color(0xFF1F2A44);
      final white = Paint()..color = Colors.white;
      // Eye whites & pupils
      canvas.drawOval(
          Rect.fromCenter(center: Offset(leftEyeX, eyeY), width: headR * 0.28, height: headR * 0.34),
          white);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(rightEyeX, eyeY), width: headR * 0.28, height: headR * 0.34),
          white);
      canvas.drawCircle(Offset(leftEyeX + cosA * 1.2, eyeY), headR * 0.12, eyeInk);
      canvas.drawCircle(Offset(rightEyeX + cosA * 1.2, eyeY), headR * 0.12, eyeInk);
      canvas.drawCircle(Offset(leftEyeX - headR * 0.04, eyeY - headR * 0.06), headR * 0.045, white);
      canvas.drawCircle(Offset(rightEyeX - headR * 0.04, eyeY - headR * 0.06), headR * 0.045, white);

      // Rosy cheeks
      final cheek = Paint()..color = const Color(0x55FF6B6B);
      canvas.drawCircle(Offset(headCenter.dx - headR * 0.48 + lookX * 0.5, eyeY + headR * 0.22), headR * 0.13, cheek);
      canvas.drawCircle(Offset(headCenter.dx + headR * 0.48 + lookX * 0.5, eyeY + headR * 0.22), headR * 0.13, cheek);

      // Determined or cheerful mouth
      canvas.drawArc(
        Rect.fromCenter(
            center: Offset(headCenter.dx + lookX * 0.6, headCenter.dy + headR * 0.38),
            width: headR * 0.42,
            height: headR * 0.24),
        0.15,
        math.pi - 0.3,
        false,
        Paint()
          ..color = const Color(0xFF6B3A2A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.065
          ..strokeCap = StrokeCap.round,
      );
    }

    // --- 5. CLEARLY VISIBLE HELD WEAPON (Bow / Blaster / Freeze Orb) ---
    if (equippedWeapon != null) {
      _drawHeldWeapon(canvas, radius, facingAngle, equippedWeapon, isAttacking);
    }
    } // end vector hero fallback

    // --- 6. CARRIED FOOD BADGES FLOATING NEATLY ABOVE HEAD ---
    if (carriedFoods.isNotEmpty) {
      final count = carriedFoods.length;
      for (int i = 0; i < count; i++) {
        final f = carriedFoods[i];
        final spreadX = (i - (count - 1) / 2.0) * radius * 0.85;
        final foodOffset = Offset(spreadX, -radius * 1.38);
        canvas.drawCircle(
          foodOffset,
          radius * 0.38,
          Paint()..color = const Color(0xF0FFF7E8),
        );
        canvas.drawCircle(
          foodOffset,
          radius * 0.38,
          Paint()
            ..color = f.conditionPercent < 100
                ? const Color(0xFFFF715B)
                : const Color(0xFF5DBB75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.08,
        );
        FoodIllustrator.drawFood(
          canvas,
          foodOffset,
          radius * 0.28,
          f.type,
          conditionPercent: f.conditionPercent,
          showShadow: false,
        );
      }
    }

    // --- 7. PROTECTIVE MAGICAL SHIELD BUBBLE ---
    if (hasShield) {
      canvas.drawCircle(
        Offset(0, -radius * 0.05),
        radius * 1.24,
        Paint()..color = const Color(0x2838BDF8),
      );
      canvas.drawCircle(
        Offset(0, -radius * 0.05),
        radius * 1.24,
        Paint()
          ..color = const Color(0xCC38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.11,
      );
    }

    canvas.restore();
  }

  static void _drawHeldWeapon(
    Canvas canvas,
    double radius,
    double angle,
    WeaponType weapon,
    bool isAttacking,
  ) {
    canvas.save();
    canvas.rotate(angle);
    final reach = radius * (isAttacking ? 0.92 : 0.72);
    canvas.translate(reach, radius * 0.1);

    if (weapon == WeaponType.bow) {
      // Curved fantasy wooden bow + taut string + nocked arrow
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: radius * 0.55, height: radius * 1.15),
        -math.pi * 0.46,
        math.pi * 0.92,
        false,
        Paint()
          ..color = const Color(0xFF8D5524)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.12
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(0, -radius * 0.55),
        Offset(0, radius * 0.55),
        Paint()
          ..color = const Color(0xFFEFE6D5)
          ..strokeWidth = radius * 0.04,
      );
      // Golden arrowhead
      canvas.drawLine(
        Offset(-radius * 0.12, 0),
        Offset(radius * 0.42, 0),
        Paint()
          ..color = const Color(0xFFFFC857)
          ..strokeWidth = radius * 0.08,
      );
    } else if (weapon == WeaponType.energyBlaster) {
      // Glowing violet-cyan fantasy energy blaster
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(radius * 0.1, 0), width: radius * 0.65, height: radius * 0.34),
          Radius.circular(radius * 0.12),
        ),
        Paint()..color = const Color(0xFF7C3AED),
      );
      canvas.drawCircle(
        Offset(radius * 0.42, 0),
        radius * 0.17,
        Paint()..color = const Color(0xFF38BDF8),
      );
    } else if (weapon == WeaponType.freezeOrb) {
      canvas.drawCircle(
        Offset(radius * 0.1, 0),
        radius * 0.24,
        Paint()..color = const Color(0xFF38BDF8),
      );
      canvas.drawCircle(
        Offset(radius * 0.06, -radius * 0.06),
        radius * 0.09,
        Paint()..color = Colors.white,
      );
    }
    canvas.restore();
  }

  /// Renders all 6 visually frightening, immediately recognizable fantasy-cartoon monsters
  /// with glowing eyes, fangs, claws/horns/wings, telegraph rings, HP bar, freeze & stun VFX.
  static void drawMonster(
    Canvas canvas,
    Offset center,
    double baseRadius,
    MonsterEntity monster,
  ) {
    if (monster.isDefeated && monster.defeatAnimTimer <= 0) return;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    final r = baseRadius * monster.type.visualScale;

    // Defeat shrink/fade animation (non-graphic puff)
    if (monster.isDefeated) {
      final t = (monster.defeatAnimTimer / 0.45).clamp(0.0, 1.0);
      canvas.scale(t);
    }

    // Windup telegraph warning circle on floor (Mushroom Beast poison / Brute slam / Boss)
    if (monster.state == MonsterAiState.windup) {
      final windupRadius = monster.type == MonsterType.mushroomBeast
          ? baseRadius * 3.1
          : baseRadius * 2.5;
      final pulse = 0.75 + math.sin(monster.animPhase * 4).abs() * 0.25;
      canvas.drawCircle(
        Offset.zero,
        windupRadius * pulse,
        Paint()
          ..color = (monster.type == MonsterType.mushroomBeast
                  ? const Color(0x389333EA)
                  : const Color(0x38E63946)),
      );
      canvas.drawCircle(
        Offset.zero,
        windupRadius,
        Paint()
          ..color = (monster.type == MonsterType.mushroomBeast
                  ? const Color(0xCC9333EA)
                  : const Color(0xCCE63946))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    // Detect/Chase crimson menace ring
    if (monster.state == MonsterAiState.detect ||
        monster.state == MonsterAiState.chase) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.15,
        Paint()
          ..color = const Color(0x2EFF1744)
          ..style = PaintingStyle.fill,
      );
    }

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.78),
        width: r * 1.65,
        height: r * 0.5,
      ),
      Paint()..color = const Color(0x481A1024),
    );

    final bounce = monster.isFrozen || monster.isStunned
        ? 0.0
        : (monster.type == MonsterType.flyingCreature
            ? math.sin(monster.animPhase * 1.4) * r * 0.25 - r * 0.18
            : math.sin(monster.animPhase).abs() * r * 0.16);

    final biteScale = monster.biteAnimTimer > 0
        ? 1.0 + math.sin(monster.biteAnimTimer * math.pi * 5).abs() * 0.22
        : 1.0;

    canvas.translate(0, -bounce);
    canvas.scale(biteScale);

    final monsterSprite = SpriteAtlas.instance.monsterSpriteFor(monster.type);
    if (monsterSprite != null) {
      // High-resolution painted 2.5D scary monster sprite with breathing, squash & directional flip!
      canvas.save();
      final faceX = math.cos(monster.facingAngle) < -0.15 ? -1.0 : 1.0;
      final breath = monster.isFrozen || monster.isStunned
          ? 0.0
          : math.sin(monster.animPhase) * 0.055;
      canvas.scale(faceX * (1.0 + breath), 1.0 - breath);

      final drawSize = r * 2.55;
      final dst = Rect.fromCenter(
        center: Offset(0, -r * 0.06),
        width: drawSize,
        height: drawSize,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        monsterSprite.width.toDouble(),
        monsterSprite.height.toDouble(),
      );
      final paint = Paint()..filterQuality = FilterQuality.high;
      if (monster.hitFlashTimer > 0) {
        paint.colorFilter = const ColorFilter.mode(
          Color(0xAAFFFFFF),
          BlendMode.srcATop,
        );
      }
      canvas.drawImageRect(monsterSprite, src, dst, paint);
      canvas.restore();
    } else {
      // Vector fallback when sprite asset is unavailable
      switch (monster.type) {
        case MonsterType.redHunter:
          _drawRedHunter(canvas, r, monster);
          break;
        case MonsterType.shadowCrawler:
          _drawShadowCrawler(canvas, r, monster);
          break;
        case MonsterType.forestBrute:
          _drawForestBrute(canvas, r, monster);
          break;
        case MonsterType.flyingCreature:
          _drawFlyingCreature(canvas, r, monster);
          break;
        case MonsterType.mushroomBeast:
          _drawMushroomBeast(canvas, r, monster);
          break;
        case MonsterType.mazeGuardian:
          _drawMazeGuardianBoss(canvas, r, monster);
          break;
      }
      if (monster.hitFlashTimer > 0) {
        canvas.drawCircle(
          Offset.zero,
          r * 0.85,
          Paint()..color = const Color(0x88FFFFFF),
        );
      }
    }

    // Faceted ice crystal prison when FROZEN!
    if (monster.isFrozen) {
      final iceRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 1.85, height: r * 1.85),
        Radius.circular(r * 0.28),
      );
      canvas.drawRRect(iceRect, Paint()..color = const Color(0x7838BDF8));
      canvas.drawRRect(
        iceRect,
        Paint()
          ..color = const Color(0xFFE0F2FE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.11,
      );
      canvas.drawLine(
        Offset(-r * 0.6, -r * 0.55),
        Offset(-r * 0.15, -r * 0.15),
        Paint()
          ..color = const Color(0xBBFFFFFF)
          ..strokeWidth = r * 0.1
          ..strokeCap = StrokeCap.round,
      );
    }

    // Spinning stun stars when STUNNED
    if (monster.isStunned) {
      for (int i = 0; i < 3; i++) {
        final ang = monster.animPhase * 2.2 + i * (math.pi * 2 / 3);
        canvas.drawCircle(
          Offset(math.cos(ang) * r * 0.62, -r * 1.05 + math.sin(ang) * r * 0.18),
          r * 0.14,
          Paint()..color = const Color(0xFFFACC15),
        );
      }
    }

    // Alert "!" badge on DETECT
    if (monster.state == MonsterAiState.detect) {
      final badge = Offset(0, -r * 1.28);
      canvas.drawCircle(badge, r * 0.36, Paint()..color = const Color(0xFFFFD166));
      canvas.drawCircle(
        badge,
        r * 0.36,
        Paint()
          ..color = const Color(0xFFB91C1C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '!',
          style: TextStyle(
            color: const Color(0xFFB91C1C),
            fontSize: r * 0.54,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, badge - Offset(tp.width / 2, tp.height / 2));
    }

    // Floating HP bar (shown when injured or always for Maze Guardian Mini-Boss!)
    if (!monster.isDefeated &&
        (monster.hpBarTimer > 0 ||
            monster.hp < monster.maxHp ||
            monster.type == MonsterType.mazeGuardian)) {
      final barW = r * 1.75;
      final barH = math.max(4.5, r * 0.22);
      final barTop = -r * 1.26;
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(-barW / 2, barTop, barW, barH),
        const Radius.circular(4),
      );
      canvas.drawRRect(bgRect, Paint()..color = const Color(0xDD1F2937));
      final fillW = (barW - 2) * monster.hpRatio;
      if (fillW > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-barW / 2 + 1, barTop + 1, fillW, barH - 2),
            const Radius.circular(3),
          ),
          Paint()
            ..color = monster.hpRatio > 0.45
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B),
        );
      }
    }

    canvas.restore();
  }

  /// Monster 1 — Red Hunter: Dark crimson hunched fiend, twin horns, glowing red eyes, sharp fangs, claws.
  static void _drawRedHunter(Canvas canvas, double r, MonsterEntity m) {
    // Sharp curved horns
    final hornP = Paint()..color = const Color(0xFF2B0A0D);
    for (final s in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(s * r * 0.35, -r * 0.5)
        ..quadraticBezierTo(s * r * 0.85, -r * 1.15, s * r * 0.65, -r * 1.18)
        ..quadraticBezierTo(s * r * 0.55, -r * 0.8, s * r * 0.15, -r * 0.62)
        ..close();
      canvas.drawPath(horn, hornP);
    }

    // Clawed reaching arms
    final clawP = Paint()
      ..color = const Color(0xFF450A0A)
      ..strokeWidth = r * 0.13
      ..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(Offset(s * r * 0.68, 0), Offset(s * r * 0.98, r * 0.25), clawP);
      canvas.drawLine(Offset(s * r * 0.98, r * 0.25), Offset(s * r * 1.05, r * 0.46), clawP);
    }

    // Jagged dark-crimson body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 1.55, height: r * 1.48),
      Radius.circular(r * 0.56),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF3F070A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1,
    );

    // Glowing furious red eyes
    _drawGlowingEyes(canvas, r, m.facingAngle, const Color(0xFFFF1744), const Color(0xFFFFEA00));
    _drawJaggedFangs(canvas, r, 4, const Color(0xFF280509));
  }

  /// Monster 2 — Shadow Crawler: Pitch violet-black body, long curved claws, glowing violet eyes.
  static void _drawShadowCrawler(Canvas canvas, double r, MonsterEntity m) {
    final wiggle = math.sin(m.animPhase * 1.4) * r * 0.14;
    final legP = Paint()
      ..color = const Color(0xFF1E1030)
      ..strokeWidth = r * 0.13
      ..strokeCap = StrokeCap.round;

    // 4 long spindly shadow-claws
    for (final s in [-1.0, 1.0]) {
      canvas.drawLine(Offset(s * r * 0.5, -r * 0.15), Offset(s * r * 1.08, -r * 0.35 + wiggle * s), legP);
      canvas.drawLine(Offset(s * r * 0.55, r * 0.25), Offset(s * r * 1.12, r * 0.48 - wiggle * s), legP);
      // Glowing claw tips
      canvas.drawCircle(Offset(s * r * 1.08, -r * 0.35 + wiggle * s), r * 0.08, Paint()..color = const Color(0xFFC084FC));
      canvas.drawCircle(Offset(s * r * 1.12, r * 0.48 - wiggle * s), r * 0.08, Paint()..color = const Color(0xFFC084FC));
    }

    // Crouched obsidian-purple torso
    final body = Rect.fromCenter(center: Offset(0, r * 0.05), width: r * 1.62, height: r * 1.28);
    canvas.drawOval(
      body,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF140B24)],
        ).createShader(body),
    );
    canvas.drawOval(
      body,
      Paint()
        ..color = const Color(0xFF9333EA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08,
    );

    _drawGlowingEyes(canvas, r, m.facingAngle, const Color(0xFFD946EF), const Color(0xFFF5D0FE));
    _drawJaggedFangs(canvas, r * 0.9, 3, const Color(0xFF0F051D));
  }

  /// Monster 3 — Giant Forest Brute: Muscular moss-green brute, huge clawed arms, heavy tusks.
  static void _drawForestBrute(Canvas canvas, double r, MonsterEntity m) {
    // Broad muscular arms & oversized fists
    final armP = Paint()..color = const Color(0xFF2D5A36);
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(s * r * 0.86, r * 0.18), width: r * 0.48, height: r * 0.95),
          Radius.circular(r * 0.22),
        ),
        armP,
      );
    }

    // Massive boxy-muscular moss-covered body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 1.65, height: r * 1.55),
      Radius.circular(r * 0.42),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4D7C0F), Color(0xFF1E3A2F)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF14271B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1,
    );

    // Moss shoulder tufts
    canvas.drawCircle(Offset(-r * 0.45, -r * 0.65), r * 0.25, Paint()..color = const Color(0xFF65A30D));
    canvas.drawCircle(Offset(r * 0.42, -r * 0.68), r * 0.22, Paint()..color = const Color(0xFF84CC16));

    // Heavy furrowed brow + amber glowing eyes + big lower tusks
    _drawGlowingEyes(canvas, r, m.facingAngle, const Color(0xFFF59E0B), const Color(0xFFFEF08A));
    _drawJaggedFangs(canvas, r * 1.05, 4, const Color(0xFF142117), hugeTusks: true);
  }

  /// Monster 4 — Flying Night Creature: Animated flapping bat wings, small horns, bright yellow eyes.
  static void _drawFlyingCreature(Canvas canvas, double r, MonsterEntity m) {
    final flap = math.sin(m.animPhase * 2.2) * 0.48;

    // Animated bat wings
    for (final s in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(s * r * 0.42, -r * 0.08);
      canvas.rotate(s * flap);
      final wing = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(s * r * 0.82, -r * 0.72, s * r * 1.15, -r * 0.12)
        ..quadraticBezierTo(s * r * 0.82, r * 0.28, s * r * 0.62, r * 0.35)
        ..quadraticBezierTo(s * r * 0.35, r * 0.12, 0, r * 0.25)
        ..close();
      canvas.drawPath(wing, Paint()..color = const Color(0xFF312E81));
      canvas.drawPath(
        wing,
        Paint()
          ..color = const Color(0xFF1E1B4B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08,
      );
      canvas.restore();
    }

    // Pointed bat ears / horns
    for (final s in [-1.0, 1.0]) {
      final ear = Path()
        ..moveTo(s * r * 0.22, -r * 0.42)
        ..lineTo(s * r * 0.52, -r * 1.02)
        ..lineTo(s * r * 0.58, -r * 0.32)
        ..close();
      canvas.drawPath(ear, Paint()..color = const Color(0xFF4338CA));
    }

    // Sleek dark-indigo body
    canvas.drawCircle(
      Offset.zero,
      r * 0.68,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF1E1B4B)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );

    _drawGlowingEyes(canvas, r * 0.92, m.facingAngle, const Color(0xFFFACC15), const Color(0xFFFFFFFF));
    _drawJaggedFangs(canvas, r * 0.82, 2, const Color(0xFF1E1030));
  }

  /// Monster 5 — Poison Mushroom Beast: Huge domed cap with glowing neon spots, creepy mouth.
  static void _drawMushroomBeast(Canvas canvas, double r, MonsterEntity m) {
    // Gnarly dark-purple stem body
    final stem = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, r * 0.26), width: r * 1.05, height: r * 0.98),
      Radius.circular(r * 0.3),
    );
    canvas.drawRRect(stem, Paint()..color = const Color(0xFF3B2F4A));
    canvas.drawRRect(
      stem,
      Paint()
        ..color = const Color(0xFF1F162B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    // Oversized domed toxic mushroom cap
    final capPath = Path()
      ..moveTo(-r * 1.05, -r * 0.08)
      ..cubicTo(-r * 1.12, -r * 1.12, r * 1.12, -r * 1.12, r * 1.05, -r * 0.08)
      ..quadraticBezierTo(0, r * 0.14, -r * 1.05, -r * 0.08)
      ..close();
    canvas.drawPath(
      capPath,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.2, -0.5),
          colors: [Color(0xFF7E22CE), Color(0xFF3B0764)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.2)),
    );
    canvas.drawPath(
      capPath,
      Paint()
        ..color = const Color(0xFF1E0538)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09,
    );

    // Pulsing neon poison-green spots on cap
    final spotP = Paint()..color = const Color(0xFF84CC16);
    canvas.drawCircle(Offset(-r * 0.45, -r * 0.48), r * 0.18, spotP);
    canvas.drawCircle(Offset(r * 0.35, -r * 0.56), r * 0.2, spotP);
    canvas.drawCircle(Offset(0, -r * 0.25), r * 0.13, Paint()..color = const Color(0xFFBEF264));

    // Glowing toxic green eyes & sinister wide grin centered cleanly on the stem face
    _drawGlowingEyes(canvas, r * 0.88, m.facingAngle, const Color(0xFF84CC16), const Color(0xFFD9F99D), yOffset: 0.18);
    _drawJaggedFangs(canvas, r * 0.85, 4, const Color(0xFF1A2E05), yOffset: 0.50);
  }

  /// Monster 6 — Maze Guardian (Mini Boss): Imposing armored horned sentinel with glowing rune & eyes.
  static void _drawMazeGuardianBoss(Canvas canvas, double r, MonsterEntity m) {
    // Pulsing dark-gold boss aura
    canvas.drawCircle(
      Offset.zero,
      r * 1.12,
      Paint()..color = const Color(0x2EFF9F1C),
    );

    // Heavy obsidian curved ram horns
    final hornP = Paint()..color = const Color(0xFFE2B857);
    for (final s in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(s * r * 0.45, -r * 0.42)
        ..cubicTo(s * r * 1.22, -r * 1.05, s * r * 1.15, -r * 0.15, s * r * 0.88, -r * 0.12)
        ..cubicTo(s * r * 0.92, -r * 0.42, s * r * 0.72, -r * 0.65, s * r * 0.35, -r * 0.56)
        ..close();
      canvas.drawPath(horn, hornP);
    }

    // Armored spiked pauldrons
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(s * r * 0.78, r * 0.05),
        r * 0.36,
        Paint()..color = const Color(0xFF334155),
      );
    }

    // Towering armored obsidian torso
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 1.68, height: r * 1.65),
      Radius.circular(r * 0.46),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.11,
    );

    // Glowing golden forehead crown rune
    final rune = Path()
      ..moveTo(0, -r * 0.78)
      ..lineTo(r * 0.16, -r * 0.55)
      ..lineTo(0, -r * 0.36)
      ..lineTo(-r * 0.16, -r * 0.55)
      ..close();
    canvas.drawPath(rune, Paint()..color = const Color(0xFFFFD166));

    // Blazing crimson-gold eyes & heavy armored jaw
    _drawGlowingEyes(canvas, r * 1.02, m.facingAngle, const Color(0xFFFF1744), const Color(0xFFFFEA00));
    _drawJaggedFangs(canvas, r * 1.08, 5, const Color(0xFF280509), hugeTusks: true);
  }

  static void _drawGlowingEyes(
    Canvas canvas,
    double r,
    double facingAngle,
    Color glowColor,
    Color coreColor, {
    double yOffset = -0.14,
  }) {
    final lx = math.cos(facingAngle) * r * 0.1;
    final ly = math.sin(facingAngle) * r * 0.06;
    final ey = r * yOffset + ly;

    for (final s in [-1.0, 1.0]) {
      final ec = Offset(s * r * 0.3 + lx, ey);
      // Outer spooky glow
      canvas.drawCircle(ec, r * 0.25, Paint()..color = glowColor.withOpacity(0.45));
      // Intense eye iris
      canvas.drawCircle(ec, r * 0.16, Paint()..color = glowColor);
      // Bright inner slit/spark
      canvas.drawCircle(ec, r * 0.075, Paint()..color = coreColor);
      // Angry slanted brow
      canvas.drawLine(
        Offset(s * r * 0.54 + lx * 0.5, ey - r * 0.24),
        Offset(s * r * 0.1 + lx * 0.5, ey - r * 0.1),
        Paint()
          ..color = const Color(0xFF0F0A14)
          ..strokeWidth = r * 0.11
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  static void _drawJaggedFangs(
    Canvas canvas,
    double r,
    int toothCount,
    Color mouthBg, {
    double yOffset = 0.28,
    bool hugeTusks = false,
  }) {
    final mouthRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(0, r * yOffset), width: r * 0.88, height: r * 0.34),
      Radius.circular(r * 0.14),
    );
    canvas.drawRRect(mouthRect, Paint()..color = mouthBg);

    final toothP = Paint()..color = const Color(0xFFFFFBEB);
    final step = (r * 0.72) / toothCount;
    for (int i = 0; i < toothCount; i++) {
      final tx = -r * 0.36 + (i + 0.5) * step;
      final fang = Path()
        ..moveTo(tx - step * 0.32, r * (yOffset - 0.14))
        ..lineTo(tx, r * (yOffset + 0.1))
        ..lineTo(tx + step * 0.32, r * (yOffset - 0.14))
        ..close();
      canvas.drawPath(fang, toothP);
    }

    if (hugeTusks) {
      for (final s in [-1.0, 1.0]) {
        final tusk = Path()
          ..moveTo(s * r * 0.26, r * (yOffset + 0.16))
          ..lineTo(s * r * 0.36, r * (yOffset - 0.14))
          ..lineTo(s * r * 0.42, r * (yOffset + 0.16))
          ..close();
        canvas.drawPath(tusk, toothP);
      }
    }
  }

  /// Renders the friendly Delivery Collector waiting in the bottom dock.
  static void drawCollector(
    Canvas canvas,
    Offset center,
    double radius, {
    required CollectorAnimState state,
    required double elapsed,
  }) {
    canvas.save();
    final jump = state == CollectorAnimState.celebrating
        ? math.sin(elapsed * 12).abs() * radius * 0.42
        : (state == CollectorAnimState.receiving ||
                state == CollectorAnimState.carryingToTruck)
            ? math.sin(elapsed * 10).abs() * radius * 0.18
            : math.sin(elapsed * 3) * radius * 0.05;
    final shiftX =
        state == CollectorAnimState.carryingToTruck ? radius * 0.55 : 0.0;

    canvas.translate(center.dx + shiftX, center.dy);

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, radius * 0.72),
          width: radius * 1.4,
          height: radius * 0.45),
      Paint()..color = const Color(0x331F2A44),
    );
    canvas.translate(0, -jump);

    final collectorSprite = SpriteAtlas.instance.collector;
    if (collectorSprite != null) {
      final drawSize = radius * 2.55;
      final dst = Rect.fromCenter(
        center: Offset(0, -radius * 0.08),
        width: drawSize,
        height: drawSize,
      );
      final src = Rect.fromLTWH(
        0,
        0,
        collectorSprite.width.toDouble(),
        collectorSprite.height.toDouble(),
      );
      canvas.drawImageRect(
        collectorSprite,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, radius * 0.18),
            width: radius * 1.15,
            height: radius * 0.92),
        Radius.circular(radius * 0.36),
      ),
      Paint()..color = const Color(0xFF4EA8DE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, radius * 0.3),
            width: radius * 0.78,
            height: radius * 0.62),
        Radius.circular(radius * 0.18),
      ),
      Paint()..color = const Color(0xFFFFC857),
    );

    final waveAngle = state == CollectorAnimState.waiting
        ? math.sin(elapsed * 4.5) * 0.35 - 0.6
        : -1.1;
    canvas.save();
    canvas.translate(-radius * 0.55, radius * 0.02);
    canvas.rotate(waveAngle);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            -radius * 0.14, -radius * 0.45, radius * 0.28, radius * 0.52),
        Radius.circular(radius * 0.14),
      ),
      Paint()..color = const Color(0xFF4EA8DE),
    );
    canvas.restore();

    canvas.drawCircle(
      Offset(0, -radius * 0.32),
      radius * 0.58,
      Paint()..color = const Color(0xFFFFDFC4),
    );
    canvas.drawCircle(
      Offset(0, -radius * 0.32),
      radius * 0.58,
      Paint()
        ..color = const Color(0xFF243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08,
    );

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, -radius * 0.66),
          width: radius * 1.5,
          height: radius * 0.34),
      Paint()..color = const Color(0xFF5DBB75),
    );
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(0, -radius * 0.66),
          width: radius * 1.0,
          height: radius * 0.62),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF3E8E53),
    );

    final ink = Paint()..color = const Color(0xFF243447);
    canvas.drawCircle(Offset(-radius * 0.2, -radius * 0.32), radius * 0.08, ink);
    canvas.drawCircle(Offset(radius * 0.2, -radius * 0.32), radius * 0.08, ink);
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(0, -radius * 0.2),
          width: radius * 0.42,
          height: radius * 0.28),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = const Color(0xFF243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  /// Renders the miniature cartoon Delivery Truck parked in the bottom dock.
  static void drawDeliveryTruck(
    Canvas canvas,
    Offset dockCenter,
    double scale, {
    required TruckAnimState state,
    required double driveOffset,
    required List<FoodItem> loadedFoods,
    required double elapsed,
  }) {
    if (state == TruckAnimState.arrived) return;

    canvas.save();
    final rumble = state == TruckAnimState.engineStart
        ? math.sin(elapsed * 45) * scale * 0.06
        : (state == TruckAnimState.drivingOnRoad
            ? math.sin(elapsed * 32) * scale * 0.04
            : 0.0);
    final travelX = driveOffset * scale * 6.0;

    canvas.translate(dockCenter.dx + travelX, dockCenter.dy + rumble);

    final w = scale * 2.15;
    final h = scale * 1.45;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, h * 0.46), width: w * 1.05, height: h * 0.34),
        Radius.circular(scale * 0.2),
      ),
      Paint()..color = const Color(0x331F2A44),
    );

    if (state == TruckAnimState.engineStart ||
        state == TruckAnimState.drivingOnRoad) {
      for (int i = 0; i < 3; i++) {
        final p = ((elapsed * 2.5 + i * 0.33) % 1.0);
        canvas.drawCircle(
          Offset(-w * 0.56 - p * scale * 0.8, h * 0.24 - p * scale * 0.35),
          scale * (0.14 + p * 0.16),
          Paint()..color = Color.fromRGBO(255, 255, 255, (1.0 - p) * 0.7),
        );
      }
    }

    final bedRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-w * 0.5, -h * 0.46, w * 0.68, h * 0.82),
      Radius.circular(scale * 0.16),
    );
    canvas.drawRRect(bedRect, Paint()..color = const Color(0xFFFFF3DA));
    canvas.drawRRect(
      bedRect,
      Paint()
        ..color = const Color(0xFF243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.07,
    );

    final doorsClosed = state == TruckAnimState.closingDoors ||
        state == TruckAnimState.engineStart ||
        state == TruckAnimState.drivingOnRoad;

    if (!doorsClosed) {
      final showCount = math.min(loadedFoods.length, 4);
      for (int i = 0; i < showCount; i++) {
        final col = i % 2;
        final row = i ~/ 2;
        final fx = -w * 0.32 + col * scale * 0.48;
        final fy = -h * 0.16 + row * scale * 0.36;
        FoodIllustrator.drawFood(
          canvas,
          Offset(fx, fy),
          scale * 0.22,
          loadedFoods[i].type,
          conditionPercent: loadedFoods[i].conditionPercent,
          showShadow: false,
        );
      }
    } else {
      canvas.drawRRect(bedRect, Paint()..color = const Color(0xFF5DBB75));
      canvas.drawRRect(
        bedRect,
        Paint()
          ..color = const Color(0xFF243447)
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * 0.07,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-w * 0.42, -h * 0.12, w * 0.52, h * 0.2),
          Radius.circular(scale * 0.08),
        ),
        Paint()..color = const Color(0xFFFFC857),
      );
    }

    final cabRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, -h * 0.32, w * 0.36, h * 0.68),
      Radius.circular(scale * 0.16),
    );
    canvas.drawRRect(cabRect, Paint()..color = const Color(0xFFFF715B));
    canvas.drawRRect(
      cabRect,
      Paint()
        ..color = const Color(0xFF243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * 0.07,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, -h * 0.22, w * 0.22, h * 0.28),
        Radius.circular(scale * 0.08),
      ),
      Paint()..color = const Color(0xFF80CFF2),
    );
    canvas.drawCircle(
      Offset(w * 0.48, h * 0.12),
      scale * 0.09,
      Paint()..color = const Color(0xFFFFE66D),
    );

    final wheelPaint = Paint()..color = const Color(0xFF243447);
    final hubPaint = Paint()..color = const Color(0xFFFFC857);
    for (final wx in [-w * 0.28, w * 0.30]) {
      canvas.drawCircle(Offset(wx, h * 0.38), scale * 0.22, wheelPaint);
      canvas.drawCircle(Offset(wx, h * 0.38), scale * 0.09, hubPaint);
    }

    canvas.restore();
  }
}

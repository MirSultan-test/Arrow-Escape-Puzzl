import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/maze/monster.dart';
import '../../models/maze/monster_variants.dart';

/// V3.5 Articulated 2.5D Unique Monster Renderer.
/// Renders genuinely distinct monster anatomies (10 silhouettes, 8 horn styles,
/// 1/2/3/4 eye layouts, 5 mouth styles, 6 skin textures, 2/4/6 articulated limbs),
/// dynamic facial expressions, and movement-matched physical animations!
class UniqueMonsterIllustrator {
  UniqueMonsterIllustrator._();

  static void drawUniqueMazeMonster(
    Canvas canvas,
    Offset center,
    double baseRadius,
    MonsterEntity monster,
  ) {
    if (monster.isDefeated && monster.defeatAnimTimer <= 0) return;

    final spec = monster.appearance;
    final r = baseRadius * monster.type.visualScale;
    final faceRight = math.cos(monster.facingAngle) >= -0.15;
    final dirX = faceRight ? 1.0 : -1.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Defeat shrink puff
    if (monster.isDefeated) {
      final t = (monster.defeatAnimTimer / 0.45).clamp(0.0, 1.0);
      canvas.scale(t);
    }

    // Telegraphed windup danger zone (charge warning, poison cloud, or heavy slam!)
    if (monster.state == MonsterAiState.windup) {
      final pulse = 0.78 + math.sin(monster.animPhase * 4.5).abs() * 0.22;
      final isCharge =
          monster.movementProfile == MonsterMovementProfile.chargingMonster;
      final zoneR = monster.type == MonsterType.mushroomBeast
          ? baseRadius * 2.9
          : baseRadius * (isCharge ? 2.1 : 2.3);
      final ringColor = monster.type == MonsterType.mushroomBeast
          ? const Color(0xFF9333EA)
          : const Color(0xFFE63946);
      canvas.drawCircle(
        Offset.zero,
        zoneR * pulse,
        Paint()..color = ringColor.withOpacity(0.22),
      );
      canvas.drawCircle(
        Offset.zero,
        zoneR,
        Paint()
          ..color = ringColor.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      if (isCharge) {
        // Directional crimson charge arrow warning!
        final tip = Offset(
          math.cos(monster.facingAngle) * r * 2.0,
          math.sin(monster.facingAngle) * r * 2.0,
        );
        canvas.drawLine(
          Offset.zero,
          tip,
          Paint()
            ..color = const Color(0xCCE63946)
            ..strokeWidth = r * 0.42
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Crimson menace glow when detecting or chasing
    if (monster.state == MonsterAiState.detect ||
        monster.state == MonsterAiState.chase) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.18,
        Paint()..color = const Color(0x28FF1744),
      );
    }

    // Movement-specific vertical lift (Hop arc / Flying hover / Running bounce / Ambush crouch!)
    double liftY = 0.0;
    double crouchScaleY = 1.0;
    if (!monster.isFrozen && !monster.isStunned) {
      if (monster.movementProfile == MonsterMovementProfile.jumpingCreature) {
        liftY = math.sin(monster.hopPhase.clamp(0.0, math.pi)) * r * 0.78;
      } else if (monster.movementProfile == MonsterMovementProfile.flyingMonster) {
        liftY = r * 0.34 + math.sin(monster.animPhase * 1.5) * r * 0.16;
      } else if (monster.movementProfile == MonsterMovementProfile.ambushMonster &&
          monster.ambushCrouched) {
        crouchScaleY = 0.72;
      } else if (monster.isMoving) {
        liftY = math.sin(monster.animPhase).abs() * r * 0.14;
      }
    }

    // Ground Contact Shadow (shrinks dynamically while airborne during jumps or flight!)
    final shadowFactor = (1.0 - (liftY / (r * 2.4))).clamp(0.55, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.80),
        width: r * 1.65 * spec.widthRatio * shadowFactor,
        height: r * 0.48 * shadowFactor,
      ),
      Paint()..color = const Color(0x461A1024),
    );

    final biteScale = monster.biteAnimTimer > 0
        ? 1.0 + math.sin(monster.biteAnimTimer * math.pi * 5).abs() * 0.22
        : 1.0;

    canvas.translate(0, -liftY);
    canvas.scale(biteScale, biteScale * crouchScaleY);

    // Body lean matching movement personality
    double bodyLean = 0.0;
    if (monster.movementProfile == MonsterMovementProfile.zigzagMonster &&
        monster.isMoving) {
      bodyLean = math.sin(monster.zigzagPhase) * 0.18;
    } else if (monster.chargeActiveTimer > 0 ||
        monster.state == MonsterAiState.chase) {
      bodyLean = dirX * 0.14;
    } else if (monster.hitFlashTimer > 0 || monster.isStunned) {
      bodyLean = -dirX * 0.18;
    }
    canvas.save();
    canvas.rotate(bodyLean);

    final isHitFlash = monster.hitFlashTimer > 0;
    final primary = isHitFlash ? Colors.white : Color(spec.bodyPrimaryHex);
    final secondary =
        isHitFlash ? const Color(0xFFFFCDD2) : Color(spec.bodySecondaryHex);
    final belly = isHitFlash ? Colors.white : Color(spec.bellyHex);
    final glow = Color(spec.eyeGlowHex);
    final hornColor = Color(spec.hornHex);
    final clawColor = Color(spec.clawHex);

    final bw = r * 1.48 * spec.widthRatio;
    final bh = r * 1.32 * spec.heightRatio;

    // 1. MOVEMENT-MATCHED ARTICULATED LIMBS / WINGS
    _drawMonsterLimbsAndWings(
      canvas,
      r: r,
      bw: bw,
      bh: bh,
      spec: spec,
      monster: monster,
      primary: primary,
      secondary: secondary,
      clawColor: clawColor,
      dirX: dirX,
    );

    // 2. DISTINCT BODY SILHOUETTE & SKIN TEXTURE
    _drawBodySilhouette(
      canvas,
      r: r,
      bw: bw,
      bh: bh,
      spec: spec,
      primary: primary,
      secondary: secondary,
      belly: belly,
      glow: glow,
      elapsed: monster.animPhase,
    );

    // 3. DISTINCT HORN / HEAD CREST ANATOMY
    final headY = spec.bodyShape == MonsterBodyShape.lowCrawler
        ? -bh * 0.18
        : -bh * 0.36;
    drawHornCrest(
      canvas,
      headCenter: Offset(0, headY),
      headR: r * 0.52,
      hornStyle: spec.hornStyle,
      hornColor: hornColor,
      glowColor: glow,
    );

    // 4. EXPRESSIVE EYES (1, 2, 3, OR 4 EYES + DYNAMIC FACIAL EXPRESSIONS!)
    final bool isAggressive = monster.state == MonsterAiState.chase ||
        monster.state == MonsterAiState.detect ||
        monster.state == MonsterAiState.attack ||
        monster.chargeActiveTimer > 0 ||
        monster.hpRatio <= 0.4;
    final bool isRoaring = monster.state == MonsterAiState.attack ||
        monster.state == MonsterAiState.windup ||
        monster.biteAnimTimer > 0 ||
        monster.chargeActiveTimer > 0;

    drawMonsterEyes(
      canvas,
      headCenter: Offset(dirX * r * 0.06, headY),
      headR: r * 0.52,
      eyeCount: spec.eyeCount,
      dirX: dirX,
      glowColor: glow,
      isPain: isHitFlash,
      isStunned: monster.isStunned,
      isAggressive: isAggressive,
    );

    // 5. DISTINCT MOUTH / JAW / FANGS / TUSKS / MANDIBLES
    drawMonsterMouth(
      canvas,
      mouthCenter: Offset(dirX * r * 0.05, headY + r * 0.34),
      headR: r * 0.52,
      mouthStyle: spec.mouthStyle,
      jawOpen: isRoaring ? 1.0 : (isAggressive ? 0.58 : 0.25),
      clawColor: clawColor,
    );

    canvas.restore(); // End bodyLean

    // 6. STATUS OVERLAYS (FROZEN CRYSTAL, STUN STARS, ALERT '!', HP BAR)
    if (monster.isFrozen) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 2.0, height: r * 2.1),
          Radius.circular(r * 0.32),
        ),
        Paint()..color = const Color(0x6638BDF8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: r * 2.0, height: r * 2.1),
          Radius.circular(r * 0.32),
        ),
        Paint()
          ..color = const Color(0xEEBAE6FD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    if (monster.isStunned) {
      for (int i = 0; i < 3; i++) {
        final a = monster.animPhase * 1.4 + i * (math.pi * 2 / 3);
        canvas.drawCircle(
          Offset(math.cos(a) * r * 0.8, -r * 1.18 + math.sin(a) * r * 0.2),
          r * 0.15,
          Paint()..color = const Color(0xFFFFC857),
        );
      }
    }

    if (monster.state == MonsterAiState.detect) {
      final badge = Offset(0, -r * 1.28);
      canvas.drawCircle(badge, r * 0.34, Paint()..color = const Color(0xFFFF1744));
      final tp = TextPainter(
        text: TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: math.max(9.0, r * 0.52),
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, badge - Offset(tp.width / 2, tp.height / 2));
    }

    // Compact HP Bar when damaged or Mini-Boss
    if (!monster.isDefeated &&
        (monster.hp < monster.maxHp ||
            monster.hpBarTimer > 0 ||
            monster.type == MonsterType.mazeGuardian)) {
      final barW = r * 1.9;
      final barH = math.max(4.0, r * 0.22);
      final barRect = Rect.fromCenter(
        center: Offset(0, -r * 1.12),
        width: barW,
        height: barH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
        Paint()..color = const Color(0xCC1F2937),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            barRect.left + 1,
            barRect.top + 1,
            math.max(0.0, (barRect.width - 2) * monster.hpRatio),
            barRect.height - 2,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = monster.hpRatio > 0.45
              ? const Color(0xFFFF4D6D)
              : const Color(0xFFFF9F1C),
      );
    }

    canvas.restore();
  }

  static void _drawMonsterLimbsAndWings(
    Canvas canvas, {
    required double r,
    required double bw,
    required double bh,
    required MonsterAppearanceSpec spec,
    required MonsterEntity monster,
    required Color primary,
    required Color secondary,
    required Color clawColor,
    required double dirX,
  }) {
    final stride = (monster.isMoving && !monster.isFrozen && !monster.isStunned)
        ? math.sin(monster.animPhase)
        : 0.0;

    // A. Winged Flier: Animated Flapping Bat/Moth Wings!
    if (spec.bodyShape == MonsterBodyShape.wingedFlier) {
      final flap = (monster.isFrozen || monster.isStunned)
          ? 0.0
          : math.sin(monster.animPhase * 2.1) * 0.48;
      for (final side in const [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(side * bw * 0.35, -bh * 0.10);
        canvas.rotate(side * (-0.35 + flap));
        final wing = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(side * r * 0.85, -r * 0.65, side * r * 1.25, -r * 0.08)
          ..quadraticBezierTo(side * r * 0.85, r * 0.15, side * r * 0.72, r * 0.42)
          ..quadraticBezierTo(side * r * 0.35, r * 0.18, 0, r * 0.25)
          ..close();
        canvas.drawPath(wing, Paint()..color = secondary);
        canvas.drawPath(
          wing,
          Paint()
            ..color = const Color(0xFF120C1C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
        canvas.restore();
      }
      return;
    }

    // B. Low Crawler: 6 Independently Rippling Arachnid / Crawler Legs!
    if (spec.bodyShape == MonsterBodyShape.lowCrawler || spec.limbCount >= 6) {
      final legPaint = Paint()
        ..color = secondary
        ..strokeWidth = math.max(2.2, r * 0.15)
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 3; i++) {
        final yOff = (i - 1) * bh * 0.28;
        final wave = (monster.isMoving && !monster.isFrozen && !monster.isStunned)
            ? math.sin(monster.animPhase * 1.6 + i * 1.8) * r * 0.20
            : 0.0;
        for (final side in const [-1.0, 1.0]) {
          final knee = Offset(side * (bw * 0.62), yOff - r * 0.12 + wave * side);
          final foot = Offset(side * (bw * 0.82), yOff + r * 0.24 - wave * side);
          canvas.drawLine(Offset(side * bw * 0.38, yOff), knee, legPaint);
          canvas.drawLine(knee, foot, legPaint);
          canvas.drawCircle(foot, r * 0.08, Paint()..color = clawColor);
        }
      }
      return;
    }

    // C. Standard Bipedal / Quadrupedal Articulated Legs & Swinging Clawed Arms!
    final legAmp = monster.movementProfile == MonsterMovementProfile.fastHunter ||
            monster.chargeActiveTimer > 0
        ? 0.55
        : 0.36;
    final legLen = spec.bodyShape == MonsterBodyShape.tallLanky ? r * 0.68 : r * 0.48;
    for (final side in const [-1.0, 1.0]) {
      final swing = stride * legAmp * side;
      canvas.save();
      canvas.translate(side * bw * 0.26, bh * 0.28);
      canvas.rotate(swing);
      final legRect = Rect.fromLTWH(-r * 0.16, 0, r * 0.32, legLen);
      canvas.drawRRect(
        RRect.fromRectAndRadius(legRect, Radius.circular(r * 0.12)),
        Paint()..color = secondary,
      );
      canvas.drawCircle(Offset(0, legLen), r * 0.09, Paint()..color = clawColor);
      canvas.restore();
    }

    // Swinging Clawed Arms (raise overhead on windup!)
    for (final side in const [-1.0, 1.0]) {
      final armAngle = monster.state == MonsterAiState.windup
          ? side * -2.25
          : (side * 0.55 - stride * 0.55 * side);
      canvas.save();
      canvas.translate(side * bw * 0.44, -bh * 0.06);
      canvas.rotate(armAngle);
      canvas.drawLine(
        Offset.zero,
        Offset(0, r * 0.55),
        Paint()
          ..color = primary
          ..strokeWidth = math.max(3.0, r * 0.24)
          ..strokeCap = StrokeCap.round,
      );
      // 2 sharp claws on hand
      canvas.drawCircle(Offset(-r * 0.08, r * 0.60), r * 0.075, Paint()..color = clawColor);
      canvas.drawCircle(Offset(r * 0.08, r * 0.60), r * 0.075, Paint()..color = clawColor);
      canvas.restore();
    }
  }

  static void _drawBodySilhouette(
    Canvas canvas, {
    required double r,
    required double bw,
    required double bh,
    required MonsterAppearanceSpec spec,
    required Color primary,
    required Color secondary,
    required Color belly,
    required Color glow,
    required double elapsed,
  }) {
    final outline = Paint()
      ..color = const Color(0xFF120C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, r * 0.075);

    if (spec.bodyShape == MonsterBodyShape.mushroomFiend) {
      // Thick stalk + oversized spotted glowing fungal dome cap!
      final stalk = Rect.fromCenter(center: Offset(0, bh * 0.12), width: bw * 0.66, height: bh * 0.72);
      canvas.drawRRect(RRect.fromRectAndRadius(stalk, Radius.circular(r * 0.22)), Paint()..color = belly);
      canvas.drawRRect(RRect.fromRectAndRadius(stalk, Radius.circular(r * 0.22)), outline);
      final cap = Rect.fromCenter(center: Offset(0, -bh * 0.34), width: bw * 1.25, height: bh * 0.75);
      canvas.drawArc(cap, math.pi, math.pi, true, Paint()..color = primary);
      canvas.drawArc(cap, math.pi, math.pi, true, outline);
      // Glowing fungal spots
      canvas.drawCircle(Offset(-bw * 0.28, -bh * 0.48), r * 0.14, Paint()..color = glow);
      canvas.drawCircle(Offset(bw * 0.24, -bh * 0.52), r * 0.11, Paint()..color = glow);
      canvas.drawCircle(Offset(0, -bh * 0.60), r * 0.09, Paint()..color = glow);
      return;
    }

    if (spec.bodyShape == MonsterBodyShape.phantomWraith) {
      // Jagged ghostly cloak silhouette!
      final cloak = Path()
        ..moveTo(0, -bh * 0.66)
        ..quadraticBezierTo(bw * 0.64, -bh * 0.45, bw * 0.55, bh * 0.45)
        ..lineTo(bw * 0.25, bh * 0.28)
        ..lineTo(0, bh * 0.52)
        ..lineTo(-bw * 0.25, bh * 0.28)
        ..lineTo(-bw * 0.55, bh * 0.45)
        ..quadraticBezierTo(-bw * 0.64, -bh * 0.45, 0, -bh * 0.66)
        ..close();
      canvas.drawPath(cloak, Paint()..color = primary);
      canvas.drawPath(cloak, outline);
      return;
    }

    // Sculpted 2.5D shaded body matching widthRatio & heightRatio
    final bodyRect = Rect.fromCenter(center: Offset(0, -bh * 0.08), width: bw, height: bh);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.46)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [primary, secondary],
        ).createShader(bodyRect),
    );
    // Belly patch
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, bh * 0.08), width: bw * 0.58, height: bh * 0.46),
      Paint()..color = belly.withOpacity(0.85),
    );

    // Distinct Skin Texture Patterns!
    drawSkinPattern(canvas, bodyRect, r, spec.skinPattern, glow, secondary);

    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(r * 0.46)),
      outline,
    );
  }

  /// Shared skin texture painter used by both unique Maze Monsters and all 50 Giant Bosses!
  static void drawSkinPattern(
    Canvas canvas,
    Rect bodyRect,
    double r,
    MonsterSkinPattern pattern,
    Color glow,
    Color dark,
  ) {
    switch (pattern) {
      case MonsterSkinPattern.armoredPlates:
        final plate = Paint()..color = const Color(0xFF94A3B8);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(-bodyRect.width * 0.42, bodyRect.top + bodyRect.height * 0.25), width: r * 0.46, height: r * 0.34),
          plate,
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(bodyRect.width * 0.42, bodyRect.top + bodyRect.height * 0.25), width: r * 0.46, height: r * 0.34),
          plate,
        );
        break;
      case MonsterSkinPattern.thornySpines:
        final sp = Paint()..color = glow;
        for (final sx in const [-0.36, 0.0, 0.36]) {
          final p = Path()
            ..moveTo(sx * bodyRect.width - r * 0.12, bodyRect.top + r * 0.10)
            ..lineTo(sx * bodyRect.width, bodyRect.top - r * 0.30)
            ..lineTo(sx * bodyRect.width + r * 0.12, bodyRect.top + r * 0.10)
            ..close();
          canvas.drawPath(p, sp);
        }
        break;
      case MonsterSkinPattern.glowingSpots:
        final dot = Paint()..color = glow.withOpacity(0.75);
        canvas.drawCircle(Offset(-bodyRect.width * 0.24, bodyRect.top + bodyRect.height * 0.26), r * 0.10, dot);
        canvas.drawCircle(Offset(bodyRect.width * 0.26, bodyRect.top + bodyRect.height * 0.34), r * 0.08, dot);
        break;
      case MonsterSkinPattern.crackedMagma:
        final crack = Paint()
          ..color = glow.withOpacity(0.85)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(-bodyRect.width * 0.24, bodyRect.center.dy - r * 0.1),
          Offset(0, bodyRect.center.dy + r * 0.12),
          crack,
        );
        canvas.drawLine(
          Offset(0, bodyRect.center.dy + r * 0.12),
          Offset(bodyRect.width * 0.22, bodyRect.center.dy - r * 0.04),
          crack,
        );
        break;
      case MonsterSkinPattern.mossyFur:
        final tuft = Paint()..color = dark.withOpacity(0.7);
        canvas.drawCircle(Offset(-bodyRect.width * 0.32, bodyRect.top + r * 0.2), r * 0.14, tuft);
        canvas.drawCircle(Offset(bodyRect.width * 0.32, bodyRect.top + r * 0.2), r * 0.14, tuft);
        break;
      case MonsterSkinPattern.smooth:
        break;
    }
  }

  /// Shared 8-style Horn & Head Crest painter (used by Maze Monsters & all 50 Giant Bosses!).
  static void drawHornCrest(
    Canvas canvas, {
    required Offset headCenter,
    required double headR,
    required MonsterHornStyle hornStyle,
    required Color hornColor,
    required Color glowColor,
  }) {
    final hornStroke = Paint()
      ..color = hornColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.6, headR * 0.22)
      ..strokeCap = StrokeCap.round;

    switch (hornStyle) {
      case MonsterHornStyle.none:
        return;
      case MonsterHornStyle.twinCurved:
        for (final s in const [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(headCenter.dx + s * headR * 0.45, headCenter.dy - headR * 0.45)
            ..quadraticBezierTo(
              headCenter.dx + s * headR * 1.15,
              headCenter.dy - headR * 0.72,
              headCenter.dx + s * headR * 0.85,
              headCenter.dy - headR * 1.25,
            );
          canvas.drawPath(p, hornStroke);
        }
        break;
      case MonsterHornStyle.ramSpiral:
        for (final s in const [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(headCenter.dx + s * headR * 0.45, headCenter.dy - headR * 0.40)
            ..cubicTo(
              headCenter.dx + s * headR * 1.35,
              headCenter.dy - headR * 0.85,
              headCenter.dx + s * headR * 1.45,
              headCenter.dy + headR * 0.15,
              headCenter.dx + s * headR * 0.95,
              headCenter.dy + headR * 0.08,
            );
          canvas.drawPath(p, hornStroke);
        }
        break;
      case MonsterHornStyle.crownSpikes:
        final crown = Path()
          ..moveTo(headCenter.dx - headR * 0.65, headCenter.dy - headR * 0.55)
          ..lineTo(headCenter.dx - headR * 0.52, headCenter.dy - headR * 1.20)
          ..lineTo(headCenter.dx - headR * 0.18, headCenter.dy - headR * 0.82)
          ..lineTo(headCenter.dx, headCenter.dy - headR * 1.38)
          ..lineTo(headCenter.dx + headR * 0.18, headCenter.dy - headR * 0.82)
          ..lineTo(headCenter.dx + headR * 0.52, headCenter.dy - headR * 1.20)
          ..lineTo(headCenter.dx + headR * 0.65, headCenter.dy - headR * 0.55)
          ..close();
        canvas.drawPath(crown, Paint()..color = hornColor);
        break;
      case MonsterHornStyle.antlerThorns:
        for (final s in const [-1.0, 1.0]) {
          final base = Offset(headCenter.dx + s * headR * 0.42, headCenter.dy - headR * 0.48);
          final tip = Offset(headCenter.dx + s * headR * 0.98, headCenter.dy - headR * 1.28);
          canvas.drawLine(base, tip, hornStroke);
          canvas.drawLine(
            Offset.lerp(base, tip, 0.5)!,
            Offset(headCenter.dx + s * headR * 1.25, headCenter.dy - headR * 0.92),
            hornStroke..strokeWidth = math.max(1.8, headR * 0.15),
          );
        }
        break;
      case MonsterHornStyle.singleRhino:
        final rhino = Path()
          ..moveTo(headCenter.dx - headR * 0.24, headCenter.dy - headR * 0.48)
          ..lineTo(headCenter.dx, headCenter.dy - headR * 1.42)
          ..lineTo(headCenter.dx + headR * 0.24, headCenter.dy - headR * 0.48)
          ..close();
        canvas.drawPath(rhino, Paint()..color = hornColor);
        break;
      case MonsterHornStyle.bladeCrest:
        final fin = Path()
          ..moveTo(headCenter.dx - headR * 0.35, headCenter.dy - headR * 0.55)
          ..lineTo(headCenter.dx - headR * 0.10, headCenter.dy - headR * 1.32)
          ..lineTo(headCenter.dx + headR * 0.16, headCenter.dy - headR * 0.96)
          ..lineTo(headCenter.dx + headR * 0.40, headCenter.dy - headR * 1.18)
          ..lineTo(headCenter.dx + headR * 0.45, headCenter.dy - headR * 0.52)
          ..close();
        canvas.drawPath(fin, Paint()..color = glowColor);
        break;
      case MonsterHornStyle.antennae:
        for (final s in const [-1.0, 1.0]) {
          final tip = Offset(headCenter.dx + s * headR * 0.72, headCenter.dy - headR * 1.22);
          canvas.drawLine(
            Offset(headCenter.dx + s * headR * 0.28, headCenter.dy - headR * 0.52),
            tip,
            Paint()
              ..color = hornColor
              ..strokeWidth = math.max(1.8, headR * 0.12),
          );
          canvas.drawCircle(tip, headR * 0.17, Paint()..color = glowColor);
        }
        break;
    }
  }

  /// Shared 1 / 2 / 3 / 4 Eye Anatomy & Expression painter!
  static void drawMonsterEyes(
    Canvas canvas, {
    required Offset headCenter,
    required double headR,
    required int eyeCount,
    required double dirX,
    required Color glowColor,
    required bool isPain,
    required bool isStunned,
    required bool isAggressive,
  }) {
    final List<Offset> eyePos;
    final double eyeScale;
    if (eyeCount == 1) {
      // Giant Cyclops Eye!
      eyePos = [headCenter + Offset(dirX * headR * 0.08, -headR * 0.06)];
      eyeScale = 1.48;
    } else if (eyeCount == 3) {
      // Tri-Eyed Mystic Beast!
      eyePos = [
        headCenter + Offset(-headR * 0.42, 0),
        headCenter + Offset(headR * 0.42, 0),
        headCenter + Offset(0, -headR * 0.34),
      ];
      eyeScale = 0.88;
    } else if (eyeCount >= 4) {
      // 4-Eyed Arachnid Spider Cluster!
      eyePos = [
        headCenter + Offset(-headR * 0.46, 0),
        headCenter + Offset(headR * 0.46, 0),
        headCenter + Offset(-headR * 0.22, -headR * 0.26),
        headCenter + Offset(headR * 0.22, -headR * 0.26),
      ];
      eyeScale = 0.72;
    } else {
      eyePos = [
        headCenter + Offset(-headR * 0.38, -headR * 0.06),
        headCenter + Offset(headR * 0.38, -headR * 0.06),
      ];
      eyeScale = 1.0;
    }

    for (final e in eyePos) {
      final er = headR * 0.22 * eyeScale;
      if (isStunned) {
        canvas.drawCircle(e, er, Paint()..color = const Color(0xFF1F2937));
        canvas.drawCircle(
          e,
          er * 0.72,
          Paint()
            ..color = const Color(0xFFFFC857)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      } else if (isPain) {
        final w = Paint()
          ..color = glowColor
          ..strokeWidth = math.max(1.8, er * 0.55)
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(e + Offset(-er * 0.7, -er * 0.6), e + Offset(er * 0.6, er * 0.6), w);
        canvas.drawLine(e + Offset(er * 0.7, -er * 0.6), e + Offset(-er * 0.6, er * 0.6), w);
      } else {
        canvas.drawCircle(e, er * 1.32, Paint()..color = glowColor.withOpacity(0.35));
        canvas.drawOval(
          Rect.fromCenter(center: e, width: er * 1.55, height: er * 1.15),
          Paint()..color = glowColor,
        );
        canvas.drawCircle(
          e + Offset(dirX * er * 0.22, 0),
          er * 0.42,
          Paint()..color = const Color(0xFF120C1C),
        );
        canvas.drawCircle(
          e + Offset(-er * 0.25, -er * 0.22),
          er * 0.22,
          Paint()..color = Colors.white,
        );
      }
    }

    // Angry slanted brows when threatening / chasing!
    if (!isStunned && !isPain && isAggressive && eyeCount != 4) {
      final brow = Paint()
        ..color = const Color(0xFF120C1C)
        ..strokeWidth = math.max(2.0, headR * 0.16)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        headCenter + Offset(-headR * 0.58, -headR * 0.34),
        headCenter + Offset(-headR * 0.12, -headR * 0.14),
        brow,
      );
      canvas.drawLine(
        headCenter + Offset(headR * 0.58, -headR * 0.34),
        headCenter + Offset(headR * 0.12, -headR * 0.14),
        brow,
      );
    }
  }

  /// Shared 5-style Mouth / Jaw / Tusk / Mandible painter!
  static void drawMonsterMouth(
    Canvas canvas, {
    required Offset mouthCenter,
    required double headR,
    required MonsterMouthStyle mouthStyle,
    required double jawOpen,
    required Color clawColor,
  }) {
    final mw = headR * (0.95 + jawOpen * 0.25);
    final mh = headR * (0.26 + jawOpen * 0.38);

    if (mouthStyle == MonsterMouthStyle.mandibles) {
      // Curved insectoid mandibles!
      canvas.drawOval(
        Rect.fromCenter(center: mouthCenter, width: mw * 0.65, height: mh * 0.8),
        Paint()..color = const Color(0xFF3A0716),
      );
      for (final s in const [-1.0, 1.0]) {
        final pincer = Path()
          ..moveTo(mouthCenter.dx + s * mw * 0.42, mouthCenter.dy - mh * 0.2)
          ..quadraticBezierTo(
            mouthCenter.dx + s * mw * 0.65,
            mouthCenter.dy + mh * 0.65,
            mouthCenter.dx + s * mw * 0.16,
            mouthCenter.dy + mh * 0.72,
          )
          ..quadraticBezierTo(
            mouthCenter.dx + s * mw * 0.40,
            mouthCenter.dy + mh * 0.35,
            mouthCenter.dx + s * mw * 0.26,
            mouthCenter.dy - mh * 0.1,
          )
          ..close();
        canvas.drawPath(pincer, Paint()..color = clawColor);
      }
      return;
    }

    if (mouthStyle == MonsterMouthStyle.beakSnarl) {
      final beak = Path()
        ..moveTo(mouthCenter.dx - mw * 0.32, mouthCenter.dy - mh * 0.35)
        ..lineTo(mouthCenter.dx + mw * 0.32, mouthCenter.dy - mh * 0.35)
        ..lineTo(mouthCenter.dx, mouthCenter.dy + mh * 0.85)
        ..close();
      canvas.drawPath(beak, Paint()..color = const Color(0xFFFFC857));
      canvas.drawPath(
        beak,
        Paint()
          ..color = const Color(0xFF120C1C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      return;
    }

    // Open roaring jaw + fangs / tusks
    canvas.drawOval(
      Rect.fromCenter(center: mouthCenter, width: mw, height: mh),
      Paint()..color = const Color(0xFF3A0716),
    );
    if (jawOpen > 0.5) {
      canvas.drawOval(
        Rect.fromCenter(center: mouthCenter + Offset(0, mh * 0.1), width: mw * 0.62, height: mh * 0.52),
        Paint()..color = const Color(0xFFE63946),
      );
    }

    final tooth = Paint()..color = clawColor;
    if (mouthStyle == MonsterMouthStyle.tuskedUnderbite) {
      // Giant upward-curving boar/ogre tusks!
      for (final s in const [-1.0, 1.0]) {
        final tusk = Path()
          ..moveTo(mouthCenter.dx + s * mw * 0.36, mouthCenter.dy + mh * 0.45)
          ..lineTo(mouthCenter.dx + s * mw * 0.46, mouthCenter.dy - mh * 0.72)
          ..lineTo(mouthCenter.dx + s * mw * 0.22, mouthCenter.dy + mh * 0.35)
          ..close();
        canvas.drawPath(tusk, tooth);
      }
    } else {
      // Sharp upper & lower fangs
      for (int i = -2; i <= 2; i++) {
        final fx = mouthCenter.dx + i * mw * 0.17;
        final fang = Path()
          ..moveTo(fx - headR * 0.07, mouthCenter.dy - mh * 0.42)
          ..lineTo(fx, mouthCenter.dy - mh * 0.04)
          ..lineTo(fx + headR * 0.07, mouthCenter.dy - mh * 0.42)
          ..close();
        canvas.drawPath(fang, tooth);
      }
    }
  }
}

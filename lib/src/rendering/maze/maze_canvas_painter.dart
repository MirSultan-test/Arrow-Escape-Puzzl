import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engine/maze/maze_game_engine.dart';
import '../../models/maze/character_animation_state.dart';
import '../../models/maze/combat_models.dart';
import '../../models/maze/delivery_state.dart';
import '../../models/maze/maze_level.dart';
import '../../models/maze/monster.dart';
import '../../models/maze/truck_defense_models.dart';
import 'boss_cage_illustrator.dart';
import 'character_illustrator.dart';
import 'food_illustrator.dart';
import 'skeletal_character_animator.dart';
import 'unique_monster_illustrator.dart';

/// Camera & world-to-screen transform helper shared between painter and tap-to-move input.
/// V3.1: Dock sits compactly BELOW the maze so 100% of horizontal width expands the maze!
class MazeViewportTransform {
  static const double bottomDockRows = 1.68;

  final double tileSize;
  final double originX;
  final double originY;
  final bool isCameraPanning;

  const MazeViewportTransform({
    required this.tileSize,
    required this.originX,
    required this.originY,
    required this.isCameraPanning,
  });

  Offset worldToScreen(double wx, double wy) =>
      Offset(originX + wx * tileSize, originY + wy * tileSize);

  Offset screenToWorld(Offset localPos) => Offset(
        (localPos.dx - originX) / tileSize,
        (localPos.dy - originY) / tileSize,
      );

  GridPoint screenToCell(Offset localPos) {
    final wx = (localPos.dx - originX) / tileSize;
    final wy = (localPos.dy - originY) / tileSize;
    return GridPoint(wx.floor(), wy.floor());
  }

  /// Computes a tight, space-maximizing transform fitting the full maze width
  /// and compact bottom delivery dock cleanly inside the viewport.
  static MazeViewportTransform compute(
    Size canvasSize,
    MazeGameEngine engine,
  ) {
    final level = engine.level;
    final totalWorldCols = level.cols.toDouble();
    final totalWorldRows = level.rows + bottomDockRows;

    const padX = 6.0;
    const padY = 4.0;
    final availW = math.max(100.0, canvasSize.width - padX * 2);
    final availH = math.max(100.0, canvasSize.height - padY * 2);

    final fitTileW = availW / totalWorldCols;
    final fitTileH = availH / totalWorldRows;
    final fitTile = math.min(fitTileW, fitTileH);

    // Keep tiles large & crisp; enable smooth camera-follow only for very large mazes
    const minReadableTile = 26.0;
    final tileSize = math.max(fitTile, minReadableTile).clamp(18.0, 56.0);
    final worldPxW = totalWorldCols * tileSize;
    final worldPxH = totalWorldRows * tileSize;

    final needsPanX = worldPxW > availW + 1.0;
    final needsPanY = worldPxH > availH + 1.0;

    double originX;
    double originY;

    if (!needsPanX) {
      originX = (canvasSize.width - worldPxW) / 2.0;
    } else {
      final focusX = engine.phase.isCutsceneOrLoading
          ? level.exitCell.centerX
          : engine.playerX;
      final desired = canvasSize.width / 2.0 - focusX * tileSize;
      final minOriginX = canvasSize.width - padX - worldPxW;
      const maxOriginX = padX;
      originX = desired.clamp(minOriginX, maxOriginX);
    }

    if (!needsPanY) {
      // V3.3 Layout Redesign: Anchor maze cleanly near the top (eliminating
      // wasted cream space above!) so the bottom Dock, Monster Cage & Winding
      // Road Preview fill the lower space naturally without shrinking the maze.
      final spareY = canvasSize.height - worldPxH;
      originY = padY + math.min(6.0, math.max(0.0, spareY * 0.05));
    } else {
      final focusY = engine.phase.isCutsceneOrLoading
          ? (level.rows + 0.6)
          : engine.playerY;
      final desired = canvasSize.height / 2.0 - focusY * tileSize;
      final minOriginY = canvasSize.height - padY - worldPxH;
      const maxOriginY = padY;
      originY = desired.clamp(minOriginY, maxOriginY);
    }

    return MazeViewportTransform(
      tileSize: tileSize,
      originX: originX,
      originY: originY,
      isCameraPanning: needsPanX || needsPanY,
    );
  }
}

/// Renders the upgraded V3.1 2.5D Food Maze Delivery Adventure world:
/// - Expanded full-width maze with slim, connected garden-hedge walls
/// - Compact horizontal Delivery Dock directly below the maze exit
/// - Collectible Health Hearts with healing glow
/// - Food items, Monsters, Courier, Collector, Delivery Truck, Popups & optional Minimap
class MazeCanvasPainter extends CustomPainter {
  final MazeGameEngine engine;
  final bool reducedMotion;

  MazeCanvasPainter({
    required this.engine,
    this.reducedMotion = false,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final level = engine.level;
    final district = level.districtInfo;
    final vp = MazeViewportTransform.compute(size, engine);
    final ts = vp.tileSize;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1. Maze Floor Panel (clipped neatly inside the slim outer perimeter hedge!)
    final inset = ts * 0.22;
    final mazeRect = Rect.fromLTRB(
      vp.originX + inset,
      vp.originY + inset,
      vp.originX + level.cols * ts - inset,
      vp.originY + level.rows * ts - inset,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          mazeRect.shift(const Offset(0, 4)), const Radius.circular(14)),
      Paint()..color = const Color(0x22243447),
    );

    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(mazeRect, const Radius.circular(12)));
    final floorLight = Paint()..color = Color(district.floorLightHex);
    final floorDark = Paint()..color = Color(district.floorDarkHex);
    final exitPadPaint = Paint()..color = const Color(0xFFD8F3DC);

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        final rect = Rect.fromLTWH(
          vp.originX + c * ts,
          vp.originY + r * ts,
          ts + 0.5,
          ts + 0.5,
        );
        if (level.exitCell.col == c && level.exitCell.row == r) {
          canvas.drawRect(rect, exitPadPaint);
        } else {
          canvas.drawRect(rect, (r + c).isEven ? floorLight : floorDark);
        }
      }
    }
    canvas.restore();

    // 2. Compact Horizontal Delivery Dock + Reinforced Monster Cage + Scenic Road Preview below
    final dockGeometry = _computeDockAndCageRects(vp, level, size);
    _drawLowerRoadPreview(canvas, size, dockGeometry.dockRect, dockGeometry.cageRect, district);
    _drawBottomDeliveryDock(canvas, vp, level, district, dockGeometry.dockRect);

    // 3. Subtle Patrol Route Guides
    _drawPatrolGuides(canvas, vp, level);

    // 4. Exit Downward Chevron Signage
    _drawExitSignage(canvas, vp, level);

    // 5. Optional Tap-to-Move & Hint Breadcrumb Trails
    _drawNavTrails(canvas, vp);

    // 6. Redesigned Slim Connected 2.5D Garden-Hedge Maze Walls
    _drawSlimConnectedWalls(canvas, vp, level, district);

    // 6b. V3.5 Invalid-Wall Drag Indicator (drawn ABOVE walls so blocked X is crystal-clear!)
    _drawInvalidDragIndicator(canvas, vp);

    // 7. Collectible Health Recovery Hearts & Combat Supply/Shield Pickups
    for (final hp in engine.activeHealthPickups) {
      final bob = reducedMotion
          ? 0.0
          : math.sin(engine.elapsedTime * 4.2 + hp.col * 1.3) * ts * 0.07;
      final pos = vp.worldToScreen(hp.col + 0.5, hp.row + 0.5) + Offset(0, bob);
      _drawHealthPickup(canvas, pos, ts * 0.34, engine.health < engine.maxHealth);
    }

    for (final cp in engine.activeCombatPickups) {
      final bob = reducedMotion
          ? 0.0
          : math.sin(engine.elapsedTime * 4.0 + cp.col * 1.7) * ts * 0.06;
      final pos = vp.worldToScreen(cp.col + 0.5, cp.row + 0.5) + Offset(0, bob);
      _drawCombatPickup(canvas, pos, ts * 0.34, cp.type);
    }

    // 7b. Active Poison Clouds & Food Decoys on the floor
    for (final cloud in engine.poisonClouds) {
      _drawPoisonCloud(canvas, vp.worldToScreen(cloud.x, cloud.y), cloud.radius * ts, cloud.alpha);
    }
    for (final decoy in engine.decoys) {
      _drawFoodDecoy(canvas, vp.worldToScreen(decoy.x, decoy.y), ts * 0.36);
    }

    // 8. On-Map Food Items
    for (final food in engine.onMapFoods) {
      final bob = reducedMotion
          ? 0.0
          : math.sin(engine.elapsedTime * 3.8 + food.spawnCol + food.spawnRow) *
              ts *
              0.07;
      final basePos = vp.worldToScreen(food.spawnCol + 0.5, food.spawnRow + 0.5);
      final pulse = reducedMotion
          ? 0.43
          : 0.41 + math.sin(engine.elapsedTime * 4.5 + food.spawnCol) * 0.04;
      canvas.drawCircle(
        basePos,
        ts * pulse,
        Paint()..color = const Color(0x33FFC857),
      );
      FoodIllustrator.drawFood(
        canvas,
        basePos + Offset(0, bob),
        ts * 0.38,
        food.type,
        conditionPercent: food.conditionPercent,
      );
    }

    // 9. Reinforced Monster Cage (left of Dock), Dock Worker & Delivery Truck
    final td = engine.truckDefense;
    final dockRect = dockGeometry.dockRect;
    final cageRect = dockGeometry.cageRect;

    // Draw Reinforced Fantasy Monster Cage with visible unique Giant Boss inside!
    BossCageIllustrator.drawMonsterCage(
      canvas,
      cageRect,
      cageState: td.cageState,
      bossType: td.boss.type,
      bossAppearance: td.boss.appearance,
      levelId: engine.level.id,
      shakeIntensity: td.cageShakeIntensity,
      animPhase: td.boss.animPhase,
      elapsed: engine.elapsedTime,
      showBossInside: td.cageState != BossCageState.escaped &&
          td.cageState != BossCageState.doorOpening,
    );

    // During cageEscapeCutscene door-opening, draw Giant Boss bursting out of the cage!
    if (td.cageState == BossCageState.doorOpening ||
        (engine.phase == MazeGamePhase.cageEscapeCutscene &&
            td.cageState == BossCageState.escaped)) {
      final leapT = td.arenaTransitionProgress.clamp(0.0, 1.0);
      final escapePos = Offset(
        cageRect.center.dx + leapT * ts * 1.4,
        cageRect.center.dy + leapT * ts * 0.65,
      );
      SkeletalCharacterAnimator.drawGiantBossRig(
        canvas,
        escapePos,
        ts * 0.66,
        BossAnimSnapshot(
          bossType: td.boss.type,
          appearance: td.boss.appearance,
          state: BossAnimState.run,
          expression: BossExpression.furiousRoar,
          facingAngle: 0.2,
          walkCyclePhase: td.boss.animPhase,
          stateProgress: leapT,
          elapsed: engine.elapsedTime,
          hpRatio: 1.0,
          isCaged: false,
        ),
      );
    }

    // Articulated Dock Worker (peaceful waving/loading before escape; draws knife ONLY after escape!)
    final collectorCenter = Offset(
      dockRect.left + dockRect.width * 0.34,
      dockRect.center.dy + ts * 0.04,
    );
    final truckCenter = Offset(
      dockRect.left + dockRect.width * 0.72,
      dockRect.center.dy + ts * 0.04,
    );

    SkeletalCharacterAnimator.drawDockWorkerRig(
      canvas,
      collectorCenter,
      ts * 0.44,
      engine.buildMazeDockWorkerAnimSnapshot(),
    );

    CharacterIllustrator.drawDeliveryTruck(
      canvas,
      truckCenter,
      ts * 0.60,
      state: engine.truckState,
      driveOffset: engine.truckDriveOffset,
      loadedFoods: engine.truckLoadedFoods,
      elapsed: engine.elapsedTime,
    );

    // 10. V3.5 Unique Articulated Maze Monsters (Per-Level Anatomy & 10 Movement Behaviors)
    for (final monster in engine.monsters) {
      final pos = vp.worldToScreen(monster.x, monster.y);
      UniqueMonsterIllustrator.drawUniqueMazeMonster(
        canvas,
        pos,
        ts * 0.46,
        monster,
      );
    }

    // 11. Articulated Human Delivery Adventurer Courier (with 9 facial expressions & live Bow/Blaster rig!)
    final courierPos = vp.worldToScreen(engine.playerX, engine.playerY);
    SkeletalCharacterAnimator.drawCourierRig(
      canvas,
      courierPos,
      ts * 0.48,
      engine.buildCourierAnimSnapshot(),
    );

    // 11b. Active Projectiles & Combat Visual Effects
    for (final p in engine.projectiles) {
      if (p.active) {
        _drawProjectile(canvas, vp.worldToScreen(p.x, p.y), ts, p);
      }
    }
    for (final effect in engine.vfx) {
      _drawCombatVfx(canvas, vp.worldToScreen(effect.x, effect.y), ts, effect);
    }

    // 12. Floating Feedback Popups
    for (final popup in engine.popups) {
      final p = popup.progress;
      final alpha = (1.0 - p * p).clamp(0.0, 1.0);
      final screenPos = vp.worldToScreen(popup.worldX, popup.worldY - p * 0.85);
      final tp = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            color: Color(popup.colorHex).withOpacity(alpha),
            fontSize: math.max(12.0, ts * 0.36),
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Colors.white.withOpacity(alpha * 0.95),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, screenPos - Offset(tp.width / 2, tp.height / 2));
    }

    canvas.restore();

    // 13. Compact Overview Minimap only when camera panning is active
    if (vp.isCameraPanning) {
      _drawMinimap(canvas, size, level);
    }
  }

  /// Computes clean non-overlapping rectangles for the Delivery Dock and the
  /// adjacent reinforced Monster Cage (placed on the left side of the Dock!).
  ({Rect dockRect, Rect cageRect}) _computeDockAndCageRects(
    MazeViewportTransform vp,
    MazeLevel level,
    Size canvasSize,
  ) {
    final ts = vp.tileSize;
    final exitCenterX = vp.originX + level.exitCell.centerX * ts;
    final mazeLeft = vp.originX + ts * 0.2;
    final mazeRight = vp.originX + level.cols * ts - ts * 0.2;
    final mazeBottomY = vp.originY + level.rows * ts;

    final dockHeight = ts * 1.38;
    final dockTop = mazeBottomY + ts * 0.20;
    final cageWidth = math.max(ts * 1.72, 54.0);
    final gap = math.max(ts * 0.22, 6.0);

    final maxDockW = math.max(ts * 3.8, (mazeRight - mazeLeft) - cageWidth - gap);
    final dockWidth = math.min(maxDockW, ts * 5.2);

    // Keep the Dock aligned cleanly with the maze exit while guaranteeing room
    // on its LEFT side for the giant Monster Cage!
    final minDockLeft = mazeLeft + cageWidth + gap;
    final maxDockLeft = math.max(minDockLeft, mazeRight - dockWidth);
    final desiredDockLeft = exitCenterX - dockWidth * 0.42;
    final dockLeft = desiredDockLeft.clamp(minDockLeft, maxDockLeft);

    final dockRect = Rect.fromLTWH(dockLeft, dockTop, dockWidth, dockHeight);
    final cageRect = Rect.fromLTWH(
      dockRect.left - gap - cageWidth,
      dockTop - ts * 0.04,
      cageWidth,
      dockHeight + ts * 0.08,
    );
    return (dockRect: dockRect, cageRect: cageRect);
  }

  /// Renders a lush scenic preview of the winding delivery road in any natural
  /// vertical space remaining below the Dock & Cage (never shrinks the maze!).
  void _drawLowerRoadPreview(
    Canvas canvas,
    Size canvasSize,
    Rect dockRect,
    Rect cageRect,
    MazeDistrictInfo district,
  ) {
    final startY = dockRect.bottom + 8.0;
    final availH = canvasSize.height - startY - 6.0;
    if (availH < 32.0) return;

    final previewRect = Rect.fromLTWH(8, startY, canvasSize.width - 16, availH);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(previewRect, const Radius.circular(14)),
    );

    // Subtle meadow/courtyard panel matching district palette
    final Color lawnColor = district.id == 1
        ? const Color(0xFFE7F5D6)
        : (district.id == 2
            ? const Color(0xFFF6E6CF)
            : (district.id == 3
                ? const Color(0xFFDCEEE0)
                : (district.id == 4
                    ? const Color(0xFFEAE2F3)
                    : const Color(0xFFE3EDF6))));
    canvas.drawRect(previewRect, Paint()..color = lawnColor);

    // Winding cartoon S-curved road connecting smoothly from the right edge of the Dock!
    final leftX = previewRect.left + 32.0;
    final rightX = previewRect.right - 32.0;
    final roadPath = Path();
    final exitRightX = math.min(rightX, dockRect.right + 12.0);
    roadPath.moveTo(exitRightX, startY - 6.0);

    if (availH >= 85.0) {
      // Full double S-bend road preview (just like the user's Level 18 red sketch!)
      final y1 = startY + availH * 0.24;
      final y2 = startY + availH * 0.56;
      final y3 = startY + availH * 0.84;
      roadPath.cubicTo(rightX + 12, startY + 8, rightX + 6, y1, (leftX + rightX) * 0.5, y1);
      roadPath.cubicTo(leftX - 18, y1, leftX - 18, y2, (leftX + rightX) * 0.5, y2);
      roadPath.cubicTo(rightX + 18, y2, rightX + 18, y3, leftX + 44, y3);
    } else {
      // Compact graceful single S-curve for shorter phones
      final midY = startY + availH * 0.52;
      roadPath.cubicTo(
        rightX + 10,
        startY + 6,
        (leftX + rightX) * 0.55,
        midY,
        leftX + 36,
        midY + availH * 0.18,
      );
    }

    final roadW = math.min(26.0, math.max(16.0, availH * 0.19));
    // Road shoulder curb
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFFE6DAC3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadW + 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Road asphalt body
    canvas.drawPath(
      roadPath,
      Paint()
        ..color = const Color(0xFF7B8794)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Dashed road lane markings
    for (final metric in roadPath.computeMetrics()) {
      for (double d = 10; d < metric.length - 12; d += 18) {
        final seg = metric.extractPath(d, math.min(metric.length, d + 9));
        canvas.drawPath(
          seg,
          Paint()
            ..color = const Color(0xCCFFE8A3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }
      // Small destination flag marker at road end
      final endTan = metric.getTangentForOffset(metric.length);
      if (endTan != null) {
        final destPos = endTan.position;
        canvas.drawCircle(destPos, 11, Paint()..color = const Color(0xFF5DBB75));
        canvas.drawCircle(
          destPos,
          11,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
        final flagTp = TextPainter(
          text: const TextSpan(
            text: 'FINISH',
            style: TextStyle(
              color: Color(0xFF2E7D32),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: Colors.white, blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        flagTp.paint(canvas, destPos + Offset(14, -flagTp.height / 2));
      }
    }

    // Subtle decorative roadside foliage tufts
    final bushPaint = Paint()..color = Color(district.wallTopHex).withOpacity(0.55);
    canvas.drawCircle(Offset(previewRect.left + 16, previewRect.top + 16), 8, bushPaint);
    canvas.drawCircle(Offset(previewRect.right - 16, previewRect.bottom - 14), 9, bushPaint);

    // Subtle "DELIVERY ROAD" corner label
    final labelTp = TextPainter(
      text: const TextSpan(
        text: 'DELIVERY ROAD',
        style: TextStyle(
          color: Color(0xAA475569),
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas, Offset(previewRect.right - labelTp.width - 10, previewRect.top + 6));

    canvas.restore();
  }

  /// Draws the compact horizontal Delivery Dock directly beneath the maze exit.
  void _drawBottomDeliveryDock(
    Canvas canvas,
    MazeViewportTransform vp,
    MazeLevel level,
    MazeDistrictInfo district,
    Rect dockRect,
  ) {
    final ts = vp.tileSize;
    final exitCenterX = vp.originX + level.exitCell.centerX * ts;
    final mazeBottomY = vp.originY + level.rows * ts;

    // Connecting ramp neck from bottom doorway straight into the dock bay
    final neckRect = Rect.fromLTWH(
      exitCenterX - ts * 0.46,
      mazeBottomY - ts * 0.16,
      ts * 0.92,
      ts * 0.45,
    );
    canvas.drawRect(neckRect, Paint()..color = const Color(0xFFD8F3DC));

    // Subtle elevation shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          dockRect.shift(const Offset(0, 3)), const Radius.circular(16)),
      Paint()..color = const Color(0x1E243447),
    );
    // Warm mint loading lane surface
    canvas.drawRRect(
      RRect.fromRectAndRadius(dockRect, const Radius.circular(16)),
      Paint()..color = const Color(0xFFEAF7EE),
    );
    // Crisp border matching district green
    canvas.drawRRect(
      RRect.fromRectAndRadius(dockRect, const Radius.circular(16)),
      Paint()
        ..color = const Color(0xFF5DBB75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Subtle road centerline dashes inside the loading bay
    final dashY = dockRect.bottom - ts * 0.24;
    final dashPaint = Paint()
      ..color = const Color(0x555DBB75)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (double x = dockRect.left + 14; x < dockRect.right - 16; x += 14) {
      canvas.drawLine(Offset(x, dashY), Offset(x + 7, dashY), dashPaint);
    }

    // Small neat "DOCK" badge on left corner of loading bay
    final tp = TextPainter(
      text: TextSpan(
        text: 'DOCK',
        style: TextStyle(
          color: const Color(0xFF2E7D32),
          fontSize: math.max(8.5, ts * 0.25),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(dockRect.left + 10, dockRect.top + 6));
  }

  /// Renders slim, connected 2.5D garden-hedge walls (~28% thinner than full tiles)
  /// with soft rounded corners, leaf details, highlights, and district styling.
  void _drawSlimConnectedWalls(
    Canvas canvas,
    MazeViewportTransform vp,
    MazeLevel level,
    MazeDistrictInfo district,
  ) {
    final ts = vp.tileSize;
    final wallThick = ts * 0.66; // ~30% slimmer than full square tile blocks!
    final halfT = wallThick / 2.0;
    final depth = math.max(2.5, ts * 0.13);
    final cornerR = Radius.circular(halfT * 0.72);

    final shadowPaint = Paint()..color = const Color(0x1C243447);
    final sidePaint = Paint()..color = Color(district.wallSideHex);
    final topPaint = Paint()..color = Color(district.wallTopHex);
    final trimPaint = Paint()..color = Color(district.wallTrimHex);

    // Helper builds a connected slim path across all adjacent wall neighbors
    Path buildConnectedShape(double dyOffset, double shrink) {
      final path = Path();
      final t = halfT - shrink;
      for (int r = 0; r < level.rows; r++) {
        for (int c = 0; c < level.cols; c++) {
          if (!level.isWall(c, r)) continue;
          final cx = vp.originX + (c + 0.5) * ts;
          final cy = vp.originY + (r + 0.5) * ts + dyOffset;

          // Center rounded hub
          path.addRRect(RRect.fromRectAndRadius(
            Rect.fromLTRB(cx - t, cy - t, cx + t, cy + t),
            cornerR,
          ));

          // Seamless bridge right
          if (c + 1 < level.cols && level.isWall(c + 1, r)) {
            path.addRect(Rect.fromLTRB(cx, cy - t, cx + ts, cy + t));
          }
          // Seamless bridge down
          if (r + 1 < level.rows && level.isWall(c, r + 1)) {
            path.addRect(Rect.fromLTRB(cx - t, cy, cx + t, cy + ts));
          }
        }
      }
      return path;
    }

    // Pass 1: Soft ground shadow under hedges
    canvas.drawPath(buildConnectedShape(depth * 1.45, 0.0), shadowPaint);

    // Pass 2: 2.5D darker hedge/wall base extrusion
    canvas.drawPath(buildConnectedShape(depth * 0.55, 0.0), sidePaint);

    // Pass 3: Main slim top hedge/wall surface
    canvas.drawPath(buildConnectedShape(-depth * 0.35, 0.2), topPaint);

    // Pass 4: Slim highlight crest & district miniature details (leaves/blossoms/bricks)
    final leafPaint = Paint()..color = Color(district.wallTrimHex);
    final blossomPaint = Paint()..color = const Color(0xFFFFE8A3);
    final darkLeafPaint = Paint()
      ..color = Color(district.wallSideHex).withOpacity(0.45);

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        if (!level.isWall(c, r)) continue;
        final cx = vp.originX + (c + 0.5) * ts;
        final cy = vp.originY + (r + 0.5) * ts - depth * 0.4;

        // Top sunlit highlight ribbon
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx, cy - halfT * 0.34),
              width: wallThick * 0.62,
              height: math.max(2.0, wallThick * 0.16),
            ),
            const Radius.circular(3),
          ),
          trimPaint,
        );

        // Environmental foliage / texture accents by district
        final hash = (r * 31 + c * 17) % 7;
        if (district.id == 1 || district.id == 3) {
          // Sunny Orchard & Forest: delicate leaf puffs + occasional tiny blossoms
          if (hash == 0 || hash == 3) {
            canvas.drawCircle(
                Offset(cx - halfT * 0.32, cy + halfT * 0.12), ts * 0.08, leafPaint);
            canvas.drawCircle(
                Offset(cx + halfT * 0.28, cy - halfT * 0.08), ts * 0.07, darkLeafPaint);
          }
          if (district.id == 1 && hash == 2) {
            canvas.drawCircle(
                Offset(cx + halfT * 0.22, cy + halfT * 0.16), ts * 0.065, blossomPaint);
          }
        } else if (district.id == 2) {
          // Garden Market: neat brick seam ticks
          if (hash.isEven) {
            canvas.drawLine(
              Offset(cx - halfT * 0.35, cy + halfT * 0.14),
              Offset(cx + halfT * 0.35, cy + halfT * 0.14),
              Paint()
                ..color = Color(district.wallSideHex).withOpacity(0.4)
                ..strokeWidth = 1.2,
            );
          }
        } else {
          // Monster Valley & City: clean geometric bevel dot
          if (hash == 1 || hash == 5) {
            canvas.drawCircle(
                Offset(cx, cy + halfT * 0.15), ts * 0.05, darkLeafPaint);
          }
        }
      }
    }
  }

  /// Renders a collectible Health Heart pickup inside a soft healing halo.
  void _drawHealthPickup(
    Canvas canvas,
    Offset center,
    double r,
    bool playerNeedsHealth,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Pulsing soft healing halo
    final pulse = reducedMotion
        ? 1.18
        : 1.12 + math.sin(engine.elapsedTime * 5.2) * 0.12;
    canvas.drawCircle(
      Offset.zero,
      r * pulse,
      Paint()
        ..color = playerNeedsHealth
            ? const Color(0x44FF4D6D)
            : const Color(0x285DBB75),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.96,
      Paint()..color = const Color(0xEEFFFFFF),
    );
    canvas.drawCircle(
      Offset.zero,
      r * 0.96,
      Paint()
        ..color = const Color(0xFFFF4D6D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.13,
    );

    // Plump ruby heart silhouette
    final hr = r * 0.62;
    final heart = Path()
      ..moveTo(0, hr * 0.78)
      ..cubicTo(-hr * 1.15, hr * 0.05, -hr * 1.0, -hr * 0.92, 0, -hr * 0.32)
      ..cubicTo(hr * 1.0, -hr * 0.92, hr * 1.15, hr * 0.05, 0, hr * 0.78)
      ..close();

    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF758F), Color(0xFFE63946)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: hr)),
    );

    // White shine dot
    canvas.drawCircle(
      Offset(-hr * 0.34, -hr * 0.28),
      hr * 0.16,
      Paint()..color = const Color(0xAAFFFFFF),
    );

    // Tiny green '+' sparkle badge at top-right so it's unmistakable from food
    final plusCenter = Offset(r * 0.68, -r * 0.65);
    canvas.drawCircle(plusCenter, r * 0.32, Paint()..color = const Color(0xFF5DBB75));
    final plusPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        plusCenter + Offset(-r * 0.15, 0), plusCenter + Offset(r * 0.15, 0), plusPaint);
    canvas.drawLine(
        plusCenter + Offset(0, -r * 0.15), plusCenter + Offset(0, r * 0.15), plusPaint);

    canvas.restore();
  }

  void _drawCombatPickup(
    Canvas canvas,
    Offset center,
    double r,
    CombatPickupType type,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    Color ringColor;
    switch (type) {
      case CombatPickupType.arrows:
        ringColor = const Color(0xFFD97706);
        break;
      case CombatPickupType.energyCharges:
        ringColor = const Color(0xFF9333EA);
        break;
      case CombatPickupType.freezeOrbs:
        ringColor = const Color(0xFF0284C7);
        break;
      case CombatPickupType.shield:
        ringColor = const Color(0xFF0EA5E9);
        break;
    }

    canvas.drawCircle(Offset.zero, r * 0.98, Paint()..color = const Color(0xEEFFFFFF));
    canvas.drawCircle(
      Offset.zero,
      r * 0.98,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );

    if (type == CombatPickupType.shield) {
      final shield = Path()
        ..moveTo(0, -r * 0.62)
        ..lineTo(r * 0.54, -r * 0.34)
        ..quadraticBezierTo(r * 0.52, r * 0.32, 0, r * 0.65)
        ..quadraticBezierTo(-r * 0.52, r * 0.32, -r * 0.54, -r * 0.34)
        ..close();
      canvas.drawPath(shield, Paint()..color = const Color(0xFF38BDF8));
      canvas.drawPath(
        shield,
        Paint()
          ..color = const Color(0xFF0369A1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1,
      );
    } else if (type == CombatPickupType.arrows) {
      final shaft = Paint()
        ..color = const Color(0xFF8D5524)
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(-r * 0.45, r * 0.45), Offset(r * 0.45, -r * 0.45), shaft);
      final tip = Path()
        ..moveTo(r * 0.55, -r * 0.55)
        ..lineTo(r * 0.15, -r * 0.48)
        ..lineTo(r * 0.48, -r * 0.15)
        ..close();
      canvas.drawPath(tip, Paint()..color = const Color(0xFFE63946));
    } else if (type == CombatPickupType.freezeOrbs) {
      canvas.drawCircle(Offset.zero, r * 0.52, Paint()..color = const Color(0xFF38BDF8));
      canvas.drawCircle(Offset(-r * 0.14, -r * 0.14), r * 0.18, Paint()..color = Colors.white);
    } else {
      // Energy bolt crystal
      final bolt = Path()
        ..moveTo(r * 0.12, -r * 0.6)
        ..lineTo(-r * 0.35, r * 0.05)
        ..lineTo(r * 0.05, r * 0.05)
        ..lineTo(-r * 0.12, r * 0.6)
        ..lineTo(r * 0.38, -r * 0.05)
        ..lineTo(-r * 0.04, -r * 0.05)
        ..close();
      canvas.drawPath(bolt, Paint()..color = const Color(0xFFA855F7));
    }

    canvas.restore();
  }

  void _drawPoisonCloud(Canvas canvas, Offset center, double radius, double alpha) {
    final a = (alpha * 0.42).clamp(0.0, 0.5);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Color.fromRGBO(147, 51, 234, a * 0.75),
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.28, -radius * 0.18),
      radius * 0.52,
      Paint()..color = Color.fromRGBO(132, 204, 22, a),
    );
    canvas.drawCircle(
      center + Offset(radius * 0.3, radius * 0.2),
      radius * 0.46,
      Paint()..color = Color.fromRGBO(168, 85, 247, a),
    );
  }

  void _drawFoodDecoy(Canvas canvas, Offset center, double r) {
    final pulse = 1.0 + math.sin(engine.elapsedTime * 6.0) * 0.25;
    canvas.drawCircle(
      center,
      r * 1.45 * pulse,
      Paint()
        ..color = const Color(0x55FFC857)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    canvas.drawCircle(center, r * 0.9, Paint()..color = const Color(0xFFFFE082));
    canvas.drawCircle(center, r * 0.55, Paint()..color = const Color(0xFFFF715B));
  }

  void _drawProjectile(Canvas canvas, Offset pos, double ts, ProjectileEntity p) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(p.angle);

    if (p.weapon == WeaponType.bow) {
      // Feathered wooden arrow
      canvas.drawLine(
        Offset(-ts * 0.34, 0),
        Offset(ts * 0.28, 0),
        Paint()
          ..color = const Color(0xFF7A4424)
          ..strokeWidth = math.max(2.4, ts * 0.08)
          ..strokeCap = StrokeCap.round,
      );
      final tip = Path()
        ..moveTo(ts * 0.38, 0)
        ..lineTo(ts * 0.16, -ts * 0.11)
        ..lineTo(ts * 0.16, ts * 0.11)
        ..close();
      canvas.drawPath(tip, Paint()..color = const Color(0xFFFFC857));
      // Fletching feathers
      canvas.drawLine(
        Offset(-ts * 0.34, 0),
        Offset(-ts * 0.22, -ts * 0.12),
        Paint()
          ..color = const Color(0xFFFF4D6D)
          ..strokeWidth = 2.0,
      );
      canvas.drawLine(
        Offset(-ts * 0.34, 0),
        Offset(-ts * 0.22, ts * 0.12),
        Paint()
          ..color = const Color(0xFFFF4D6D)
          ..strokeWidth = 2.0,
      );
    } else if (p.weapon == WeaponType.energyBlaster) {
      // Glowing violet-cyan energy plasma bolt
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: ts * 0.62, height: ts * 0.28),
        Paint()..color = const Color(0x66A855F7),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: ts * 0.44, height: ts * 0.18),
        Paint()..color = const Color(0xFF38BDF8),
      );
      canvas.drawCircle(Offset(ts * 0.1, 0), ts * 0.07, Paint()..color = Colors.white);
    } else {
      // Magical Freeze Orb
      canvas.drawCircle(Offset.zero, ts * 0.28, Paint()..color = const Color(0x6638BDF8));
      canvas.drawCircle(Offset.zero, ts * 0.19, Paint()..color = const Color(0xFF0EA5E9));
      canvas.drawCircle(Offset(-ts * 0.05, -ts * 0.05), ts * 0.07, Paint()..color = Colors.white);
    }

    canvas.restore();
  }

  void _drawCombatVfx(Canvas canvas, Offset pos, double ts, CombatVfx fx) {
    final p = fx.progress;
    final alpha = (1.0 - p).clamp(0.0, 1.0);
    final baseColor = Color(fx.colorHex);

    if (fx.type == CombatVfxType.meleeSlash) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(fx.angle);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: fx.maxRadius * ts * 0.6),
        -math.pi * 0.42,
        math.pi * 0.84,
        false,
        Paint()
          ..color = baseColor.withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ts * 0.22 * alpha
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    } else {
      // Expanding shockwave / burst ring (stun pulse, hit, freeze, shield break, defeat puff)
      final radius = fx.maxRadius * ts * (0.25 + p * 0.75);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = baseColor.withOpacity(alpha * 0.28)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = baseColor.withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, ts * 0.12 * alpha),
      );
    }
  }

  void _drawPatrolGuides(
    Canvas canvas,
    MazeViewportTransform vp,
    MazeLevel level,
  ) {
    final dotPaint = Paint()
      ..color = const Color(0x2D243447)
      ..style = PaintingStyle.fill;
    for (final m in level.monsters) {
      if (m.patrolPath.length <= 1) continue;
      for (int i = 0; i < m.patrolPath.length - 1; i++) {
        final a = vp.worldToScreen(
            m.patrolPath[i].centerX, m.patrolPath[i].centerY);
        final b = vp.worldToScreen(
            m.patrolPath[i + 1].centerX, m.patrolPath[i + 1].centerY);
        const steps = 4;
        for (int s = 0; s <= steps; s++) {
          canvas.drawCircle(
            Offset.lerp(a, b, s / steps)!,
            vp.tileSize * 0.055,
            dotPaint,
          );
        }
      }
    }
  }

  /// Pulsing downward chevron pointing out of the bottom maze exit into the Dock.
  void _drawExitSignage(
    Canvas canvas,
    MazeViewportTransform vp,
    MazeLevel level,
  ) {
    final ts = vp.tileSize;
    final center = vp.worldToScreen(level.exitCell.centerX, level.exitCell.centerY);
    final pulse = reducedMotion
        ? 0.0
        : math.sin(engine.elapsedTime * 5.0) * ts * 0.08;
    final arrowPaint = Paint()
      ..color = engine.carriedFoods.isNotEmpty
          ? const Color(0xFF2E7D32)
          : const Color(0x995DBB75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, ts * 0.1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(center.dx - ts * 0.22, center.dy - ts * 0.14 + pulse)
      ..lineTo(center.dx, center.dy + ts * 0.16 + pulse)
      ..lineTo(center.dx + ts * 0.22, center.dy - ts * 0.14 + pulse);
    canvas.drawPath(path, arrowPaint);
  }

  void _drawNavTrails(Canvas canvas, MazeViewportTransform vp) {
    final ts = vp.tileSize;
    final routeCells = engine.previewRouteCells;
    final drawing = engine.isDrawingRoute;

    // 1. V3.5 Drag-to-Move / Tap-to-Move Active Route Polyline & Indicators
    if (routeCells.isNotEmpty) {
      final courierPos = vp.worldToScreen(engine.playerX, engine.playerY);
      final pts = <Offset>[
        courierPos,
        for (final c in routeCells) vp.worldToScreen(c.centerX, c.centerY),
      ];

      // Determine accent color based on destination (Gold for Food, Emerald for Dock, Teal otherwise)
      final dest = routeCells.last;
      final targetsFood = engine.onMapFoods.any(
        (f) => f.spawnCol == dest.col && f.spawnRow == dest.row,
      );
      final targetsExit = dest == engine.level.exitCell;
      final Color accentColor = targetsFood
          ? const Color(0xFFFFB703)
          : targetsExit
              ? const Color(0xFF2EC4B6)
              : const Color(0xFF00B4D8);
      final Color coreColor = drawing
          ? accentColor
          : accentColor.withOpacity(0.86);

      // Build smooth route polyline
      if (pts.length >= 2) {
        final routePath = Path()..moveTo(pts.first.dx, pts.first.dy);
        for (int i = 1; i < pts.length; i++) {
          routePath.lineTo(pts[i].dx, pts[i].dy);
        }

        // Soft outer luminous halo
        canvas.drawPath(
          routePath,
          Paint()
            ..color = coreColor.withOpacity(drawing ? 0.34 : 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = ts * (drawing ? 0.36 : 0.28)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

        // Crisp main guide stroke
        canvas.drawPath(
          routePath,
          Paint()
            ..color = coreColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = ts * (drawing ? 0.16 : 0.12)
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

        // Bright center highlight + animated flow dots
        final flowPhase = reducedMotion ? 0.0 : (engine.elapsedTime * 3.8) % 1.0;
        for (int i = 0; i < pts.length - 1; i++) {
          final a = pts[i];
          final b = pts[i + 1];
          final mid = Offset.lerp(a, b, flowPhase)!;
          canvas.drawCircle(
            mid,
            ts * (drawing ? 0.068 : 0.052),
            Paint()..color = Colors.white.withOpacity(0.95),
          );
        }
      }

      // Start halo around Courier while actively dragging route
      if (drawing) {
        final pulse = reducedMotion
            ? 0.56
            : 0.54 + math.sin(engine.elapsedTime * 7.5) * 0.05;
        canvas.drawCircle(
          courierPos,
          ts * pulse,
          Paint()
            ..color = coreColor.withOpacity(0.18)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          courierPos,
          ts * pulse,
          Paint()
            ..color = coreColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2,
        );
      }

      // Destination target marker ring
      final destPos = vp.worldToScreen(dest.centerX, dest.centerY);
      final destPulse = reducedMotion
          ? 0.30
          : 0.28 + math.sin(engine.elapsedTime * 6.0) * 0.04;
      canvas.drawCircle(
        destPos,
        ts * destPulse,
        Paint()
          ..color = accentColor.withOpacity(0.24)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        destPos,
        ts * destPulse,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      canvas.drawCircle(
        destPos,
        ts * 0.09,
        Paint()..color = Colors.white,
      );

      // Compact tile-count pill above destination while finger is drawing
      if (drawing && routeCells.length >= 2) {
        final steps = routeCells.length - 1;
        final badgeTp = TextPainter(
          text: TextSpan(
            text: targetsFood
                ? '★ $steps'
                : targetsExit
                    ? '🚚 $steps'
                    : '$steps',
            style: TextStyle(
              color: Colors.white,
              fontSize: math.max(9.5, ts * 0.26),
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final bw = badgeTp.width + 10;
        final bh = badgeTp.height + 4;
        final badgeRect = Rect.fromCenter(
          center: Offset(destPos.dx, destPos.dy - ts * 0.52),
          width: bw,
          height: bh,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(badgeRect, const Radius.circular(8)),
          Paint()..color = const Color(0xDD1E293B),
        );
        badgeTp.paint(
          canvas,
          Offset(badgeRect.left + 5, badgeRect.top + 2),
        );
      }
    }

    // 2. On-Demand Gold Hint Trail
    if (engine.hintPath.length > 1) {
      final path = Path();
      for (int i = 0; i < engine.hintPath.length; i++) {
        final pt = vp.worldToScreen(
          engine.hintPath[i].centerX,
          engine.hintPath[i].centerY,
        );
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xAAFFC857)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ts * 0.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      for (final pt in engine.hintPath) {
        canvas.drawCircle(
          vp.worldToScreen(pt.centerX, pt.centerY),
          ts * 0.075,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  /// Draws the V3.5 crimson dashed line + crisp X badge ABOVE walls whenever the player
  /// tries to drag a route into a solid maze wall.
  void _drawInvalidDragIndicator(Canvas canvas, MazeViewportTransform vp) {
    final routeCells = engine.previewRouteCells;
    if (!engine.isDrawingRoute ||
        engine.invalidDragWorldX == null ||
        engine.invalidDragWorldY == null ||
        routeCells.isEmpty) {
      return;
    }
    final ts = vp.tileSize;
    final anchor = vp.worldToScreen(
      routeCells.last.centerX,
      routeCells.last.centerY,
    );
    final blocked = vp.worldToScreen(
      engine.invalidDragWorldX!,
      engine.invalidDragWorldY!,
    );
    final errPaint = Paint()
      ..color = const Color(0xFFE63946)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.6, ts * 0.12)
      ..strokeCap = StrokeCap.round;

    final totalLen = (blocked - anchor).distance;
    if (totalLen > 2.0) {
      final steps = math.max(2, (totalLen / (ts * 0.22)).ceil());
      for (int i = 0; i < steps; i += 2) {
        final t0 = i / steps;
        final t1 = math.min(1.0, (i + 1) / steps);
        canvas.drawLine(
          Offset.lerp(anchor, blocked, t0)!,
          Offset.lerp(anchor, blocked, t1)!,
          errPaint,
        );
      }
    }
    // High-contrast white halo + crimson circle + crisp white X
    canvas.drawCircle(
      blocked,
      ts * 0.30,
      Paint()..color = Colors.white.withOpacity(0.92),
    );
    canvas.drawCircle(
      blocked,
      ts * 0.25,
      Paint()..color = const Color(0xFFE63946),
    );
    final xSize = ts * 0.11;
    final xPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      blocked + Offset(-xSize, -xSize),
      blocked + Offset(xSize, xSize),
      xPaint,
    );
    canvas.drawLine(
      blocked + Offset(xSize, -xSize),
      blocked + Offset(-xSize, xSize),
      xPaint,
    );
  }

  void _drawMinimap(Canvas canvas, Size size, MazeLevel level) {
    const mapW = 74.0;
    final cell = mapW / level.cols;
    final mapH = cell * level.rows;
    const pad = 8.0;
    final rect = Rect.fromLTWH(pad, pad, mapW + 8, mapH + 8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      Paint()..color = const Color(0xCC243447),
    );

    const ox = pad + 4;
    const oy = pad + 4;
    final wallP = Paint()..color = const Color(0xFF5DBB75);
    final floorP = Paint()..color = const Color(0xFFFFF7E8);

    for (int r = 0; r < level.rows; r++) {
      for (int c = 0; c < level.cols; c++) {
        canvas.drawRect(
          Rect.fromLTWH(ox + c * cell, oy + r * cell, cell + 0.2, cell + 0.2),
          level.isWall(c, r) ? wallP : floorP,
        );
      }
    }

    for (final f in engine.onMapFoods) {
      canvas.drawCircle(
        Offset(ox + (f.spawnCol + 0.5) * cell, oy + (f.spawnRow + 0.5) * cell),
        math.max(2.0, cell * 0.4),
        Paint()..color = const Color(0xFFFF9F1C),
      );
    }

    for (final h in engine.activeHealthPickups) {
      canvas.drawCircle(
        Offset(ox + (h.col + 0.5) * cell, oy + (h.row + 0.5) * cell),
        math.max(2.0, cell * 0.4),
        Paint()..color = const Color(0xFFFF4D6D),
      );
    }

    for (final m in engine.monsters) {
      canvas.drawCircle(
        Offset(ox + m.x * cell, oy + m.y * cell),
        math.max(2.0, cell * 0.4),
        Paint()..color = const Color(0xFFE63946),
      );
    }

    canvas.drawCircle(
      Offset(ox + engine.playerX * cell, oy + engine.playerY * cell),
      math.max(2.6, cell * 0.5),
      Paint()..color = const Color(0xFF00B4D8),
    );
  }

  @override
  bool shouldRepaint(covariant MazeCanvasPainter oldDelegate) => true;
}

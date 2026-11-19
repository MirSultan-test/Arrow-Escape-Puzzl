import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engine/maze/maze_game_engine.dart';
import '../../models/maze/combat_models.dart';
import '../../models/maze/delivery_state.dart';
import '../../models/maze/maze_level.dart';
import '../../models/maze/truck_defense_models.dart';
import 'boss_cage_illustrator.dart';
import 'skeletal_character_animator.dart';

/// World-to-screen transform for the Full-Screen Road Battle Arena (10 x 14 world units).
/// Maximizes available viewport height & width with zero wasted blank margins!
class RoadArenaViewport {
  final double scale;
  final double originX;
  final double originY;

  const RoadArenaViewport({
    required this.scale,
    required this.originX,
    required this.originY,
  });

  Offset toScreen(double wx, double wy) =>
      Offset(originX + wx * scale, originY + wy * scale);

  static RoadArenaViewport compute(Size size) {
    final sx = size.width / RoadArenaBounds.width;
    final sy = size.height / RoadArenaBounds.height;
    final scale = math.min(sx, sy);
    final ox = (size.width - RoadArenaBounds.width * scale) / 2.0;
    final oy = (size.height - RoadArenaBounds.height * scale) / 2.0;
    return RoadArenaViewport(scale: scale, originX: ox, originY: oy);
  }
}

/// Full-Screen Winding-Road Boss Battle Arena CustomPainter (V3.3 Phase B).
class RoadBattlePainter extends CustomPainter {
  final MazeGameEngine engine;
  final bool reducedMotion;

  RoadBattlePainter({
    required this.engine,
    this.reducedMotion = false,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final td = engine.truckDefense;
    final district = engine.level.districtInfo;
    final vp = RoadArenaViewport.compute(size);
    final s = vp.scale;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 1. Lush District Terrain Backdrop (fills entire viewport cleanly — zero blank borders!)
    _drawDistrictTerrain(canvas, size, district);

    // 2. Beautiful Multi-Bend Winding Road with Curbs, Asphalt & Lane Dashes
    _drawWindingRoad(canvas, vp, td.config.road, district, td.truck.traveledDistance);

    // 3. Starting Dock Bay & Broken Monster Cage at Route Origin
    _drawStartDockAndBrokenCage(canvas, vp, td);

    // 4. Recognizable Final Destination Building at Route End
    _drawDestinationBuilding(
      canvas,
      vp,
      td.config.road.destinationPos,
      td.config.destinationType,
      arrived: engine.phase == MazeGamePhase.truckArrived ||
          engine.phase == MazeGamePhase.victory,
    );

    // 5. Roadside Scenery Decorations (trees, stalls, crates, bushes, lamps)
    for (final prop in td.config.road.props) {
      _drawSceneryProp(canvas, vp.toScreen(prop.x, prop.y), s * prop.scale, prop.kind, district);
    }

    // 6. One-Use Roadside Repair Kit Pickup
    if (!td.repairKit.collected) {
      _drawRepairKit(
        canvas,
        vp.toScreen(td.repairKit.x, td.repairKit.y),
        s * 0.42,
        engine.elapsedTime,
      );
    }

    // 7. Road Hazard Zones (Ground Slam Craters & Slowing Poison Clouds)
    for (final h in td.hazards) {
      _drawRoadHazard(canvas, vp.toScreen(h.x, h.y), h.radius * s, h);
    }

    // 8. Food Decoys in Arena
    for (final d in td.decoys) {
      final pos = vp.toScreen(d.x, d.y);
      canvas.drawCircle(
        pos,
        s * 0.48,
        Paint()
          ..color = const Color(0x66FFC857)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawCircle(pos, s * 0.28, Paint()..color = const Color(0xFFFF715B));
    }

    // 9. Boss Attack Telegraphs (Bomb Target Circles, Charge Lanes, Slam Danger Zones)
    _drawBossTelegraphs(canvas, vp, td);

    // 9b. Ground Footstep & Charge Dust Puffs!
    if (!reducedMotion) {
      for (final d in td.dustPuffs) {
        final p = d.progress;
        final alpha = (1.0 - p) * 0.55;
        canvas.drawCircle(
          vp.toScreen(d.x, d.y),
          d.maxRadius * s * (0.45 + p * 0.65),
          Paint()..color = Color(d.colorHex).withOpacity(alpha.clamp(0.0, 1.0)),
        );
      }
    }

    // 10-14. Proper 2.5D Y-Depth Sorted Character Layering (Section 8)
    // Ensures Courier, Dock Worker, Giant Boss, Truck & Minions layer cleanly without stacking!
    final drawQueue = <({double sortY, VoidCallback draw})>[];

    drawQueue.add((
      sortY: td.truck.y,
      draw: () => BossCageIllustrator.drawRoadTruck(
            canvas,
            vp.toScreen(td.truck.x, td.truck.y),
            s * 0.62,
            truck: td.truck,
            elapsed: engine.elapsedTime,
          ),
    ));

    drawQueue.add((
      sortY: td.ally.y,
      draw: () => SkeletalCharacterAnimator.drawDockWorkerRig(
            canvas,
            vp.toScreen(td.ally.x, td.ally.y),
            s * 0.50,
            td.buildRoadAllyAnimSnapshot(engine.elapsedTime),
          ),
    ));

    for (final m in td.helperMinions) {
      if (m.isDefeated) continue;
      drawQueue.add((
        sortY: m.y,
        draw: () => _drawHelperMinion(canvas, vp.toScreen(m.x, m.y), s * 0.36, m),
      ));
    }

    if (!td.boss.isDefeated && !td.boss.isCaged) {
      drawQueue.add((
        sortY: td.boss.y,
        draw: () => SkeletalCharacterAnimator.drawGiantBossRig(
              canvas,
              vp.toScreen(td.boss.x, td.boss.y),
              s * 0.72,
              td.buildBossAnimSnapshot(engine.elapsedTime),
              nameLabel: td.boss.displayName,
            ),
      ));
    }

    drawQueue.add((
      sortY: td.playerY,
      draw: () => SkeletalCharacterAnimator.drawCourierRig(
            canvas,
            vp.toScreen(td.playerX, td.playerY),
            s * 0.50,
            engine.buildCourierAnimSnapshot(),
          ),
    ));

    drawQueue.sort((a, b) => a.sortY.compareTo(b.sortY));
    for (final item in drawQueue) {
      item.draw();
    }

    // 15. Active Projectiles (Player Arrows/Bolts/Freeze Orbs & Boss Fantasy Bombs/Orbs)
    for (final p in td.playerProjectiles) {
      if (p.active) {
        _drawPlayerProjectile(canvas, vp.toScreen(p.x, p.y), s, p);
      }
    }
    for (final bp in td.bossProjectiles) {
      if (bp.active) {
        _drawBossProjectile(canvas, vp, s, bp);
      }
    }

    // 16. Combat VFX Bursts
    for (final fx in td.vfx) {
      _drawVfx(canvas, vp.toScreen(fx.x, fx.y), s, fx);
    }

    // 17. Floating Combat Popups
    for (final popup in td.popups) {
      final p = popup.progress;
      final alpha = (1.0 - p * p).clamp(0.0, 1.0);
      final pos = vp.toScreen(popup.worldX, popup.worldY - p * 0.9);
      final tp = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            color: Color(popup.colorHex).withOpacity(alpha),
            fontSize: math.max(11.5, s * 0.34),
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
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    canvas.restore();
  }

  void _drawDistrictTerrain(
    Canvas canvas,
    Size size,
    MazeDistrictInfo district,
  ) {
    final List<Color> gradColors;
    switch (district.id) {
      case 1: // Sunny Orchard meadow
        gradColors = const [Color(0xFFE7F6D5), Color(0xFFD3EFC0)];
        break;
      case 2: // Garden Market warm courtyard
        gradColors = const [Color(0xFFF9EBD7), Color(0xFFF0D9BC)];
        break;
      case 3: // Forest Food Trail mossy glade
        gradColors = const [Color(0xFFD8EDD6), Color(0xFFC2E1C4)];
        break;
      case 4: // Monster Valley twilight turf
        gradColors = const [Color(0xFFE8DFF2), Color(0xFFD8CBE8)];
        break;
      default: // Grand Delivery City plaza
        gradColors = const [Color(0xFFE3EDF6), Color(0xFFD2E1EE)];
        break;
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradColors,
        ).createShader(Offset.zero & size),
    );

    // Subtle soft decorative ground bands for rich cartoon depth
    final bandPaint = Paint()..color = Colors.white.withOpacity(0.14);
    for (double y = 24; y < size.height; y += 72) {
      canvas.drawOval(
        Rect.fromLTWH(-40, y, size.width + 80, 26),
        bandPaint,
      );
    }
  }

  void _drawWindingRoad(
    Canvas canvas,
    RoadArenaViewport vp,
    RoadPathDefinition road,
    MazeDistrictInfo district,
    double traveledDist,
  ) {
    if (road.sampledPoints.length < 2) return;
    final s = vp.scale;
    final roadPxW = road.roadWidth * s;

    final path = Path();
    final first = vp.toScreen(road.sampledPoints.first.x, road.sampledPoints.first.y);
    path.moveTo(first.dx, first.dy);
    for (int i = 1; i < road.sampledPoints.length; i++) {
      final pt = vp.toScreen(road.sampledPoints[i].x, road.sampledPoints[i].y);
      path.lineTo(pt.dx, pt.dy);
    }

    // 1. Soft earth shadow under road
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = const Color(0x22243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadPxW + 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 2. Crisp road curb / shoulder border
    canvas.drawPath(
      path,
      Paint()
        ..color = district.id == 2
            ? const Color(0xFFD8B894)
            : const Color(0xFFE6DAC3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadPxW + 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 3. Main road asphalt / cobblestone body
    final Color asphaltColor = district.id == 1
        ? const Color(0xFF7B8794)
        : (district.id == 2
            ? const Color(0xFF8C7A6B)
            : (district.id == 3
                ? const Color(0xFF6B7B73)
                : (district.id == 4
                    ? const Color(0xFF5D576B)
                    : const Color(0xFF4A5568))));
    canvas.drawPath(
      path,
      Paint()
        ..color = asphaltColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadPxW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 4. Traveled route progress highlight ribbon along road
    if (traveledDist > 0.1) {
      final progPath = Path()..moveTo(first.dx, first.dy);
      for (int i = 1; i < road.sampledPoints.length; i++) {
        if (road.cumulativeDistances[i] > traveledDist) break;
        final pt = vp.toScreen(road.sampledPoints[i].x, road.sampledPoints[i].y);
        progPath.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        progPath,
        Paint()
          ..color = const Color(0x385DBB75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = roadPxW * 0.72
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // 5. Crisp dashed road center markings
    final dashPaint = Paint()
      ..color = const Color(0xCCFFE8A3)
      ..strokeWidth = math.max(2.0, s * 0.08)
      ..strokeCap = StrokeCap.round;

    for (double d = 0.4; d < road.totalLength - 0.5; d += 0.95) {
      final a = road.sampleAtDistance(d);
      final b = road.sampleAtDistance((d + 0.42).clamp(0.0, road.totalLength));
      canvas.drawLine(vp.toScreen(a.x, a.y), vp.toScreen(b.x, b.y), dashPaint);
    }
  }

  void _drawStartDockAndBrokenCage(
    Canvas canvas,
    RoadArenaViewport vp,
    dynamic td,
  ) {
    final s = vp.scale;
    final dockPos = vp.toScreen(td.config.road.startDockPos.x, td.config.road.startDockPos.y);
    final dockRect = Rect.fromCenter(
      center: dockPos + Offset(0, -s * 0.25),
      width: s * 2.4,
      height: s * 0.95,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(dockRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFFEAF7EE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(dockRect, const Radius.circular(10)),
      Paint()
        ..color = const Color(0xFF5DBB75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'START DOCK',
        style: TextStyle(
          color: const Color(0xFF2E7D32),
          fontSize: math.max(8.0, s * 0.24),
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, dockRect.center - Offset(tp.width / 2, tp.height / 2));

    // Broken open Monster Cage right beside Start Dock
    final cagePos = vp.toScreen(td.config.road.cagePos.x, td.config.road.cagePos.y);
    final cageRect = Rect.fromCenter(
      center: cagePos,
      width: s * 1.45,
      height: s * 1.15,
    );
    BossCageIllustrator.drawMonsterCage(
      canvas,
      cageRect,
      cageState: td.cageState,
      bossType: td.boss.type,
      bossAppearance: td.boss.appearance,
      shakeIntensity: td.cageShakeIntensity,
      animPhase: td.boss.animPhase,
      elapsed: engine.elapsedTime,
      showBossInside: td.boss.isCaged,
    );
  }

  void _drawDestinationBuilding(
    Canvas canvas,
    RoadArenaViewport vp,
    RoadPoint destPos,
    DestinationBuildingType type, {
    required bool arrived,
  }) {
    final s = vp.scale;
    final center = vp.toScreen(destPos.x, destPos.y);

    // Checkered finish mat right in front of building
    final matRect = Rect.fromCenter(
      center: center + Offset(0, -s * 0.12),
      width: s * 2.1,
      height: s * 0.42,
    );
    canvas.drawRect(matRect, Paint()..color = Colors.white);
    final sqW = matRect.width / 8;
    for (int i = 0; i < 8; i++) {
      if (i.isEven) {
        canvas.drawRect(
          Rect.fromLTWH(matRect.left + i * sqW, matRect.top, sqW, matRect.height / 2),
          Paint()..color = const Color(0xFF1F2A44),
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(
            matRect.left + i * sqW,
            matRect.top + matRect.height / 2,
            sqW,
            matRect.height / 2,
          ),
          Paint()..color = const Color(0xFF1F2A44),
        );
      }
    }

    // Building facade
    final bRect = Rect.fromCenter(
      center: center + Offset(0, s * 0.45),
      width: s * 2.55,
      height: s * 1.15,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect.shift(const Offset(0, 3)), const Radius.circular(10)),
      Paint()..color = const Color(0x2E1F2A44),
    );

    final roofColor = arrived
        ? const Color(0xFF5DBB75)
        : (type == DestinationBuildingType.orchardBarn
            ? const Color(0xFFE63946)
            : (type == DestinationBuildingType.marketStorage
                ? const Color(0xFFE08D55)
                : (type == DestinationBuildingType.forestDepot
                    ? const Color(0xFF2E7D32)
                    : (type == DestinationBuildingType.valleyOutpost
                        ? const Color(0xFF7B5EA7)
                        : const Color(0xFF243447)))));

    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect, const Radius.circular(10)),
      Paint()..color = const Color(0xFFFFF8E8),
    );
    // Colored awning roof
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bRect.left - 3, bRect.top - 4, bRect.width + 6, bRect.height * 0.46),
        const Radius.circular(8),
      ),
      Paint()..color = roofColor,
    );
    // Loading bay garage opening
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(bRect.center.dx, bRect.bottom - bRect.height * 0.24),
          width: bRect.width * 0.45,
          height: bRect.height * 0.42,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF334155),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bRect, const Radius.circular(10)),
      Paint()
        ..color = const Color(0xFF243447)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Destination label on awning
    final tp = TextPainter(
      text: TextSpan(
        text: type.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: math.max(8.0, s * 0.24),
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(bRect.center.dx - tp.width / 2, bRect.top + bRect.height * 0.08),
    );
  }

  void _drawSceneryProp(
    Canvas canvas,
    Offset pos,
    double s,
    RoadPropKind kind,
    MazeDistrictInfo district,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);

    switch (kind) {
      case RoadPropKind.tree:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(0, s * 0.24), width: s * 0.85, height: s * 0.34),
          Paint()..color = const Color(0x281F2A44),
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(0, s * 0.12), width: s * 0.16, height: s * 0.30),
          Paint()..color = const Color(0xFF7A4424),
        );
        canvas.drawCircle(Offset(0, -s * 0.08), s * 0.34, Paint()..color = Color(district.wallSideHex));
        canvas.drawCircle(Offset(-s * 0.06, -s * 0.14), s * 0.26, Paint()..color = Color(district.wallTopHex));
        break;

      case RoadPropKind.bush:
        canvas.drawCircle(Offset(-s * 0.14, 0), s * 0.22, Paint()..color = Color(district.wallSideHex));
        canvas.drawCircle(Offset(s * 0.14, 0), s * 0.20, Paint()..color = Color(district.wallTopHex));
        canvas.drawCircle(Offset(0, -s * 0.10), s * 0.22, Paint()..color = Color(district.wallTrimHex));
        break;

      case RoadPropKind.marketStall:
        final r = Rect.fromCenter(center: Offset.zero, width: s * 0.82, height: s * 0.56);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(5)),
          Paint()..color = const Color(0xFFFF715B),
        );
        canvas.drawRect(
          Rect.fromLTWH(r.left + r.width * 0.25, r.top, r.width * 0.22, r.height),
          Paint()..color = const Color(0xFFFFF8E8),
        );
        canvas.drawRect(
          Rect.fromLTWH(r.left + r.width * 0.68, r.top, r.width * 0.20, r.height),
          Paint()..color = const Color(0xFFFFF8E8),
        );
        break;

      case RoadPropKind.crateStack:
        final cr = Rect.fromCenter(center: Offset.zero, width: s * 0.52, height: s * 0.52);
        canvas.drawRRect(
          RRect.fromRectAndRadius(cr, const Radius.circular(4)),
          Paint()..color = const Color(0xFFD99A55),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(cr, const Radius.circular(4)),
          Paint()
            ..color = const Color(0xFF7A4424)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        break;

      case RoadPropKind.rock:
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: s * 0.64, height: s * 0.44),
          Paint()..color = const Color(0xFF788496),
        );
        canvas.drawOval(
          Rect.fromCenter(center: Offset(-s * 0.08, -s * 0.06), width: s * 0.38, height: s * 0.24),
          Paint()..color = const Color(0xFF9AA5B1),
        );
        break;

      case RoadPropKind.lampPost:
        canvas.drawCircle(Offset.zero, s * 0.26, Paint()..color = const Color(0x40FFC857));
        canvas.drawCircle(Offset.zero, s * 0.13, Paint()..color = const Color(0xFFFFC857));
        break;

      case RoadPropKind.flowerPatch:
        for (final off in [
          Offset(-s * 0.16, -s * 0.08),
          Offset(s * 0.16, -s * 0.04),
          Offset(0, s * 0.14),
        ]) {
          canvas.drawCircle(off, s * 0.09, Paint()..color = const Color(0xFFFFC857));
          canvas.drawCircle(off, s * 0.04, Paint()..color = const Color(0xFFFF715B));
        }
        break;
    }

    canvas.restore();
  }

  void _drawRepairKit(Canvas canvas, Offset center, double r, double elapsed) {
    final pulse = reducedMotion ? 1.15 : 1.1 + math.sin(elapsed * 5.2) * 0.14;
    canvas.save();
    canvas.translate(center.dx, center.dy);

    canvas.drawCircle(Offset.zero, r * pulse * 1.2, Paint()..color = const Color(0x385DBB75));
    final box = Rect.fromCenter(center: Offset.zero, width: r * 1.65, height: r * 1.38);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(7)),
      Paint()..color = const Color(0xFF2E7D32),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(7)),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
    // Crisp white cross / repair symbol
    final cross = Paint()
      ..color = Colors.white
      ..strokeWidth = math.max(3.0, r * 0.26)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-r * 0.36, 0), Offset(r * 0.36, 0), cross);
    canvas.drawLine(Offset(0, -r * 0.36), Offset(0, r * 0.36), cross);

    final tp = TextPainter(
      text: TextSpan(
        text: 'REPAIR',
        style: TextStyle(
          color: const Color(0xFF1B5E20),
          fontSize: math.max(8.0, r * 0.42),
          fontWeight: FontWeight.w900,
          shadows: const [Shadow(color: Colors.white, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, box.bottom + 2));

    canvas.restore();
  }

  void _drawRoadHazard(
    Canvas canvas,
    Offset center,
    double radius,
    RoadHazardZone h,
  ) {
    final a = h.alpha;
    if (h.kind == RoadHazardKind.groundSlamCrater) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFFE63946).withOpacity(0.24 * a),
      );
      canvas.drawCircle(
        center,
        radius * 0.72,
        Paint()..color = const Color(0xFF475569).withOpacity(0.45 * a),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFFFF715B).withOpacity(0.75 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    } else {
      // Swirling fantasy slow cloud
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFF9333EA).withOpacity(0.32 * a),
      );
      canvas.drawCircle(
        center + Offset(-radius * 0.25, -radius * 0.15),
        radius * 0.55,
        Paint()..color = const Color(0xFF84CC16).withOpacity(0.34 * a),
      );
    }
  }

  void _drawBossTelegraphs(Canvas canvas, RoadArenaViewport vp, dynamic td) {
    final s = vp.scale;
    final boss = td.boss as RoadBossEntity;

    if (boss.aiState == BossCombatAiState.telegraphing &&
        boss.queuedAttack != null) {
      final t = boss.telegraphProgress;
      final targetPos = vp.toScreen(boss.telegraphTargetX, boss.telegraphTargetY);
      final bossPos = vp.toScreen(boss.x, boss.y);

      if (boss.queuedAttack == BossAttackType.directCharge ||
          boss.queuedAttack == BossAttackType.tireAttack) {
        // Telegraphed crimson charge lane!
        canvas.drawLine(
          bossPos,
          targetPos,
          Paint()
            ..color = (boss.queuedAttack == BossAttackType.tireAttack
                    ? const Color(0xFFFF9F1C)
                    : const Color(0xFFE63946))
                .withOpacity(0.35 + t * 0.45)
            ..strokeWidth = s * 0.55
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // Projected Bomb / Ground Slam impact danger circle!
        final r = s * 1.12;
        canvas.drawCircle(
          targetPos,
          r,
          Paint()..color = const Color(0x30E63946),
        );
        canvas.drawCircle(
          targetPos,
          r * t,
          Paint()..color = const Color(0x55E63946),
        );
        canvas.drawCircle(
          targetPos,
          r,
          Paint()
            ..color = const Color(0xFFE63946)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4,
        );
      }
    }

    // Active flying bomb landing target markers
    for (final bp in td.bossProjectiles as List<BossProjectileEntity>) {
      if (!bp.active) continue;
      final targetPos = vp.toScreen(bp.targetX, bp.targetY);
      final r = bp.blastRadius * s;
      canvas.drawCircle(targetPos, r, Paint()..color = const Color(0x2AE63946));
      canvas.drawCircle(
        targetPos,
        r,
        Paint()
          ..color = const Color(0xCCE63946)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  void _drawHelperMinion(
    Canvas canvas,
    Offset pos,
    double r,
    RoadHelperMinion m,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()..color = m.hitFlashTimer > 0 ? Colors.white : const Color(0xFF4C1D95),
    );
    canvas.drawCircle(Offset(-r * 0.28, -r * 0.15), r * 0.18, Paint()..color = const Color(0xFFFACC15));
    canvas.drawCircle(Offset(r * 0.28, -r * 0.15), r * 0.18, Paint()..color = const Color(0xFFFACC15));
    canvas.restore();
  }

  void _drawPlayerProjectile(
    Canvas canvas,
    Offset pos,
    double s,
    ProjectileEntity p,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(p.angle);
    if (p.weapon == WeaponType.bow) {
      canvas.drawLine(
        Offset(-s * 0.28, 0),
        Offset(s * 0.26, 0),
        Paint()
          ..color = const Color(0xFF7A4424)
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round,
      );
      final tip = Path()
        ..moveTo(s * 0.36, 0)
        ..lineTo(s * 0.16, -s * 0.11)
        ..lineTo(s * 0.16, s * 0.11)
        ..close();
      canvas.drawPath(tip, Paint()..color = const Color(0xFFFFC857));
    } else if (p.weapon == WeaponType.energyBlaster) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.52, height: s * 0.22),
        Paint()..color = const Color(0xFFA855F7),
      );
      canvas.drawCircle(Offset(s * 0.08, 0), s * 0.08, Paint()..color = Colors.white);
    } else {
      canvas.drawCircle(Offset.zero, s * 0.22, Paint()..color = const Color(0xFF38BDF8));
      canvas.drawCircle(Offset(-s * 0.05, -s * 0.05), s * 0.07, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  void _drawBossProjectile(
    Canvas canvas,
    RoadArenaViewport vp,
    double s,
    BossProjectileEntity bp,
  ) {
    final groundPos = vp.toScreen(bp.x, bp.y);
    final arcLift = bp.isBomb ? math.sin(bp.progress * math.pi) * s * 1.45 : 0.0;
    final airPos = groundPos + Offset(0, -arcLift);

    // Shadow on ground
    canvas.drawOval(
      Rect.fromCenter(center: groundPos, width: s * 0.44, height: s * 0.22),
      Paint()..color = const Color(0x381F2A44),
    );

    if (bp.isBomb) {
      // Stylized Fantasy Cartoon Bomb with glowing golden spark fuse!
      canvas.drawCircle(airPos, s * 0.26, Paint()..color = const Color(0xFF1F2937));
      canvas.drawCircle(
        airPos + Offset(-s * 0.07, -s * 0.07),
        s * 0.08,
        Paint()..color = const Color(0xFF64748B),
      );
      canvas.drawCircle(
        airPos + Offset(s * 0.14, -s * 0.24),
        s * 0.12,
        Paint()..color = const Color(0xFFFFC857),
      );
      canvas.drawCircle(
        airPos + Offset(s * 0.14, -s * 0.24),
        s * 0.06,
        Paint()..color = const Color(0xFFFF4D6D),
      );
    } else {
      // Swirling Boss Magic Energy Orb
      canvas.drawCircle(airPos, s * 0.26, Paint()..color = const Color(0x55A855F7));
      canvas.drawCircle(airPos, s * 0.17, Paint()..color = const Color(0xFFD946EF));
      canvas.drawCircle(airPos, s * 0.07, Paint()..color = Colors.white);
    }
  }

  void _drawVfx(Canvas canvas, Offset pos, double s, CombatVfx fx) {
    final p = fx.progress;
    final alpha = (1.0 - p).clamp(0.0, 1.0);
    final c = Color(fx.colorHex);
    if (fx.type == CombatVfxType.meleeSlash) {
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(fx.angle);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: fx.maxRadius * s * 0.55),
        -0.75,
        1.5,
        false,
        Paint()
          ..color = c.withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.2 * alpha
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    } else {
      final rad = fx.maxRadius * s * (0.25 + p * 0.75);
      canvas.drawCircle(
        pos,
        rad,
        Paint()
          ..color = c.withOpacity(alpha * 0.32),
      );
      canvas.drawCircle(
        pos,
        rad,
        Paint()
          ..color = c.withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 * alpha,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RoadBattlePainter oldDelegate) => true;
}

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/engine/maze/truck_defense_simulation.dart';
import 'package:parcel_escape/src/models/maze/delivery_state.dart';
import 'package:parcel_escape/src/models/maze/level_roster.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/monster.dart';
import 'package:parcel_escape/src/models/maze/monster_variants.dart';
import 'package:parcel_escape/src/models/maze/truck_defense_models.dart';
import 'package:parcel_escape/src/rendering/maze/maze_canvas_painter.dart';
import 'package:parcel_escape/src/rendering/maze/road_battle_painter.dart';
import 'package:parcel_escape/src/rendering/maze/unique_monster_illustrator.dart';
import 'package:parcel_escape/src/services/sprite_atlas.dart';

List<MazeLevel> _loadLevels() {
  final raw = jsonDecode(
    File('assets/levels/maze_levels.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (raw['levels'] as List)
      .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> _saveCanvasImage({
  required Size size,
  required void Function(Canvas canvas, Size size) painter,
  required String outputPath,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  painter(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData != null) {
    File(outputPath).writeAsBytesSync(byteData.buffer.asUint8List());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MazeLevel> levels;
  const artifactDir = r'C:\Users\THT-Sultan\.gemini\antigravity\brain\3db011e4-d9a1-4397-8bf2-40be4c25fe46';

  setUpAll(() {
    levels = _loadLevels();
  });

  group('Nightfall 50 Monsters Pack Verification', () {
    test('All 50 levels have valid, distinct Nightfall monster assets (PNG + GLB)', () {
      expect(LevelRosterCatalog.entries.length, equals(50));
      for (int i = 1; i <= 50; i++) {
        final roster = LevelRosterCatalog.forLevel(i);
        expect(roster.level, equals(i));

        // Model ID format: L01_... to L50_...
        final numStr = i.toString().padLeft(2, '0');
        expect(roster.primaryModelId.startsWith('L$numStr'), isTrue,
            reason: 'Level $i model ID must start with L$numStr');

        final pngFile = File(roster.previewAssetPath);
        final glbFile = File(roster.modelAssetPath);
        expect(pngFile.existsSync(), isTrue,
            reason: 'Level $i preview PNG missing: ${roster.previewAssetPath}');
        expect(glbFile.existsSync(), isTrue,
            reason: 'Level $i GLB missing: ${roster.modelAssetPath}');

        // High-resolution Nightfall assets are substantial files (> 50KB)
        expect(pngFile.lengthSync(), greaterThan(50000),
            reason: 'Level $i PNG too small, expected Nightfall 720x720 render');
        expect(glbFile.lengthSync(), greaterThan(20000),
            reason: 'Level $i GLB too small');
      }
    });

    test('Level 1 and Level 2 are in Sunny Orchard but have distinct identities & anatomies', () {
      final r1 = LevelRosterCatalog.forLevel(1);
      final r2 = LevelRosterCatalog.forLevel(2);
      expect(r1.district, equals('Sunny Orchard'));
      expect(r2.district, equals('Sunny Orchard'));
      expect(r1.primaryModelId, isNot(equals(r2.primaryModelId)));
      expect(r1.monster, equals('Pipjack'));
      expect(r2.monster, equals('Acorn Tunneler'));
      expect(r1.anatomy, equals('hare'));
      expect(r2.anatomy, equals('beetle'));
      expect(r1.previewAssetPath, isNot(equals(r2.previewAssetPath)));
    });

    test('Level 10 (Sunny Orchard) and Level 11 (Garden Market) are distinct across district boundary', () {
      final r10 = LevelRosterCatalog.forLevel(10);
      final r11 = LevelRosterCatalog.forLevel(11);
      expect(r10.district, equals('Sunny Orchard'));
      expect(r11.district, equals('Garden Market'));
      expect(r10.primaryModelId, equals('L10_thistle_roller'));
      expect(r11.primaryModelId, equals('L11_copper_kettle'));
      expect(r10.anatomy, equals('hedgehog'));
      expect(r11.anatomy, equals('golem'));
    });
  });

  group('Truck Defense Drag-to-Move Route Following During Boss Attacks', () {
    test('Courier follows drawn route past truck even when truck is slowed or stopped', () {
      final lv1 = levels.firstWhere((l) => l.id == 1);
      final engine = MazeGameEngine(level: lv1);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      td.playerX = 3.0;
      td.playerY = 4.0;
      td.truck.x = 4.0;
      td.truck.y = 5.0;
      td.truck.slamSlowTimer = 2.0; // Truck slowed down after boss attack

      // Start drag near Courier
      expect(td.beginRoadRouteDraw(3.0, 4.0), isTrue);
      // Draw route past the truck to (6.0, 7.0)
      td.updateRoadRouteDraw(2.8, 5.0);
      td.updateRoadRouteDraw(4.5, 6.2);
      td.updateRoadRouteDraw(6.0, 7.0);
      expect(td.commitRoadRouteDraw(), isTrue);
      expect(td.activeRoadRoute.length, equals(4));

      final startX = td.playerX;
      // Step simulation multiple times
      for (int i = 0; i < 20; i++) {
        td.stepDefense(
          dt: 0.05,
          inputDx: 0.0,
          inputDy: 0.0,
          playerHasShield: false,
          playerIsInvulnerable: false,
          playerIsPoisonSlowed: false,
          attackAnimTimer: 0.0,
          onConsumePlayerShield: () {},
          onHitPlayerHealth: () {},
        );
      }

      // Courier must have moved along the route past the truck, not frozen!
      expect(td.playerX, greaterThan(startX));
      expect(td.isTruckBlockingCourier, isFalse);
    });

    test('Hit-stun suspends movement and resumes route following without dropping path', () {
      final lv1 = levels.firstWhere((l) => l.id == 1);
      final engine = MazeGameEngine(level: lv1);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      td.playerX = 2.0;
      td.playerY = 3.0;

      td.beginRoadRouteDraw(2.0, 3.0);
      td.updateRoadRouteDraw(3.0, 4.0);
      td.updateRoadRouteDraw(4.0, 5.0);
      td.updateRoadRouteDraw(5.0, 6.0);
      td.commitRoadRouteDraw();

      expect(td.activeRoadRoute.length, equals(4));

      // Courier takes hit-stun (e.g. boss projectile explosion)
      td.applyStun(0.30);
      expect(td.isStunnedOrKnockedBack, isTrue);

      // During stun, route waypoints are preserved and player does not move
      td.stepDefense(
        dt: 0.05,
        inputDx: 0.0,
        inputDy: 0.0,
        playerHasShield: false,
        playerIsInvulnerable: false,
        playerIsPoisonSlowed: false,
        attackAnimTimer: 0.0,
        onConsumePlayerShield: () {},
        onHitPlayerHealth: () {},
      );

      expect(td.isStunnedOrKnockedBack, isTrue);
      expect(td.activeRoadRoute.length, equals(4),
          reason: 'Route waypoints must not be cleared during hit-stun');

      // Step past stun duration (0.35s total)
      for (int i = 0; i < 8; i++) {
        td.stepDefense(
          dt: 0.05,
          inputDx: 0.0,
          inputDy: 0.0,
          playerHasShield: false,
          playerIsInvulnerable: false,
          playerIsPoisonSlowed: false,
          attackAnimTimer: 0.0,
          onConsumePlayerShield: () {},
          onHitPlayerHealth: () {},
        );
      }

      // Stun is resolved and Courier automatically resumes following route
      expect(td.isStunnedOrKnockedBack, isFalse);
      expect(td.playerX, greaterThan(2.0),
          reason: 'Courier must resume moving along route after stun ends');
    });

    test('New drag near Courier immediately cancels previous route and starts fresh', () {
      final lv1 = levels.firstWhere((l) => l.id == 1);
      final engine = MazeGameEngine(level: lv1);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      td.playerX = 2.0;
      td.playerY = 3.0;

      // Draw first route
      td.beginRoadRouteDraw(2.0, 3.0);
      td.updateRoadRouteDraw(3.0, 4.0);
      td.commitRoadRouteDraw();
      expect(td.activeRoadRoute.isNotEmpty, isTrue);

      // Start new drag near Courier
      expect(td.beginRoadRouteDraw(2.0, 3.0), isTrue);
      // Old active route must be cancelled immediately
      expect(td.activeRoadRoute.isEmpty, isTrue,
          reason: 'Starting a new drag must immediately cancel the active route');
      expect(td.isDrawingRoadRoute, isTrue);
    });

    test('Joystick input immediately cancels active road route and gives manual control', () {
      final lv1 = levels.firstWhere((l) => l.id == 1);
      final engine = MazeGameEngine(level: lv1);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      td.playerX = 2.0;
      td.playerY = 3.0;

      td.beginRoadRouteDraw(2.0, 3.0);
      td.updateRoadRouteDraw(3.0, 4.0);
      td.commitRoadRouteDraw();
      expect(td.activeRoadRoute.isNotEmpty, isTrue);

      // Push joystick
      engine.setJoystickInput(1.0, 0.0);
      expect(td.activeRoadRoute.isEmpty, isTrue,
          reason: 'Joystick must cancel active route immediately');
    });
  });

  group('Capture Visual Proofs for Nightfall Deliverables', () {
    test('Capture Proof A: Nightfall 50 Monsters Showcase (Selected Roster Across 5 Districts)', () async {
      const size = Size(720, 520);
      await _saveCanvasImage(
        size: size,
        painter: (canvas, s) {
          canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0F172A));

          final title = TextPainter(
            text: const TextSpan(
              text: 'Food Maze Adventure — Nightfall 50 Dark Fantasy Monsters Pack',
              style: TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          title.paint(canvas, const Offset(20, 16));

          final subtitle = TextPainter(
            text: const TextSpan(
              text: 'Each level features a distinct species with anatomy-matched locomotion & 2.5D visual identity',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          subtitle.paint(canvas, const Offset(20, 40));

          // Render sample cards from across all 5 districts
          final sampleLevels = [1, 2, 4, 5, 10, 11, 16, 18, 25, 33, 42, 50];
          final colW = (s.width - 40) / 4;
          const rowH = 140.0;

          for (int i = 0; i < sampleLevels.length; i++) {
            final lvlId = sampleLevels[i];
            final roster = LevelRosterCatalog.forLevel(lvlId);
            final col = i % 4;
            final row = i ~/ 4;
            final x = 20.0 + col * colW;
            final y = 68.0 + row * rowH;

            final cardRect = Rect.fromLTWH(x + 4, y + 4, colW - 8, rowH - 8);
            canvas.drawRRect(
              RRect.fromRectAndRadius(cardRect, const Radius.circular(8)),
              Paint()..color = const Color(0xFF1E293B),
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(cardRect, const Radius.circular(8)),
              Paint()
                ..color = const Color(0xFF334155)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );

            // Draw level badge
            final badge = TextPainter(
              text: TextSpan(
                text: 'LV $lvlId • ${roster.monster}',
                style: const TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: colW - 16);
            badge.paint(canvas, Offset(x + 10, y + 10));

            final anatText = TextPainter(
              text: TextSpan(
                text: '${roster.anatomy.toUpperCase()} • ${roster.intendedLocomotion}',
                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9),
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: colW - 16);
            anatText.paint(canvas, Offset(x + 10, y + 26));

            // Draw monster representation using UniqueMonsterIllustrator
            final mEntity = MonsterEntity(
              id: 'm_$lvlId',
              type: MonsterType.values[lvlId % MonsterType.values.length],
              x: 0,
              y: 0,
              home: const GridPoint(0, 0),
              patrolPath: const [],
              maxHp: 100,
              hp: 100,
              speed: 2.0,
              detectionRange: 3.0,
              biteDamage: 15,
              stunResistance: 0.5,
              alertDuration: 0.36,
              recoverDuration: 0.5,
              movementProfile: roster.movementProfile,
              appearance: MonsterAppearanceSpec.forLevelSlot(
                levelId: lvlId,
                slotIndex: 0,
                type: MonsterType.values[lvlId % MonsterType.values.length],
                movement: roster.movementProfile,
              ),
            );

            UniqueMonsterIllustrator.drawUniqueMazeMonster(
              canvas,
              Offset(x + colW * 0.5, y + rowH * 0.68),
              22.0,
              mEntity,
            );
          }
        },
        outputPath: '$artifactDir/proof_nightfall_50_showcase.png',
      );
    });

    test('Capture Proof B: Level 1 vs Level 2 (Same District, Distinct Art & Anatomy)', () async {
      const size = Size(640, 340);
      await _saveCanvasImage(
        size: size,
        painter: (canvas, s) {
          canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0F172A));

          final title = TextPainter(
            text: const TextSpan(
              text: 'District 1 Comparison: Level 1 (Pipjack) vs Level 2 (Acorn Tunneler)',
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          title.paint(canvas, const Offset(20, 16));

          for (int idx = 0; idx < 2; idx++) {
            final lvlId = idx + 1;
            final roster = LevelRosterCatalog.forLevel(lvlId);
            final cx = s.width * (0.28 + idx * 0.44);

            final card = Rect.fromCenter(center: Offset(cx, 185), width: 240, height: 240);
            canvas.drawRRect(
              RRect.fromRectAndRadius(card, const Radius.circular(12)),
              Paint()..color = const Color(0xFF1E293B),
            );

            final label = TextPainter(
              text: TextSpan(
                text: 'Level $lvlId: ${roster.monster}\nAnatomy: ${roster.anatomy}\nLocomotion: ${roster.intendedLocomotion}\nAsset: ${roster.primaryModelId}.png',
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.4),
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 220);
            label.paint(canvas, Offset(cx - label.width * 0.5, 80));

            final m = MonsterEntity(
              id: 'm$lvlId',
              type: MonsterType.values[lvlId % MonsterType.values.length],
              x: 0,
              y: 0,
              home: const GridPoint(0, 0),
              patrolPath: const [],
              maxHp: 100,
              hp: 100,
              speed: 2.0,
              detectionRange: 3.0,
              biteDamage: 15,
              stunResistance: 0.5,
              alertDuration: 0.36,
              recoverDuration: 0.5,
              movementProfile: roster.movementProfile,
              appearance: MonsterAppearanceSpec.forLevelSlot(
                levelId: lvlId,
                slotIndex: 0,
                type: MonsterType.values[lvlId % MonsterType.values.length],
                movement: roster.movementProfile,
              ),
            );

            UniqueMonsterIllustrator.drawUniqueMazeMonster(
              canvas,
              Offset(cx, 230),
              38.0,
              m,
            );
          }
        },
        outputPath: '$artifactDir/proof_level1_vs_level2.png',
      );
    });

    test('Capture Proof C: Level 10 vs Level 11 (District Boundary Distinction)', () async {
      const size = Size(640, 340);
      await _saveCanvasImage(
        size: size,
        painter: (canvas, s) {
          canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0F172A));

          final title = TextPainter(
            text: const TextSpan(
              text: 'District Boundary: Level 10 (Thistle Roller) vs Level 11 (Copper Kettle)',
              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          title.paint(canvas, const Offset(20, 16));

          final pairs = [10, 11];
          for (int idx = 0; idx < 2; idx++) {
            final lvlId = pairs[idx];
            final roster = LevelRosterCatalog.forLevel(lvlId);
            final cx = s.width * (0.28 + idx * 0.44);

            final card = Rect.fromCenter(center: Offset(cx, 185), width: 240, height: 240);
            canvas.drawRRect(
              RRect.fromRectAndRadius(card, const Radius.circular(12)),
              Paint()..color = const Color(0xFF1E293B),
            );

            final label = TextPainter(
              text: TextSpan(
                text: 'Level $lvlId (${roster.district})\n${roster.monster}\nAnatomy: ${roster.anatomy}\nAsset: ${roster.primaryModelId}.png',
                style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, height: 1.4),
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: 220);
            label.paint(canvas, Offset(cx - label.width * 0.5, 80));

            final m = MonsterEntity(
              id: 'm$lvlId',
              type: MonsterType.values[lvlId % MonsterType.values.length],
              x: 0,
              y: 0,
              home: const GridPoint(0, 0),
              patrolPath: const [],
              maxHp: 100,
              hp: 100,
              speed: 2.0,
              detectionRange: 3.0,
              biteDamage: 15,
              stunResistance: 0.5,
              alertDuration: 0.36,
              recoverDuration: 0.5,
              movementProfile: roster.movementProfile,
              appearance: MonsterAppearanceSpec.forLevelSlot(
                levelId: lvlId,
                slotIndex: 0,
                type: MonsterType.values[lvlId % MonsterType.values.length],
                movement: roster.movementProfile,
              ),
            );

            UniqueMonsterIllustrator.drawUniqueMazeMonster(
              canvas,
              Offset(cx, 230),
              38.0,
              m,
            );
          }
        },
        outputPath: '$artifactDir/proof_level10_vs_level11.png',
      );
    });

    test('Capture Proof D: Road Battle Route Drawn Past Truck During Boss Attack', () async {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      td.playerX = 3.8;
      td.playerY = 4.0;
      td.truck.x = 4.8;
      td.truck.y = 5.2;

      // Start drag near Courier and draw curved route past the truck
      td.beginRoadRouteDraw(3.8, 4.0);
      td.updateRoadRouteDraw(4.2, 4.8);
      td.updateRoadRouteDraw(5.5, 6.0);
      td.updateRoadRouteDraw(6.8, 7.5);
      td.commitRoadRouteDraw();

      // Trigger Boss Attack Telegraph
      td.boss.aiState = BossCombatAiState.telegraphing;
      td.boss.queuedAttack = BossAttackType.bombProjectile;
      td.boss.telegraphTargetX = 5.0;
      td.boss.telegraphTargetY = 5.2;

      engine.step(0.05);

      const size = Size(360, 640);
      await _saveCanvasImage(
        size: size,
        painter: (canvas, s) {
          final painter = RoadBattlePainter(engine: engine, reducedMotion: true);
          painter.paint(canvas, s);
        },
        outputPath: '$artifactDir/proof_road_route_during_boss_attack.png',
      );
    });
  });
}

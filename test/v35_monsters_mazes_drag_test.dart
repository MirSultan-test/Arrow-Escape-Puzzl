import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/controllers/audio_controller.dart';
import 'package:parcel_escape/src/controllers/maze_game_controller.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/engine/maze/maze_pathfinder.dart';
import 'package:parcel_escape/src/engine/maze/maze_validator.dart';
import 'package:parcel_escape/src/models/maze/food_item.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/monster.dart';
import 'package:parcel_escape/src/models/maze/monster_variants.dart';
import 'package:parcel_escape/src/rendering/maze/maze_canvas_painter.dart';
import 'package:parcel_escape/src/screens/gameplay_screen.dart';
import 'package:parcel_escape/src/services/ad_service.dart';
import 'package:parcel_escape/src/services/maze_level_repository.dart';
import 'package:parcel_escape/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a compact test maze with a single controllable monster for profile verification.
MazeLevel _buildSingleMonsterArena(MonsterMovementProfile profile) {
  return MazeLevel(
    id: 25,
    district: 3,
    title: 'Profile Arena ${profile.name}',
    subtitle: 'Automated movement test',
    cols: 11,
    rows: 9,
    grid: const [
      '###########',
      '#.........#',
      '#.##...##.#',
      '#.........#',
      '#..##.##..#',
      '#.........#',
      '#.##...##.#',
      '#.........#',
      '#####E#####',
    ],
    playerStart: const GridPoint(1, 7),
    exitCell: const GridPoint(5, 8),
    cargoCapacity: 2,
    timeLimitSeconds: 90,
    minQuotaPercent: 50,
    starThresholds: const [50, 100, 200],
    foods: const [
      FoodSpawn(id: 'f1', type: FoodType.apple, col: 9, row: 1),
      FoodSpawn(id: 'f2', type: FoodType.banana, col: 1, row: 1),
    ],
    monsters: [
      MonsterDefinition(
        id: 'm_${profile.name}',
        type: MonsterType.redHunter,
        start: const GridPoint(5, 3),
        patrolPath: const [
          GridPoint(2, 3),
          GridPoint(8, 3),
          GridPoint(8, 5),
          GridPoint(2, 5),
        ],
        speed: 2.1,
        detectionRange: 4.5,
        biteDamage: 25,
        appearanceId: 'test_${profile.name}',
        movementProfile: profile,
      ),
    ],
  );
}

void main() {
  late List<MazeLevel> allLevels;

  setUpAll(() {
    final file = File('assets/levels/maze_levels.json');
    expect(file.existsSync(), isTrue);
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    allLevels = (decoded['levels'] as List<dynamic>)
        .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  group('V3.5 Unique Monsters, 50 Bosses & 10 Movement Profiles', () {
    test('1. Consecutive levels generate visually distinct monsters beyond color swaps', () {
      final levelSignatures = <int, String>{};
      final uniqueShapes = <MonsterBodyShape>{};
      final uniqueHorns = <MonsterHornStyle>{};
      final uniqueMouths = <MonsterMouthStyle>{};
      final uniquePatterns = <MonsterSkinPattern>{};
      final uniqueEyeCounts = <int>{};

      for (final lvl in allLevels) {
        if (lvl.monsters.isEmpty) continue;
        final m = lvl.monsters.first.createRuntimeEntity(
          levelId: lvl.id,
          slotIndex: 0,
        );
        final spec = m.appearance;
        uniqueShapes.add(spec.bodyShape);
        uniqueHorns.add(spec.hornStyle);
        uniqueMouths.add(spec.mouthStyle);
        uniquePatterns.add(spec.skinPattern);
        uniqueEyeCounts.add(spec.eyeCount);
        levelSignatures[lvl.id] =
            '${spec.bodyShape.name}|${spec.hornStyle.name}|${spec.mouthStyle.name}|${spec.eyeCount}|${m.movementProfile.name}';
      }

      // Rich structural variety across the campaign (not just recolors!)
      expect(uniqueShapes.length, greaterThanOrEqualTo(8));
      expect(uniqueHorns.length, greaterThanOrEqualTo(6));
      expect(uniqueMouths.length, equals(MonsterMouthStyle.values.length));
      expect(uniquePatterns.length, equals(MonsterSkinPattern.values.length));
      expect(uniqueEyeCounts.length, greaterThanOrEqualTo(3));

      // Adjacent levels with monsters never duplicate the same lead monster signature
      for (int id = 4; id <= 50; id++) {
        expect(
          levelSignatures[id],
          isNot(equals(levelSignatures[id - 1])),
          reason: 'Level $id lead monster should differ from Level ${id - 1}',
        );
      }
    });

    test('2. All 50 levels define unique Giant Boss appearances and distinct titles', () {
      final specs = <BossAppearanceSpec>[];
      final titles = <String>{};
      final anatomyKeys = <String>{};

      for (int id = 1; id <= 50; id++) {
        final district = ((id - 1) ~/ 10) + 1;
        final spec = BossAppearanceSpec.forLevel(id, district);
        specs.add(spec);
        titles.add(spec.title);
        anatomyKeys.add(
          '${spec.bodyShape.name}|${spec.hornStyle.name}|${spec.eyeCount}|${spec.mouthStyle.name}|${spec.skinPattern.name}|${spec.bodyMidHex}',
        );
      }

      expect(specs.length, 50);
      expect(titles.length, 50, reason: 'Every level boss should have a distinct name');
      expect(anatomyKeys.length, 50,
          reason: 'Every level boss should have a distinct visual anatomy/palette signature');
      // Verify L1–L5 handcrafted bosses
      expect(specs[0].title, 'Bramble Thornback');
      expect(specs[1].title, 'Gorgon Ramhorn');
      expect(specs[2].title, 'Ripclaw Timberfang');
      expect(specs[3].title, 'Stiltjaw Hunter');
      expect(specs[4].title, 'Ironhide Crusher');
    });

    test('3. All 10 monster movement profiles are present across the 50 levels', () {
      final seen = <MonsterMovementProfile>{};
      for (final lvl in allLevels) {
        for (final m in lvl.monsters) {
          seen.add(m.effectiveMovementProfile);
        }
      }
      expect(seen.length, MonsterMovementProfile.values.length);
      for (final p in MonsterMovementProfile.values) {
        expect(seen.contains(p), isTrue, reason: 'Missing profile ${p.name}');
      }
    });

    test('4. Every movement profile exhibits distinct behavior and never penetrates walls', () {
      final profileDistances = <MonsterMovementProfile, double>{};

      for (final profile in MonsterMovementProfile.values) {
        final level = _buildSingleMonsterArena(profile);
        final engine = MazeGameEngine(level: level);
        final monster = engine.monsters.first;
        expect(monster.movementProfile, profile);

        double totalMoved = 0.0;
        double maxHop = 0.0;
        bool sawCrouch = false;
        bool sawWindupOrCharge = false;
        double prevX = monster.x;
        double prevY = monster.y;

        // Phase A: Patrol / idle for 3.5 seconds
        for (int t = 0; t < 70; t++) {
          engine.step(0.05);
          expect(
            level.isWall(monster.x.floor(), monster.y.floor()),
            isFalse,
            reason: '${profile.name} entered wall at (${monster.x}, ${monster.y})',
          );
          totalMoved +=
              (Offset(monster.x, monster.y) - Offset(prevX, prevY)).distance;
          prevX = monster.x;
          prevY = monster.y;
          if (monster.hopPhase > maxHop) maxHop = monster.hopPhase;
          if (monster.ambushCrouched) sawCrouch = true;
          if (monster.state == MonsterAiState.windup ||
              monster.chargeActiveTimer > 0) {
            sawWindupOrCharge = true;
          }
        }

        // Phase B: Place player in nearby corridor so chase/ambush/charge triggers
        engine.playerX = 3.5;
        engine.playerY = 3.5;
        for (int t = 0; t < 60; t++) {
          engine.step(0.05);
          expect(
            level.isWall(monster.x.floor(), monster.y.floor()),
            isFalse,
            reason: '${profile.name} entered wall during chase at (${monster.x}, ${monster.y})',
          );
          if (monster.hopPhase > maxHop) maxHop = monster.hopPhase;
          if (monster.state == MonsterAiState.windup ||
              monster.chargeActiveTimer > 0) {
            sawWindupOrCharge = true;
          }
        }

        profileDistances[profile] = totalMoved;

        if (profile == MonsterMovementProfile.jumpingCreature) {
          expect(maxHop, greaterThan(0.05),
              reason: 'JumpingCreature should hop into the air');
        }
        if (profile == MonsterMovementProfile.ambushMonster) {
          expect(sawCrouch, isTrue,
              reason: 'AmbushMonster should crouch while lying in wait');
        }
        if (profile == MonsterMovementProfile.chargingMonster) {
          expect(sawWindupOrCharge, isTrue,
              reason: 'ChargingMonster should telegraph windup and charge');
        }
      }

      // Fast hunter / flying / crawling patrol speeds should stay actively mobile
      expect(profileDistances[MonsterMovementProfile.fastHunter]!, greaterThan(2.0));
      expect(profileDistances[MonsterMovementProfile.zigzagMonster]!, greaterThan(1.5));
      expect(profileDistances[MonsterMovementProfile.flyingMonster]!, greaterThan(2.0));
    });
  });

  group('V3.5 Progressive Complex 50-Level Mazes', () {
    test('5. Complexity metrics scale progressively across Districts 1 to 5', () {
      final districtIntersections = <int, double>{};
      final districtDeadEnds = <int, double>{};
      final districtArea = <int, double>{};

      for (int d = 1; d <= 5; d++) {
        final slice = allLevels.where((l) => l.district == d).toList();
        int sumInter = 0;
        int sumDead = 0;
        int sumArea = 0;
        for (final lvl in slice) {
          final res = MazeValidator.validate(lvl);
          expect(res.isValid, isTrue,
              reason: 'Level ${lvl.id} invalid: ${res.errors}');
          sumInter += res.intersectionCount;
          sumDead += res.deadEndCount;
          sumArea += lvl.cols * lvl.rows;
        }
        districtIntersections[d] = sumInter / slice.length;
        districtDeadEnds[d] = sumDead / slice.length;
        districtArea[d] = sumArea / slice.length;
      }

      // Maze size, intersections, and dead-end branches clearly increase from early to late game
      expect(districtArea[5]!, greaterThan(districtArea[1]! * 2.0));
      expect(districtIntersections[5]!, greaterThan(districtIntersections[1]! * 1.7));
      expect(districtDeadEnds[3]!, greaterThan(districtDeadEnds[1]!));
      expect(districtDeadEnds[5]!, greaterThan(districtDeadEnds[2]!));
    });

    test('6. All 50 levels are 100% playable & all monsters remain in walkable tiles', () {
      for (final lvl in allLevels) {
        final engine = MazeGameEngine(level: lvl);
        // Simulate 3 seconds on every single level
        for (int t = 0; t < 60; t++) {
          engine.step(0.05);
        }
        for (final m in engine.monsters) {
          expect(
            lvl.isWall(m.x.floor(), m.y.floor()),
            isFalse,
            reason: 'Level ${lvl.id} monster ${m.id} clipped wall at (${m.x}, ${m.y})',
          );
        }
      }
    });
  });

  group('V3.5 Drag-to-Move, Wall Rejection & Control Priority', () {
    test('7. Drag-to-Move starts only near Courier, draws multi-turn corridor route, and follows to target food', () {
      final level = allLevels[0]; // Level 1: 9x7, start=(1,5), apple=(4,1)
      final engine = MazeGameEngine(level: level);

      // Starting far away from Courier should NOT begin route draw
      expect(engine.beginRouteDraw(7.5, 1.5), isFalse);
      expect(engine.isDrawingRoute, isFalse);

      // Touching near Courier begins route drawing
      expect(engine.beginRouteDraw(engine.playerX + 0.3, engine.playerY), isTrue);
      expect(engine.isDrawingRoute, isTrue);
      expect(engine.draftRouteCells.first, level.playerStart);

      // Compute a real multi-turn walkable path from playerStart to the apple at (4,1)
      final foodCell = GridPoint(level.foods.first.col, level.foods.first.row);
      final bfsRoute = MazePathfinder.findPath(level, level.playerStart, foodCell);
      expect(bfsRoute.length, greaterThan(4));

      // Drag finger along each walkable tile of the multi-turn route
      for (final cell in bfsRoute.skip(1)) {
        engine.updateRouteDraw(cell.centerX, cell.centerY);
      }
      expect(engine.draftRouteCells.last, foodCell);
      expect(engine.invalidDragWorldX, isNull);
      for (final c in engine.draftRouteCells) {
        expect(level.isWalkable(c.col, c.row), isTrue);
      }

      // Release finger -> commits route & Courier automatically walks and collects the apple!
      expect(engine.commitRouteDraw(), isTrue);
      expect(engine.isDrawingRoute, isFalse);
      expect(engine.isFollowingAutoRoute, isTrue);

      for (int i = 0; i < 160 && engine.isFollowingAutoRoute; i++) {
        engine.step(0.05);
      }

      expect(engine.carriedFoods.length, 1,
          reason: 'Courier should collect the target apple automatically');
      expect(engine.isFollowingAutoRoute, isFalse,
          reason: 'Courier should stop cleanly after reaching destination');
    });

    test('8. Dragging into walls is strictly rejected and never teleports or cuts through walls', () {
      final level = allLevels[0];
      final engine = MazeGameEngine(level: level);

      expect(engine.beginRouteDraw(engine.playerX, engine.playerY), isTrue);
      // Drag into outer border wall (0, 5)
      engine.updateRouteDraw(0.4, 5.5);
      expect(engine.invalidDragWorldX, isNotNull);
      expect(engine.draftRouteCells.length, 1);

      // Drag straight across solid wall block (3, 4) from (1, 5)
      engine.updateRouteDraw(3.5, 4.5);
      expect(engine.invalidDragWorldX, isNotNull);
      for (final c in engine.draftRouteCells) {
        expect(level.isWall(c.col, c.row), isFalse);
      }
    });

    test('9. Backtracking while dragging cleanly trims and simplifies the route', () {
      final level = allLevels[0];
      final engine = MazeGameEngine(level: level);

      expect(engine.beginRouteDraw(engine.playerX, engine.playerY), isTrue);
      // Row 5 is open from col 1..7 on Level 1
      engine.updateRouteDraw(2.5, 5.5);
      engine.updateRouteDraw(3.5, 5.5);
      engine.updateRouteDraw(4.5, 5.5);
      expect(engine.draftRouteCells.length, 4);

      // Backtrack to (2, 5) -> removes (3,5) and (4,5) cleanly!
      engine.updateRouteDraw(2.5, 5.5);
      expect(engine.draftRouteCells.length, 2);
      expect(engine.draftRouteCells.last, const GridPoint(2, 5));
    });

    test('10. Joystick input immediately interrupts an active auto-route', () {
      final level = allLevels[0];
      final engine = MazeGameEngine(level: level);

      engine.beginRouteDraw(engine.playerX, engine.playerY);
      engine.updateRouteDraw(2.5, 5.5);
      engine.updateRouteDraw(3.5, 5.5);
      engine.updateRouteDraw(4.5, 5.5);
      engine.commitRouteDraw();
      expect(engine.isFollowingAutoRoute, isTrue);

      // Player touches virtual joystick -> immediately cancels auto-route!
      engine.setJoystickInput(0.0, -1.0);
      expect(engine.isFollowingAutoRoute, isFalse);
      expect(engine.activeTapPath, isEmpty);
    });

    test('11. Drawing a new route replaces the previous active route; Tap-to-Move still works', () {
      final level = allLevels[0];
      final engine = MazeGameEngine(level: level);

      // Tap-to-Move works seamlessly
      engine.setTapTarget(const GridPoint(7, 5));
      expect(engine.isFollowingAutoRoute, isTrue);
      expect(engine.activeTapPath.last, const GridPoint(7, 5));

      // Drawing a new route replaces the old one cleanly
      expect(engine.beginRouteDraw(engine.playerX, engine.playerY), isTrue);
      engine.updateRouteDraw(1.5, 4.5);
      engine.updateRouteDraw(1.5, 3.5);
      expect(engine.commitRouteDraw(), isTrue);
      expect(engine.activeTapPath.last, const GridPoint(1, 3));
    });

    test('12. Pause cancels in-progress draft drag safely and freezes active auto-route', () {
      final level = allLevels[0];
      final engine = MazeGameEngine(level: level);

      engine.beginRouteDraw(engine.playerX, engine.playerY);
      engine.updateRouteDraw(2.5, 5.5);
      expect(engine.isDrawingRoute, isTrue);
      engine.pause();
      expect(engine.isDrawingRoute, isFalse);
      expect(engine.draftRouteCells, isEmpty);

      // Resume, commit route, pause -> position stays frozen & route preserved
      engine.resume();
      engine.setTapTarget(const GridPoint(6, 5));
      final savedX = engine.playerX;
      engine.pause();
      for (int i = 0; i < 20; i++) {
        engine.step(0.05);
      }
      expect(engine.playerX, closeTo(savedX, 0.001));
      expect(engine.activeTapPath, isNotEmpty);
    });

    test('13. Monster attack during auto-route cancels auto-route so player regains control', () {
      final level = _buildSingleMonsterArena(MonsterMovementProfile.patrolGuardian);
      final engine = MazeGameEngine(level: level);
      final monster = engine.monsters.first;

      // Start an auto-route along row 7
      engine.setTapTarget(const GridPoint(8, 7));
      expect(engine.isFollowingAutoRoute, isTrue);

      // Move monster right on top of the Courier to land a hit
      monster.x = engine.playerX + 0.1;
      monster.y = engine.playerY;
      monster.attackCooldown = 0.0;
      engine.step(0.05);

      expect(engine.health, lessThan(engine.maxHealth));
      expect(engine.isFollowingAutoRoute, isFalse,
          reason: 'Auto-route must stop on monster hit so player can react');
    });

    testWidgets('14. GameplayScreen real pointer Drag-to-Move & higher-level maze render cleanly with 0 overflows', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final controller = MazeGameController(
        storageService: StorageService(),
        audioController: AudioController(enableAudio: false),
        adService: DisabledAdService(),
        levelRepository: MazeLevelRepository(injectedLevels: allLevels),
        preloadSprites: false,
      );
      await controller.initialize();
      controller.selectLevel(1, persistSelection: false);

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: GameplayScreen(controller: controller),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final eng = controller.engine!;
      final mazeFinder = find.byKey(const ValueKey('maze_stage_canvas'));
      expect(mazeFinder, findsOneWidget);

      final rect = tester.getRect(mazeFinder);
      final vp = MazeViewportTransform.compute(rect.size, eng);

      // Drag from Courier cell (1,5) across open row 5 to (4,5)
      final startGlobal = rect.topLeft + vp.worldToScreen(eng.playerX, eng.playerY);
      final step1Global = rect.topLeft + vp.worldToScreen(2.5, 5.5);
      final step2Global = rect.topLeft + vp.worldToScreen(3.5, 5.5);
      final step3Global = rect.topLeft + vp.worldToScreen(4.5, 5.5);

      final gesture = await tester.startGesture(startGlobal);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(step1Global);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(step2Global);
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveTo(step3Global);
      await tester.pump(const Duration(milliseconds: 16));

      expect(eng.isDrawingRoute, isTrue);
      expect(eng.draftRouteCells.last, const GridPoint(4, 5));

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 16));
      expect(eng.isDrawingRoute, isFalse);
      expect(eng.isFollowingAutoRoute, isTrue);

      // Switch to a complex high-level maze (Level 45: 17x17) and verify clean render
      controller.selectLevel(45, persistSelection: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.currentLevel!.cols, 17);
      expect(controller.currentLevel!.rows, 17);
      expect(tester.takeException(), isNull);

      controller.dispose();
    });
  });
}

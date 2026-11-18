import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/controllers/audio_controller.dart';
import 'package:parcel_escape/src/controllers/maze_game_controller.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/models/maze/combat_models.dart';
import 'package:parcel_escape/src/models/maze/delivery_state.dart';
import 'package:parcel_escape/src/models/maze/food_item.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/truck_defense_models.dart';
import 'package:parcel_escape/src/rendering/maze/maze_canvas_painter.dart';
import 'package:parcel_escape/src/screens/gameplay_screen.dart';
import 'package:parcel_escape/src/services/ad_service.dart';
import 'package:parcel_escape/src/services/maze_level_repository.dart';
import 'package:parcel_escape/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<MazeLevel> _loadAllLevels() {
  final raw = jsonDecode(
    File('assets/levels/maze_levels.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (raw['levels'] as List)
      .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  late List<MazeLevel> allLevels;

  setUpAll(() {
    allLevels = _loadAllLevels();
  });

  group('V3.3 Monster Cage, Winding Road & Truck Defense Tests', () {
    test('1. Boss stays locked inside cage during food collection and cannot attack or escape early', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);

      expect(engine.phase, MazeGamePhase.playing);
      expect(engine.truckDefense.cageState, BossCageState.locked);
      expect(engine.truckDefense.boss.isCaged, isTrue);
      expect(engine.truckDefense.ally.hasKnifeDrawn, isFalse);

      // Step 5 seconds of Maze gameplay (idle cage shaking only)
      for (int i = 0; i < 100; i++) {
        engine.step(0.05);
      }
      expect(engine.truckDefense.cageState, BossCageState.locked);
      expect(engine.truckDefense.boss.isCaged, isTrue);
      expect(engine.truckDefense.truck.hp, 100);
      expect(engine.truckDefense.truck.traveledDistance, 0.0);
      expect(engine.truckDefense.ally.hasKnifeDrawn, isFalse);

      // Attempting to damage boss while caged has zero effect
      final initialBossHp = engine.truckDefense.boss.hp;
      engine.truckDefense.damageBoss(damage: 50, fromPlayer: true);
      expect(engine.truckDefense.boss.hp, initialBossHp);
    });

    test('2 & 3. Loading completion triggers cage escape strictly ONCE; Dock Worker draws knife ONLY after escape', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      int cageBreakCount = 0;
      engine.callbacks = MazeEngineCallbacks(
        onCageBreakOpen: () => cageBreakCount++,
      );
      engine.reset();

      // Deliver only 4 of 5 foods -> 80% >= 60% quota, BUT 1 collectable food still remains!
      // Boss escape MUST NOT trigger while collectable food still waits on map!
      for (int i = 0; i < engine.foods.length - 1; i++) {
        engine.foods[i].status = FoodStatus.delivered;
        engine.truckLoadedFoods.add(engine.foods[i]);
      }
      engine.step(0.02);
      expect(engine.phase, MazeGamePhase.playing);
      expect(engine.truckDefense.cageState, BossCageState.locked);
      expect(engine.truckDefense.ally.hasKnifeDrawn, isFalse);

      // Now collect & deliver the final 5th food item!
      final lastFood = engine.foods.last;
      engine.playerX = lastFood.spawnCol + 0.5;
      engine.playerY = lastFood.spawnRow + 0.5;
      engine.step(0.02);
      engine.playerX = level18.exitCell.centerX;
      engine.playerY = level18.exitCell.centerY;
      engine.step(0.02);

      // Must enter FOOD_LOADING_COMPLETE, NOT instant victory!
      expect(engine.phase, MazeGamePhase.foodLoadingComplete);
      expect(engine.truckDefense.escapeTriggered, isTrue);
      expect(engine.truckDefense.ally.hasKnifeDrawn, isFalse);

      // Duplicate escape trigger call must be strictly rejected
      expect(engine.truckDefense.beginFoodLoadingComplete(), isFalse);

      // Step through foodLoadingComplete -> cageEscapeCutscene -> truckDefensePlaying
      final mazeTimeAtLoad = engine.remainingTime;
      bool sawCutscene = false;
      for (int i = 0; i < 80; i++) {
        engine.step(0.05);
        if (engine.phase == MazeGamePhase.cageEscapeCutscene) {
          sawCutscene = true;
        }
        if (engine.phase == MazeGamePhase.truckDefensePlaying) break;
      }

      expect(sawCutscene, isTrue);
      expect(engine.phase, MazeGamePhase.truckDefensePlaying);
      expect(cageBreakCount, 1);
      expect(engine.truckDefense.cageState, BossCageState.escaped);
      expect(engine.truckDefense.ally.hasKnifeDrawn, isTrue);
      // Maze timer stopped cleanly when loading completed!
      expect(engine.remainingTime, closeTo(mazeTimeAtLoad, 0.06));
    });

    test('4, 5 & 6. Truck moves along winding road after escape, rotates smoothly along curves, and updates distance progress', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);

      // Deliver all food & enter Truck Defense
      for (final f in engine.foods) {
        f.status = FoodStatus.carried;
      }
      engine.playerX = level18.exitCell.centerX;
      engine.playerY = level18.exitCell.centerY;
      engine.step(0.02);
      engine.skipEscapeCutscene();
      expect(engine.phase, MazeGamePhase.truckDefensePlaying);

      // Neutralize boss so we measure pure truck spline driving & curve turning
      engine.truckDefense.boss.hp = 0;
      engine.truckDefense.boss.aiState = BossCombatAiState.defeated;

      final startAngle = engine.truckDefense.truck.angle;
      final observedAngles = <double>{};
      double prevDist = 0.0;

      for (int i = 0; i < 200; i++) {
        engine.step(0.05);
        final dist = engine.truckDefense.truck.traveledDistance;
        expect(dist, greaterThanOrEqualTo(prevDist));
        prevDist = dist;
        observedAngles.add((engine.truckDefense.truck.angle * 4).round() / 4.0);
        if (engine.phase == MazeGamePhase.truckArrived) break;
      }

      // Truck traveled significant distance & rotated through multiple curve directions!
      expect(engine.truckDefense.truck.traveledDistance, greaterThan(5.0));
      expect(observedAngles.length, greaterThanOrEqualTo(3));
      expect(engine.truckDefense.destinationProgressPercent, greaterThan(20));
      expect(startAngle.isFinite, isTrue);
    });

    test('7 & 8. Boss attacks reduce Truck HP accurately; Tire damage slows truck without 1-shotting it', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      final truck = engine.truckDefense.truck;
      expect(truck.hp, 100);
      expect(truck.damageState, TruckDamageState.healthy);
      final normalSpeedMult = truck.currentSpeedMultiplier;

      // Apply Tire Attack -> flashes tire, slows truck, never 1-hit destroys!
      engine.truckDefense.damageTruck(10, isTireAttack: true);
      expect(truck.hp, 90);
      expect(truck.isDestroyed, isFalse);
      expect(truck.isTireDamaged, isTrue);
      expect(truck.tireFlashTimer, greaterThan(0.0));
      expect(truck.currentSpeedMultiplier, lessThan(normalSpeedMult));

      // Apply heavy bomb & charge damage -> Damaged -> Critical states
      engine.truckDefense.damageTruck(35);
      expect(truck.hp, 55);
      expect(truck.damageState, TruckDamageState.damaged);

      engine.truckDefense.damageTruck(35);
      expect(truck.hp, 20);
      expect(truck.damageState, TruckDamageState.critical);

      // One-use Roadside Repair Kit heals truck & fixes tires cleanly ONCE!
      engine.truckDefense.playerX = engine.truckDefense.repairKit.x;
      engine.truckDefense.playerY = engine.truckDefense.repairKit.y;
      engine.step(0.05);
      expect(engine.truckDefense.repairKit.collected, isTrue);
      expect(truck.hp, greaterThan(20));
      expect(truck.tireCondition, 100);
      expect(truck.tireSlowTimer, 0.0);
    });

    test('9. Player weapons (Bow, Blaster, Freeze Orb, Melee) damage & stun/freeze escaped Boss', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      // Enter Truck Defense cleanly
      for (final f in engine.foods) {
        f.status = FoodStatus.carried;
      }
      engine.playerX = level18.exitCell.centerX;
      engine.playerY = level18.exitCell.centerY;
      engine.step(0.02);
      engine.skipEscapeCutscene();

      final boss = engine.truckDefense.boss;
      final startHp = boss.hp;
      // Place courier close to boss and fire Bow & Freeze Orb!
      engine.truckDefense.playerX = boss.x - 1.5;
      engine.truckDefense.playerY = boss.y;

      expect(engine.useWeapon(WeaponType.bow), isTrue);
      for (int i = 0; i < 15; i++) {
        engine.step(0.03);
      }
      expect(boss.hp, lessThan(startHp));

      final hpAfterBow = boss.hp;
      expect(engine.useWeapon(WeaponType.freezeOrb), isTrue);
      for (int i = 0; i < 20; i++) {
        engine.step(0.03);
      }
      expect(boss.hp, lessThan(hpAfterBow));
      expect(boss.freezeTimer, greaterThan(0.0));
    });

    test('10. Dock Worker Ally attacks ONLY valid nearby targets and cannot solo-win effortlessly', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      final ally = engine.truckDefense.ally;
      final boss = engine.truckDefense.boss;
      expect(ally.hasKnifeDrawn, isTrue);

      // Far boss (> 4 units from truck) -> Ally stays escorting truck & does NOT slash
      boss.x = RoadArenaBounds.width - 0.8;
      boss.y = RoadArenaBounds.height - 0.8;
      for (int i = 0; i < 10; i++) {
        engine.step(0.05);
      }
      expect(ally.totalHitsLanded, 0);

      // Bring boss close to truck & ally -> Ally intercepts and lands a timed knife slash!
      boss.x = engine.truckDefense.truck.x + 0.9;
      boss.y = engine.truckDefense.truck.y + 0.5;
      ally.x = boss.x - 0.6;
      ally.y = boss.y;
      final hpBefore = boss.hp;
      engine.step(0.05);
      expect(ally.totalHitsLanded, greaterThanOrEqualTo(1));
      expect(boss.hp, lessThan(hpBefore));
      // Balanced ally damage: cannot one-shot or solo-melt the giant boss!
      expect(boss.hp, greaterThan(boss.maxHp ~/ 2));
    });

    test('11. Pausing during Truck Defense freezes truck, boss, projectiles, and defense timer', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      engine.step(0.05);
      engine.pause();
      expect(engine.phase, MazeGamePhase.paused);

      final frozenDist = engine.truckDefense.truck.traveledDistance;
      final frozenBossX = engine.truckDefense.boss.x;
      final frozenTimer = engine.truckDefense.defenseRemainingTime;

      for (int i = 0; i < 40; i++) {
        engine.step(0.05);
      }

      expect(engine.truckDefense.truck.traveledDistance, frozenDist);
      expect(engine.truckDefense.boss.x, frozenBossX);
      expect(engine.truckDefense.defenseRemainingTime, frozenTimer);

      // Resume restores Truck Defense cleanly!
      engine.resume();
      expect(engine.phase, MazeGamePhase.truckDefensePlaying);
      engine.step(0.05);
      expect(engine.truckDefense.truck.traveledDistance, greaterThan(frozenDist));
    });

    test('12 & 13. Truck destruction triggers defeat ("Delivery Failed — Truck Stopped!"); Destination arrival triggers victory', () {
      // Scenario A: Failure (Level 18 Truck Destroyed)
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final failEngine = MazeGameEngine(level: level18);
      failEngine.truckDefense.skipCutscene();
      failEngine.phase = MazeGamePhase.truckDefensePlaying;

      failEngine.truckDefense.damageTruck(100);
      expect(failEngine.truckDefense.truck.isDestroyed, isTrue);

      for (int i = 0; i < 30; i++) {
        failEngine.step(0.05);
      }
      expect(failEngine.phase, MazeGamePhase.defeat);
      expect(failEngine.defeatReason, DefeatReason.truckDestroyed);
      expect(failEngine.defeatReason.title, 'Delivery Failed — Truck Stopped!');

      // Truck cannot arrive after being destroyed!
      failEngine.truckDefense.truck.traveledDistance =
          failEngine.truckDefense.truck.totalRoadLength;
      failEngine.step(0.05);
      expect(failEngine.phase, MazeGamePhase.defeat);

      // Scenario B: Success (Level 18 Destination Arrival)
      final winEngine = MazeGameEngine(level: level18);
      for (final f in winEngine.foods) {
        f.status = FoodStatus.carried;
      }
      winEngine.playerX = level18.exitCell.centerX;
      winEngine.playerY = level18.exitCell.centerY;
      winEngine.step(0.02);
      winEngine.skipEscapeCutscene();

      winEngine.truckDefense.truck.traveledDistance =
          winEngine.truckDefense.truck.totalRoadLength - 0.01;
      winEngine.step(0.05);
      expect(winEngine.phase, MazeGamePhase.truckArrived);

      for (int i = 0; i < 40; i++) {
        winEngine.step(0.05);
      }
      expect(winEngine.phase, MazeGamePhase.victory);
      expect(winEngine.finalBreakdown, isNotNull);
      expect(winEngine.finalBreakdown!.truckSurvivalBonus, greaterThan(0));
    });

    test('14 & 15. All 50 levels have valid distinct road curves, boss configs, district boss archetypes, and progression scaling', () {
      expect(allLevels.length, 50);

      final seenBossTypes = <DistrictBossType>{};
      final seenDestinations = <DestinationBuildingType>{};
      final seenRouteIds = <String>{};

      for (final level in allLevels) {
        final cfg = level.truckDefenseConfig;
        expect(cfg.bossMaxHp, greaterThanOrEqualTo(100));
        expect(cfg.truckMaxHp, 100);
        expect(cfg.unlockedAttacks, isNotEmpty);
        expect(cfg.road.controlPoints.length, greaterThanOrEqualTo(6));
        expect(cfg.road.totalLength, greaterThan(15.0));
        expect(cfg.defenseTimeLimitSeconds, greaterThanOrEqualTo(45));

        seenBossTypes.add(cfg.bossType);
        seenDestinations.add(cfg.destinationType);
        seenRouteIds.add(cfg.road.routeId);

        // Verify genuine multi-bend curvature across the full spline (not a straight line!)
        double totalTurn = 0.0;
        double prevAngle = cfg.road.sampleAtDistance(0.0).angle;
        for (int k = 1; k <= 20; k++) {
          final sample = cfg.road
              .sampleAtDistance(cfg.road.totalLength * (k / 20.0));
          double diff = (sample.angle - prevAngle).abs();
          if (diff > 3.14159) diff = (6.28318 - diff).abs();
          totalTurn += diff;
          prevAngle = sample.angle;
        }
        expect(totalTurn, greaterThan(4.0));
      }

      // All 5 districts have distinct boss identities & destination buildings
      expect(seenBossTypes.length, 5);
      expect(seenDestinations.length, 5);
      expect(seenRouteIds.length, 50);

      // Verify difficulty progression across tiers
      final lv1 = allLevels.firstWhere((l) => l.id == 1).truckDefenseConfig;
      final lv18 = allLevels.firstWhere((l) => l.id == 18).truckDefenseConfig;
      final lv50 = allLevels.firstWhere((l) => l.id == 50).truckDefenseConfig;
      expect(lv1.unlockedAttacks.length, 1);
      expect(lv18.unlockedAttacks, contains(BossAttackType.tireAttack));
      expect(lv18.unlockedAttacks, contains(BossAttackType.bombProjectile));
      expect(lv50.unlockedAttacks.length, 5);
      expect(lv50.bossMaxHp, greaterThan(lv18.bossMaxHp));
      expect(lv18.bossMaxHp, greaterThan(lv1.bossMaxHp));
    });

    testWidgets('16, 17 & 18. Level 18 renders cleanly on 360x640 and 360x800 with top-anchored maze (no huge empty top gap) and transitions seamlessly to Full-Screen Road Battle Arena', (tester) async {
      for (final screenSize in const [Size(360, 640), Size(360, 800)]) {
        tester.view.physicalSize = screenSize;
        tester.view.devicePixelRatio = 1.0;

        SharedPreferences.setMockInitialValues({});
        final controller = MazeGameController(
          storageService: StorageService(),
          levelRepository: MazeLevelRepository(injectedLevels: allLevels),
          adService: DisabledAdService(),
          audioController: AudioController(enableAudio: false),
          preloadSprites: false,
        );
        await controller.initialize();
        await controller.setReducedMotion(true);
        controller.selectLevel(18);

        await tester.pumpWidget(
          MaterialApp(home: GameplayScreen(controller: controller)),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verify top-anchored layout removes huge empty top cream region!
        final eng = controller.engine!;
        final vp = MazeViewportTransform.compute(
          Size(screenSize.width, screenSize.height - 230),
          eng,
        );
        expect(vp.originY, lessThanOrEqualTo(12.0));
        expect(vp.tileSize, greaterThanOrEqualTo(24.0));
        expect(find.text('LV 18 • Garden Market'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Deliver all Level 18 foods -> Cutscene -> Full-Screen Road Battle Arena
        for (final f in eng.foods) {
          f.status = FoodStatus.carried;
        }
        eng.playerX = eng.level.exitCell.centerX;
        eng.playerY = eng.level.exitCell.centerY;
        eng.step(0.02);
        await tester.pump(const Duration(milliseconds: 60));

        expect(eng.phase, MazeGamePhase.foodLoadingComplete);
        controller.skipEscapeCutscene();
        await tester.pump(const Duration(milliseconds: 80));

        expect(eng.phase, MazeGamePhase.truckDefensePlaying);
        expect(find.textContaining('Truck HP: 100/100'), findsOneWidget);
        expect(find.textContaining('Destination Progress:'), findsOneWidget);
        expect(find.text('Ally Guard Active'), findsOneWidget);
        expect(tester.takeException(), isNull);

        controller.dispose();
      }
      tester.view.resetPhysicalSize();
    });
  });
}

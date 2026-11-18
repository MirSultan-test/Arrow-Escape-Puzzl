import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/controllers/audio_controller.dart';
import 'package:parcel_escape/src/controllers/maze_game_controller.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/models/maze/delivery_state.dart';
import 'package:parcel_escape/src/models/maze/food_item.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/monster.dart';
import 'package:parcel_escape/src/models/save_data.dart';
import 'package:parcel_escape/src/services/ad_service.dart';
import 'package:parcel_escape/src/services/maze_level_repository.dart';
import 'package:parcel_escape/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper constructing a clean deterministic test arena.
MazeLevel _buildArena({
  List<FoodSpawn>? foods,
  List<MonsterDefinition>? monsters,
  int cargoCapacity = 2,
  int timeLimitSeconds = 60,
  int minQuotaPercent = 60,
  GridPoint playerStart = const GridPoint(1, 2),
}) {
  return MazeLevel(
    id: 99,
    district: 1,
    title: 'Test Arena',
    subtitle: 'Deterministic test maze',
    cols: 7,
    rows: 5,
    grid: const [
      '#######',
      '#.....#',
      '#..#..E',
      '#.....#',
      '#######',
    ],
    playerStart: playerStart,
    exitCell: const GridPoint(6, 2),
    cargoCapacity: cargoCapacity,
    timeLimitSeconds: timeLimitSeconds,
    minQuotaPercent: minQuotaPercent,
    starThresholds: const [80, 180, 260],
    foods: foods ??
        const [
          FoodSpawn(id: 'f1', type: FoodType.apple, col: 2, row: 1, basePoints: 100),
          FoodSpawn(id: 'f2', type: FoodType.banana, col: 4, row: 1, basePoints: 100),
        ],
    monsters: monsters ?? const [],
  );
}

void main() {
  group('Food Maze Engine — Core Gameplay & Rules (Section 22)', () {
    test('1. Player movement stops cleanly at maze walls', () {
      final level = _buildArena(playerStart: const GridPoint(1, 2));
      final engine = MazeGameEngine(level: level);

      // Push directly left into outer wall at col 0
      engine.setJoystickInput(-1.0, 0.0);
      for (int i = 0; i < 60; i++) {
        engine.step(0.05);
      }

      // Player center must stay strictly outside col 0 wall (>= 1.0 + radius)
      expect(engine.playerX, greaterThanOrEqualTo(1.0 + MazeGameEngine.playerRadius - 0.01));
      expect(level.isWall(engine.playerCell.col, engine.playerCell.row), isFalse);

      // Push directly right into interior wall at (3, 2)
      engine.reset();
      engine.setJoystickInput(1.0, 0.0);
      for (int i = 0; i < 60; i++) {
        engine.step(0.05);
      }
      expect(engine.playerX, lessThanOrEqualTo(3.0 - MazeGameEngine.playerRadius + 0.01));
    });

    test('2 & 3. Food pickup updates cargo and strictly enforces carrying capacity', () {
      final level = _buildArena(
        cargoCapacity: 2,
        foods: const [
          FoodSpawn(id: 'a1', type: FoodType.apple, col: 2, row: 1),
          FoodSpawn(id: 'b1', type: FoodType.banana, col: 3, row: 1),
          FoodSpawn(id: 'm1', type: FoodType.mango, col: 4, row: 1),
        ],
        playerStart: const GridPoint(1, 1),
      );
      bool cargoFullTriggered = false;
      final engine = MazeGameEngine(
        level: level,
        callbacks: MazeEngineCallbacks(
          onCargoFull: () => cargoFullTriggered = true,
        ),
      );

      // Walk right across all 3 fruits
      engine.setJoystickInput(1.0, 0.0);
      for (int i = 0; i < 45; i++) {
        engine.step(0.05);
      }

      expect(engine.carriedFoods.length, 2);
      expect(engine.carriedFoods.map((f) => f.id).toSet(), {'a1', 'b1'});
      expect(engine.onMapFoods.map((f) => f.id).toList(), ['m1']);
      expect(engine.isCargoFull, isTrue);
      expect(cargoFullTriggered, isTrue);
    });

    test('4, 5, 6, 7 & 8. Monster attack reduces food condition, preserves separate conditions, decrements health, enforces cooldown, and consumed food earns 0', () {
      final level = _buildArena(
        cargoCapacity: 2,
        foods: const [
          FoodSpawn(id: 'a1', type: FoodType.apple, col: 2, row: 1, basePoints: 100),
          FoodSpawn(id: 'b1', type: FoodType.banana, col: 3, row: 1, basePoints: 100),
        ],
        monsters: const [
          MonsterDefinition(
            id: 'm1',
            type: MonsterType.redHunter,
            start: GridPoint(4, 1),
            patrolPath: [GridPoint(4, 1)],
            biteDamage: 50,
          ),
        ],
        playerStart: const GridPoint(1, 1),
      );
      final engine = MazeGameEngine(level: level);

      // Walk into apple & banana, then contact monster at (4, 1) and stop next to it
      engine.setJoystickInput(1.0, 0.0);
      for (int i = 0; i < 30; i++) {
        engine.step(0.05);
        if (engine.health < 3) break;
      }
      engine.setJoystickInput(0.0, 0.0);

      // First hit: apple drops to 50%, banana untouched at 100%, health drops 3 -> 2
      expect(engine.health, 2);
      final apple = engine.foods.firstWhere((f) => f.id == 'a1');
      final banana = engine.foods.firstWhere((f) => f.id == 'b1');
      expect(apple.conditionPercent, 50);
      expect(banana.conditionPercent, 100);

      // Verify cooldown prevents duplicate instant damage on subsequent frames
      for (int i = 0; i < 10; i++) {
        engine.step(0.05); // 0.5s < 1.65s cooldown
      }
      expect(engine.health, 2);
      expect(apple.conditionPercent, 50);

      // Wait for cooldown to expire (another ~1.5s) while still adjacent -> second bite consumes apple completely!
      for (int i = 0; i < 35; i++) {
        engine.step(0.05);
        if (engine.health < 2) break;
      }
      expect(engine.health, 1);
      expect(apple.conditionPercent, 0);
      expect(apple.status, FoodStatus.consumed);
      expect(apple.earnedPoints, 0);
      expect(banana.conditionPercent, 100);
      expect(banana.status, FoodStatus.carried);
    });

    test('9. Monsters cannot move through maze walls during patrol or chase', () {
      final level = _buildArena(
        playerStart: const GridPoint(1, 2),
        monsters: const [
          MonsterDefinition(
            id: 'h1',
            type: MonsterType.hunter,
            start: GridPoint(4, 2),
            patrolPath: [GridPoint(4, 2), GridPoint(5, 2)],
            detectionRange: 6.0,
            speed: 3.0,
          ),
        ],
      );
      final engine = MazeGameEngine(level: level);

      // Step 4 seconds while hunter chases around center wall (3, 2)
      for (int i = 0; i < 80; i++) {
        engine.step(0.05);
        final m = engine.monsters.first;
        expect(level.isWall(m.x.floor(), m.y.floor()), isFalse,
            reason: 'Monster entered a wall cell at (${m.x}, ${m.y})');
      }
    });

    test('10, 11, 12, 15 & 17. Collector receives cargo, truck loads & departs only on objective completion, partial-food quota & scoring work', () {
      final level = _buildArena(
        cargoCapacity: 2,
        minQuotaPercent: 60,
        timeLimitSeconds: 60,
        playerStart: const GridPoint(5, 2),
        foods: const [
          FoodSpawn(id: 'a1', type: FoodType.apple, col: 5, row: 1, basePoints: 100),
          FoodSpawn(id: 'b1', type: FoodType.banana, col: 5, row: 3, basePoints: 100),
        ],
      );
      final engine = MazeGameEngine(level: level);

      // Walking onto exit while empty must NOT trigger delivery or truck departure
      engine.setJoystickInput(1.0, 0.0);
      for (int i = 0; i < 15; i++) {
        engine.step(0.05);
      }
      expect(engine.deliveredFoods, isEmpty);
      expect(engine.phase, MazeGamePhase.playing);
      expect(engine.truckState, TruckAnimState.waiting);

      // Collect apple (5,1), simulate 25% bite damage, deliver apple first
      engine.playerX = 5.5;
      engine.playerY = 1.5;
      engine.step(0.02);
      expect(engine.carriedFoods.length, 1);
      engine.carriedFoods.first.applyBite(25); // 75% remaining -> 75 pts

      // Deliver apple at exit (6,2) -> banana still on map so truck must NOT depart yet!
      engine.playerX = 6.3;
      engine.playerY = 2.5;
      engine.step(0.02);
      expect(engine.deliveredFoods.length, 1);
      expect(engine.truckLoadedFoods.length, 1);
      expect(engine.phase, MazeGamePhase.playing);

      // Collect banana (5,3) at 100% and deliver -> now all food delivered (88% >= 60% quota!)
      engine.playerX = 5.5;
      engine.playerY = 3.5;
      engine.step(0.02);
      engine.playerX = 6.3;
      engine.playerY = 2.5;
      engine.step(0.02);

      expect(engine.deliveredFoods.length, 2);
      expect(engine.truckLoadedFoods.length, 2);
      // V3.3: Loading all food triggers FOOD_LOADING_COMPLETE (never instant victory!)
      expect(engine.phase, MazeGamePhase.foodLoadingComplete);
      expect(engine.collectorState, CollectorAnimState.surprised);

      // Advance through escape cutscene into active Truck Defense
      engine.skipEscapeCutscene();
      expect(engine.phase, MazeGamePhase.truckDefensePlaying);
      expect(engine.truckState, TruckAnimState.drivingOnRoad);

      // Drive truck cleanly to destination arrival (defending or boss cleared)
      engine.truckDefense.boss.hp = 0;
      engine.truckDefense.truck.traveledDistance =
          engine.truckDefense.truck.totalRoadLength - 0.02;
      engine.step(0.05);
      expect(engine.phase, MazeGamePhase.truckArrived);
      engine.skipEscapeCutscene();
      expect(engine.phase, MazeGamePhase.victory);
      expect(engine.truckState, TruckAnimState.arrived);

      final b = engine.finalBreakdown!;
      // Apple (75) + Banana (100) = 175 delivered food score
      expect(b.deliveredFoodScore, 175);
      expect(b.survivalBonus, 60); // 3 hearts * 20
      expect(
        b.totalScore,
        b.deliveredFoodScore +
            b.timeBonus +
            b.survivalBonus +
            b.truckSurvivalBonus +
            b.defensePerformanceBonus,
      );
      expect(b.coinsEarned, b.totalScore ~/ 100);
      expect(b.deliveredPercent, 88);
    });

    test('13 & 14. Pausing stops simulation & countdown; timer expiration causes defeat', () {
      final level = _buildArena(timeLimitSeconds: 5);
      final engine = MazeGameEngine(level: level);

      engine.setJoystickInput(0.0, -1.0);
      engine.pause();
      final startY = engine.playerY;
      for (int i = 0; i < 60; i++) {
        engine.step(0.05);
      }
      // Completely frozen while paused
      expect(engine.remainingTime, 5.0);
      expect(engine.playerY, startY);
      expect(engine.phase, MazeGamePhase.paused);

      // Resume and let countdown expire
      engine.resume();
      for (int i = 0; i < 120; i++) {
        engine.step(0.05);
      }
      expect(engine.remainingTime, 0.0);
      expect(engine.phase, MazeGamePhase.defeat);
      expect(engine.defeatReason, DefeatReason.timeExpired);
    });

    test('16. Losing all 3 hearts causes healthDepleted defeat', () {
      final level = _buildArena(
        playerStart: const GridPoint(2, 1),
        foods: const [
          FoodSpawn(id: 'f1', type: FoodType.apple, col: 5, row: 3),
        ],
        monsters: const [
          MonsterDefinition(
            id: 'm1',
            type: MonsterType.guardian,
            start: GridPoint(2, 1),
            patrolPath: [GridPoint(2, 1)],
          ),
        ],
      );
      final engine = MazeGameEngine(level: level);

      // Run 5 seconds so monster lands 3 cooldown-spaced hits
      for (int i = 0; i < 120; i++) {
        engine.step(0.05);
        if (engine.phase == MazeGamePhase.defeat) break;
      }
      expect(engine.health, 0);
      expect(engine.phase, MazeGamePhase.defeat);
      expect(engine.defeatReason, DefeatReason.healthDepleted);
    });

    test('18 & 19. Saved progression persists, migrates legacy V2 safely, and prevents duplicate completion rewards', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();

      // Verify legacy V2 migration retains backup & preserves unlocked access
      final legacyV2Json = jsonEncode({
        'schemaVersion': 2,
        'windupCompletedLevels': [1, 2, 3],
        'windupHighestUnlockedLevel': 4,
        'soundEnabled': false,
        'userAgeCategory': 'neutral_adult',
      });
      final migrated = SaveData.fromJsonString(legacyV2Json);
      expect(migrated.schemaVersion, SaveData.currentSchemaVersion);
      expect(migrated.windupCompletedLevels, {1, 2, 3});
      expect(migrated.mazeCompletedLevels, isEmpty);
      expect(migrated.mazeHighestUnlockedLevel, 4);
      expect(migrated.soundEnabled, isFalse);
      expect(migrated.userAgeCategory, 'neutral_adult');

      // Controller victory + idempotency check (rapid duplicate skip calls cannot award coins twice)
      final raw = jsonDecode(
          File('assets/levels/maze_levels.json').readAsStringSync()) as Map<String, dynamic>;
      final levels = (raw['levels'] as List)
          .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
          .toList();

      final controller = MazeGameController(
        storageService: storage,
        levelRepository: MazeLevelRepository(injectedLevels: levels),
        adService: DisabledAdService(),
        audioController: AudioController(enableAudio: false),
        preloadSprites: false,
      );
      await controller.initialize();
      controller.selectLevel(1);

      final eng = controller.engine!;
      // Grab Level 1 apple & deliver
      final apple = eng.level.foods.first;
      eng.playerX = apple.col + 0.5;
      eng.playerY = apple.row + 0.5;
      eng.step(0.02);
      eng.playerX = eng.level.exitCell.centerX;
      eng.playerY = eng.level.exitCell.centerY;
      eng.step(0.02);

      // V3.3: Loading food triggers cage escape, NOT instant completion!
      expect(eng.phase, MazeGamePhase.foodLoadingComplete);
      expect(controller.saveData.mazeCompletedLevels, isNot(contains(1)));

      // Skip cutscene -> Truck Defense -> arrive at destination
      controller.skipEscapeCutscene();
      expect(eng.phase, MazeGamePhase.truckDefensePlaying);
      eng.truckDefense.truck.traveledDistance =
          eng.truckDefense.truck.totalRoadLength - 0.01;
      eng.step(0.05);
      expect(eng.phase, MazeGamePhase.truckArrived);

      // Rapidly tap skip 5 times in a row during arrival -> rewards awarded STRICTLY ONCE!
      for (int i = 0; i < 5; i++) {
        controller.skipEscapeCutscene();
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final coinsAfterFirst = controller.totalCoins;
      expect(coinsAfterFirst, greaterThan(0));
      expect(controller.saveData.mazeCompletedLevels, contains(1));
      expect(controller.saveData.mazeHighestUnlockedLevel, greaterThanOrEqualTo(2));

      // Verify persisted save restores cleanly in a fresh StorageService load
      final reloaded = await storage.loadSaveData();
      expect(reloaded.mazeCompletedLevels, contains(1));
      expect(reloaded.totalCoins, coinsAfterFirst);
      expect(reloaded.mazeBestStars[1], greaterThanOrEqualTo(1));

      controller.dispose();
    });

    test('V3.1 Health Mechanic A: Collectible heart restores +1 heart, never exceeds max, and is NOT wasted at full health', () {
      const level = MazeLevel(
        id: 101,
        district: 1,
        title: 'Heart Test',
        subtitle: 'Health pickup verification',
        cols: 7,
        rows: 5,
        grid: [
          '#######',
          '#.....#',
          '#..#..#',
          '#.....#',
          '###E###',
        ],
        playerStart: GridPoint(1, 1),
        exitCell: GridPoint(3, 4),
        cargoCapacity: 2,
        timeLimitSeconds: 60,
        minQuotaPercent: 60,
        starThresholds: [80, 140, 200],
        foods: [
          FoodSpawn(id: 'a1', type: FoodType.apple, col: 5, row: 1),
        ],
        monsters: [],
        healthPickups: [
          HealthPickupSpawn(id: 'hp1', col: 2, row: 1),
          HealthPickupSpawn(id: 'hp2', col: 4, row: 1),
        ],
      );

      final engine = MazeGameEngine(level: level);
      expect(engine.health, 3);

      // Step directly onto hp1 while at FULL health (3/3) -> must NOT consume it!
      engine.playerX = 2.5;
      engine.playerY = 1.5;
      engine.step(0.02);
      expect(engine.health, 3);
      expect(engine.activeHealthPickups.length, 2);
      expect(engine.carriedFoods, isEmpty); // Never takes a bag slot

      // Reduce health to 1 -> collect hp1 -> restores to 2 (not 3), removes hp1
      engine.health = 1;
      engine.step(0.02);
      expect(engine.health, 2);
      expect(engine.activeHealthPickups.length, 1);

      // Walk onto hp2 -> restores to 3 (max), removes hp2
      engine.playerX = 4.5;
      engine.playerY = 1.5;
      engine.step(0.02);
      expect(engine.health, 3);
      expect(engine.activeHealthPickups, isEmpty);
    });

    test('V3.1 Health Mechanic B: 2 damage-free drop-offs restore +1 heart ONCE per level (cannot farm unlimited health)', () {
      const level = MazeLevel(
        id: 102,
        district: 1,
        title: 'Careful Delivery Test',
        subtitle: 'Delivery heal verification',
        cols: 7,
        rows: 5,
        grid: [
          '#######',
          '#.....#',
          '#.....#',
          '#.....#',
          '###E###',
        ],
        playerStart: GridPoint(3, 3),
        exitCell: GridPoint(3, 4),
        cargoCapacity: 1,
        timeLimitSeconds: 60,
        minQuotaPercent: 60,
        starThresholds: [80, 140, 200],
        foods: [
          FoodSpawn(id: 'f1', type: FoodType.apple, col: 1, row: 1),
          FoodSpawn(id: 'f2', type: FoodType.banana, col: 3, row: 1),
          FoodSpawn(id: 'f3', type: FoodType.mango, col: 5, row: 1),
          FoodSpawn(id: 'f4', type: FoodType.orange, col: 1, row: 3),
        ],
        monsters: [],
      );

      final engine = MazeGameEngine(level: level);
      engine.health = 1; // Player took damage earlier

      // Delivery #1: f1 -> cleanDeliveries = 1, still 1 heart
      engine.playerX = 1.5;
      engine.playerY = 1.5;
      engine.step(0.02);
      engine.playerX = 3.5;
      engine.playerY = 4.3;
      engine.step(0.02);
      expect(engine.health, 1);
      expect(engine.deliveryHealGranted, isFalse);

      // Delivery #2: f2 -> 2 clean drop-offs -> restores +1 heart (1 -> 2), marks deliveryHealGranted!
      engine.playerX = 3.5;
      engine.playerY = 1.5;
      engine.step(0.02);
      engine.playerX = 3.5;
      engine.playerY = 4.3;
      engine.step(0.02);
      expect(engine.health, 2);
      expect(engine.deliveryHealGranted, isTrue);

      // Lose 1 heart again and complete 2 MORE deliveries -> must NOT grant a second delivery heal!
      engine.health = 1;
      engine.playerX = 5.5;
      engine.playerY = 1.5;
      engine.step(0.02);
      engine.playerX = 3.5;
      engine.playerY = 4.3;
      engine.step(0.02);
      expect(engine.health, 1);

      engine.playerX = 1.5;
      engine.playerY = 3.5;
      engine.step(0.02);
      engine.playerX = 3.5;
      engine.playerY = 4.3;
      engine.step(0.02);
      expect(engine.health, 1);
    });

    test('V3.1 Hint displays only on demand and auto-dismisses after ~3.2 seconds', () {
      final level = _buildArena();
      final engine = MazeGameEngine(level: level);

      expect(engine.hintMessage, isNull);
      expect(engine.hintPath, isEmpty);

      engine.requestHint();
      expect(engine.hintMessage, isNotNull);
      expect(engine.hintPath, isNotEmpty);

      // Step 3.4 seconds -> automatically dismissed
      for (int i = 0; i < 70; i++) {
        engine.step(0.05);
      }
      expect(engine.hintMessage, isNull);
      expect(engine.hintPath, isEmpty);
    });
  });
}

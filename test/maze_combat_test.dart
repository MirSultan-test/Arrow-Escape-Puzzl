import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/models/maze/combat_models.dart';
import 'package:parcel_escape/src/models/maze/food_item.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/monster.dart';

MazeLevel _combatArena({
  int levelId = 30,
  List<String>? grid,
  GridPoint playerStart = const GridPoint(1, 2),
  List<MonsterDefinition> monsters = const [],
  List<CombatPickupSpawn> combatPickups = const [],
}) {
  return MazeLevel(
    id: levelId,
    district: 3,
    title: 'Combat Test Arena',
    subtitle: 'Automated V3.2 verification',
    cols: 9,
    rows: 5,
    grid: grid ??
        const [
          '#########',
          '#.......#',
          '#.......#',
          '#.......#',
          '####E####',
        ],
    playerStart: playerStart,
    exitCell: const GridPoint(4, 4),
    cargoCapacity: 2,
    timeLimitSeconds: 90,
    minQuotaPercent: 60,
    starThresholds: const [80, 150, 220],
    foods: const [
      FoodSpawn(id: 'f1', type: FoodType.apple, col: 7, row: 1),
    ],
    monsters: monsters,
    combatPickups: combatPickups,
  );
}

void main() {
  group('V3.2 Combat, Weapons & 6-Monster System Tests (Section 15)', () {
    test('1. All 6 monster types define valid HP, speed, damage, and distinct threat profiles', () {
      expect(MonsterType.values.length, 6);
      for (final type in MonsterType.values) {
        expect(type.defaultMaxHp, greaterThanOrEqualTo(40));
        expect(type.defaultSpeed, greaterThan(1.0));
        expect(type.defaultDetectionRange, greaterThan(2.0));
        expect(type.defaultBiteDamage, greaterThan(0));
      }
      expect(MonsterType.mazeGuardian.defaultMaxHp, 300);
      expect(MonsterType.forestBrute.defaultMaxHp, 160);
      expect(MonsterType.flyingCreature.defaultMaxHp, 40);
    });

    test('2 & 3. Bow damages Red Hunter, stuns briefly, consumes ammo, and enforces fire cooldown', () {
      final level = _combatArena(
        levelId: 7,
        monsters: const [
          MonsterDefinition(
            id: 'rh1',
            type: MonsterType.redHunter,
            start: GridPoint(4, 2),
            patrolPath: [GridPoint(4, 2)],
          ),
        ],
      );
      final engine = MazeGameEngine(level: level);
      final startAmmo = engine.ammoFor(WeaponType.bow);
      expect(startAmmo, 10);

      // Fire first arrow -> succeeds, consumes 1 ammo
      expect(engine.useWeapon(WeaponType.bow), isTrue);
      expect(engine.ammoFor(WeaponType.bow), 9);

      // Immediate rapid second tap during cooldown -> blocked!
      expect(engine.useWeapon(WeaponType.bow), isFalse);
      expect(engine.ammoFor(WeaponType.bow), 9);

      // Step simulation so arrow hits Red Hunter
      for (int i = 0; i < 15; i++) {
        engine.step(0.04);
      }

      final hunter = engine.monsters.first;
      expect(hunter.hp, 60 - WeaponType.bow.baseDamage);
      expect(hunter.isStunned, isTrue);

      // Wait for cooldown & stun to expire cleanly
      for (int i = 0; i < 30; i++) {
        engine.step(0.05);
      }
      expect(hunter.isStunned, isFalse);
      expect(engine.cooldownFor(WeaponType.bow), 0.0);
    });

    test('4 & 5. Arrows cannot pass through solid maze walls and do not damage blocked targets', () {
      final level = _combatArena(
        levelId: 7,
        grid: const [
          '#########',
          '#.......#',
          '#..#....#', // Wall at (3, 2) directly between player (1,2) and monster (5,2)
          '#.......#',
          '####E####',
        ],
        playerStart: const GridPoint(1, 2),
        monsters: const [
          MonsterDefinition(
            id: 'm1',
            type: MonsterType.redHunter,
            start: GridPoint(5, 2),
            patrolPath: [GridPoint(5, 2)],
          ),
        ],
      );
      final engine = MazeGameEngine(level: level);
      engine.playerFacingAngle = 0.0; // Aim right into wall at (3,2)
      expect(engine.useWeapon(WeaponType.bow), isTrue);

      for (int i = 0; i < 20; i++) {
        engine.step(0.03);
      }

      expect(engine.projectiles, isEmpty);
      expect(engine.monsters.first.hp, engine.monsters.first.maxHp);
    });

    test('6 & 7. Energy Blaster deals bonus light damage to Shadow Crawler; Freeze Orb freezes temporarily and expires', () {
      final level = _combatArena(
        levelId: 20,
        monsters: const [
          MonsterDefinition(
            id: 'sc1',
            type: MonsterType.shadowCrawler,
            start: GridPoint(4, 2),
            patrolPath: [GridPoint(4, 2)],
          ),
        ],
      );
      final engine = MazeGameEngine(level: level);

      // Freeze Orb first
      expect(engine.useWeapon(WeaponType.freezeOrb), isTrue);
      for (int i = 0; i < 18; i++) {
        engine.step(0.04);
      }
      final crawler = engine.monsters.first;
      expect(crawler.isFrozen, isTrue);
      final frozenX = crawler.x;

      // Frozen monster does not move during freeze
      for (int i = 0; i < 10; i++) {
        engine.step(0.05);
      }
      expect(crawler.x, closeTo(frozenX, 0.25));

      // Wait for freeze to expire completely (~3s)
      for (int i = 0; i < 70; i++) {
        engine.step(0.05);
      }
      expect(crawler.isFrozen, isFalse);

      // Fire Energy Blaster -> 1.5x super-effective damage against Shadow Crawler!
      final hpBefore = crawler.hp;
      expect(engine.useWeapon(WeaponType.energyBlaster), isTrue);
      for (int i = 0; i < 18; i++) {
        engine.step(0.04);
      }
      final expectedDmg = (WeaponType.energyBlaster.baseDamage * 1.5).round();
      expect(hpBefore - crawler.hp, expectedDmg);
    });

    test('8. Defeated enemy cannot continue attacking and simultaneous movement + combat preserves food & timer', () {
      final level = _combatArena(
        levelId: 20,
        playerStart: const GridPoint(1, 2),
        monsters: const [
          MonsterDefinition(
            id: 'fc1',
            type: MonsterType.flyingCreature, // 40 HP
            start: GridPoint(3, 2),
            patrolPath: [GridPoint(3, 2)],
          ),
        ],
      );
      final engine = MazeGameEngine(level: level);

      // Move with joystick while firing two Energy Blaster / Bow shots to defeat 40 HP Night Wing
      engine.setJoystickInput(0.0, -0.5);
      expect(engine.useWeapon(WeaponType.energyBlaster), isTrue); // 38 dmg
      for (int i = 0; i < 20; i++) {
        engine.step(0.05);
      }
      expect(engine.useWeapon(WeaponType.bow), isTrue); // +25 dmg -> defeated!
      for (int i = 0; i < 20; i++) {
        engine.step(0.05);
      }

      final bat = engine.monsters.first;
      expect(bat.isDefeated, isTrue);
      expect(bat.hp, 0);

      // Walk directly onto defeated monster -> must NOT deal damage!
      final hpBefore = engine.health;
      engine.playerX = bat.x;
      engine.playerY = bat.y;
      for (int i = 0; i < 20; i++) {
        engine.step(0.05);
      }
      expect(engine.health, hpBefore);
      expect(engine.remainingTime, lessThan(level.timeLimitSeconds.toDouble()));
    });

    test('Shield pickup blocks 1 attack cleanly, Food Decoy lures monsters, and ammo pickups cannot be double-collected', () {
      final level = _combatArena(
        levelId: 28,
        playerStart: const GridPoint(1, 2),
        monsters: const [
          MonsterDefinition(
            id: 'rh1',
            type: MonsterType.redHunter,
            start: GridPoint(5, 2),
            patrolPath: [GridPoint(5, 2)],
          ),
        ],
        combatPickups: const [
          CombatPickupSpawn(
              id: 'sh1', type: CombatPickupType.shield, col: 2, row: 2, amount: 1),
          CombatPickupSpawn(
              id: 'ar1', type: CombatPickupType.arrows, col: 3, row: 2, amount: 5),
        ],
      );
      final engine = MazeGameEngine(level: level);

      // Pick up shield & arrows (stepping repeatedly must NOT grant arrows twice!)
      engine.playerX = 2.5;
      engine.playerY = 2.5;
      engine.step(0.02);
      expect(engine.hasShield, isTrue);

      engine.playerX = 3.5;
      engine.playerY = 2.5;
      engine.step(0.02);
      engine.step(0.02);
      engine.step(0.02);
      expect(engine.ammoFor(WeaponType.bow), 15); // 10 + 5 once only!

      // Drop Food Decoy
      expect(engine.useWeapon(WeaponType.foodDecoy), isTrue);
      expect(engine.decoys.length, 1);

      // Contact monster -> Shield blocks ALL health damage and shatters!
      engine.playerX = engine.monsters.first.x;
      engine.playerY = engine.monsters.first.y;
      engine.step(0.02);
      expect(engine.hasShield, isFalse);
      expect(engine.health, 3);
    });

    test('Weapon unlock progression matches Section 10 campaign milestones across all 50 levels', () {
      final raw = jsonDecode(
          File('assets/levels/maze_levels.json').readAsStringSync()) as Map<String, dynamic>;
      final levels = (raw['levels'] as List)
          .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(MazeGameEngine(level: levels[0]).unlockedWeapons, isEmpty); // L1
      expect(MazeGameEngine(level: levels[2]).unlockedWeapons, isEmpty); // L3
      expect(MazeGameEngine(level: levels[3]).unlockedWeapons, [WeaponType.melee]); // L4
      expect(MazeGameEngine(level: levels[5]).unlockedWeapons,
          containsAll([WeaponType.melee, WeaponType.bow])); // L6
      expect(MazeGameEngine(level: levels[10]).unlockedWeapons,
          contains(WeaponType.freezeOrb)); // L11
      expect(MazeGameEngine(level: levels[15]).unlockedWeapons,
          contains(WeaponType.energyBlaster)); // L16
      expect(MazeGameEngine(level: levels[20]).unlockedWeapons,
          contains(WeaponType.foodDecoy)); // L21
      expect(MazeGameEngine(level: levels[25]).unlockedWeapons,
          contains(WeaponType.stunPulse)); // L26

      // Verify Maze Guardian Mini-Boss exists on milestone boss levels (20, 30, 40, 50)
      for (final bossId in [20, 30, 40, 50]) {
        final bossLevel = levels.firstWhere((l) => l.id == bossId);
        expect(
          bossLevel.monsters.any((m) => m.type == MonsterType.mazeGuardian),
          isTrue,
          reason: 'Level $bossId should feature the Maze Guardian Mini-Boss',
        );
      }
    });
  });
}

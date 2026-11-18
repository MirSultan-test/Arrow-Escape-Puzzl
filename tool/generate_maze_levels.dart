import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:parcel_escape/src/engine/maze/maze_pathfinder.dart';
import 'package:parcel_escape/src/engine/maze/maze_validator.dart';
import 'package:parcel_escape/src/models/maze/combat_models.dart';
import 'package:parcel_escape/src/models/maze/food_item.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/monster.dart';

/// Builds all 50 validated Food Maze Delivery Adventure levels (V3.1)
/// with bottom-edge delivery exits leading directly into the compact bottom dock
/// and balanced collectible Health Hearts, saving to `assets/levels/maze_levels.json`.
void main() {
  final levels = <MazeLevel>[
    ..._buildHandcraftedDistrict1(),
    ..._buildDistrict2To5(),
  ];

  if (levels.length != 50) {
    stderr.writeln('Expected 50 levels, got ${levels.length}');
    exit(1);
  }

  int totalFoods = 0;
  int totalMonsters = 0;
  int totalHearts = 0;
  for (final lvl in levels) {
    final res = MazeValidator.validate(lvl);
    if (!res.isValid) {
      stderr.writeln('VALIDATION FAILED FOR LEVEL ${lvl.id}:');
      for (final e in res.errors) {
        stderr.writeln('  - $e');
      }
      exit(1);
    }
    if (lvl.exitCell.row != lvl.rows - 1) {
      stderr.writeln('LEVEL ${lvl.id} exitCell is not on bottom row!');
      exit(1);
    }
    totalFoods += lvl.foods.length;
    totalMonsters += lvl.monsters.length;
    totalHearts += lvl.healthPickups.length;
  }

  final outFile = File('assets/levels/maze_levels.json');
  outFile.parent.createSync(recursive: true);
  final encoder = const JsonEncoder.withIndent('  ');
  outFile.writeAsStringSync(
    encoder.convert({
      'version': 31,
      'campaign': 'food_maze_adventure',
      'levels': levels.map((l) => l.toJson()).toList(),
    }),
  );

  print('Successfully generated & validated 50 V3.1 Food Maze levels!');
  print('  Total food items:    $totalFoods');
  print('  Total monsters:      $totalMonsters');
  print('  Total health hearts: $totalHearts');
  print('  Output:              ${outFile.path}');
}

List<int> _computeThresholds(List<FoodSpawn> foods, int timeLimitSec) {
  final maxFood = foods.fold<int>(0, (s, f) => s + f.effectiveBasePoints);
  final star1 = (maxFood * 0.65).round();
  final star2 = (maxFood * 0.95 + 50).round();
  final star3 = (maxFood + 75 + (timeLimitSec * 1.4).round()).round();
  return [star1, star2, star3];
}

// ============================================================================
// DISTRICT 1 — SUNNY ORCHARD (Levels 1–10, 100% Handcrafted, Bottom Dock Exit)
// ============================================================================

List<MazeLevel> _buildHandcraftedDistrict1() {
  // Level 1: Learn movement, collect one apple, reach the bottom collector dock (No enemies)
  final l1Foods = [
    const FoodSpawn(id: 'l1_apple', type: FoodType.apple, col: 4, row: 1),
  ];
  final level1 = MazeLevel(
    id: 1,
    district: 1,
    title: 'First Orchard Run',
    subtitle: 'Pick up the crisp apple & bring it to the Collector!',
    tutorialTip:
        'Use the joystick to grab the Apple, then walk down to the Delivery Dock!',
    cols: 9,
    rows: 7,
    grid: const [
      '#########',
      '#.......#',
      '#..###..#',
      '#.......#',
      '#..###..#',
      '#.......#',
      '####E####',
    ],
    playerStart: const GridPoint(1, 5),
    exitCell: const GridPoint(4, 6),
    cargoCapacity: 2,
    timeLimitSeconds: 45,
    minQuotaPercent: 100,
    starThresholds: _computeThresholds(l1Foods, 45),
    difficulty: 1,
    foods: l1Foods,
    monsters: const [],
  );

  // Level 2: Deliver two different fruits through simple corridors (No enemies)
  final l2Foods = [
    const FoodSpawn(id: 'l2_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l2_banana', type: FoodType.banana, col: 7, row: 1),
  ];
  final level2 = MazeLevel(
    id: 2,
    district: 1,
    title: 'Twin Fruit Harvest',
    subtitle: 'Your bag holds 2 fruits — grab both before delivering!',
    cols: 9,
    rows: 7,
    grid: const [
      '#########',
      '#...#...#',
      '#.#.#.#.#',
      '#.#...#.#',
      '#.##.##.#',
      '#.......#',
      '####E####',
    ],
    playerStart: const GridPoint(1, 5),
    exitCell: const GridPoint(4, 6),
    cargoCapacity: 2,
    timeLimitSeconds: 50,
    minQuotaPercent: 100,
    starThresholds: _computeThresholds(l2Foods, 50),
    difficulty: 1,
    foods: l2Foods,
    monsters: const [],
  );

  // Level 3: Introduce the first stationary guardian and safe detour
  final l3Foods = [
    const FoodSpawn(id: 'l3_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l3_mango', type: FoodType.mango, col: 9, row: 1),
  ];
  final level3 = MazeLevel(
    id: 3,
    district: 1,
    title: 'The Sleepy Guardian',
    subtitle: 'Sneak around the Guardian or take the safe detour!',
    cols: 11,
    rows: 7,
    grid: const [
      '###########',
      '#....#....#',
      '#.##.#.##.#',
      '#.........#',
      '#.##.###..#',
      '#.........#',
      '#####E#####',
    ],
    playerStart: const GridPoint(1, 5),
    exitCell: const GridPoint(5, 6),
    cargoCapacity: 2,
    timeLimitSeconds: 55,
    minQuotaPercent: 50,
    starThresholds: _computeThresholds(l3Foods, 55),
    difficulty: 1,
    foods: l3Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l3_g1',
        type: MonsterType.guardian,
        start: GridPoint(5, 3),
        patrolPath: [GridPoint(5, 3), GridPoint(6, 3)],
        biteDamage: 25,
      ),
    ],
  );

  // Level 4: Deliver three food items while avoiding a patrol monster
  final l4Foods = [
    const FoodSpawn(id: 'l4_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l4_banana', type: FoodType.banana, col: 9, row: 1),
    const FoodSpawn(id: 'l4_strawberry', type: FoodType.strawberry, col: 1, row: 7),
  ];
  final level4 = MazeLevel(
    id: 4,
    district: 1,
    title: 'Orchard Patrol',
    subtitle: 'Watch the Patroller\'s loop and deliver in 2 trips.',
    cols: 11,
    rows: 9,
    grid: const [
      '###########',
      '#....#....#',
      '#.##.#.##.#',
      '#.........#',
      '###.###.###',
      '#.........#',
      '#.##.#.##.#',
      '#....#....#',
      '#######E###',
    ],
    playerStart: const GridPoint(8, 7),
    exitCell: const GridPoint(7, 8),
    cargoCapacity: 2,
    timeLimitSeconds: 65,
    minQuotaPercent: 60,
    starThresholds: _computeThresholds(l4Foods, 65),
    difficulty: 2,
    foods: l4Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l4_p1',
        type: MonsterType.patrol,
        start: GridPoint(2, 3),
        patrolPath: [GridPoint(2, 3), GridPoint(8, 3)],
        speed: 1.85,
        biteDamage: 25,
      ),
    ],
  );

  // Level 5: Food damage, condition indicators & first collectible Health Heart!
  final l5Foods = [
    const FoodSpawn(id: 'l5_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l5_mango', type: FoodType.mango, col: 9, row: 1),
    const FoodSpawn(id: 'l5_orange', type: FoodType.orange, col: 5, row: 5),
  ];
  final level5 = MazeLevel(
    id: 5,
    district: 1,
    title: 'Protect the Basket',
    subtitle: 'Guard your fruit condition — grab a heart if injured!',
    cols: 11,
    rows: 9,
    grid: const [
      '###########',
      '#.........#',
      '#.##.#.##.#',
      '#.#..#..#.#',
      '#....#....#',
      '#.##...##.#',
      '#.#..#..#.#',
      '#.........#',
      '#####E#####',
    ],
    playerStart: const GridPoint(1, 7),
    exitCell: const GridPoint(5, 8),
    cargoCapacity: 2,
    timeLimitSeconds: 68,
    minQuotaPercent: 60,
    starThresholds: _computeThresholds(l5Foods, 68),
    difficulty: 2,
    foods: l5Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l5_g1',
        type: MonsterType.guardian,
        start: GridPoint(4, 5),
        patrolPath: [GridPoint(4, 5), GridPoint(6, 5)],
        biteDamage: 25,
      ),
      MonsterDefinition(
        id: 'l5_p1',
        type: MonsterType.patrol,
        start: GridPoint(3, 7),
        patrolPath: [GridPoint(3, 7), GridPoint(8, 7)],
        speed: 1.85,
        biteDamage: 25,
      ),
    ],
    healthPickups: const [
      HealthPickupSpawn(id: 'l5_hp1', col: 5, row: 1),
    ],
  );

  // Level 6: Four-corner orchard with fast guarded center vs safe outer lanes
  final l6Foods = [
    const FoodSpawn(id: 'l6_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l6_banana', type: FoodType.banana, col: 9, row: 1),
    const FoodSpawn(id: 'l6_mango', type: FoodType.mango, col: 9, row: 5),
    const FoodSpawn(id: 'l6_strawberry', type: FoodType.strawberry, col: 1, row: 9),
  ];
  final level6 = MazeLevel(
    id: 6,
    district: 1,
    title: 'Four-Corner Orchard',
    subtitle: 'Choose between the fast guarded center or the safer outer lanes!',
    cols: 11,
    rows: 11,
    grid: const [
      '###########',
      '#...#.....#',
      '#.#.#.###.#',
      '#.#.......#',
      '#.###.###.#',
      '#...#.....#',
      '###.#.###.#',
      '#.........#',
      '#.###.###.#',
      '#.........#',
      '#####E#####',
    ],
    playerStart: const GridPoint(7, 9),
    exitCell: const GridPoint(5, 10),
    cargoCapacity: 2,
    timeLimitSeconds: 85,
    minQuotaPercent: 60,
    starThresholds: _computeThresholds(l6Foods, 85),
    difficulty: 2,
    foods: l6Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l6_p1',
        type: MonsterType.patrol,
        start: GridPoint(3, 3),
        patrolPath: [GridPoint(3, 3), GridPoint(9, 3)],
        speed: 1.95,
        biteDamage: 25,
      ),
      MonsterDefinition(
        id: 'l6_p2',
        type: MonsterType.patrol,
        start: GridPoint(2, 7),
        patrolPath: [GridPoint(1, 7), GridPoint(9, 7)],
        speed: 1.95,
        biteDamage: 25,
      ),
    ],
    healthPickups: const [
      HealthPickupSpawn(id: 'l6_hp1', col: 5, row: 1),
    ],
    combatPickups: const [
      CombatPickupSpawn(
          id: 'l6_arr1', type: CombatPickupType.arrows, col: 5, row: 7, amount: 5),
    ],
  );

  // Level 7: Introduce Red Hunter + Giant Forest Brute + Bow Arrow Quiver + Heart!
  final l7Foods = [
    const FoodSpawn(id: 'l7_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l7_mango', type: FoodType.mango, col: 9, row: 1),
    const FoodSpawn(id: 'l7_banana', type: FoodType.banana, col: 1, row: 7),
  ];
  final level7 = MazeLevel(
    id: 7,
    district: 1,
    title: 'Hungry Red Hunter',
    subtitle: 'Stun the Red Hunter with your Bow or slip around the hedges!',
    cols: 11,
    rows: 9,
    grid: const [
      '###########',
      '#.........#',
      '#.###.###.#',
      '#.#.....#.#',
      '#...#.#...#',
      '#.#.....#.#',
      '#.###.###.#',
      '#.........#',
      '#####E#####',
    ],
    playerStart: const GridPoint(8, 7),
    exitCell: const GridPoint(5, 8),
    cargoCapacity: 2,
    timeLimitSeconds: 75,
    minQuotaPercent: 60,
    starThresholds: _computeThresholds(l7Foods, 75),
    difficulty: 3,
    foods: l7Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l7_h1',
        type: MonsterType.redHunter,
        start: GridPoint(5, 3),
        patrolPath: [
          GridPoint(3, 3),
          GridPoint(7, 3),
          GridPoint(7, 5),
          GridPoint(3, 5),
        ],
        speed: 2.1,
        detectionRange: 3.5,
        biteDamage: 30,
      ),
      MonsterDefinition(
        id: 'l7_g1',
        type: MonsterType.forestBrute,
        start: GridPoint(1, 4),
        patrolPath: [GridPoint(1, 3), GridPoint(1, 5)],
        biteDamage: 35,
      ),
    ],
    healthPickups: const [
      HealthPickupSpawn(id: 'l7_hp1', col: 5, row: 1),
    ],
    combatPickups: const [
      CombatPickupSpawn(
          id: 'l7_arr1', type: CombatPickupType.arrows, col: 9, row: 4, amount: 5),
    ],
  );

  // Level 8: Two-Trip Strategy (4 foods, 2 slots, 3 monsters + 1 heart)
  final l8Foods = [
    const FoodSpawn(id: 'l8_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l8_banana', type: FoodType.banana, col: 9, row: 1),
    const FoodSpawn(id: 'l8_strawberry', type: FoodType.strawberry, col: 1, row: 9),
    const FoodSpawn(id: 'l8_orange', type: FoodType.orange, col: 4, row: 5),
  ];
  final level8 = MazeLevel(
    id: 8,
    district: 1,
    title: 'Two-Trip Strategy',
    subtitle: 'Plan which 2 fruits to grab first to avoid backtracking!',
    cols: 11,
    rows: 11,
    grid: const [
      '###########',
      '#....#....#',
      '#.##.#.##.#',
      '#.........#',
      '#.##.#.##.#',
      '#....#....#',
      '#.##.#.##.#',
      '#.........#',
      '#.##.#.##.#',
      '#....#....#',
      '#######E###',
    ],
    playerStart: const GridPoint(9, 9),
    exitCell: const GridPoint(7, 10),
    cargoCapacity: 2,
    timeLimitSeconds: 90,
    minQuotaPercent: 60,
    starThresholds: _computeThresholds(l8Foods, 90),
    difficulty: 3,
    foods: l8Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l8_p1',
        type: MonsterType.patrol,
        start: GridPoint(1, 3),
        patrolPath: [GridPoint(1, 3), GridPoint(9, 3)],
        speed: 1.95,
      ),
      MonsterDefinition(
        id: 'l8_p2',
        type: MonsterType.patrol,
        start: GridPoint(9, 7),
        patrolPath: [GridPoint(9, 7), GridPoint(1, 7)],
        speed: 1.95,
      ),
      MonsterDefinition(
        id: 'l8_g1',
        type: MonsterType.guardian,
        start: GridPoint(5, 3),
        patrolPath: [GridPoint(5, 3), GridPoint(6, 3)],
      ),
    ],
    healthPickups: const [
      HealthPickupSpawn(id: 'l8_hp1', col: 7, row: 5),
    ],
  );

  // Level 9: Crossroads Timing (3 patrols + 1 heart)
  final l9Foods = [
    const FoodSpawn(id: 'l9_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l9_mango', type: FoodType.mango, col: 11, row: 1),
    const FoodSpawn(id: 'l9_strawberry', type: FoodType.strawberry, col: 1, row: 9),
    const FoodSpawn(id: 'l9_watermelon', type: FoodType.watermelon, col: 6, row: 5),
  ];
  final level9 = MazeLevel(
    id: 9,
    district: 1,
    title: 'Crossroads Timing',
    subtitle: 'Read three overlapping patrol loops through the orchard!',
    cols: 13,
    rows: 11,
    grid: const [
      '#############',
      '#.....#.....#',
      '#.###.#.###.#',
      '#...........#',
      '###.#.#.#.###',
      '#...#...#...#',
      '###.#.#.#.###',
      '#...........#',
      '#.###.#.###.#',
      '#.....#.....#',
      '#########E###',
    ],
    playerStart: const GridPoint(11, 9),
    exitCell: const GridPoint(9, 10),
    cargoCapacity: 2,
    timeLimitSeconds: 95,
    minQuotaPercent: 60,
    starThresholds: _computeThresholds(l9Foods, 95),
    difficulty: 3,
    foods: l9Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l9_p1',
        type: MonsterType.patrol,
        start: GridPoint(1, 3),
        patrolPath: [GridPoint(1, 3), GridPoint(11, 3)],
        speed: 2.05,
      ),
      MonsterDefinition(
        id: 'l9_p2',
        type: MonsterType.patrol,
        start: GridPoint(11, 7),
        patrolPath: [GridPoint(11, 7), GridPoint(1, 7)],
        speed: 2.05,
      ),
      MonsterDefinition(
        id: 'l9_p3',
        type: MonsterType.patrol,
        start: GridPoint(5, 3),
        patrolPath: [GridPoint(5, 3), GridPoint(5, 7)],
        speed: 1.9,
      ),
    ],
    healthPickups: const [
      HealthPickupSpawn(id: 'l9_hp1', col: 1, row: 5),
    ],
  );

  // Level 10: District 1 Finale — Sunny Orchard Boss Challenge!
  final l10Foods = [
    const FoodSpawn(id: 'l10_apple', type: FoodType.apple, col: 1, row: 1),
    const FoodSpawn(id: 'l10_banana', type: FoodType.banana, col: 11, row: 1),
    const FoodSpawn(id: 'l10_mango', type: FoodType.mango, col: 11, row: 5),
    const FoodSpawn(id: 'l10_strawberry', type: FoodType.strawberry, col: 1, row: 9),
    const FoodSpawn(id: 'l10_watermelon', type: FoodType.watermelon, col: 6, row: 5),
  ];
  final level10 = MazeLevel(
    id: 10,
    district: 1,
    title: 'Grand Orchard Harvest',
    subtitle: 'District 1 Finale: 5 prize fruits, patrols & a prowling Hunter!',
    cols: 13,
    rows: 11,
    grid: const [
      '#############',
      '#...#...#...#',
      '#.#.#.#.#.#.#',
      '#...........#',
      '#.###.#.###.#',
      '#.#.......#.#',
      '#.###.#.###.#',
      '#...........#',
      '#.#.#.#.#.#.#',
      '#...#...#...#',
      '######E######',
    ],
    playerStart: const GridPoint(9, 9),
    exitCell: const GridPoint(6, 10),
    cargoCapacity: 2,
    timeLimitSeconds: 115,
    minQuotaPercent: 60,
    starThresholds: _computeThresholds(l10Foods, 115),
    difficulty: 4,
    foods: l10Foods,
    monsters: const [
      MonsterDefinition(
        id: 'l10_p1',
        type: MonsterType.patrol,
        start: GridPoint(1, 3),
        patrolPath: [GridPoint(1, 3), GridPoint(11, 3)],
        speed: 2.05,
      ),
      MonsterDefinition(
        id: 'l10_p2',
        type: MonsterType.patrol,
        start: GridPoint(11, 7),
        patrolPath: [GridPoint(11, 7), GridPoint(1, 7)],
        speed: 2.05,
      ),
      MonsterDefinition(
        id: 'l10_h1',
        type: MonsterType.hunter,
        start: GridPoint(5, 5),
        patrolPath: [GridPoint(3, 5), GridPoint(9, 5)],
        speed: 2.15,
        detectionRange: 3.4,
      ),
      MonsterDefinition(
        id: 'l10_g1',
        type: MonsterType.guardian,
        start: GridPoint(7, 1),
        patrolPath: [GridPoint(6, 1), GridPoint(7, 1)],
      ),
    ],
    healthPickups: const [
      HealthPickupSpawn(id: 'l10_hp1', col: 1, row: 5),
    ],
    combatPickups: const [
      CombatPickupSpawn(
          id: 'l10_arr1', type: CombatPickupType.arrows, col: 6, row: 3, amount: 5),
    ],
  );

  return [
    level1,
    level2,
    level3,
    level4,
    level5,
    level6,
    level7,
    level8,
    level9,
    level10,
  ];
}

// ============================================================================
// DISTRICTS 2–5 (Levels 11–50, Bottom Dock Exit + Collectible Health Hearts)
// ============================================================================

List<MazeLevel> _buildDistrict2To5() {
  final levels = <MazeLevel>[];

  const districtTitles = <int, List<String>>{
    2: [
      'Market Dawn',
      'Cobble Crossing',
      'Carrot Alley',
      'Tomato Stall',
      'Bazaar Loop',
      'Spice & Citrus',
      'Vendor Shortcut',
      'Market Rush',
      'Merchant Square',
      'Grand Market Day',
    ],
    3: [
      'Pinewood Gate',
      'Mossy Fork',
      'Berry Hollow',
      'Timber Watch',
      'Hunter\'s Glade',
      'Fern Switchback',
      'Canopy Detour',
      'Woodland Express',
      'Deep Grove Run',
      'Forest Trail Boss',
    ],
    4: [
      'Valley Entrance',
      'Echo Canyon',
      'Imp Ambush',
      'Twilight Ridge',
      'Obsidian Maze',
      'Shadow Bypass',
      'Double Chase',
      'Crag Gauntlet',
      'Monster Lair',
      'Valley Overlord',
    ],
    5: [
      'Downtown Dock',
      'Midtown Avenue',
      'Plaza Sprint',
      'Expressway Grid',
      'Skyline Market',
      'Metro Crossroads',
      'Rush Hour Run',
      'Harbor Warehouse',
      'Clocktower Square',
      'Grand City Finale',
    ],
  };

  const districtFoods = <int, List<FoodType>>{
    2: [
      FoodType.carrot,
      FoodType.tomato,
      FoodType.apple,
      FoodType.orange,
      FoodType.banana,
    ],
    3: [
      FoodType.strawberry,
      FoodType.mango,
      FoodType.watermelon,
      FoodType.apple,
      FoodType.carrot,
    ],
    4: [
      FoodType.watermelon,
      FoodType.mango,
      FoodType.strawberry,
      FoodType.tomato,
      FoodType.orange,
      FoodType.banana,
    ],
    5: [
      FoodType.apple,
      FoodType.banana,
      FoodType.mango,
      FoodType.strawberry,
      FoodType.orange,
      FoodType.watermelon,
      FoodType.carrot,
      FoodType.tomato,
    ],
  };

  for (int id = 11; id <= 50; id++) {
    final district = ((id - 1) ~/ 10) + 1; // 2..5
    final indexInDistrict = (id - 1) % 10; // 0..9
    final isBoss = indexInDistrict == 9;
    final rng = math.Random(202600 + id * 97);

    final cols = district == 2
        ? (indexInDistrict < 5 ? 11 : 13)
        : district == 3
            ? 13
            : district == 4
                ? (indexInDistrict < 5 ? 13 : 15)
                : 15;
    final rows = district == 2
        ? 11
        : district == 3
            ? (indexInDistrict < 5 ? 11 : 13)
            : 13;

    final gridChars = _generateBraidedMaze(cols, rows, rng, braidRatio: 0.42);

    // Relocated Bottom-Wall Delivery Exit leading directly into the compact Bottom Dock!
    final exitCol = (cols ~/ 2).isOdd ? (cols ~/ 2) : (cols ~/ 2) + 1;
    gridChars[rows - 1][exitCol] = 'E';
    gridChars[rows - 2][exitCol] = '.';
    final exitCell = GridPoint(exitCol, rows - 1);
    final playerStart = GridPoint(exitCol, rows - 2);

    final baseGrid = gridChars.map((r) => r.join()).toList();
    final tempLevel = MazeLevel(
      id: id,
      district: district,
      title: '',
      subtitle: '',
      cols: cols,
      rows: rows,
      grid: baseGrid,
      playerStart: playerStart,
      exitCell: exitCell,
      timeLimitSeconds: 999,
      starThresholds: const [100, 200, 300],
      foods: const [],
      monsters: const [],
    );

    final walkable = <GridPoint>[];
    final distMap = <GridPoint, int>{};
    for (int r = 1; r < rows - 1; r++) {
      for (int c = 1; c < cols - 1; c++) {
        if (gridChars[r][c] == '.') {
          final p = GridPoint(c, r);
          final d = MazePathfinder.shortestSteps(tempLevel, playerStart, p);
          if (d >= 2) {
            walkable.add(p);
            distMap[p] = d;
          }
        }
      }
    }

    final foodCount =
        (3 + (district - 1) + (isBoss ? 1 : (indexInDistrict >= 5 ? 1 : 0)))
            .clamp(4, 6);
    final cargoCapacity = (district == 5 && indexInDistrict >= 4) ? 3 : 2;
    final palette = districtFoods[district]!;

    final chosenFoodPoints = _pickSpreadPoints(
      walkable,
      count: foodCount,
      minSpacing: 3,
      rng: rng,
      preferQuadrants: true,
      cols: cols,
      rows: rows,
    );

    final foods = <FoodSpawn>[];
    for (int i = 0; i < chosenFoodPoints.length; i++) {
      final pt = chosenFoodPoints[i];
      final type = palette[(id + i) % palette.length];
      foods.add(FoodSpawn(
        id: 'l${id}_f$i',
        type: type,
        col: pt.col,
        row: pt.row,
      ));
    }

    final monsterCount =
        (district + (indexInDistrict >= 4 ? 1 : 0) + (isBoss ? 1 : 0))
            .clamp(2, 5);
    final monsterTypes =
        _monsterRosterFor(district, indexInDistrict, monsterCount);
    final occupied = <GridPoint>{playerStart, exitCell, ...chosenFoodPoints};
    final monsters = <MonsterDefinition>[];

    final safeMonsterCandidates = walkable
        .where((p) => !occupied.contains(p) && (distMap[p] ?? 0) >= 4)
        .toList();
    safeMonsterCandidates.shuffle(rng);

    for (int i = 0;
        i < monsterTypes.length && safeMonsterCandidates.isNotEmpty;
        i++) {
      final mType = monsterTypes[i];
      GridPoint? startPt;
      for (final cand in safeMonsterCandidates) {
        final farEnough = monsters.every((m) => m.start.manhattanTo(cand) >= 3);
        if (farEnough) {
          startPt = cand;
          break;
        }
      }
      if (startPt == null) continue;
      occupied.add(startPt);

      final patrolPath = _buildPatrolPath(tempLevel, startPt, mType, rng);
      final speedScale = 1.0 + (district - 2) * 0.05 + (isBoss ? 0.04 : 0.0);

      monsters.add(MonsterDefinition(
        id: 'l${id}_m$i',
        type: mType,
        start: startPt,
        patrolPath: patrolPath,
        speed:
            double.parse((mType.defaultSpeed * speedScale).toStringAsFixed(2)),
        detectionRange: mType == MonsterType.hunter
            ? (3.5 + (district - 2) * 0.2)
            : mType.defaultDetectionRange,
        biteDamage: mType.defaultBiteDamage,
      ));
    }

    // Balanced Collectible Health Hearts (1 in Districts 2–3, 1–2 in Districts 4–5)
    final desiredHearts =
        (district >= 4 && (isBoss || indexInDistrict >= 5)) ? 2 : 1;
    final heartCandidates = walkable
        .where((p) =>
            !occupied.contains(p) &&
            monsters.every((m) => m.start.manhattanTo(p) >= 2))
        .toList();
    heartCandidates.shuffle(rng);
    final healthPickups = <HealthPickupSpawn>[];
    for (final cand in heartCandidates) {
      if (healthPickups.length >= desiredHearts) break;
      if (healthPickups.every(
          (h) => GridPoint(h.col, h.row).manhattanTo(cand) >= 4)) {
        healthPickups.add(HealthPickupSpawn(
          id: 'l${id}_hp${healthPickups.length + 1}',
          col: cand.col,
          row: cand.row,
        ));
        occupied.add(cand);
      }
    }

    // Balanced Combat Supplies & Shields (aligned with weapon unlock progression!)
    final combatPickups = <CombatPickupSpawn>[];
    final supplyPool = walkable.where((p) => !occupied.contains(p)).toList()
      ..shuffle(rng);
    if (supplyPool.isNotEmpty) {
      final firstPt = supplyPool.removeAt(0);
      occupied.add(firstPt);
      combatPickups.add(CombatPickupSpawn(
        id: 'l${id}_cp1',
        type: id >= 16 && id.isEven
            ? CombatPickupType.energyCharges
            : (id >= 11 && id % 3 == 0
                ? CombatPickupType.freezeOrbs
                : CombatPickupType.arrows),
        col: firstPt.col,
        row: firstPt.row,
        amount: id >= 16 && id.isEven ? 3 : (id >= 11 && id % 3 == 0 ? 2 : 5),
      ));
    }
    if (id >= 26 && supplyPool.isNotEmpty) {
      final shieldPt = supplyPool.removeAt(0);
      occupied.add(shieldPt);
      combatPickups.add(CombatPickupSpawn(
        id: 'l${id}_sh1',
        type: CombatPickupType.shield,
        col: shieldPt.col,
        row: shieldPt.row,
        amount: 1,
      ));
    }

    final preLevel = MazeLevel(
      id: id,
      district: district,
      title: districtTitles[district]![indexInDistrict],
      subtitle: isBoss
          ? 'District $district Boss Finale! Confront the Maze Guardian & deliver!'
          : 'Collect $foodCount fresh items and reach the Collector!',
      cols: cols,
      rows: rows,
      grid: baseGrid,
      playerStart: playerStart,
      exitCell: exitCell,
      cargoCapacity: cargoCapacity,
      timeLimitSeconds: 999,
      minQuotaPercent: 60,
      starThresholds: const [100, 200, 300],
      difficulty: district.clamp(1, 5),
      foods: foods,
      monsters: monsters,
      healthPickups: healthPickups,
      combatPickups: combatPickups,
    );

    final preVal = MazeValidator.validate(preLevel);
    final minTime = preVal.estimatedMinSeconds;
    final timeLimit = ((minTime * 1.95) + 18 + monsters.length * 4)
        .round()
        .clamp(60, 180);

    levels.add(MazeLevel(
      id: id,
      district: district,
      title: preLevel.title,
      subtitle: preLevel.subtitle,
      cols: cols,
      rows: rows,
      grid: baseGrid,
      playerStart: playerStart,
      exitCell: exitCell,
      cargoCapacity: cargoCapacity,
      timeLimitSeconds: timeLimit,
      minQuotaPercent: 60,
      starThresholds: _computeThresholds(foods, timeLimit),
      difficulty: district.clamp(1, 5),
      foods: foods,
      monsters: monsters,
      healthPickups: healthPickups,
      combatPickups: combatPickups,
    ));
  }

  return levels;
}

List<MonsterType> _monsterRosterFor(
    int district, int indexInDistrict, int count) {
  final isBoss = indexInDistrict == 9;
  final list = <MonsterType>[];
  for (int i = 0; i < count; i++) {
    // Place the intimidating Maze Guardian Mini-Boss on milestone boss levels (20, 30, 40, 50)!
    if (isBoss && i == 0) {
      list.add(MonsterType.mazeGuardian);
      continue;
    }
    if (district == 2) {
      final cycle = [
        MonsterType.shadowCrawler,
        MonsterType.flyingCreature,
        MonsterType.redHunter,
        MonsterType.forestBrute,
      ];
      list.add(cycle[(indexInDistrict + i) % cycle.length]);
    } else if (district == 3) {
      final cycle = [
        MonsterType.mushroomBeast,
        MonsterType.redHunter,
        MonsterType.shadowCrawler,
        MonsterType.forestBrute,
        MonsterType.flyingCreature,
      ];
      list.add(cycle[(indexInDistrict + i) % cycle.length]);
    } else if (district == 4) {
      final cycle = [
        MonsterType.flyingCreature,
        MonsterType.mushroomBeast,
        MonsterType.redHunter,
        MonsterType.shadowCrawler,
        MonsterType.forestBrute,
      ];
      list.add(cycle[(indexInDistrict + i) % cycle.length]);
    } else {
      final cycle = [
        MonsterType.redHunter,
        MonsterType.flyingCreature,
        MonsterType.mushroomBeast,
        MonsterType.shadowCrawler,
        MonsterType.forestBrute,
      ];
      list.add(cycle[(indexInDistrict + i) % cycle.length]);
    }
  }
  return list;
}

List<List<String>> _generateBraidedMaze(
  int cols,
  int rows,
  math.Random rng, {
  double braidRatio = 0.40,
}) {
  final grid = List.generate(rows, (_) => List.filled(cols, '#'));
  final visited = <GridPoint>{};
  final stack = <GridPoint>[const GridPoint(1, 1)];
  visited.add(const GridPoint(1, 1));
  grid[1][1] = '.';

  const dirs = [
    GridPoint(0, -2),
    GridPoint(2, 0),
    GridPoint(0, 2),
    GridPoint(-2, 0),
  ];

  while (stack.isNotEmpty) {
    final curr = stack.last;
    final neighbors = <GridPoint>[];
    for (final d in dirs) {
      final nc = curr.col + d.col;
      final nr = curr.row + d.row;
      if (nc > 0 && nc < cols - 1 && nr > 0 && nr < rows - 1) {
        final np = GridPoint(nc, nr);
        if (!visited.contains(np)) {
          neighbors.add(np);
        }
      }
    }
    if (neighbors.isEmpty) {
      stack.removeLast();
    } else {
      final next = neighbors[rng.nextInt(neighbors.length)];
      grid[(curr.row + next.row) ~/ 2][(curr.col + next.col) ~/ 2] = '.';
      grid[next.row][next.col] = '.';
      visited.add(next);
      stack.add(next);
    }
  }

  for (int r = 1; r < rows - 1; r++) {
    for (int c = 1; c < cols - 1; c++) {
      if (grid[r][c] != '#') continue;
      final horizontalBridge = grid[r][c - 1] == '.' &&
          grid[r][c + 1] == '.' &&
          grid[r - 1][c] == '#' &&
          grid[r + 1][c] == '#';
      final verticalBridge = grid[r - 1][c] == '.' &&
          grid[r + 1][c] == '.' &&
          grid[r][c - 1] == '#' &&
          grid[r][c + 1] == '#';
      if ((horizontalBridge || verticalBridge) &&
          rng.nextDouble() < braidRatio) {
        grid[r][c] = '.';
      }
    }
  }

  return grid;
}

List<GridPoint> _pickSpreadPoints(
  List<GridPoint> candidates, {
  required int count,
  required int minSpacing,
  required math.Random rng,
  required bool preferQuadrants,
  required int cols,
  required int rows,
}) {
  final picked = <GridPoint>[];
  final pool = List<GridPoint>.from(candidates)..shuffle(rng);

  if (preferQuadrants) {
    final midC = cols ~/ 2;
    final midR = rows ~/ 2;
    final quadrants = <List<GridPoint>>[
      pool.where((p) => p.col < midC && p.row < midR).toList(),
      pool.where((p) => p.col >= midC && p.row < midR).toList(),
      pool.where((p) => p.col < midC && p.row >= midR).toList(),
      pool.where((p) => p.col >= midC && p.row >= midR).toList(),
    ];

    for (final q in quadrants) {
      if (picked.length >= count) break;
      for (final p in q) {
        if (picked.every((other) => other.manhattanTo(p) >= minSpacing)) {
          picked.add(p);
          break;
        }
      }
    }
  }

  for (final p in pool) {
    if (picked.length >= count) break;
    if (picked.contains(p)) continue;
    if (picked.every((other) => other.manhattanTo(p) >= minSpacing)) {
      picked.add(p);
    }
  }

  for (final p in pool) {
    if (picked.length >= count) break;
    if (!picked.contains(p)) picked.add(p);
  }

  return picked;
}

List<GridPoint> _buildPatrolPath(
  MazeLevel level,
  GridPoint start,
  MonsterType type,
  math.Random rng,
) {
  final targetSteps = type == MonsterType.guardian ? 2 : 5;
  final path = <GridPoint>[start];
  var curr = start;
  const dirs = [
    GridPoint(1, 0),
    GridPoint(-1, 0),
    GridPoint(0, 1),
    GridPoint(0, -1),
  ];

  for (int step = 0; step < targetSteps; step++) {
    final nextOpts = <GridPoint>[];
    for (final d in dirs) {
      final np = GridPoint(curr.col + d.col, curr.row + d.row);
      if (level.isWalkable(np.col, np.row) &&
          np != level.playerStart &&
          np != level.exitCell &&
          !path.contains(np)) {
        nextOpts.add(np);
      }
    }
    if (nextOpts.isEmpty) break;
    curr = nextOpts[rng.nextInt(nextOpts.length)];
    path.add(curr);
  }
  return path;
}

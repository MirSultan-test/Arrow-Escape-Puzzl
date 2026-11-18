import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/engine/maze/maze_validator.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/monster.dart';

void main() {
  late List<MazeLevel> levels;

  setUpAll(() {
    final file = File('assets/levels/maze_levels.json');
    expect(file.existsSync(), isTrue,
        reason: 'assets/levels/maze_levels.json must exist');
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    levels = (decoded['levels'] as List<dynamic>)
        .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  group('50-Level Food Maze Campaign Verification (Section 22 #20)', () {
    test('Contains exactly 50 sequential levels across 5 districts', () {
      expect(levels.length, 50);
      for (int i = 0; i < 50; i++) {
        expect(levels[i].id, i + 1);
        expect(levels[i].district, (i ~/ 10) + 1);
      }
    });

    test('All 50 levels pass geometry, bottom-dock exit, health pickup, monster patrol, and time-budget validation', () {
      for (final level in levels) {
        final res = MazeValidator.validate(level);
        expect(
          res.isValid,
          isTrue,
          reason: 'Level ${level.id} failed validation: ${res.errors.join("; ")}',
        );
        expect(
          level.exitCell.row,
          level.rows - 1,
          reason: 'Level ${level.id} exit must sit on bottom wall for bottom delivery dock',
        );
      }
      // Levels 5-50 include balanced collectible health hearts
      expect(levels[4].healthPickups, isNotEmpty);
      expect(levels[6].healthPickups, isNotEmpty);
    });

    test('First 10 levels follow Section 11 progressive onboarding & enemy roster', () {
      // L1: 1 apple, 0 enemies
      expect(levels[0].foods.length, 1);
      expect(levels[0].monsters, isEmpty);
      expect(levels[0].tutorialTip, isNotNull);

      // L2: 2 fruits, 0 enemies
      expect(levels[1].foods.length, 2);
      expect(levels[1].monsters, isEmpty);

      // L3: First stationary guardian
      expect(levels[2].monsters.length, 1);
      expect(levels[2].monsters.first.type, MonsterType.guardian);

      // L4: 3 foods, 1 patrol monster
      expect(levels[3].foods.length, 3);
      expect(levels[3].monsters.any((m) => m.type == MonsterType.patrol), isTrue);

      // L5: 1-2 monsters teaching food damage
      expect(levels[4].monsters.length, inInclusiveRange(1, 2));

      // L6: 4 corner fruits inspired by reference sketch, 2 monsters
      expect(levels[5].foods.length, 4);
      expect(levels[5].monsters.length, 2);

      // L7: Introduces Food Hunter
      expect(levels[6].monsters.any((m) => m.type == MonsterType.hunter), isTrue);

      // L8: Multi-trip cargo logistics (4 foods, capacity 2, 2-3 monsters)
      expect(levels[7].foods.length, 4);
      expect(levels[7].cargoCapacity, 2);
      expect(levels[7].monsters.length, inInclusiveRange(2, 3));

      // L9: 3 patrols
      expect(levels[8].monsters.length, 3);

      // L10: District 1 Finale (5 foods, 3-4 monsters)
      expect(levels[9].foods.length, 5);
      expect(levels[9].monsters.length, inInclusiveRange(3, 4));
    });

    test('Deterministic patrol simulation across Levels 1-10 keeps all monsters inside open corridors', () {
      for (int i = 0; i < 10; i++) {
        final engine = MazeGameEngine(level: levels[i]);
        // Simulate 10 seconds of live patrol movement
        for (int tick = 0; tick < 200; tick++) {
          engine.step(0.05);
          for (final m in engine.monsters) {
            expect(
              levels[i].isWall(m.x.floor(), m.y.floor()),
              isFalse,
              reason: 'Level ${levels[i].id} monster ${m.id} entered wall at (${m.x}, ${m.y})',
            );
          }
        }
      }
    });
  });
}

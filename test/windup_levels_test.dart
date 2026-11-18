// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/puzzle_engine.dart';
import 'package:parcel_escape/src/engine/state_space_solver.dart';
import 'package:parcel_escape/src/models/level_data.dart';

void main() {
  group('Wind-Up Campaign Levels Verification (All 50 Levels)', () {
    late List<LevelData> levels;

    setUpAll(() {
      final file = File('assets/levels/windup_levels.json');
      expect(file.existsSync(), isTrue,
          reason: 'assets/levels/windup_levels.json must exist');
      final jsonStr = file.readAsStringSync();
      final list = jsonDecode(jsonStr) as List<dynamic>;
      levels = list
          .map((item) => LevelData.fromJson(item as Map<String, dynamic>))
          .toList();
    });

    test('Contains exactly 50 frozen levels with sequential IDs 1..50', () {
      expect(levels.length, 50);
      for (int i = 0; i < 50; i++) {
        expect(levels[i].id, i + 1);
        expect(levels[i].campaign == 'depot' || levels[i].campaign == 'windup', isTrue);
        expect(levels[i].district, inInclusiveRange(1, 5));
      }
    });

    test('All 50 levels satisfy board integrity constraints', () {
      for (final level in levels) {
        final error = level.validateIntegrity();
        expect(error, isNull, reason: 'Level ${level.id} integrity error: $error');
      }
    });

    test('All 50 levels are 100% solvable by StateSpaceSolver with witness solutions', () {
      const solver = StateSpaceSolver(maxStates: 50000);
      int totalExplored = 0;
      int maxExplored = 0;
      int totalParcels = 0;

      for (final level in levels) {
        final engine = PuzzleEngine(
          rows: level.rows,
          cols: level.cols,
          parcels: level.parcels,
          manifest: level.manifest,
        );

        final result = solver.solve(engine);
        expect(result.status, SolveStatus.solvable,
            reason: 'Level ${level.id} (${level.name}) must be solvable');
        expect(result.dispatchSequence.length, level.parcels.length,
            reason: 'Level ${level.id} dispatch sequence must equal parcel count');
        expect(result.witnessPath.length, level.parcels.length * 2,
            reason: 'Level ${level.id} witness path must equal total actions (dispatch + load)');

        totalExplored += result.exploredStates;
        if (result.exploredStates > maxExplored) {
          maxExplored = result.exploredStates;
        }
        totalParcels += level.parcels.length;

        // Verify witness path clears board step-by-step
        final replay = engine.clone();
        for (final moveId in result.witnessPath) {
          expect(replay.canExit(moveId), isTrue,
              reason: 'Move $moveId must be legal during witness replay on level ${level.id}');
          replay.executeExit(moveId);
        }
        expect(replay.isCompleted, isTrue);
      }

      print('----------------------------------------------------');
      print('50 WIND-UP LEVELS VERIFICATION SUMMARY:');
      print('Total levels verified: 50');
      print('Total parcels: $totalParcels (avg: ${(totalParcels / 50).toStringAsFixed(1)})');
      print('Total solver states explored: $totalExplored (avg: ${(totalExplored / 50).toStringAsFixed(1)}/level)');
      print('Peak states explored in a single level: $maxExplored');
      print('----------------------------------------------------');
    });

    test('Tutorials 1-3 have clear instructional text', () {
      for (int i = 0; i < 3; i++) {
        expect(levels[i].tutorialText, isNotNull);
        expect(levels[i].tutorialText!.isNotEmpty, isTrue);
      }
    });
  });
}

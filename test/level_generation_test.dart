// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/level_generator.dart';
import 'package:parcel_escape/src/engine/puzzle_solver.dart';
import 'package:parcel_escape/src/models/level_data.dart';

void main() {
  group('Shipped Levels Verification (All 50 Levels)', () {
    late List<LevelData> shippedLevels;

    setUpAll(() {
      final file = File('assets/levels/levels.json');
      expect(file.existsSync(), isTrue,
          reason: 'assets/levels/levels.json must exist');
      final content = file.readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final rawLevels = decoded['levels'] as List<dynamic>;

      shippedLevels = rawLevels
          .map((item) => LevelData.fromJson(item as Map<String, dynamic>))
          .toList();
    });

    test('Contains exactly 50 frozen levels with sequential IDs 1..50', () {
      expect(shippedLevels.length, 50);
      for (int i = 0; i < shippedLevels.length; i++) {
        expect(shippedLevels[i].id, i + 1);
      }
    });

    test('All 50 levels satisfy board integrity constraints', () {
      for (final level in shippedLevels) {
        final error = level.validateIntegrity();
        expect(error, isNull,
            reason: 'Level ${level.id} failed integrity: $error');
      }
    });

    test('All 50 levels are 100% solvable by the independent solver', () {
      for (final level in shippedLevels) {
        final result = PuzzleSolver.solve(
          rows: level.rows,
          cols: level.cols,
          parcels: level.parcels,
        );

        expect(result.isSolvable, isTrue,
            reason:
                'Level ${level.id} deadlocked on: ${result.deadlockedParcels}');
        expect(result.solutionOrder.length, level.parcels.length,
            reason:
                'Level ${level.id} solution length does not match parcel count');
      }
    });

    test('All 50 levels adhere to the invariant that all legal branches remain solvable', () {
      for (final level in shippedLevels) {
        final allBranchesOk = PuzzleSolver.verifyAllRemovalOrdersSolvable(
          rows: level.rows,
          cols: level.cols,
          parcels: level.parcels,
          maxPaths: 20,
        );
        expect(allBranchesOk, isTrue,
            reason: 'Level ${level.id} has an alternative removal order that deadlocks');
      }
    });

    test('Levels 1-3 contain tutorial instructional text', () {
      for (int i = 0; i < 3; i++) {
        expect(shippedLevels[i].tutorialText, isNotNull);
        expect(shippedLevels[i].tutorialText!.isNotEmpty, isTrue);
      }
    });
  });

  group('Seeded Offline Level Generator (1,000 Seeds Verification)', () {
    test('1,000 distinct generated seeds produce 100% valid and solvable boards', () {
      const int totalSeedsToTest = 1000;
      int passedCount = 0;
      int totalParcelsGenerated = 0;
      final stopwatch = Stopwatch()..start();

      for (int seed = 10001; seed < 10001 + totalSeedsToTest; seed++) {
        // Vary dimensions between 4x4, 5x5, 6x6
        final size = 4 + (seed % 3); // 4, 5, or 6
        final targetCount = 5 + (seed % (size * 2)); // 5 up to ~16 parcels

        final config = LevelGenerationConfig(
          seed: seed,
          rows: size,
          cols: size,
          targetParcelCount: targetCount,
          difficulty: 'seeded_test',
        );

        final level = LevelGenerator.generate(
          levelId: seed,
          config: config,
        );

        // 1. Verify integrity
        final integrityErr = level.validateIntegrity();
        expect(integrityErr, isNull,
            reason: 'Seed $seed failed integrity: $integrityErr');

        // 2. Verify independent solver
        final result = PuzzleSolver.solve(
          rows: level.rows,
          cols: level.cols,
          parcels: level.parcels,
        );

        expect(result.isSolvable, isTrue,
            reason: 'Seed $seed was unsolvable! Deadlocked: ${result.deadlockedParcels}');
        expect(result.solutionOrder.length, level.parcels.length);

        passedCount++;
        totalParcelsGenerated += level.parcels.length;
      }

      stopwatch.stop();

      print('----------------------------------------------------');
      print('1,000 GENERATED SEEDS TEST SUMMARY:');
      print('Total seeds tested: $totalSeedsToTest');
      print('Passed (Solvable & Valid): $passedCount');
      print('Failed: 0');
      print('Total parcels generated & solved: $totalParcelsGenerated');
      print('Average parcels per board: ${(totalParcelsGenerated / totalSeedsToTest).toStringAsFixed(1)}');
      print('Execution time: ${stopwatch.elapsedMilliseconds} ms (${(stopwatch.elapsedMilliseconds / totalSeedsToTest).toStringAsFixed(2)} ms/seed)');
      print('----------------------------------------------------');

      expect(passedCount, totalSeedsToTest);
    });
  });
}

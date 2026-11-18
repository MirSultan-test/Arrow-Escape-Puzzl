import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/board_matrix.dart';
import 'package:parcel_escape/src/engine/puzzle_engine.dart';
import 'package:parcel_escape/src/engine/puzzle_solver.dart';
import 'package:parcel_escape/src/engine/ray_cast.dart';
import 'package:parcel_escape/src/models/direction.dart';
import 'package:parcel_escape/src/models/grid_position.dart';
import 'package:parcel_escape/src/models/level_data.dart';
import 'package:parcel_escape/src/models/parcel.dart';
import 'package:parcel_escape/src/models/save_data.dart';

void main() {
  group('Direction & GridPosition Tests', () {
    test('Direction deltas and string conversions', () {
      expect(Direction.up.deltaRow, -1);
      expect(Direction.up.deltaCol, 0);
      expect(Direction.down.deltaRow, 1);
      expect(Direction.down.deltaCol, 0);
      expect(Direction.left.deltaRow, 0);
      expect(Direction.left.deltaCol, -1);
      expect(Direction.right.deltaRow, 0);
      expect(Direction.right.deltaCol, 1);

      expect(Direction.fromKey('UP'), Direction.up);
      expect(Direction.fromKey('down'), Direction.down);
      expect(Direction.fromKey('LEFT'), Direction.left);
      expect(Direction.fromKey('right'), Direction.right);
      expect(Direction.fromKey('unknown'), Direction.up);
    });

    test('GridPosition equality and offset', () {
      const p1 = GridPosition(2, 3);
      const p2 = GridPosition(2, 3);
      const p3 = GridPosition(3, 2);

      expect(p1, equals(p2));
      expect(p1 == p3, isFalse);
      expect(p1.offset(-1, 2), equals(const GridPosition(1, 5)));
    });
  });

  group('RayCasting Tests in All 4 Directions', () {
    test('Clear exit in all four directions from board edges', () {
      final matrix = BoardMatrix(rows: 4, cols: 4);

      const pUp = Parcel(id: 'up', row: 0, col: 1, direction: Direction.up);
      const pDown = Parcel(id: 'down', row: 3, col: 2, direction: Direction.down);
      const pLeft = Parcel(id: 'left', row: 1, col: 0, direction: Direction.left);
      const pRight = Parcel(id: 'right', row: 2, col: 3, direction: Direction.right);

      matrix.place(pUp);
      matrix.place(pDown);
      matrix.place(pLeft);
      matrix.place(pRight);

      expect(RayCaster.cast(matrix: matrix, parcel: pUp).isClear, isTrue);
      expect(RayCaster.cast(matrix: matrix, parcel: pDown).isClear, isTrue);
      expect(RayCaster.cast(matrix: matrix, parcel: pLeft).isClear, isTrue);
      expect(RayCaster.cast(matrix: matrix, parcel: pRight).isClear, isTrue);
    });

    test('Direct adjacent blocker in all four directions', () {
      final matrix = BoardMatrix(rows: 4, cols: 4);
      const center = Parcel(id: 'c', row: 2, col: 2, direction: Direction.up);
      const topBlocker = Parcel(id: 'top', row: 1, col: 2, direction: Direction.right);
      matrix.place(center);
      matrix.place(topBlocker);

      final rayUp = RayCaster.cast(matrix: matrix, parcel: center);
      expect(rayUp.isClear, isFalse);
      expect(rayUp.blockingParcel?.id, 'top');
      expect(rayUp.distanceToBlocker, 1);

      // Down blocked
      const downParcel = Parcel(id: 'd', row: 1, col: 1, direction: Direction.down);
      const bottomBlocker = Parcel(id: 'bot', row: 2, col: 1, direction: Direction.left);
      matrix.place(downParcel);
      matrix.place(bottomBlocker);
      final rayDown = RayCaster.cast(matrix: matrix, parcel: downParcel);
      expect(rayDown.isClear, isFalse);
      expect(rayDown.blockingParcel?.id, 'bot');

      // Left blocked
      const rightParcel = Parcel(id: 'r', row: 0, col: 2, direction: Direction.left);
      const leftBlocker = Parcel(id: 'l', row: 0, col: 1, direction: Direction.down);
      matrix.place(rightParcel);
      matrix.place(leftBlocker);
      final rayLeft = RayCaster.cast(matrix: matrix, parcel: rightParcel);
      expect(rayLeft.isClear, isFalse);
      expect(rayLeft.blockingParcel?.id, 'l');

      // Right blocked
      const leftParcel = Parcel(id: 'l2', row: 3, col: 0, direction: Direction.right);
      const rightBlocker = Parcel(id: 'r2', row: 3, col: 1, direction: Direction.up);
      matrix.place(leftParcel);
      matrix.place(rightBlocker);
      final rayRight = RayCaster.cast(matrix: matrix, parcel: leftParcel);
      expect(rayRight.isClear, isFalse);
      expect(rayRight.blockingParcel?.id, 'r2');
    });

    test('Blocker beyond an empty gap', () {
      final matrix = BoardMatrix(rows: 5, cols: 5);
      // Parcel at (3, 1) pointing UP. Cell (2, 1) is empty. Parcel at (1, 1) blocks it.
      const p1 = Parcel(id: 'p1', row: 3, col: 1, direction: Direction.up);
      const pBlock = Parcel(id: 'blocker', row: 1, col: 1, direction: Direction.left);
      matrix.place(p1);
      matrix.place(pBlock);

      // Cell (2,1) must be empty
      expect(matrix.getAt(2, 1), isNull);

      final ray = RayCaster.cast(matrix: matrix, parcel: p1);
      expect(ray.isClear, isFalse);
      expect(ray.blockingParcel?.id, 'blocker');
      expect(ray.distanceToBlocker, 2);
    });

    test('Empty cells are passable', () {
      final matrix = BoardMatrix(rows: 5, cols: 5);
      // Parcel at (4, 2) pointing UP. All cells (3,2), (2,2), (1,2), (0,2) are empty.
      const p = Parcel(id: 'bottom', row: 4, col: 2, direction: Direction.up);
      matrix.place(p);

      final ray = RayCaster.cast(matrix: matrix, parcel: p);
      expect(ray.isClear, isTrue);
      expect(ray.blockingParcel, isNull);
      expect(ray.distanceToEdge, 5);
    });
  });

  group('PuzzleEngine Gameplay Mechanics', () {
    test('Sequential removal: A blocked by B, B exits downward, then A exits right', () {
      // Prompt example: 4x4 board, A at (1,1) pointing RIGHT and B at (1,2) pointing DOWN
      final engine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: const [
          Parcel(id: 'A', row: 1, col: 1, direction: Direction.right),
          Parcel(id: 'B', row: 1, col: 2, direction: Direction.down),
        ],
      );

      // A is initially blocked by B
      expect(engine.canExit('A'), isFalse);
      expect(engine.canExit('B'), isTrue);

      // Tapping blocked A throws StateError on executeExit
      expect(() => engine.executeExit('A'), throwsStateError);

      // B exits downward successfully
      final exitedB = engine.executeExit('B');
      expect(exitedB.id, 'B');
      expect(engine.remainingCount, 1);
      expect(engine.matrix.getAt(1, 2), isNull);

      // Now A can exit to the right
      expect(engine.canExit('A'), isTrue);
      final exitedA = engine.executeExit('A');
      expect(exitedA.id, 'A');
      expect(engine.remainingCount, 0);
      expect(engine.isCompleted, isTrue);
    });

    test('Undo restores the most recent exit and updates board matrix and counters', () {
      final engine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: const [
          Parcel(id: 'A', row: 1, col: 1, direction: Direction.right),
          Parcel(id: 'B', row: 1, col: 2, direction: Direction.down),
        ],
      );

      engine.executeExit('B');
      expect(engine.remainingCount, 1);
      expect(engine.clearedCount, 1);

      final restored = engine.undo();
      expect(restored?.id, 'B');
      expect(engine.remainingCount, 2);
      expect(engine.clearedCount, 0);
      expect(engine.matrix.getAt(1, 2)?.id, 'B');
      // A is blocked again
      expect(engine.canExit('A'), isFalse);
    });

    test('Restart resets board back to initial state', () {
      final engine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: const [
          Parcel(id: 'A', row: 1, col: 1, direction: Direction.right),
          Parcel(id: 'B', row: 1, col: 2, direction: Direction.down),
        ],
      );

      engine.executeExit('B');
      engine.executeExit('A');
      expect(engine.isCompleted, isTrue);

      engine.restart();
      expect(engine.isCompleted, isFalse);
      expect(engine.remainingCount, 2);
      expect(engine.clearedCount, 0);
      expect(engine.matrix.getAt(1, 1)?.id, 'A');
      expect(engine.matrix.getAt(1, 2)?.id, 'B');
    });

    test('Deadlock detection: circular dependency where no parcel can exit', () {
      // 4 parcels pointing at each other in a closed loop
      // (1,1) -> right, (1,2) -> down, (2,2) -> left, (2,1) -> up
      final engine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: const [
          Parcel(id: 'p1', row: 1, col: 1, direction: Direction.right),
          Parcel(id: 'p2', row: 1, col: 2, direction: Direction.down),
          Parcel(id: 'p3', row: 2, col: 2, direction: Direction.left),
          Parcel(id: 'p4', row: 2, col: 1, direction: Direction.up),
        ],
      );

      expect(engine.findClearParcels(), isEmpty);
      expect(engine.isDeadlocked, isTrue);
      expect(engine.isCompleted, isFalse);

      final solveResult = PuzzleSolver.solve(
        rows: 4,
        cols: 4,
        parcels: engine.initialParcels,
      );
      expect(solveResult.isSolvable, isFalse);
      expect(solveResult.deadlockedParcels.length, 4);
    });

    test('Invariant test: Any legal move preserves solvability', () {
      // Board with two separate unblocked exits leading to full clearance
      const parcels = [
        Parcel(id: 'A1', row: 0, col: 0, direction: Direction.up),
        Parcel(id: 'A2', row: 1, col: 0, direction: Direction.up),
        Parcel(id: 'B1', row: 0, col: 3, direction: Direction.up),
        Parcel(id: 'B2', row: 1, col: 3, direction: Direction.up),
      ];

      final allSolvable = PuzzleSolver.verifyAllRemovalOrdersSolvable(
        rows: 4,
        cols: 4,
        parcels: parcels,
      );
      expect(allSolvable, isTrue);
    });
  });

  group('Level Integrity and Error Handling', () {
    test('LevelData validation rejects duplicate cells, duplicate IDs, and out of bounds', () {
      // Duplicate ID
      const badId = LevelData(
        id: 99,
        name: 'Bad ID',
        rows: 3,
        cols: 3,
        parcels: [
          Parcel(id: 'dup', row: 0, col: 0, direction: Direction.up),
          Parcel(id: 'dup', row: 1, col: 1, direction: Direction.down),
        ],
        difficulty: 'easy',
        exampleSolution: [],
      );
      expect(badId.validateIntegrity(), contains('Duplicate parcel ID'));

      // Duplicate cell
      const badCell = LevelData(
        id: 99,
        name: 'Bad Cell',
        rows: 3,
        cols: 3,
        parcels: [
          Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up),
          Parcel(id: 'p2', row: 1, col: 1, direction: Direction.down),
        ],
        difficulty: 'easy',
        exampleSolution: [],
      );
      expect(badCell.validateIntegrity(), contains('Multiple parcels occupy cell'));

      // Out of bounds
      const badBounds = LevelData(
        id: 99,
        name: 'Bad Bounds',
        rows: 3,
        cols: 3,
        parcels: [
          Parcel(id: 'p1', row: 5, col: 1, direction: Direction.up),
        ],
        difficulty: 'easy',
        exampleSolution: [],
      );
      expect(badBounds.validateIntegrity(), contains('out of grid bounds'));
    });
  });

  group('SaveData Persistence & Recovery Tests', () {
    test('SaveData serializes and deserializes accurately', () {
      const save = SaveData(
        completedLevels: {1, 2, 3},
        highestUnlockedLevel: 4,
        currentLevelId: 4,
        soundEnabled: false,
        hapticsEnabled: true,
        reducedMotion: true,
        selectedThemeId: 'air',
        tutorialCompleted: true,
        freeHintsRemaining: 5,
        totalParcelsCleared: 12,
        ageGateCompleted: true,
        userAgeCategory: 'neutral_adult',
      );

      final jsonString = save.toJsonString();
      final loaded = SaveData.fromJsonString(jsonString);

      expect(loaded.completedLevels, {1, 2, 3});
      expect(loaded.highestUnlockedLevel, 4);
      expect(loaded.soundEnabled, isFalse);
      expect(loaded.reducedMotion, isTrue);
      expect(loaded.selectedThemeId, 'air');
      expect(loaded.tutorialCompleted, isTrue);
      expect(loaded.freeHintsRemaining, 5);
      expect(loaded.totalParcelsCleared, 12);
      expect(loaded.ageGateCompleted, isTrue);
      expect(loaded.userAgeCategory, 'neutral_adult');
    });

    test('Corrupted save recovery produces safe default without crashing', () {
      final recoveredNull = SaveData.fromJsonString(null);
      expect(recoveredNull.highestUnlockedLevel, 1);
      expect(recoveredNull.soundEnabled, isTrue);

      final recoveredGarbage = SaveData.fromJsonString('{ not valid json %%%');
      expect(recoveredGarbage.highestUnlockedLevel, 1);
      expect(recoveredGarbage.completedLevels, isEmpty);

      final recoveredBadTypes = SaveData.fromJsonString('{"completedLevels": "bad", "highestUnlockedLevel": "not_an_int"}');
      expect(recoveredBadTypes.highestUnlockedLevel, 1);
      expect(recoveredBadTypes.completedLevels, isEmpty);
    });

    test('Resetting progress strictly preserves privacy choices and age gates', () {
      const original = SaveData(
        completedLevels: {1, 2, 3, 4, 5},
        highestUnlockedLevel: 6,
        currentLevelId: 6,
        tutorialCompleted: true,
        totalParcelsCleared: 45,
        ageGateCompleted: true,
        userAgeCategory: 'neutral_adult',
        privacyConsentGiven: true,
        lastAdTimestampMs: 1234567,
      );

      final reset = original.resetProgressOnly();

      // Gameplay progress is reset:
      expect(reset.completedLevels, isEmpty);
      expect(reset.highestUnlockedLevel, 1);
      expect(reset.currentLevelId, 1);
      expect(reset.tutorialCompleted, isFalse);
      expect(reset.totalParcelsCleared, 0);

      // Privacy and user configuration MUST remain preserved:
      expect(reset.ageGateCompleted, isTrue);
      expect(reset.userAgeCategory, 'neutral_adult');
      expect(reset.privacyConsentGiven, isTrue);
      expect(reset.lastAdTimestampMs, 1234567);
    });
  });
}

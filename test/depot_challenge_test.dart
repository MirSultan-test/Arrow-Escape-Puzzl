import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/puzzle_engine.dart';
import 'package:parcel_escape/src/engine/state_space_solver.dart';
import 'package:parcel_escape/src/models/direction.dart';
import 'package:parcel_escape/src/models/parcel.dart';

void main() {
  group('Depot Challenge Mechanics & Section 5 Fixture', () {
    // Section 5 Rack-Jam Fixture:
    // 4x4 board:
    // A: (0,0), UP, STAR
    // B: (1,1), UP, MOON
    // C: (1,2), LEFT, STAR
    // D: (2,0), DOWN, SUN
    // Rack capacity: 2
    // Manifest: [STAR, MOON, STAR, SUN]
    const pA = Parcel(
      id: 'A',
      row: 0,
      col: 0,
      direction: Direction.up,
      manifestSymbol: 'star',
    );
    const pB = Parcel(
      id: 'B',
      row: 1,
      col: 1,
      direction: Direction.up,
      manifestSymbol: 'moon',
    );
    const pC = Parcel(
      id: 'C',
      row: 1,
      col: 2,
      direction: Direction.left,
      manifestSymbol: 'star',
    );
    const pD = Parcel(
      id: 'D',
      row: 2,
      col: 0,
      direction: Direction.down,
      manifestSymbol: 'sun',
    );

    PuzzleEngine buildSection5Engine() {
      return PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC, pD],
        manifest: ['star', 'moon', 'star', 'sun'],
        rackCapacity: 2,
        truckSizes: [2, 2],
      );
    }

    test('Section 5 Fixture: Winning path solves the puzzle completely', () {
      final engine = buildSection5Engine();

      // Initially, C is blocked to the left by B at (1,1)
      expect(engine.canDispatch('C'), isFalse);
      expect(engine.canDispatch('A'), isTrue);
      expect(engine.canDispatch('B'), isTrue);
      expect(engine.canDispatch('D'), isTrue);
      expect(engine.rack, isEmpty);
      expect(engine.nextRequiredSymbol, 'star');

      // 1. Dispatch A (STAR) to rack
      engine.executeDispatch('A');
      expect(engine.rack.map((p) => p.id), ['A']);
      expect(engine.canLoad('A'), isTrue);

      // Load A into truck (matches STAR)
      engine.executeLoad('A');
      expect(engine.rack, isEmpty);
      expect(engine.manifestIndex, 1);
      expect(engine.nextRequiredSymbol, 'moon');

      // 2. Dispatch B (MOON) to rack
      expect(engine.canDispatch('B'), isTrue);
      engine.executeDispatch('B');
      expect(engine.rack.map((p) => p.id), ['B']);
      expect(engine.canLoad('B'), isTrue);

      // Load B into truck (matches MOON)
      engine.executeLoad('B');
      expect(engine.rack, isEmpty);
      expect(engine.manifestIndex, 2);
      expect(engine.nextRequiredSymbol, 'star');

      // Truck 1 was size 2, so now Truck 1 is complete! Current truck is 1
      expect(engine.currentTruckIndex, 1);

      // 3. C was blocked by B at (1,1), now (1,1) is empty! C can exit left to col 0.
      expect(engine.canDispatch('C'), isTrue);
      engine.executeDispatch('C');
      expect(engine.rack.map((p) => p.id), ['C']);
      expect(engine.canLoad('C'), isTrue);

      // Load C into truck (matches STAR)
      engine.executeLoad('C');
      expect(engine.rack, isEmpty);
      expect(engine.manifestIndex, 3);
      expect(engine.nextRequiredSymbol, 'sun');

      // 4. Dispatch D (SUN) to rack
      expect(engine.canDispatch('D'), isTrue);
      engine.executeDispatch('D');
      expect(engine.rack.map((p) => p.id), ['D']);
      expect(engine.canLoad('D'), isTrue);

      // Load D into truck (matches SUN)
      engine.executeLoad('D');
      expect(engine.rack, isEmpty);
      expect(engine.manifestIndex, 4);
      expect(engine.isCompleted, isTrue);
    });

    test('Section 5 Fixture: Rack-jam deadlock occurs when dispatching B then D', () {
      final engine = buildSection5Engine();

      // Player dispatches B (MOON) to rack slot 0
      engine.executeDispatch('B');
      expect(engine.rack.length, 1);

      // Player dispatches D (SUN) to rack slot 1
      engine.executeDispatch('D');
      expect(engine.rack.length, 2);
      expect(engine.isRackFull, isTrue);

      // Required manifest symbol is STAR
      expect(engine.nextRequiredSymbol, 'star');

      // Neither B nor D matches STAR
      expect(engine.canLoad('B'), isFalse);
      expect(engine.canLoad('D'), isFalse);

      // Board parcels A and C cannot dispatch because rack is full
      expect(engine.canDispatch('A'), isFalse);
      expect(engine.canDispatch('C'), isFalse);

      // Both rack load and board dispatch are blocked -> DEADLOCK!
      expect(engine.isDeadlocked, isTrue);
      expect(engine.findLegalMoves(), isEmpty);
    });

    test('Section 5 Fixture: StateSpaceSolver solves and detects consequential choice', () {
      final engine = buildSection5Engine();
      const solver = StateSpaceSolver();

      final result = solver.solve(engine);
      expect(result.isSolvable, isTrue);
      expect(result.dispatchSequence, ['A', 'B', 'C', 'D']);

      // In the Section 5 fixture, after dispatching B, choosing D deadlocks while choosing A solves
      final branchEngine = buildSection5Engine();
      branchEngine.executeDispatch('B');
      expect(solver.hasConsequentialBranch(branchEngine), isTrue);
    });

    test('Gear Shift Rule: Board dispatch rotates gears, but rack-to-truck load does NOT rotate gears', () {
      // Board with 1 gear parcel and 1 regular parcel
      const gear = Parcel(
        id: 'G1',
        row: 1,
        col: 1,
        direction: Direction.up,
        hasGear: true,
        manifestSymbol: 'star',
      );
      const regular = Parcel(
        id: 'R1',
        row: 0,
        col: 0,
        direction: Direction.up,
        manifestSymbol: 'moon',
      );

      final engine = PuzzleEngine(
        rows: 3,
        cols: 3,
        parcels: [gear, regular],
        manifest: ['moon', 'star'],
        rackCapacity: 2,
      );

      expect(engine.getParcel('G1')?.direction, Direction.up);

      // 1. Dispatch regular parcel R1 to rack
      engine.executeDispatch('R1');

      // G1 was on board during dispatch, so it MUST rotate 90° CW (UP -> RIGHT)
      expect(engine.getParcel('G1')?.direction, Direction.right);

      // 2. Load R1 from rack to truck
      engine.executeLoad('R1');

      // Loading from rack to truck MUST NOT rotate G1!
      expect(engine.getParcel('G1')?.direction, Direction.right);

      // 3. Dispatch G1 to rack
      engine.executeDispatch('G1');
      expect(engine.rack.first.direction, Direction.right);

      // 4. Load G1 to truck
      engine.executeLoad('G1');
      expect(engine.isCompleted, isTrue);
    });

    test('Reversible Undo: Restores board, rack, gear orientations, and manifest atomically', () {
      const gear = Parcel(
        id: 'G1',
        row: 1,
        col: 1,
        direction: Direction.up,
        hasGear: true,
        manifestSymbol: 'star',
      );
      const regular = Parcel(
        id: 'R1',
        row: 0,
        col: 0,
        direction: Direction.up,
        manifestSymbol: 'moon',
      );

      final engine = PuzzleEngine(
        rows: 3,
        cols: 3,
        parcels: [gear, regular],
        manifest: ['moon', 'star'],
        rackCapacity: 2,
      );

      // Dispatch R1
      engine.executeDispatch('R1');
      expect(engine.getParcel('G1')?.direction, Direction.right);
      expect(engine.rack.length, 1);

      // Load R1
      engine.executeLoad('R1');
      expect(engine.rack, isEmpty);
      expect(engine.manifestIndex, 1);

      // Undo load R1 -> R1 should return to rack, manifest back to 0
      final undoneLoad = engine.undo();
      expect(undoneLoad?.id, 'R1');
      expect(engine.rack.length, 1);
      expect(engine.manifestIndex, 0);
      expect(engine.getParcel('G1')?.direction, Direction.right); // Gears unchanged by load undo

      // Undo dispatch R1 -> R1 should return to board, G1 gear restored to UP
      final undoneDispatch = engine.undo();
      expect(undoneDispatch?.id, 'R1');
      expect(engine.rack, isEmpty);
      expect(engine.getParcel('R1'), isNotNull);
      expect(engine.getParcel('G1')?.direction, Direction.up);
    });

    test('Truck Batches & Manifest tracking', () {
      final engine = buildSection5Engine(); // truckSizes: [2, 2]
      expect(engine.totalTrucks, 2);
      expect(engine.currentTruckIndex, 0);
      expect(engine.currentTruckCapacity, 2);
      expect(engine.currentTruckLoadedCount, 0);

      engine.executeDispatch('A');
      engine.executeLoad('A');
      expect(engine.currentTruckIndex, 0);
      expect(engine.currentTruckLoadedCount, 1);

      engine.executeDispatch('B');
      engine.executeLoad('B');
      // Truck 0 finished, now on Truck 1
      expect(engine.currentTruckIndex, 1);
      expect(engine.currentTruckLoadedCount, 0);
    });
  });
}

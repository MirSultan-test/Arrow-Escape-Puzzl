import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/puzzle_engine.dart';
import 'package:parcel_escape/src/engine/state_space_solver.dart';
import 'package:parcel_escape/src/models/direction.dart';
import 'package:parcel_escape/src/models/parcel.dart';

void main() {
  group('Depot Challenge Mechanics & Gear Shift Fixtures', () {
    test('Mandatory Gear Shift fixture: A first wins (A, B, C); C first deadlocks (A<->B)', () {
      // 4x4 board
      // A: (1,1), UP, gear parcel
      // B: (1,2), LEFT, ordinary parcel
      // C: (0,0), UP, ordinary parcel
      const pA = Parcel(
        id: 'A',
        row: 1,
        col: 1,
        direction: Direction.up,
        hasGear: true,
      );
      const pB = Parcel(
        id: 'B',
        row: 1,
        col: 2,
        direction: Direction.left,
        hasGear: false,
      );
      const pC = Parcel(
        id: 'C',
        row: 0,
        col: 0,
        direction: Direction.up,
        hasGear: false,
      );

      // --- Winning Branch: A, B, C ---
      final winningEngine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC],
        rackCapacity: 2,
      );

      expect(winningEngine.canDispatch('A'), isTrue);
      expect(winningEngine.canDispatch('B'), isFalse, reason: 'B blocked by A');
      expect(winningEngine.canDispatch('C'), isTrue);

      // Dispatch & Load A
      winningEngine.executeDispatch('A');
      expect(winningEngine.matrix.getById('A'), isNull);
      winningEngine.executeLoad('A');

      // B and C are ordinary parcels, so neither rotated
      expect(winningEngine.getParcel('B')!.direction, Direction.left);
      expect(winningEngine.getParcel('C')!.direction, Direction.up);

      // Now B is clear to exit LEFT because (1,1) is empty
      expect(winningEngine.canDispatch('B'), isTrue);
      winningEngine.executeDispatch('B');
      winningEngine.executeLoad('B');

      // Now C exits UP
      expect(winningEngine.canDispatch('C'), isTrue);
      winningEngine.executeDispatch('C');
      winningEngine.executeLoad('C');

      expect(winningEngine.isCompleted, isTrue);

      // --- Deadlock Branch: C first ---
      final deadEngine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC],
        rackCapacity: 2,
      );

      // Dispatch & Load C
      deadEngine.executeDispatch('C');
      deadEngine.executeLoad('C');
      expect(deadEngine.matrix.getById('C'), isNull);

      // A was surviving gear parcel, so it rotated 90 degrees clockwise: UP -> RIGHT!
      final rotatedA = deadEngine.getParcel('A')!;
      expect(rotatedA.direction, Direction.right,
          reason: 'Surviving gear parcel A must rotate 90 deg clockwise to RIGHT');

      // B is ordinary parcel, stays LEFT
      final survivorB = deadEngine.getParcel('B')!;
      expect(survivorB.direction, Direction.left);

      // Mutual deadlock check:
      // A at (1,1) pointing RIGHT is blocked by B at (1,2)
      expect(deadEngine.canDispatch('A'), isFalse);
      final evalA = deadEngine.evaluateDispatch('A');
      expect(evalA.legality, ExitLegality.blockedByRay);
      expect(evalA.rayResult?.blockingParcel?.id, 'B');

      // B at (1,2) pointing LEFT is blocked by A at (1,1)
      expect(deadEngine.canDispatch('B'), isFalse);
      final evalB = deadEngine.evaluateDispatch('B');
      expect(evalB.legality, ExitLegality.blockedByRay);
      expect(evalB.rayResult?.blockingParcel?.id, 'A');

      expect(deadEngine.isDeadlocked, isTrue);
      expect(deadEngine.findLegalMoves(), isEmpty);

      // Test solver verification
      const solver = StateSpaceSolver();
      final solverRes = solver.solve(PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC],
      ));
      expect(solverRes.isSolvable, isTrue);
      expect(solverRes.dispatchSequence, ['A', 'B', 'C']);
      expect(solver.hasConsequentialBranch(PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC],
      )), isTrue);
    });

    test('Mandatory Delivery Manifest fixture: B, C, A wins; A first deadlocks', () {
      // 4x4 board, no gear parcels
      // A: (0,0), UP, STAR
      // B: (1,1), UP, STAR
      // C: (1,2), LEFT, MOON
      // Manifest: STAR, MOON, STAR
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
        manifestSymbol: 'star',
      );
      const pC = Parcel(
        id: 'C',
        row: 1,
        col: 2,
        direction: Direction.left,
        manifestSymbol: 'moon',
      );
      const manifest = ['star', 'moon', 'star'];

      // --- Winning Branch: B, C, A ---
      final winningEngine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC],
        manifest: manifest,
        rackCapacity: 2,
      );

      expect(winningEngine.manifestIndex, 0);
      expect(winningEngine.nextRequiredSymbol, 'star');
      expect(winningEngine.canDispatch('A'), isTrue);
      expect(winningEngine.canDispatch('B'), isTrue);
      expect(winningEngine.canDispatch('C'), isFalse,
          reason: 'C is blocked by B at (1,1)');

      // Dispatch & Load B first
      winningEngine.executeDispatch('B');
      expect(winningEngine.canLoad('B'), isTrue);
      winningEngine.executeLoad('B');
      expect(winningEngine.manifestIndex, 1);
      expect(winningEngine.nextRequiredSymbol, 'moon');

      // Now C is clear to exit LEFT and matches MOON
      expect(winningEngine.canDispatch('C'), isTrue);
      winningEngine.executeDispatch('C');
      expect(winningEngine.canLoad('C'), isTrue);
      winningEngine.executeLoad('C');
      expect(winningEngine.manifestIndex, 2);
      expect(winningEngine.nextRequiredSymbol, 'star');

      // Now A matches STAR and can dispatch & load
      expect(winningEngine.canDispatch('A'), isTrue);
      winningEngine.executeDispatch('A');
      expect(winningEngine.canLoad('A'), isTrue);
      winningEngine.executeLoad('A');

      expect(winningEngine.isCompleted, isTrue);
      expect(winningEngine.isManifestComplete, isTrue);

      // --- Deadlock Branch: A first ---
      final deadEngine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC],
        manifest: manifest,
        rackCapacity: 2,
      );

      // Dispatch & Load A first
      deadEngine.executeDispatch('A');
      deadEngine.executeLoad('A');
      expect(deadEngine.manifestIndex, 1);
      expect(deadEngine.nextRequiredSymbol, 'moon');

      // Now MOON is required.
      // B on board is STAR -> even if dispatched to rack, cannot load!
      // C on board is MOON, but C is BLOCKED by B at (1,1)!
      // If player dispatches B to rack:
      deadEngine.executeDispatch('B');
      expect(deadEngine.canLoad('B'), isFalse, reason: 'B is STAR, but MOON is required');
      // Now C is clear to dispatch to rack:
      deadEngine.executeDispatch('C');
      // Rack has [B, C]. Rack is full!
      // Next required is MOON. C is in rack and can load!
      expect(deadEngine.canLoad('C'), isTrue);
      deadEngine.executeLoad('C');
      // Now MOON is loaded. Next required is STAR.
      expect(deadEngine.nextRequiredSymbol, 'star');
      // B in rack matches STAR!
      expect(deadEngine.canLoad('B'), isTrue);
      deadEngine.executeLoad('B');
      expect(deadEngine.isCompleted, isTrue);
      // Notice: In Depot Challenge, rack buffering allows A first to also be solved if rack cap >= 2!
      // However, if rack cap is 1:
      final tightEngine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB, pC],
        manifest: manifest,
        rackCapacity: 1, // With rack capacity 1, A first deadlocks!
      );
      tightEngine.executeDispatch('A');
      tightEngine.executeLoad('A');
      // Now MOON is required. C is blocked by B.
      // If we dispatch B into rack (cap 1):
      tightEngine.executeDispatch('B');
      // Rack is full with B (STAR). Next is MOON.
      // B cannot load! C cannot dispatch because rack is full!
      expect(tightEngine.isDeadlocked, isTrue);
    });

    test('Undo completely restores gear orientations and manifest index', () {
      const pA = Parcel(
        id: 'A',
        row: 1,
        col: 1,
        direction: Direction.up,
        hasGear: true,
        manifestSymbol: 'star',
      );
      const pB = Parcel(
        id: 'B',
        row: 0,
        col: 0,
        direction: Direction.up,
        hasGear: false,
        manifestSymbol: 'star',
      );

      final engine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pB],
        manifest: ['star', 'star'],
        rackCapacity: 2,
      );

      expect(engine.manifestIndex, 0);
      expect(engine.getParcel('A')!.direction, Direction.up);

      // Dispatch B
      engine.executeDispatch('B');
      expect(engine.getParcel('A')!.direction, Direction.right);

      // Undo dispatch
      final undone = engine.undo();
      expect(undone?.id, 'B');
      expect(engine.getParcel('A')!.direction, Direction.up,
          reason: 'Gear parcel direction must be restored to UP on undo');
      expect(engine.matrix.getById('B'), isNotNull);
    });

    test('Preview Dispatch computes projected state without mutating engine', () {
      const pA = Parcel(
        id: 'A',
        row: 1,
        col: 1,
        direction: Direction.up,
        hasGear: true,
      );
      const pC = Parcel(
        id: 'C',
        row: 0,
        col: 0,
        direction: Direction.up,
        hasGear: false,
      );

      final engine = PuzzleEngine(
        rows: 4,
        cols: 4,
        parcels: [pA, pC],
        rackCapacity: 2,
      );

      final preview = engine.previewDispatch('C');
      expect(preview.canExit, isTrue);
      expect(preview.projectedParcels.length, 1);
      final projA = preview.projectedParcels.firstWhere((p) => p.id == 'A');
      expect(projA.direction, Direction.right);

      // Verify engine was NOT mutated
      expect(engine.matrix.getById('C'), isNotNull);
      expect(engine.matrix.getById('A')!.direction, Direction.up);
      expect(engine.moves, isEmpty);
    });
  });
}

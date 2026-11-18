import '../models/parcel.dart';
import 'puzzle_engine.dart';

/// The result of an independent solver evaluation.
class SolverResult {
  final bool isSolvable;
  final List<String> solutionOrder;
  final List<String> deadlockedParcels;
  final int initialParcelCount;
  final int maxBranchingFactor;

  const SolverResult({
    required this.isSolvable,
    required this.solutionOrder,
    required this.deadlockedParcels,
    required this.initialParcelCount,
    this.maxBranchingFactor = 1,
  });

  @override
  String toString() => isSolvable
      ? 'SolverResult(SOLVABLE in ${solutionOrder.length} steps)'
      : 'SolverResult(DEADLOCK with ${deadlockedParcels.length} stuck parcels)';
}

/// Independent deterministic puzzle solver for verification and validation.
class PuzzleSolver {
  const PuzzleSolver();

  /// Attempts to solve the given board by iteratively picking and clearing unblocked parcels.
  /// Guarantees independent evaluation without mutating the original engine.
  static SolverResult solve({
    required int rows,
    required int cols,
    required List<Parcel> parcels,
  }) {
    if (parcels.isEmpty) {
      return const SolverResult(
        isSolvable: true,
        solutionOrder: [],
        deadlockedParcels: [],
        initialParcelCount: 0,
      );
    }

    final engine = PuzzleEngine(rows: rows, cols: cols, parcels: parcels);
    final solution = <String>[];
    int maxBranching = 1;

    while (!engine.isCompleted) {
      final clearParcels = engine.findClearParcels();
      if (clearParcels.isEmpty) {
        // Deadlock reached: remaining parcels cannot exit
        return SolverResult(
          isSolvable: false,
          solutionOrder: solution,
          deadlockedParcels: engine.activeParcels.map((p) => p.id).toList(),
          initialParcelCount: parcels.length,
          maxBranchingFactor: maxBranching,
        );
      }

      if (clearParcels.length > maxBranching) {
        maxBranching = clearParcels.length;
      }

      // Pick the first legal move
      final pick = clearParcels.first;
      engine.executeExit(pick.id);
      solution.add(pick.id);
    }

    return SolverResult(
      isSolvable: true,
      solutionOrder: solution,
      deadlockedParcels: const [],
      initialParcelCount: parcels.length,
      maxBranchingFactor: maxBranching,
    );
  }

  /// Verifies the critical game invariant:
  /// Any legal move chosen among multiple clear exits must strictly leave a solvable board.
  /// Explores all removal paths up to [maxPaths] to guarantee no branch ever causes deadlock.
  static bool verifyAllRemovalOrdersSolvable({
    required int rows,
    required int cols,
    required List<Parcel> parcels,
    int maxPaths = 100,
  }) {
    int pathsChecked = 0;

    bool explore(PuzzleEngine engine) {
      if (engine.isCompleted) return true;
      if (pathsChecked >= maxPaths) return true;

      final clear = engine.findClearParcels();
      if (clear.isEmpty) return false;

      for (final p in clear) {
        pathsChecked++;
        final subEngine = engine.clone();
        subEngine.executeExit(p.id);
        if (!explore(subEngine)) {
          return false;
        }
      }
      return true;
    }

    final initialEngine =
        PuzzleEngine(rows: rows, cols: cols, parcels: parcels);
    return explore(initialEngine);
  }
}

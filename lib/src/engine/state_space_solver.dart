import 'puzzle_engine.dart';

/// The solution status from a state space exploration.
enum SolveStatus {
  solvable,
  unsolvable,
  budgetExceeded,
}

/// The result of an independent state space solver evaluation.
class SolverResult {
  final SolveStatus status;

  /// Full sequence of actions (both dispatches to rack and loads to truck).
  final List<String> witnessPath;

  /// Sequence of board parcel IDs dispatched to the rack.
  final List<String> dispatchSequence;

  final int exploredStates;
  final int maxBranchingFactor;
  final int deadEndCount;

  const SolverResult({
    required this.status,
    required this.witnessPath,
    this.dispatchSequence = const [],
    required this.exploredStates,
    this.maxBranchingFactor = 0,
    this.deadEndCount = 0,
  });

  bool get isSolvable => status == SolveStatus.solvable;
  bool get isUnsolvable => status == SolveStatus.unsolvable;
  bool get isBudgetExceeded => status == SolveStatus.budgetExceeded;

  @override
  String toString() {
    switch (status) {
      case SolveStatus.solvable:
        return 'SolverResult(SOLVABLE, steps: ${witnessPath.length}, dispatches: ${dispatchSequence.length}, explored: $exploredStates, maxBranch: $maxBranchingFactor)';
      case SolveStatus.unsolvable:
        return 'SolverResult(UNSOLVABLE, explored: $exploredStates, deadEnds: $deadEndCount)';
      case SolveStatus.budgetExceeded:
        return 'SolverResult(BUDGET_EXCEEDED, explored: $exploredStates)';
    }
  }
}

/// Memoized state-space solver for Depot Challenge puzzles.
///
/// Features:
/// - Explores both Stage A/B (board dispatch into sorting rack) and Stage C (loading into delivery truck)
/// - Strictly prioritizes dominant rack-to-truck loads (frees buffer slot, progresses manifest, 0 gear rotations)
/// - Deterministic backtracking with state hashing
/// - Zero heap cloning per search step using engine execute/undo
/// - Returns witness path, solvable/unsolvable/budgetExceeded status
/// - Evaluates whether choices are consequential (branch leading to rack jam or deadlock)
class StateSpaceSolver {
  final int maxStates;

  const StateSpaceSolver({this.maxStates = 50000});

  static String computeStateKey(PuzzleEngine engine) {
    final boardParcels = engine.activeParcels;
    final boardItems = <String>[];
    for (final p in boardParcels) {
      boardItems.add('${p.id}:${p.direction.name}');
    }
    boardItems.sort();

    final rackIds = engine.rack.map((p) => p.id).toList()..sort();

    return 'm${engine.manifestIndex};r:${rackIds.join(',')};b:${boardItems.join(',')}';
  }

  /// Solves the puzzle from the engine's current state, returning the first valid witness path found.
  SolverResult solve(PuzzleEngine initialEngine) {
    if (initialEngine.isCompleted) {
      return const SolverResult(
        status: SolveStatus.solvable,
        witnessPath: [],
        dispatchSequence: [],
        exploredStates: 0,
        maxBranchingFactor: 0,
      );
    }

    final engine = initialEngine.clone();
    final visitedDeadends = <String>{};
    final currentPath = <String>[];
    final currentDispatches = <String>[];
    int explored = 0;
    int maxBranching = 0;
    int deadEnds = 0;
    bool budgetHit = false;

    bool search() {
      if (engine.isCompleted) {
        return true;
      }
      if (explored >= maxStates) {
        budgetHit = true;
        return false;
      }

      final stateKey = computeStateKey(engine);
      if (visitedDeadends.contains(stateKey)) {
        return false;
      }

      explored++;

      // Dominant action: If any parcel in the sorting rack matches the next required truck slot,
      // loading it is strictly dominant (frees buffer capacity, advances manifest, does not rotate gears).
      final loadable = engine.findLoadableRackParcels();
      if (loadable.isNotEmpty) {
        final toLoad = loadable.first;
        engine.executeLoad(toLoad.id);
        currentPath.add(toLoad.id);

        if (search()) {
          return true;
        }

        currentPath.removeLast();
        engine.undo();
        visitedDeadends.add(stateKey);
        return false;
      }

      // No rack parcel can be loaded. We must dispatch an unblocked board parcel into the rack.
      if (engine.isRackFull) {
        // Rack is full with non-matching parcels and no board parcel can leave -> DEADLOCK!
        deadEnds++;
        visitedDeadends.add(stateKey);
        return false;
      }

      final dispatchable = engine.findDispatchableParcels();
      if (dispatchable.length > maxBranching) {
        maxBranching = dispatchable.length;
      }

      if (dispatchable.isEmpty) {
        // No parcel can exit the board -> DEADLOCK!
        deadEnds++;
        visitedDeadends.add(stateKey);
        return false;
      }

      for (final candidate in dispatchable) {
        engine.executeDispatch(candidate.id);
        currentPath.add(candidate.id);
        currentDispatches.add(candidate.id);

        if (search()) {
          return true;
        }

        currentDispatches.removeLast();
        currentPath.removeLast();
        engine.undo();

        if (budgetHit) return false;
      }

      visitedDeadends.add(stateKey);
      return false;
    }

    final found = search();

    if (found) {
      return SolverResult(
        status: SolveStatus.solvable,
        witnessPath: List.unmodifiable(currentPath),
        dispatchSequence: List.unmodifiable(currentDispatches),
        exploredStates: explored,
        maxBranchingFactor: maxBranching,
        deadEndCount: deadEnds,
      );
    }

    if (budgetHit) {
      return SolverResult(
        status: SolveStatus.budgetExceeded,
        witnessPath: const [],
        dispatchSequence: const [],
        exploredStates: explored,
        maxBranchingFactor: maxBranching,
        deadEndCount: deadEnds,
      );
    }

    return SolverResult(
      status: SolveStatus.unsolvable,
      witnessPath: const [],
      dispatchSequence: const [],
      exploredStates: explored,
      maxBranchingFactor: maxBranching,
      deadEndCount: deadEnds,
    );
  }

  /// Evaluates whether the puzzle has consequential choices (i.e. at least one branch leads to deadlock).
  bool hasConsequentialBranch(PuzzleEngine initialEngine) {
    final engine = initialEngine.clone();

    // If a rack parcel can load, loading it is strictly dominant, so check dispatch branches.
    if (engine.findLoadableRackParcels().isNotEmpty) {
      final toLoad = engine.findLoadableRackParcels().first;
      engine.executeLoad(toLoad.id);
      final sub = hasConsequentialBranch(engine);
      engine.undo();
      return sub;
    }

    final dispatchable = engine.findDispatchableParcels();
    if (dispatchable.length <= 1) return false;

    int solvableBranches = 0;
    int deadBranches = 0;

    for (final move in dispatchable) {
      engine.executeDispatch(move.id);
      final subResult = solve(engine);
      if (subResult.isSolvable) {
        solvableBranches++;
      } else {
        deadBranches++;
      }
      engine.undo();
    }

    return solvableBranches > 0 && deadBranches > 0;
  }

  /// Dynamic hint helper for gameplay:
  /// Evaluates the current state.
  /// - If a parcel in the rack can load to the truck: returns that rack parcel ID.
  /// - If a board parcel should be dispatched next: returns that board parcel ID.
  /// - If the current state is stuck: returns null.
  String? findBestMove(PuzzleEngine currentEngine) {
    if (currentEngine.isCompleted) return null;

    // Check if rack parcel is ready to load
    final loadable = currentEngine.findLoadableRackParcels();
    if (loadable.isNotEmpty) {
      return loadable.first.id;
    }

    final result = solve(currentEngine);
    if (result.isSolvable && result.witnessPath.isNotEmpty) {
      return result.witnessPath.first;
    }
    return null;
  }
}

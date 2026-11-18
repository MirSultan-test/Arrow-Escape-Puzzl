import '../models/direction.dart';
import '../models/game_move.dart';
import '../models/parcel.dart';
import 'board_matrix.dart';
import 'ray_cast.dart';

/// Exit / move legality status for user interaction feedback and validation.
enum ExitLegality {
  legal,
  blockedByRay,
  rackFull,
  manifestMismatch,
  notOnBoard,
  notInRack,
}

/// Detailed evaluation of a parcel tap (on board or rack).
class ExitEvaluation {
  final ExitLegality legality;
  final RayCastResult? rayResult;
  final bool matchesManifest;
  final String? expectedManifestSymbol;
  final String? parcelManifestSymbol;

  const ExitEvaluation({
    required this.legality,
    this.rayResult,
    required this.matchesManifest,
    this.expectedManifestSymbol,
    this.parcelManifestSymbol,
  });

  bool get isLegal => legality == ExitLegality.legal;
}

/// Non-mutating preview of what the board & rack state would become after candidate dispatch.
class ExitPreview {
  final bool canExit;
  final ExitLegality legality;
  final Parcel? parcel;
  final List<Parcel> projectedParcels;
  final List<Parcel> projectedRack;
  final String? nextManifestSymbol;
  final int nextManifestIndex;

  const ExitPreview({
    required this.canExit,
    required this.legality,
    this.parcel,
    required this.projectedParcels,
    required this.projectedRack,
    this.nextManifestSymbol,
    this.nextManifestIndex = 0,
  });
}

/// Pure puzzle logic engine, completely decoupled from Flutter widgets and rendering.
///
/// Implements the Depot Challenge 3-stage mechanics:
/// - Stage A: Solve the Arrow Board (unobstructed rays)
/// - Stage B: Limited-Capacity Sorting Rack (default 2 slots, buffers parcels)
/// - Stage C: Delivery Truck Loading (matches manifest, departs when filled)
///
/// Gear Shift Rule: Dispatches from board to rack rotate surviving board gear parcels 90° CW.
/// Loading from rack to truck does NOT rotate gear parcels.
class PuzzleEngine {
  final int rows;
  final int cols;
  final List<Parcel> initialParcels;
  final List<String>? initialManifest;
  final int rackCapacity;
  final List<int>? truckSizes;

  late final BoardMatrix _matrix;
  final List<Parcel> _rack = [];
  final List<GameMove> _moves = [];
  int _manifestIndex = 0;

  PuzzleEngine({
    required this.rows,
    required this.cols,
    required List<Parcel> parcels,
    List<String>? manifest,
    this.rackCapacity = 2,
    this.truckSizes,
  })  : initialParcels = List.unmodifiable(parcels),
        initialManifest =
            manifest != null ? List.unmodifiable(manifest) : null {
    _matrix = BoardMatrix(rows: rows, cols: cols);
    _populateInitial();
  }

  void _populateInitial() {
    _matrix.clear();
    _rack.clear();
    for (final parcel in initialParcels) {
      _matrix.place(parcel);
    }
  }

  /// Current board matrix.
  BoardMatrix get matrix => _matrix;

  /// All parcels currently on the board.
  List<Parcel> get activeParcels => _matrix.allParcels;

  /// All parcels currently sitting in the sorting rack.
  List<Parcel> get rack => List.unmodifiable(_rack);

  /// Number of parcels remaining (board + rack).
  int get remainingCount => _matrix.parcelCount + _rack.length;

  /// Number of parcels still on the board.
  int get boardParcelCount => _matrix.parcelCount;

  /// Number of parcels in the sorting rack.
  int get rackParcelCount => _rack.length;

  /// Whether the sorting rack has reached maximum capacity.
  bool get isRackFull => _rack.length >= rackCapacity;

  /// Whether the sorting rack is empty.
  bool get isRackEmpty => _rack.isEmpty;

  /// Total parcels when the puzzle started.
  int get initialCount => initialParcels.length;

  /// Number of parcels successfully delivered to trucks.
  int get deliveredCount =>
      _moves.where((m) => m.type == GameMoveType.loadToTruck).length;

  /// Alias for deliveredCount / moves made.
  int get clearedCount =>
      _moves.where((m) => m.type == GameMoveType.loadToTruck).length;

  /// Chronological stack of moves made.
  List<GameMove> get moves => List.unmodifiable(_moves);

  /// Whether the puzzle is fully solved (board empty, rack empty, manifest complete).
  bool get isCompleted =>
      _matrix.isEmpty && _rack.isEmpty && isManifestComplete;

  /// Whether manifest rules apply.
  bool get hasManifest =>
      initialManifest != null && initialManifest!.isNotEmpty;

  /// Full manifest sequence.
  List<String>? get manifest => initialManifest;

  /// Current zero-based index in the manifest sequence.
  int get manifestIndex => _manifestIndex;

  /// The next required manifest symbol, or null if complete or no manifest.
  String? get nextRequiredSymbol {
    if (initialManifest == null || _manifestIndex >= initialManifest!.length) {
      return null;
    }
    return initialManifest![_manifestIndex];
  }

  /// Remaining manifest symbols from current index to the end.
  List<String> get remainingManifest {
    if (initialManifest == null || _manifestIndex >= initialManifest!.length) {
      return const [];
    }
    return initialManifest!.sublist(_manifestIndex);
  }

  /// Whether the manifest sequence has been completely fulfilled.
  bool get isManifestComplete =>
      initialManifest == null || _manifestIndex >= initialManifest!.length;

  // ---------------------------------------------------------------------------
  // Truck Batch Helpers
  // ---------------------------------------------------------------------------

  /// The index of the current delivery truck (0-indexed).
  int get currentTruckIndex {
    if (truckSizes == null || truckSizes!.isEmpty) return 0;
    int accumulated = 0;
    for (int i = 0; i < truckSizes!.length; i++) {
      accumulated += truckSizes![i];
      if (_manifestIndex < accumulated) {
        return i;
      }
    }
    return truckSizes!.length - 1;
  }

  /// The total number of trucks for this level.
  int get totalTrucks =>
      truckSizes != null && truckSizes!.isNotEmpty ? truckSizes!.length : 1;

  /// The capacity of the current delivery truck.
  int get currentTruckCapacity {
    if (truckSizes == null || truckSizes!.isEmpty) {
      return initialManifest?.length ?? initialParcels.length;
    }
    final idx = currentTruckIndex;
    return truckSizes![idx];
  }

  /// How many parcels have been loaded into the current truck.
  int get currentTruckLoadedCount {
    if (truckSizes == null || truckSizes!.isEmpty) {
      return _manifestIndex;
    }
    int startOfCurrentTruck = 0;
    for (int i = 0; i < currentTruckIndex; i++) {
      startOfCurrentTruck += truckSizes![i];
    }
    return (_manifestIndex - startOfCurrentTruck).clamp(0, currentTruckCapacity);
  }

  /// Manifest slice for the current truck.
  List<String> get currentTruckManifest {
    if (initialManifest == null) return const [];
    if (truckSizes == null || truckSizes!.isEmpty) return initialManifest!;
    int start = 0;
    for (int i = 0; i < currentTruckIndex; i++) {
      start += truckSizes![i];
    }
    final end = (start + currentTruckCapacity).clamp(0, initialManifest!.length);
    return initialManifest!.sublist(start, end);
  }

  // ---------------------------------------------------------------------------
  // Parcel Lookup & Ray Caster
  // ---------------------------------------------------------------------------

  /// Looks up parcel by ID (checks board first, then rack).
  Parcel? getParcel(String id) {
    final onBoard = _matrix.getById(id);
    if (onBoard != null) return onBoard;
    for (final p in _rack) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Examines the ray for a specific board parcel.
  RayCastResult evaluateParcel(String id) {
    final parcel = _matrix.getById(id);
    if (parcel == null) {
      throw ArgumentError('Parcel $id is not on the board');
    }
    return RayCaster.cast(matrix: _matrix, parcel: parcel);
  }

  // ---------------------------------------------------------------------------
  // Stage A & B: Board -> Rack Dispatch
  // ---------------------------------------------------------------------------

  /// Evaluates whether a board parcel can be dispatched to the sorting rack.
  ExitEvaluation evaluateDispatch(String parcelId) {
    final parcel = _matrix.getById(parcelId);
    if (parcel == null) {
      return const ExitEvaluation(
        legality: ExitLegality.notOnBoard,
        matchesManifest: false,
      );
    }

    final ray = RayCaster.cast(matrix: _matrix, parcel: parcel);
    if (!ray.isClear) {
      return ExitEvaluation(
        legality: ExitLegality.blockedByRay,
        rayResult: ray,
        matchesManifest: false,
        expectedManifestSymbol: nextRequiredSymbol,
        parcelManifestSymbol: parcel.manifestSymbol,
      );
    }

    if (isRackFull) {
      return ExitEvaluation(
        legality: ExitLegality.rackFull,
        rayResult: ray,
        matchesManifest: false,
        expectedManifestSymbol: nextRequiredSymbol,
        parcelManifestSymbol: parcel.manifestSymbol,
      );
    }

    final expected = nextRequiredSymbol;
    final matches = expected == null || parcel.manifestSymbol == expected;

    return ExitEvaluation(
      legality: ExitLegality.legal,
      rayResult: ray,
      matchesManifest: matches,
      expectedManifestSymbol: expected,
      parcelManifestSymbol: parcel.manifestSymbol,
    );
  }

  /// Convenience check whether [parcelId] can dispatch from board to rack right now.
  bool canDispatch(String parcelId) => evaluateDispatch(parcelId).isLegal;

  /// Finds all parcels that have an unobstructed ray to the edge (regardless of rack capacity).
  List<Parcel> findClearParcels() {
    final clear = <Parcel>[];
    for (final parcel in _matrix.allParcels) {
      if (RayCaster.cast(matrix: _matrix, parcel: parcel).isClear) {
        clear.add(parcel);
      }
    }
    return clear;
  }

  /// Finds all parcels that can legally dispatch to the sorting rack right now.
  List<Parcel> findDispatchableParcels() {
    if (isRackFull) return const [];
    return findClearParcels();
  }

  /// Executes a dispatch from board to sorting rack:
  /// 1. Removes parcel from board.
  /// 2. Adds parcel to sorting rack.
  /// 3. Rotates all surviving board gear parcels 90° clockwise.
  /// 4. Records move into history for 100% reversible undo.
  Parcel executeDispatch(String parcelId) {
    final eval = evaluateDispatch(parcelId);
    if (!eval.isLegal) {
      if (eval.legality == ExitLegality.notOnBoard) {
        throw StateError('Cannot dispatch: parcel $parcelId is not on the board');
      }
      if (eval.legality == ExitLegality.blockedByRay) {
        throw StateError(
          'Cannot dispatch: parcel $parcelId is blocked by ${eval.rayResult?.blockingParcel?.id}',
        );
      }
      if (eval.legality == ExitLegality.rackFull) {
        throw StateError(
          'Cannot dispatch: sorting rack is full ($rackCapacity/$rackCapacity)',
        );
      }
    }

    final departingParcel = _matrix.getById(parcelId)!;

    // Record pre-move gear orientations of all surviving gear parcels on board
    final preMoveGears = <String, Direction>{};
    for (final p in _matrix.allParcels) {
      if (p.id != parcelId && p.hasGear) {
        preMoveGears[p.id] = p.direction;
      }
    }

    // Step 1: Remove departing parcel from board
    _matrix.removeById(parcelId);

    // Step 2: Add parcel to sorting rack
    final slotIdx = _rack.length;
    _rack.add(departingParcel);

    // Step 3: Rotate all surviving gear parcels on board 90° clockwise
    for (final p in _matrix.allParcels) {
      if (p.hasGear) {
        final rotated = p.copyWith(direction: p.direction.rotateClockwise90());
        _matrix.place(rotated);
      }
    }

    // Step 4: Record move
    _moves.add(
      GameMove(
        parcel: departingParcel,
        type: GameMoveType.dispatchToRack,
        moveIndex: _moves.length,
        preMoveManifestIndex: _manifestIndex,
        preMoveGearOrientations: preMoveGears,
        rackSlotIndex: slotIdx,
      ),
    );

    return departingParcel;
  }

  // ---------------------------------------------------------------------------
  // Stage C: Rack -> Truck Load
  // ---------------------------------------------------------------------------

  /// Evaluates whether a parcel in the rack can be loaded into the delivery truck.
  ExitEvaluation evaluateLoad(String parcelId) {
    final idx = _rack.indexWhere((p) => p.id == parcelId);
    if (idx < 0) {
      return const ExitEvaluation(
        legality: ExitLegality.notInRack,
        matchesManifest: false,
      );
    }

    final parcel = _rack[idx];
    final expected = nextRequiredSymbol;
    final matches = expected == null || parcel.manifestSymbol == expected;

    if (!matches) {
      return ExitEvaluation(
        legality: ExitLegality.manifestMismatch,
        matchesManifest: false,
        expectedManifestSymbol: expected,
        parcelManifestSymbol: parcel.manifestSymbol,
      );
    }

    return ExitEvaluation(
      legality: ExitLegality.legal,
      matchesManifest: true,
      expectedManifestSymbol: expected,
      parcelManifestSymbol: parcel.manifestSymbol,
    );
  }

  /// Convenience check whether [parcelId] in rack can load into truck right now.
  bool canLoad(String parcelId) => evaluateLoad(parcelId).isLegal;

  /// Finds all parcels currently sitting in rack that match the next required truck slot.
  List<Parcel> findLoadableRackParcels() {
    final expected = nextRequiredSymbol;
    return _rack.where((p) => expected == null || p.manifestSymbol == expected).toList();
  }

  /// Executes loading a parcel from sorting rack into the delivery truck:
  /// 1. Removes parcel from rack.
  /// 2. Advances manifest index.
  /// 3. Does NOT rotate board gears.
  /// 4. Records move into history for 100% reversible undo.
  Parcel executeLoad(String parcelId) {
    final eval = evaluateLoad(parcelId);
    if (!eval.isLegal) {
      if (eval.legality == ExitLegality.notInRack) {
        throw StateError('Cannot load: parcel $parcelId is not in the sorting rack');
      }
      if (eval.legality == ExitLegality.manifestMismatch) {
        throw StateError(
          'Cannot load: parcel $parcelId (${eval.parcelManifestSymbol}) does not match next required manifest symbol (${eval.expectedManifestSymbol})',
        );
      }
    }

    final slotIdx = _rack.indexWhere((p) => p.id == parcelId);
    final loadedParcel = _rack.removeAt(slotIdx);
    final preMoveManifest = _manifestIndex;

    if (hasManifest) {
      _manifestIndex++;
    }

    _moves.add(
      GameMove(
        parcel: loadedParcel,
        type: GameMoveType.loadToTruck,
        moveIndex: _moves.length,
        preMoveManifestIndex: preMoveManifest,
        preMoveGearOrientations: const {},
        rackSlotIndex: slotIdx,
      ),
    );

    return loadedParcel;
  }

  // ---------------------------------------------------------------------------
  // Unified Compatibility Helpers
  // ---------------------------------------------------------------------------

  /// Unified legality check for a parcel ID on either the board or in the rack.
  ExitEvaluation evaluateExitLegality(String parcelId) {
    if (_matrix.getById(parcelId) != null) {
      return evaluateDispatch(parcelId);
    }
    if (_rack.any((p) => p.id == parcelId)) {
      return evaluateLoad(parcelId);
    }
    return const ExitEvaluation(
      legality: ExitLegality.notOnBoard,
      matchesManifest: false,
    );
  }

  /// Unified check whether [parcelId] can exit board OR load to truck right now.
  bool canExit(String parcelId) {
    if (_matrix.getById(parcelId) != null) {
      return canDispatch(parcelId);
    }
    if (_rack.any((p) => p.id == parcelId)) {
      return canLoad(parcelId);
    }
    return false;
  }

  /// Unified execution for [parcelId]:
  /// Dispatches if on board; loads if in rack.
  /// If [hasManifest] is false (unmanifested / legacy mode), automatically loads to complete the exit.
  Parcel executeExit(String parcelId) {
    if (_matrix.getById(parcelId) != null) {
      final p = executeDispatch(parcelId);
      if (!hasManifest) {
        executeLoad(parcelId);
      }
      return p;
    }
    if (_rack.any((p) => p.id == parcelId)) {
      return executeLoad(parcelId);
    }
    throw StateError('Parcel $parcelId does not exist on board or in rack');
  }

  /// All parcels that can be acted on right now (dispatchable board parcels + loadable rack parcels).
  List<Parcel> findLegalMoves() {
    final list = <Parcel>[];
    list.addAll(findLoadableRackParcels());
    list.addAll(findDispatchableParcels());
    return list;
  }

  /// Whether the game is in a deadlock state:
  /// Remaining parcels exist, but no parcel can be loaded from the rack
  /// and no parcel can be dispatched from the board.
  bool get isDeadlocked {
    if (isCompleted) return false;
    final canLoadAny = findLoadableRackParcels().isNotEmpty;
    final canDispatchAny = findDispatchableParcels().isNotEmpty;
    return !canLoadAny && !canDispatchAny;
  }

  // ---------------------------------------------------------------------------
  // Reversible Undo & State Restoration
  // ---------------------------------------------------------------------------

  /// Undoes the most recent action atomically:
  /// - If [loadToTruck]: restores parcel to rack at previous slot, restores manifest index.
  /// - If [dispatchToRack]: restores parcel to board cell, removes from rack, restores pre-move gear orientations.
  Parcel? undo() {
    if (_moves.isEmpty) return null;
    final lastMove = _moves.removeLast();

    if (lastMove.type == GameMoveType.loadToTruck) {
      _manifestIndex = lastMove.preMoveManifestIndex;
      final insertIndex = lastMove.rackSlotIndex.clamp(0, _rack.length);
      _rack.insert(insertIndex, lastMove.parcel);
      if (!hasManifest &&
          _moves.isNotEmpty &&
          _moves.last.type == GameMoveType.dispatchToRack &&
          _moves.last.parcel.id == lastMove.parcel.id) {
        return undo();
      }
      return lastMove.parcel;
    } else {
      // dispatchToRack
      _rack.removeWhere((p) => p.id == lastMove.parcel.id);
      for (final entry in lastMove.preMoveGearOrientations.entries) {
        final existing = _matrix.getById(entry.key);
        if (existing != null) {
          _matrix.place(existing.copyWith(direction: entry.value));
        }
      }
      _matrix.place(lastMove.parcel);
      return lastMove.parcel;
    }
  }

  /// Resets the engine back to its initial level state, clearing all moves.
  void restart() {
    _moves.clear();
    _manifestIndex = 0;
    _populateInitial();
  }

  /// Restores an in-progress state (e.g. from local save data).
  void restoreState({
    required List<Parcel> currentParcels,
    List<Parcel>? rackParcels,
    List<GameMove>? pastMoves,
    int manifestIndex = 0,
  }) {
    _matrix.clear();
    for (final p in currentParcels) {
      _matrix.place(p);
    }
    _rack.clear();
    if (rackParcels != null) {
      _rack.addAll(rackParcels);
    }
    _moves.clear();
    if (pastMoves != null) {
      _moves.addAll(pastMoves);
    }
    _manifestIndex = manifestIndex;
  }

  /// Non-mutating preview of what board & rack would look like if [parcelId] is dispatched.
  ExitPreview previewDispatch(String parcelId) {
    final eval = evaluateDispatch(parcelId);
    if (!eval.isLegal) {
      return ExitPreview(
        canExit: false,
        legality: eval.legality,
        parcel: _matrix.getById(parcelId),
        projectedParcels: _matrix.allParcels,
        projectedRack: _rack,
        nextManifestSymbol: nextRequiredSymbol,
        nextManifestIndex: _manifestIndex,
      );
    }

    final departing = _matrix.getById(parcelId)!;
    final projected = <Parcel>[];

    for (final p in _matrix.allParcels) {
      if (p.id == parcelId) continue;
      if (p.hasGear) {
        projected.add(p.copyWith(direction: p.direction.rotateClockwise90()));
      } else {
        projected.add(p);
      }
    }

    final projRack = List<Parcel>.from(_rack)..add(departing);

    return ExitPreview(
      canExit: true,
      legality: ExitLegality.legal,
      parcel: departing,
      projectedParcels: projected,
      projectedRack: projRack,
      nextManifestSymbol: nextRequiredSymbol,
      nextManifestIndex: _manifestIndex,
    );
  }

  /// Backwards compatibility alias for [previewDispatch].
  ExitPreview previewExit(String parcelId) => previewDispatch(parcelId);

  /// Creates a deep copy of this engine state.
  PuzzleEngine clone() {
    final copy = PuzzleEngine(
      rows: rows,
      cols: cols,
      parcels: initialParcels,
      manifest: initialManifest != null ? List<String>.from(initialManifest!) : null,
      rackCapacity: rackCapacity,
      truckSizes: truckSizes != null ? List<int>.from(truckSizes!) : null,
    );
    copy.restoreState(
      currentParcels: _matrix.allParcels,
      rackParcels: _rack,
      pastMoves: _moves,
      manifestIndex: _manifestIndex,
    );
    return copy;
  }
}

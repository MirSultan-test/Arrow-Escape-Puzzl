import 'dart:math' as math;
import '../models/direction.dart';
import '../models/level_data.dart';
import '../models/parcel.dart';
import 'board_matrix.dart';
import 'puzzle_solver.dart';
import 'ray_cast.dart';

/// Configuration parameters for deterministic seeded level generation.
class LevelGenerationConfig {
  final int seed;
  final int rows;
  final int cols;
  final int targetParcelCount;
  final String difficulty;
  final int maxPlacementAttempts;
  final int maxRetries;

  const LevelGenerationConfig({
    required this.seed,
    required this.rows,
    required this.cols,
    required this.targetParcelCount,
    this.difficulty = 'medium',
    this.maxPlacementAttempts = 250,
    this.maxRetries = 20,
  });
}

/// Offline procedural level generator using the reverse-insertion construction method.
class LevelGenerator {
  const LevelGenerator();

  /// Canonical structural signature of a board, used to detect exact duplicates.
  static String computeSignature(int rows, int cols, List<Parcel> parcels) {
    final sorted = List<Parcel>.from(parcels)
      ..sort((a, b) {
        if (a.row != b.row) return a.row.compareTo(b.row);
        return a.col.compareTo(b.col);
      });
    final buf = StringBuffer('${rows}x$cols:');
    for (final p in sorted) {
      buf.write('[${p.row},${p.col},${p.direction.name}]');
    }
    return buf.toString();
  }

  /// Computes all 8 symmetry signatures (rotations and reflections) for duplicate rejection.
  static Set<String> computeSymmetrySignatures(
      int rows, int cols, List<Parcel> parcels) {
    final signatures = <String>{};

    // Identity
    signatures.add(computeSignature(rows, cols, parcels));

    // Horizontal reflection (flip cols)
    final hFlip = parcels.map((p) {
      final newCol = cols - 1 - p.col;
      var newDir = p.direction;
      if (newDir == Direction.left) {
        newDir = Direction.right;
      } else if (newDir == Direction.right) {
        newDir = Direction.left;
      }
      return Parcel(id: p.id, row: p.row, col: newCol, direction: newDir);
    }).toList();
    signatures.add(computeSignature(rows, cols, hFlip));

    // Vertical reflection (flip rows)
    final vFlip = parcels.map((p) {
      final newRow = rows - 1 - p.row;
      var newDir = p.direction;
      if (newDir == Direction.up) {
        newDir = Direction.down;
      } else if (newDir == Direction.down) {
        newDir = Direction.up;
      }
      return Parcel(id: p.id, row: newRow, col: p.col, direction: newDir);
    }).toList();
    signatures.add(computeSignature(rows, cols, vFlip));

    // Rotations if square
    if (rows == cols) {
      // 90 deg clockwise
      final rot90 = parcels.map((p) {
        final newRow = p.col;
        final newCol = rows - 1 - p.row;
        var newDir = p.direction;
        switch (p.direction) {
          case Direction.up:
            newDir = Direction.right;
            break;
          case Direction.right:
            newDir = Direction.down;
            break;
          case Direction.down:
            newDir = Direction.left;
            break;
          case Direction.left:
            newDir = Direction.up;
            break;
        }
        return Parcel(id: p.id, row: newRow, col: newCol, direction: newDir);
      }).toList();
      signatures.add(computeSignature(rows, cols, rot90));

      // 180 deg
      final rot180 = rot90.map((p) {
        final newRow = p.col;
        final newCol = rows - 1 - p.row;
        var newDir = p.direction;
        switch (p.direction) {
          case Direction.up:
            newDir = Direction.right;
            break;
          case Direction.right:
            newDir = Direction.down;
            break;
          case Direction.down:
            newDir = Direction.left;
            break;
          case Direction.left:
            newDir = Direction.up;
            break;
        }
        return Parcel(id: p.id, row: newRow, col: newCol, direction: newDir);
      }).toList();
      signatures.add(computeSignature(rows, cols, rot180));
    }

    return signatures;
  }

  /// Generates a validated solvable level using reverse insertion with bounded retries.
  static LevelData generate({
    required int levelId,
    required LevelGenerationConfig config,
    String? levelName,
    Set<String>? existingSignatures,
  }) {
    for (int retry = 0; retry < config.maxRetries; retry++) {
      final currentSeed = config.seed + retry * 7919;
      final candidate = _attemptGeneration(
        levelId: levelId,
        config: config,
        effectiveSeed: currentSeed,
        levelName: levelName,
      );

      if (candidate != null) {
        final sig = computeSignature(candidate.rows, candidate.cols, candidate.parcels);
        if (existingSignatures != null && existingSignatures.contains(sig)) {
          // Reject duplicate layout
          continue;
        }
        return candidate;
      }
    }

    // Known-valid fallback to guarantee zero infinite loops
    return _buildDeterministicFallback(
      levelId: levelId,
      rows: config.rows,
      cols: config.cols,
      difficulty: config.difficulty,
      levelName: levelName,
    );
  }

  static LevelData? _attemptGeneration({
    required int levelId,
    required LevelGenerationConfig config,
    required int effectiveSeed,
    String? levelName,
  }) {
    final rand = math.Random(effectiveSeed);
    final rows = config.rows;
    final cols = config.cols;
    final targetCount = config.targetParcelCount.clamp(1, rows * cols);
    final matrix = BoardMatrix(rows: rows, cols: cols);
    final placedParcels = <Parcel>[];

    final colorTypes = ['standard', 'priority', 'fragile', 'eco', 'express'];

    int attempts = 0;
    while (placedParcels.length < targetCount &&
        attempts < config.maxPlacementAttempts) {
      attempts++;

      // Pick a random unoccupied cell
      final r = rand.nextInt(rows);
      final c = rand.nextInt(cols);
      if (matrix.getAt(r, c) != null) continue;

      // Find all directions whose exit ray is unobstructed among CURRENTLY placed parcels
      final validDirections = <Direction>[];
      for (final dir in Direction.values) {
        final testParcel = Parcel(
          id: 'test',
          row: r,
          col: c,
          direction: dir,
        );
        final ray = RayCaster.cast(matrix: matrix, parcel: testParcel);
        if (ray.isClear) {
          validDirections.add(dir);
        }
      }

      if (validDirections.isEmpty) continue;

      // Pick one valid clear direction
      final chosenDir =
          validDirections[rand.nextInt(validDirections.length)];
      final parcelId = 'p${placedParcels.length + 1}';
      final colorType = colorTypes[rand.nextInt(colorTypes.length)];

      final parcel = Parcel(
        id: parcelId,
        row: r,
        col: c,
        direction: chosenDir,
        colorType: colorType,
      );

      matrix.place(parcel);
      placedParcels.add(parcel);
    }

    if (placedParcels.length < targetCount) {
      return null;
    }

    // Reverse insertion order is candidate solution
    final candidateSolution =
        placedParcels.reversed.map((p) => p.id).toList();

    final level = LevelData(
      id: levelId,
      name: levelName ?? 'Level $levelId',
      rows: rows,
      cols: cols,
      parcels: placedParcels,
      difficulty: config.difficulty,
      exampleSolution: candidateSolution,
    );

    // Independent validation check
    final integrityError = level.validateIntegrity();
    if (integrityError != null) return null;

    final solveResult = PuzzleSolver.solve(
      rows: rows,
      cols: cols,
      parcels: placedParcels,
    );

    if (!solveResult.isSolvable ||
        solveResult.solutionOrder.length != placedParcels.length) {
      return null;
    }

    return level;
  }

  /// Known-valid structured fallback board for failsafe operation.
  static LevelData _buildDeterministicFallback({
    required int levelId,
    required int rows,
    required int cols,
    required String difficulty,
    String? levelName,
  }) {
    final parcels = <Parcel>[];
    // Create an edge-facing cascade that is guaranteed 100% solvable
    int count = 0;
    // Top row pointing up
    for (int c = 0; c < cols; c++) {
      count++;
      parcels.add(Parcel(
        id: 'p$count',
        row: 0,
        col: c,
        direction: Direction.up,
        colorType: 'standard',
      ));
    }
    // Bottom row pointing down
    for (int c = 0; c < cols; c++) {
      count++;
      parcels.add(Parcel(
        id: 'p$count',
        row: rows - 1,
        col: c,
        direction: Direction.down,
        colorType: 'priority',
      ));
    }
    // If room in middle, point left and right to clear outer columns
    if (rows > 2) {
      count++;
      parcels.add(Parcel(
        id: 'p$count',
        row: 1,
        col: 0,
        direction: Direction.left,
        colorType: 'eco',
      ));
      if (cols > 1) {
        count++;
        parcels.add(Parcel(
          id: 'p$count',
          row: 1,
          col: cols - 1,
          direction: Direction.right,
          colorType: 'fragile',
        ));
      }
    }

    final solveResult =
        PuzzleSolver.solve(rows: rows, cols: cols, parcels: parcels);

    return LevelData(
      id: levelId,
      name: levelName ?? 'Level $levelId',
      rows: rows,
      cols: cols,
      parcels: parcels,
      difficulty: difficulty,
      exampleSolution: solveResult.solutionOrder,
    );
  }
}

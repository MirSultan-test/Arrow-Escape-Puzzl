import '../../models/maze/maze_level.dart';
import '../../models/maze/monster.dart';
import 'maze_pathfinder.dart';

/// Result of validating a MazeLevel's geometry, reachability, monsters, and time budget.
class MazeValidationResult {
  final bool isValid;
  final List<String> errors;
  final int estimatedTourSteps;
  final double estimatedMinSeconds;

  const MazeValidationResult({
    required this.isValid,
    required this.errors,
    required this.estimatedTourSteps,
    required this.estimatedMinSeconds,
  });
}

/// Validates maze geometry, BFS reachability, multi-trip cargo routing, monster patrols, and time limits.
class MazeValidator {
  static MazeValidationResult validate(MazeLevel level) {
    final errors = <String>[];

    if (level.rows < 5 || level.cols < 5) {
      errors.add('Level ${level.id}: Grid too small (${level.cols}x${level.rows}).');
    }

    if (level.grid.length != level.rows) {
      errors.add(
          'Level ${level.id}: grid length (${level.grid.length}) != rows (${level.rows}).');
    } else {
      for (int r = 0; r < level.rows; r++) {
        if (level.grid[r].length != level.cols) {
          errors.add(
              'Level ${level.id}: row $r length (${level.grid[r].length}) != cols (${level.cols}).');
        }
      }
    }

    if (errors.isNotEmpty) {
      return MazeValidationResult(
        isValid: false,
        errors: errors,
        estimatedTourSteps: 0,
        estimatedMinSeconds: 0,
      );
    }

    // Check player start & exit cell walkability
    if (!level.isWalkable(level.playerStart.col, level.playerStart.row)) {
      errors.add(
          'Level ${level.id}: playerStart ${level.playerStart} is on a wall.');
    }
    if (!level.isWalkable(level.exitCell.col, level.exitCell.row)) {
      errors.add('Level ${level.id}: exitCell ${level.exitCell} is on a wall.');
    }

    // Check exit reachability from player start
    if (!MazePathfinder.isReachable(level, level.playerStart, level.exitCell)) {
      errors.add(
          'Level ${level.id}: exitCell ${level.exitCell} is unreachable from playerStart.');
    }

    // Check foods
    if (level.foods.isEmpty) {
      errors.add('Level ${level.id}: contains no food items.');
    }
    final foodIds = <String>{};
    final foodCells = <GridPoint>{};
    for (final f in level.foods) {
      if (!foodIds.add(f.id)) {
        errors.add('Level ${level.id}: duplicate food ID ${f.id}.');
      }
      final pt = GridPoint(f.col, f.row);
      if (!foodCells.add(pt)) {
        errors.add('Level ${level.id}: two foods overlap at $pt.');
      }
      if (!level.isWalkable(f.col, f.row)) {
        errors.add('Level ${level.id}: food ${f.id} at $pt is inside a wall.');
      } else if (!MazePathfinder.isReachable(level, level.playerStart, pt)) {
        errors.add(
            'Level ${level.id}: food ${f.id} at $pt is unreachable from playerStart.');
      }
    }

    // Check health recovery pickups
    final healthIds = <String>{};
    for (final h in level.healthPickups) {
      if (!healthIds.add(h.id)) {
        errors.add('Level ${level.id}: duplicate health pickup ID ${h.id}.');
      }
      final pt = GridPoint(h.col, h.row);
      if (!level.isWalkable(h.col, h.row)) {
        errors.add(
            'Level ${level.id}: health pickup ${h.id} at $pt is inside a wall.');
      } else if (!MazePathfinder.isReachable(level, level.playerStart, pt)) {
        errors.add(
            'Level ${level.id}: health pickup ${h.id} at $pt is unreachable.');
      }
      if (foodCells.contains(pt)) {
        errors.add(
            'Level ${level.id}: health pickup ${h.id} overlaps food at $pt.');
      }
      if (pt == level.playerStart || pt == level.exitCell) {
        errors.add(
            'Level ${level.id}: health pickup ${h.id} overlaps start or exit.');
      }
    }

    // Check combat supply & shield pickups
    final combatIds = <String>{};
    for (final cp in level.combatPickups) {
      if (!combatIds.add(cp.id)) {
        errors.add('Level ${level.id}: duplicate combat pickup ID ${cp.id}.');
      }
      final pt = GridPoint(cp.col, cp.row);
      if (!level.isWalkable(cp.col, cp.row)) {
        errors.add(
            'Level ${level.id}: combat pickup ${cp.id} at $pt is inside a wall.');
      } else if (!MazePathfinder.isReachable(level, level.playerStart, pt)) {
        errors.add(
            'Level ${level.id}: combat pickup ${cp.id} at $pt is unreachable.');
      }
    }

    // Check monsters & patrol continuity
    final monsterIds = <String>{};
    for (final m in level.monsters) {
      if (!monsterIds.add(m.id)) {
        errors.add('Level ${level.id}: duplicate monster ID ${m.id}.');
      }
      if (!level.isWalkable(m.start.col, m.start.row)) {
        errors.add(
            'Level ${level.id}: monster ${m.id} start ${m.start} is inside a wall.');
      }
      if (m.start == level.playerStart) {
        errors.add(
            'Level ${level.id}: monster ${m.id} spawns directly on playerStart.');
      }
      if (m.start == level.exitCell) {
        errors.add(
            'Level ${level.id}: monster ${m.id} spawns directly on exitCell.');
      }
      for (int i = 0; i < m.patrolPath.length; i++) {
        final wp = m.patrolPath[i];
        if (!level.isWalkable(wp.col, wp.row)) {
          errors.add(
              'Level ${level.id}: monster ${m.id} waypoint $wp is inside a wall.');
        }
        if (i > 0) {
          final prev = m.patrolPath[i - 1];
          if (!MazePathfinder.isReachable(level, prev, wp)) {
            errors.add(
                'Level ${level.id}: monster ${m.id} patrol path disconnected between $prev and $wp.');
          }
        }
      }
    }

    // Estimate practical multi-trip tour steps respecting cargoCapacity
    int tourSteps = 0;
    if (errors.isEmpty) {
      tourSteps = _estimateCargoTourSteps(level);
    }

    final estimatedMinSec =
        level.playerSpeed > 0 ? (tourSteps / level.playerSpeed) : 999.0;

    // Ensure time limit gives fair breathing room (at least 1.35x optimal tour + 6s buffer)
    final requiredMinLimit = (estimatedMinSec * 1.35 + 6.0).ceil();
    if (level.timeLimitSeconds < requiredMinLimit) {
      errors.add(
          'Level ${level.id}: timeLimitSeconds (${level.timeLimitSeconds}s) is too tight for estimated route ($tourSteps steps, min ${requiredMinLimit}s).');
    }

    // Quota & star thresholds sanity checks
    if (level.minQuotaPercent <= 0 || level.minQuotaPercent > 100) {
      errors.add(
          'Level ${level.id}: invalid minQuotaPercent (${level.minQuotaPercent}).');
    }
    if (level.starThresholds.length != 3 ||
        level.starThresholds[0] > level.starThresholds[1] ||
        level.starThresholds[1] > level.starThresholds[2]) {
      errors.add(
          'Level ${level.id}: invalid starThresholds (${level.starThresholds}).');
    }

    return MazeValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      estimatedTourSteps: tourSteps,
      estimatedMinSeconds: estimatedMinSec,
    );
  }

  /// Greedy nearest-neighbor multi-trip tour estimator accounting for cargo capacity.
  static int _estimateCargoTourSteps(MazeLevel level) {
    final remaining = level.foods.map((f) => GridPoint(f.col, f.row)).toList();
    var current = level.playerStart;
    int carried = 0;
    int totalSteps = 0;

    while (remaining.isNotEmpty || carried > 0) {
      if (carried >= level.cargoCapacity || remaining.isEmpty) {
        final d = MazePathfinder.shortestSteps(level, current, level.exitCell);
        if (d < 0) return 9999;
        totalSteps += d;
        current = level.exitCell;
        carried = 0;
      } else {
        int bestIdx = 0;
        int bestDist = 999999;
        for (int i = 0; i < remaining.length; i++) {
          final d = MazePathfinder.shortestSteps(level, current, remaining[i]);
          if (d >= 0 && d < bestDist) {
            bestDist = d;
            bestIdx = i;
          }
        }
        totalSteps += bestDist;
        current = remaining.removeAt(bestIdx);
        carried++;
      }
    }
    return totalSteps;
  }
}

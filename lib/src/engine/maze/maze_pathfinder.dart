import 'dart:collection';
import '../../models/maze/maze_level.dart';
import '../../models/maze/monster.dart';

/// Deterministic grid-aware BFS pathfinder for monsters, tap-to-move, hints, and level validation.
class MazePathfinder {
  static const List<GridPoint> _cardinalDirs = [
    GridPoint(0, -1), // Up
    GridPoint(1, 0), // Right
    GridPoint(0, 1), // Down
    GridPoint(-1, 0), // Left
  ];

  /// Returns shortest walkable cell path from [start] to [goal] (inclusive),
  /// or an empty list if [goal] is unreachable.
  static List<GridPoint> findPath(
    MazeLevel level,
    GridPoint start,
    GridPoint goal, {
    Set<GridPoint>? avoidCells,
  }) {
    if (!level.isWalkable(start.col, start.row) ||
        !level.isWalkable(goal.col, goal.row)) {
      return const [];
    }
    if (start == goal) return [start];

    final queue = Queue<GridPoint>()..add(start);
    final cameFrom = <GridPoint, GridPoint?>{start: null};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == goal) {
        final path = <GridPoint>[];
        GridPoint? step = goal;
        while (step != null) {
          path.add(step);
          step = cameFrom[step];
        }
        return path.reversed.toList();
      }

      for (final d in _cardinalDirs) {
        final next = GridPoint(current.col + d.col, current.row + d.row);
        if (!level.isWalkable(next.col, next.row)) continue;
        if (cameFrom.containsKey(next)) continue;
        if (avoidCells != null && next != goal && avoidCells.contains(next)) {
          continue;
        }
        cameFrom[next] = current;
        queue.add(next);
      }
    }

    return const [];
  }

  /// Returns whether [goal] can be reached from [start] along walkable corridors.
  static bool isReachable(MazeLevel level, GridPoint start, GridPoint goal) {
    return findPath(level, start, goal).isNotEmpty;
  }

  /// Returns the shortest step count between [start] and [goal], or -1 if unreachable.
  static int shortestSteps(MazeLevel level, GridPoint start, GridPoint goal) {
    final path = findPath(level, start, goal);
    if (path.isEmpty) return -1;
    return path.length - 1;
  }

  /// Returns true if two points have unobstructed straight-line sight (no walls between them).
  static bool hasLineOfSight(
    MazeLevel level,
    double x1,
    double y1,
    double x2,
    double y2,
  ) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final dist = (dx * dx + dy * dy);
    if (dist < 0.0001) return true;
    final steps = ((dx.abs() + dy.abs()) * 4).ceil().clamp(2, 48);
    for (int i = 1; i < steps; i++) {
      final t = i / steps;
      final sx = (x1 + dx * t).floor();
      final sy = (y1 + dy * t).floor();
      if (level.isWall(sx, sy)) return false;
    }
    return true;
  }
}

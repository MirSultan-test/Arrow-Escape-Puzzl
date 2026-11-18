import 'dart:math' as math;

/// Represents the fixed exit direction of a parcel arrow on the rectangular grid.
enum Direction {
  up,
  down,
  left,
  right;

  /// Row coordinate change when advancing in this direction (row 0 is top).
  int get deltaRow {
    switch (this) {
      case Direction.up:
        return -1;
      case Direction.down:
        return 1;
      case Direction.left:
      case Direction.right:
        return 0;
    }
  }

  /// Column coordinate change when advancing in this direction (col 0 is left).
  int get deltaCol {
    switch (this) {
      case Direction.left:
        return -1;
      case Direction.right:
        return 1;
      case Direction.up:
      case Direction.down:
        return 0;
    }
  }

  /// Rotation in radians where 0 is pointing right (standard Cartesian rotation).
  double get angleRadians {
    switch (this) {
      case Direction.right:
        return 0.0;
      case Direction.down:
        return math.pi / 2.0;
      case Direction.left:
        return math.pi;
      case Direction.up:
        return -math.pi / 2.0;
    }
  }

  /// Rotates the direction exactly 90 degrees clockwise:
  /// UP -> RIGHT -> DOWN -> LEFT -> UP.
  Direction rotateClockwise90() {
    switch (this) {
      case Direction.up:
        return Direction.right;
      case Direction.right:
        return Direction.down;
      case Direction.down:
        return Direction.left;
      case Direction.left:
        return Direction.up;
    }
  }

  /// Stable string serialization key.
  String toKey() => name;

  /// Parse from string key, defaulting to up if unrecognized.
  static Direction fromKey(String key) {
    switch (key.trim().toLowerCase()) {
      case 'down':
        return Direction.down;
      case 'left':
        return Direction.left;
      case 'right':
        return Direction.right;
      case 'up':
      default:
        return Direction.up;
    }
  }
}

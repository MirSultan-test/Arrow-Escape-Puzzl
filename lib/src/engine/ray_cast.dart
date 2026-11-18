import '../models/direction.dart';
import '../models/parcel.dart';
import 'board_matrix.dart';

/// The evaluated result of projecting an exit ray from a parcel to the board edge.
class RayCastResult {
  /// Whether the exit ray is completely empty of other parcels all the way to the edge.
  final bool isClear;

  /// The first parcel obstructing the path, or null if clear.
  final Parcel? blockingParcel;

  /// Number of cells between this parcel and the board edge in the arrow direction.
  final int distanceToEdge;

  /// Number of cells between this parcel and the first blocker, or -1 if clear.
  final int distanceToBlocker;

  const RayCastResult({
    required this.isClear,
    required this.blockingParcel,
    required this.distanceToEdge,
    required this.distanceToBlocker,
  });

  @override
  String toString() => isClear
      ? 'RayCastResult(CLEAR, edgeDist: $distanceToEdge)'
      : 'RayCastResult(BLOCKED by ${blockingParcel?.id} at dist: $distanceToBlocker)';
}

/// Utility for performing deterministic discrete ray checks along the grid.
class RayCaster {
  const RayCaster();

  /// Casts an exit ray from [parcel] across [matrix] towards the board edge.
  /// Examines EVERY cell between [parcel] and the board edge in its arrow direction.
  static RayCastResult cast({
    required BoardMatrix matrix,
    required Parcel parcel,
  }) {
    final dir = parcel.direction;
    final dr = dir.deltaRow;
    final dc = dir.deltaCol;

    int edgeDistance;
    switch (dir) {
      case Direction.up:
        edgeDistance = parcel.row + 1;
        break;
      case Direction.down:
        edgeDistance = matrix.rows - parcel.row;
        break;
      case Direction.left:
        edgeDistance = parcel.col + 1;
        break;
      case Direction.right:
        edgeDistance = matrix.cols - parcel.col;
        break;
    }

    int currR = parcel.row + dr;
    int currC = parcel.col + dc;
    int step = 1;

    while (matrix.isInside(currR, currC)) {
      final occupant = matrix.getAt(currR, currC);
      if (occupant != null) {
        return RayCastResult(
          isClear: false,
          blockingParcel: occupant,
          distanceToEdge: edgeDistance,
          distanceToBlocker: step,
        );
      }
      currR += dr;
      currC += dc;
      step++;
    }

    return RayCastResult(
      isClear: true,
      blockingParcel: null,
      distanceToEdge: edgeDistance,
      distanceToBlocker: -1,
    );
  }
}

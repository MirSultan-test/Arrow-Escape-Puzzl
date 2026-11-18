import 'direction.dart';
import 'parcel.dart';

/// The specific phase of a Depot Challenge move.
enum GameMoveType {
  /// Parcel dispatched from Arrow Board into Sorting Rack.
  dispatchToRack,

  /// Parcel loaded from Sorting Rack into Delivery Truck.
  loadToTruck,
}

/// Represents a successfully executed puzzle action, enabling complete deterministic undo.
class GameMove {
  final Parcel parcel;
  final GameMoveType type;
  final int moveIndex;
  final int preMoveManifestIndex;
  final Map<String, Direction> preMoveGearOrientations;
  final int rackSlotIndex;
  final DateTime timestamp;

  GameMove({
    required this.parcel,
    this.type = GameMoveType.dispatchToRack,
    required this.moveIndex,
    this.preMoveManifestIndex = 0,
    Map<String, Direction>? preMoveGearOrientations,
    this.rackSlotIndex = 0,
    DateTime? timestamp,
  })  : preMoveGearOrientations = preMoveGearOrientations ?? const {},
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'parcel': parcel.toJson(),
        'type': type.name,
        'moveIndex': moveIndex,
        'preMoveManifestIndex': preMoveManifestIndex,
        'preMoveGearOrientations': preMoveGearOrientations.map(
          (k, v) => MapEntry(k, v.toKey()),
        ),
        'rackSlotIndex': rackSlotIndex,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GameMove.fromJson(Map<String, dynamic> json) {
    final rawGears =
        (json['preMoveGearOrientations'] as Map<String, dynamic>?) ?? {};
    final gearMap = rawGears.map(
      (k, v) => MapEntry(k, Direction.fromKey(v.toString())),
    );

    final rawType = json['type'] as String?;
    final type = rawType == 'loadToTruck'
        ? GameMoveType.loadToTruck
        : GameMoveType.dispatchToRack;

    return GameMove(
      parcel: Parcel.fromJson(json['parcel'] as Map<String, dynamic>),
      type: type,
      moveIndex: json['moveIndex'] as int,
      preMoveManifestIndex:
          (json['preMoveManifestIndex'] as num?)?.toInt() ?? 0,
      preMoveGearOrientations: gearMap,
      rackSlotIndex: (json['rackSlotIndex'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameMove &&
          runtimeType == other.runtimeType &&
          parcel == other.parcel &&
          type == other.type &&
          moveIndex == other.moveIndex &&
          preMoveManifestIndex == other.preMoveManifestIndex &&
          rackSlotIndex == other.rackSlotIndex;

  @override
  int get hashCode => Object.hash(parcel, type, moveIndex, preMoveManifestIndex, rackSlotIndex);
}

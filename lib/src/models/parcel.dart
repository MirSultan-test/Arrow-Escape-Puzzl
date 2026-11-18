import 'direction.dart';
import 'grid_position.dart';

/// Immutable model representing an arrow-marked parcel placed at a specific cell.
class Parcel {
  final String id;
  final int row;
  final int col;
  final Direction direction;
  final String colorType;
  final bool hasGear;
  final String? manifestSymbol;

  const Parcel({
    required this.id,
    required this.row,
    required this.col,
    required this.direction,
    this.colorType = 'standard',
    this.hasGear = false,
    this.manifestSymbol,
  });

  GridPosition get position => GridPosition(row, col);

  Parcel copyWith({
    String? id,
    int? row,
    int? col,
    Direction? direction,
    String? colorType,
    bool? hasGear,
    String? manifestSymbol,
    bool clearManifestSymbol = false,
  }) {
    return Parcel(
      id: id ?? this.id,
      row: row ?? this.row,
      col: col ?? this.col,
      direction: direction ?? this.direction,
      colorType: colorType ?? this.colorType,
      hasGear: hasGear ?? this.hasGear,
      manifestSymbol: clearManifestSymbol
          ? null
          : (manifestSymbol ?? this.manifestSymbol),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'row': row,
        'col': col,
        'direction': direction.toKey(),
        'colorType': colorType,
        if (hasGear) 'hasGear': true,
        if (manifestSymbol != null) 'manifestSymbol': manifestSymbol,
      };

  factory Parcel.fromJson(Map<String, dynamic> json) {
    return Parcel(
      id: json['id'] as String,
      row: json['row'] as int,
      col: json['col'] as int,
      direction: Direction.fromKey(json['direction'] as String? ?? 'up'),
      colorType: json['colorType'] as String? ?? 'standard',
      hasGear: json['hasGear'] as bool? ?? false,
      manifestSymbol: json['manifestSymbol'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Parcel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          row == other.row &&
          col == other.col &&
          direction == other.direction &&
          colorType == other.colorType &&
          hasGear == other.hasGear &&
          manifestSymbol == other.manifestSymbol;

  @override
  int get hashCode => Object.hash(
        id,
        row,
        col,
        direction,
        colorType,
        hasGear,
        manifestSymbol,
      );

  @override
  String toString() =>
      'Parcel(id: $id, pos: ($row, $col), dir: ${direction.name}, gear: $hasGear, manifest: $manifestSymbol)';
}

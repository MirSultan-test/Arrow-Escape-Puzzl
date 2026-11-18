/// Supported fresh food items transported through the maze.
enum FoodType {
  apple,
  banana,
  mango,
  strawberry,
  orange,
  watermelon,
  carrot,
  tomato;

  String get displayName {
    switch (this) {
      case FoodType.apple:
        return 'Apple';
      case FoodType.banana:
        return 'Banana';
      case FoodType.mango:
        return 'Mango';
      case FoodType.strawberry:
        return 'Strawberry';
      case FoodType.orange:
        return 'Orange';
      case FoodType.watermelon:
        return 'Watermelon';
      case FoodType.carrot:
        return 'Carrot';
      case FoodType.tomato:
        return 'Tomato';
    }
  }

  int get defaultBasePoints {
    switch (this) {
      case FoodType.apple:
        return 100;
      case FoodType.banana:
        return 100;
      case FoodType.mango:
        return 120;
      case FoodType.strawberry:
        return 110;
      case FoodType.orange:
        return 100;
      case FoodType.watermelon:
        return 150;
      case FoodType.carrot:
        return 90;
      case FoodType.tomato:
        return 100;
    }
  }

  int get primaryColorHex {
    switch (this) {
      case FoodType.apple:
        return 0xFFE63946;
      case FoodType.banana:
        return 0xFFFFD13B;
      case FoodType.mango:
        return 0xFFFF9F1C;
      case FoodType.strawberry:
        return 0xFFFF4D6D;
      case FoodType.orange:
        return 0xFFFF7B00;
      case FoodType.watermelon:
        return 0xFF2DC653;
      case FoodType.carrot:
        return 0xFFFF6D00;
      case FoodType.tomato:
        return 0xFFD62828;
    }
  }

  int get accentColorHex {
    switch (this) {
      case FoodType.apple:
        return 0xFF52B788;
      case FoodType.banana:
        return 0xFF8D5B2B;
      case FoodType.mango:
        return 0xFFFF595E;
      case FoodType.strawberry:
        return 0xFF40916C;
      case FoodType.orange:
        return 0xFF5DBB75;
      case FoodType.watermelon:
        return 0xFFFF4D6D;
      case FoodType.carrot:
        return 0xFF52B788;
      case FoodType.tomato:
        return 0xFF40916C;
    }
  }

  static FoodType fromName(String raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return FoodType.apple;
  }
}

/// Lifecycle state of an individual food item.
/// An item can strictly exist in only ONE of these states at any moment.
enum FoodStatus {
  onMap,
  carried,
  delivered,
  consumed,
}

/// Immutable level spawn definition for a food item.
class FoodSpawn {
  final String id;
  final FoodType type;
  final int col;
  final int row;
  final int maxQuantity;
  final int basePoints;

  const FoodSpawn({
    required this.id,
    required this.type,
    required this.col,
    required this.row,
    this.maxQuantity = 100,
    int? basePoints,
  }) : basePoints = basePoints ?? 0;

  int get effectiveBasePoints =>
      basePoints > 0 ? basePoints : type.defaultBasePoints;

  FoodItem createRuntimeItem() {
    return FoodItem(
      id: id,
      type: type,
      spawnCol: col,
      spawnRow: row,
      maxQuantity: maxQuantity,
      remainingQuantity: maxQuantity,
      basePoints: effectiveBasePoints,
      status: FoodStatus.onMap,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'col': col,
        'row': row,
        'maxQuantity': maxQuantity,
        'basePoints': effectiveBasePoints,
      };

  factory FoodSpawn.fromJson(Map<String, dynamic> json) {
    final type = FoodType.fromName(json['type'] as String? ?? 'apple');
    return FoodSpawn(
      id: json['id'] as String? ?? 'f0',
      type: type,
      col: (json['col'] as num).toInt(),
      row: (json['row'] as num).toInt(),
      maxQuantity: (json['maxQuantity'] as num?)?.toInt() ?? 100,
      basePoints:
          (json['basePoints'] as num?)?.toInt() ?? type.defaultBasePoints,
    );
  }
}

/// Runtime food item retaining identity, remaining edible percentage, and status.
class FoodItem {
  final String id;
  final FoodType type;
  final int spawnCol;
  final int spawnRow;
  final int maxQuantity;
  int remainingQuantity;
  final int basePoints;
  FoodStatus status;

  FoodItem({
    required this.id,
    required this.type,
    required this.spawnCol,
    required this.spawnRow,
    this.maxQuantity = 100,
    int? remainingQuantity,
    int? basePoints,
    this.status = FoodStatus.onMap,
  })  : remainingQuantity =
            (remainingQuantity ?? maxQuantity).clamp(0, maxQuantity),
        basePoints = basePoints ?? type.defaultBasePoints;

  /// Remaining condition percentage in [0, 100].
  int get conditionPercent {
    if (maxQuantity <= 0) return 0;
    return ((remainingQuantity * 100) / maxQuantity).round().clamp(0, 100);
  }

  /// Percentage eaten by monsters in [0, 100].
  int get eatenPercent => (100 - conditionPercent).clamp(0, 100);

  /// Points earned for this item if delivered.
  /// Formula: Base Food Points * Remaining Food Percentage / 100.
  int get earnedPoints {
    if (status != FoodStatus.delivered || remainingQuantity <= 0) return 0;
    return (basePoints * conditionPercent / 100).round();
  }

  /// Applies bite damage. Returns the actual quantity consumed.
  int applyBite(int damageAmount) {
    if (damageAmount <= 0 || remainingQuantity <= 0) return 0;
    final actual =
        damageAmount > remainingQuantity ? remainingQuantity : damageAmount;
    remainingQuantity -= actual;
    if (remainingQuantity <= 0) {
      remainingQuantity = 0;
      status = FoodStatus.consumed;
    }
    return actual;
  }

  FoodItem clone() => FoodItem(
        id: id,
        type: type,
        spawnCol: spawnCol,
        spawnRow: spawnRow,
        maxQuantity: maxQuantity,
        remainingQuantity: remainingQuantity,
        basePoints: basePoints,
        status: status,
      );
}

import 'combat_models.dart';
import 'food_item.dart';
import 'monster.dart';
import 'truck_defense_models.dart';

/// Immutable spawn location for a collectible health-recovery heart inside a maze.
class HealthPickupSpawn {
  final String id;
  final int col;
  final int row;

  const HealthPickupSpawn({
    required this.id,
    required this.col,
    required this.row,
  });

  HealthPickupItem createRuntimeItem() => HealthPickupItem(
        id: id,
        col: col,
        row: row,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'col': col,
        'row': row,
      };

  factory HealthPickupSpawn.fromJson(Map<String, dynamic> json) =>
      HealthPickupSpawn(
        id: json['id'] as String? ?? 'hp0',
        col: (json['col'] as num).toInt(),
        row: (json['row'] as num).toInt(),
      );
}

/// Live runtime collectible health heart inside MazeGameEngine.
class HealthPickupItem {
  final String id;
  final int col;
  final int row;
  bool collected;

  HealthPickupItem({
    required this.id,
    required this.col,
    required this.row,
    this.collected = false,
  });
}

/// Biome visual palette (pure Dart ARGB hex values) for each of the 5 campaign districts.
class MazeDistrictInfo {
  final int id;
  final String name;
  final String subtitle;
  final int startLevel;
  final int endLevel;
  final int floorLightHex;
  final int floorDarkHex;
  final int wallTopHex;
  final int wallSideHex;
  final int wallTrimHex;
  final int accentHex;
  final int skyBgHex;

  const MazeDistrictInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.startLevel,
    required this.endLevel,
    required this.floorLightHex,
    required this.floorDarkHex,
    required this.wallTopHex,
    required this.wallSideHex,
    required this.wallTrimHex,
    required this.accentHex,
    required this.skyBgHex,
  });

  static const List<MazeDistrictInfo> all = [
    MazeDistrictInfo(
      id: 1,
      name: 'Sunny Orchard',
      subtitle: 'Fresh fruit groves & gentle hedges',
      startLevel: 1,
      endLevel: 10,
      floorLightHex: 0xFFFFF5DF,
      floorDarkHex: 0xFFF6E6C6,
      wallTopHex: 0xFF5DBB75,
      wallSideHex: 0xFF3E8E53,
      wallTrimHex: 0xFF83D496,
      accentHex: 0xFFFF715B,
      skyBgHex: 0xFFFFF7E8,
    ),
    MazeDistrictInfo(
      id: 2,
      name: 'Garden Market',
      subtitle: 'Cobblestone stalls & busy lanes',
      startLevel: 11,
      endLevel: 20,
      floorLightHex: 0xFFFAF1E4,
      floorDarkHex: 0xFFEEE0CC,
      wallTopHex: 0xFFE08D55,
      wallSideHex: 0xFFAD5E2E,
      wallTrimHex: 0xFFF4B382,
      accentHex: 0xFFFFC857,
      skyBgHex: 0xFFFFF6EA,
    ),
    MazeDistrictInfo(
      id: 3,
      name: 'Forest Food Trail',
      subtitle: 'Mossy paths & prowling hunters',
      startLevel: 21,
      endLevel: 30,
      floorLightHex: 0xFFEFF6EA,
      floorDarkHex: 0xFFDFECDA,
      wallTopHex: 0xFF3E7C59,
      wallSideHex: 0xFF26523A,
      wallTrimHex: 0xFF67A882,
      accentHex: 0xFF26A69A,
      skyBgHex: 0xFFF2F8F0,
    ),
    MazeDistrictInfo(
      id: 4,
      name: 'Monster Valley',
      subtitle: 'Twilight cliffs & speedy imps',
      startLevel: 31,
      endLevel: 40,
      floorLightHex: 0xFFF4EFF8,
      floorDarkHex: 0xFFE6DCF0,
      wallTopHex: 0xFF7B5EA7,
      wallSideHex: 0xFF523B78,
      wallTrimHex: 0xFFA287CC,
      accentHex: 0xFFFF715B,
      skyBgHex: 0xFFF7F2FA,
    ),
    MazeDistrictInfo(
      id: 5,
      name: 'Grand Delivery City',
      subtitle: 'Bustling avenues & master routes',
      startLevel: 41,
      endLevel: 50,
      floorLightHex: 0xFFF0F5FA,
      floorDarkHex: 0xFFE0EAF3,
      wallTopHex: 0xFF3D5A80,
      wallSideHex: 0xFF243447,
      wallTrimHex: 0xFF6B8FB8,
      accentHex: 0xFF80CFF2,
      skyBgHex: 0xFFF2F7FC,
    ),
  ];

  static MazeDistrictInfo forDistrict(int districtId) {
    return all.firstWhere(
      (d) => d.id == districtId,
      orElse: () => all.first,
    );
  }

  static MazeDistrictInfo forLevel(int levelId) {
    final idx = ((levelId - 1) ~/ 10).clamp(0, all.length - 1);
    return all[idx];
  }
}

/// Complete immutable definition of a playable Food Maze Adventure level.
class MazeLevel {
  final int id;
  final int district;
  final String title;
  final String subtitle;
  final String? tutorialTip;
  final int cols;
  final int rows;

  /// ASCII grid of length [rows], each string length [cols]:
  /// '#' = solid wall
  /// '.' = walkable corridor
  /// 'E' = delivery exit doorway connected to the right-side dock
  final List<String> grid;
  final GridPoint playerStart;
  final GridPoint exitCell;
  final int cargoCapacity;
  final int timeLimitSeconds;
  final int minQuotaPercent;
  final List<int> starThresholds; // [1-star, 2-star, 3-star]
  final int difficulty; // 1..5
  final double playerSpeed;
  final List<FoodSpawn> foods;
  final List<MonsterDefinition> monsters;
  final List<HealthPickupSpawn> healthPickups;
  final List<CombatPickupSpawn> combatPickups;

  const MazeLevel({
    required this.id,
    required this.district,
    required this.title,
    required this.subtitle,
    this.tutorialTip,
    required this.cols,
    required this.rows,
    required this.grid,
    required this.playerStart,
    required this.exitCell,
    this.cargoCapacity = 2,
    required this.timeLimitSeconds,
    this.minQuotaPercent = 60,
    required this.starThresholds,
    this.difficulty = 1,
    this.playerSpeed = 3.65,
    required this.foods,
    required this.monsters,
    this.healthPickups = const [],
    this.combatPickups = const [],
  });

  MazeDistrictInfo get districtInfo => MazeDistrictInfo.forDistrict(district);

  /// V3.3 per-level Truck Defense boss, cage, winding road & destination config.
  TruckDefenseConfig get truckDefenseConfig => TruckDefenseConfig.forLevel(
        levelId: id,
        districtId: district,
      );

  bool inBounds(int col, int row) =>
      col >= 0 && col < cols && row >= 0 && row < rows;

  bool isWall(int col, int row) {
    if (!inBounds(col, row)) return true;
    return grid[row][col] == '#';
  }

  bool isWalkable(int col, int row) => !isWall(col, row);

  int get totalOriginalFoodQuantity =>
      foods.fold<int>(0, (sum, f) => sum + f.maxQuantity);

  int get maxPossibleFoodScore =>
      foods.fold<int>(0, (sum, f) => sum + f.effectiveBasePoints);

  Map<String, dynamic> toJson() => {
        'id': id,
        'district': district,
        'title': title,
        'subtitle': subtitle,
        if (tutorialTip != null) 'tutorialTip': tutorialTip,
        'cols': cols,
        'rows': rows,
        'grid': grid,
        'playerStart': playerStart.toJson(),
        'exitCell': exitCell.toJson(),
        'cargoCapacity': cargoCapacity,
        'timeLimitSeconds': timeLimitSeconds,
        'minQuotaPercent': minQuotaPercent,
        'starThresholds': starThresholds,
        'difficulty': difficulty,
        'playerSpeed': playerSpeed,
        'foods': foods.map((f) => f.toJson()).toList(),
        'monsters': monsters.map((m) => m.toJson()).toList(),
        if (healthPickups.isNotEmpty)
          'healthPickups': healthPickups.map((h) => h.toJson()).toList(),
        if (combatPickups.isNotEmpty)
          'combatPickups': combatPickups.map((c) => c.toJson()).toList(),
      };

  factory MazeLevel.fromJson(Map<String, dynamic> json) {
    final gridList = (json['grid'] as List<dynamic>)
        .map((e) => e.toString())
        .toList();
    final rows = (json['rows'] as num?)?.toInt() ?? gridList.length;
    final cols = (json['cols'] as num?)?.toInt() ??
        (gridList.isNotEmpty ? gridList.first.length : 0);
    return MazeLevel(
      id: (json['id'] as num).toInt(),
      district: (json['district'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? 'Orchard Run',
      subtitle: json['subtitle'] as String? ?? 'Deliver the fresh harvest',
      tutorialTip: json['tutorialTip'] as String?,
      cols: cols,
      rows: rows,
      grid: gridList,
      playerStart:
          GridPoint.fromJson(json['playerStart'] as Map<String, dynamic>),
      exitCell: GridPoint.fromJson(json['exitCell'] as Map<String, dynamic>),
      cargoCapacity: (json['cargoCapacity'] as num?)?.toInt() ?? 2,
      timeLimitSeconds: (json['timeLimitSeconds'] as num).toInt(),
      minQuotaPercent: (json['minQuotaPercent'] as num?)?.toInt() ?? 60,
      starThresholds: (json['starThresholds'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [100, 220, 320],
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      playerSpeed: (json['playerSpeed'] as num?)?.toDouble() ?? 3.65,
      foods: (json['foods'] as List<dynamic>)
          .map((e) => FoodSpawn.fromJson(e as Map<String, dynamic>))
          .toList(),
      monsters: (json['monsters'] as List<dynamic>? ?? const [])
          .map((e) => MonsterDefinition.fromJson(e as Map<String, dynamic>))
          .toList(),
      healthPickups: (json['healthPickups'] as List<dynamic>? ?? const [])
          .map((e) => HealthPickupSpawn.fromJson(e as Map<String, dynamic>))
          .toList(),
      combatPickups: (json['combatPickups'] as List<dynamic>? ?? const [])
          .map((e) => CombatPickupSpawn.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

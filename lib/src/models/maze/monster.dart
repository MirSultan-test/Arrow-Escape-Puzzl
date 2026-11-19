import 'dart:math' as math;
import 'monster_variants.dart';

/// Integer cell coordinate inside a maze grid (col = x, row = y).
class GridPoint {
  final int col;
  final int row;

  const GridPoint(this.col, this.row);

  double get centerX => col + 0.5;
  double get centerY => row + 0.5;

  int manhattanTo(GridPoint other) =>
      (col - other.col).abs() + (row - other.row).abs();

  double distanceTo(GridPoint other) {
    final dx = (col - other.col).toDouble();
    final dy = (row - other.row).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  Map<String, dynamic> toJson() => {'col': col, 'row': row};

  factory GridPoint.fromJson(Map<String, dynamic> json) => GridPoint(
        (json['col'] as num).toInt(),
        (json['row'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPoint && col == other.col && row == other.row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => '($col,$row)';
}

/// Six distinct spooky fantasy-cartoon monster archetypes with unique silhouettes,
/// health pools, combat behaviors, and tactical weaknesses (Section 2 & 3).
enum MonsterType {
  /// Monster 1 — Red Hunter: Fast crimson pursuer, stunned briefly by arrows.
  redHunter,

  /// Monster 2 — Shadow Crawler: Dark purple/black ambusher, vulnerable to light Blaster.
  shadowCrawler,

  /// Monster 3 — Giant Forest Brute: High HP moss-covered brute, slow telegraphed heavy strikes.
  forestBrute,

  /// Monster 4 — Flying Night Creature: Fast winged bat-imp, low HP, respects walls.
  flyingCreature,

  /// Monster 5 — Poison Mushroom Beast: Guards zones, telegraphed slowing poison cloud.
  mushroomBeast,

  /// Monster 6 — Maze Guardian (Mini Boss): Armored horned boss with multi-pattern attacks.
  mazeGuardian;

  // Backward-compatible aliases so existing references compile cleanly
  static const MonsterType hunter = MonsterType.redHunter;
  static const MonsterType patrol = MonsterType.shadowCrawler;
  static const MonsterType guardian = MonsterType.forestBrute;
  static const MonsterType fast = MonsterType.flyingCreature;

  String get displayName {
    switch (this) {
      case MonsterType.redHunter:
        return 'Red Hunter';
      case MonsterType.shadowCrawler:
        return 'Shadow Crawler';
      case MonsterType.forestBrute:
        return 'Forest Brute';
      case MonsterType.flyingCreature:
        return 'Night Wing';
      case MonsterType.mushroomBeast:
        return 'Spore Beast';
      case MonsterType.mazeGuardian:
        return 'Maze Guardian';
    }
  }

  int get defaultMaxHp {
    switch (this) {
      case MonsterType.redHunter:
        return 60;
      case MonsterType.shadowCrawler:
        return 80;
      case MonsterType.forestBrute:
        return 160;
      case MonsterType.flyingCreature:
        return 40;
      case MonsterType.mushroomBeast:
        return 100;
      case MonsterType.mazeGuardian:
        return 300;
    }
  }

  double get defaultSpeed {
    switch (this) {
      case MonsterType.redHunter:
        return 2.30;
      case MonsterType.shadowCrawler:
        return 1.85;
      case MonsterType.forestBrute:
        return 1.32;
      case MonsterType.flyingCreature:
        return 2.75;
      case MonsterType.mushroomBeast:
        return 1.25;
      case MonsterType.mazeGuardian:
        return 1.70;
    }
  }

  double get defaultDetectionRange {
    switch (this) {
      case MonsterType.redHunter:
        return 3.9;
      case MonsterType.shadowCrawler:
        return 3.1;
      case MonsterType.forestBrute:
        return 2.7;
      case MonsterType.flyingCreature:
        return 3.2;
      case MonsterType.mushroomBeast:
        return 3.4;
      case MonsterType.mazeGuardian:
        return 4.3;
    }
  }

  int get defaultBiteDamage {
    switch (this) {
      case MonsterType.redHunter:
        return 30;
      case MonsterType.shadowCrawler:
        return 25;
      case MonsterType.forestBrute:
        return 45;
      case MonsterType.flyingCreature:
        return 18;
      case MonsterType.mushroomBeast:
        return 25;
      case MonsterType.mazeGuardian:
        return 40;
    }
  }

  double get defaultStunResistance {
    switch (this) {
      case MonsterType.redHunter:
        return 0.0;
      case MonsterType.shadowCrawler:
        return 0.15;
      case MonsterType.forestBrute:
        return 0.45;
      case MonsterType.flyingCreature:
        return 0.0;
      case MonsterType.mushroomBeast:
        return 0.25;
      case MonsterType.mazeGuardian:
        return 0.55;
    }
  }

  double get defaultRecoverDuration {
    switch (this) {
      case MonsterType.redHunter:
        return 0.95;
      case MonsterType.shadowCrawler:
        return 0.90;
      case MonsterType.forestBrute:
        return 1.35;
      case MonsterType.flyingCreature:
        return 1.45; // Clear weakness: tires after swoop
      case MonsterType.mushroomBeast:
        return 1.25;
      case MonsterType.mazeGuardian:
        return 1.30;
    }
  }

  double get visualScale {
    switch (this) {
      case MonsterType.forestBrute:
        return 1.24;
      case MonsterType.mazeGuardian:
        return 1.38;
      case MonsterType.flyingCreature:
        return 0.96;
      default:
        return 1.06;
    }
  }

  static MonsterType fromName(String raw) {
    switch (raw) {
      case 'redHunter':
      case 'hunter':
        return MonsterType.redHunter;
      case 'shadowCrawler':
      case 'patrol':
        return MonsterType.shadowCrawler;
      case 'forestBrute':
      case 'guardian':
        return MonsterType.forestBrute;
      case 'flyingCreature':
      case 'fast':
        return MonsterType.flyingCreature;
      case 'mushroomBeast':
        return MonsterType.mushroomBeast;
      case 'mazeGuardian':
        return MonsterType.mazeGuardian;
      default:
        return MonsterType.shadowCrawler;
    }
  }
}

/// Complete deterministic combat & navigation AI states (Section 8).
enum MonsterAiState {
  idle,
  patrol,
  detect,
  chase,
  windup,
  attack,
  stunned,
  recover,
  defeated,
}

/// Immutable monster spawn configuration in level JSON.
class MonsterDefinition {
  final String id;
  final MonsterType type;
  final GridPoint start;
  final List<GridPoint> patrolPath;
  final int? maxHp;
  final double? speed;
  final double? detectionRange;
  final int? biteDamage;
  final double? stunResistance;
  final double alertDuration;
  final double? recoverDuration;
  final bool respawns;

  // V3.5 Data-Driven Per-Level Appearance & 10-Profile Movement System
  final String? appearanceId;
  final MonsterMovementProfile? movementProfile;

  const MonsterDefinition({
    required this.id,
    required this.type,
    required this.start,
    this.patrolPath = const [],
    this.maxHp,
    this.speed,
    this.detectionRange,
    this.biteDamage,
    this.stunResistance,
    this.alertDuration = 0.36,
    this.recoverDuration,
    this.respawns = false,
    this.appearanceId,
    this.movementProfile,
  });

  int get effectiveMaxHp => maxHp ?? type.defaultMaxHp;
  double get effectiveSpeed => speed ?? type.defaultSpeed;
  double get effectiveDetectionRange =>
      detectionRange ?? type.defaultDetectionRange;
  int get effectiveBiteDamage => biteDamage ?? type.defaultBiteDamage;
  double get effectiveStunResistance =>
      stunResistance ?? type.defaultStunResistance;
  double get effectiveRecoverDuration =>
      recoverDuration ?? type.defaultRecoverDuration;
  MonsterMovementProfile get effectiveMovementProfile =>
      movementProfile ?? MonsterMovementProfile.fromName(null, type);

  MonsterEntity createRuntimeEntity({int levelId = 1, int slotIndex = 0}) {
    final path =
        patrolPath.isNotEmpty ? List<GridPoint>.from(patrolPath) : [start];
    final profile = effectiveMovementProfile;
    final spec = MonsterAppearanceSpec.forLevelSlot(
      levelId: levelId,
      slotIndex: slotIndex,
      type: type,
      movement: profile,
      explicitAppearanceId: appearanceId,
    );
    return MonsterEntity(
      id: id,
      type: type,
      x: start.centerX,
      y: start.centerY,
      home: start,
      patrolPath: path,
      maxHp: effectiveMaxHp,
      hp: effectiveMaxHp,
      speed: effectiveSpeed,
      detectionRange: effectiveDetectionRange,
      biteDamage: effectiveBiteDamage,
      stunResistance: effectiveStunResistance,
      alertDuration: alertDuration,
      recoverDuration: effectiveRecoverDuration,
      respawns: respawns,
      movementProfile: profile,
      appearance: spec,
      state: profile == MonsterMovementProfile.ambushMonster
          ? MonsterAiState.idle
          : (path.length > 1 ? MonsterAiState.patrol : MonsterAiState.idle),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'start': start.toJson(),
        'patrolPath': patrolPath.map((p) => p.toJson()).toList(),
        if (maxHp != null) 'maxHp': maxHp,
        if (speed != null) 'speed': speed,
        if (detectionRange != null) 'detectionRange': detectionRange,
        if (biteDamage != null) 'biteDamage': biteDamage,
        if (stunResistance != null) 'stunResistance': stunResistance,
        'alertDuration': alertDuration,
        if (recoverDuration != null) 'recoverDuration': recoverDuration,
        if (respawns) 'respawns': respawns,
        if (appearanceId != null) 'appearanceId': appearanceId,
        if (movementProfile != null) 'movementProfile': movementProfile!.name,
      };

  factory MonsterDefinition.fromJson(Map<String, dynamic> json) {
    final type = MonsterType.fromName(json['type'] as String? ?? 'shadowCrawler');
    final start = GridPoint.fromJson(json['start'] as Map<String, dynamic>);
    final rawPath = (json['patrolPath'] as List<dynamic>?)
            ?.map((e) => GridPoint.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [start];
    final rawMove = json['movementProfile'] as String?;
    return MonsterDefinition(
      id: json['id'] as String? ?? 'm0',
      type: type,
      start: start,
      patrolPath: rawPath,
      maxHp: (json['maxHp'] as num?)?.toInt(),
      speed: (json['speed'] as num?)?.toDouble(),
      detectionRange: (json['detectionRange'] as num?)?.toDouble(),
      biteDamage: (json['biteDamage'] as num?)?.toInt(),
      stunResistance: (json['stunResistance'] as num?)?.toDouble(),
      alertDuration: (json['alertDuration'] as num?)?.toDouble() ?? 0.36,
      recoverDuration: (json['recoverDuration'] as num?)?.toDouble(),
      respawns: json['respawns'] as bool? ?? false,
      appearanceId: json['appearanceId'] as String?,
      movementProfile: rawMove != null
          ? MonsterMovementProfile.fromName(rawMove, type)
          : null,
    );
  }
}

/// Live runtime monster entity with health, stun, freeze, knockback, and telegraph states.
class MonsterEntity {
  final String id;
  final MonsterType type;
  final GridPoint home;
  final List<GridPoint> patrolPath;
  final int maxHp;
  int hp;
  final double speed;
  final double detectionRange;
  final int biteDamage;
  final double stunResistance;
  final double alertDuration;
  final double recoverDuration;
  final bool respawns;
  final MonsterMovementProfile movementProfile;
  final MonsterAppearanceSpec appearance;

  double x;
  double y;
  double facingAngle;
  MonsterAiState state;
  double stateTimer;
  int patrolIndex;
  bool patrolForward;
  List<GridPoint> activeNavPath;
  double repathTimer;
  double attackCooldown;
  double specialCooldown;
  double animPhase;
  double biteAnimTimer;

  // V3.5 Movement-Specific Animation & Behavior Timers
  double hopPhase; // 0..pi during active hop arc for jumpingCreature
  double hopCooldown;
  double zigzagPhase; // lateral weaving phase for zigzagMonster
  double chargeVx;
  double chargeVy;
  double chargeActiveTimer;
  bool ambushCrouched;
  bool isMoving;

  // Combat feedback timers
  double stunTimer;
  double freezeTimer;
  double hitFlashTimer;
  double hpBarTimer;
  double defeatAnimTimer;
  double knockbackVx;
  double knockbackVy;
  int bossPatternIndex;

  MonsterEntity({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.home,
    required this.patrolPath,
    required this.maxHp,
    required this.hp,
    required this.speed,
    required this.detectionRange,
    required this.biteDamage,
    required this.stunResistance,
    required this.alertDuration,
    required this.recoverDuration,
    this.respawns = false,
    MonsterMovementProfile? movementProfile,
    MonsterAppearanceSpec? appearance,
    this.facingAngle = 0.0,
    this.state = MonsterAiState.patrol,
    this.stateTimer = 0.0,
    this.patrolIndex = 0,
    this.patrolForward = true,
    List<GridPoint>? activeNavPath,
    this.repathTimer = 0.0,
    this.attackCooldown = 0.0,
    this.specialCooldown = 2.0,
    this.animPhase = 0.0,
    this.biteAnimTimer = 0.0,
    this.hopPhase = 0.0,
    this.hopCooldown = 0.0,
    this.zigzagPhase = 0.0,
    this.chargeVx = 0.0,
    this.chargeVy = 0.0,
    this.chargeActiveTimer = 0.0,
    this.ambushCrouched = false,
    this.isMoving = false,
    this.stunTimer = 0.0,
    this.freezeTimer = 0.0,
    this.hitFlashTimer = 0.0,
    this.hpBarTimer = 0.0,
    this.defeatAnimTimer = 0.0,
    this.knockbackVx = 0.0,
    this.knockbackVy = 0.0,
    this.bossPatternIndex = 0,
  })  : movementProfile =
            movementProfile ?? MonsterMovementProfile.fromName(null, type),
        appearance = appearance ??
            MonsterAppearanceSpec.forLevelSlot(
              levelId: 1,
              slotIndex: 0,
              type: type,
              movement:
                  movementProfile ?? MonsterMovementProfile.fromName(null, type),
            ),
        activeNavPath = activeNavPath ?? [];

  bool get isDefeated => state == MonsterAiState.defeated || hp <= 0;
  bool get isFrozen => freezeTimer > 0.0;
  bool get isStunned => state == MonsterAiState.stunned || stunTimer > 0.0;
  double get hpRatio => maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;

  GridPoint get currentCell => GridPoint(x.floor(), y.floor());
}

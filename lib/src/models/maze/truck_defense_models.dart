import 'dart:math' as math;

/// Logical portrait arena dimensions for the dedicated Full-Screen Road Battle Arena.
/// Chosen at a 10:14 aspect ratio so curves are spacious and readable on every phone size.
class RoadArenaBounds {
  static const double width = 10.0;
  static const double height = 14.0;
  static const double playableMarginX = 0.55;
  static const double playableMarginTop = 0.85;
  static const double playableMarginBottom = 0.75;
}

/// 5 visually distinct giant District Bosses (Section 9).
enum DistrictBossType {
  orchardThornBeast, // District 1: Sunny Orchard (Giant Thorn Creature)
  marketArmoredBrute, // District 2: Garden Market (Armored Food-Hunting Monster)
  forestShadowBeast, // District 3: Forest Food Trail (Dark Forest Beast)
  valleyHornedTitan, // District 4: Monster Valley (Heavy Horned Monster)
  cityGrandGuardian; // District 5: Grand Delivery City (Powerful Final Guardian)

  String get displayName {
    switch (this) {
      case DistrictBossType.orchardThornBeast:
        return 'Thorn Ravager';
      case DistrictBossType.marketArmoredBrute:
        return 'Iron Market Brute';
      case DistrictBossType.forestShadowBeast:
        return 'Dread Forest Beast';
      case DistrictBossType.valleyHornedTitan:
        return 'Horned Valley Titan';
      case DistrictBossType.cityGrandGuardian:
        return 'Grand City Guardian';
    }
  }

  int get primaryColorHex {
    switch (this) {
      case DistrictBossType.orchardThornBeast:
        return 0xFF2D5A27;
      case DistrictBossType.marketArmoredBrute:
        return 0xFF6B3A2A;
      case DistrictBossType.forestShadowBeast:
        return 0xFF1B3B2B;
      case DistrictBossType.valleyHornedTitan:
        return 0xFF3A1C54;
      case DistrictBossType.cityGrandGuardian:
        return 0xFF1F2A44;
    }
  }

  int get accentColorHex {
    switch (this) {
      case DistrictBossType.orchardThornBeast:
        return 0xFFFF595E;
      case DistrictBossType.marketArmoredBrute:
        return 0xFFFF9F1C;
      case DistrictBossType.forestShadowBeast:
        return 0xFF84CC16;
      case DistrictBossType.valleyHornedTitan:
        return 0xFFD946EF;
      case DistrictBossType.cityGrandGuardian:
        return 0xFFFFC857;
    }
  }

  static DistrictBossType forDistrict(int districtId) {
    switch (districtId) {
      case 1:
        return DistrictBossType.orchardThornBeast;
      case 2:
        return DistrictBossType.marketArmoredBrute;
      case 3:
        return DistrictBossType.forestShadowBeast;
      case 4:
        return DistrictBossType.valleyHornedTitan;
      default:
        return DistrictBossType.cityGrandGuardian;
    }
  }
}

/// 5 distinct telegraphed Boss Attack Patterns against the moving delivery truck (Section 7).
enum BossAttackType {
  bombProjectile, // Attack 1: Fantasy Bomb Projectile with impact circle
  tireAttack, // Attack 2: Tire Lunge that flashes tire & slows truck
  directCharge, // Attack 3: Direct high-speed charge (interruptible!)
  groundSlam, // Attack 4: Heavy ground slam danger zone on the road
  specialAbility; // Attack 5: Slow cloud / multi-orb / shockwave / minion / shield

  String get telegraphLabel {
    switch (this) {
      case BossAttackType.bombProjectile:
        return 'BOMB!';
      case BossAttackType.tireAttack:
        return 'TIRE LUNGE!';
      case BossAttackType.directCharge:
        return 'CHARGE!';
      case BossAttackType.groundSlam:
        return 'SLAM!';
      case BossAttackType.specialAbility:
        return 'SPECIAL!';
    }
  }
}

/// Destination building visual archetype at the end of the winding delivery road.
enum DestinationBuildingType {
  orchardBarn,
  marketStorage,
  forestDepot,
  valleyOutpost,
  cityDistributionCenter;

  String get label {
    switch (this) {
      case DestinationBuildingType.orchardBarn:
        return 'ORCHARD BARN';
      case DestinationBuildingType.marketStorage:
        return 'MARKET DEPOT';
      case DestinationBuildingType.forestDepot:
        return 'FOREST STATION';
      case DestinationBuildingType.valleyOutpost:
        return 'VALLEY HUB';
      case DestinationBuildingType.cityDistributionCenter:
        return 'GRAND CENTER';
    }
  }

  static DestinationBuildingType forDistrict(int districtId) {
    switch (districtId) {
      case 1:
        return DestinationBuildingType.orchardBarn;
      case 2:
        return DestinationBuildingType.marketStorage;
      case 3:
        return DestinationBuildingType.forestDepot;
      case 4:
        return DestinationBuildingType.valleyOutpost;
      default:
        return DestinationBuildingType.cityDistributionCenter;
    }
  }
}

/// Containment cage lifecycle state.
enum BossCageState {
  locked,
  rattling,
  lockBreaking,
  doorOpening,
  escaped,
}

/// Delivery vehicle health condition states (Section 8).
enum TruckDamageState {
  healthy,
  damaged,
  critical,
  destroyed,
}

/// 2D point in road arena world space.
class RoadPoint {
  final double x;
  final double y;

  const RoadPoint(this.x, this.y);

  double distanceTo(RoadPoint other) {
    final dx = other.x - x;
    final dy = other.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Sampled point + tangent angle along a smooth arc-length parameterized road curve.
class RoadSample {
  final double x;
  final double y;
  final double angle; // Radians along travel direction

  const RoadSample({
    required this.x,
    required this.y,
    required this.angle,
  });
}

/// Scenery decoration along the roadside (trees, market stalls, crates, rocks, flowers, lamps).
enum RoadPropKind {
  tree,
  bush,
  marketStall,
  crateStack,
  rock,
  lampPost,
  flowerPatch,
}

class RoadSceneryProp {
  final RoadPropKind kind;
  final double x;
  final double y;
  final double scale;

  const RoadSceneryProp({
    required this.kind,
    required this.x,
    required this.y,
    this.scale = 1.0,
  });
}

/// Smooth Catmull-Rom winding delivery road with exact arc-length parameterization.
class RoadPathDefinition {
  final String routeId;
  final List<RoadPoint> controlPoints;
  final List<RoadPoint> sampledPoints;
  final List<double> cumulativeDistances;
  final double totalLength;
  final double roadWidth;
  final RoadPoint startDockPos;
  final RoadPoint cagePos;
  final RoadPoint destinationPos;
  final RoadPoint repairKitPos;
  final List<RoadSceneryProp> props;

  RoadPathDefinition._({
    required this.routeId,
    required this.controlPoints,
    required this.sampledPoints,
    required this.cumulativeDistances,
    required this.totalLength,
    required this.roadWidth,
    required this.startDockPos,
    required this.cagePos,
    required this.destinationPos,
    required this.repairKitPos,
    required this.props,
  });

  /// Constructs a smooth, densely sampled Catmull-Rom spline road through [controlPoints].
  factory RoadPathDefinition.fromControlPoints({
    required String routeId,
    required List<RoadPoint> controlPoints,
    required RoadPoint cagePos,
    required RoadPoint repairKitPos,
    required List<RoadSceneryProp> props,
    double roadWidth = 1.38,
    int samplesPerSegment = 18,
  }) {
    assert(controlPoints.length >= 2);
    final sampled = <RoadPoint>[];

    for (int i = 0; i < controlPoints.length - 1; i++) {
      final p0 = controlPoints[math.max(0, i - 1)];
      final p1 = controlPoints[i];
      final p2 = controlPoints[i + 1];
      final p3 = controlPoints[math.min(controlPoints.length - 1, i + 2)];

      final steps = (i == controlPoints.length - 2)
          ? samplesPerSegment + 1
          : samplesPerSegment;
      for (int s = 0; s < steps; s++) {
        final t = s / samplesPerSegment;
        final t2 = t * t;
        final t3 = t2 * t;
        final x = 0.5 *
            ((2 * p1.x) +
                (-p0.x + p2.x) * t +
                (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
                (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3);
        final y = 0.5 *
            ((2 * p1.y) +
                (-p0.y + p2.y) * t +
                (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
                (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3);
        sampled.add(RoadPoint(
          x.clamp(0.8, RoadArenaBounds.width - 0.8),
          y.clamp(0.9, RoadArenaBounds.height - 0.9),
        ));
      }
    }

    final cumDist = <double>[0.0];
    double total = 0.0;
    for (int i = 1; i < sampled.length; i++) {
      total += sampled[i - 1].distanceTo(sampled[i]);
      cumDist.add(total);
    }

    return RoadPathDefinition._(
      routeId: routeId,
      controlPoints: controlPoints,
      sampledPoints: sampled,
      cumulativeDistances: cumDist,
      totalLength: math.max(0.01, total),
      roadWidth: roadWidth,
      startDockPos: controlPoints.first,
      cagePos: cagePos,
      destinationPos: controlPoints.last,
      repairKitPos: repairKitPos,
      props: props,
    );
  }

  /// Samples exact world position and forward tangent angle at arc-length [distance].
  RoadSample sampleAtDistance(double distance) {
    final d = distance.clamp(0.0, totalLength);
    if (sampledPoints.length < 2) {
      return RoadSample(x: startDockPos.x, y: startDockPos.y, angle: 0.0);
    }

    int idx = 0;
    // Binary search for segment containing d
    int lo = 0;
    int hi = cumulativeDistances.length - 2;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cumulativeDistances[mid] <= d) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    final d0 = cumulativeDistances[idx];
    final d1 = cumulativeDistances[idx + 1];
    final segLen = math.max(1e-5, d1 - d0);
    final t = ((d - d0) / segLen).clamp(0.0, 1.0);
    final a = sampledPoints[idx];
    final b = sampledPoints[idx + 1];
    final x = a.x + (b.x - a.x) * t;
    final y = a.y + (b.y - a.y) * t;

    // Look slightly ahead for silky-smooth steering rotation along curves
    final lookIdx = math.min(sampledPoints.length - 1, idx + 2);
    final prevIdx = math.max(0, idx - 1);
    final dirA = sampledPoints[prevIdx];
    final dirB = sampledPoints[lookIdx];
    final angle = math.atan2(dirB.y - dirA.y, dirB.x - dirA.x);

    return RoadSample(x: x, y: y, angle: angle);
  }

  /// Computes minimum distance from point ([px], [py]) to the road centerline.
  double distanceToCenterline(double px, double py) {
    double bestSq = double.infinity;
    for (int i = 0; i < sampledPoints.length; i += 2) {
      final pt = sampledPoints[i];
      final dx = px - pt.x;
      final dy = py - pt.y;
      final dSq = dx * dx + dy * dy;
      if (dSq < bestSq) bestSq = dSq;
    }
    return math.sqrt(bestSq);
  }
}

/// Complete immutable Truck Defense configuration for a campaign level (Levels 1–50).
class TruckDefenseConfig {
  final int levelId;
  final int districtId;
  final DistrictBossType bossType;
  final DestinationBuildingType destinationType;
  final int bossMaxHp;
  final double bossSpeed;
  final double bossAttackInterval;
  final int bossDamageScale; // Base attack power multiplier (%)
  final List<BossAttackType> unlockedAttacks;
  final int truckMaxHp;
  final double truckBaseSpeed;
  final int defenseTimeLimitSeconds;
  final int difficultyTier; // 1 (Tutorial) .. 6 (Expert)
  final RoadPathDefinition road;

  const TruckDefenseConfig({
    required this.levelId,
    required this.districtId,
    required this.bossType,
    required this.destinationType,
    required this.bossMaxHp,
    required this.bossSpeed,
    required this.bossAttackInterval,
    required this.bossDamageScale,
    required this.unlockedAttacks,
    this.truckMaxHp = 100,
    required this.truckBaseSpeed,
    required this.defenseTimeLimitSeconds,
    required this.difficultyTier,
    required this.road,
  });

  /// Deterministic per-level campaign configuration for all 50 levels (Sections 9 & 18).
  /// Scales difficulty via attack pool, timing, tactical patterns, and distinct curved routes.
  static TruckDefenseConfig forLevel({
    required int levelId,
    required int districtId,
  }) {
    final bossType = DistrictBossType.forDistrict(districtId);
    final destType = DestinationBuildingType.forDistrict(districtId);

    // 6-tier progression table matching Section 9 exactly!
    final int tier;
    final List<BossAttackType> attacks;
    final int bossHp;
    final double bossSpeed;
    final double attackInterval;
    final int dmgScale;
    final double truckSpeed;
    final int defenseSeconds;

    if (levelId <= 5) {
      // Levels 1-5: Tutorial (Slow boss, basic attack)
      tier = 1;
      attacks = const [BossAttackType.directCharge];
      bossHp = 110 + levelId * 10;
      bossSpeed = 1.65 + levelId * 0.04;
      attackInterval = 3.85;
      dmgScale = 75;
      truckSpeed = 1.18;
      defenseSeconds = 52;
    } else if (levelId <= 10) {
      // Levels 6-10: Easy (Faster attacks & first fantasy bomb projectile)
      tier = 2;
      attacks = const [
        BossAttackType.directCharge,
        BossAttackType.bombProjectile,
      ];
      bossHp = 155 + (levelId - 5) * 14;
      bossSpeed = 1.90 + (levelId - 5) * 0.05;
      attackInterval = 3.30;
      dmgScale = 88;
      truckSpeed = 1.14;
      defenseSeconds = 55;
    } else if (levelId <= 20) {
      // Levels 11-20: Medium (Tire attacks, projectiles, charges) — includes Level 18 Garden Market!
      tier = 3;
      attacks = const [
        BossAttackType.bombProjectile,
        BossAttackType.tireAttack,
        BossAttackType.directCharge,
      ];
      bossHp = 225 + (levelId - 10) * 14;
      bossSpeed = 2.15 + (levelId - 10) * 0.03;
      attackInterval = 2.85;
      dmgScale = 100;
      truckSpeed = 1.10;
      defenseSeconds = 58;
    } else if (levelId <= 30) {
      // Levels 21-30: Challenging (Ground Slam + Multiple Attack Combinations)
      tier = 4;
      attacks = const [
        BossAttackType.bombProjectile,
        BossAttackType.tireAttack,
        BossAttackType.directCharge,
        BossAttackType.groundSlam,
      ];
      bossHp = 330 + (levelId - 20) * 15;
      bossSpeed = 2.38 + (levelId - 20) * 0.025;
      attackInterval = 2.55;
      dmgScale = 110;
      truckSpeed = 1.07;
      defenseSeconds = 60;
    } else if (levelId <= 40) {
      // Levels 31-40: Hard (Defensive abilities, helper monsters, all attacks)
      tier = 5;
      attacks = const [
        BossAttackType.bombProjectile,
        BossAttackType.tireAttack,
        BossAttackType.directCharge,
        BossAttackType.groundSlam,
        BossAttackType.specialAbility,
      ];
      bossHp = 440 + (levelId - 30) * 16;
      bossSpeed = 2.58 + (levelId - 30) * 0.02;
      attackInterval = 2.30;
      dmgScale = 120;
      truckSpeed = 1.05;
      defenseSeconds = 64;
    } else {
      // Levels 41-50: Expert (Advanced attack patterns & Grand Guardians)
      tier = 6;
      attacks = const [
        BossAttackType.bombProjectile,
        BossAttackType.tireAttack,
        BossAttackType.directCharge,
        BossAttackType.groundSlam,
        BossAttackType.specialAbility,
      ];
      bossHp = 560 + (levelId - 40) * 20;
      bossSpeed = 2.75 + (levelId - 40) * 0.02;
      attackInterval = 2.05;
      dmgScale = 132;
      truckSpeed = 1.04;
      defenseSeconds = 68;
    }

    final road = _buildRoadForLevel(levelId: levelId, districtId: districtId);

    return TruckDefenseConfig(
      levelId: levelId,
      districtId: districtId,
      bossType: bossType,
      destinationType: destType,
      bossMaxHp: bossHp,
      bossSpeed: bossSpeed,
      bossAttackInterval: attackInterval,
      bossDamageScale: dmgScale,
      unlockedAttacks: attacks,
      truckMaxHp: 100,
      truckBaseSpeed: truckSpeed,
      defenseTimeLimitSeconds: defenseSeconds,
      difficultyTier: tier,
      road: road,
    );
  }

  /// Generates 5 distinct multi-bend winding road templates varied by level & district,
  /// with S-curves, bends, Dock + Cage start, Repair Kit, Destination & scenic roadside props.
  static RoadPathDefinition _buildRoadForLevel({
    required int levelId,
    required int districtId,
  }) {
    final variant = (levelId - 1) % 5;
    final bool mirror = ((levelId - 1) ~/ 5).isOdd && variant != 0;

    double mx(double x) => mirror ? (RoadArenaBounds.width - x) : x;

    late final List<RoadPoint> rawPts;
    late final RoadPoint cagePos;
    late final RoadPoint repairPos;

    switch (variant) {
      case 0:
        // Classic Double-S Orchard/Market Winding Route (matches user's red sketch!)
        rawPts = const [
          RoadPoint(5.2, 1.35),
          RoadPoint(8.3, 1.90),
          RoadPoint(7.9, 4.10),
          RoadPoint(2.2, 4.85),
          RoadPoint(1.8, 7.35),
          RoadPoint(8.0, 8.20),
          RoadPoint(7.8, 10.65),
          RoadPoint(2.6, 11.45),
          RoadPoint(5.4, 12.65),
        ];
        cagePos = const RoadPoint(2.2, 1.55);
        repairPos = const RoadPoint(5.0, 6.40);
        break;
      case 1:
        // Sweeping Serpentine Hairpin Route
        rawPts = [
          RoadPoint(mx(4.8), 1.35),
          RoadPoint(mx(8.2), 2.30),
          RoadPoint(mx(2.0), 4.40),
          RoadPoint(mx(8.2), 6.95),
          RoadPoint(mx(2.1), 9.65),
          RoadPoint(mx(7.6), 11.80),
          RoadPoint(mx(5.0), 12.70),
        ];
        cagePos = RoadPoint(mx(2.0), 1.50);
        repairPos = RoadPoint(mx(5.1), 7.80);
        break;
      case 2:
        // Wide Canyon/Market Loopback Route (Level 18 Garden Market uses variant 2!)
        rawPts = [
          RoadPoint(mx(5.4), 1.35),
          RoadPoint(mx(8.4), 1.95),
          RoadPoint(mx(8.1), 4.65),
          RoadPoint(mx(2.0), 5.30),
          RoadPoint(mx(2.2), 8.20),
          RoadPoint(mx(8.2), 8.85),
          RoadPoint(mx(7.9), 11.55),
          RoadPoint(mx(3.2), 12.55),
        ];
        cagePos = RoadPoint(mx(2.1), 1.55);
        repairPos = RoadPoint(mx(5.2), 6.85);
        break;
      case 3:
        // Three-Bend Forest Trail Route
        rawPts = [
          RoadPoint(mx(4.6), 1.35),
          RoadPoint(mx(7.9), 2.45),
          RoadPoint(mx(6.8), 5.05),
          RoadPoint(mx(2.1), 6.05),
          RoadPoint(mx(2.5), 8.95),
          RoadPoint(mx(8.1), 10.10),
          RoadPoint(mx(6.6), 12.65),
        ];
        cagePos = RoadPoint(mx(1.9), 1.55);
        repairPos = RoadPoint(mx(5.3), 7.55);
        break;
      default:
        // Grand Zigzag Highway Route
        rawPts = [
          RoadPoint(mx(5.0), 1.35),
          RoadPoint(mx(8.3), 2.15),
          RoadPoint(mx(3.0), 3.95),
          RoadPoint(mx(1.9), 6.35),
          RoadPoint(mx(8.1), 7.65),
          RoadPoint(mx(7.2), 10.25),
          RoadPoint(mx(2.3), 11.20),
          RoadPoint(mx(5.6), 12.70),
        ];
        cagePos = RoadPoint(mx(2.1), 1.50);
        repairPos = RoadPoint(mx(4.9), 5.65);
        break;
    }

    // Build preliminary road to place roadside scenery cleanly outside the asphalt!
    final tempRoad = RoadPathDefinition.fromControlPoints(
      routeId: 'L${levelId}_V$variant',
      controlPoints: rawPts,
      cagePos: cagePos,
      repairKitPos: repairPos,
      props: const [],
    );

    final props = _generateRoadsideProps(
      road: tempRoad,
      districtId: districtId,
      seed: levelId * 97 + districtId * 13,
    );

    return RoadPathDefinition.fromControlPoints(
      routeId: 'L${levelId}_V$variant',
      controlPoints: rawPts,
      cagePos: cagePos,
      repairKitPos: repairPos,
      props: props,
    );
  }

  static List<RoadSceneryProp> _generateRoadsideProps({
    required RoadPathDefinition road,
    required int districtId,
    required int seed,
  }) {
    final rng = math.Random(seed);
    final props = <RoadSceneryProp>[];

    final List<RoadPropKind> palette;
    switch (districtId) {
      case 1:
        palette = const [
          RoadPropKind.tree,
          RoadPropKind.bush,
          RoadPropKind.flowerPatch,
        ];
        break;
      case 2:
        palette = const [
          RoadPropKind.marketStall,
          RoadPropKind.crateStack,
          RoadPropKind.bush,
          RoadPropKind.flowerPatch,
        ];
        break;
      case 3:
        palette = const [
          RoadPropKind.tree,
          RoadPropKind.bush,
          RoadPropKind.rock,
        ];
        break;
      case 4:
        palette = const [
          RoadPropKind.rock,
          RoadPropKind.lampPost,
          RoadPropKind.bush,
        ];
        break;
      default:
        palette = const [
          RoadPropKind.lampPost,
          RoadPropKind.crateStack,
          RoadPropKind.tree,
        ];
        break;
    }

    for (int attempt = 0; attempt < 90 && props.length < 18; attempt++) {
      final px = 0.55 + rng.nextDouble() * (RoadArenaBounds.width - 1.1);
      final py = 1.9 + rng.nextDouble() * (RoadArenaBounds.height - 3.3);

      // Keep clear of road asphalt, cage, repair kit, and destination building
      if (road.distanceToCenterline(px, py) < 1.25) continue;
      final pt = RoadPoint(px, py);
      if (pt.distanceTo(road.cagePos) < 1.5) continue;
      if (pt.distanceTo(road.repairKitPos) < 1.25) continue;
      if (pt.distanceTo(road.destinationPos) < 1.7) continue;

      bool overlaps = false;
      for (final existing in props) {
        final dx = existing.x - px;
        final dy = existing.y - py;
        if (dx * dx + dy * dy < 1.15 * 1.15) {
          overlaps = true;
          break;
        }
      }
      if (overlaps) continue;

      props.add(RoadSceneryProp(
        kind: palette[rng.nextInt(palette.length)],
        x: px,
        y: py,
        scale: 0.85 + rng.nextDouble() * 0.32,
      ));
    }
    return props;
  }
}

// ---------------------------------------------------------------------------
// Live Runtime Entities for the Truck Defense Phase
// ---------------------------------------------------------------------------

class TruckDefenseVehicle {
  final int maxHp;
  int hp;
  int tireCondition; // 0..100
  double traveledDistance;
  final double totalRoadLength;
  final double baseSpeed;

  double x;
  double y;
  double angle;
  double wheelSpinPhase = 0.0;

  double tireSlowTimer = 0.0;
  double tireFlashTimer = 0.0;
  double slamSlowTimer = 0.0;
  double hitFlashTimer = 0.0;
  double repairFlashTimer = 0.0;

  TruckDefenseVehicle({
    required this.maxHp,
    required this.totalRoadLength,
    required this.baseSpeed,
    required this.x,
    required this.y,
    required this.angle,
  })  : hp = maxHp,
        tireCondition = 100,
        traveledDistance = 0.0;

  double get progress =>
      (traveledDistance / math.max(0.01, totalRoadLength)).clamp(0.0, 1.0);

  int get progressPercent => (progress * 100).round().clamp(0, 100);

  bool get isDestroyed => hp <= 0;

  bool get isTireDamaged => tireSlowTimer > 0.0 || tireCondition < 70;

  TruckDamageState get damageState {
    if (hp <= 0) return TruckDamageState.destroyed;
    final pct = hp / math.max(1, maxHp);
    if (pct <= 0.30) return TruckDamageState.critical;
    if (pct <= 0.65) return TruckDamageState.damaged;
    return TruckDamageState.healthy;
  }

  /// Current speed factor accounting for tire condition & active slows (never permanently freezes unless destroyed!).
  double get currentSpeedMultiplier {
    if (isDestroyed) return 0.0;
    double mult = 1.0;
    if (tireSlowTimer > 0.0) {
      mult *= 0.45;
    } else if (tireCondition < 60) {
      mult *= 0.78;
    }
    if (slamSlowTimer > 0.0) {
      mult *= 0.55;
    }
    if (damageState == TruckDamageState.critical) {
      mult *= 0.88;
    }
    return mult.clamp(0.28, 1.0);
  }
}

enum AllyCombatState {
  peaceful,
  surprised,
  escorting,
  intercepting,
  slashing,
  recovering,
  celebrating,
}

class DockWorkerAlly {
  double x;
  double y;
  double facingAngle = 0.0;
  double walkPhase = 0.0;
  bool hasKnifeDrawn = false;
  AllyCombatState state = AllyCombatState.peaceful;
  double attackCooldown = 0.0;
  double slashAnimTimer = 0.0;
  double recoverTimer = 0.0;
  double hitFlashTimer = 0.0;
  int totalHitsLanded = 0;

  DockWorkerAlly({
    required this.x,
    required this.y,
  });
}

enum BossCombatAiState {
  caged,
  escaping,
  pursuingTruck,
  telegraphing,
  charging,
  recovering,
  stunned,
  frozen,
  defeated,
  retreating,
}

class RoadBossEntity {
  final DistrictBossType type;
  final int maxHp;
  int hp;
  final double baseSpeed;
  final double attackInterval;
  final int damageScale;
  final List<BossAttackType> attackPool;

  double x;
  double y;
  double facingAngle = 0.0;
  double animPhase = 0.0;

  BossCombatAiState aiState = BossCombatAiState.caged;
  BossAttackType? queuedAttack;
  double stateTimer = 0.0;
  double attackCooldown = 1.8;
  double stunTimer = 0.0;
  double freezeTimer = 0.0;
  double hitFlashTimer = 0.0;
  double shieldTimer = 0.0; // Defensive boss shield (L31+)
  double knockbackVx = 0.0;
  double knockbackVy = 0.0;

  // Telegraph target coordinates (for bomb impact circle / charge lane / ground slam zone)
  double telegraphTargetX = 0.0;
  double telegraphTargetY = 0.0;
  double telegraphDuration = 0.9;
  int patternCursor = 0;
  bool distractedByAlly = false;
  double distractTimer = 0.0;

  RoadBossEntity({
    required this.type,
    required this.maxHp,
    required this.baseSpeed,
    required this.attackInterval,
    required this.damageScale,
    required this.attackPool,
    required this.x,
    required this.y,
  }) : hp = maxHp;

  bool get isDefeated => hp <= 0 || aiState == BossCombatAiState.defeated;
  bool get isCaged => aiState == BossCombatAiState.caged;
  bool get hasShield => shieldTimer > 0.0;
  double get hpRatio => (hp / math.max(1, maxHp)).clamp(0.0, 1.0);
  double get telegraphProgress =>
      (stateTimer / math.max(0.05, telegraphDuration)).clamp(0.0, 1.0);
}

/// Fantasy bomb or magic orb fired by the giant boss toward the truck.
class BossProjectileEntity {
  final bool isBomb; // true = lobbed fantasy bomb with arc, false = magic orb
  final double startX;
  final double startY;
  final double targetX;
  final double targetY;
  double x;
  double y;
  double age = 0.0;
  final double travelDuration;
  final int damage;
  final double blastRadius;
  bool active = true;
  bool intercepted = false;

  BossProjectileEntity({
    required this.isBomb,
    required this.startX,
    required this.startY,
    required this.targetX,
    required this.targetY,
    required this.travelDuration,
    required this.damage,
    this.blastRadius = 1.05,
  })  : x = startX,
        y = startY;

  double get progress => (age / math.max(0.05, travelDuration)).clamp(0.0, 1.0);
}

/// Temporary road hazard created by Ground Slam or Special Slow Cloud.
enum RoadHazardKind {
  groundSlamCrater,
  slowingCloud,
}

class RoadHazardZone {
  final RoadHazardKind kind;
  final double x;
  final double y;
  final double radius;
  double remainingTime;
  final double maxTime;
  final int damageOnContact;
  bool hasDamagedTruck = false;

  RoadHazardZone({
    required this.kind,
    required this.x,
    required this.y,
    required this.radius,
    required this.remainingTime,
    required this.damageOnContact,
  }) : maxTime = remainingTime;

  bool get isExpired => remainingTime <= 0.0;
  double get alpha => (remainingTime / math.max(0.1, maxTime)).clamp(0.0, 1.0);
}

/// Small helper imp summoned by high-level bosses (Levels 31–50).
class RoadHelperMinion {
  double x;
  double y;
  int hp;
  final int maxHp;
  double speed;
  double facingAngle = 0.0;
  double animPhase = 0.0;
  double attackCooldown = 0.8;
  double hitFlashTimer = 0.0;
  double stunTimer = 0.0;

  RoadHelperMinion({
    required this.x,
    required this.y,
    this.hp = 35,
    this.speed = 2.25,
  }) : maxHp = hp;

  bool get isDefeated => hp <= 0;
}

/// One-use roadside repair kit that heals a small amount of Truck HP & restores tires (Section 8).
class RoadRepairKit {
  final double x;
  final double y;
  final int healAmount;
  bool collected = false;

  RoadRepairKit({
    required this.x,
    required this.y,
    this.healAmount = 22,
  });
}

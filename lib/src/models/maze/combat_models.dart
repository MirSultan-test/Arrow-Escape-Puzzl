/// Weapons and defensive abilities unlocked progressively across the 50-level campaign.
enum WeaponType {
  melee,
  bow,
  freezeOrb,
  energyBlaster,
  foodDecoy,
  stunPulse;

  String get displayName {
    switch (this) {
      case WeaponType.melee:
        return 'Push Strike';
      case WeaponType.bow:
        return 'Bow';
      case WeaponType.freezeOrb:
        return 'Freeze Orb';
      case WeaponType.energyBlaster:
        return 'Blaster';
      case WeaponType.foodDecoy:
        return 'Decoy';
      case WeaponType.stunPulse:
        return 'Stun Pulse';
    }
  }

  /// Campaign level at which this weapon/ability becomes available (Section 10).
  int get unlockLevel {
    switch (this) {
      case WeaponType.melee:
        return 4;
      case WeaponType.bow:
        return 6;
      case WeaponType.freezeOrb:
        return 11;
      case WeaponType.energyBlaster:
        return 16;
      case WeaponType.foodDecoy:
        return 21;
      case WeaponType.stunPulse:
        return 26;
    }
  }

  int get baseDamage {
    switch (this) {
      case WeaponType.melee:
        return 15;
      case WeaponType.bow:
        return 25;
      case WeaponType.freezeOrb:
        return 10;
      case WeaponType.energyBlaster:
        return 38;
      case WeaponType.foodDecoy:
        return 0;
      case WeaponType.stunPulse:
        return 10;
    }
  }

  double get cooldownSeconds {
    switch (this) {
      case WeaponType.melee:
        return 0.55;
      case WeaponType.bow:
        return 0.60;
      case WeaponType.freezeOrb:
        return 1.05;
      case WeaponType.energyBlaster:
        return 0.85;
      case WeaponType.foodDecoy:
        return 2.40;
      case WeaponType.stunPulse:
        return 4.00;
    }
  }

  double get rangeTiles {
    switch (this) {
      case WeaponType.melee:
        return 1.50;
      case WeaponType.bow:
        return 6.50;
      case WeaponType.freezeOrb:
        return 5.50;
      case WeaponType.energyBlaster:
        return 5.20;
      case WeaponType.foodDecoy:
        return 4.50;
      case WeaponType.stunPulse:
        return 2.05;
    }
  }

  double get projectileSpeed {
    switch (this) {
      case WeaponType.bow:
        return 9.8;
      case WeaponType.freezeOrb:
        return 7.2;
      case WeaponType.energyBlaster:
        return 10.8;
      default:
        return 0.0;
    }
  }

  int get startingAmmo {
    switch (this) {
      case WeaponType.melee:
        return -1; // Unlimited
      case WeaponType.bow:
        return 10;
      case WeaponType.freezeOrb:
        return 4;
      case WeaponType.energyBlaster:
        return 6;
      case WeaponType.foodDecoy:
        return 3;
      case WeaponType.stunPulse:
        return -1; // Unlimited on cooldown
    }
  }

  bool get isProjectile =>
      this == WeaponType.bow ||
      this == WeaponType.freezeOrb ||
      this == WeaponType.energyBlaster;

  bool get isPrimaryRanged =>
      this == WeaponType.bow || this == WeaponType.energyBlaster;

  bool get isSpecialAbility =>
      this == WeaponType.freezeOrb ||
      this == WeaponType.foodDecoy ||
      this == WeaponType.stunPulse;

  int get colorHex {
    switch (this) {
      case WeaponType.melee:
        return 0xFFFF9F1C;
      case WeaponType.bow:
        return 0xFFC87D32;
      case WeaponType.freezeOrb:
        return 0xFF38BDF8;
      case WeaponType.energyBlaster:
        return 0xFFA855F7;
      case WeaponType.foodDecoy:
        return 0xFF5DBB75;
      case WeaponType.stunPulse:
        return 0xFFFACC15;
    }
  }
}

/// Collectible combat supply or defensive power-up placed in the maze.
enum CombatPickupType {
  arrows,
  energyCharges,
  freezeOrbs,
  shield;

  String get displayName {
    switch (this) {
      case CombatPickupType.arrows:
        return '+5 Arrows';
      case CombatPickupType.energyCharges:
        return '+3 Blaster';
      case CombatPickupType.freezeOrbs:
        return '+2 Freeze';
      case CombatPickupType.shield:
        return 'Shield';
    }
  }

  static CombatPickupType fromName(String raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return CombatPickupType.arrows;
  }
}

class CombatPickupSpawn {
  final String id;
  final CombatPickupType type;
  final int col;
  final int row;
  final int amount;

  const CombatPickupSpawn({
    required this.id,
    required this.type,
    required this.col,
    required this.row,
    this.amount = 5,
  });

  CombatPickupItem createRuntimeItem() => CombatPickupItem(
        id: id,
        type: type,
        col: col,
        row: row,
        amount: amount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'col': col,
        'row': row,
        'amount': amount,
      };

  factory CombatPickupSpawn.fromJson(Map<String, dynamic> json) =>
      CombatPickupSpawn(
        id: json['id'] as String? ?? 'cp0',
        type: CombatPickupType.fromName(json['type'] as String? ?? 'arrows'),
        col: (json['col'] as num).toInt(),
        row: (json['row'] as num).toInt(),
        amount: (json['amount'] as num?)?.toInt() ?? 5,
      );
}

class CombatPickupItem {
  final String id;
  final CombatPickupType type;
  final int col;
  final int row;
  final int amount;
  bool collected;

  CombatPickupItem({
    required this.id,
    required this.type,
    required this.col,
    required this.row,
    required this.amount,
    this.collected = false,
  });
}

/// Active projectile fired by the player (Arrow, Energy Blaster Bolt, Freeze Orb).
class ProjectileEntity {
  final WeaponType weapon;
  double x;
  double y;
  final double vx;
  final double vy;
  final double angle;
  final int damage;
  double remainingRange;
  bool active;

  ProjectileEntity({
    required this.weapon,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.damage,
    required this.remainingRange,
    this.active = true,
  });
}

/// Temporary food decoy dropped by the player to lure nearby monsters away.
class FoodDecoyEntity {
  final double x;
  final double y;
  double remainingTime;
  final double maxTime;

  FoodDecoyEntity({
    required this.x,
    required this.y,
    this.remainingTime = 5.5,
    this.maxTime = 5.5,
  });

  bool get isExpired => remainingTime <= 0;
}

/// Fantasy poison cloud released by Poison Mushroom Beasts & Maze Guardians.
class PoisonCloudEntity {
  final double x;
  final double y;
  final double radius;
  double remainingTime;
  final double maxTime;

  PoisonCloudEntity({
    required this.x,
    required this.y,
    this.radius = 1.35,
    this.remainingTime = 3.2,
    this.maxTime = 3.2,
  });

  bool get isExpired => remainingTime <= 0;
  double get alpha => (remainingTime / maxTime).clamp(0.0, 1.0);
}

/// Lightweight pooled-friendly visual effect burst (melee arc, stun ring, hit sparks, shield pop).
enum CombatVfxType {
  meleeSlash,
  stunPulseRing,
  hitBurst,
  freezeBurst,
  defeatPuff,
  shieldBreak,
}

class CombatVfx {
  final CombatVfxType type;
  final double x;
  final double y;
  final double angle;
  final double maxRadius;
  final int colorHex;
  double age;
  final double duration;

  CombatVfx({
    required this.type,
    required this.x,
    required this.y,
    this.angle = 0.0,
    this.maxRadius = 1.0,
    required this.colorHex,
    this.age = 0.0,
    this.duration = 0.35,
  });

  double get progress => (age / duration).clamp(0.0, 1.0);
  bool get isExpired => age >= duration;
}

import 'combat_models.dart';
import 'food_item.dart';
import 'monster_variants.dart';
import 'truck_defense_models.dart';

/// Authoritative animation states for the playable Human Courier (Section 2).
enum CourierAnimState {
  idle,
  walk,
  run,
  aimBow,
  releaseBow,
  fireBlaster,
  castOrb,
  meleeSlash,
  pickupFood,
  deliverFood,
  hurt,
  celebrate,
}

/// Expressive facial states visibly rendered on the Courier's face (Section 2).
enum CourierExpression {
  relaxed, // Idle, gentle blinking
  focused, // Running
  alert, // Enemy approaching
  determined, // Attacking / aiming
  pain, // Taking damage
  happy, // Picking up food
  smiling, // Delivering food
  excited, // Winning
  worried, // Low health (1 heart)
}

/// Complete per-frame animation snapshot passed to the articulated 2.5D Courier rig.
class CourierAnimSnapshot {
  final CourierAnimState state;
  final CourierExpression expression;
  final double facingAngle; // Radians (supports full 8-way / smooth direction!)
  final double moveSpeedRatio; // 0.0 = stationary, 0.5 = walk, 1.0 = run
  final double walkCyclePhase;
  final double stateProgress; // 0.0..1.0 normalized progress inside active action
  final double elapsed;
  final WeaponType? equippedWeapon;
  final WeaponType? activeAttackWeapon;
  final double hurtRecoilProgress; // 0.0..1.0
  final double recoilDirX;
  final double recoilDirY;
  final bool hasShield;
  final bool isInvulnerable;
  final bool isPoisonSlowed;
  final bool isHealing;
  final List<FoodItem> carriedFoods;

  const CourierAnimSnapshot({
    required this.state,
    required this.expression,
    required this.facingAngle,
    required this.moveSpeedRatio,
    required this.walkCyclePhase,
    required this.stateProgress,
    required this.elapsed,
    this.equippedWeapon,
    this.activeAttackWeapon,
    this.hurtRecoilProgress = 0.0,
    this.recoilDirX = 0.0,
    this.recoilDirY = 0.0,
    this.hasShield = false,
    this.isInvulnerable = false,
    this.isPoisonSlowed = false,
    this.isHealing = false,
    this.carriedFoods = const [],
  });
}

/// Authoritative animation states for the Dock Worker (Peaceful Worker + Combat Defender, Section 3).
enum DockWorkerAnimState {
  // Peaceful Dock Work States (STRICTLY before monster escapes!)
  idleWaiting,
  waving,
  receivingFood,
  carryingToTruck,
  loadingTruck,
  closingCargo,
  smilingAfterLoad,
  // Combat Defender States (STRICTLY after monster escapes!)
  surprised,
  drawingKnife,
  defendStance,
  advancing,
  knifeHorizontalSwing,
  knifeCounterSlash,
  hurtRecoil,
  celebrating,
}

/// Expressive facial states for the Dock Worker.
enum DockWorkerExpression {
  friendly,
  smiling,
  working,
  surprised,
  focusedCombat,
  determinedStrike,
  hurt,
  celebrating,
}

/// Complete per-frame animation snapshot passed to the articulated 2.5D Dock Worker rig.
class DockWorkerAnimSnapshot {
  final DockWorkerAnimState state;
  final DockWorkerExpression expression;
  final double facingAngle;
  final double walkCyclePhase;
  final double stateProgress; // 0.0..1.0 normalized animation marker
  final double elapsed;
  final bool hasKnifeDrawn;
  final FoodType? carriedFoodType; // Visibly held in both hands while loading!
  final double hurtRecoilProgress;

  const DockWorkerAnimSnapshot({
    required this.state,
    required this.expression,
    required this.facingAngle,
    required this.walkCyclePhase,
    required this.stateProgress,
    required this.elapsed,
    required this.hasKnifeDrawn,
    this.carriedFoodType,
    this.hurtRecoilProgress = 0.0,
  });
}

/// Authoritative animation states for the Giant District Boss Monster (Section 4).
enum BossAnimState {
  cagedIdle,
  breakingCage,
  idle,
  walk,
  run,
  windupClaw,
  clawStrike,
  windupTireAttack,
  tireStrike,
  windupCharge,
  charging,
  windupSlam,
  groundSlam,
  windupBomb,
  throwBomb,
  specialCast,
  hurtRecoil,
  stunned,
  frozen,
  defeated,
  retreating,
}

/// Expressive facial states for the Giant Boss Monster.
enum BossExpression {
  angryCaged,
  furiousRoar,
  aggressiveChase,
  focusedWindup,
  attackRoar,
  painRecoil,
  dizzyStunned,
  exhaustedLowHp,
  defeatedWeak,
}

/// Complete per-frame animation snapshot passed to the articulated 2.5D Giant Boss rig.
class BossAnimSnapshot {
  final DistrictBossType bossType;
  final BossAppearanceSpec? appearance;
  final BossAnimState state;
  final BossExpression expression;
  final double facingAngle;
  final double walkCyclePhase;
  final double stateProgress; // 0.0..1.0 normalized progress
  final double elapsed;
  final double hpRatio;
  final double hurtRecoilProgress;
  final double recoilDirX;
  final double recoilDirY;
  final bool hasShield;
  final bool isHoldingBomb; // Bomb visibly gripped in boss's throwing claw during windup!
  final bool isCaged;

  const BossAnimSnapshot({
    required this.bossType,
    this.appearance,
    required this.state,
    required this.expression,
    required this.facingAngle,
    required this.walkCyclePhase,
    required this.stateProgress,
    required this.elapsed,
    required this.hpRatio,
    this.hurtRecoilProgress = 0.0,
    this.recoilDirX = 0.0,
    this.recoilDirY = 0.0,
    this.hasShield = false,
    this.isHoldingBomb = false,
    this.isCaged = false,
  });
}

/// Lightweight ground contact footstep / charge / landing dust puff.
class DustPuffEntity {
  double x;
  double y;
  double age = 0.0;
  final double lifetime;
  final double maxRadius;
  final int colorHex;

  DustPuffEntity({
    required this.x,
    required this.y,
    this.lifetime = 0.36,
    this.maxRadius = 0.28,
    this.colorHex = 0xFFD9C7A3,
  });

  double get progress => (age / lifetime).clamp(0.0, 1.0);
  bool get isExpired => age >= lifetime;
}

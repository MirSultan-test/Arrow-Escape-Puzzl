import 'dart:math' as math;
import '../../models/maze/character_animation_state.dart';
import '../../models/maze/combat_models.dart';
import '../../models/maze/delivery_state.dart';
import '../../models/maze/food_item.dart';
import '../../models/maze/maze_level.dart';
import '../../models/maze/monster.dart';
import '../../models/maze/monster_variants.dart';
import '../../models/maze/truck_defense_models.dart';
import 'maze_pathfinder.dart';
import 'truck_defense_simulation.dart';

/// Callbacks emitted by the pure simulation engine for audio, haptics, and UI feedback.
class MazeEngineCallbacks {
  final void Function(FoodItem item)? onFoodPickup;
  final void Function()? onCargoFull;
  final void Function(MonsterEntity monster)? onMonsterAlert;
  final void Function(MonsterEntity monster, FoodItem? bittenFood, int eatenAmount)?
      onMonsterAttack;
  final void Function(WeaponType weapon)? onWeaponFired;
  final void Function(MonsterEntity monster, int damage, bool defeated)?
      onMonsterHit;
  final void Function(CombatPickupItem pickup)? onCombatPickup;
  final void Function()? onShieldBlocked;
  final void Function(List<FoodItem> deliveredItems, int pointsAdded)?
      onFoodDelivered;
  final void Function(int newHealth, String source)? onHealthRestored;
  final void Function()? onTruckEngineStart;
  final void Function()? onCageBreakOpen;
  final void Function(int damage, bool isTireHit)? onTruckDamaged;
  final void Function(int healedAmount)? onTruckRepaired;
  final void Function(int damage, bool bossDefeated)? onBossHit;
  final void Function()? onAllySlash;
  final void Function(MazeScoreBreakdown breakdown)? onVictory;
  final void Function(DefeatReason reason)? onDefeat;
  final void Function()? onCriticalTick;

  const MazeEngineCallbacks({
    this.onFoodPickup,
    this.onCargoFull,
    this.onMonsterAlert,
    this.onMonsterAttack,
    this.onWeaponFired,
    this.onMonsterHit,
    this.onCombatPickup,
    this.onShieldBlocked,
    this.onFoodDelivered,
    this.onHealthRestored,
    this.onTruckEngineStart,
    this.onCageBreakOpen,
    this.onTruckDamaged,
    this.onTruckRepaired,
    this.onBossHit,
    this.onAllySlash,
    this.onVictory,
    this.onDefeat,
    this.onCriticalTick,
  });
}

/// Deterministic, headless real-time simulation engine for Parcel Escape: Food Maze Adventure (V3.2).
/// Handles smooth movement, wall collisions, food cargo & condition, 6 scary monster archetypes,
/// weapons/projectiles/abilities, shields, health recovery, collector & truck dock, and scoring.
class MazeGameEngine {
  static const double playerRadius = 0.28;
  static const double monsterRadius = 0.29;
  static const double pickupDistance = 0.58;
  static const double deliveryDistance = 0.72;
  static const double attackDistance = 0.58;
  static const double playerInvulnDuration = 1.65;
  static const double monsterAttackCooldownDuration = 1.65;

  final MazeLevel level;
  MazeEngineCallbacks callbacks;
  bool autoTargetEnabled;

  // Game phase & timer (Authoritative State Machine)
  MazeGamePhase phase = MazeGamePhase.playing;
  MazeGamePhase _phaseBeforePause = MazeGamePhase.playing;
  DefeatReason defeatReason = DefeatReason.none;
  double remainingTime = 0.0;
  double elapsedTime = 0.0;
  int _lastCriticalSecond = -1;

  // V3.3 Monster Cage, Winding Road & Truck Defense simulation
  late TruckDefenseSimulation truckDefense;

  // Player state
  double playerX = 0.5;
  double playerY = 0.5;
  double playerFacingAngle = 0.0;
  bool playerIsMoving = false;
  double playerMoveSpeedRatio = 0.0;
  double walkAnimPhase = 0.0;
  int health = 3;
  final int maxHealth = 3;
  bool hasShield = false;
  double invulnerabilityTimer = 0.0;
  double damageFlashTimer = 0.0;
  double healAnimTimer = 0.0;
  double pickupAnimTimer = 0.0;
  double deliveryAnimTimer = 0.0;
  double attackAnimTimer = 0.0;
  static const double attackAnimDuration = 0.34;
  WeaponType? lastUsedWeapon;
  double poisonSlowTimer = 0.0;
  double _cargoFullCooldown = 0.0;
  int cleanDeliveriesSinceDamage = 0;
  bool deliveryHealGranted = false;

  // Combat inventory & cooldowns
  late List<WeaponType> unlockedWeapons;
  WeaponType activePrimaryWeapon = WeaponType.melee;
  WeaponType? activeSpecialWeapon;
  final Map<WeaponType, int> weaponAmmo = {};
  final Map<WeaponType, double> weaponCooldowns = {};

  // Input & V3.5 Drag-to-Move / Tap-to-Move Route State
  double _inputDx = 0.0;
  double _inputDy = 0.0;
  List<GridPoint> _tapMovePath = [];
  bool isDrawingRoute = false;
  final List<GridPoint> draftRouteCells = [];
  double? invalidDragWorldX;
  double? invalidDragWorldY;
  GridPoint? autoRouteGoalCell;
  String? routeFeedbackMessage;
  double _routeFeedbackTimer = 0.0;

  // World entities
  late List<FoodItem> foods;
  late List<MonsterEntity> monsters;
  late List<HealthPickupItem> healthPickups;
  late List<CombatPickupItem> combatPickups;
  final List<ProjectileEntity> projectiles = [];
  final List<FoodDecoyEntity> decoys = [];
  final List<PoisonCloudEntity> poisonClouds = [];
  final List<CombatVfx> vfx = [];
  final List<FloatingPopup> popups = [];

  // Collector & Truck state
  CollectorAnimState collectorState = CollectorAnimState.waiting;
  double collectorAnimTimer = 0.0;
  FoodType? collectorCarryingFoodType;
  double collectorSmileTimer = 0.0;
  TruckAnimState truckState = TruckAnimState.waiting;
  double truckAnimTimer = 0.0;
  double truckDriveOffset = 0.0;
  final List<FoodItem> truckLoadedFoods = [];

  // Hint guidance state (strictly on-demand)
  List<GridPoint> hintPath = [];
  String? hintMessage;
  double hintTimer = 0.0;

  // Scoring & single-award guard
  MazeScoreBreakdown? finalBreakdown;
  bool _completionAwarded = false;

  MazeGameEngine({
    required this.level,
    this.callbacks = const MazeEngineCallbacks(),
    this.autoTargetEnabled = true,
  }) {
    reset();
  }

  /// Resets the engine to the exact initial state of [level].
  void reset() {
    phase = MazeGamePhase.playing;
    _phaseBeforePause = MazeGamePhase.playing;
    defeatReason = DefeatReason.none;
    remainingTime = level.timeLimitSeconds.toDouble();
    elapsedTime = 0.0;
    _lastCriticalSecond = -1;

    truckDefense = TruckDefenseSimulation(
      config: level.truckDefenseConfig,
      callbacks: TruckDefenseCallbacks(
        onCageWarning: () => callbacks.onCargoFull?.call(),
        onCageBreakOpen: () => callbacks.onCageBreakOpen?.call(),
        onKnifeDrawn: () => callbacks.onCargoFull?.call(),
        onTruckEngineStart: () => callbacks.onTruckEngineStart?.call(),
        onTruckDamaged: (dmg, isTire) =>
            callbacks.onTruckDamaged?.call(dmg, isTire),
        onTruckRepaired: (healed) => callbacks.onTruckRepaired?.call(healed),
        onBossHit: (dmg, defeated) => callbacks.onBossHit?.call(dmg, defeated),
        onAllySlash: () => callbacks.onAllySlash?.call(),
        onShieldBlocked: () => callbacks.onShieldBlocked?.call(),
      ),
    );

    playerX = level.playerStart.centerX;
    playerY = level.playerStart.centerY;
    playerFacingAngle = 0.0;
    playerIsMoving = false;
    playerMoveSpeedRatio = 0.0;
    walkAnimPhase = 0.0;
    health = maxHealth;
    hasShield = false;
    invulnerabilityTimer = 0.0;
    damageFlashTimer = 0.0;
    healAnimTimer = 0.0;
    pickupAnimTimer = 0.0;
    deliveryAnimTimer = 0.0;
    attackAnimTimer = 0.0;
    lastUsedWeapon = null;
    poisonSlowTimer = 0.0;
    _cargoFullCooldown = 0.0;
    cleanDeliveriesSinceDamage = 0;
    deliveryHealGranted = false;

    // Determine unlocked weapons strictly by campaign progression (Section 10)
    unlockedWeapons = WeaponType.values
        .where((w) => level.id >= w.unlockLevel)
        .toList();

    weaponAmmo.clear();
    weaponCooldowns.clear();
    for (final w in unlockedWeapons) {
      weaponAmmo[w] = w.startingAmmo;
      weaponCooldowns[w] = 0.0;
    }

    if (unlockedWeapons.contains(WeaponType.bow)) {
      activePrimaryWeapon = WeaponType.bow;
    } else {
      activePrimaryWeapon = WeaponType.melee;
    }

    // Special slot defaults to Freeze Orb -> Food Decoy -> Stun Pulse -> Melee
    if (unlockedWeapons.contains(WeaponType.freezeOrb)) {
      activeSpecialWeapon = WeaponType.freezeOrb;
    } else if (unlockedWeapons.contains(WeaponType.foodDecoy)) {
      activeSpecialWeapon = WeaponType.foodDecoy;
    } else if (unlockedWeapons.contains(WeaponType.stunPulse)) {
      activeSpecialWeapon = WeaponType.stunPulse;
    } else if (unlockedWeapons.contains(WeaponType.melee) &&
        activePrimaryWeapon != WeaponType.melee) {
      activeSpecialWeapon = WeaponType.melee;
    } else {
      activeSpecialWeapon = null;
    }

    _inputDx = 0.0;
    _inputDy = 0.0;
    _tapMovePath = [];
    isDrawingRoute = false;
    draftRouteCells.clear();
    invalidDragWorldX = null;
    invalidDragWorldY = null;
    autoRouteGoalCell = null;
    routeFeedbackMessage = null;
    _routeFeedbackTimer = 0.0;

    foods = level.foods.map((f) => f.createRuntimeItem()).toList();
    monsters = [
      for (int i = 0; i < level.monsters.length; i++)
        level.monsters[i].createRuntimeEntity(levelId: level.id, slotIndex: i),
    ];
    healthPickups =
        level.healthPickups.map((h) => h.createRuntimeItem()).toList();
    combatPickups =
        level.combatPickups.map((c) => c.createRuntimeItem()).toList();
    projectiles.clear();
    decoys.clear();
    poisonClouds.clear();
    vfx.clear();
    popups.clear();

    collectorState = CollectorAnimState.waiting;
    collectorAnimTimer = 0.0;
    collectorCarryingFoodType = null;
    collectorSmileTimer = 0.0;
    truckState = TruckAnimState.waiting;
    truckAnimTimer = 0.0;
    truckDriveOffset = 0.0;
    truckLoadedFoods.clear();

    hintPath = [];
    hintMessage = null;
    hintTimer = 0.0;

    finalBreakdown = null;
    _completionAwarded = false;
  }

  // --- Queries ---

  bool get hasCombatUnlocked => unlockedWeapons.isNotEmpty;

  List<WeaponType> get unlockedPrimaryWeapons {
    final list = <WeaponType>[];
    if (unlockedWeapons.contains(WeaponType.bow)) list.add(WeaponType.bow);
    if (unlockedWeapons.contains(WeaponType.energyBlaster)) {
      list.add(WeaponType.energyBlaster);
    }
    if (list.isEmpty && unlockedWeapons.contains(WeaponType.melee)) {
      list.add(WeaponType.melee);
    }
    return list;
  }

  List<WeaponType> get unlockedSpecialAbilities {
    final list = <WeaponType>[];
    if (unlockedWeapons.contains(WeaponType.freezeOrb)) {
      list.add(WeaponType.freezeOrb);
    }
    if (unlockedWeapons.contains(WeaponType.foodDecoy)) {
      list.add(WeaponType.foodDecoy);
    }
    if (unlockedWeapons.contains(WeaponType.stunPulse)) {
      list.add(WeaponType.stunPulse);
    }
    if (unlockedWeapons.contains(WeaponType.melee) &&
        activePrimaryWeapon != WeaponType.melee) {
      list.add(WeaponType.melee);
    }
    return list;
  }

  int ammoFor(WeaponType w) => weaponAmmo[w] ?? 0;
  double cooldownFor(WeaponType w) => weaponCooldowns[w] ?? 0.0;
  double cooldownRatioFor(WeaponType w) {
    final cd = cooldownFor(w);
    if (cd <= 0 || w.cooldownSeconds <= 0) return 0.0;
    return (cd / w.cooldownSeconds).clamp(0.0, 1.0);
  }

  GridPoint get playerCell => GridPoint(playerX.floor(), playerY.floor());

  List<FoodItem> get onMapFoods =>
      foods.where((f) => f.status == FoodStatus.onMap).toList();

  List<FoodItem> get carriedFoods =>
      foods.where((f) => f.status == FoodStatus.carried).toList();

  List<FoodItem> get deliveredFoods =>
      foods.where((f) => f.status == FoodStatus.delivered).toList();

  List<FoodItem> get consumedFoods =>
      foods.where((f) => f.status == FoodStatus.consumed).toList();

  List<HealthPickupItem> get activeHealthPickups =>
      healthPickups.where((h) => !h.collected).toList();

  List<CombatPickupItem> get activeCombatPickups =>
      combatPickups.where((c) => !c.collected).toList();

  List<MonsterEntity> get aliveMonsters =>
      monsters.where((m) => !m.isDefeated).toList();

  bool get isCargoFull => carriedFoods.length >= level.cargoCapacity;

  int get totalOriginalQuantity =>
      foods.fold<int>(0, (sum, f) => sum + f.maxQuantity);

  int get totalDeliveredQuantity =>
      deliveredFoods.fold<int>(0, (sum, f) => sum + f.remainingQuantity);

  int get deliveredQuantityPercent {
    final total = totalOriginalQuantity;
    if (total <= 0) return 100;
    return ((totalDeliveredQuantity * 100) / total).round().clamp(0, 100);
  }

  int get maxAchievableQuantityPercent {
    final total = totalOriginalQuantity;
    if (total <= 0) return 100;
    final remaining = foods
        .where((f) => f.status != FoodStatus.consumed)
        .fold<int>(0, (sum, f) => sum + f.remainingQuantity);
    return ((remaining * 100) / total).round().clamp(0, 100);
  }

  int get liveDeliveredFoodScore =>
      deliveredFoods.fold<int>(0, (sum, f) => sum + f.earnedPoints);

  /// Active countdown seconds shown in the top header (Maze Timer during Stage 1,
  /// separate Defense Timer during Stage 2!).
  double get activeDisplayRemainingTime => phase.isRoadBattleView
      ? truckDefense.defenseRemainingTime
      : remainingTime;

  TimerUrgency get timerUrgency {
    final t = activeDisplayRemainingTime;
    if (t <= 10.0) return TimerUrgency.critical;
    final budget = phase.isRoadBattleView
        ? truckDefense.config.defenseTimeLimitSeconds
        : level.timeLimitSeconds;
    final ratio = budget > 0 ? t / budget : 1.0;
    if (ratio <= 0.35) return TimerUrgency.warning;
    return TimerUrgency.normal;
  }

  List<GridPoint> get activeTapPath => List.unmodifiable(_tapMovePath);

  /// Builds the authoritative V3.4 state-driven animation snapshot & facial expression
  /// for the playable Human Courier (used in BOTH Maze Stage & Truck Defense Arena!).
  CourierAnimSnapshot buildCourierAnimSnapshot() {
    final bool inRoad = phase.isRoadBattleView;
    final double facing =
        inRoad ? truckDefense.playerFacingAngle : playerFacingAngle;
    final double speedRatio =
        inRoad ? truckDefense.playerMoveSpeedRatio : playerMoveSpeedRatio;
    final double walkPhase =
        inRoad ? truckDefense.playerWalkPhase : walkAnimPhase;

    // Check if an enemy is approaching nearby (triggers Alert expression!)
    bool enemyNear = false;
    if (inRoad) {
      if (!truckDefense.boss.isDefeated && !truckDefense.boss.isCaged) {
        final dx = truckDefense.boss.x - truckDefense.playerX;
        final dy = truckDefense.boss.y - truckDefense.playerY;
        if (dx * dx + dy * dy <= 3.0 * 3.0) enemyNear = true;
      }
    } else {
      for (final m in monsters) {
        if (m.isDefeated) continue;
        final dx = m.x - playerX;
        final dy = m.y - playerY;
        if (dx * dx + dy * dy <= 2.5 * 2.5) {
          enemyNear = true;
          break;
        }
      }
    }

    // Priority-ordered animation state & expression resolution (Section 2 & 7)
    CourierAnimState state;
    CourierExpression expr;
    double stateProgress = 0.0;

    if (phase == MazeGamePhase.victory || phase == MazeGamePhase.truckArrived) {
      state = CourierAnimState.celebrate;
      expr = CourierExpression.excited;
    } else if (damageFlashTimer > 0) {
      state = CourierAnimState.hurt;
      expr = CourierExpression.pain;
      stateProgress = (1.0 - damageFlashTimer / 0.45).clamp(0.0, 1.0);
    } else if (attackAnimTimer > 0) {
      stateProgress =
          (1.0 - attackAnimTimer / attackAnimDuration).clamp(0.0, 1.0);
      expr = CourierExpression.determined;
      switch (lastUsedWeapon ?? activePrimaryWeapon) {
        case WeaponType.bow:
          state = stateProgress < 0.35
              ? CourierAnimState.aimBow
              : CourierAnimState.releaseBow;
          break;
        case WeaponType.energyBlaster:
          state = CourierAnimState.fireBlaster;
          break;
        case WeaponType.freezeOrb:
        case WeaponType.stunPulse:
        case WeaponType.foodDecoy:
          state = CourierAnimState.castOrb;
          break;
        case WeaponType.melee:
          state = CourierAnimState.meleeSlash;
          break;
      }
    } else if (deliveryAnimTimer > 0) {
      state = CourierAnimState.deliverFood;
      expr = CourierExpression.smiling;
      stateProgress = (1.0 - deliveryAnimTimer / 0.55).clamp(0.0, 1.0);
    } else if (pickupAnimTimer > 0) {
      state = CourierAnimState.pickupFood;
      expr = CourierExpression.happy;
      stateProgress = (1.0 - pickupAnimTimer / 0.35).clamp(0.0, 1.0);
    } else if (speedRatio > 0.55) {
      state = CourierAnimState.run;
      expr = health <= 1
          ? CourierExpression.worried
          : (enemyNear ? CourierExpression.alert : CourierExpression.focused);
    } else if (speedRatio > 0.05) {
      state = CourierAnimState.walk;
      expr = health <= 1
          ? CourierExpression.worried
          : (enemyNear ? CourierExpression.alert : CourierExpression.focused);
    } else {
      state = CourierAnimState.idle;
      expr = health <= 1
          ? CourierExpression.worried
          : (enemyNear ? CourierExpression.alert : CourierExpression.relaxed);
    }

    return CourierAnimSnapshot(
      state: state,
      expression: expr,
      facingAngle: facing,
      moveSpeedRatio: speedRatio,
      walkCyclePhase: walkPhase,
      stateProgress: stateProgress,
      elapsed: elapsedTime,
      equippedWeapon: (hasCombatUnlocked || inRoad) ? activePrimaryWeapon : null,
      activeAttackWeapon: attackAnimTimer > 0 ? lastUsedWeapon : null,
      hurtRecoilProgress: (damageFlashTimer / 0.45).clamp(0.0, 1.0),
      recoilDirX: -math.cos(facing),
      recoilDirY: -math.sin(facing),
      hasShield: hasShield,
      isInvulnerable: invulnerabilityTimer > 0,
      isPoisonSlowed: poisonSlowTimer > 0,
      isHealing: healAnimTimer > 0,
      carriedFoods: inRoad ? const [] : carriedFoods,
    );
  }

  /// Builds the authoritative V3.4 animation snapshot for the Peaceful Dock Worker
  /// during Stage 1 (Maze Gameplay & Cage Escape Cutscene).
  DockWorkerAnimSnapshot buildMazeDockWorkerAnimSnapshot() {
    if (truckDefense.ally.hasKnifeDrawn ||
        phase == MazeGamePhase.cageEscapeCutscene) {
      return truckDefense.buildRoadAllyAnimSnapshot(elapsedTime);
    }

    DockWorkerAnimState animState;
    DockWorkerExpression expr;
    double progress = 0.0;
    double facing = math.atan2(
      playerY - (level.rows + 0.5),
      playerX - level.exitCell.centerX,
    );

    if (phase == MazeGamePhase.foodLoadingComplete) {
      animState = DockWorkerAnimState.closingCargo;
      expr = DockWorkerExpression.working;
      progress = (truckDefense.phaseTimer /
              TruckDefenseSimulation.loadingCompleteDuration)
          .clamp(0.0, 1.0);
      facing = 0.0;
    } else if (collectorState == CollectorAnimState.receiving) {
      animState = DockWorkerAnimState.receivingFood;
      expr = DockWorkerExpression.working;
      progress = (1.0 - collectorAnimTimer / 0.42).clamp(0.0, 1.0);
      facing = -math.pi * 0.5;
    } else if (collectorState == CollectorAnimState.carryingToTruck) {
      final p = (1.0 - collectorAnimTimer / 0.55).clamp(0.0, 1.0);
      animState = p < 0.65
          ? DockWorkerAnimState.carryingToTruck
          : DockWorkerAnimState.loadingTruck;
      expr = DockWorkerExpression.working;
      progress = p;
      facing = 0.0;
    } else if (collectorSmileTimer > 0) {
      animState = DockWorkerAnimState.smilingAfterLoad;
      expr = DockWorkerExpression.smiling;
      progress = (1.0 - collectorSmileTimer / 1.1).clamp(0.0, 1.0);
    } else {
      // Friendly waiting & periodic wave when Courier approaches!
      final distToExit = math.sqrt(
        math.pow(playerX - level.exitCell.centerX, 2) +
            math.pow(playerY - level.exitCell.centerY, 2),
      );
      final shouldWave = distToExit < 3.5 || (elapsedTime % 5.0) > 3.6;
      animState = shouldWave
          ? DockWorkerAnimState.waving
          : DockWorkerAnimState.idleWaiting;
      expr = shouldWave
          ? DockWorkerExpression.smiling
          : DockWorkerExpression.friendly;
    }

    return DockWorkerAnimSnapshot(
      state: animState,
      expression: expr,
      facingAngle: facing,
      walkCyclePhase: elapsedTime * 9.0,
      stateProgress: progress,
      elapsed: elapsedTime,
      hasKnifeDrawn: false,
      carriedFoodType: collectorCarryingFoodType,
    );
  }

  // --- Controls & V3.5 Drag-to-Move / Tap-to-Move / Joystick Priority ---

  bool get isFollowingAutoRoute => _tapMovePath.isNotEmpty;

  /// Returns the currently active preview route (draft route while dragging,
  /// or remaining auto-move path once released!).
  List<GridPoint> get previewRouteCells => isDrawingRoute
      ? List.unmodifiable(draftRouteCells)
      : List.unmodifiable(_tapMovePath);

  void setJoystickInput(double dx, double dy) {
    final mag = math.sqrt(dx * dx + dy * dy);
    if (mag < 0.08) {
      _inputDx = 0.0;
      _inputDy = 0.0;
    } else {
      // Priority Rule (Section 9): Joystick immediately cancels any active auto-route or draft!
      _tapMovePath = [];
      autoRouteGoalCell = null;
      isDrawingRoute = false;
      draftRouteCells.clear();
      invalidDragWorldX = null;
      invalidDragWorldY = null;
      truckDefense.cancelActiveRoadRoute();
      truckDefense.cancelRoadRouteDraw();
      if (mag > 1.0) {
        _inputDx = dx / mag;
        _inputDy = dy / mag;
      } else {
        _inputDx = dx;
        _inputDy = dy;
      }
    }
  }

  /// Step 1 (Section 7): Begins Drag-to-Move route drawing when touching near the Courier.
  /// Uses a generous 1.45-tile touch radius so pixel-perfect contact is never needed.
  /// Does NOT move the Courier until the player releases their finger!
  bool beginRouteDraw(double worldX, double worldY) {
    if (phase != MazeGamePhase.playing) return false;
    final dx = worldX - playerX;
    final dy = worldY - playerY;
    if (dx * dx + dy * dy > 1.45 * 1.45) return false;

    isDrawingRoute = true;
    draftRouteCells
      ..clear()
      ..add(playerCell);
    invalidDragWorldX = null;
    invalidDragWorldY = null;
    routeFeedbackMessage = null;
    return true;
  }

  /// Step 2 & 3 (Section 7 & 12): Appends valid corridor cells along the player's finger drag.
  /// Respects walls strictly (never cuts through or teleports across walls!),
  /// allows tiny touchscreen slip snapping, and simplifies accidental double-backs cleanly.
  bool updateRouteDraw(double worldX, double worldY) {
    if (!isDrawingRoute || phase != MazeGamePhase.playing) return false;
    if (draftRouteCells.isEmpty) {
      draftRouteCells.add(playerCell);
    }

    // Clamp to maze bounds for validation
    final rawCol = worldX.floor();
    final rawRow = worldY.floor();
    GridPoint? targetCell;

    if (level.inBounds(rawCol, rawRow) && level.isWalkable(rawCol, rawRow)) {
      targetCell = GridPoint(rawCol, rawRow);
    } else if (rawRow >= level.rows &&
        (rawCol - level.exitCell.col).abs() <= 2) {
      // Dragging onto the bottom Delivery Dock snaps cleanly to the Dock exit cell!
      targetCell = level.exitCell;
    } else {
      // Minor touchscreen inaccuracy snap: check if an adjacent walkable corridor cell
      // lies within 0.48 tiles of the finger AND borders the current route tip!
      final tip = draftRouteCells.last;
      double bestDistSq = 0.52 * 0.52;
      for (final d in const [
        GridPoint(1, 0),
        GridPoint(-1, 0),
        GridPoint(0, 1),
        GridPoint(0, -1),
      ]) {
        final cand = GridPoint(tip.col + d.col, tip.row + d.row);
        if (!level.isWalkable(cand.col, cand.row)) continue;
        final ddx = worldX - cand.centerX;
        final ddy = worldY - cand.centerY;
        final dSq = ddx * ddx + ddy * ddy;
        if (dSq < bestDistSq) {
          bestDistSq = dSq;
          targetCell = cand;
        }
      }
    }

    if (targetCell == null) {
      // Finger hit a solid wall! Show red invalid-segment indicator & do NOT cross wall!
      invalidDragWorldX = worldX.clamp(0.0, level.cols.toDouble());
      invalidDragWorldY = worldY.clamp(0.0, level.rows.toDouble());
      return false;
    }

    final tip = draftRouteCells.last;
    if (targetCell == tip) {
      invalidDragWorldX = null;
      invalidDragWorldY = null;
      return true;
    }

    // Backtracking / Loop Simplification (Section 12):
    // If finger drags back over an earlier cell in the drawn route, trim back cleanly!
    final existingIdx = draftRouteCells.indexOf(targetCell);
    if (existingIdx >= 0) {
      draftRouteCells.removeRange(existingIdx + 1, draftRouteCells.length);
      invalidDragWorldX = null;
      invalidDragWorldY = null;
      return true;
    }

    // 4-way adjacent walkable step: append directly!
    if (tip.manhattanTo(targetCell) == 1) {
      draftRouteCells.add(targetCell);
      invalidDragWorldX = null;
      invalidDragWorldY = null;
      return true;
    }

    // Fast finger drag across multiple corridor cells:
    // Connect along short walkable corridor ONLY if unobstructed (<= 5 corridor steps)
    // so walls are NEVER crossed and the user's chosen branch is NEVER silently replaced!
    final bridge = MazePathfinder.findPath(level, tip, targetCell);
    if (bridge.length >= 2 && bridge.length <= 6) {
      for (int i = 1; i < bridge.length; i++) {
        final stepCell = bridge[i];
        final backIdx = draftRouteCells.indexOf(stepCell);
        if (backIdx >= 0) {
          draftRouteCells.removeRange(backIdx + 1, draftRouteCells.length);
        } else {
          draftRouteCells.add(stepCell);
        }
      }
      invalidDragWorldX = null;
      invalidDragWorldY = null;
      return true;
    }

    // Wall separates tip from dragged finger -> show red invalid path indicator!
    invalidDragWorldX = worldX.clamp(0.0, level.cols.toDouble());
    invalidDragWorldY = worldY.clamp(0.0, level.rows.toDouble());
    return false;
  }

  /// Step 4 (Section 7): Releases finger, commits valid multi-turn route, and starts auto-movement!
  bool commitRouteDraw() {
    if (!isDrawingRoute) return false;
    isDrawingRoute = false;
    invalidDragWorldX = null;
    invalidDragWorldY = null;

    if (draftRouteCells.length <= 1) {
      draftRouteCells.clear();
      return false;
    }

    _tapMovePath = draftRouteCells.sublist(1);
    autoRouteGoalCell = draftRouteCells.last;
    draftRouteCells.clear();
    return true;
  }

  void cancelRouteDraw() {
    isDrawingRoute = false;
    draftRouteCells.clear();
    invalidDragWorldX = null;
    invalidDragWorldY = null;
  }

  void cancelAutoRoute() {
    _tapMovePath = [];
    autoRouteGoalCell = null;
  }

  /// Optional Tap-to-Move (Section 8): computes shortest walkable path via BFS/A*.
  bool setTapTarget(GridPoint targetCell) {
    if (phase != MazeGamePhase.playing) return false;
    if (!level.isWalkable(targetCell.col, targetCell.row)) return false;
    cancelRouteDraw();
    final path = MazePathfinder.findPath(level, playerCell, targetCell);
    if (path.length <= 1) {
      _tapMovePath = [];
      autoRouteGoalCell = null;
      return false;
    }
    _tapMovePath = path.sublist(1);
    autoRouteGoalCell = targetCell;
    return true;
  }

  /// Cycles active primary weapon (Bow <-> Energy Blaster) when multiple are unlocked.
  void cyclePrimaryWeapon() {
    final primaries = unlockedPrimaryWeapons;
    if (primaries.length <= 1) return;
    final idx = primaries.indexOf(activePrimaryWeapon);
    activePrimaryWeapon = primaries[(idx + 1) % primaries.length];
  }

  /// Cycles active special ability (Freeze Orb -> Food Decoy -> Stun Pulse -> Push Strike).
  void cycleSpecialWeapon() {
    final specials = unlockedSpecialAbilities;
    if (specials.length <= 1) return;
    final idx = activeSpecialWeapon != null
        ? specials.indexOf(activeSpecialWeapon!)
        : -1;
    activeSpecialWeapon = specials[(idx + 1) % specials.length];
  }

  /// Triggers the main Attack button (uses active primary weapon; gracefully falls back
  /// to close-range Push Strike if ranged ammo is empty!).
  /// Active in BOTH Maze Gameplay and Truck Defense Boss Battle!
  bool triggerPrimaryAttack() {
    if ((phase != MazeGamePhase.playing &&
            phase != MazeGamePhase.truckDefensePlaying) ||
        !hasCombatUnlocked) {
      return false;
    }
    var weapon = activePrimaryWeapon;
    if (weapon.startingAmmo > 0 && ammoFor(weapon) <= 0) {
      if (unlockedWeapons.contains(WeaponType.melee)) {
        weapon = WeaponType.melee;
      } else {
        return false;
      }
    }
    return useWeapon(weapon);
  }

  /// Triggers the Special Ability button.
  bool triggerSpecialAttack() {
    if ((phase != MazeGamePhase.playing &&
            phase != MazeGamePhase.truckDefensePlaying) ||
        activeSpecialWeapon == null) {
      return false;
    }
    return useWeapon(activeSpecialWeapon!);
  }

  /// Executes [weapon] if unlocked, off cooldown, and with sufficient ammo.
  /// Works simultaneously while moving with the joystick in BOTH phases!
  bool useWeapon(WeaponType weapon) {
    if (phase != MazeGamePhase.playing &&
        phase != MazeGamePhase.truckDefensePlaying) {
      return false;
    }
    if (!unlockedWeapons.contains(weapon)) return false;
    if (cooldownFor(weapon) > 0.0) return false;
    if (weapon.startingAmmo > 0 && ammoFor(weapon) <= 0) {
      final px = phase == MazeGamePhase.truckDefensePlaying
          ? truckDefense.playerX
          : playerX;
      final py = phase == MazeGamePhase.truckDefensePlaying
          ? truckDefense.playerY
          : playerY;
      final popupTarget = phase == MazeGamePhase.truckDefensePlaying
          ? truckDefense.popups
          : popups;
      popupTarget.add(FloatingPopup(
        text: 'Out of ${weapon.displayName}!',
        worldX: px,
        worldY: py - 0.55,
        colorHex: 0xFFFF715B,
        lifetime: 0.9,
      ));
      return false;
    }

    // Consume ammo & enforce cooldown strictly before effect
    if (weapon.startingAmmo > 0) {
      weaponAmmo[weapon] = math.max(0, ammoFor(weapon) - 1);
    }
    weaponCooldowns[weapon] = weapon.cooldownSeconds;
    attackAnimTimer = attackAnimDuration;
    lastUsedWeapon = weapon;

    // Route weapon execution cleanly to Road Battle Arena during Truck Defense!
    if (phase == MazeGamePhase.truckDefensePlaying) {
      truckDefense.executePlayerWeapon(
        weapon: weapon,
        autoTargetEnabled: autoTargetEnabled,
      );
      callbacks.onWeaponFired?.call(weapon);
      return true;
    }

    // Determine aim angle (optional auto-targeting with LOS check!)
    double aimAngle = playerFacingAngle;
    if (autoTargetEnabled &&
        (weapon.isProjectile || weapon == WeaponType.melee)) {
      final target = _findBestAutoTarget(weapon.rangeTiles);
      if (target != null) {
        aimAngle = math.atan2(target.y - playerY, target.x - playerX);
        playerFacingAngle = aimAngle;
      }
    }

    switch (weapon) {
      case WeaponType.melee:
        _performMeleeStrike(aimAngle);
        break;
      case WeaponType.bow:
      case WeaponType.energyBlaster:
      case WeaponType.freezeOrb:
        _spawnProjectile(weapon, aimAngle);
        break;
      case WeaponType.stunPulse:
        _performStunPulse();
        break;
      case WeaponType.foodDecoy:
        _dropFoodDecoy();
        break;
    }

    callbacks.onWeaponFired?.call(weapon);
    return true;
  }

  MonsterEntity? _findBestAutoTarget(double maxRange) {
    MonsterEntity? best;
    double bestDist = maxRange + 0.001;
    for (final m in monsters) {
      if (m.isDefeated) continue;
      final dx = m.x - playerX;
      final dy = m.y - playerY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= maxRange && dist < bestDist) {
        if (MazePathfinder.hasLineOfSight(level, playerX, playerY, m.x, m.y)) {
          bestDist = dist;
          best = m;
        }
      }
    }
    return best;
  }

  void _spawnProjectile(WeaponType weapon, double angle) {
    final speed = weapon.projectileSpeed;
    // Launch directly from bow-tip / blaster muzzle while never clipping into a solid wall
    double offset = weapon == WeaponType.bow ? 0.36 : 0.34;
    double sx = playerX + math.cos(angle) * offset;
    double sy = playerY + math.sin(angle) * offset;
    if (level.isWall(sx.floor(), sy.floor())) {
      sx = playerX + math.cos(angle) * 0.16;
      sy = playerY + math.sin(angle) * 0.16;
    }
    projectiles.add(ProjectileEntity(
      weapon: weapon,
      x: sx,
      y: sy,
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
      angle: angle,
      damage: weapon.baseDamage,
      remainingRange: weapon.rangeTiles,
    ));
    vfx.add(CombatVfx(
      type: CombatVfxType.hitBurst,
      x: sx,
      y: sy,
      maxRadius: 0.24,
      colorHex: weapon.colorHex,
      duration: 0.15,
    ));
  }

  void _performMeleeStrike(double angle) {
    vfx.add(CombatVfx(
      type: CombatVfxType.meleeSlash,
      x: playerX + math.cos(angle) * 0.45,
      y: playerY + math.sin(angle) * 0.45,
      angle: angle,
      maxRadius: 0.95,
      colorHex: WeaponType.melee.colorHex,
      duration: 0.24,
    ));

    for (final m in monsters) {
      if (m.isDefeated) continue;
      final dx = m.x - playerX;
      final dy = m.y - playerY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= WeaponType.melee.rangeTiles &&
          MazePathfinder.hasLineOfSight(level, playerX, playerY, m.x, m.y)) {
        final kbDir = dist > 0.01 ? math.atan2(dy, dx) : angle;
        _damageMonster(
          m,
          WeaponType.melee.baseDamage,
          weapon: WeaponType.melee,
          knockbackAngle: kbDir,
          knockbackForce: 4.5,
          stunDuration: 0.55,
        );
      }
    }
  }

  void _performStunPulse() {
    vfx.add(CombatVfx(
      type: CombatVfxType.stunPulseRing,
      x: playerX,
      y: playerY,
      maxRadius: WeaponType.stunPulse.rangeTiles,
      colorHex: WeaponType.stunPulse.colorHex,
      duration: 0.38,
    ));

    for (final m in monsters) {
      if (m.isDefeated) continue;
      final dx = m.x - playerX;
      final dy = m.y - playerY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= WeaponType.stunPulse.rangeTiles &&
          MazePathfinder.hasLineOfSight(level, playerX, playerY, m.x, m.y)) {
        final kbDir = dist > 0.01 ? math.atan2(dy, dx) : playerFacingAngle;
        _damageMonster(
          m,
          WeaponType.stunPulse.baseDamage,
          weapon: WeaponType.stunPulse,
          knockbackAngle: kbDir,
          knockbackForce: 5.5,
          stunDuration: 2.2,
        );
      }
    }
  }

  void _dropFoodDecoy() {
    decoys.add(FoodDecoyEntity(x: playerX, y: playerY));
    popups.add(FloatingPopup(
      text: 'Food Decoy!',
      worldX: playerX,
      worldY: playerY - 0.5,
      colorHex: 0xFF2E7D32,
      lifetime: 1.0,
    ));
  }

  void _damageMonster(
    MonsterEntity m,
    int rawDamage, {
    required WeaponType weapon,
    required double knockbackAngle,
    double knockbackForce = 2.6,
    double stunDuration = 0.0,
    double freezeDuration = 0.0,
  }) {
    if (m.isDefeated) return;

    // Shadow Crawler weakness: 1.5x vulnerability to Magic Energy Blaster light shots!
    int dmg = rawDamage;
    String? bonusTag;
    if (weapon == WeaponType.energyBlaster &&
        m.type == MonsterType.shadowCrawler) {
      dmg = (rawDamage * 1.5).round();
      bonusTag = 'SUPER!';
    }

    m.hp = math.max(0, m.hp - dmg);
    m.hitFlashTimer = 0.22;
    m.hpBarTimer = 3.2;

    // Knockback scaled by resistance
    final kbScale = (1.0 - m.stunResistance * 0.7).clamp(0.25, 1.0);
    m.knockbackVx = math.cos(knockbackAngle) * knockbackForce * kbScale;
    m.knockbackVy = math.sin(knockbackAngle) * knockbackForce * kbScale;

    // Freeze effect (reduced on powerful monsters via stunResistance)
    if (freezeDuration > 0) {
      final effFreeze =
          (freezeDuration * (1.0 - m.stunResistance * 0.65)).clamp(1.0, 4.0);
      m.freezeTimer = math.max(m.freezeTimer, effFreeze);
      vfx.add(CombatVfx(
        type: CombatVfxType.freezeBurst,
        x: m.x,
        y: m.y,
        maxRadius: 0.75,
        colorHex: 0xFF38BDF8,
        duration: 0.35,
      ));
      popups.add(FloatingPopup(
        text: 'FROZEN!',
        worldX: m.x,
        worldY: m.y - 0.65,
        colorHex: 0xFF0284C7,
        lifetime: 1.0,
      ));
    } else if (stunDuration > 0) {
      final effStun =
          (stunDuration * (1.0 - m.stunResistance * 0.6)).clamp(0.2, 3.0);
      m.stunTimer = math.max(m.stunTimer, effStun);
      m.state = MonsterAiState.stunned;
      m.stateTimer = 0.0;
    }

    vfx.add(CombatVfx(
      type: CombatVfxType.hitBurst,
      x: m.x,
      y: m.y,
      maxRadius: 0.55,
      colorHex: weapon.colorHex,
      duration: 0.26,
    ));

    if (m.hp <= 0) {
      m.state = MonsterAiState.defeated;
      m.defeatAnimTimer = 0.45;
      m.freezeTimer = 0.0;
      m.stunTimer = 0.0;
      vfx.add(CombatVfx(
        type: CombatVfxType.defeatPuff,
        x: m.x,
        y: m.y,
        maxRadius: 0.95,
        colorHex: 0xFFFFC857,
        duration: 0.45,
      ));
      popups.add(FloatingPopup(
        text: 'Defeated!',
        worldX: m.x,
        worldY: m.y - 0.55,
        colorHex: 0xFFFF9F1C,
        lifetime: 1.2,
      ));
      callbacks.onMonsterHit?.call(m, dmg, true);
    } else {
      popups.add(FloatingPopup(
        text: bonusTag != null ? '-$dmg $bonusTag' : '-$dmg',
        worldX: m.x,
        worldY: m.y - 0.45,
        colorHex: bonusTag != null ? 0xFF9333EA : 0xFFE63946,
        lifetime: 0.85,
      ));
      // React to being attacked: alert/chase if idle or patrolling
      if (m.state == MonsterAiState.idle || m.state == MonsterAiState.patrol) {
        m.state = MonsterAiState.chase;
        m.stateTimer = 0.0;
      }
      callbacks.onMonsterHit?.call(m, dmg, false);
    }
  }

  void pause() {
    if (phase == MazeGamePhase.playing ||
        phase == MazeGamePhase.foodLoadingComplete ||
        phase == MazeGamePhase.cageEscapeCutscene ||
        phase == MazeGamePhase.truckDefensePlaying) {
      _phaseBeforePause = phase;
      phase = MazeGamePhase.paused;
      _inputDx = 0.0;
      _inputDy = 0.0;
      cancelRouteDraw();
      truckDefense.cancelRoadRouteDraw();
    }
  }

  void resume() {
    if (phase == MazeGamePhase.paused) {
      phase = _phaseBeforePause;
    }
  }

  void requestHint() {
    if (phase == MazeGamePhase.truckDefensePlaying) {
      hintPath = [];
      hintMessage = !truckDefense.repairKit.collected &&
              truckDefense.truck.hp < 85
          ? 'Grab the green Repair Kit beside the road to heal the truck!'
          : 'Defend the truck with your weapons — shoot bombs or stun the boss!';
      hintTimer = 3.2;
      return;
    }
    if (phase != MazeGamePhase.playing) return;

    GridPoint target;
    String msg;

    if (isCargoFull || onMapFoods.isEmpty) {
      target = level.exitCell;
      msg = 'Deliver to the Collector at the bottom dock!';
    } else {
      FoodItem? nearest;
      int bestDist = 999999;
      for (final f in onMapFoods) {
        final d = MazePathfinder.shortestSteps(
          level,
          playerCell,
          GridPoint(f.spawnCol, f.spawnRow),
        );
        if (d >= 0 && d < bestDist) {
          bestDist = d;
          nearest = f;
        }
      }
      if (nearest != null) {
        target = GridPoint(nearest.spawnCol, nearest.spawnRow);
        msg = 'Collect the ${nearest.type.displayName} — watch out for monsters!';
      } else {
        target = level.exitCell;
        msg = 'Deliver your cargo to the Collector at the bottom dock!';
      }
    }

    hintPath = MazePathfinder.findPath(level, playerCell, target);
    hintMessage = msg;
    hintTimer = 3.2;
  }

  void dismissHint() {
    hintPath = [];
    hintMessage = null;
    hintTimer = 0.0;
  }

  /// Skips the short cage-escape cutscene straight into active Truck Defense
  /// (or finishes the arrival celebration if the truck already arrived).
  /// Never skips the Truck Defense battle itself!
  void skipEscapeCutscene() {
    if (phase == MazeGamePhase.foodLoadingComplete ||
        phase == MazeGamePhase.cageEscapeCutscene) {
      truckDefense.skipCutscene();
      _enterTruckDefensePlaying();
    } else if (phase == MazeGamePhase.truckArrived) {
      truckState = TruckAnimState.arrived;
      _finalizeVictory();
    }
  }

  /// Backwards-compatible alias for skipping active transition cutscenes.
  void skipTruckAnimation() => skipEscapeCutscene();

  // --- Simulation Step ---

  void step(double dtSeconds) {
    if (dtSeconds <= 0) return;
    final dt = dtSeconds.clamp(0.0, 0.05);

    if (phase == MazeGamePhase.paused ||
        phase == MazeGamePhase.victory ||
        phase == MazeGamePhase.defeat) {
      return;
    }

    elapsedTime += dt;

    for (final p in popups) {
      p.age += dt;
    }
    popups.removeWhere((p) => p.isExpired);

    for (final effect in vfx) {
      effect.age += dt;
    }
    vfx.removeWhere((e) => e.isExpired);

    if (_routeFeedbackTimer > 0) {
      _routeFeedbackTimer = (_routeFeedbackTimer - dt).clamp(0.0, 5.0);
      if (_routeFeedbackTimer <= 0) routeFeedbackMessage = null;
    }
    if (hintTimer > 0) {
      hintTimer = (hintTimer - dt).clamp(0.0, 10.0);
      if (hintTimer <= 0) {
        hintPath = [];
        hintMessage = null;
      }
    }

    if (collectorAnimTimer > 0) {
      collectorAnimTimer = (collectorAnimTimer - dt).clamp(0.0, 10.0);
      if (collectorAnimTimer <= 0 && phase == MazeGamePhase.playing) {
        if (collectorState == CollectorAnimState.receiving) {
          collectorState = CollectorAnimState.carryingToTruck;
          collectorAnimTimer = 0.55;
        } else if (collectorState == CollectorAnimState.carryingToTruck) {
          collectorState = CollectorAnimState.waiting;
          collectorCarryingFoodType = null;
          collectorSmileTimer = 1.1;
          truckState = TruckAnimState.waiting;
        }
      }
    }
    if (collectorSmileTimer > 0) {
      collectorSmileTimer = (collectorSmileTimer - dt).clamp(0.0, 5.0);
    }

    // --- V3.3 Multi-Phase State Machine Transitions ---
    if (phase == MazeGamePhase.foodLoadingComplete) {
      if (truckDefense.stepFoodLoadingComplete(dt)) {
        phase = MazeGamePhase.cageEscapeCutscene;
      }
      return;
    }

    if (phase == MazeGamePhase.cageEscapeCutscene) {
      if (truckDefense.ally.hasKnifeDrawn) {
        collectorState = CollectorAnimState.combatReady;
      } else if (truckDefense.cageState == BossCageState.lockBreaking) {
        collectorState = CollectorAnimState.surprised;
      }
      if (truckDefense.stepEscapeCutscene(dt)) {
        _enterTruckDefensePlaying();
      }
      return;
    }

    if (phase == MazeGamePhase.truckDefensePlaying) {
      _stepTruckDefensePhase(dt);
      return;
    }

    if (phase == MazeGamePhase.truckArrived) {
      if (truckDefense.stepTruckArrived(dt)) {
        _finalizeVictory();
      }
      return;
    }

    if (phase == MazeGamePhase.truckDestroyed) {
      if (truckDefense.stepTruckDestroyed(dt)) {
        _triggerDefeat(DefeatReason.truckDestroyed);
      }
      return;
    }

    // --- Stage 1: MAZE_PLAYING ---
    // Animate caged boss subtly shaking bars (cannot escape or attack!)
    truckDefense.stepIdleCage(dt);

    _stepCountdown(dt);
    if (phase != MazeGamePhase.playing) return;

    // Decrement timers & weapon cooldowns
    if (invulnerabilityTimer > 0) {
      invulnerabilityTimer = (invulnerabilityTimer - dt).clamp(0.0, 10.0);
    }
    if (damageFlashTimer > 0) {
      damageFlashTimer = (damageFlashTimer - dt).clamp(0.0, 10.0);
    }
    if (healAnimTimer > 0) {
      healAnimTimer = (healAnimTimer - dt).clamp(0.0, 10.0);
    }
    if (pickupAnimTimer > 0) {
      pickupAnimTimer = (pickupAnimTimer - dt).clamp(0.0, 10.0);
    }
    if (deliveryAnimTimer > 0) {
      deliveryAnimTimer = (deliveryAnimTimer - dt).clamp(0.0, 10.0);
    }
    if (attackAnimTimer > 0) {
      attackAnimTimer = (attackAnimTimer - dt).clamp(0.0, 10.0);
    }
    if (poisonSlowTimer > 0) {
      poisonSlowTimer = (poisonSlowTimer - dt).clamp(0.0, 5.0);
    }
    if (_cargoFullCooldown > 0) {
      _cargoFullCooldown = (_cargoFullCooldown - dt).clamp(0.0, 10.0);
    }
    for (final w in weaponCooldowns.keys.toList()) {
      final rem = (weaponCooldowns[w]! - dt).clamp(0.0, 30.0);
      weaponCooldowns[w] = rem;
    }

    // Update decoys & poison clouds
    for (final d in decoys) {
      d.remainingTime -= dt;
    }
    decoys.removeWhere((d) => d.isExpired);

    for (final cloud in poisonClouds) {
      cloud.remainingTime -= dt;
      final dx = playerX - cloud.x;
      final dy = playerY - cloud.y;
      if (dx * dx + dy * dy <= cloud.radius * cloud.radius) {
        poisonSlowTimer = 0.35;
      }
    }
    poisonClouds.removeWhere((c) => c.isExpired);

    _stepPlayerMovement(dt);
    _stepProjectiles(dt);
    _checkFoodPickups();
    _checkHealthPickups();
    _checkCombatPickups();
    _checkDeliveryEndpoint();
    if (phase != MazeGamePhase.playing) return;

    _stepMonsters(dt);
  }

  void _enterTruckDefensePlaying() {
    phase = MazeGamePhase.truckDefensePlaying;
    collectorState = CollectorAnimState.combatReady;
    truckState = TruckAnimState.drivingOnRoad;
    _tapMovePath = [];
    hintPath = [];
    hintMessage = null;
    _lastCriticalSecond = -1;

    // Ensure player ALWAYS has responsive combat options during Truck Defense
    // (including Levels 1-5 tutorial bosses!) while preserving unlocked progression.
    if (!unlockedWeapons.contains(WeaponType.melee)) {
      unlockedWeapons = [...unlockedWeapons, WeaponType.melee];
      weaponAmmo[WeaponType.melee] = -1;
      weaponCooldowns[WeaponType.melee] = 0.0;
    }
    if (!unlockedWeapons.contains(WeaponType.bow)) {
      unlockedWeapons = [...unlockedWeapons, WeaponType.bow];
      weaponAmmo[WeaponType.bow] = 10;
      weaponCooldowns[WeaponType.bow] = 0.0;
      activePrimaryWeapon = WeaponType.bow;
      activeSpecialWeapon ??= WeaponType.melee;
    } else {
      // Fair defense resupply: ensure at least 8 arrows when boss escapes!
      final curArrows = weaponAmmo[WeaponType.bow] ?? 0;
      if (curArrows < 8) {
        weaponAmmo[WeaponType.bow] = 8;
      }
    }
    if (unlockedWeapons.contains(WeaponType.energyBlaster)) {
      final curEnergy = weaponAmmo[WeaponType.energyBlaster] ?? 0;
      if (curEnergy < 4) weaponAmmo[WeaponType.energyBlaster] = 4;
    }
    if (unlockedWeapons.contains(WeaponType.freezeOrb)) {
      final curFreeze = weaponAmmo[WeaponType.freezeOrb] ?? 0;
      if (curFreeze < 2) weaponAmmo[WeaponType.freezeOrb] = 2;
    }
  }

  void _stepTruckDefensePhase(double dt) {
    if (invulnerabilityTimer > 0) {
      invulnerabilityTimer = (invulnerabilityTimer - dt).clamp(0.0, 10.0);
    }
    if (damageFlashTimer > 0) {
      damageFlashTimer = (damageFlashTimer - dt).clamp(0.0, 10.0);
    }
    if (attackAnimTimer > 0) {
      attackAnimTimer = (attackAnimTimer - dt).clamp(0.0, 10.0);
    }
    for (final w in weaponCooldowns.keys.toList()) {
      weaponCooldowns[w] = (weaponCooldowns[w]! - dt).clamp(0.0, 30.0);
    }

    // Critical defense timer tick sound
    final remDef = truckDefense.defenseRemainingTime;
    if (remDef > 0 && remDef <= 10.0) {
      final sec = remDef.ceil();
      if (sec != _lastCriticalSecond) {
        _lastCriticalSecond = sec;
        callbacks.onCriticalTick?.call();
      }
    }

    final outcome = truckDefense.stepDefense(
      dt: dt,
      inputDx: _inputDx,
      inputDy: _inputDy,
      playerHasShield: hasShield,
      playerIsInvulnerable: invulnerabilityTimer > 0,
      playerIsPoisonSlowed: false,
      attackAnimTimer: attackAnimTimer,
      onConsumePlayerShield: () {
        hasShield = false;
        invulnerabilityTimer = 1.2;
      },
      onHitPlayerHealth: () {
        invulnerabilityTimer = playerInvulnDuration;
        damageFlashTimer = 0.45;
        health = math.max(0, health - 1);
      },
    );

    // Sync Dock Worker state
    collectorState = truckDefense.ally.slashAnimTimer > 0
        ? CollectorAnimState.slashing
        : CollectorAnimState.combatReady;

    if (health <= 0) {
      _triggerDefeat(DefeatReason.healthDepleted);
      return;
    }

    if (outcome == 1) {
      phase = MazeGamePhase.truckArrived;
      truckState = TruckAnimState.arrived;
      collectorState = CollectorAnimState.celebrating;
      _inputDx = 0.0;
      _inputDy = 0.0;
    } else if (outcome == -1) {
      phase = MazeGamePhase.truckDestroyed;
      truckState = TruckAnimState.destroyed;
      _inputDx = 0.0;
      _inputDy = 0.0;
    } else if (outcome == -2) {
      truckState = TruckAnimState.destroyed;
      _triggerDefeat(DefeatReason.defenseTimeExpired);
    }
  }

  void _stepCountdown(double dt) {
    remainingTime = (remainingTime - dt).clamp(0.0, 9999.0);
    if (remainingTime > 0 && remainingTime <= 10.0) {
      final sec = remainingTime.ceil();
      if (sec != _lastCriticalSecond) {
        _lastCriticalSecond = sec;
        callbacks.onCriticalTick?.call();
      }
    }
    if (remainingTime <= 0.0) {
      remainingTime = 0.0;
      _triggerDefeat(DefeatReason.timeExpired);
    }
  }

  void _stepPlayerMovement(double dt) {
    double vx = _inputDx;
    double vy = _inputDy;

    if (vx == 0.0 && vy == 0.0 && _tapMovePath.isNotEmpty) {
      final nextCell = _tapMovePath.first;
      final tx = nextCell.centerX;
      final ty = nextCell.centerY;
      final dx = tx - playerX;
      final dy = ty - playerY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < 0.14) {
        _tapMovePath.removeAt(0);
      } else {
        vx = dx / dist;
        vy = dy / dist;
      }
    }

    final speedMag = math.sqrt(vx * vx + vy * vy).clamp(0.0, 1.0);
    if (speedMag > 0.01) {
      playerIsMoving = true;
      playerMoveSpeedRatio = speedMag;
      if (attackAnimTimer <= 0.05) {
        playerFacingAngle = math.atan2(vy, vx);
      }
      final slowFactor = poisonSlowTimer > 0 ? 0.58 : 1.0;
      walkAnimPhase += dt * (8.2 + speedMag * 5.8) * slowFactor;

      final moveDist = level.playerSpeed * slowFactor * dt;
      final targetX = playerX + vx * moveDist;
      final targetY = playerY + vy * moveDist;

      if (!_collidesWithWall(targetX, playerY, playerRadius)) {
        playerX = targetX;
      } else {
        final cellCenterY = playerY.floor() + 0.5;
        final dyCenter = cellCenterY - playerY;
        if (dyCenter.abs() > 0.03 && dyCenter.abs() < 0.35 && vy.abs() < 0.3) {
          final nudgeY = playerY +
              dyCenter.sign * math.min(moveDist * 0.7, dyCenter.abs());
          if (!_collidesWithWall(playerX, nudgeY, playerRadius)) {
            playerY = nudgeY;
          }
        }
      }

      if (!_collidesWithWall(playerX, targetY, playerRadius)) {
        playerY = targetY;
      } else {
        final cellCenterX = playerX.floor() + 0.5;
        final dxCenter = cellCenterX - playerX;
        if (dxCenter.abs() > 0.03 && dxCenter.abs() < 0.35 && vx.abs() < 0.3) {
          final nudgeX = playerX +
              dxCenter.sign * math.min(moveDist * 0.7, dxCenter.abs());
          if (!_collidesWithWall(nudgeX, playerY, playerRadius)) {
            playerX = nudgeX;
          }
        }
      }
    } else {
      playerIsMoving = false;
      playerMoveSpeedRatio = 0.0;
    }
  }

  void _stepProjectiles(double dt) {
    for (final p in projectiles) {
      if (!p.active) continue;
      final stepX = p.vx * dt;
      final stepY = p.vy * dt;
      final stepDist = math.sqrt(stepX * stepX + stepY * stepY);
      p.x += stepX;
      p.y += stepY;
      p.remainingRange -= stepDist;

      // Solid wall check — arrows/bolts/orbs strictly NEVER pass through walls!
      if (p.remainingRange <= 0 || level.isWall(p.x.floor(), p.y.floor())) {
        p.active = false;
        vfx.add(CombatVfx(
          type: CombatVfxType.hitBurst,
          x: p.x - stepX * 0.5,
          y: p.y - stepY * 0.5,
          maxRadius: 0.35,
          colorHex: p.weapon.colorHex,
          duration: 0.2,
        ));
        continue;
      }

      // Monster hit check
      for (final m in monsters) {
        if (m.isDefeated) continue;
        final dx = m.x - p.x;
        final dy = m.y - p.y;
        final hitR = monsterRadius * m.type.visualScale + 0.18;
        if (dx * dx + dy * dy <= hitR * hitR) {
          p.active = false;
          final stun = (p.weapon == WeaponType.bow &&
                  m.type == MonsterType.redHunter)
              ? 0.95
              : (p.weapon == WeaponType.bow ? 0.3 : 0.25);
          final freeze = p.weapon == WeaponType.freezeOrb ? 3.0 : 0.0;
          _damageMonster(
            m,
            p.damage,
            weapon: p.weapon,
            knockbackAngle: p.angle,
            knockbackForce: p.weapon == WeaponType.energyBlaster ? 3.4 : 2.2,
            stunDuration: freeze > 0 ? 0.0 : stun,
            freezeDuration: freeze,
          );
          break;
        }
      }
    }
    projectiles.removeWhere((p) => !p.active);
  }

  bool _collidesWithWall(double cx, double cy, double radius) {
    final minCol = (cx - radius).floor();
    final maxCol = (cx + radius).floor();
    final minRow = (cy - radius).floor();
    final maxRow = (cy + radius).floor();

    for (int r = minRow; r <= maxRow; r++) {
      for (int c = minCol; c <= maxCol; c++) {
        if (level.isWall(c, r)) {
          final closestX = cx.clamp(c.toDouble(), (c + 1).toDouble());
          final closestY = cy.clamp(r.toDouble(), (r + 1).toDouble());
          final dx = cx - closestX;
          final dy = cy - closestY;
          if (dx * dx + dy * dy < radius * radius - 1e-6) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _checkFoodPickups() {
    for (final item in foods) {
      if (item.status != FoodStatus.onMap) continue;
      final fx = item.spawnCol + 0.5;
      final fy = item.spawnRow + 0.5;
      final dx = playerX - fx;
      final dy = playerY - fy;
      if (math.sqrt(dx * dx + dy * dy) <= pickupDistance) {
        if (isCargoFull) {
          if (_cargoFullCooldown <= 0) {
            _cargoFullCooldown = 1.8;
            popups.add(FloatingPopup(
              text: 'Bag Full! (${carriedFoods.length}/${level.cargoCapacity})',
              worldX: playerX,
              worldY: playerY - 0.5,
              colorHex: 0xFFFF715B,
            ));
            callbacks.onCargoFull?.call();
          }
          continue;
        }
        item.status = FoodStatus.carried;
        pickupAnimTimer = 0.35;
        // Step 5 (Section 7): If the drawn auto-route targeted this food, complete route cleanly!
        if (autoRouteGoalCell != null &&
            autoRouteGoalCell!.col == item.spawnCol &&
            autoRouteGoalCell!.row == item.spawnRow) {
          _tapMovePath = [];
          autoRouteGoalCell = null;
        }
        popups.add(FloatingPopup(
          text: '+ ${item.type.displayName}',
          worldX: fx,
          worldY: fy - 0.35,
          colorHex: 0xFF2E7D32,
        ));
        callbacks.onFoodPickup?.call(item);
      }
    }
  }

  void _checkHealthPickups() {
    if (health >= maxHealth) return;
    for (final hp in healthPickups) {
      if (hp.collected) continue;
      final hx = hp.col + 0.5;
      final hy = hp.row + 0.5;
      final dx = playerX - hx;
      final dy = playerY - hy;
      if (math.sqrt(dx * dx + dy * dy) <= pickupDistance) {
        hp.collected = true;
        health = math.min(maxHealth, health + 1);
        healAnimTimer = 0.8;
        popups.add(FloatingPopup(
          text: '+1 Heart!',
          worldX: hx,
          worldY: hy - 0.45,
          colorHex: 0xFFE63946,
          lifetime: 1.3,
        ));
        callbacks.onHealthRestored?.call(health, 'pickup');
        if (health >= maxHealth) break;
      }
    }
  }

  void _checkCombatPickups() {
    for (final cp in combatPickups) {
      if (cp.collected) continue;
      final cx = cp.col + 0.5;
      final cy = cp.row + 0.5;
      final dx = playerX - cx;
      final dy = playerY - cy;
      if (math.sqrt(dx * dx + dy * dy) > pickupDistance) continue;

      if (cp.type == CombatPickupType.shield) {
        if (hasShield) continue; // Don't waste shield if already active!
        cp.collected = true;
        hasShield = true;
        popups.add(FloatingPopup(
          text: 'Shield Ready!',
          worldX: cx,
          worldY: cy - 0.45,
          colorHex: 0xFF0284C7,
          lifetime: 1.2,
        ));
        callbacks.onCombatPickup?.call(cp);
      } else {
        cp.collected = true;
        if (cp.type == CombatPickupType.arrows) {
          weaponAmmo[WeaponType.bow] =
              (weaponAmmo[WeaponType.bow] ?? 0) + cp.amount;
        } else if (cp.type == CombatPickupType.energyCharges) {
          weaponAmmo[WeaponType.energyBlaster] =
              (weaponAmmo[WeaponType.energyBlaster] ?? 0) + cp.amount;
        } else if (cp.type == CombatPickupType.freezeOrbs) {
          weaponAmmo[WeaponType.freezeOrb] =
              (weaponAmmo[WeaponType.freezeOrb] ?? 0) + cp.amount;
        }
        popups.add(FloatingPopup(
          text: cp.type.displayName,
          worldX: cx,
          worldY: cy - 0.45,
          colorHex: 0xFF7C3AED,
          lifetime: 1.1,
        ));
        callbacks.onCombatPickup?.call(cp);
      }
    }
  }

  void _checkDeliveryEndpoint() {
    final ex = level.exitCell.centerX;
    final ey = level.exitCell.centerY;
    final dx = playerX - ex;
    final dy = playerY - ey;
    if (math.sqrt(dx * dx + dy * dy) > deliveryDistance) return;

    final carried = carriedFoods;
    if (carried.isEmpty) return;

    int addedPoints = 0;
    final deliveredBatch = <FoodItem>[];
    for (final item in carried) {
      if (item.status == FoodStatus.carried && item.remainingQuantity > 0) {
        item.status = FoodStatus.delivered;
        deliveredBatch.add(item);
        truckLoadedFoods.add(item);
        addedPoints += item.earnedPoints;
      }
    }
    if (deliveredBatch.isEmpty) return;

    deliveryAnimTimer = 0.55;
    collectorState = CollectorAnimState.receiving;
    collectorAnimTimer = 0.42;
    collectorCarryingFoodType = deliveredBatch.first.type;
    truckState = TruckAnimState.loading;

    popups.add(FloatingPopup(
      text: 'Delivered +$addedPoints!',
      worldX: ex - 0.2,
      worldY: ey - 0.5,
      colorHex: 0xFF1B8A5A,
      lifetime: 1.35,
    ));

    callbacks.onFoodDelivered?.call(deliveredBatch, addedPoints);

    // Mechanic B — Careful Delivery Reward (once per level)
    cleanDeliveriesSinceDamage++;
    if (cleanDeliveriesSinceDamage >= 2 &&
        !deliveryHealGranted &&
        health < maxHealth) {
      deliveryHealGranted = true;
      health = math.min(maxHealth, health + 1);
      healAnimTimer = 0.85;
      popups.add(FloatingPopup(
        text: 'Careful Delivery! +1 Heart',
        worldX: ex,
        worldY: ey - 0.95,
        colorHex: 0xFFE63946,
        lifetime: 1.5,
      ));
      callbacks.onHealthRestored?.call(health, 'delivery');
    }

    _evaluateObjectiveCompletion();
  }

  void _evaluateObjectiveCompletion() {
    // Do NOT trigger boss escape while any collectable food still remains on map or in bag!
    // Completely eaten food has status == FoodStatus.consumed so it is properly ignored here.
    if (onMapFoods.isNotEmpty || carriedFoods.isNotEmpty) {
      if (maxAchievableQuantityPercent < level.minQuotaPercent) {
        _triggerDefeat(DefeatReason.insufficientFood);
      }
      return;
    }

    if (deliveredQuantityPercent >= level.minQuotaPercent &&
        health > 0 &&
        remainingTime > 0) {
      // Strictly trigger the Cage Escape & Truck Defense phase ONCE per run
      // (never unlock or complete the level immediately after loading food!).
      if (truckDefense.beginFoodLoadingComplete()) {
        phase = MazeGamePhase.foodLoadingComplete;
        _inputDx = 0.0;
        _inputDy = 0.0;
        _tapMovePath = [];
        collectorState = CollectorAnimState.surprised;
        truckState = TruckAnimState.closingDoors;
        truckAnimTimer = 0.0;
        truckDriveOffset = 0.0;
      }
    } else {
      _triggerDefeat(DefeatReason.insufficientFood);
    }
  }

  void _finalizeVictory() {
    if (_completionAwarded) return;
    _completionAwarded = true;
    phase = MazeGamePhase.victory;
    finalBreakdown = _computeScoreBreakdown();
    callbacks.onVictory?.call(finalBreakdown!);
  }

  MazeScoreBreakdown _computeScoreBreakdown() {
    final deliveredScore = liveDeliveredFoodScore;
    final remSec = remainingTime.ceil().clamp(0, level.timeLimitSeconds);
    final maxTimeBonus =
        (level.maxPossibleFoodScore * 0.65).round().clamp(60, 400);
    final timeBonus = (remSec * 5).clamp(0, maxTimeBonus);
    final survivalBonus = health * 20;

    // V3.3 Truck Survival Bonus (depends on remaining truck HP, keeps food protection #1!)
    final truckHp = truckDefense.truck.hp.clamp(0, truckDefense.truck.maxHp);
    final truckSurvivalBonus = ((truckHp / math.max(1, truckDefense.truck.maxHp)) * 90)
        .round()
        .clamp(0, 90);

    // Modest Defense Performance Bonus (rewards clean defense without outweighing food delivery)
    final perfRaw = (truckDefense.bombsIntercepted * 12) +
        (truckDefense.chargesInterrupted * 15) +
        (truckDefense.isBossDefeated ? 35 : 0);
    final defensePerformanceBonus = perfRaw.clamp(0, 65);

    final total = deliveredScore +
        timeBonus +
        survivalBonus +
        truckSurvivalBonus +
        defensePerformanceBonus;
    final coins = math.max(1, total ~/ 100);

    int stars = 1;
    if (total >= level.starThresholds[2]) {
      stars = 3;
    } else if (total >= level.starThresholds[1]) {
      stars = 2;
    }

    return MazeScoreBreakdown(
      deliveredFoodScore: deliveredScore,
      timeBonus: timeBonus,
      survivalBonus: survivalBonus,
      truckSurvivalBonus: truckSurvivalBonus,
      defensePerformanceBonus: defensePerformanceBonus,
      totalScore: total,
      coinsEarned: coins,
      starsEarned: stars,
      deliveredPercent: deliveredQuantityPercent,
      remainingSeconds: remSec,
      remainingHealth: health,
      remainingTruckHp: truckHp,
      bossDefeated: truckDefense.isBossDefeated,
      foodResults: foods.map((f) => f.clone()).toList(),
    );
  }

  void _triggerDefeat(DefeatReason reason) {
    if (phase == MazeGamePhase.victory || phase == MazeGamePhase.defeat) return;
    phase = MazeGamePhase.defeat;
    defeatReason = reason;
    _inputDx = 0.0;
    _inputDy = 0.0;
    _tapMovePath = [];
    callbacks.onDefeat?.call(reason);
  }

  // --- Monster AI System (6 Types, Full State Machine, Wall-Respecting) ---

  void _stepMonsters(double dt) {
    for (final m in monsters) {
      if (m.hitFlashTimer > 0) {
        m.hitFlashTimer = (m.hitFlashTimer - dt).clamp(0.0, 5.0);
      }
      if (m.hpBarTimer > 0) {
        m.hpBarTimer = (m.hpBarTimer - dt).clamp(0.0, 10.0);
      }
      if (m.defeatAnimTimer > 0) {
        m.defeatAnimTimer = (m.defeatAnimTimer - dt).clamp(0.0, 5.0);
      }

      // Defeated monsters never move or attack!
      if (m.isDefeated) {
        m.isMoving = false;
        continue;
      }
      m.isMoving = false;

      // Apply decaying knockback while strictly respecting maze walls
      if (m.knockbackVx.abs() > 0.05 || m.knockbackVy.abs() > 0.05) {
        final nx = m.x + m.knockbackVx * dt;
        final ny = m.y + m.knockbackVy * dt;
        if (!_collidesWithWall(nx, m.y, monsterRadius)) m.x = nx;
        if (!_collidesWithWall(m.x, ny, monsterRadius)) m.y = ny;
        final decay = math.exp(-10.0 * dt);
        m.knockbackVx *= decay;
        m.knockbackVy *= decay;
      }

      // Frozen enemies cannot act until freeze expires
      if (m.freezeTimer > 0) {
        m.freezeTimer = (m.freezeTimer - dt).clamp(0.0, 10.0);
        continue;
      }

      m.animPhase += dt * (m.state == MonsterAiState.chase ? 13.0 : 6.5);
      if (m.attackCooldown > 0) {
        m.attackCooldown = (m.attackCooldown - dt).clamp(0.0, 10.0);
      }
      if (m.specialCooldown > 0) {
        m.specialCooldown = (m.specialCooldown - dt).clamp(0.0, 10.0);
      }
      if (m.biteAnimTimer > 0) {
        m.biteAnimTimer = (m.biteAnimTimer - dt).clamp(0.0, 10.0);
      }
      if (m.repathTimer > 0) {
        m.repathTimer = (m.repathTimer - dt).clamp(0.0, 10.0);
      }

      // Stunned state expires cleanly into recover -> patrol
      if (m.state == MonsterAiState.stunned || m.stunTimer > 0) {
        m.stunTimer = (m.stunTimer - dt).clamp(0.0, 10.0);
        if (m.stunTimer <= 0) {
          m.state = MonsterAiState.recover;
          m.stateTimer = 0.0;
        }
        continue;
      }

      final dx = playerX - m.x;
      final dy = playerY - m.y;
      final distToPlayer = math.sqrt(dx * dx + dy * dy);
      final hasLos =
          MazePathfinder.hasLineOfSight(level, m.x, m.y, playerX, playerY);

      // Telegraphed windup attacks (Charging Monster corridor rush, Mushroom Beast cloud, Brute slam)
      if (m.state == MonsterAiState.windup) {
        m.stateTimer += dt;
        m.facingAngle = math.atan2(dy, dx);
        final isCharger =
            m.movementProfile == MonsterMovementProfile.chargingMonster;
        final windupDur = m.type == MonsterType.mushroomBeast
            ? 0.85
            : (isCharger ? 0.58 : 0.55);
        if (m.stateTimer >= windupDur) {
          m.stateTimer = 0.0;
          if (isCharger && m.type != MonsterType.mushroomBeast) {
            // Launch high-speed wall-safe corridor charge!
            final angle = math.atan2(dy, dx);
            m.chargeVx = math.cos(angle) * m.speed * 2.15;
            m.chargeVy = math.sin(angle) * m.speed * 2.15;
            m.chargeActiveTimer = 0.72;
            m.specialCooldown = 3.8;
            m.state = MonsterAiState.chase;
          } else if (m.type == MonsterType.mushroomBeast ||
              (m.type == MonsterType.mazeGuardian && m.bossPatternIndex == 1)) {
            poisonClouds.add(PoisonCloudEntity(x: m.x, y: m.y, radius: 1.45));
            m.specialCooldown = 5.5;
            m.state = MonsterAiState.recover;
          } else {
            // Heavy telegraphed slam for Brute / Guardian
            vfx.add(CombatVfx(
              type: CombatVfxType.stunPulseRing,
              x: m.x,
              y: m.y,
              maxRadius: 1.15,
              colorHex: 0xFFE63946,
              duration: 0.3,
            ));
            if (distToPlayer <= 1.15 &&
                invulnerabilityTimer <= 0 &&
                hasLos) {
              _executeMonsterAttack(m);
              if (phase != MazeGamePhase.playing) return;
            } else {
              m.state = MonsterAiState.recover;
            }
          }
          m.bossPatternIndex = (m.bossPatternIndex + 1) % 3;
        }
        continue;
      }

      // Active High-Speed Corridor Charge (Charging Monster H — strictly wall-stopping!)
      if (m.chargeActiveTimer > 0) {
        m.chargeActiveTimer = (m.chargeActiveTimer - dt).clamp(0.0, 2.0);
        m.isMoving = true;
        final nx = m.x + m.chargeVx * dt;
        final ny = m.y + m.chargeVy * dt;
        bool hitWall = false;
        if (!_collidesWithWall(nx, m.y, monsterRadius)) {
          m.x = nx;
        } else {
          hitWall = true;
        }
        if (!_collidesWithWall(m.x, ny, monsterRadius)) {
          m.y = ny;
        } else {
          hitWall = true;
        }
        if (hitWall || m.chargeActiveTimer <= 0) {
          m.chargeActiveTimer = 0.0;
          m.state = MonsterAiState.recover;
          m.stateTimer = 0.0;
        }
        if (distToPlayer <= attackDistance + 0.12 &&
            hasLos &&
            m.attackCooldown <= 0.0 &&
            invulnerabilityTimer <= 0.0) {
          m.chargeActiveTimer = 0.0;
          _executeMonsterAttack(m);
          if (phase != MazeGamePhase.playing) return;
        }
        continue;
      }

      // Direct contact attack check (strictly cannot attack through walls!)
      if (distToPlayer <= attackDistance &&
          hasLos &&
          m.attackCooldown <= 0.0 &&
          invulnerabilityTimer <= 0.0 &&
          m.state != MonsterAiState.recover) {
        if (m.type == MonsterType.forestBrute) {
          // Forest Brute telegraphs heavy swing fairly!
          m.state = MonsterAiState.windup;
          m.stateTimer = 0.0;
          continue;
        }
        _executeMonsterAttack(m);
        if (phase != MazeGamePhase.playing) return;
        continue;
      }

      // Check active Food Decoy distraction!
      final decoy = _findNearbyDecoy(m);
      if (decoy != null && m.state != MonsterAiState.attack) {
        final ddx = decoy.x - m.x;
        final ddy = decoy.y - m.y;
        final dDist = math.sqrt(ddx * ddx + ddy * ddy);
        if (dDist > 0.35) {
          if (m.repathTimer <= 0) {
            m.repathTimer = 0.3;
            final path = MazePathfinder.findPath(
              level,
              m.currentCell,
              GridPoint(decoy.x.floor(), decoy.y.floor()),
            );
            m.activeNavPath = path.length > 1 ? path.sublist(1) : [];
          }
          if (m.activeNavPath.isNotEmpty) {
            _moveMonsterTowardCell(m, m.activeNavPath.first, m.speed, dt,
                onReached: () => m.activeNavPath.removeAt(0));
          } else {
            _moveMonsterTowardPoint(m, decoy.x, decoy.y, m.speed, dt);
          }
        }
        continue;
      }

      // Mushroom Beast & Maze Guardian ranged spore/slam trigger
      if ((m.type == MonsterType.mushroomBeast ||
              m.type == MonsterType.mazeGuardian) &&
          m.specialCooldown <= 0.0 &&
          distToPlayer <= 2.4 &&
          hasLos &&
          m.state != MonsterAiState.recover) {
        m.state = MonsterAiState.windup;
        m.stateTimer = 0.0;
        callbacks.onMonsterAlert?.call(m);
        continue;
      }

      switch (m.state) {
        case MonsterAiState.idle:
          m.stateTimer += dt;
          m.ambushCrouched =
              m.movementProfile == MonsterMovementProfile.ambushMonster;
          if (!m.ambushCrouched) {
            m.facingAngle += dt * 1.35;
          } else {
            m.facingAngle = math.atan2(dy, dx);
          }
          if (_canDetectPlayer(m, distToPlayer, hasLos)) {
            m.ambushCrouched = false;
            _enterDetectState(m);
          } else if (!m.ambushCrouched &&
              m.patrolPath.length > 1 &&
              m.stateTimer >= 1.15) {
            m.state = MonsterAiState.patrol;
            m.stateTimer = 0.0;
          }
          break;

        case MonsterAiState.patrol:
          m.ambushCrouched = false;
          if (_canDetectPlayer(m, distToPlayer, hasLos)) {
            _enterDetectState(m);
          } else {
            _moveAlongPatrol(m, dt);
          }
          break;

        case MonsterAiState.detect:
          m.ambushCrouched = false;
          m.facingAngle = math.atan2(dy, dx);
          m.stateTimer += dt;
          if (m.stateTimer >= m.alertDuration) {
            m.stateTimer = 0.0;
            if (m.movementProfile == MonsterMovementProfile.chargingMonster &&
                hasLos &&
                m.specialCooldown <= 0.0 &&
                distToPlayer <= 4.5) {
              m.state = MonsterAiState.windup;
            } else {
              m.state = MonsterAiState.chase;
            }
            m.repathTimer = 0.0;
          }
          break;

        case MonsterAiState.chase:
          final isFlying =
              m.movementProfile == MonsterMovementProfile.flyingMonster;
          final maxChaseRange = isFlying
              ? m.detectionRange * 1.32
              : (m.movementProfile == MonsterMovementProfile.intelligentHunter
                  ? m.detectionRange * 1.75
                  : m.detectionRange * 1.5);
          m.stateTimer += dt;
          final tiredOut = isFlying && m.stateTimer >= 3.0;

          if (distToPlayer > maxChaseRange || tiredOut) {
            m.state = MonsterAiState.recover;
            m.stateTimer = 0.0;
            m.activeNavPath = [];
            break;
          }

          // Charging Monster triggers telegraphed charge down open corridors!
          if (m.movementProfile == MonsterMovementProfile.chargingMonster &&
              hasLos &&
              m.specialCooldown <= 0.0 &&
              distToPlayer > 1.35 &&
              distToPlayer <= 4.4) {
            m.state = MonsterAiState.windup;
            m.stateTimer = 0.0;
            break;
          }

          if (m.repathTimer <= 0.0) {
            m.repathTimer = 0.25;
            GridPoint goalCell = playerCell;
            // Intelligent Hunter (Profile J): predicts & flanks 1-2 cells ahead of player!
            if (m.movementProfile == MonsterMovementProfile.intelligentHunter &&
                distToPlayer > 1.8) {
              final leadCol =
                  (playerX + math.cos(playerFacingAngle) * 1.6).floor();
              final leadRow =
                  (playerY + math.sin(playerFacingAngle) * 1.6).floor();
              if (level.inBounds(leadCol, leadRow) &&
                  level.isWalkable(leadCol, leadRow)) {
                goalCell = GridPoint(leadCol, leadRow);
              }
            }
            final path = MazePathfinder.findPath(level, m.currentCell, goalCell);
            m.activeNavPath = path.length > 1 ? path.sublist(1) : [];
          }

          // Distinct chase speeds matched to each of the 10 movement profiles!
          final double chaseMult;
          switch (m.movementProfile) {
            case MonsterMovementProfile.slowStalker:
              chaseMult = 0.88;
              break;
            case MonsterMovementProfile.fastHunter:
              chaseMult = 1.24;
              break;
            case MonsterMovementProfile.ambushMonster:
              chaseMult = 1.36;
              break;
            case MonsterMovementProfile.crawlingMonster:
              chaseMult = 1.28;
              break;
            case MonsterMovementProfile.flyingMonster:
              chaseMult = 1.15;
              break;
            case MonsterMovementProfile.intelligentHunter:
              chaseMult = 1.12;
              break;
            default:
              chaseMult = 1.06;
              break;
          }
          final chaseSpeed = m.speed * chaseMult;

          if (m.activeNavPath.isNotEmpty) {
            _moveMonsterTowardCell(m, m.activeNavPath.first, chaseSpeed, dt,
                onReached: () => m.activeNavPath.removeAt(0));
          } else if (hasLos) {
            _moveMonsterTowardPoint(m, playerX, playerY, chaseSpeed, dt);
          }
          break;

        case MonsterAiState.attack:
          m.stateTimer += dt;
          if (m.stateTimer >= 0.28) {
            m.state = MonsterAiState.recover;
            m.stateTimer = 0.0;
          }
          break;

        case MonsterAiState.recover:
          m.stateTimer += dt;
          if (m.stateTimer >= m.recoverDuration) {
            m.stateTimer = 0.0;
            m.activeNavPath = [];
            m.state = m.patrolPath.length > 1
                ? MonsterAiState.patrol
                : MonsterAiState.idle;
          }
          break;

        case MonsterAiState.windup:
        case MonsterAiState.stunned:
        case MonsterAiState.defeated:
          break;
      }
    }
  }

  FoodDecoyEntity? _findNearbyDecoy(MonsterEntity m) {
    for (final d in decoys) {
      final dx = d.x - m.x;
      final dy = d.y - m.y;
      if (dx * dx + dy * dy <= 4.5 * 4.5) return d;
    }
    return null;
  }

  bool _canDetectPlayer(MonsterEntity m, double distToPlayer, bool hasLos) {
    if (distToPlayer > m.detectionRange) return false;
    if (m.type == MonsterType.forestBrute && distToPlayer > 2.4) return false;
    if (m.type == MonsterType.mushroomBeast && distToPlayer > 2.6) return false;
    if (hasLos) return true;
    if (carriedFoods.isNotEmpty && distToPlayer <= m.detectionRange * 0.72) {
      return true;
    }
    return false;
  }

  void _enterDetectState(MonsterEntity m) {
    m.state = MonsterAiState.detect;
    m.stateTimer = 0.0;
    m.activeNavPath = [];
    callbacks.onMonsterAlert?.call(m);
  }

  void _moveAlongPatrol(MonsterEntity m, double dt) {
    if (m.patrolPath.isEmpty) return;
    final targetWp = m.patrolPath[m.patrolIndex];
    if (m.activeNavPath.isEmpty && m.currentCell != targetWp) {
      final path = MazePathfinder.findPath(level, m.currentCell, targetWp);
      m.activeNavPath = path.length > 1 ? path.sublist(1) : [targetWp];
    }

    if (m.activeNavPath.isNotEmpty) {
      _moveMonsterTowardCell(m, m.activeNavPath.first, m.speed, dt,
          onReached: () {
        m.activeNavPath.removeAt(0);
        if (m.activeNavPath.isEmpty) _advancePatrolWaypoint(m);
      });
    } else {
      _advancePatrolWaypoint(m);
    }
  }

  void _advancePatrolWaypoint(MonsterEntity m) {
    if (m.patrolPath.length <= 1) {
      m.state = MonsterAiState.idle;
      m.stateTimer = 0.0;
      return;
    }
    if (m.type == MonsterType.forestBrute ||
        m.type == MonsterType.mushroomBeast) {
      m.state = MonsterAiState.idle;
      m.stateTimer = 0.0;
    }
    if (m.patrolForward) {
      if (m.patrolIndex + 1 < m.patrolPath.length) {
        m.patrolIndex++;
      } else {
        m.patrolForward = false;
        m.patrolIndex = math.max(0, m.patrolPath.length - 2);
      }
    } else {
      if (m.patrolIndex > 0) {
        m.patrolIndex--;
      } else {
        m.patrolForward = true;
        m.patrolIndex = math.min(1, m.patrolPath.length - 1);
      }
    }
  }

  void _moveMonsterTowardCell(
    MonsterEntity m,
    GridPoint cell,
    double speed,
    double dt, {
    required void Function() onReached,
  }) {
    final tx = cell.centerX;
    final ty = cell.centerY;
    final dx = tx - m.x;
    final dy = ty - m.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist <= 0.08) {
      m.x = tx;
      m.y = ty;
      onReached();
      return;
    }
    _moveMonsterTowardPoint(m, tx, ty, speed, dt);
  }

  void _moveMonsterTowardPoint(
    MonsterEntity m,
    double tx,
    double ty,
    double speed,
    double dt,
  ) {
    final dx = tx - m.x;
    final dy = ty - m.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1e-5) return;

    m.isMoving = true;
    m.facingAngle = math.atan2(dy, dx);

    // Profile F — Jumping Creature: rhythmic hop cycles (takeoff -> leap -> land pause!)
    double effSpeed = speed;
    if (m.movementProfile == MonsterMovementProfile.jumpingCreature) {
      if (m.hopCooldown > 0) {
        m.hopCooldown = (m.hopCooldown - dt).clamp(0.0, 2.0);
        m.hopPhase = 0.0;
        m.isMoving = false;
        return; // Brief crouch before next hop!
      }
      m.hopPhase += dt * 7.8;
      effSpeed = speed * 1.65;
      if (m.hopPhase >= math.pi) {
        m.hopPhase = 0.0;
        m.hopCooldown = 0.28;
      }
    }

    final stepDist = math.min(effSpeed * dt, dist);
    double vx = (dx / dist) * stepDist;
    double vy = (dy / dist) * stepDist;

    // Profile C — Zigzag Monster: wall-safe perpendicular lateral weave!
    if (m.movementProfile == MonsterMovementProfile.zigzagMonster) {
      m.zigzagPhase += dt * 9.5;
      final perpX = -dy / dist;
      final perpY = dx / dist;
      final weave = math.sin(m.zigzagPhase) * stepDist * 0.42;
      vx += perpX * weave;
      vy += perpY * weave;
    }

    final nx = m.x + vx;
    final ny = m.y + vy;
    if (!_collidesWithWall(nx, m.y, monsterRadius)) m.x = nx;
    if (!_collidesWithWall(m.x, ny, monsterRadius)) m.y = ny;
  }

  void _executeMonsterAttack(MonsterEntity m) {
    m.state = MonsterAiState.attack;
    m.stateTimer = 0.0;
    m.biteAnimTimer = 0.4;
    m.attackCooldown = monsterAttackCooldownDuration;

    // Temporary Shield blocks 1 incoming attack completely and vanishes!
    if (hasShield) {
      hasShield = false;
      invulnerabilityTimer = 1.25;
      m.state = MonsterAiState.recover;
      vfx.add(CombatVfx(
        type: CombatVfxType.shieldBreak,
        x: playerX,
        y: playerY,
        maxRadius: 0.9,
        colorHex: 0xFF38BDF8,
        duration: 0.4,
      ));
      popups.add(FloatingPopup(
        text: 'Shield Blocked!',
        worldX: playerX,
        worldY: playerY - 0.55,
        colorHex: 0xFF0284C7,
        lifetime: 1.2,
      ));
      callbacks.onShieldBlocked?.call();
      return;
    }

    // Section 10: Enemy attack interrupts active auto-route so player immediately regains manual control!
    if (_tapMovePath.isNotEmpty) {
      _tapMovePath = [];
      autoRouteGoalCell = null;
      routeFeedbackMessage = 'Attacked! Manual control restored.';
      _routeFeedbackTimer = 2.0;
    }

    invulnerabilityTimer = playerInvulnDuration;
    damageFlashTimer = 0.45;

    FoodItem? bitten;
    int eaten = 0;
    final carried = carriedFoods;
    if (carried.isNotEmpty) {
      bitten = carried.first;
      eaten = bitten.applyBite(m.biteDamage);
      final label = bitten.status == FoodStatus.consumed
          ? '${bitten.type.displayName} Eaten!'
          : '-$eaten% ${bitten.type.displayName}';
      popups.add(FloatingPopup(
        text: label,
        worldX: playerX,
        worldY: playerY - 0.55,
        colorHex: 0xFFD62828,
        lifetime: 1.3,
      ));
    } else {
      popups.add(FloatingPopup(
        text: 'Ouch! -1 Heart',
        worldX: playerX,
        worldY: playerY - 0.55,
        colorHex: 0xFFD62828,
        lifetime: 1.1,
      ));
    }

    health = math.max(0, health - 1);
    cleanDeliveriesSinceDamage = 0;
    callbacks.onMonsterAttack?.call(m, bitten, eaten);

    if (health <= 0) {
      _triggerDefeat(DefeatReason.healthDepleted);
      return;
    }
    if (maxAchievableQuantityPercent < level.minQuotaPercent) {
      _triggerDefeat(DefeatReason.insufficientFood);
      return;
    }
    if (onMapFoods.isEmpty && carriedFoods.isEmpty) {
      _evaluateObjectiveCompletion();
    }
  }
}

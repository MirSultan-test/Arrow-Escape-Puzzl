import 'dart:math' as math;
import 'dart:ui';
import '../../models/maze/character_animation_state.dart';
import '../../models/maze/combat_models.dart';
import '../../models/maze/delivery_state.dart';
import '../../models/maze/truck_defense_models.dart';

/// Callbacks emitted by [TruckDefenseSimulation] for audio, haptics, and engine coordination.
class TruckDefenseCallbacks {
  final void Function()? onCageWarning;
  final void Function()? onCageBreakOpen;
  final void Function()? onKnifeDrawn;
  final void Function()? onTruckEngineStart;
  final void Function(int damage, bool isTireHit)? onTruckDamaged;
  final void Function(int healedAmount)? onTruckRepaired;
  final void Function(int damage, bool bossDefeated)? onBossHit;
  final void Function()? onAllySlash;
  final void Function()? onPlayerDamaged;
  final void Function()? onShieldBlocked;
  final void Function()? onWeaponFired;
  final void Function()? onTruckArrived;
  final void Function(DefeatReason reason)? onDefenseFailed;

  const TruckDefenseCallbacks({
    this.onCageWarning,
    this.onCageBreakOpen,
    this.onKnifeDrawn,
    this.onTruckEngineStart,
    this.onTruckDamaged,
    this.onTruckRepaired,
    this.onBossHit,
    this.onAllySlash,
    this.onPlayerDamaged,
    this.onShieldBlocked,
    this.onWeaponFired,
    this.onTruckArrived,
    this.onDefenseFailed,
  });
}

/// Pure, headless, deterministic simulation for the V3.3 Monster Cage,
/// Escape Cutscene, Winding Road Truck Movement, Boss Combat, and Dock Worker Ally AI.
class TruckDefenseSimulation {
  static const double loadingCompleteDuration = 0.45;
  static const double cutsceneTotalDuration = 2.35;
  static const double arrivalCelebrationDuration = 1.25;
  static const double destroySequenceDuration = 0.75;
  static const double playerMoveSpeed = 4.25;
  static const double playerRadius = 0.36;
  static const double truckCollisionRadius = 0.68;
  static const double bossRadius = 0.62;

  final TruckDefenseConfig config;
  TruckDefenseCallbacks callbacks;

  // Cage & escape guard (strictly opens ONCE per level attempt)
  BossCageState cageState = BossCageState.locked;
  bool _escapeTriggered = false;
  bool _lockBrokenEmitted = false;
  bool _knifeDrawnEmitted = false;
  bool _engineStartEmitted = false;
  double cageIdleShakePhase = 0.0;
  double cageShakeIntensity = 0.0;
  double phaseTimer = 0.0;

  /// Smooth transition progress 0.0 (Maze + Dock + Cage) -> 1.0 (Full-Screen Road Arena).
  double arenaTransitionProgress = 0.0;

  // Separate Defense Phase Timer (starts ONLY when player gains control in Truck Defense)
  double defenseRemainingTime = 0.0;

  // Live entities
  late TruckDefenseVehicle truck;
  late DockWorkerAlly ally;
  late RoadBossEntity boss;
  late RoadRepairKit repairKit;

  // Player position & movement state in Road Battle Arena coordinates
  double playerX = 4.2;
  double playerY = 2.2;
  double playerFacingAngle = 0.0;
  bool playerIsMoving = false;
  double playerMoveSpeedRatio = 0.0;
  double playerWalkPhase = 0.0;
  double _playerDustTimer = 0.0;

  // Finger-drawn road route navigation (V3.5 / integration brief)
  bool isDrawingRoadRoute = false;
  final List<Offset> draftRoadRoute = [];
  final List<Offset> activeRoadRoute = [];
  int roadRouteIndex = 0;
  Offset? invalidDragPoint;
  bool isStunnedOrKnockedBack = false;
  double stunDuration = 0.0;
  bool isTruckBlockingCourier = false;

  bool isRoadPointWalkable(double wx, double wy) {
    if (wx < RoadArenaBounds.playableMarginX ||
        wx > RoadArenaBounds.width - RoadArenaBounds.playableMarginX) {
      return false;
    }
    if (wy < RoadArenaBounds.playableMarginTop ||
        wy > RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom) {
      return false;
    }
    // Check truck hull obstacle
    final tdx = wx - truck.x;
    final tdy = wy - truck.y;
    final distToTruck = math.sqrt(tdx * tdx + tdy * tdy);
    if (distToTruck < 0.65) {
      return false;
    }
    return true;
  }

  bool beginRoadRouteDraw(double wx, double wy) {
    // Touch tolerance: must start near Courier (generous 1.95 world radius for phone screens)
    final pdx = wx - playerX;
    final pdy = wy - playerY;
    final distToPlayer = math.sqrt(pdx * pdx + pdy * pdy);
    if (distToPlayer > 1.95) return false;

    // A new drag near the Courier immediately cancels the previous active path and starts fresh
    cancelActiveRoadRoute();
    isDrawingRoadRoute = true;
    draftRoadRoute.clear();
    draftRoadRoute.add(Offset(playerX, playerY));
    invalidDragPoint = null;
    return true;
  }

  bool updateRoadRouteDraw(double wx, double wy) {
    if (!isDrawingRoadRoute) return false;

    if (!isRoadPointWalkable(wx, wy)) {
      invalidDragPoint = Offset(wx, wy);
      // Retain draft without corrupting it
      return true;
    }

    invalidDragPoint = null;
    if (draftRoadRoute.isEmpty) {
      draftRoadRoute.add(Offset(playerX, playerY));
    }

    final last = draftRoadRoute.last;
    final dLast = math.sqrt((wx - last.dx) * (wx - last.dx) + (wy - last.dy) * (wy - last.dy));
    if (dLast >= 0.28) {
      // Check for backtracking to simplify route
      int backtrackIdx = -1;
      for (int i = 0; i < draftRoadRoute.length - 1; i++) {
        final pt = draftRoadRoute[i];
        final dist = math.sqrt((wx - pt.dx) * (wx - pt.dx) + (wy - pt.dy) * (wy - pt.dy));
        if (dist < 0.32) {
          backtrackIdx = i;
          break;
        }
      }
      if (backtrackIdx >= 0) {
        draftRoadRoute.removeRange(backtrackIdx + 1, draftRoadRoute.length);
      } else {
        draftRoadRoute.add(Offset(wx, wy));
      }
    }
    return true;
  }

  bool commitRoadRouteDraw() {
    if (!isDrawingRoadRoute) return false;
    isDrawingRoadRoute = false;
    invalidDragPoint = null;

    if (draftRoadRoute.length >= 2) {
      activeRoadRoute.clear();
      activeRoadRoute.addAll(draftRoadRoute);
      roadRouteIndex = 1;
      draftRoadRoute.clear();
      return true;
    }
    draftRoadRoute.clear();
    return false;
  }

  void cancelRoadRouteDraw() {
    isDrawingRoadRoute = false;
    draftRoadRoute.clear();
    invalidDragPoint = null;
  }

  void cancelActiveRoadRoute() {
    activeRoadRoute.clear();
    roadRouteIndex = 0;
    isTruckBlockingCourier = false;
  }

  void applyStun(double duration) {
    isStunnedOrKnockedBack = true;
    stunDuration = math.max(stunDuration, duration);
  }

  // Combat projectiles, hazards, helpers, dust puffs, VFX & popups inside Road Arena
  final List<ProjectileEntity> playerProjectiles = [];
  final List<BossProjectileEntity> bossProjectiles = [];
  final List<RoadHazardZone> hazards = [];
  final List<RoadHelperMinion> helperMinions = [];
  final List<FoodDecoyEntity> decoys = [];
  final List<DustPuffEntity> dustPuffs = [];
  final List<CombatVfx> vfx = [];
  final List<FloatingPopup> popups = [];

  // Defense performance metrics for V3.3 transparent scoring
  int bossDamageDealtByPlayer = 0;
  int bombsIntercepted = 0;
  int chargesInterrupted = 0;
  int helpersDefeated = 0;
  bool _arrivalResolved = false;
  bool _failureResolved = false;

  TruckDefenseSimulation({
    required this.config,
    this.callbacks = const TruckDefenseCallbacks(),
  }) {
    reset();
  }

  bool get escapeTriggered => _escapeTriggered;
  bool get isBossDefeated => boss.isDefeated;
  double get destinationProgress => truck.progress;
  int get destinationProgressPercent => truck.progressPercent;

  void reset() {
    cageState = BossCageState.locked;
    _escapeTriggered = false;
    _lockBrokenEmitted = false;
    _knifeDrawnEmitted = false;
    _engineStartEmitted = false;
    cageIdleShakePhase = 0.0;
    cageShakeIntensity = 0.0;
    phaseTimer = 0.0;
    arenaTransitionProgress = 0.0;
    defenseRemainingTime = config.defenseTimeLimitSeconds.toDouble();

    final startSample = config.road.sampleAtDistance(0.0);
    truck = TruckDefenseVehicle(
      maxHp: config.truckMaxHp,
      totalRoadLength: config.road.totalLength,
      baseSpeed: config.truckBaseSpeed,
      x: startSample.x,
      y: startSample.y,
      angle: startSample.angle,
    );

    ally = DockWorkerAlly(
      x: (startSample.x - 0.85).clamp(1.0, RoadArenaBounds.width - 1.0),
      y: startSample.y + 0.55,
    );

    boss = RoadBossEntity(
      type: config.bossType,
      appearance: config.bossAppearance,
      maxHp: config.bossMaxHp,
      baseSpeed: config.bossSpeed,
      attackInterval: config.bossAttackInterval,
      damageScale: config.bossDamageScale,
      attackPool: config.unlockedAttacks,
      x: config.road.cagePos.x,
      y: config.road.cagePos.y,
    );

    repairKit = RoadRepairKit(
      x: config.road.repairKitPos.x,
      y: config.road.repairKitPos.y,
    );

    playerX = (startSample.x - 0.35).clamp(1.2, RoadArenaBounds.width - 1.2);
    playerY = (startSample.y + 1.35).clamp(1.8, RoadArenaBounds.height - 2.0);
    playerFacingAngle = math.atan2(boss.y - playerY, boss.x - playerX);
    playerIsMoving = false;
    playerMoveSpeedRatio = 0.0;
    playerWalkPhase = 0.0;
    _playerDustTimer = 0.0;

    playerProjectiles.clear();
    bossProjectiles.clear();
    hazards.clear();
    helperMinions.clear();
    decoys.clear();
    dustPuffs.clear();
    vfx.clear();
    popups.clear();

    bossDamageDealtByPlayer = 0;
    bombsIntercepted = 0;
    chargesInterrupted = 0;
    helpersDefeated = 0;
    _arrivalResolved = false;
    _failureResolved = false;
  }

  /// Subtle idle cage rattle while player is still collecting food in the maze.
  /// Strictly NEVER escapes or attacks while caged.
  void stepIdleCage(double dt) {
    if (cageState != BossCageState.locked) return;
    cageIdleShakePhase += dt;
    boss.animPhase += dt * 4.2;
    // Periodic menacing bar rattle every ~3.4 seconds
    final cycle = cageIdleShakePhase % 3.4;
    if (cycle > 2.65 && cycle < 3.15) {
      cageShakeIntensity = math.sin((cycle - 2.65) * 26.0) * 0.65;
    } else {
      cageShakeIntensity = 0.0;
    }
  }

  /// Starts the once-per-run escape sequence when food loading completes.
  /// Returns true on first trigger; strictly ignores duplicate calls.
  bool beginFoodLoadingComplete() {
    if (_escapeTriggered) return false;
    _escapeTriggered = true;
    phaseTimer = 0.0;
    cageState = BossCageState.rattling;
    cageShakeIntensity = 1.0;
    callbacks.onCageWarning?.call();
    return true;
  }

  /// Steps `FOOD_LOADING_COMPLETE`. Returns true when ready for `CAGE_ESCAPE_CUTSCENE`.
  bool stepFoodLoadingComplete(double dt) {
    phaseTimer += dt;
    boss.animPhase += dt * 11.0;
    cageShakeIntensity = math.sin(phaseTimer * 38.0) * 1.1;
    if (phaseTimer >= loadingCompleteDuration) {
      phaseTimer = 0.0;
      return true;
    }
    return false;
  }

  /// Steps `CAGE_ESCAPE_CUTSCENE`. Returns true when transition into `TRUCK_DEFENSE_PLAYING` completes.
  bool stepEscapeCutscene(double dt) {
    phaseTimer += dt;
    boss.animPhase += dt * 13.0;
    _stepVfxAndPopups(dt);

    if (phaseTimer < 0.65) {
      // Heavy cage shaking & boss roar
      cageState = BossCageState.rattling;
      cageShakeIntensity = math.sin(phaseTimer * 48.0) * 1.65;
      arenaTransitionProgress = 0.0;
    } else if (phaseTimer < 1.15) {
      // Lock shatters with golden-red fantasy sparks
      cageState = BossCageState.lockBreaking;
      cageShakeIntensity = math.sin(phaseTimer * 52.0) * 2.0;
      if (!_lockBrokenEmitted) {
        _lockBrokenEmitted = true;
        vfx.add(CombatVfx(
          type: CombatVfxType.hitBurst,
          x: config.road.cagePos.x,
          y: config.road.cagePos.y,
          maxRadius: 1.6,
          colorHex: 0xFFFFC857,
          duration: 0.45,
        ));
        popups.add(FloatingPopup(
          text: 'BOSS ESCAPED!',
          worldX: config.road.cagePos.x + 1.0,
          worldY: config.road.cagePos.y - 0.5,
          colorHex: 0xFFE63946,
          lifetime: 1.3,
        ));
        callbacks.onCageBreakOpen?.call();
      }
      arenaTransitionProgress = ((phaseTimer - 0.65) / 1.70).clamp(0.0, 0.3);
    } else if (phaseTimer < 1.70) {
      // Door swings open, giant boss leaps out, Dock Worker reacts & draws combat knife!
      cageState = BossCageState.doorOpening;
      cageShakeIntensity = 0.0;
      boss.aiState = BossCombatAiState.escaping;
      final leapT = ((phaseTimer - 1.15) / 0.55).clamp(0.0, 1.0);
      boss.x = config.road.cagePos.x + leapT * 1.15;
      boss.y = config.road.cagePos.y + leapT * 1.45;
      if (!_knifeDrawnEmitted) {
        _knifeDrawnEmitted = true;
        ally.state = AllyCombatState.surprised;
        ally.hasKnifeDrawn = true;
        ally.knifeDrawTimer = 0.45;
        popups.add(FloatingPopup(
          text: 'Protect the Truck!',
          worldX: ally.x,
          worldY: ally.y - 0.7,
          colorHex: 0xFFFF9F1C,
          lifetime: 1.25,
        ));
        callbacks.onKnifeDrawn?.call();
      }
      arenaTransitionProgress = (0.3 + leapT * 0.45).clamp(0.3, 0.75);
    } else if (phaseTimer < cutsceneTotalDuration) {
      // Smooth full-screen transition into the Road Battle Arena; truck engine roars!
      cageState = BossCageState.escaped;
      if (!_engineStartEmitted) {
        _engineStartEmitted = true;
        ally.state = AllyCombatState.escorting;
        callbacks.onTruckEngineStart?.call();
      }
      final t = ((phaseTimer - 1.70) / (cutsceneTotalDuration - 1.70))
          .clamp(0.0, 1.0);
      arenaTransitionProgress = (0.75 + t * 0.25).clamp(0.75, 1.0);
    } else {
      _enterActiveDefenseState();
      return true;
    }
    return false;
  }

  /// Skips the escape cutscene cleanly without losing any state invariants.
  void skipCutscene() {
    if (!_escapeTriggered) {
      beginFoodLoadingComplete();
    }
    if (!_lockBrokenEmitted) {
      _lockBrokenEmitted = true;
      callbacks.onCageBreakOpen?.call();
    }
    if (!_knifeDrawnEmitted) {
      _knifeDrawnEmitted = true;
      ally.hasKnifeDrawn = true;
      callbacks.onKnifeDrawn?.call();
    }
    if (!_engineStartEmitted) {
      _engineStartEmitted = true;
      callbacks.onTruckEngineStart?.call();
    }
    _enterActiveDefenseState();
  }

  void _enterActiveDefenseState() {
    cageState = BossCageState.escaped;
    cageShakeIntensity = 0.0;
    arenaTransitionProgress = 1.0;
    phaseTimer = 0.0;

    ally.hasKnifeDrawn = true;
    ally.state = AllyCombatState.escorting;

    boss.x = (config.road.cagePos.x + 1.15).clamp(1.0, RoadArenaBounds.width - 1.0);
    boss.y = (config.road.cagePos.y + 1.55).clamp(1.8, RoadArenaBounds.height - 2.0);
    boss.aiState = BossCombatAiState.pursuingTruck;
    boss.attackCooldown = 1.6;
    boss.stateTimer = 0.0;
  }

  /// Steps `TRUCK_ARRIVED` celebration briefly before showing Victory dialog.
  bool stepTruckArrived(double dt) {
    phaseTimer += dt;
    _stepVfxAndPopups(dt);
    ally.state = AllyCombatState.celebrating;
    if (!boss.isDefeated) {
      boss.aiState = BossCombatAiState.retreating;
      boss.x = (boss.x - dt * 2.5).clamp(-2.0, RoadArenaBounds.width + 2.0);
    }
    return phaseTimer >= arrivalCelebrationDuration;
  }

  /// Steps `TRUCK_DESTROYED` brief failure effect before showing Defeat dialog.
  bool stepTruckDestroyed(double dt) {
    phaseTimer += dt;
    _stepVfxAndPopups(dt);
    return phaseTimer >= destroySequenceDuration;
  }

  /// Main simulation step during `TRUCK_DEFENSE_PLAYING`.
  /// Returns:
  /// - `1` if truck safely arrived at destination (`TRUCK_ARRIVED`)
  /// - `-1` if truck was destroyed (`TRUCK_DESTROYED`)
  /// - `-2` if defense timer expired
  /// - `0` while battle continues.
  int stepDefense({
    required double dt,
    required double inputDx,
    required double inputDy,
    required bool playerHasShield,
    required bool playerIsInvulnerable,
    required bool playerIsPoisonSlowed,
    required double attackAnimTimer,
    required void Function() onConsumePlayerShield,
    required void Function() onHitPlayerHealth,
  }) {
    if (_arrivalResolved || _failureResolved) return 0;

    _stepVfxAndPopups(dt);

    // 1. Defense countdown timer (separate from Maze Timer!)
    defenseRemainingTime = (defenseRemainingTime - dt).clamp(0.0, 999.0);
    if (defenseRemainingTime <= 0.0) {
      _failureResolved = true;
      phaseTimer = 0.0;
      callbacks.onDefenseFailed?.call(DefeatReason.defenseTimeExpired);
      return -2;
    }

    // 2. Step Truck smoothly along winding road spline
    _stepTruckOnRoad(dt);
    if (truck.isDestroyed) {
      _failureResolved = true;
      phaseTimer = 0.0;
      callbacks.onDefenseFailed?.call(DefeatReason.truckDestroyed);
      return -1;
    }
    if (truck.traveledDistance >= truck.totalRoadLength - 0.05) {
      _arrivalResolved = true;
      phaseTimer = 0.0;
      truck.traveledDistance = truck.totalRoadLength;
      ally.state = AllyCombatState.celebrating;
      vfx.add(CombatVfx(
        type: CombatVfxType.defeatPuff,
        x: truck.x,
        y: truck.y,
        maxRadius: 2.0,
        colorHex: 0xFF5DBB75,
        duration: 0.65,
      ));
      popups.add(FloatingPopup(
        text: 'TRUCK ARRIVED!',
        worldX: truck.x,
        worldY: truck.y - 0.9,
        colorHex: 0xFF2E7D32,
        lifetime: 1.4,
      ));
      callbacks.onTruckArrived?.call();
      return 1;
    }

    // 3. Step Courier movement inside roadside battle arena (never trapped behind truck!)
    _stepCourierInArena(
      dt: dt,
      inputDx: inputDx,
      inputDy: inputDy,
      isSlowed: playerIsPoisonSlowed,
      attackAnimTimer: attackAnimTimer,
    );

    // 4. Check one-use Roadside Repair Kit pickup
    _checkRepairKitPickup();

    // 5. Update Decoys & Road Hazards (Ground Slam craters & Poison Clouds)
    for (final d in decoys) {
      d.remainingTime -= dt;
    }
    decoys.removeWhere((d) => d.isExpired);

    _stepHazards(dt);

    // 6. Step Player Projectiles (hit Boss, Helper Minions, or intercept Boss Bombs!)
    _stepPlayerProjectiles(dt);

    // 7. Step Dock Worker Ally AI (knife combat around the moving truck!)
    _stepDockWorkerAlly(dt);

    // 8. Step Giant Boss AI & Helper Minions & Boss Projectiles
    _stepBossAi(
      dt: dt,
      playerHasShield: playerHasShield,
      playerIsInvulnerable: playerIsInvulnerable,
      onConsumePlayerShield: onConsumePlayerShield,
      onHitPlayerHealth: onHitPlayerHealth,
    );
    _stepHelperMinions(
      dt: dt,
      playerHasShield: playerHasShield,
      playerIsInvulnerable: playerIsInvulnerable,
      onConsumePlayerShield: onConsumePlayerShield,
      onHitPlayerHealth: onHitPlayerHealth,
    );
    _stepBossProjectiles(
      dt: dt,
      playerHasShield: playerHasShield,
      playerIsInvulnerable: playerIsInvulnerable,
      onConsumePlayerShield: onConsumePlayerShield,
      onHitPlayerHealth: onHitPlayerHealth,
    );

    if (truck.isDestroyed) {
      _failureResolved = true;
      phaseTimer = 0.0;
      vfx.add(CombatVfx(
        type: CombatVfxType.hitBurst,
        x: truck.x,
        y: truck.y,
        maxRadius: 2.0,
        colorHex: 0xFFE63946,
        duration: 0.6,
      ));
      popups.add(FloatingPopup(
        text: 'TRUCK STOPPED!',
        worldX: truck.x,
        worldY: truck.y - 0.85,
        colorHex: 0xFFD62828,
        lifetime: 1.3,
      ));
      callbacks.onDefenseFailed?.call(DefeatReason.truckDestroyed);
      return -1;
    }

    return 0;
  }

  // --- Player Combat Actions inside Road Battle Arena ---

  /// Finds the best valid auto-target within [maxRange] (prioritizes mid-air bombs -> charging boss -> boss -> minions).
  RoadPoint? findBestTarget(double maxRange) {
    final maxSq = maxRange * maxRange;

    // Priority 1: Incoming fantasy bomb close enough to shoot down!
    BossProjectileEntity? bestBomb;
    double bestBombSq = maxSq;
    for (final bp in bossProjectiles) {
      if (!bp.active || !bp.isBomb) continue;
      final dx = bp.x - playerX;
      final dy = bp.y - playerY;
      final dSq = dx * dx + dy * dy;
      if (dSq <= bestBombSq) {
        bestBombSq = dSq;
        bestBomb = bp;
      }
    }
    if (bestBomb != null) return RoadPoint(bestBomb.x, bestBomb.y);

    // Priority 2: Giant Boss (when alive & escaped)
    if (!boss.isDefeated && !boss.isCaged) {
      final dx = boss.x - playerX;
      final dy = boss.y - playerY;
      if (dx * dx + dy * dy <= maxSq) {
        return RoadPoint(boss.x, boss.y);
      }
    }

    // Priority 3: Nearest active Helper Minion
    RoadHelperMinion? bestMinion;
    double bestMinionSq = maxSq;
    for (final m in helperMinions) {
      if (m.isDefeated) continue;
      final dx = m.x - playerX;
      final dy = m.y - playerY;
      final dSq = dx * dx + dy * dy;
      if (dSq <= bestMinionSq) {
        bestMinionSq = dSq;
        bestMinion = m;
      }
    }
    if (bestMinion != null) return RoadPoint(bestMinion.x, bestMinion.y);
    return null;
  }

  /// Executes a player weapon inside the Road Battle Arena.
  void executePlayerWeapon({
    required WeaponType weapon,
    required bool autoTargetEnabled,
  }) {
    double aimAngle = playerFacingAngle;
    if (autoTargetEnabled &&
        (weapon.isProjectile || weapon == WeaponType.melee)) {
      final target = findBestTarget(weapon.rangeTiles + 1.5);
      if (target != null) {
        aimAngle = math.atan2(target.y - playerY, target.x - playerX);
        playerFacingAngle = aimAngle;
      }
    }

    switch (weapon) {
      case WeaponType.melee:
        _playerMeleeStrike(aimAngle);
        break;
      case WeaponType.bow:
      case WeaponType.energyBlaster:
      case WeaponType.freezeOrb:
        final speed = weapon.projectileSpeed;
        // Launch projectile directly from the weapon muzzle / bow-tip world coordinates!
        final muzzleOffset = weapon == WeaponType.bow ? 0.56 : 0.52;
        final muzzleX = playerX + math.cos(aimAngle) * muzzleOffset;
        final muzzleY = playerY + math.sin(aimAngle) * muzzleOffset - 0.08;
        playerProjectiles.add(ProjectileEntity(
          weapon: weapon,
          x: muzzleX,
          y: muzzleY,
          vx: math.cos(aimAngle) * speed,
          vy: math.sin(aimAngle) * speed,
          angle: aimAngle,
          damage: weapon.baseDamage,
          remainingRange: weapon.rangeTiles + 1.8,
        ));
        vfx.add(CombatVfx(
          type: CombatVfxType.hitBurst,
          x: muzzleX,
          y: muzzleY,
          maxRadius: 0.32,
          colorHex: weapon.colorHex,
          duration: 0.16,
        ));
        break;
      case WeaponType.stunPulse:
        _playerStunPulse();
        break;
      case WeaponType.foodDecoy:
        decoys.add(FoodDecoyEntity(x: playerX, y: playerY, remainingTime: 5.0, maxTime: 5.0));
        popups.add(FloatingPopup(
          text: 'Decoy Lure!',
          worldX: playerX,
          worldY: playerY - 0.65,
          colorHex: 0xFF2E7D32,
          lifetime: 1.0,
        ));
        break;
    }

    callbacks.onWeaponFired?.call();
  }

  void _playerMeleeStrike(double aimAngle) {
    vfx.add(CombatVfx(
      type: CombatVfxType.meleeSlash,
      x: playerX,
      y: playerY,
      angle: aimAngle,
      maxRadius: 1.85,
      colorHex: WeaponType.melee.colorHex,
      duration: 0.25,
    ));

    // Melee can bat away nearby bombs!
    for (final bp in bossProjectiles) {
      if (!bp.active || !bp.isBomb) continue;
      final d = _dist(playerX, playerY, bp.x, bp.y);
      if (d <= 1.75) {
        _interceptBomb(bp);
      }
    }

    if (!boss.isDefeated && !boss.isCaged) {
      final d = _dist(playerX, playerY, boss.x, boss.y);
      if (d <= 2.15) {
        damageBoss(
          damage: 20,
          fromPlayer: true,
          knockbackAngle: math.atan2(boss.y - playerY, boss.x - playerX),
          knockbackForce: 3.4,
          stunDuration: 0.75,
        );
      }
    }

    for (final m in helperMinions) {
      if (m.isDefeated) continue;
      if (_dist(playerX, playerY, m.x, m.y) <= 1.9) {
        _damageHelperMinion(m, 22, stunDuration: 0.8);
      }
    }
  }

  void _playerStunPulse() {
    vfx.add(CombatVfx(
      type: CombatVfxType.stunPulseRing,
      x: playerX,
      y: playerY,
      maxRadius: 3.1,
      colorHex: WeaponType.stunPulse.colorHex,
      duration: 0.42,
    ));

    // Intercept nearby bombs with shockwave!
    for (final bp in bossProjectiles) {
      if (!bp.active || !bp.isBomb) continue;
      if (_dist(playerX, playerY, bp.x, bp.y) <= 3.1) {
        _interceptBomb(bp);
      }
    }

    if (!boss.isDefeated && !boss.isCaged) {
      if (_dist(playerX, playerY, boss.x, boss.y) <= 3.35) {
        damageBoss(
          damage: 16,
          fromPlayer: true,
          knockbackAngle: math.atan2(boss.y - playerY, boss.x - playerX),
          knockbackForce: 4.2,
          stunDuration: 2.2,
        );
      }
    }

    for (final m in helperMinions) {
      if (m.isDefeated) continue;
      if (_dist(playerX, playerY, m.x, m.y) <= 3.1) {
        _damageHelperMinion(m, 18, stunDuration: 2.4);
      }
    }
  }

  /// Applies damage, knockback, stun, or freeze to the escaped Giant Boss.
  /// Strictly ignores hits if the boss is still locked inside the cage!
  void damageBoss({
    required int damage,
    required bool fromPlayer,
    double knockbackAngle = 0.0,
    double knockbackForce = 0.0,
    double stunDuration = 0.0,
    double freezeDuration = 0.0,
  }) {
    if (boss.isCaged || boss.isDefeated) return;

    int effDmg = damage;
    if (boss.hasShield) {
      effDmg = math.max(4, (damage * 0.45).round());
    }

    boss.hp = math.max(0, boss.hp - effDmg);
    boss.hitFlashTimer = 0.22;
    boss.hurtRecoilTimer = 0.28;
    boss.recoilDirX = math.cos(knockbackAngle);
    boss.recoilDirY = math.sin(knockbackAngle);
    if (fromPlayer) {
      bossDamageDealtByPlayer += effDmg;
    }

    if (knockbackForce > 0) {
      boss.knockbackVx = math.cos(knockbackAngle) * knockbackForce;
      boss.knockbackVy = math.sin(knockbackAngle) * knockbackForce;
    }

    // Interrupting a Charge or Telegraph with stun/freeze/heavy hit!
    final wasChargingOrTelegraph = boss.aiState == BossCombatAiState.charging ||
        boss.aiState == BossCombatAiState.telegraphing;

    if (freezeDuration > 0) {
      boss.freezeTimer = math.max(boss.freezeTimer, freezeDuration);
      boss.aiState = BossCombatAiState.frozen;
      boss.queuedAttack = null;
      if (wasChargingOrTelegraph && fromPlayer) {
        chargesInterrupted++;
      }
      vfx.add(CombatVfx(
        type: CombatVfxType.freezeBurst,
        x: boss.x,
        y: boss.y,
        maxRadius: 1.25,
        colorHex: 0xFF38BDF8,
        duration: 0.4,
      ));
      popups.add(FloatingPopup(
        text: 'FROZEN!',
        worldX: boss.x,
        worldY: boss.y - 0.85,
        colorHex: 0xFF0284C7,
        lifetime: 1.0,
      ));
    } else if (stunDuration > 0) {
      boss.stunTimer = math.max(boss.stunTimer, stunDuration);
      boss.aiState = BossCombatAiState.stunned;
      boss.queuedAttack = null;
      if (wasChargingOrTelegraph && fromPlayer) {
        chargesInterrupted++;
        popups.add(FloatingPopup(
          text: 'INTERRUPTED!',
          worldX: boss.x,
          worldY: boss.y - 0.95,
          colorHex: 0xFFFF9F1C,
          lifetime: 1.1,
        ));
      }
    }

    vfx.add(CombatVfx(
      type: CombatVfxType.hitBurst,
      x: boss.x,
      y: boss.y,
      maxRadius: 0.85,
      colorHex: fromPlayer ? 0xFFFFC857 : 0xFF38BDF8,
      duration: 0.25,
    ));

    if (boss.hp <= 0) {
      boss.aiState = BossCombatAiState.defeated;
      boss.queuedAttack = null;
      boss.freezeTimer = 0.0;
      boss.stunTimer = 0.0;
      vfx.add(CombatVfx(
        type: CombatVfxType.defeatPuff,
        x: boss.x,
        y: boss.y,
        maxRadius: 1.9,
        colorHex: 0xFFFFC857,
        duration: 0.6,
      ));
      popups.add(FloatingPopup(
        text: 'BOSS DEFEATED!',
        worldX: boss.x,
        worldY: boss.y - 0.85,
        colorHex: 0xFFFF9F1C,
        lifetime: 1.5,
      ));
      callbacks.onBossHit?.call(effDmg, true);
    } else {
      popups.add(FloatingPopup(
        text: boss.hasShield ? '-$effDmg (Shield)' : '-$effDmg',
        worldX: boss.x,
        worldY: boss.y - 0.65,
        colorHex: fromPlayer ? 0xFFE63946 : 0xFF0EA5E9,
        lifetime: 0.8,
      ));
      callbacks.onBossHit?.call(effDmg, false);
    }
  }

  /// Directly applies damage to the delivery truck (used by boss attacks & tests).
  void damageTruck(int amount, {bool isTireAttack = false}) {
    if (truck.isDestroyed || _arrivalResolved) return;
    final dmg = math.max(1, amount);
    truck.hp = math.max(0, truck.hp - dmg);
    truck.hitFlashTimer = 0.35;

    if (isTireAttack) {
      truck.tireCondition = math.max(15, truck.tireCondition - 32);
      truck.tireSlowTimer = 3.5;
      truck.tireFlashTimer = 1.6;
      popups.add(FloatingPopup(
        text: 'TIRE HIT! -$dmg',
        worldX: truck.x,
        worldY: truck.y - 0.85,
        colorHex: 0xFFD97706,
        lifetime: 1.25,
      ));
    } else {
      popups.add(FloatingPopup(
        text: 'TRUCK -$dmg HP',
        worldX: truck.x,
        worldY: truck.y - 0.85,
        colorHex: 0xFFD62828,
        lifetime: 1.15,
      ));
    }

    vfx.add(CombatVfx(
      type: CombatVfxType.hitBurst,
      x: truck.x,
      y: truck.y,
      maxRadius: 1.15,
      colorHex: isTireAttack ? 0xFFFF9F1C : 0xFFE63946,
      duration: 0.32,
    ));

    callbacks.onTruckDamaged?.call(dmg, isTireAttack);
  }

  // --- Internal Step Helpers ---

  void _stepTruckOnRoad(double dt) {
    if (truck.hitFlashTimer > 0) {
      truck.hitFlashTimer = (truck.hitFlashTimer - dt).clamp(0.0, 5.0);
    }
    if (truck.repairFlashTimer > 0) {
      truck.repairFlashTimer = (truck.repairFlashTimer - dt).clamp(0.0, 5.0);
    }
    if (truck.tireSlowTimer > 0) {
      truck.tireSlowTimer = (truck.tireSlowTimer - dt).clamp(0.0, 10.0);
    }
    if (truck.tireFlashTimer > 0) {
      truck.tireFlashTimer = (truck.tireFlashTimer - dt).clamp(0.0, 10.0);
    }
    if (truck.slamSlowTimer > 0) {
      truck.slamSlowTimer = (truck.slamSlowTimer - dt).clamp(0.0, 10.0);
    }

    if (truck.isDestroyed) return;

    final speed = truck.baseSpeed * truck.currentSpeedMultiplier;
    truck.traveledDistance =
        (truck.traveledDistance + speed * dt).clamp(0.0, truck.totalRoadLength);
    truck.wheelSpinPhase += dt * speed * 9.0;

    final sample = config.road.sampleAtDistance(truck.traveledDistance);
    truck.x = sample.x;
    truck.y = sample.y;
    truck.angle = sample.angle;
  }

  void _stepCourierInArena({
    required double dt,
    required double inputDx,
    required double inputDy,
    required bool isSlowed,
    required double attackAnimTimer,
  }) {
    // Priority 1: Stun/Knockback temporarily suspends movement, retaining route!
    if (isStunnedOrKnockedBack) {
      stunDuration -= dt;
      if (stunDuration <= 0.0) {
        isStunnedOrKnockedBack = false;
        stunDuration = 0.0;
      }
      playerIsMoving = false;
      playerMoveSpeedRatio = 0.0;
      return;
    }

    final mag = math.sqrt(inputDx * inputDx + inputDy * inputDy).clamp(0.0, 1.0);
    // Priority 2: Joystick overrides active route
    if (mag > 0.08) {
      cancelActiveRoadRoute();
      playerIsMoving = true;
      playerMoveSpeedRatio = mag;
      if (attackAnimTimer <= 0.05) {
        playerFacingAngle = math.atan2(inputDy, inputDx);
      }
      final slow = isSlowed ? 0.62 : 1.0;
      // Faster movement produces visibly faster running leg cadence!
      playerWalkPhase += dt * (8.5 + mag * 6.5) * slow;
      playerX += inputDx * playerMoveSpeed * slow * dt;
      playerY += inputDy * playerMoveSpeed * slow * dt;

      _playerDustTimer -= dt;
      if (mag > 0.55 && _playerDustTimer <= 0.0) {
        _playerDustTimer = 0.24;
        dustPuffs.add(DustPuffEntity(
          x: playerX - inputDx * 0.18,
          y: playerY + 0.28,
          maxRadius: 0.20,
        ));
      }
    } else if (activeRoadRoute.isNotEmpty && roadRouteIndex < activeRoadRoute.length) {
      // Priority 3: Follow finger-drawn road route waypoints!
      final target = activeRoadRoute[roadRouteIndex];
      final rdx = target.dx - playerX;
      final rdy = target.dy - playerY;
      final rdist = math.sqrt(rdx * rdx + rdy * rdy);

      // Check moving truck obstacle: if Courier is directly head-on into truck center, pause safely;
      // otherwise, let Courier smoothly slide around truck contour along the drawn curved path!
      final tdx = truck.x - playerX;
      final tdy = truck.y - playerY;
      final tdist = math.sqrt(tdx * tdx + tdy * tdy);
      const minTruckClearance = playerRadius + truckCollisionRadius * 0.76;
      final cosHeading = rdist > 0.001 && tdist > 0.001
          ? (rdx * tdx + rdy * tdy) / (rdist * tdist)
          : 0.0;
      final bool truckBlocks = tdist < minTruckClearance && cosHeading > 0.92;

      if (truckBlocks) {
        isTruckBlockingCourier = true;
        playerIsMoving = false;
        playerMoveSpeedRatio = 0.0;
      } else {
        isTruckBlockingCourier = false;
        if (rdist <= 0.08) {
          playerX = target.dx;
          playerY = target.dy;
          roadRouteIndex++;
          if (roadRouteIndex >= activeRoadRoute.length) {
            cancelActiveRoadRoute();
            playerIsMoving = false;
            playerMoveSpeedRatio = 0.0;
          }
        } else {
          playerIsMoving = true;
          playerMoveSpeedRatio = 1.0;
          final dirX = rdx / rdist;
          final dirY = rdy / rdist;
          if (attackAnimTimer <= 0.05) {
            playerFacingAngle = math.atan2(dirY, dirX);
          }
          final slow = isSlowed ? 0.62 : 1.0;
          playerWalkPhase += dt * (8.5 + 6.5) * slow;
          final moveDist = math.min(rdist, playerMoveSpeed * slow * dt);
          playerX += dirX * moveDist;
          playerY += dirY * moveDist;

          _playerDustTimer -= dt;
          if (_playerDustTimer <= 0.0) {
            _playerDustTimer = 0.24;
            dustPuffs.add(DustPuffEntity(
              x: playerX - dirX * 0.18,
              y: playerY + 0.28,
              maxRadius: 0.20,
            ));
          }

          if (rdist - moveDist <= 0.06) {
            roadRouteIndex++;
            if (roadRouteIndex >= activeRoadRoute.length) {
              cancelActiveRoadRoute();
              playerIsMoving = false;
              playerMoveSpeedRatio = 0.0;
            }
          }
        }
      }
    } else {
      playerIsMoving = false;
      playerMoveSpeedRatio = 0.0;
    }

    // Clamp cleanly inside playable roadside combat arena
    playerX = playerX.clamp(
      RoadArenaBounds.playableMarginX,
      RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
    );
    playerY = playerY.clamp(
      RoadArenaBounds.playableMarginTop,
      RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
    );

    // Smoothly push courier outside truck hull so player NEVER gets trapped behind moving truck!
    final dx = playerX - truck.x;
    final dy = playerY - truck.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    const minSep = playerRadius + truckCollisionRadius * 0.78;
    if (dist < minSep && dist > 1e-4) {
      final push = minSep - dist;
      playerX = (playerX + (dx / dist) * push).clamp(
        RoadArenaBounds.playableMarginX,
        RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
      );
      playerY = (playerY + (dy / dist) * push).clamp(
        RoadArenaBounds.playableMarginTop,
        RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
      );
    }

    // Prevent Courier & Dock Worker from visually stacking directly on top of each other!
    final adx = playerX - ally.x;
    final ady = playerY - ally.y;
    final aDist = math.sqrt(adx * adx + ady * ady);
    if (aDist < 0.72 && aDist > 1e-4) {
      final push = (0.72 - aDist) * 0.5;
      playerX = (playerX + (adx / aDist) * push).clamp(
        RoadArenaBounds.playableMarginX,
        RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
      );
      playerY = (playerY + (ady / aDist) * push).clamp(
        RoadArenaBounds.playableMarginTop,
        RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
      );
    }
  }

  void _checkRepairKitPickup() {
    if (repairKit.collected || truck.isDestroyed) return;
    if (_dist(playerX, playerY, repairKit.x, repairKit.y) <= 0.85) {
      repairKit.collected = true;
      final before = truck.hp;
      truck.hp = math.min(truck.maxHp, truck.hp + repairKit.healAmount);
      truck.tireCondition = 100;
      truck.tireSlowTimer = 0.0;
      truck.tireFlashTimer = 0.0;
      truck.repairFlashTimer = 0.9;
      final gained = truck.hp - before;
      vfx.add(CombatVfx(
        type: CombatVfxType.defeatPuff,
        x: truck.x,
        y: truck.y,
        maxRadius: 1.4,
        colorHex: 0xFF5DBB75,
        duration: 0.45,
      ));
      popups.add(FloatingPopup(
        text: gained > 0 ? 'Truck +$gained HP & Tires Fixed!' : 'Tires Restored!',
        worldX: repairKit.x,
        worldY: repairKit.y - 0.55,
        colorHex: 0xFF2E7D32,
        lifetime: 1.5,
      ));
      callbacks.onTruckRepaired?.call(gained);
    }
  }

  void _stepHazards(double dt) {
    for (final h in hazards) {
      h.remainingTime -= dt;
      final dTruck = _dist(truck.x, truck.y, h.x, h.y);
      if (dTruck <= h.radius + 0.38) {
        truck.slamSlowTimer = math.max(truck.slamSlowTimer, 0.45);
        if (!h.hasDamagedTruck && h.damageOnContact > 0) {
          h.hasDamagedTruck = true;
          damageTruck(h.damageOnContact);
        }
      }
    }
    hazards.removeWhere((h) => h.isExpired);
  }

  void _stepPlayerProjectiles(double dt) {
    for (final p in playerProjectiles) {
      if (!p.active) continue;
      final sx = p.vx * dt;
      final sy = p.vy * dt;
      p.x += sx;
      p.y += sy;
      p.remainingRange -= math.sqrt(sx * sx + sy * sy);

      if (p.remainingRange <= 0 ||
          p.x < 0.0 ||
          p.x > RoadArenaBounds.width ||
          p.y < 0.0 ||
          p.y > RoadArenaBounds.height) {
        p.active = false;
        continue;
      }

      // 1. Check mid-air interception of Boss Fantasy Bombs!
      bool hitSomething = false;
      for (final bp in bossProjectiles) {
        if (!bp.active || !bp.isBomb) continue;
        if (_dist(p.x, p.y, bp.x, bp.y) <= 0.65) {
          p.active = false;
          _interceptBomb(bp);
          hitSomething = true;
          break;
        }
      }
      if (hitSomething) continue;

      // 2. Check Giant Boss hit
      if (!boss.isDefeated && !boss.isCaged) {
        if (_dist(p.x, p.y, boss.x, boss.y) <= bossRadius + 0.25) {
          p.active = false;
          final freeze = p.weapon == WeaponType.freezeOrb ? 2.5 : 0.0;
          final stun = p.weapon == WeaponType.energyBlaster
              ? 0.55
              : (p.weapon == WeaponType.bow ? 0.28 : 0.0);
          damageBoss(
            damage: p.damage,
            fromPlayer: true,
            knockbackAngle: p.angle,
            knockbackForce: p.weapon == WeaponType.energyBlaster ? 3.2 : 1.9,
            stunDuration: freeze > 0 ? 0.0 : stun,
            freezeDuration: freeze,
          );
          continue;
        }
      }

      // 3. Check Helper Minions
      for (final m in helperMinions) {
        if (m.isDefeated) continue;
        if (_dist(p.x, p.y, m.x, m.y) <= 0.52) {
          p.active = false;
          _damageHelperMinion(
            m,
            p.damage,
            stunDuration: p.weapon == WeaponType.freezeOrb ? 2.2 : 0.35,
          );
          break;
        }
      }
    }
    playerProjectiles.removeWhere((p) => !p.active);
  }

  void _interceptBomb(BossProjectileEntity bp) {
    bp.active = false;
    bp.intercepted = true;
    bombsIntercepted++;
    vfx.add(CombatVfx(
      type: CombatVfxType.defeatPuff,
      x: bp.x,
      y: bp.y,
      maxRadius: 0.9,
      colorHex: 0xFF38BDF8,
      duration: 0.35,
    ));
    popups.add(FloatingPopup(
      text: 'BOMB BLOCKED!',
      worldX: bp.x,
      worldY: bp.y - 0.5,
      colorHex: 0xFF0284C7,
      lifetime: 1.0,
    ));
  }

  void _damageHelperMinion(
    RoadHelperMinion m,
    int dmg, {
    double stunDuration = 0.0,
  }) {
    m.hp = math.max(0, m.hp - dmg);
    m.hitFlashTimer = 0.16;
    if (stunDuration > 0) {
      m.stunTimer = math.max(m.stunTimer, stunDuration);
    }
    if (m.isDefeated) {
      helpersDefeated++;
      vfx.add(CombatVfx(
        type: CombatVfxType.defeatPuff,
        x: m.x,
        y: m.y,
        maxRadius: 0.85,
        colorHex: 0xFFFFC857,
        duration: 0.35,
      ));
    }
  }

  // --- Dock Worker Ally AI (Knife Fighter ONLY after Escape!) ---

  void _stepDockWorkerAlly(double dt) {
    if (!ally.hasKnifeDrawn) return;

    if (ally.knifeDrawTimer > 0) {
      ally.knifeDrawTimer = (ally.knifeDrawTimer - dt).clamp(0.0, 2.0);
    }
    if (ally.attackCooldown > 0) {
      ally.attackCooldown = (ally.attackCooldown - dt).clamp(0.0, 10.0);
    }
    if (ally.slashAnimTimer > 0) {
      ally.slashAnimTimer = (ally.slashAnimTimer - dt).clamp(0.0, 5.0);
    }
    if (ally.hitFlashTimer > 0) {
      ally.hitFlashTimer = (ally.hitFlashTimer - dt).clamp(0.0, 5.0);
    }
    if (ally.hurtRecoilTimer > 0) {
      ally.hurtRecoilTimer = (ally.hurtRecoilTimer - dt).clamp(0.0, 2.0);
    }

    if (ally.state == AllyCombatState.recovering) {
      ally.moveSpeedRatio = 0.0;
      ally.recoverTimer -= dt;
      if (ally.recoverTimer <= 0.0) {
        ally.state = AllyCombatState.escorting;
      }
      return;
    }

    // Active Synchronized Knife Swing Sequence (Windup -> Hit Frame -> Follow-through!)
    if (ally.isSwinging) {
      ally.swingElapsed += dt;
      final t = ally.swingProgress;
      ally.moveSpeedRatio = 0.25;

      // Slight forward lunge step during active slash frames
      if (t >= 0.20 && t <= 0.55) {
        ally.x = (ally.x + math.cos(ally.facingAngle) * 1.15 * dt).clamp(
          RoadArenaBounds.playableMarginX,
          RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
        );
        ally.y = (ally.y + math.sin(ally.facingAngle) * 1.15 * dt).clamp(
          RoadArenaBounds.playableMarginTop,
          RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
        );
      }

      // EXACT SYNCHRONIZED HIT-FRAME MARKER (t >= 0.36, guarded against duplicate hits!)
      if (!ally.hitConfirmedThisSwing && t >= 0.36) {
        ally.hitConfirmedThisSwing = true;
        ally.slashAnimTimer = 0.24;
        final impactX = ally.x + math.cos(ally.facingAngle) * 0.62;
        final impactY = ally.y + math.sin(ally.facingAngle) * 0.62;
        vfx.add(CombatVfx(
          type: CombatVfxType.meleeSlash,
          x: impactX,
          y: impactY,
          angle: ally.facingAngle,
          maxRadius: 1.05,
          colorHex: ally.comboStep == 0 ? 0xFF38BDF8 : 0xFFFFC857,
          duration: 0.22,
        ));
        callbacks.onAllySlash?.call();

        if (ally.swingTargetingBoss && !boss.isDefeated && !boss.isCaged) {
          if (_dist(ally.x, ally.y, boss.x, boss.y) <= 1.65) {
            ally.totalHitsLanded++;
            final knifeDmg = boss.aiState == BossCombatAiState.stunned ||
                    boss.aiState == BossCombatAiState.frozen
                ? 13
                : 9;
            damageBoss(
              damage: knifeDmg,
              fromPlayer: false,
              knockbackAngle: ally.facingAngle,
              knockbackForce: 1.65,
            );
            if (boss.aiState == BossCombatAiState.pursuingTruck) {
              boss.distractedByAlly = true;
              boss.distractTimer = 1.1;
            }
          }
        } else if (ally.swingTargetMinion != null &&
            !ally.swingTargetMinion!.isDefeated) {
          if (_dist(ally.x, ally.y, ally.swingTargetMinion!.x,
                  ally.swingTargetMinion!.y) <=
              1.55) {
            ally.totalHitsLanded++;
            _damageHelperMinion(ally.swingTargetMinion!, 16, stunDuration: 0.45);
          }
        }
      }

      if (ally.swingElapsed >= ally.swingDuration) {
        ally.isSwinging = false;
        ally.swingElapsed = 0.0;
        ally.state = AllyCombatState.escorting;
      }
      return;
    }

    // Escort anchor right next to the moving truck's side
    final perpAngle = truck.angle + math.pi * 0.5;
    final escortX = (truck.x + math.cos(perpAngle) * 1.15).clamp(
      RoadArenaBounds.playableMarginX,
      RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
    );
    final escortY = (truck.y + math.sin(perpAngle) * 1.15).clamp(
      RoadArenaBounds.playableMarginTop,
      RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
    );

    // Choose valid nearby threat within safe defensive perimeter of the truck!
    double? targetX;
    double? targetY;
    RoadHelperMinion? targetMinion;
    bool targetingBoss = false;

    for (final m in helperMinions) {
      if (m.isDefeated) continue;
      if (_dist(m.x, m.y, truck.x, truck.y) <= 3.1) {
        targetX = m.x;
        targetY = m.y;
        targetMinion = m;
        break;
      }
    }

    if (targetX == null && !boss.isDefeated && !boss.isCaged) {
      final bossDistToTruck = _dist(boss.x, boss.y, truck.x, truck.y);
      if (bossDistToTruck <= 3.4) {
        targetX = boss.x;
        targetY = boss.y;
        targetingBoss = true;
      }
    }

    const allySpeed = 3.25;
    if (targetX != null && targetY != null) {
      final distToTarget = _dist(ally.x, ally.y, targetX, targetY);
      ally.facingAngle = math.atan2(targetY - ally.y, targetX - ally.x);

      // Stand at clean readable fighting spacing (0.90..1.25 units) instead of overlapping boss!
      if (distToTarget <= 1.25) {
        ally.moveSpeedRatio = 0.0;
        if (ally.attackCooldown <= 0.0) {
          ally.state = AllyCombatState.slashing;
          ally.attackCooldown = 1.18;
          ally.isSwinging = true;
          ally.swingElapsed = 0.0;
          ally.hitConfirmedThisSwing = false;
          ally.comboStep = (ally.comboStep + 1) % 2; // Alternate Horizontal Swing & Counter Slash!
          ally.swingTargetingBoss = targetingBoss;
          ally.swingTargetMinion = targetMinion;
        }
      } else {
        ally.state = AllyCombatState.intercepting;
        ally.moveSpeedRatio = 0.95;
        ally.walkPhase += dt * 12.0;
        final nx = ally.x + math.cos(ally.facingAngle) * allySpeed * dt;
        final ny = ally.y + math.sin(ally.facingAngle) * allySpeed * dt;
        if (_dist(nx, ny, truck.x, truck.y) <= 3.55) {
          ally.x = nx.clamp(
            RoadArenaBounds.playableMarginX,
            RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
          );
          ally.y = ny.clamp(
            RoadArenaBounds.playableMarginTop,
            RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
          );
        }
      }
    } else {
      // Return smoothly to escorting the moving truck
      ally.state = AllyCombatState.escorting;
      final dEscort = _dist(ally.x, ally.y, escortX, escortY);
      if (dEscort > 0.16) {
        final angle = math.atan2(escortY - ally.y, escortX - ally.x);
        ally.facingAngle = angle;
        ally.moveSpeedRatio = 0.72;
        ally.walkPhase += dt * 9.5;
        final step = math.min(allySpeed * dt, dEscort);
        ally.x += math.cos(angle) * step;
        ally.y += math.sin(angle) * step;
      } else {
        ally.moveSpeedRatio = 0.0;
        if (!boss.isDefeated && !boss.isCaged) {
          ally.facingAngle = math.atan2(boss.y - ally.y, boss.x - ally.x);
        }
      }
    }

    // Soft separation so Ally never visually overlaps on top of Boss center
    if (!boss.isDefeated && !boss.isCaged) {
      final bdx = ally.x - boss.x;
      final bdy = ally.y - boss.y;
      final bDist = math.sqrt(bdx * bdx + bdy * bdy);
      if (bDist < 0.88 && bDist > 1e-4) {
        final push = 0.88 - bDist;
        ally.x = (ally.x + (bdx / bDist) * push).clamp(
          RoadArenaBounds.playableMarginX,
          RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
        );
        ally.y = (ally.y + (bdy / bDist) * push).clamp(
          RoadArenaBounds.playableMarginTop,
          RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
        );
      }
    }
  }

  // --- Giant Boss Combat AI (5 Attack Patterns + Level Progression) ---

  void _stepBossAi({
    required double dt,
    required bool playerHasShield,
    required bool playerIsInvulnerable,
    required void Function() onConsumePlayerShield,
    required void Function() onHitPlayerHealth,
  }) {
    if (boss.hitFlashTimer > 0) {
      boss.hitFlashTimer = (boss.hitFlashTimer - dt).clamp(0.0, 5.0);
    }
    if (boss.hurtRecoilTimer > 0) {
      boss.hurtRecoilTimer = (boss.hurtRecoilTimer - dt).clamp(0.0, 2.0);
    }
    if (boss.followThroughTimer > 0) {
      boss.followThroughTimer = (boss.followThroughTimer - dt).clamp(0.0, 2.0);
    }
    if (boss.shieldTimer > 0) {
      boss.shieldTimer = (boss.shieldTimer - dt).clamp(0.0, 10.0);
    }
    if (boss.attackCooldown > 0) {
      boss.attackCooldown = (boss.attackCooldown - dt).clamp(0.0, 10.0);
    }
    if (boss.distractTimer > 0) {
      boss.distractTimer = (boss.distractTimer - dt).clamp(0.0, 5.0);
      if (boss.distractTimer <= 0) boss.distractedByAlly = false;
    }

    if (boss.isCaged || boss.isDefeated) {
      boss.moveSpeedRatio = 0.0;
      return;
    }

    // Apply decaying knockback inside arena bounds
    if (boss.knockbackVx.abs() > 0.05 || boss.knockbackVy.abs() > 0.05) {
      boss.x = (boss.x + boss.knockbackVx * dt).clamp(
        RoadArenaBounds.playableMarginX,
        RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
      );
      boss.y = (boss.y + boss.knockbackVy * dt).clamp(
        RoadArenaBounds.playableMarginTop,
        RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
      );
      final decay = math.exp(-8.5 * dt);
      boss.knockbackVx *= decay;
      boss.knockbackVy *= decay;
    }

    // Frozen state (limbs strictly frozen!)
    if (boss.freezeTimer > 0) {
      boss.moveSpeedRatio = 0.0;
      boss.freezeTimer = (boss.freezeTimer - dt).clamp(0.0, 10.0);
      if (boss.freezeTimer <= 0) {
        boss.aiState = BossCombatAiState.pursuingTruck;
      }
      return;
    }

    // Stunned state (no walking/running while stunned!)
    if (boss.stunTimer > 0) {
      boss.moveSpeedRatio = 0.0;
      boss.stunTimer = (boss.stunTimer - dt).clamp(0.0, 10.0);
      if (boss.stunTimer <= 0) {
        boss.aiState = BossCombatAiState.pursuingTruck;
      }
      return;
    }

    boss.animPhase += dt * (boss.aiState == BossCombatAiState.charging ? 15.0 : 9.5);

    // Check Food Decoy distraction
    if (decoys.isNotEmpty && boss.aiState == BossCombatAiState.pursuingTruck) {
      final d = decoys.first;
      if (_dist(boss.x, boss.y, d.x, d.y) <= 4.5) {
        _moveBossToward(d.x, d.y, boss.baseSpeed * 0.9, dt);
        return;
      }
    }

    switch (boss.aiState) {
      case BossCombatAiState.pursuingTruck:
        final tx = boss.distractedByAlly ? ally.x : truck.x;
        final ty = boss.distractedByAlly ? ally.y : truck.y;
        final distToTruck = _dist(boss.x, boss.y, truck.x, truck.y);

        _moveBossToward(tx, ty, boss.baseSpeed, dt);

        // Select next telegraphed attack when ready & within engagement range
        if (boss.attackCooldown <= 0.0 && distToTruck <= 5.4) {
          _queueNextBossAttack(distToTruck);
        }
        break;

      case BossCombatAiState.telegraphing:
        boss.moveSpeedRatio = 0.0;
        boss.stateTimer += dt;
        boss.facingAngle = math.atan2(
          boss.telegraphTargetY - boss.y,
          boss.telegraphTargetX - boss.x,
        );
        if (boss.stateTimer >= boss.telegraphDuration) {
          _executeQueuedBossAttack(
            playerHasShield: playerHasShield,
            playerIsInvulnerable: playerIsInvulnerable,
            onConsumePlayerShield: onConsumePlayerShield,
            onHitPlayerHealth: onHitPlayerHealth,
          );
        }
        break;

      case BossCombatAiState.charging:
        boss.moveSpeedRatio = 1.0;
        boss.stateTimer += dt;
        final chargeSpeed = boss.baseSpeed * 2.35;
        final dx = boss.telegraphTargetX - boss.x;
        final dy = boss.telegraphTargetY - boss.y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d > 0.25 && boss.stateTimer < 0.85) {
          boss.x = (boss.x + (dx / d) * chargeSpeed * dt).clamp(
            RoadArenaBounds.playableMarginX,
            RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
          );
          boss.y = (boss.y + (dy / d) * chargeSpeed * dt).clamp(
            RoadArenaBounds.playableMarginTop,
            RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
          );

          // Spawn heavy running charge dust puffs beneath feet!
          boss.dustSpawnTimer -= dt;
          if (boss.dustSpawnTimer <= 0.0) {
            boss.dustSpawnTimer = 0.14;
            dustPuffs.add(DustPuffEntity(
              x: boss.x - (dx / d) * 0.35,
              y: boss.y + 0.48,
              maxRadius: 0.34,
              colorHex: 0xFFCDB79E,
            ));
          }

          // Check collision with Truck
          if (_dist(boss.x, boss.y, truck.x, truck.y) <=
              bossRadius + truckCollisionRadius * 0.85) {
            final isTire = boss.queuedAttack == BossAttackType.tireAttack;
            final dmg = _scaledDmg(isTire ? 9 : 16);
            damageTruck(dmg, isTireAttack: isTire);
            if (!isTire) {
              truck.slamSlowTimer = math.max(truck.slamSlowTimer, 1.3);
            }
            boss.lastExecutedAttack =
                isTire ? BossAttackType.tireAttack : BossAttackType.directCharge;
            boss.followThroughTimer = 0.38;
            boss.aiState = BossCombatAiState.recovering;
            boss.stateTimer = 0.0;
            boss.queuedAttack = null;
            boss.attackCooldown = boss.attackInterval;
            break;
          }

          // Check collision with Ally (pushes ally into brief hurt recoil + recovery)
          if (ally.hasKnifeDrawn &&
              ally.state != AllyCombatState.recovering &&
              _dist(boss.x, boss.y, ally.x, ally.y) <= bossRadius + 0.35) {
            ally.state = AllyCombatState.recovering;
            ally.isSwinging = false;
            ally.recoverTimer = 1.35;
            ally.hitFlashTimer = 0.35;
            ally.hurtRecoilTimer = 0.36;
          }

          // Check collision with Courier
          if (_dist(boss.x, boss.y, playerX, playerY) <=
              bossRadius + playerRadius) {
            _hitPlayer(
              playerHasShield: playerHasShield,
              playerIsInvulnerable: playerIsInvulnerable,
              onConsumePlayerShield: onConsumePlayerShield,
              onHitPlayerHealth: onHitPlayerHealth,
            );
          }
        } else {
          boss.aiState = BossCombatAiState.recovering;
          boss.stateTimer = 0.0;
          boss.queuedAttack = null;
          boss.attackCooldown = boss.attackInterval * 0.9;
        }
        break;

      case BossCombatAiState.recovering:
        boss.stateTimer += dt;
        if (boss.stateTimer >= 0.72) {
          boss.aiState = BossCombatAiState.pursuingTruck;
          boss.stateTimer = 0.0;
        }
        break;

      case BossCombatAiState.caged:
      case BossCombatAiState.escaping:
      case BossCombatAiState.stunned:
      case BossCombatAiState.frozen:
      case BossCombatAiState.defeated:
      case BossCombatAiState.retreating:
        break;
    }
  }

  void _queueNextBossAttack(double distToTruck) {
    if (boss.attackPool.isEmpty) return;
    BossAttackType chosen =
        boss.attackPool[boss.patternCursor % boss.attackPool.length];
    boss.patternCursor++;

    // If far from truck & bomb/special is available, prefer ranged bomb so boss stays threatening
    if (distToTruck > 3.6 &&
        chosen == BossAttackType.tireAttack &&
        boss.attackPool.contains(BossAttackType.bombProjectile)) {
      chosen = BossAttackType.bombProjectile;
    }

    boss.queuedAttack = chosen;
    boss.aiState = BossCombatAiState.telegraphing;
    boss.stateTimer = 0.0;

    // Lead slightly ahead along the road for fair, dodgeable/interceptable targeting
    final leadSample = config.road.sampleAtDistance(
      (truck.traveledDistance + 0.85).clamp(0.0, config.road.totalLength),
    );

    switch (chosen) {
      case BossAttackType.bombProjectile:
        boss.telegraphDuration = 0.78;
        boss.telegraphTargetX = leadSample.x;
        boss.telegraphTargetY = leadSample.y;
        break;
      case BossAttackType.tireAttack:
        boss.telegraphDuration = 0.72;
        boss.telegraphTargetX = truck.x;
        boss.telegraphTargetY = truck.y;
        break;
      case BossAttackType.directCharge:
        boss.telegraphDuration = 0.82;
        boss.telegraphTargetX = truck.x;
        boss.telegraphTargetY = truck.y;
        break;
      case BossAttackType.groundSlam:
        boss.telegraphDuration = 0.92;
        boss.telegraphTargetX = leadSample.x;
        boss.telegraphTargetY = leadSample.y;
        break;
      case BossAttackType.specialAbility:
        boss.telegraphDuration = 0.85;
        boss.telegraphTargetX = leadSample.x;
        boss.telegraphTargetY = leadSample.y;
        break;
    }

    popups.add(FloatingPopup(
      text: chosen.telegraphLabel,
      worldX: boss.x,
      worldY: boss.y - 0.9,
      colorHex: 0xFFFF715B,
      lifetime: 0.75,
    ));
  }

  void _executeQueuedBossAttack({
    required bool playerHasShield,
    required bool playerIsInvulnerable,
    required void Function() onConsumePlayerShield,
    required void Function() onHitPlayerHealth,
  }) {
    final attack = boss.queuedAttack ?? BossAttackType.directCharge;
    boss.stateTimer = 0.0;

    switch (attack) {
      case BossAttackType.bombProjectile:
        // Launch bomb directly from the boss's extended throwing hand!
        final handX = boss.x + math.cos(boss.facingAngle) * 0.58;
        final handY = boss.y + math.sin(boss.facingAngle) * 0.58 - 0.25;
        bossProjectiles.add(BossProjectileEntity(
          isBomb: true,
          startX: handX,
          startY: handY,
          targetX: boss.telegraphTargetX,
          targetY: boss.telegraphTargetY,
          travelDuration: 1.05,
          damage: _scaledDmg(15),
          blastRadius: 1.05,
        ));
        boss.lastExecutedAttack = BossAttackType.bombProjectile;
        boss.followThroughTimer = 0.42;
        boss.aiState = BossCombatAiState.recovering;
        boss.queuedAttack = null;
        boss.attackCooldown = boss.attackInterval;
        break;

      case BossAttackType.tireAttack:
      case BossAttackType.directCharge:
        boss.aiState = BossCombatAiState.charging;
        boss.stateTimer = 0.0;
        break;

      case BossAttackType.groundSlam:
        boss.lastExecutedAttack = BossAttackType.groundSlam;
        boss.followThroughTimer = 0.45;
        hazards.add(RoadHazardZone(
          kind: RoadHazardKind.groundSlamCrater,
          x: boss.telegraphTargetX,
          y: boss.telegraphTargetY,
          radius: 1.15,
          remainingTime: 4.5,
          damageOnContact: _scaledDmg(12),
        ));
        vfx.add(CombatVfx(
          type: CombatVfxType.stunPulseRing,
          x: boss.telegraphTargetX,
          y: boss.telegraphTargetY,
          maxRadius: 1.35,
          colorHex: 0xFFE63946,
          duration: 0.42,
        ));
        if (_dist(playerX, playerY, boss.telegraphTargetX,
                boss.telegraphTargetY) <=
            1.15) {
          _hitPlayer(
            playerHasShield: playerHasShield,
            playerIsInvulnerable: playerIsInvulnerable,
            onConsumePlayerShield: onConsumePlayerShield,
            onHitPlayerHealth: onHitPlayerHealth,
          );
        }
        boss.aiState = BossCombatAiState.recovering;
        boss.queuedAttack = null;
        boss.attackCooldown = boss.attackInterval;
        break;

      case BossAttackType.specialAbility:
        final sub = boss.patternCursor % 4;
        if (sub == 0) {
          // Slowing fantasy cloud on road ahead
          hazards.add(RoadHazardZone(
            kind: RoadHazardKind.slowingCloud,
            x: boss.telegraphTargetX,
            y: boss.telegraphTargetY,
            radius: 1.35,
            remainingTime: 4.8,
            damageOnContact: 0,
          ));
        } else if (sub == 1) {
          // Multi-orb magical volley (2 orbs)
          for (final offset in const [-0.55, 0.55]) {
            bossProjectiles.add(BossProjectileEntity(
              isBomb: false,
              startX: boss.x,
              startY: boss.y,
              targetX: (boss.telegraphTargetX + offset)
                  .clamp(0.8, RoadArenaBounds.width - 0.8),
              targetY: boss.telegraphTargetY,
              travelDuration: 0.9,
              damage: _scaledDmg(10),
              blastRadius: 0.78,
            ));
          }
        } else if (sub == 2 && helperMinions.length < 2) {
          // Summon small helper monster!
          helperMinions.add(RoadHelperMinion(
            x: (boss.x + 0.8).clamp(1.0, RoadArenaBounds.width - 1.0),
            y: (boss.y + 0.5).clamp(1.5, RoadArenaBounds.height - 1.5),
            hp: 32 + config.difficultyTier * 4,
          ));
          popups.add(FloatingPopup(
            text: 'Helper Summoned!',
            worldX: boss.x,
            worldY: boss.y - 0.85,
            colorHex: 0xFF9333EA,
            lifetime: 1.1,
          ));
        } else {
          // Defensive boss shield (3.4s)
          boss.shieldTimer = 3.4;
          popups.add(FloatingPopup(
            text: 'Boss Shield!',
            worldX: boss.x,
            worldY: boss.y - 0.85,
            colorHex: 0xFF7C3AED,
            lifetime: 1.1,
          ));
        }
        boss.aiState = BossCombatAiState.recovering;
        boss.queuedAttack = null;
        boss.attackCooldown = boss.attackInterval * 1.1;
        break;
    }
  }

  void _stepBossProjectiles({
    required double dt,
    required bool playerHasShield,
    required bool playerIsInvulnerable,
    required void Function() onConsumePlayerShield,
    required void Function() onHitPlayerHealth,
  }) {
    for (final bp in bossProjectiles) {
      if (!bp.active) continue;
      bp.age += dt;
      final t = bp.progress;
      bp.x = bp.startX + (bp.targetX - bp.startX) * t;
      bp.y = bp.startY + (bp.targetY - bp.startY) * t;

      if (t >= 1.0) {
        bp.active = false;
        vfx.add(CombatVfx(
          type: CombatVfxType.hitBurst,
          x: bp.targetX,
          y: bp.targetY,
          maxRadius: bp.blastRadius * 1.1,
          colorHex: bp.isBomb ? 0xFFFF715B : 0xFFA855F7,
          duration: 0.35,
        ));

        if (_dist(truck.x, truck.y, bp.targetX, bp.targetY) <=
            bp.blastRadius + truckCollisionRadius * 0.65) {
          damageTruck(bp.damage);
        }
        if (_dist(playerX, playerY, bp.targetX, bp.targetY) <= bp.blastRadius) {
          _hitPlayer(
            playerHasShield: playerHasShield,
            playerIsInvulnerable: playerIsInvulnerable,
            onConsumePlayerShield: onConsumePlayerShield,
            onHitPlayerHealth: onHitPlayerHealth,
          );
        }
      }
    }
    bossProjectiles.removeWhere((b) => !b.active);
  }

  void _stepHelperMinions({
    required double dt,
    required bool playerHasShield,
    required bool playerIsInvulnerable,
    required void Function() onConsumePlayerShield,
    required void Function() onHitPlayerHealth,
  }) {
    for (final m in helperMinions) {
      if (m.isDefeated) continue;
      if (m.hitFlashTimer > 0) {
        m.hitFlashTimer = (m.hitFlashTimer - dt).clamp(0.0, 5.0);
      }
      if (m.attackCooldown > 0) {
        m.attackCooldown = (m.attackCooldown - dt).clamp(0.0, 5.0);
      }
      if (m.stunTimer > 0) {
        m.stunTimer = (m.stunTimer - dt).clamp(0.0, 5.0);
        continue;
      }

      m.animPhase += dt * 10.0;
      final dx = truck.x - m.x;
      final dy = truck.y - m.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 0.85) {
        m.facingAngle = math.atan2(dy, dx);
        m.x += (dx / d) * m.speed * dt;
        m.y += (dy / d) * m.speed * dt;
      } else if (m.attackCooldown <= 0.0) {
        m.attackCooldown = 2.0;
        damageTruck(_scaledDmg(6));
      }

      if (_dist(m.x, m.y, playerX, playerY) <= 0.68 && m.attackCooldown <= 0.0) {
        m.attackCooldown = 1.8;
        _hitPlayer(
          playerHasShield: playerHasShield,
          playerIsInvulnerable: playerIsInvulnerable,
          onConsumePlayerShield: onConsumePlayerShield,
          onHitPlayerHealth: onHitPlayerHealth,
        );
      }
    }
    helperMinions.removeWhere((m) => m.isDefeated);
  }

  void _moveBossToward(double tx, double ty, double speed, double dt) {
    final dx = tx - boss.x;
    final dy = ty - boss.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 0.85) {
      boss.moveSpeedRatio = 0.0;
      return;
    }
    boss.facingAngle = math.atan2(dy, dx);
    boss.moveSpeedRatio = d > 1.8 ? 0.92 : 0.55;
    boss.x = (boss.x + (dx / d) * speed * dt).clamp(
      RoadArenaBounds.playableMarginX,
      RoadArenaBounds.width - RoadArenaBounds.playableMarginX,
    );
    boss.y = (boss.y + (dy / d) * speed * dt).clamp(
      RoadArenaBounds.playableMarginTop,
      RoadArenaBounds.height - RoadArenaBounds.playableMarginBottom,
    );

    if (boss.moveSpeedRatio > 0.7) {
      boss.dustSpawnTimer -= dt;
      if (boss.dustSpawnTimer <= 0.0) {
        boss.dustSpawnTimer = 0.28;
        dustPuffs.add(DustPuffEntity(
          x: boss.x - (dx / d) * 0.3,
          y: boss.y + 0.45,
          maxRadius: 0.25,
          colorHex: 0xFFD9C7A3,
        ));
      }
    }
  }

  void _hitPlayer({
    required bool playerHasShield,
    required bool playerIsInvulnerable,
    required void Function() onConsumePlayerShield,
    required void Function() onHitPlayerHealth,
  }) {
    if (playerIsInvulnerable) return;
    if (playerHasShield) {
      onConsumePlayerShield();
      vfx.add(CombatVfx(
        type: CombatVfxType.shieldBreak,
        x: playerX,
        y: playerY,
        maxRadius: 1.0,
        colorHex: 0xFF38BDF8,
        duration: 0.35,
      ));
      popups.add(FloatingPopup(
        text: 'Shield Blocked!',
        worldX: playerX,
        worldY: playerY - 0.65,
        colorHex: 0xFF0284C7,
        lifetime: 1.1,
      ));
      callbacks.onShieldBlocked?.call();
      return;
    }

    popups.add(FloatingPopup(
      text: 'Ouch! -1 Heart',
      worldX: playerX,
      worldY: playerY - 0.65,
      colorHex: 0xFFD62828,
      lifetime: 1.1,
    ));
    onHitPlayerHealth();
    applyStun(0.40);
    callbacks.onPlayerDamaged?.call();
  }

  void _stepVfxAndPopups(double dt) {
    for (final p in popups) {
      p.age += dt;
    }
    popups.removeWhere((p) => p.isExpired);

    for (final fx in vfx) {
      fx.age += dt;
    }
    vfx.removeWhere((fx) => fx.isExpired);

    for (final d in dustPuffs) {
      d.age += dt;
    }
    dustPuffs.removeWhere((d) => d.isExpired);
  }

  /// Builds the authoritative V3.4 animation snapshot for the Dock Worker Ally
  /// during the Road Battle & Escape Cutscene.
  DockWorkerAnimSnapshot buildRoadAllyAnimSnapshot(double elapsed) {
    DockWorkerAnimState animState;
    DockWorkerExpression expr;
    double progress = 0.0;

    if (ally.state == AllyCombatState.celebrating) {
      animState = DockWorkerAnimState.celebrating;
      expr = DockWorkerExpression.celebrating;
    } else if (ally.hurtRecoilTimer > 0) {
      animState = DockWorkerAnimState.hurtRecoil;
      expr = DockWorkerExpression.hurt;
      progress = (1.0 - ally.hurtRecoilTimer / 0.36).clamp(0.0, 1.0);
    } else if (!ally.hasKnifeDrawn) {
      animState = ally.state == AllyCombatState.surprised
          ? DockWorkerAnimState.surprised
          : DockWorkerAnimState.idleWaiting;
      expr = ally.state == AllyCombatState.surprised
          ? DockWorkerExpression.surprised
          : DockWorkerExpression.friendly;
    } else if (ally.knifeDrawTimer > 0) {
      animState = DockWorkerAnimState.drawingKnife;
      expr = DockWorkerExpression.surprised;
      progress = (1.0 - ally.knifeDrawTimer / 0.45).clamp(0.0, 1.0);
    } else if (ally.isSwinging) {
      animState = ally.comboStep == 0
          ? DockWorkerAnimState.knifeHorizontalSwing
          : DockWorkerAnimState.knifeCounterSlash;
      expr = DockWorkerExpression.determinedStrike;
      progress = ally.swingProgress;
    } else if (ally.moveSpeedRatio > 0.2) {
      animState = DockWorkerAnimState.advancing;
      expr = DockWorkerExpression.focusedCombat;
    } else {
      animState = DockWorkerAnimState.defendStance;
      expr = DockWorkerExpression.focusedCombat;
    }

    return DockWorkerAnimSnapshot(
      state: animState,
      expression: expr,
      facingAngle: ally.facingAngle,
      walkCyclePhase: ally.walkPhase,
      stateProgress: progress,
      elapsed: elapsed,
      hasKnifeDrawn: ally.hasKnifeDrawn,
      hurtRecoilProgress: (ally.hurtRecoilTimer / 0.36).clamp(0.0, 1.0),
    );
  }

  /// Builds the authoritative V3.4 animation snapshot for the Giant District Boss.
  BossAnimSnapshot buildBossAnimSnapshot(double elapsed) {
    BossAnimState animState;
    BossExpression expr;
    double progress = 0.0;
    bool holdingBomb = false;

    if (boss.isDefeated) {
      animState = BossAnimState.defeated;
      expr = BossExpression.defeatedWeak;
    } else if (boss.aiState == BossCombatAiState.retreating) {
      animState = BossAnimState.retreating;
      expr = BossExpression.defeatedWeak;
    } else if (boss.isCaged) {
      final breaking = cageState == BossCageState.rattling ||
          cageState == BossCageState.lockBreaking;
      animState = breaking ? BossAnimState.breakingCage : BossAnimState.cagedIdle;
      expr = breaking ? BossExpression.furiousRoar : BossExpression.angryCaged;
    } else if (boss.freezeTimer > 0) {
      animState = BossAnimState.frozen;
      expr = BossExpression.painRecoil;
    } else if (boss.stunTimer > 0) {
      animState = BossAnimState.stunned;
      expr = BossExpression.dizzyStunned;
    } else if (boss.hurtRecoilTimer > 0) {
      animState = BossAnimState.hurtRecoil;
      expr = BossExpression.painRecoil;
      progress = (1.0 - boss.hurtRecoilTimer / 0.28).clamp(0.0, 1.0);
    } else if (boss.aiState == BossCombatAiState.telegraphing) {
      progress = boss.telegraphProgress;
      expr = BossExpression.focusedWindup;
      switch (boss.queuedAttack ?? BossAttackType.directCharge) {
        case BossAttackType.bombProjectile:
          animState = BossAnimState.windupBomb;
          holdingBomb = true;
          break;
        case BossAttackType.tireAttack:
          animState = BossAnimState.windupTireAttack;
          break;
        case BossAttackType.directCharge:
          animState = BossAnimState.windupCharge;
          break;
        case BossAttackType.groundSlam:
          animState = BossAnimState.windupSlam;
          break;
        case BossAttackType.specialAbility:
          animState = BossAnimState.specialCast;
          break;
      }
    } else if (boss.aiState == BossCombatAiState.charging) {
      animState = boss.queuedAttack == BossAttackType.tireAttack
          ? BossAnimState.tireStrike
          : BossAnimState.charging;
      expr = BossExpression.attackRoar;
      progress = (boss.stateTimer / 0.85).clamp(0.0, 1.0);
    } else if (boss.followThroughTimer > 0) {
      progress = (1.0 - boss.followThroughTimer / 0.42).clamp(0.0, 1.0);
      expr = BossExpression.attackRoar;
      switch (boss.lastExecutedAttack ?? BossAttackType.directCharge) {
        case BossAttackType.bombProjectile:
          animState = BossAnimState.throwBomb;
          break;
        case BossAttackType.groundSlam:
          animState = BossAnimState.groundSlam;
          break;
        case BossAttackType.tireAttack:
          animState = BossAnimState.tireStrike;
          break;
        case BossAttackType.directCharge:
          animState = BossAnimState.clawStrike;
          break;
        case BossAttackType.specialAbility:
          animState = BossAnimState.specialCast;
          break;
      }
    } else if (boss.moveSpeedRatio > 0.65) {
      animState = BossAnimState.run;
      expr = boss.hpRatio <= 0.35
          ? BossExpression.exhaustedLowHp
          : BossExpression.aggressiveChase;
    } else if (boss.moveSpeedRatio > 0.1) {
      animState = BossAnimState.walk;
      expr = boss.hpRatio <= 0.35
          ? BossExpression.exhaustedLowHp
          : BossExpression.aggressiveChase;
    } else {
      animState = BossAnimState.idle;
      expr = boss.hpRatio <= 0.35
          ? BossExpression.exhaustedLowHp
          : BossExpression.angryCaged;
    }

    return BossAnimSnapshot(
      bossType: boss.type,
      appearance: boss.appearance,
      state: animState,
      expression: expr,
      facingAngle: boss.facingAngle,
      walkCyclePhase: boss.animPhase,
      stateProgress: progress,
      elapsed: elapsed,
      hpRatio: boss.hpRatio,
      hurtRecoilProgress: (boss.hurtRecoilTimer / 0.28).clamp(0.0, 1.0),
      recoilDirX: boss.recoilDirX,
      recoilDirY: boss.recoilDirY,
      hasShield: boss.hasShield,
      isHoldingBomb: holdingBomb,
      isCaged: boss.isCaged,
    );
  }

  int _scaledDmg(int base) =>
      math.max(4, (base * boss.damageScale / 100.0).round());

  static double _dist(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return math.sqrt(dx * dx + dy * dy);
  }
}

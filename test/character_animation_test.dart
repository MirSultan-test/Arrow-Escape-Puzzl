import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/models/maze/character_animation_state.dart';
import 'package:parcel_escape/src/models/maze/combat_models.dart';
import 'package:parcel_escape/src/models/maze/delivery_state.dart';
import 'package:parcel_escape/src/models/maze/food_item.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/truck_defense_models.dart';

List<MazeLevel> _loadLevels() {
  final raw = jsonDecode(
    File('assets/levels/maze_levels.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (raw['levels'] as List)
      .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  late List<MazeLevel> levels;

  setUpAll(() {
    levels = _loadLevels();
  });

  group('V3.4 Character Animations, Facial Expressions & Combat Sync Tests', () {
    test('1 & 2. Courier legs animate when moving, stop when stationary, and face actual movement direction', () {
      final lv4 = levels.firstWhere((l) => l.id == 4);
      final engine = MazeGameEngine(level: lv4);

      // Stationary -> idle, moveSpeedRatio == 0, walkPhase stays fixed!
      final phaseIdle0 = engine.walkAnimPhase;
      engine.step(0.05);
      engine.step(0.05);
      final idleSnap = engine.buildCourierAnimSnapshot();
      expect(idleSnap.state, CourierAnimState.idle);
      expect(idleSnap.moveSpeedRatio, 0.0);
      expect(engine.walkAnimPhase, phaseIdle0);

      // Walk slowly -> walk state, facing right
      engine.setJoystickInput(0.4, 0.0);
      engine.step(0.05);
      final walkSnap = engine.buildCourierAnimSnapshot();
      expect(walkSnap.state, CourierAnimState.walk);
      expect(walkSnap.facingAngle, closeTo(0.0, 0.05));
      final walkDelta = engine.walkAnimPhase - phaseIdle0;
      expect(walkDelta, greaterThan(0.0));

      // Run fast diagonally up-left -> run state, faster leg cadence, correct diagonal facing angle!
      final phaseBeforeRun = engine.walkAnimPhase;
      engine.setJoystickInput(-0.75, -0.75);
      engine.step(0.05);
      final runSnap = engine.buildCourierAnimSnapshot();
      expect(runSnap.state, CourierAnimState.run);
      expect(runSnap.facingAngle, closeTo(-math.pi * 0.75, 0.08));
      expect(engine.walkAnimPhase - phaseBeforeRun, greaterThan(walkDelta));
    });

    test('3. Courier facial expressions change visibly by situation (relaxed, focused, alert, determined, pain, happy, smiling, worried, excited)', () {
      final lv7 = levels.firstWhere((l) => l.id == 7);
      final engine = MazeGameEngine(level: lv7);

      // Idle far from monsters -> relaxed
      for (final m in engine.monsters) {
        m.hp = 0;
      }
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.relaxed);

      // Running -> focused
      engine.setJoystickInput(1.0, 0.0);
      engine.step(0.04);
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.focused);
      engine.setJoystickInput(0.0, 0.0);

      // Pickup food -> happy
      final f = engine.foods.first;
      engine.playerX = f.spawnCol + 0.5;
      engine.playerY = f.spawnRow + 0.5;
      engine.step(0.02);
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.happy);

      // Deliver food -> smiling
      engine.pickupAnimTimer = 0.0;
      engine.playerX = lv7.exitCell.centerX;
      engine.playerY = lv7.exitCell.centerY;
      engine.step(0.02);
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.smiling);

      // Attacking with Bow -> determined
      engine.deliveryAnimTimer = 0.0;
      engine.useWeapon(WeaponType.bow);
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.determined);

      // Taking damage -> pain
      engine.damageFlashTimer = 0.35;
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.pain);

      // Low health (1 heart) -> worried
      engine.damageFlashTimer = 0.0;
      engine.attackAnimTimer = 0.0;
      engine.health = 1;
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.worried);

      // Winning -> excited
      engine.phase = MazeGamePhase.victory;
      expect(engine.buildCourierAnimSnapshot().expression, CourierExpression.excited);
    });

    test('4 & 5. Bow firing plays aimBow -> releaseBow and launches arrow from weapon tip (not center)', () {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);
      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      engine.truckDefense.playerX = 3.0;
      engine.truckDefense.playerY = 6.0;
      engine.truckDefense.boss.x = 6.0;
      engine.truckDefense.boss.y = 6.0;

      expect(engine.useWeapon(WeaponType.bow), isTrue);
      // Immediately enters aimBow phase!
      expect(engine.buildCourierAnimSnapshot().state, CourierAnimState.aimBow);

      // Arrow launched forward from bow tip (+X offset from Courier center)
      expect(engine.truckDefense.playerProjectiles.length, 1);
      final arrow = engine.truckDefense.playerProjectiles.first;
      expect(arrow.x, greaterThan(engine.truckDefense.playerX + 0.35));

      // Advance halfway through attack animation -> transitions smoothly to releaseBow follow-through!
      for (int i = 0; i < 4; i++) {
        engine.step(0.04);
      }
      expect(engine.buildCourierAnimSnapshot().state, CourierAnimState.releaseBow);
    });

    test('6 & 7. Dock Worker receives & carries actual food with both hands before escape, and draws knife ONLY after escape', () {
      final lv4 = levels.firstWhere((l) => l.id == 4);
      final engine = MazeGameEngine(level: lv4);

      // Before escape: peaceful, knife NOT drawn
      final waitSnap = engine.buildMazeDockWorkerAnimSnapshot();
      expect(waitSnap.hasKnifeDrawn, isFalse);
      expect(
        waitSnap.state == DockWorkerAnimState.idleWaiting ||
            waitSnap.state == DockWorkerAnimState.waving,
        isTrue,
      );

      // Deliver 1 food item (not all) -> Dock Worker physically holds & carries it to the truck!
      final food0 = engine.foods.first;
      food0.status = FoodStatus.carried;
      engine.playerX = lv4.exitCell.centerX;
      engine.playerY = lv4.exitCell.centerY;
      engine.step(0.02);

      final recvSnap = engine.buildMazeDockWorkerAnimSnapshot();
      expect(recvSnap.hasKnifeDrawn, isFalse);
      expect(recvSnap.state, DockWorkerAnimState.receivingFood);
      expect(recvSnap.carriedFoodType, food0.type);

      // Advance into carryingToTruck -> loadingTruck
      for (int i = 0; i < 12; i++) {
        engine.step(0.05);
      }
      final carrySnap = engine.buildMazeDockWorkerAnimSnapshot();
      expect(carrySnap.hasKnifeDrawn, isFalse);
      expect(
        carrySnap.state == DockWorkerAnimState.carryingToTruck ||
            carrySnap.state == DockWorkerAnimState.loadingTruck,
        isTrue,
      );
      expect(carrySnap.carriedFoodType, food0.type);
    });

    test('8, 12, 13, 14 & 15. Dock Worker knife combo synchronizes hit-frame damage (no frame-0 hit, no duplicate damage per swing) & Boss visibly recoils', () {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);
      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      final td = engine.truckDefense;
      final ally = td.ally;
      final boss = td.boss;

      // Place ally within melee knife range of boss
      boss.x = td.truck.x + 1.0;
      boss.y = td.truck.y + 0.4;
      ally.x = boss.x - 0.9;
      ally.y = boss.y;
      ally.attackCooldown = 0.0;
      final hpBefore = boss.hp;

      // Frame 1: Ally begins wind-up -> NO premature instant damage yet!
      engine.step(0.04);
      expect(ally.isSwinging, isTrue);
      expect(ally.hitConfirmedThisSwing, isFalse);
      expect(boss.hp, hpBefore);
      final swingSnap = td.buildRoadAllyAnimSnapshot(engine.elapsedTime);
      expect(
        swingSnap.state == DockWorkerAnimState.knifeHorizontalSwing ||
            swingSnap.state == DockWorkerAnimState.knifeCounterSlash,
        isTrue,
      );

      // Advance through active slash hit-frame (t >= 0.36 of 0.42s = ~0.15s) -> damage confirmed ONCE!
      for (int i = 0; i < 5; i++) {
        engine.step(0.04);
      }
      expect(ally.hitConfirmedThisSwing, isTrue);
      final hpAfterHit = boss.hp;
      expect(hpAfterHit, lessThan(hpBefore));
      expect(ally.totalHitsLanded, 1);
      // Boss visibly reacts with hurtRecoil & painRecoil expression!
      expect(boss.hurtRecoilTimer, greaterThan(0.0));
      expect(td.buildBossAnimSnapshot(engine.elapsedTime).expression,
          BossExpression.painRecoil);

      // Remaining recovery frames of the same swing MUST NOT duplicate damage!
      for (int i = 0; i < 6; i++) {
        engine.step(0.04);
      }
      expect(boss.hp, hpAfterHit);
      expect(ally.totalHitsLanded, 1);
    });

    test('9, 10 & 11. Giant Monster runs with dust puffs, holds live bomb during windupBomb, launches bomb from hand, and changes facial expressions', () {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);
      final td = engine.truckDefense;

      // While caged -> angryCaged
      expect(td.buildBossAnimSnapshot(0.5).state, BossAnimState.cagedIdle);
      expect(td.buildBossAnimSnapshot(0.5).expression, BossExpression.angryCaged);

      // Enter Truck Defense -> pursuing/running with dust puffs
      td.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;
      td.boss.x = td.truck.x - 3.5;
      td.boss.y = td.truck.y;
      td.boss.attackCooldown = 5.0;
      td.ally.attackCooldown = 5.0; // Isolate pure boss running state without ally hit recoil
      for (int i = 0; i < 10; i++) {
        engine.step(0.05);
      }
      final runSnap = td.buildBossAnimSnapshot(engine.elapsedTime);
      expect(runSnap.state, BossAnimState.run);
      expect(runSnap.expression, BossExpression.aggressiveChase);
      expect(td.dustPuffs, isNotEmpty);

      // Bomb Throw Windup -> holds live bomb visibly in hand!
      td.boss.aiState = BossCombatAiState.telegraphing;
      td.boss.queuedAttack = BossAttackType.bombProjectile;
      td.boss.telegraphDuration = 0.78;
      td.boss.stateTimer = 0.4;
      td.boss.telegraphTargetX = td.truck.x;
      td.boss.telegraphTargetY = td.truck.y;
      final bombWindupSnap = td.buildBossAnimSnapshot(engine.elapsedTime);
      expect(bombWindupSnap.state, BossAnimState.windupBomb);
      expect(bombWindupSnap.isHoldingBomb, isTrue);
      expect(bombWindupSnap.expression, BossExpression.focusedWindup);

      // Complete windup -> Bomb launches from hand + boss plays throwBomb follow-through!
      for (int i = 0; i < 10; i++) {
        engine.step(0.05);
      }
      expect(td.bossProjectiles, isNotEmpty);
      expect(td.buildBossAnimSnapshot(engine.elapsedTime).state, BossAnimState.throwBomb);

      // Stunned -> dizzyStunned expression & legs stop moving!
      td.boss.stunTimer = 1.5;
      td.boss.aiState = BossCombatAiState.stunned;
      final stunSnap = td.buildBossAnimSnapshot(engine.elapsedTime);
      expect(stunSnap.state, BossAnimState.stunned);
      expect(stunSnap.expression, BossExpression.dizzyStunned);
    });
  });
}

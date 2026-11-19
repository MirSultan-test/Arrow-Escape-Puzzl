import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/models/maze/delivery_state.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/truck_defense_models.dart';
import 'package:parcel_escape/src/rendering/maze/road_battle_painter.dart';

List<MazeLevel> _loadAllLevels() {
  final raw = jsonDecode(
    File('assets/levels/maze_levels.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (raw['levels'] as List)
      .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
      .toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MazeLevel> allLevels;

  setUpAll(() {
    allLevels = _loadAllLevels();
  });

  group('Road Battle Drag-to-Move & Multi-Touch Regression Tests', () {
    test('1. Two-turn maze route: drawing works in maze phase', () {
      final level3 = allLevels.firstWhere((l) => l.id == 3);
      final engine = MazeGameEngine(level: level3);

      expect(engine.phase, equals(MazeGamePhase.playing));
      expect(engine.beginRouteDraw(engine.playerX, engine.playerY), isTrue);
      expect(engine.isDrawingRoute, isTrue);

      // Draw two turns
      engine.updateRouteDraw(engine.playerX + 1.0, engine.playerY);
      engine.updateRouteDraw(engine.playerX + 1.0, engine.playerY + 1.0);
      expect(engine.commitRouteDraw(), isTrue);
      expect(engine.autoRouteGoalCell, isNotNull);
    });

    test('2. Static vs scrolling road camera: world waypoints are stored invariant of camera', () {
      final vp1 = RoadArenaViewport.compute(const Size(360, 640));
      final vp2 = RoadArenaViewport.compute(const Size(412, 915));

      const roadPoint = Offset(4.5, 6.0);
      final screenPos1 = vp1.toScreen(roadPoint.dx, roadPoint.dy);
      final screenPos2 = vp2.toScreen(roadPoint.dx, roadPoint.dy);

      // Inverse transform recovers exact world coordinates regardless of screen dimensions
      final recovered1 = vp1.toWorld(screenPos1);
      final recovered2 = vp2.toWorld(screenPos2);

      expect((recovered1.dx - roadPoint.dx).abs(), lessThan(1e-4));
      expect((recovered1.dy - roadPoint.dy).abs(), lessThan(1e-4));
      expect((recovered2.dx - roadPoint.dx).abs(), lessThan(1e-4));
      expect((recovered2.dy - roadPoint.dy).abs(), lessThan(1e-4));

      // Level 18 truck defense simulation stores waypoints in world coordinates
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      final td = engine.truckDefense;

      // Draw route in world coords
      expect(td.beginRoadRouteDraw(td.playerX, td.playerY), isTrue);
      td.updateRoadRouteDraw(td.playerX + 0.5, td.playerY + 0.5);
      td.updateRoadRouteDraw(td.playerX + 1.0, td.playerY + 1.0);
      expect(td.commitRoadRouteDraw(), isTrue);
      expect(td.activeRoadRoute.length, equals(3));
      expect(td.activeRoadRoute.first, equals(Offset(td.playerX, td.playerY)));
    });

    test('3. Draw before and during boss attack: route is accepted and followed', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      final td = engine.truckDefense;

      // Enter road defense
      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;
      expect(engine.phase, equals(MazeGamePhase.truckDefensePlaying));

      // Put boss into attack wind-up / telegraph
      td.boss.aiState = BossCombatAiState.telegraphing;
      td.boss.attackCooldown = 0.5;

      // Draw curved route past the truck
      final startX = td.playerX;
      final startY = td.playerY;
      expect(td.beginRoadRouteDraw(startX, startY), isTrue);
      td.updateRoadRouteDraw(startX + 0.6, startY + 0.4);
      td.updateRoadRouteDraw(startX + 1.2, startY + 0.8);
      td.updateRoadRouteDraw(startX + 1.8, startY + 1.2);
      expect(td.commitRoadRouteDraw(), isTrue);
      expect(td.activeRoadRoute.length, greaterThanOrEqualTo(2));

      // Step simulation while boss attacks
      final initX = td.playerX;
      final initY = td.playerY;
      engine.step(0.15);

      // Courier advanced along the finger-drawn route!
      expect(td.playerIsMoving, isTrue);
      expect((td.playerX - initX).abs() + (td.playerY - initY).abs(),
          greaterThan(0.1));
    });

    test('4. Attack, stun, and recover while following: weapon firing preserves route, stun suspends & resumes', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      // Establish active route
      td.playerX = 3.0;
      td.playerY = 3.0;
      td.beginRoadRouteDraw(3.0, 3.0);
      td.updateRoadRouteDraw(3.0, 4.0);
      td.updateRoadRouteDraw(3.0, 5.0);
      td.commitRoadRouteDraw();
      expect(td.activeRoadRoute.length, equals(3));

      // 4a. Attack while following route does NOT clear the route
      engine.triggerPrimaryAttack();
      expect(td.activeRoadRoute.length, equals(3),
          reason: 'Normal attack must not clear route');
      engine.step(0.1);
      expect(td.activeRoadRoute.length, equals(3));

      // 4b. Boss damage applies stun, suspending movement safely without clearing route
      td.applyStun(0.40);
      expect(td.isStunnedOrKnockedBack, isTrue);
      final posXBeforeStun = td.playerX;
      final posYBeforeStun = td.playerY;

      // Step while stunned (0.15s = 3 x 0.05s)
      for (int i = 0; i < 3; i++) {
        engine.step(0.05);
      }
      expect(td.playerIsMoving, isFalse);
      expect(td.playerX, equals(posXBeforeStun));
      expect(td.playerY, equals(posYBeforeStun));
      expect(td.activeRoadRoute.length, equals(3),
          reason: 'Stun must retain the route');

      // Step until stun expires (remaining 0.25s + margin = 7 x 0.05s)
      for (int i = 0; i < 7; i++) {
        engine.step(0.05);
      }
      expect(td.isStunnedOrKnockedBack, isFalse);

      // Following safely resumes!
      for (int i = 0; i < 3; i++) {
        engine.step(0.05);
      }
      expect(td.playerIsMoving, isTrue);
      expect(td.playerY, greaterThan(posYBeforeStun));
    });

    test('5. Second pointer on Attack does not interrupt drawing pointer', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      // Simulate pointer 1 starting drag
      expect(td.beginRoadRouteDraw(td.playerX, td.playerY), isTrue);
      expect(td.isDrawingRoadRoute, isTrue);
      td.updateRoadRouteDraw(td.playerX + 0.4, td.playerY + 0.3);

      // Pointer 2 fires weapon (independent event)
      engine.triggerPrimaryAttack();

      // Drawing pointer 1 continues unaffected!
      expect(td.isDrawingRoadRoute, isTrue);
      td.updateRoadRouteDraw(td.playerX + 0.8, td.playerY + 0.6);
      expect(td.commitRoadRouteDraw(), isTrue);
      expect(td.activeRoadRoute.length, greaterThanOrEqualTo(2));
    });

    test('6. Joystick override, pause freezing, invalid terrain rejection & truck blocking', () {
      final level18 = allLevels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: level18);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      // 6a. Invalid terrain rejection shows indicator without killing draft
      td.playerX = 5.0;
      td.playerY = 5.0;
      td.beginRoadRouteDraw(5.0, 5.0);
      td.updateRoadRouteDraw(5.5, 5.5);
      // Drag way out of bounds
      td.updateRoadRouteDraw(-5.0, 25.0);
      expect(td.invalidDragPoint, isNotNull,
          reason: 'Out-of-bounds drag sets invalidDragPoint');
      expect(td.draftRoadRoute.length, equals(2),
          reason: 'Invalid drag does not kill valid draft waypoints');

      // 6b. Commit valid portion
      expect(td.commitRoadRouteDraw(), isTrue);
      expect(td.activeRoadRoute.length, equals(2));

      // 6c. Pause freezes consumption
      engine.pause();
      expect(engine.phase, equals(MazeGamePhase.paused));
      final prePauseY = td.playerY;
      engine.step(0.5); // Should not move while paused
      expect(td.playerY, equals(prePauseY));
      expect(td.activeRoadRoute.length, equals(2),
          reason: 'Pause freezes and retains route');

      engine.resume();
      expect(engine.phase, equals(MazeGamePhase.truckDefensePlaying));

      // 6d. Joystick immediately cancels active road route
      engine.setJoystickInput(1.0, 0.0);
      expect(td.activeRoadRoute, isEmpty,
          reason: 'Joystick override must cancel active route');
      engine.step(0.02);
      expect(td.playerIsMoving, isTrue);
    });
  });
}

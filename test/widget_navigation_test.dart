import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/main.dart';
import 'package:parcel_escape/src/controllers/audio_controller.dart';
import 'package:parcel_escape/src/controllers/maze_game_controller.dart';
import 'package:parcel_escape/src/models/maze/delivery_state.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/rendering/maze/virtual_joystick.dart';
import 'package:parcel_escape/src/screens/gameplay_screen.dart';
import 'package:parcel_escape/src/services/ad_service.dart';
import 'package:parcel_escape/src/services/maze_level_repository.dart';
import 'package:parcel_escape/src/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MazeGameController> _createTestController() async {
  SharedPreferences.setMockInitialValues({});
  final raw = jsonDecode(
      File('assets/levels/maze_levels.json').readAsStringSync()) as Map<String, dynamic>;
  final levels = (raw['levels'] as List)
      .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
      .toList();

  final controller = MazeGameController(
    storageService: StorageService(),
    levelRepository: MazeLevelRepository(injectedLevels: levels),
    adService: DisabledAdService(),
    audioController: AudioController(enableAudio: false),
    preloadSprites: false,
  );
  await controller.initialize();
  await controller.setReducedMotion(true);
  return controller;
}

void main() {
  group('Food Maze Adventure Widget & Navigation Tests', () {
    testWidgets('Home screen renders title, diorama, Play button, and navigates to Map & Settings',
        (tester) async {
      final controller = await _createTestController();
      await tester.pumpWidget(ParcelEscapeApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PARCEL ESCAPE'), findsOneWidget);
      expect(find.text('FOOD MAZE DELIVERY ADVENTURE'), findsOneWidget);
      expect(find.text('Play Level 1'), findsOneWidget);
      expect(find.text('Level Map'), findsOneWidget);
      expect(find.text('Postcards'), findsOneWidget);

      // Navigate to Level Map
      await tester.tap(find.text('Level Map'));
      await tester.pumpAndSettle();
      expect(find.text('Delivery World Map'), findsOneWidget);
      expect(find.textContaining('SUNNY ORCHARD'), findsOneWidget);

      // Navigate back
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('PARCEL ESCAPE'), findsOneWidget);

      // Navigate to Settings and toggle Sound Effects & Background Music
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sound Effects'), findsOneWidget);
      expect(find.text('Background Music'), findsOneWidget);

      await tester.tap(find.text('Background Music'));
      await tester.pump();
      expect(controller.saveData.musicEnabled, isFalse);

      controller.dispose();
    });

    testWidgets('Gameplay screen renders Maze, Timer, Hearts, Courier Bag, and Pause Menu without overflow on 360x640',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = await _createTestController();
      await tester.pumpWidget(ParcelEscapeApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play Level 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('LV 1 • Sunny Orchard'), findsOneWidget);
      expect(find.text('COURIER BAG'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Verify automatic hint banner does NOT appear at startup
      expect(controller.engine!.hintMessage, isNull);
      expect(find.byIcon(Icons.tips_and_updates_rounded), findsNothing);

      // Pressing Hint shows compact on-demand overlay, and X dismisses it
      await tester.tap(find.text('Hint'));
      await tester.pump();
      expect(controller.engine!.hintMessage, isNotNull);
      expect(find.text(controller.engine!.hintMessage!), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(controller.engine!.hintMessage, isNull);

      // Open Pause menu -> verify simulation pauses
      await tester.tap(find.byIcon(Icons.pause_circle_filled_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Game Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger Level 1 food loading -> Cage Escape -> Truck Defense -> Arrival -> Victory dialog
      final eng = controller.engine!;
      final apple = eng.level.foods.first;
      eng.playerX = apple.col + 0.5;
      eng.playerY = apple.row + 0.5;
      eng.step(0.02);
      eng.playerX = eng.level.exitCell.centerX;
      eng.playerY = eng.level.exitCell.centerY;
      eng.step(0.02);
      expect(eng.phase, MazeGamePhase.foodLoadingComplete);

      controller.skipEscapeCutscene();
      await tester.pump(const Duration(milliseconds: 80));
      expect(eng.phase, MazeGamePhase.truckDefensePlaying);
      expect(find.textContaining('Truck HP:'), findsOneWidget);
      expect(find.textContaining('Destination Progress:'), findsOneWidget);

      // Advance truck to destination arrival & finalize victory
      eng.truckDefense.truck.traveledDistance =
          eng.truckDefense.truck.totalRoadLength - 0.01;
      eng.step(0.05);
      controller.skipEscapeCutscene();

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Delivery Complete!'), findsOneWidget);
      expect(find.text('Next Level'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Compact 320x568 phone renders Home and Gameplay without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = await _createTestController();
      await tester.pumpWidget(ParcelEscapeApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Play Level 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);
      controller.dispose();
    });

    testWidgets('V3.1 VirtualJoystick responds smoothly to touch-down, drag direction switches, and release',
        (tester) async {
      double lastDx = 0.0;
      double lastDy = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: VirtualJoystick(
                size: 128,
                hapticsEnabled: false,
                onChanged: (dx, dy) {
                  lastDx = dx;
                  lastDy = dy;
                },
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(VirtualJoystick));
      // Touch down to the right -> immediate right vector
      final gesture = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      expect(lastDx, greaterThan(0.7));
      expect(lastDy.abs(), lessThan(0.15));

      // Drag smoothly up-left without lifting finger
      await gesture.moveTo(center + const Offset(-35, -35));
      await tester.pump();
      expect(lastDx, lessThan(-0.4));
      expect(lastDy, lessThan(-0.4));

      // Release -> cleanly resets to (0, 0)
      await gesture.up();
      await tester.pump();
      expect(lastDx, 0.0);
      expect(lastDy, 0.0);
    });

    testWidgets('V3.2 Level 7 renders human courier, scary monsters, and two-thumb Combat controls without overflow on 360x640',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = await _createTestController();
      controller.selectLevel(7);

      await tester.pumpWidget(
        MaterialApp(
          home: GameplayScreen(controller: controller),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('LV 7 • Sunny Orchard'), findsOneWidget);
      expect(find.text('10'), findsOneWidget); // Starting 10 Bow arrows!
      expect(find.text('SP'), findsOneWidget); // Close-range special push strike!

      // Tap Attack button -> fires an arrow (ammo 10 -> 9) cleanly!
      await tester.tap(find.text('10'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('9'), findsOneWidget);
      expect(tester.takeException(), isNull);

      controller.dispose();
    });
  });
}

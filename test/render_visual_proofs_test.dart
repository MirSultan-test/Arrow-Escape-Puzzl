import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/engine/maze/maze_game_engine.dart';
import 'package:parcel_escape/src/models/maze/delivery_state.dart';
import 'package:parcel_escape/src/models/maze/level_roster.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/rendering/maze/maze_canvas_painter.dart';
import 'package:parcel_escape/src/rendering/maze/road_battle_painter.dart';

List<MazeLevel> _loadLevels() {
  final raw = jsonDecode(
    File('assets/levels/maze_levels.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return (raw['levels'] as List)
      .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<void> _saveCanvasImage({
  required Size size,
  required void Function(Canvas canvas, Size size) painter,
  required String outputPath,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  painter(canvas, size);
  final picture = recorder.endRecording();
  final img = await picture.toImage(size.width.toInt(), size.height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final buffer = byteData!.buffer.asUint8List();
  File(outputPath).writeAsBytesSync(buffer);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<MazeLevel> levels;
  const artifactDir =
      r'C:\Users\THT-Sultan\.gemini\antigravity\brain\3db011e4-d9a1-4397-8bf2-40be4c25fe46';

  setUpAll(() {
    levels = _loadLevels();
  });

  group('Visual Proof Captures for Integration Brief', () {
    test('1. Capture Proof 1: 50-Level Identity Roster & 3D Art Kit Showcase', () async {
      const size = Size(720, 480);
      await _saveCanvasImage(
        size: size,
        painter: (canvas, s) {
          // Dark stylish background
          canvas.drawRect(
            Offset.zero & s,
            Paint()..color = const Color(0xFF131722),
          );

          final titlePaint = TextPainter(
            text: const TextSpan(
              text: 'Food Maze Adventure — 50 Unique Level Identities (Art Kit)',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          titlePaint.paint(canvas, const Offset(24, 20));

          // Draw showcase tiles for sample levels from each district
          final sampleLevels = [1, 3, 7, 10, 18, 25, 33, 42, 50];
          final colW = (s.width - 48) / 3;
          const rowH = 110.0;

          for (int i = 0; i < sampleLevels.length; i++) {
            final lvlId = sampleLevels[i];
            final roster = LevelRosterCatalog.forLevel(lvlId);
            final col = i % 3;
            final row = i ~/ 3;
            final x = 24.0 + col * colW;
            final y = 64.0 + row * rowH;

            final cardRect = Rect.fromLTWH(x + 4, y + 4, colW - 8, rowH - 8);
            canvas.drawRRect(
              RRect.fromRectAndRadius(cardRect, const Radius.circular(10)),
              Paint()..color = const Color(0xFF1E2638),
            );
            canvas.drawRRect(
              RRect.fromRectAndRadius(cardRect, const Radius.circular(10)),
              Paint()
                ..color = const Color(0xFF334155)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );

            // Level pill
            final tp = TextPainter(
              text: TextSpan(
                text: 'LV $lvlId • ${roster.monster}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: '\nID: ${roster.primaryModelId}',
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '\nGait: ${roster.movementProfile.name}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                  TextSpan(
                    text: '\nTarget: ${roster.intendedAttack}',
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: colW - 20);
            tp.paint(canvas, Offset(x + 14, y + 12));
          }
        },
        outputPath: '$artifactDir/proof_1_50_identities_art_kit_showcase.png',
      );
    });

    test('2. Capture Proof 2: Road Battle Finger-Drawn Route Past Moving Truck', () async {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      // Draw curved route past the truck
      td.playerX = 3.5;
      td.playerY = 2.5;
      td.beginRoadRouteDraw(3.5, 2.5);
      td.updateRoadRouteDraw(4.0, 3.8);
      td.updateRoadRouteDraw(5.2, 5.0);
      td.updateRoadRouteDraw(6.5, 6.2);
      td.updateRoadRouteDraw(7.8, 7.8);
      td.commitRoadRouteDraw();

      // Step Courier into motion
      engine.step(0.05);

      const size = Size(360, 640);
      await _saveCanvasImage(
        size: size,
        painter: (canvas, s) {
          final painter = RoadBattlePainter(engine: engine, reducedMotion: true);
          painter.paint(canvas, s);
        },
        outputPath: '$artifactDir/proof_2_road_battle_finger_drawn_curved_route.png',
      );
    });

    test('3. Capture Proof 3: Road Battle Invalid Route Rejection Indicator', () async {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      // Start drag and drag into untraversable terrain
      td.playerX = 4.0;
      td.playerY = 4.0;
      td.beginRoadRouteDraw(4.0, 4.0);
      td.updateRoadRouteDraw(4.8, 4.5);
      // Touch into invalid terrain
      td.updateRoadRouteDraw(-0.5, 8.0);

      const size3 = Size(360, 640);
      await _saveCanvasImage(
        size: size3,
        painter: (canvas, s) {
          final painter = RoadBattlePainter(engine: engine, reducedMotion: true);
          painter.paint(canvas, s);
        },
        outputPath: '$artifactDir/proof_3_road_battle_invalid_route_rejection.png',
      );
    });

    test('4. Capture Proof 4: Attack & Traveling Projectiles in Road Battle', () async {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);
      final td = engine.truckDefense;

      engine.truckDefense.skipCutscene();
      engine.phase = MazeGamePhase.truckDefensePlaying;

      td.playerX = 4.0;
      td.playerY = 4.0;
      td.beginRoadRouteDraw(4.0, 4.0);
      td.updateRoadRouteDraw(5.0, 5.0);
      td.commitRoadRouteDraw();

      // Fire weapon while following route
      engine.triggerPrimaryAttack();
      engine.step(0.05);

      const size4 = Size(360, 640);
      await _saveCanvasImage(
        size: size4,
        painter: (canvas, s) {
          final painter = RoadBattlePainter(engine: engine, reducedMotion: true);
          painter.paint(canvas, s);
        },
        outputPath: '$artifactDir/proof_4_road_battle_attack_and_multi_touch.png',
      );
    });

    test('5. Capture Proof 5: Toy Diorama Gameplay Screens on 360x640 and 360x800', () async {
      final lv18 = levels.firstWhere((l) => l.id == 18);
      final engine = MazeGameEngine(level: lv18);

      // Render 360x640
      await _saveCanvasImage(
        size: const Size(360, 640),
        painter: (canvas, s) {
          final painter = MazeCanvasPainter(engine: engine, reducedMotion: true);
          painter.paint(canvas, s);
        },
        outputPath: '$artifactDir/proof_5_toy_diorama_gameplay_360x640.png',
      );

      // Render 360x800
      await _saveCanvasImage(
        size: const Size(360, 800),
        painter: (canvas, s) {
          final painter = MazeCanvasPainter(engine: engine, reducedMotion: true);
          painter.paint(canvas, s);
        },
        outputPath: '$artifactDir/proof_6_toy_diorama_gameplay_360x800.png',
      );
    });
  });
}

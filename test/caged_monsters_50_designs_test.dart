import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/models/maze/level_roster.dart';
import 'package:parcel_escape/src/models/maze/monster_variants.dart';
import 'package:parcel_escape/src/models/maze/truck_defense_models.dart';
import 'package:parcel_escape/src/rendering/maze/boss_cage_illustrator.dart';
import 'package:parcel_escape/src/services/sprite_atlas.dart';

Future<ui.Image> _loadPngImage(String path) async {
  final bytes = File(path).readAsBytesSync();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Preload monster sprites for tests
    final showcaseLevels = [1, 2, 4, 5, 7, 11, 15, 16, 20, 50];
    for (final lvl in showcaseLevels) {
      final roster = LevelRosterCatalog.forLevel(lvl);
      final file = File(roster.previewAssetPath);
      if (file.existsSync()) {
        final img = await _loadPngImage(file.path);
        SpriteAtlas.instance.registerMonsterImage(roster.primaryModelId, img);
        SpriteAtlas.instance.registerMonsterImage(roster.previewAssetPath, img);
      }
    }
  });

  group('Caged Monsters 50 Distinct Designs & Anatomy-Matched Body Language', () {
    test('All 50 levels have distinct monster identities and valid roster entries', () {
      final names = <String>{};
      final models = <String>{};

      for (int lvl = 1; lvl <= 50; lvl++) {
        final entry = LevelRosterCatalog.forLevel(lvl);
        expect(entry.level, equals(lvl));
        expect(entry.monster, isNotEmpty);
        expect(entry.anatomy, isNotEmpty);
        expect(entry.primaryModelId, isNotEmpty);

        expect(names.contains(entry.monster), isFalse,
            reason: 'Level $lvl duplicate monster name: ${entry.monster}');
        expect(models.contains(entry.primaryModelId), isFalse,
            reason: 'Level $lvl duplicate primaryModelId: ${entry.primaryModelId}');

        names.add(entry.monster);
        models.add(entry.primaryModelId);
      }

      expect(names.length, equals(50), reason: 'Must have 50 unique monster identities');
      expect(models.length, equals(50), reason: 'Must have 50 unique 3D model/preview IDs');
    });

    test('All 7 body language archetypes are represented across the 50 levels', () {
      final archetypeCounts = <CagedBodyLanguageType, int>{};
      for (final type in CagedBodyLanguageType.values) {
        archetypeCounts[type] = 0;
      }

      for (int lvl = 1; lvl <= 50; lvl++) {
        final entry = LevelRosterCatalog.forLevel(lvl);
        final archetype = CagedBodyLanguageCalculator.bodyLanguageForAnatomy(entry.anatomy);
        archetypeCounts[archetype] = archetypeCounts[archetype]! + 1;
      }

      for (final type in CagedBodyLanguageType.values) {
        expect(archetypeCounts[type], greaterThan(0),
            reason: 'Archetype $type must be represented in the 50 levels');
      }

      // Check specific canonical creatures
      // Level 1: Pipjack (hare) -> prowlingStalker
      expect(CagedBodyLanguageCalculator.bodyLanguageForAnatomy('hare'),
          equals(CagedBodyLanguageType.prowlingStalker));
      // Level 2: Acorn Tunneler (beetle) -> arthropodSkitterer
      expect(CagedBodyLanguageCalculator.bodyLanguageForAnatomy('beetle'),
          equals(CagedBodyLanguageType.arthropodSkitterer));
      // Level 5: Cherrywing (bat) -> wingedPercher
      expect(CagedBodyLanguageCalculator.bodyLanguageForAnatomy('bat'),
          equals(CagedBodyLanguageType.wingedPercher));
      // Level 7: Cider Tusk (boar) -> hornedBatteringRam
      expect(CagedBodyLanguageCalculator.bodyLanguageForAnatomy('boar'),
          equals(CagedBodyLanguageType.hornedBatteringRam));
      // Level 11: Copper Kettle (golem) -> armoredColossus
      expect(CagedBodyLanguageCalculator.bodyLanguageForAnatomy('golem'),
          equals(CagedBodyLanguageType.armoredColossus));
      // Level 15: Noodle Naga (snake) -> serpentineCoil
      expect(CagedBodyLanguageCalculator.bodyLanguageForAnatomy('snake'),
          equals(CagedBodyLanguageType.serpentineCoil));
      // Level 4: Dewdrop Snail (snail) -> shelledAmbusher
      expect(CagedBodyLanguageCalculator.bodyLanguageForAnatomy('snail'),
          equals(CagedBodyLanguageType.shelledAmbusher));
    });

    test('Kinematic poses are distinctly different between creature archetypes', () {
      const cageRect = Rect.fromLTWH(100, 100, 120, 100);

      // Winged vs Colossus vs Ram vs Stalker
      final wingedPose = CagedBodyLanguageCalculator.computeCagedPose(
        bodyLanguage: CagedBodyLanguageType.wingedPercher,
        cageRect: cageRect,
        isAgitated: false,
        animPhase: 0.0,
        elapsed: 1.0,
        levelId: 5,
      );
      final colossusPose = CagedBodyLanguageCalculator.computeCagedPose(
        bodyLanguage: CagedBodyLanguageType.armoredColossus,
        cageRect: cageRect,
        isAgitated: false,
        animPhase: 0.0,
        elapsed: 1.0,
        levelId: 11,
      );
      final ramPose = CagedBodyLanguageCalculator.computeCagedPose(
        bodyLanguage: CagedBodyLanguageType.hornedBatteringRam,
        cageRect: cageRect,
        isAgitated: false,
        animPhase: 0.0,
        elapsed: 1.0,
        levelId: 7,
      );
      final stalkerPose = CagedBodyLanguageCalculator.computeCagedPose(
        bodyLanguage: CagedBodyLanguageType.prowlingStalker,
        cageRect: cageRect,
        isAgitated: false,
        animPhase: 0.0,
        elapsed: 1.0,
        levelId: 1,
      );

      // Winged sits high in the cage (negative Y offset)
      expect(wingedPose.centerOffset.dy, lessThan(0.0),
          reason: 'Winged creatures must perch high near the ceiling');

      // Horned ram sits low in the cage (positive Y offset)
      expect(ramPose.centerOffset.dy, greaterThan(0.0),
          reason: 'Horned chargers must stay low to ground');

      // Colossus is wide and fills cage
      expect(colossusPose.scaleX, greaterThan(1.05),
          reason: 'Colossus must expand horizontally taking cage volume');

      // Stalker has non-zero pacing offset
      expect(stalkerPose.centerOffset.dx.abs(), greaterThan(0.0),
          reason: 'Stalkers must pace horizontally across cage');

      // Behaviors must be distinctly labeled
      expect(wingedPose.behaviorDescription, isNot(equals(colossusPose.behaviorDescription)));
      expect(colossusPose.behaviorDescription, isNot(equals(ramPose.behaviorDescription)));
      expect(ramPose.behaviorDescription, isNot(equals(stalkerPose.behaviorDescription)));
    });

    test('Agitated state produces explosive, anatomy-specific kinematics', () {
      const cageRect = Rect.fromLTWH(100, 100, 120, 100);

      for (final type in CagedBodyLanguageType.values) {
        final idle = CagedBodyLanguageCalculator.computeCagedPose(
          bodyLanguage: type,
          cageRect: cageRect,
          isAgitated: false,
          animPhase: 0.0,
          elapsed: 2.0,
          levelId: 1,
        );
        final agitated = CagedBodyLanguageCalculator.computeCagedPose(
          bodyLanguage: type,
          cageRect: cageRect,
          isAgitated: true,
          animPhase: 0.0,
          elapsed: 2.0,
          levelId: 1,
        );

        expect(agitated.barAgitationIntensity, greaterThan(idle.barAgitationIntensity),
            reason: '$type must exhibit higher bar agitation when rattling');
        expect(agitated.eyeGlowIntensity, greaterThanOrEqualTo(idle.eyeGlowIntensity),
            reason: '$type eye glow must flare during rattling');
        expect(agitated.barGripPoints.isNotEmpty, isTrue,
            reason: '$type must specify contact points on cage bars');
      }
    });

    test('BossCageIllustrator renders all 50 levels cleanly without exceptions', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const cageRect = Rect.fromLTWH(40, 40, 140, 110);

      for (int lvl = 1; lvl <= 50; lvl++) {
        final districtId = ((lvl - 1) ~/ 10) + 1;
        final bossType = DistrictBossType.forDistrict(districtId);
        final spec = BossAppearanceSpec.forLevel(lvl, districtId);

        // Test locked state
        expect(() {
          BossCageIllustrator.drawMonsterCage(
            canvas,
            cageRect,
            cageState: BossCageState.locked,
            bossType: bossType,
            bossAppearance: spec,
            levelId: lvl,
            shakeIntensity: 0.0,
            animPhase: 0.5,
            elapsed: 1.25,
            showBossInside: true,
          );
        }, returnsNormally, reason: 'Level $lvl locked cage render failed');

        // Test rattling / agitated state
        expect(() {
          BossCageIllustrator.drawMonsterCage(
            canvas,
            cageRect,
            cageState: BossCageState.rattling,
            bossType: bossType,
            bossAppearance: spec,
            levelId: lvl,
            shakeIntensity: 1.0,
            animPhase: 1.8,
            elapsed: 2.5,
            showBossInside: true,
          );
        }, returnsNormally, reason: 'Level $lvl rattling cage render failed');

        // Test lockBreaking state
        expect(() {
          BossCageIllustrator.drawMonsterCage(
            canvas,
            cageRect,
            cageState: BossCageState.lockBreaking,
            bossType: bossType,
            bossAppearance: spec,
            levelId: lvl,
            shakeIntensity: 1.2,
            animPhase: 2.2,
            elapsed: 3.1,
            showBossInside: true,
          );
        }, returnsNormally, reason: 'Level $lvl lock breaking render failed');

        // Test escaped state
        expect(() {
          BossCageIllustrator.drawMonsterCage(
            canvas,
            cageRect,
            cageState: BossCageState.escaped,
            bossType: bossType,
            bossAppearance: spec,
            levelId: lvl,
            shakeIntensity: 0.0,
            animPhase: 0.0,
            elapsed: 5.0,
            showBossInside: false,
          );
        }, returnsNormally, reason: 'Level $lvl escaped cage render failed');
      }

      final pic = recorder.endRecording();
      expect(pic, isNotNull);
    });

    test('Visual Proof: Render Caged Monsters across multiple levels & distinct body languages', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const canvasW = 960.0;
      const canvasH = 540.0;

      // Dark diorama background
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, canvasW, canvasH),
        Paint()..color = const Color(0xFF0F172A),
      );

      // Header title
      final titlePainter = TextPainter(
        text: const TextSpan(
          text: 'V3.5 CAGED MONSTERS: 50 UNIQUE DESIGNS & DISTINCT BODY LANGUAGE',
          style: TextStyle(
            color: Color(0xFFF8FAFC),
            fontSize: 16.0,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      titlePainter.paint(canvas, const Offset(30, 20));

      final subtitlePainter = TextPainter(
        text: const TextSpan(
          text: 'Anatomy-Matched Kinematics: Winged Perch, Horned Ram, Prowling Stalker, Serpentine Coil, Colossus Heave & Shelled Bunker',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subtitlePainter.paint(canvas, const Offset(30, 42));

      // Display 8 showcase cages across diverse levels and anatomies:
      // Level 1: Pipjack (hare / Prowling Stalker)
      // Level 2: Acorn Tunneler (beetle / Arthropod Skitterer)
      // Level 4: Dewdrop Snail (snail / Shelled Ambusher)
      // Level 5: Cherrywing (bat / Winged Percher)
      // Level 7: Cider Tusk (boar / Horned Battering Ram)
      // Level 11: Copper Kettle (golem / Armored Colossus)
      // Level 15: Noodle Naga (snake / Serpentine Coil)
      // Level 50: Crownwing Warden (griffin / Winged Royal Colossus)
      final showcaseLevels = [1, 2, 4, 5, 7, 11, 15, 50];
      const cols = 4;
      const cellW = 215.0;
      const cellH = 205.0;
      const startX = 35.0;
      const startY = 75.0;

      for (int i = 0; i < showcaseLevels.length; i++) {
        final lvl = showcaseLevels[i];
        final col = i % cols;
        final row = i ~/ cols;
        final cx = startX + col * cellW;
        final cy = startY + row * cellH;

        final districtId = ((lvl - 1) ~/ 10) + 1;
        final bossType = DistrictBossType.forDistrict(districtId);
        final spec = BossAppearanceSpec.forLevel(lvl, districtId);
        final roster = LevelRosterCatalog.forLevel(lvl);
        final bodyLang = CagedBodyLanguageCalculator.bodyLanguageForAnatomy(roster.anatomy);

        final cageRect = Rect.fromLTWH(cx + 25, cy + 20, 160, 125);

        // Sub-panel card background
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx, cy, cellW - 10, cellH - 10),
            const Radius.circular(8),
          ),
          Paint()..color = const Color(0xFF1E293B),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx, cy, cellW - 10, cellH - 10),
            const Radius.circular(8),
          ),
          Paint()
            ..color = const Color(0xFF334155)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );

        // Draw Caged Monster with anatomy body language
        final isAgitated = i % 2 == 1; // Alternate idle and agitated
        BossCageIllustrator.drawMonsterCage(
          canvas,
          cageRect,
          cageState: isAgitated ? BossCageState.rattling : BossCageState.locked,
          bossType: bossType,
          bossAppearance: spec,
          levelId: lvl,
          shakeIntensity: isAgitated ? 0.8 : 0.0,
          animPhase: i * 0.85,
          elapsed: 1.5 + i * 0.4,
          showBossInside: true,
        );

        // Caption info text below cage
        final infoPainter = TextPainter(
          text: TextSpan(
            text: 'Anatomy: ${roster.anatomy.toUpperCase()} (${bodyLang.name})\nBehavior: ${isAgitated ? "Rattling Front Bars" : "Anatomy-Specific Idle"}',
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: cellW - 20);
        infoPainter.paint(canvas, Offset(cx + 10, cy + 152));
      }

      final pic = recorder.endRecording();
      final img = await pic.toImage(canvasW.toInt(), canvasH.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      const outPath = 'C:/Users/THT-Sultan/.gemini/antigravity/brain/3db011e4-d9a1-4397-8bf2-40be4c25fe46/proof_caged_monsters_50_designs.png';
      File(outPath).writeAsBytesSync(bytes);
      expect(File(outPath).existsSync(), isTrue);
      expect(File(outPath).lengthSync(), greaterThan(10000));
    });

    test('Visual Proof: Close-Up Caged Monster Anatomy Comparison', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const canvasW = 900.0;
      const canvasH = 340.0;

      canvas.drawRect(
        const Rect.fromLTWH(0, 0, canvasW, canvasH),
        Paint()..color = const Color(0xFF0F172A),
      );

      // Comparison pairs:
      // Pair 1: L05 Cherrywing (Bat / High Perch Flap) vs L07 Cider Tusk (Boar / Horn Ram)
      // Pair 2: L11 Copper Kettle (Golem / Two-Hand Wrench) vs L16 Spice Scorpion (Scorpion / Stinger Skitter)
      final comparisonLevels = [5, 7, 11, 16];
      const cellW = 210.0;
      const startX = 25.0;
      const startY = 40.0;

      for (int i = 0; i < comparisonLevels.length; i++) {
        final lvl = comparisonLevels[i];
        final cx = startX + i * (cellW + 10);
        const cy = startY;

        final districtId = ((lvl - 1) ~/ 10) + 1;
        final bossType = DistrictBossType.forDistrict(districtId);
        final spec = BossAppearanceSpec.forLevel(lvl, districtId);

        // Preload if needed
        final roster = LevelRosterCatalog.forLevel(lvl);
        final file = File(roster.previewAssetPath);
        if (file.existsSync() && SpriteAtlas.instance.monsterSpriteForLevel(lvl) == null) {
          final img = await _loadPngImage(file.path);
          SpriteAtlas.instance.registerMonsterImage(roster.primaryModelId, img);
        }

        final cageRect = Rect.fromLTWH(cx + 15, cy + 25, 175, 145);

        // Card container
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx, cy, cellW, 250),
            const Radius.circular(10),
          ),
          Paint()..color = const Color(0xFF1E293B),
        );

        // Draw close-up cage in active agitation/rattling state
        BossCageIllustrator.drawMonsterCage(
          canvas,
          cageRect,
          cageState: BossCageState.rattling,
          bossType: bossType,
          bossAppearance: spec,
          levelId: lvl,
          shakeIntensity: 1.0,
          animPhase: 1.5,
          elapsed: 2.3 + i * 0.5,
          showBossInside: true,
        );
      }

      final pic = recorder.endRecording();
      final img = await pic.toImage(canvasW.toInt(), canvasH.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      const outPath = 'C:/Users/THT-Sultan/.gemini/antigravity/brain/3db011e4-d9a1-4397-8bf2-40be4c25fe46/proof_caged_monsters_close_up_comparison.png';
      File(outPath).writeAsBytesSync(bytes);
      expect(File(outPath).existsSync(), isTrue);
      expect(File(outPath).lengthSync(), greaterThan(10000));
    });
  });
}

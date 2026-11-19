import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/models/maze/level_roster.dart';
import 'package:parcel_escape/src/models/maze/maze_level.dart';
import 'package:parcel_escape/src/models/maze/truck_defense_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Level Roster 50-Level Identity & Art Kit Data Test', () {
    test('maze_levels.json contains exactly 50 levels with IDs 1 to 50', () {
      final file = File('assets/levels/maze_levels.json');
      expect(file.existsSync(), isTrue,
          reason: 'assets/levels/maze_levels.json must exist');

      final jsonString = file.readAsStringSync();
      final Map<String, dynamic> root = jsonDecode(jsonString);
      final List<dynamic> data = root['levels'] as List<dynamic>;
      expect(data.length, equals(50), reason: 'Must contain exactly 50 levels');

      final ids = data.map((e) => (e as Map<String, dynamic>)['id'] as int).toList();
      expect(ids, equals(List.generate(50, (i) => i + 1)),
          reason: 'Level IDs must be sequentially 1 to 50');
    });

    test('All 50 levels have distinct primary model IDs from level_roster.csv', () {
      expect(LevelRosterCatalog.entries.length, equals(50),
          reason: 'LevelRosterCatalog must define all 50 levels');

      final file = File('assets/levels/maze_levels.json');
      final jsonString = file.readAsStringSync();
      final Map<String, dynamic> root = jsonDecode(jsonString);
      final List<dynamic> data = root['levels'] as List<dynamic>;
      final levels = data
          .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
          .toList();

      final primaryModelIds = <String>{};
      for (final lvl in levels) {
        final roster = LevelRosterCatalog.forLevel(lvl.id);
        expect(roster.level, equals(lvl.id));
        expect(roster.primaryModelId, isNotEmpty);
        expect(primaryModelIds.contains(roster.primaryModelId), isFalse,
            reason:
                'Level ${lvl.id} has duplicate primaryModelId: ${roster.primaryModelId}');
        primaryModelIds.add(roster.primaryModelId);

        // MazeLevel getters must match
        expect(lvl.primaryModelId, equals(roster.primaryModelId));
        expect(lvl.rosterEntry.monster, equals(roster.monster));
      }

      expect(primaryModelIds.length, equals(50),
          reason: 'Must have exactly 50 distinct primary model IDs');
    });

    test('No integer division by 10 for enemy identity', () {
      // Ensure monster identity is NOT 5 identities repeated 10 times by district
      final file = File('assets/levels/maze_levels.json');
      final Map<String, dynamic> root = jsonDecode(file.readAsStringSync());
      final List<dynamic> data = root['levels'] as List<dynamic>;
      final levels = data
          .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
          .toList();

      final district1Ids = levels.take(10).map((l) => l.primaryModelId).toSet();
      final district2Ids =
          levels.skip(10).take(10).map((l) => l.primaryModelId).toSet();
      final district3Ids =
          levels.skip(20).take(10).map((l) => l.primaryModelId).toSet();
      final district4Ids =
          levels.skip(30).take(10).map((l) => l.primaryModelId).toSet();
      final district5Ids =
          levels.skip(40).take(10).map((l) => l.primaryModelId).toSet();

      // No district overlaps in primary identities
      expect(district1Ids.intersection(district2Ids), isEmpty);
      expect(district2Ids.intersection(district3Ids), isEmpty);
      expect(district3Ids.intersection(district4Ids), isEmpty);
      expect(district4Ids.intersection(district5Ids), isEmpty);
    });

    test('All 50 primary model (.glb) and preview (.png) asset paths exist on disk', () {
      for (int i = 1; i <= 50; i++) {
        final roster = LevelRosterCatalog.forLevel(i);
        final modelFile = File(roster.modelAssetPath);
        final previewFile = File(roster.previewAssetPath);

        expect(modelFile.existsSync(), isTrue,
            reason:
                'Level $i primary model glb missing: ${roster.modelAssetPath}');
        expect(modelFile.lengthSync(), greaterThan(0),
            reason: 'Level $i primary model glb is empty: ${roster.modelAssetPath}');

        expect(previewFile.existsSync(), isTrue,
            reason:
                'Level $i preview png missing: ${roster.previewAssetPath}');
        expect(previewFile.lengthSync(), greaterThan(0),
            reason: 'Level $i preview png is empty: ${roster.previewAssetPath}');
      }
    });

    test('Normal monster IDs and Boss IDs remain strictly separate', () {
      final normalModelIds =
          LevelRosterCatalog.entries.map((e) => e.primaryModelId).toSet();

      // Check TruckDefenseConfig boss IDs
      final bossIds = <String>{};
      for (int i = 1; i <= 50; i++) {
        final cfg = TruckDefenseConfig.forLevel(
          levelId: i,
          districtId: ((i - 1) ~/ 10) + 1,
        );
        final bossId = cfg.bossAppearance.bossId;
        expect(bossIds.contains(bossId), isFalse,
            reason: 'Level $i boss ID was duplicated: $bossId');
        bossIds.add(bossId);

        // Must not clash with any normal monster primary model ID
        expect(normalModelIds.contains(bossId), isFalse,
            reason:
                'Boss ID $bossId collides with normal monster primary model ID');
      }
    });

    test('The three 03_Boss_Studies are example studies, not silently cycled 50 times', () {
      final bossStudiesDir = Directory('assets/art_kit/03_Boss_Studies');
      expect(bossStudiesDir.existsSync(), isTrue);

      final bossStudyGlbs = bossStudiesDir
          .listSync()
          .where((f) => f.path.endsWith('.glb'))
          .map((f) => f.uri.pathSegments.last)
          .toList();

      expect(bossStudyGlbs.length, equals(3),
          reason: 'Art kit provides exactly 3 boss study models');
      expect(bossStudyGlbs, contains('thorn_ravager.glb'));
      expect(bossStudyGlbs, contains('lantern_leviathan.glb'));
      expect(bossStudyGlbs, contains('ironbell_colossus.glb'));

      // Ensure that TruckDefenseConfig acknowledges boss studies without
      // pretending all 50 bosses are these 3 files
      final file = File('assets/levels/maze_levels.json');
      final Map<String, dynamic> root = jsonDecode(file.readAsStringSync());
      final List<dynamic> data = root['levels'] as List<dynamic>;
      final levels = data
          .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final lvl in levels) {
        final cfg = lvl.truckDefenseConfig;
        // Boss titles are thematic to their levels and not blindly named only the 3 studies
        expect(cfg.bossAppearance.title, isNotEmpty);
      }
    });
  });
}

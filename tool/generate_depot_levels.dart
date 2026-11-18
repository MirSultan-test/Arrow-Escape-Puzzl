import 'dart:convert';
import 'dart:io';

import '../lib/src/engine/puzzle_engine.dart';
import '../lib/src/engine/state_space_solver.dart';
import '../lib/src/models/direction.dart';
import '../lib/src/models/level_data.dart';
import '../lib/src/models/parcel.dart';

void main() {
  print('====================================================');
  print('Building 50 Depot Challenge Campaign Levels (V2)...');
  print('====================================================');

  final levels = <LevelData>[];

  LevelData buildAndVerify({
    required int id,
    required String name,
    required int district,
    required int rows,
    required int cols,
    required List<Parcel> parcels,
    required String difficulty,
    String? tutorialText,
    required List<String> manifest,
    int rackCapacity = 2,
    List<int>? truckSizes,
  }) {
    assert(manifest.length == parcels.length,
        'Level $id: manifest count (${manifest.length}) != parcels (${parcels.length})');

    final effectiveTruckSizes = truckSizes ?? [manifest.length];
    final sumTrucks = effectiveTruckSizes.fold<int>(0, (a, b) => a + b);
    assert(sumTrucks == parcels.length,
        'Level $id: sum of truck sizes ($sumTrucks) != parcel count (${parcels.length})');

    final engine = PuzzleEngine(
      rows: rows,
      cols: cols,
      parcels: parcels,
      manifest: manifest,
      rackCapacity: rackCapacity,
      truckSizes: effectiveTruckSizes,
    );

    const solver = StateSpaceSolver(maxStates: 50000);
    final res = solver.solve(engine);

    if (!res.isSolvable) {
      throw StateError('Level $id "$name" is UNSOLVABLE by StateSpaceSolver! Explored: ${res.exploredStates}');
    }

    // Verify replay works 100%
    final replay = engine.clone();
    for (final actId in res.witnessPath) {
      if (!replay.canExit(actId)) {
        throw StateError('Level $id: Action $actId illegal during replay! Rack: ${replay.rack.map((p) => p.id)}, Manifest: ${replay.nextRequiredSymbol}');
      }
      replay.executeExit(actId);
    }
    if (!replay.isCompleted) {
      throw StateError('Level $id replay finished without completing level!');
    }

    final level = LevelData(
      id: id,
      name: name,
      campaign: 'depot',
      district: district,
      rows: rows,
      cols: cols,
      parcels: parcels,
      difficulty: difficulty,
      exampleSolution: res.witnessPath,
      tutorialText: tutorialText,
      manifest: manifest,
      rackCapacity: rackCapacity,
      truckSizes: effectiveTruckSizes,
    );

    final integrityErr = level.validateIntegrity();
    if (integrityErr != null) {
      throw StateError('Level $id integrity error: $integrityErr');
    }

    return level;
  }

  // ---------------------------------------------------------------------------
  // DISTRICT 1: The Whistle Depot (Levels 1–10)
  // ---------------------------------------------------------------------------

  // Level 1: Sorting Station (Intro to dispatch -> rack -> load)
  levels.add(buildAndVerify(
    id: 1,
    name: 'Sorting Station',
    district: 1,
    rows: 3,
    cols: 3,
    difficulty: 'easy',
    tutorialText: 'Tap a parcel to dispatch it to the Sorting Rack, then tap the rack to load the truck!',
    rackCapacity: 2,
    truckSizes: [3],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 1, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      Parcel(id: 'p3', row: 2, col: 2, direction: Direction.right, manifestSymbol: 'star'),
    ],
    manifest: const ['star', 'star', 'star'],
  ));

  // Level 2: Buffer Basics (2 symbols, 2-slot buffering)
  levels.add(buildAndVerify(
    id: 2,
    name: 'Buffer Basics',
    district: 1,
    rows: 3,
    cols: 3,
    difficulty: 'easy',
    tutorialText: 'The Sorting Rack holds 2 parcels. Match the truck\'s order to load!',
    rackCapacity: 2,
    truckSizes: [2, 2],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'sun'),
      Parcel(id: 'p3', row: 2, col: 0, direction: Direction.down, manifestSymbol: 'star'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.down, manifestSymbol: 'sun'),
    ],
    manifest: const ['star', 'sun', 'star', 'sun'],
  ));

  // Level 3: Traffic Priority (Choice matters)
  levels.add(buildAndVerify(
    id: 3,
    name: 'Traffic Priority',
    district: 1,
    rows: 3,
    cols: 3,
    difficulty: 'easy',
    tutorialText: 'Plan ahead! If the rack fills with the wrong parcels, deliveries will jam.',
    rackCapacity: 2,
    truckSizes: [2, 2],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 0, col: 2, direction: Direction.right, manifestSymbol: 'sun'),
      Parcel(id: 'p3', row: 2, col: 0, direction: Direction.left, manifestSymbol: 'moon'),
      Parcel(id: 'p4', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'star'),
    ],
    manifest: const ['star', 'sun', 'star', 'moon'],
  ));

  // Level 4: Depot Jam (Section 5 Rack-Jam Fixture)
  levels.add(buildAndVerify(
    id: 4,
    name: 'Depot Jam',
    district: 1,
    rows: 4,
    cols: 4,
    difficulty: 'medium',
    tutorialText: 'Clear blockers on the board before filling the rack to avoid deadlocks.',
    rackCapacity: 2,
    truckSizes: [2, 2],
    parcels: const [
      Parcel(id: 'A', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'B', row: 1, col: 1, direction: Direction.up, manifestSymbol: 'moon'),
      Parcel(id: 'C', row: 1, col: 2, direction: Direction.left, manifestSymbol: 'star'),
      Parcel(id: 'D', row: 2, col: 0, direction: Direction.down, manifestSymbol: 'sun'),
    ],
    manifest: const ['star', 'moon', 'star', 'sun'],
  ));

  // Level 5: Wind-Up Gears (Gear shift intro in Depot Challenge)
  levels.add(buildAndVerify(
    id: 5,
    name: 'Wind-Up Gears',
    district: 1,
    rows: 4,
    cols: 4,
    difficulty: 'medium',
    tutorialText: 'Dispatching from the board rotates surviving gear parcels 90° clockwise!',
    rackCapacity: 2,
    truckSizes: [2, 2],
    parcels: const [
      Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 1, col: 2, direction: Direction.left, manifestSymbol: 'moon'),
      Parcel(id: 'p3', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p4', row: 2, col: 0, direction: Direction.down, manifestSymbol: 'sun'),
    ],
    manifest: const ['star', 'moon', 'star', 'sun'],
  ));

  // Level 6: Clockwork Buffer (Gears + buffer interaction)
  levels.add(buildAndVerify(
    id: 6,
    name: 'Clockwork Buffer',
    district: 1,
    rows: 4,
    cols: 4,
    difficulty: 'medium',
    rackCapacity: 2,
    truckSizes: [2, 3],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'sun'),
      Parcel(id: 'p3', row: 1, col: 2, direction: Direction.right, manifestSymbol: 'moon'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      Parcel(id: 'p5', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'sun'),
    ],
    manifest: const ['star', 'moon', 'sun', 'star', 'sun'],
  ));

  // Level 7: Shift & Sort (Rack buffer + gear shift combination)
  levels.add(buildAndVerify(
    id: 7,
    name: 'Shift & Sort',
    district: 1,
    rows: 4,
    cols: 4,
    difficulty: 'medium',
    rackCapacity: 2,
    truckSizes: [3, 2],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 0, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      Parcel(id: 'p3', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'sun'),
      Parcel(id: 'p5', row: 3, col: 0, direction: Direction.down, manifestSymbol: 'star'),
    ],
    manifest: const ['star', 'moon', 'star', 'sun', 'star'],
  ));

  // Level 8: Fleet Departure (Multi-truck dispatch: 3 + 3)
  levels.add(buildAndVerify(
    id: 8,
    name: 'Fleet Departure',
    district: 1,
    rows: 4,
    cols: 4,
    difficulty: 'medium',
    rackCapacity: 2,
    truckSizes: [3, 3],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'sun'),
      Parcel(id: 'p3', row: 1, col: 1, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      Parcel(id: 'p5', row: 3, col: 0, direction: Direction.down, manifestSymbol: 'sun'),
      Parcel(id: 'p6', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
    ],
    manifest: const ['star', 'sun', 'moon', 'star', 'sun', 'moon'],
  ));

  // Level 9: Clog Prevention (Tight rack constraint + gear cascades)
  levels.add(buildAndVerify(
    id: 9,
    name: 'Clog Prevention',
    district: 1,
    rows: 4,
    cols: 4,
    difficulty: 'hard',
    rackCapacity: 2,
    truckSizes: [3, 3],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'moon'),
      Parcel(id: 'p3', row: 1, col: 2, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      Parcel(id: 'p5', row: 3, col: 1, direction: Direction.down, hasGear: true, manifestSymbol: 'moon'),
      Parcel(id: 'p6', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'sun'),
    ],
    manifest: const ['moon', 'star', 'sun', 'star', 'moon', 'sun'],
  ));

  // Level 10: Depot Grand Master (District 1 Mini-Boss)
  levels.add(buildAndVerify(
    id: 10,
    name: 'Depot Grand Master',
    district: 1,
    rows: 4,
    cols: 4,
    difficulty: 'hard',
    rackCapacity: 2,
    truckSizes: [4, 3],
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      Parcel(id: 'p2', row: 0, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
      Parcel(id: 'p3', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'moon'),
      Parcel(id: 'p4', row: 1, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      Parcel(id: 'p5', row: 2, col: 1, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      Parcel(id: 'p6', row: 3, col: 0, direction: Direction.down, manifestSymbol: 'moon'),
      Parcel(id: 'p7', row: 3, col: 3, direction: Direction.right, manifestSymbol: 'star'),
    ],
    manifest: const ['star', 'sun', 'moon', 'star', 'sun', 'moon', 'star'],
  ));

  print('District 1 generated & verified successfully (10/10).');

  // Generator helper for Districts 2 to 5 to generate rich, deterministic, solver-verified levels
  void generateDistrictLevels({
    required int startId,
    required int endId,
    required int district,
    required String districtName,
    required int minParcels,
    required int maxParcels,
    required List<String> availableSymbols,
    int rackCapacity = 2,
  }) {
    final names = [
      'Switchyard Sync', 'Conveyor Twist', 'Rotary Yard', 'Cargo Junction',
      'Valve Gate', 'Pressure Buffer', 'Piston Alley', 'Whistle Line',
      'Freight Turn', 'Terminal Express', 'Canal Way', 'Harbor Hoist',
      'Steam Crane', 'Barge Lock', 'Dockside Relay', 'Pivot Platform',
      'Gearbox Grid', 'Chime Tower', 'Flywheel Forge', 'Master Dispatch'
    ];

    for (int id = startId; id <= endId; id++) {
      final nameIndex = (id - startId) % names.length;
      final levelName = '$districtName ${names[nameIndex]}';
      final parcelCount = minParcels + ((id - startId) % (maxParcels - minParcels + 1));
      final rows = parcelCount >= 8 ? 5 : 4;
      final cols = parcelCount >= 8 ? 5 : 4;

      // Deterministic generation per level ID
      bool solved = false;
      int seed = id * 7919;

      while (!solved) {
        seed++;
        final rnd = _SimpleRng(seed);
        final placed = <Parcel>[];
        final occupied = <String>{};

        for (int p = 0; p < parcelCount; p++) {
          int attempts = 0;
          while (attempts++ < 100) {
            final r = rnd.nextInt(rows);
            final c = rnd.nextInt(cols);
            final key = '$r,$c';
            if (!occupied.contains(key)) {
              occupied.add(key);
              final dir = Direction.values[rnd.nextInt(4)];
              final sym = availableSymbols[rnd.nextInt(availableSymbols.length)];
              final hasGear = rnd.nextDouble() < 0.38;
              placed.add(Parcel(
                id: 'p${p + 1}',
                row: r,
                col: c,
                direction: dir,
                hasGear: hasGear,
                manifestSymbol: sym,
              ));
              break;
            }
          }
        }

        if (placed.length != parcelCount) continue;

        // Create test engine with no manifest to find a valid removal order
        final unmanifested = PuzzleEngine(
          rows: rows,
          cols: cols,
          parcels: placed,
          rackCapacity: rackCapacity,
        );

        const testSolver = StateSpaceSolver(maxStates: 8000);
        final baseResult = testSolver.solve(unmanifested);

        if (baseResult.isSolvable && baseResult.dispatchSequence.length == parcelCount) {
          // Generate manifest from the winning dispatch sequence
          final manifest = <String>[];
          for (final pid in baseResult.dispatchSequence) {
            final p = placed.firstWhere((item) => item.id == pid);
            manifest.add(p.manifestSymbol ?? 'star');
          }

          // Partition into trucks (e.g. trucks of size 2, 3, or 4)
          final truckSizes = <int>[];
          int remaining = parcelCount;
          while (remaining > 0) {
            if (remaining <= 3) {
              truckSizes.add(remaining);
              remaining = 0;
            } else if (remaining == 4) {
              truckSizes.addAll([2, 2]);
              remaining = 0;
            } else {
              truckSizes.add(3);
              remaining -= 3;
            }
          }

          try {
            final verifiedLevel = buildAndVerify(
              id: id,
              name: levelName,
              district: district,
              rows: rows,
              cols: cols,
              parcels: placed,
              difficulty: parcelCount >= 8 ? 'hard' : 'medium',
              manifest: manifest,
              rackCapacity: rackCapacity,
              truckSizes: truckSizes,
            );
            levels.add(verifiedLevel);
            solved = true;
          } catch (_) {
            // If manifest order causes buffer deadlocks, retry with next seed
          }
        }
      }
    }
    print('$districtName generated & verified successfully ($startId–$endId).');
  }

  // District 2: The Clockwork Junction (Levels 11–20)
  generateDistrictLevels(
    startId: 11,
    endId: 20,
    district: 2,
    districtName: 'Junction',
    minParcels: 5,
    maxParcels: 7,
    availableSymbols: const ['star', 'sun', 'moon'],
    rackCapacity: 2,
  );

  // District 3: The Steam Conveyor (Levels 21–30)
  generateDistrictLevels(
    startId: 21,
    endId: 30,
    district: 3,
    districtName: 'Conveyor',
    minParcels: 6,
    maxParcels: 8,
    availableSymbols: const ['star', 'sun', 'moon', 'clover'],
    rackCapacity: 2,
  );

  // District 4: The Canal Basin (Levels 31–40)
  generateDistrictLevels(
    startId: 31,
    endId: 40,
    district: 4,
    districtName: 'Canal',
    minParcels: 7,
    maxParcels: 9,
    availableSymbols: const ['star', 'sun', 'moon', 'clover', 'heart'],
    rackCapacity: 2,
  );

  // District 5: The Grand Terminal (Levels 41–50)
  generateDistrictLevels(
    startId: 41,
    endId: 50,
    district: 5,
    districtName: 'Terminal',
    minParcels: 7,
    maxParcels: 10,
    availableSymbols: const ['star', 'sun', 'moon', 'clover', 'heart', 'diamond'],
    rackCapacity: 2,
  );

  assert(levels.length == 50, 'Must have exactly 50 levels, found ${levels.length}');

  // Save to assets/levels/windup_levels.json
  final jsonString = const JsonEncoder.withIndent('  ').convert(
    levels.map((l) => l.toJson()).toList(),
  );

  final outFile = File('assets/levels/windup_levels.json');
  outFile.writeAsStringSync(jsonString);

  print('====================================================');
  print('Successfully generated and verified all 50 Depot Challenge levels!');
  print('Saved to: ${outFile.path} (${outFile.lengthSync()} bytes)');
  print('====================================================');
}

/// Simple lightweight LCG random number generator for reproducible seed-based generation.
class _SimpleRng {
  int _state;
  _SimpleRng(int seed) : _state = seed & 0x7FFFFFFF;

  int nextInt(int max) {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state % max;
  }

  double nextDouble() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}

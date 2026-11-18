import 'dart:convert';
import 'dart:io';

import '../lib/src/engine/puzzle_engine.dart';
import '../lib/src/engine/state_space_solver.dart';
import '../lib/src/models/direction.dart';
import '../lib/src/models/level_data.dart';
import '../lib/src/models/parcel.dart';

void main() {
  print('Generating 50 Wind-Up Depot campaign levels...');

  final levels = <LevelData>[];

  // Helper to build and verify a level
  LevelData buildLevel({
    required int id,
    required String name,
    required int district,
    required int rows,
    required int cols,
    required List<Parcel> parcels,
    required String difficulty,
    String? tutorialText,
    List<String>? manifest,
    int rackCapacity = 2,
    List<int>? truckSizes,
  }) {
    // Ensure parcels have manifest symbols
    final effectiveParcels = parcels.map((p) =>
      p.manifestSymbol == null ? p.copyWith(manifestSymbol: 'star') : p
    ).toList();

    final effectiveManifest = manifest ??
      effectiveParcels.map((p) => p.manifestSymbol!).toList();

    assert(
      effectiveManifest.length == effectiveParcels.length,
      'Level $id: manifest length (${effectiveManifest.length}) != parcels count (${effectiveParcels.length})',
    );

    // Compute automatic truck partition if not specified
    List<int> effectiveTrucks = truckSizes ?? [];
    if (effectiveTrucks.isEmpty) {
      final count = effectiveParcels.length;
      if (count <= 3) {
        effectiveTrucks = [count];
      } else if (count == 4) {
        effectiveTrucks = [2, 2];
      } else if (count == 5) {
        effectiveTrucks = [3, 2];
      } else if (count == 6) {
        effectiveTrucks = [3, 3];
      } else if (count == 7) {
        effectiveTrucks = [4, 3];
      } else if (count == 8) {
        effectiveTrucks = [4, 4];
      } else if (count == 9) {
        effectiveTrucks = [3, 3, 3];
      } else if (count == 10) {
        effectiveTrucks = [4, 3, 3];
      } else {
        effectiveTrucks = [count];
      }
    }

    final testEngine = PuzzleEngine(
      rows: rows,
      cols: cols,
      parcels: effectiveParcels,
      manifest: effectiveManifest,
      rackCapacity: rackCapacity,
      truckSizes: effectiveTrucks,
    );

    const solver = StateSpaceSolver(maxStates: 50000);
    var result = solver.solve(testEngine);

    // If rackCapacity 2 is too tight on advanced levels, try rackCapacity 3
    int finalRackCapacity = rackCapacity;
    if (!result.isSolvable && rackCapacity < 3) {
      final fallbackEngine = PuzzleEngine(
        rows: rows,
        cols: cols,
        parcels: effectiveParcels,
        manifest: effectiveManifest,
        rackCapacity: 3,
        truckSizes: effectiveTrucks,
      );
      final fallbackRes = solver.solve(fallbackEngine);
      if (fallbackRes.isSolvable) {
        result = fallbackRes;
        finalRackCapacity = 3;
      }
    }

    if (!result.isSolvable) {
      throw StateError(
        'Level $id "$name" is UNSOLVABLE! Result: $result',
      );
    }

    final level = LevelData(
      id: id,
      name: name,
      campaign: 'depot',
      district: district,
      rows: rows,
      cols: cols,
      parcels: effectiveParcels,
      difficulty: difficulty,
      exampleSolution: result.witnessPath,
      tutorialText: tutorialText,
      manifest: effectiveManifest,
      rackCapacity: finalRackCapacity,
      truckSizes: effectiveTrucks,
    );

    final err = level.validateIntegrity();
    if (err != null) {
      throw StateError('Level $id integrity error: $err');
    }

    return level;
  }

  // =========================================================================
  // DISTRICT 1: The Whistle Depot (Levels 1–10)
  // Focus: Introduction to Depot Challenge 3-stage loop & Gear Shift
  // =========================================================================

  // Level 1: Sorting Station (Intro to dispatch -> rack -> load)
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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
  levels.add(buildLevel(
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

  // =========================================================================
  // DISTRICT 2: Clockwork Sorting (Levels 11–20)
  // Focus: Delivery Manifest introduction & light gear combinations
  // =========================================================================

  // Level 11: Mandatory Manifest Fixture!
  // A(0,0,UP,star), B(1,1,UP,star), C(1,2,LEFT,moon); Manifest: [star, moon, star]
  levels.add(buildLevel(
    id: 11,
    name: 'Manifest Call',
    district: 2,
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    tutorialText: 'Delivery Manifest: dispatch parcels matching the required symbol at the top ribbon.',
    manifest: ['star', 'moon', 'star'],
    parcels: [
      const Parcel(id: 'pA', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'pB', row: 1, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'pC', row: 1, col: 2, direction: Direction.left, manifestSymbol: 'moon'),
    ],
  ));

  // Level 12: Color Coded
  levels.add(buildLevel(
    id: 12,
    name: 'Color Coded',
    district: 2,
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    manifest: ['moon', 'star', 'moon', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 0, direction: Direction.left, manifestSymbol: 'star'),
    ],
  ));

  // Level 13: Sun & Star
  levels.add(buildLevel(
    id: 13,
    name: 'Sun & Star',
    district: 2,
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    manifest: ['sun', 'star', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'star'),
    ],
  ));

  // Level 14: Triple Stamp (Star, Moon, Sun)
  levels.add(buildLevel(
    id: 14,
    name: 'Triple Stamp',
    district: 2,
    rows: 4,
    cols: 4,
    difficulty: 'medium',
    manifest: ['star', 'sun', 'moon', 'star', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 1, col: 2, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 3, direction: Direction.down, manifestSymbol: 'sun'),
    ],
  ));

  // Level 15: Conveyor Line (Milestone: Unlocks Bridge!)
  levels.add(buildLevel(
    id: 15,
    name: 'Conveyor Line',
    district: 2,
    rows: 5,
    cols: 5,
    difficulty: 'medium',
    manifest: ['moon', 'star', 'moon', 'star', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 3, col: 1, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 4, col: 3, direction: Direction.down, manifestSymbol: 'sun'),
    ],
  ));

  // Level 16: Manifest & Gear (First combo)
  levels.add(buildLevel(
    id: 16,
    name: 'Manifest & Gear',
    district: 2,
    rows: 4,
    cols: 4,
    difficulty: 'medium',
    tutorialText: 'Gears rotate on every delivery, even while following the manifest!',
    manifest: ['star', 'moon', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
    ],
  ));

  // Level 17: The Sorter
  levels.add(buildLevel(
    id: 17,
    name: 'The Sorter',
    district: 2,
    rows: 5,
    cols: 5,
    difficulty: 'medium',
    manifest: ['sun', 'star', 'moon', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 0, direction: Direction.left, manifestSymbol: 'moon'),
    ],
  ));

  // Level 18: Cargo Bay
  levels.add(buildLevel(
    id: 18,
    name: 'Cargo Bay',
    district: 2,
    rows: 5,
    cols: 5,
    difficulty: 'medium',
    manifest: ['star', 'moon', 'star', 'sun', 'moon', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 3, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 3, col: 1, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 3, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 0, col: 4, direction: Direction.right, manifestSymbol: 'star'),
    ],
  ));

  // Level 19: Alternating Shift
  levels.add(buildLevel(
    id: 19,
    name: 'Alternating Shift',
    district: 2,
    rows: 5,
    cols: 5,
    difficulty: 'hard',
    manifest: ['star', 'sun', 'star', 'sun', 'moon', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 3, col: 1, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 3, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 4, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
    ],
  ));

  // Level 20: Grand Sorter (Milestone: Unlocks Postcard 2!)
  levels.add(buildLevel(
    id: 20,
    name: 'Grand Sorter',
    district: 2,
    rows: 5,
    cols: 5,
    difficulty: 'hard',
    manifest: ['moon', 'star', 'sun', 'star', 'moon', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 0, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 3, col: 0, direction: Direction.left, manifestSymbol: 'star'),
    ],
  ));

  // =========================================================================
  // DISTRICT 3: Steam Junction (Levels 21–35)
  // Focus: Deeper combinations of Gear Shifts and Manifest sequences
  // =========================================================================

  levels.add(buildLevel(
    id: 21,
    name: 'Junction Gate',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'medium',
    manifest: ['star', 'moon', 'star', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
    ],
  ));

  levels.add(buildLevel(
    id: 22,
    name: 'Steampipe Loop',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'medium',
    manifest: ['sun', 'star', 'sun', 'moon', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 1, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p5', row: 3, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 3, direction: Direction.down, manifestSymbol: 'moon'),
    ],
  ));

  levels.add(buildLevel(
    id: 23,
    name: 'Valve Control',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'medium',
    manifest: ['star', 'moon', 'sun', 'star', 'moon', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 2, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.down, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 24,
    name: 'Gearmesh Lane',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'hard',
    manifest: ['moon', 'star', 'moon', 'star', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.right, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 1, col: 3, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 2, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 1, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p6', row: 3, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'star'),
    ],
  ));

  // Level 25: (Milestone: Unlocks Greenhouse!)
  levels.add(buildLevel(
    id: 25,
    name: 'Greenhouse Rail',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'hard',
    manifest: ['star', 'sun', 'moon', 'star', 'sun', 'moon', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 3, direction: Direction.up, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 3, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p6', row: 0, col: 4, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 4, col: 0, direction: Direction.down, manifestSymbol: 'star'),
    ],
  ));

  levels.add(buildLevel(
    id: 26,
    name: 'Boiler Room',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'hard',
    manifest: ['sun', 'star', 'moon', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 1, direction: Direction.down, manifestSymbol: 'moon'),
    ],
  ));

  levels.add(buildLevel(
    id: 27,
    name: 'Crankshaft Crossing',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'hard',
    manifest: ['star', 'moon', 'star', 'sun', 'star', 'moon', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 3, col: 0, direction: Direction.left, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 28,
    name: 'Dual Escapement',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'hard',
    manifest: ['moon', 'star', 'sun', 'moon', 'star', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 3, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 3, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p5', row: 3, col: 3, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 4, col: 2, direction: Direction.down, manifestSymbol: 'star'),
    ],
  ));

  levels.add(buildLevel(
    id: 29,
    name: 'Piston Relay',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['star', 'sun', 'moon', 'star', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 1, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 1, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p6', row: 3, col: 3, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 4, col: 0, direction: Direction.left, manifestSymbol: 'moon'),
    ],
  ));

  // Level 30: Steam Hub (Milestone: Unlocks Postcard 3!)
  levels.add(buildLevel(
    id: 30,
    name: 'Steam Hub',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['star', 'moon', 'sun', 'star', 'moon', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 1, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 1, col: 4, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 3, col: 0, direction: Direction.left, manifestSymbol: 'moon'),
    ],
  ));

  levels.add(buildLevel(
    id: 31,
    name: 'Interlocking Wheels',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['moon', 'star', 'sun', 'star', 'moon', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 0, col: 3, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 4, col: 1, direction: Direction.down, manifestSymbol: 'star'),
    ],
  ));

  levels.add(buildLevel(
    id: 32,
    name: 'High Pressure Line',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['star', 'sun', 'star', 'moon', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p6', row: 1, col: 3, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 4, col: 4, direction: Direction.down, manifestSymbol: 'moon'),
    ],
  ));

  levels.add(buildLevel(
    id: 33,
    name: 'Governor Gear',
    district: 3,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['sun', 'moon', 'star', 'sun', 'moon', 'star', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 4, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 34,
    name: 'Flywheel Chamber',
    district: 3,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['star', 'moon', 'star', 'sun', 'moon', 'star', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 4, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 3, col: 3, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 4, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 0, col: 3, direction: Direction.up, manifestSymbol: 'sun'),
    ],
  ));

  // Level 35: (Milestone: Unlocks Water Tower!)
  levels.add(buildLevel(
    id: 35,
    name: 'Water Tower Switch',
    district: 3,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['moon', 'star', 'sun', 'moon', 'star', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p5', row: 4, col: 3, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 5, col: 4, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 3, col: 4, direction: Direction.right, manifestSymbol: 'moon'),
    ],
  ));

  // =========================================================================
  // DISTRICT 4: Grand Dispatch (Levels 36–45)
  // Focus: Compact expert layouts, consequential choices & tight dependency paths
  // =========================================================================

  levels.add(buildLevel(
    id: 36,
    name: 'The Central Turntable',
    district: 4,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['star', 'moon', 'star', 'sun', 'star', 'moon', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 2, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 2, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 0, col: 4, direction: Direction.right, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 37,
    name: 'Synchronized Gears',
    district: 4,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['sun', 'star', 'moon', 'sun', 'star', 'moon', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 3, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 3, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 4, col: 2, direction: Direction.down, manifestSymbol: 'star'),
    ],
  ));

  levels.add(buildLevel(
    id: 38,
    name: 'Hourglass Track',
    district: 4,
    rows: 5,
    cols: 5,
    difficulty: 'expert',
    manifest: ['star', 'moon', 'sun', 'star', 'moon', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 0, col: 3, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 1, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 4, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 4, col: 3, direction: Direction.down, manifestSymbol: 'moon'),
    ],
  ));

  levels.add(buildLevel(
    id: 39,
    name: 'Courier Quad',
    district: 4,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['moon', 'star', 'sun', 'star', 'moon', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 4, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 3, col: 3, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 4, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 5, col: 3, direction: Direction.down, manifestSymbol: 'moon'),
    ],
  ));

  // Level 40: (Milestone: Unlocks Postcard 4!)
  levels.add(buildLevel(
    id: 40,
    name: 'The Grand Rotunda',
    district: 4,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['star', 'sun', 'moon', 'star', 'sun', 'moon', 'star', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 2, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 2, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 2, col: 4, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 4, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p6', row: 4, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 0, col: 3, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 5, col: 2, direction: Direction.down, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 41,
    name: 'Spiral Dispatch',
    district: 4,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['sun', 'moon', 'star', 'sun', 'moon', 'star', 'sun', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 3, col: 4, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 4, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 5, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 5, col: 0, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p8', row: 2, col: 5, direction: Direction.up, manifestSymbol: 'moon'),
    ],
  ));

  levels.add(buildLevel(
    id: 42,
    name: 'Pendulum Alley',
    district: 4,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['star', 'moon', 'star', 'sun', 'moon', 'star', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 4, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p4', row: 3, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 5, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 0, col: 0, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p8', row: 5, col: 4, direction: Direction.down, manifestSymbol: 'star'),
    ],
  ));

  levels.add(buildLevel(
    id: 43,
    name: 'Quartermaster Lock',
    district: 4,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['moon', 'star', 'sun', 'star', 'moon', 'sun', 'star', 'moon', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 3, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 4, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.down, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 1, col: 5, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 5, col: 0, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p9', row: 5, col: 5, direction: Direction.right, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 44,
    name: 'Escapement Bridge',
    district: 4,
    rows: 6,
    cols: 6,
    difficulty: 'expert',
    manifest: ['star', 'sun', 'moon', 'star', 'sun', 'star', 'moon', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 3, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 4, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p6', row: 4, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p7', row: 0, col: 5, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p8', row: 5, col: 1, direction: Direction.down, manifestSymbol: 'sun'),
    ],
  ));

  // Level 45: (Milestone: Unlocks Clock Tower!)
  levels.add(buildLevel(
    id: 45,
    name: 'Clock Tower Ascent',
    district: 4,
    rows: 6,
    cols: 6,
    difficulty: 'master',
    manifest: ['moon', 'star', 'moon', 'sun', 'star', 'moon', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 4, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 1, col: 5, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p8', row: 5, col: 0, direction: Direction.left, manifestSymbol: 'star'),
    ],
  ));

  // =========================================================================
  // DISTRICT 5: Master Works (Levels 46–50)
  // Focus: Climax mastery puzzles with deep branching and intricate clockwork
  // =========================================================================

  levels.add(buildLevel(
    id: 46,
    name: 'The Grand Orrery',
    district: 5,
    rows: 6,
    cols: 6,
    difficulty: 'master',
    manifest: ['star', 'moon', 'sun', 'star', 'moon', 'sun', 'star', 'moon'],
    parcels: [
      const Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 4, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 2, col: 2, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 4, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 4, col: 4, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'moon'),
    ],
  ));

  levels.add(buildLevel(
    id: 47,
    name: 'Perpetual Route',
    district: 5,
    rows: 6,
    cols: 6,
    difficulty: 'master',
    manifest: ['sun', 'star', 'moon', 'sun', 'star', 'moon', 'star', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 3, direction: Direction.up, manifestSymbol: 'sun'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 2, col: 1, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 4, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 5, col: 1, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 3, col: 0, direction: Direction.left, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 48,
    name: 'Centennial Express',
    district: 5,
    rows: 6,
    cols: 6,
    difficulty: 'master',
    manifest: ['star', 'sun', 'moon', 'star', 'moon', 'sun', 'star', 'moon', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 0, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 1, col: 2, direction: Direction.up, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p3', row: 1, col: 4, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p4', row: 2, col: 1, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 3, direction: Direction.down, hasGear: true, manifestSymbol: 'moon'),
      const Parcel(id: 'p6', row: 3, col: 5, direction: Direction.right, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 4, col: 2, direction: Direction.down, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 5, col: 1, direction: Direction.left, manifestSymbol: 'moon'),
      const Parcel(id: 'p9', row: 5, col: 4, direction: Direction.down, manifestSymbol: 'sun'),
    ],
  ));

  levels.add(buildLevel(
    id: 49,
    name: 'Chronos Gate',
    district: 5,
    rows: 6,
    cols: 6,
    difficulty: 'master',
    manifest: ['moon', 'star', 'sun', 'moon', 'star', 'sun', 'star', 'moon', 'sun'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 2, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p2', row: 1, col: 1, direction: Direction.left, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p3', row: 1, col: 4, direction: Direction.right, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p5', row: 3, col: 2, direction: Direction.left, manifestSymbol: 'star'),
      const Parcel(id: 'p6', row: 4, col: 1, direction: Direction.down, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p7', row: 4, col: 4, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 5, col: 3, direction: Direction.down, manifestSymbol: 'moon'),
      const Parcel(id: 'p9', row: 2, col: 5, direction: Direction.right, manifestSymbol: 'sun'),
    ],
  ));

  // Level 50: Climax Master Level (Milestone: Unlocks Grand Central Station & Final Postcard!)
  levels.add(buildLevel(
    id: 50,
    name: 'Master of the Depot',
    district: 5,
    rows: 6,
    cols: 6,
    difficulty: 'master',
    manifest: ['star', 'moon', 'sun', 'star', 'sun', 'moon', 'star', 'moon', 'sun', 'star'],
    parcels: [
      const Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, manifestSymbol: 'star'),
      const Parcel(id: 'p2', row: 0, col: 4, direction: Direction.up, manifestSymbol: 'moon'),
      const Parcel(id: 'p3', row: 1, col: 2, direction: Direction.left, hasGear: true, manifestSymbol: 'sun'),
      const Parcel(id: 'p4', row: 2, col: 3, direction: Direction.right, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p5', row: 3, col: 1, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p6', row: 3, col: 4, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p7', row: 4, col: 2, direction: Direction.down, hasGear: true, manifestSymbol: 'star'),
      const Parcel(id: 'p8', row: 4, col: 5, direction: Direction.right, manifestSymbol: 'moon'),
      const Parcel(id: 'p9', row: 5, col: 0, direction: Direction.left, manifestSymbol: 'sun'),
      const Parcel(id: 'p10', row: 5, col: 3, direction: Direction.down, manifestSymbol: 'star'),
    ],
  ));

  assert(levels.length == 50, 'Must have exactly 50 levels');
  print('Successfully built and verified all 50 levels with StateSpaceSolver.');

  final jsonString = const JsonEncoder.withIndent('  ').convert(
    levels.map((l) => l.toJson()).toList(),
  );

  final targetFile = File('assets/levels/windup_levels.json');
  targetFile.writeAsStringSync(jsonString);

  print('Wrote 50 Wind-Up Depot levels to ${targetFile.path} (${jsonString.length} bytes)');
}

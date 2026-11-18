import 'dart:convert';
import 'dart:io';
import '../lib/src/engine/level_generator.dart';
import '../lib/src/engine/puzzle_solver.dart';
import '../lib/src/models/direction.dart';
import '../lib/src/models/level_data.dart';
import '../lib/src/models/parcel.dart';

void main() {
  final levels = <LevelData>[];
  final signatures = <String>{};

  // --- LEVELS 1-3: Hand-authored Guided Tutorials ---

  // Level 1: Very simple single parcel
  final l1 = LevelData(
    id: 1,
    name: 'Tutorial: Clear Path',
    rows: 3,
    cols: 3,
    difficulty: 'tutorial',
    tutorialText: 'Tap a parcel with a clear path.',
    parcels: const [
      Parcel(
        id: 'p1',
        row: 1,
        col: 1,
        direction: Direction.up,
        colorType: 'standard',
      ),
    ],
    exampleSolution: const ['p1'],
  );
  levels.add(l1);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l1.rows, l1.cols, l1.parcels));

  // Level 2: Two parcels demonstrating a single blocker
  final l2 = LevelData(
    id: 2,
    name: 'Tutorial: Clearing Blockers',
    rows: 3,
    cols: 3,
    difficulty: 'tutorial',
    tutorialText: 'Parcel is blocked! Tap the outer parcel first to clear the exit path.',
    parcels: const [
      Parcel(
        id: 'p1',
        row: 1,
        col: 1,
        direction: Direction.right,
        colorType: 'standard',
      ),
      Parcel(
        id: 'p2',
        row: 1,
        col: 2,
        direction: Direction.down,
        colorType: 'priority',
      ),
    ],
    exampleSolution: const ['p2', 'p1'],
  );
  levels.add(l2);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l2.rows, l2.cols, l2.parcels));

  // Level 3: Three parcels showing chain reaction
  final l3 = LevelData(
    id: 3,
    name: 'Tutorial: Chain Reaction',
    rows: 4,
    cols: 4,
    difficulty: 'tutorial',
    tutorialText: 'Unblock packages step by step. Tapping a blocked package gives a gentle bump.',
    parcels: const [
      Parcel(
        id: 'p1',
        row: 1,
        col: 1,
        direction: Direction.right,
        colorType: 'standard',
      ),
      Parcel(
        id: 'p2',
        row: 1,
        col: 2,
        direction: Direction.down,
        colorType: 'priority',
      ),
      Parcel(
        id: 'p3',
        row: 2,
        col: 2,
        direction: Direction.right,
        colorType: 'fragile',
      ),
    ],
    exampleSolution: const ['p3', 'p2', 'p1'],
  );
  levels.add(l3);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l3.rows, l3.cols, l3.parcels));

  // --- LEVELS 4-10: Hand-authored Easy Puzzles ---

  // Level 4: Simple Crossroads (4 parcels, 2 pairs)
  final l4 = LevelData(
    id: 4,
    name: 'Crossroads Express',
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    parcels: const [
      Parcel(id: 'p1', row: 1, col: 1, direction: Direction.left, colorType: 'standard'),
      Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, colorType: 'standard'),
      Parcel(id: 'p3', row: 2, col: 1, direction: Direction.left, colorType: 'priority'),
      Parcel(id: 'p4', row: 2, col: 2, direction: Direction.right, colorType: 'priority'),
    ],
    exampleSolution: const ['p1', 'p2', 'p3', 'p4'],
  );
  levels.add(l4);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l4.rows, l4.cols, l4.parcels));

  // Level 5: Corner Lock (5 parcels)
  final l5 = LevelData(
    id: 5,
    name: 'Corner Depot',
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.down, colorType: 'fragile'),
      Parcel(id: 'p2', row: 1, col: 0, direction: Direction.down, colorType: 'standard'),
      Parcel(id: 'p3', row: 2, col: 0, direction: Direction.right, colorType: 'priority'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.up, colorType: 'eco'),
      Parcel(id: 'p5', row: 0, col: 1, direction: Direction.right, colorType: 'express'),
    ],
    exampleSolution: const ['p5', 'p4', 'p3', 'p2', 'p1'],
  );
  levels.add(l5);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l5.rows, l5.cols, l5.parcels));

  // Level 6: Central Hub (6 parcels)
  final l6 = LevelData(
    id: 6,
    name: 'Central Hub',
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    parcels: const [
      Parcel(id: 'p1', row: 1, col: 1, direction: Direction.up, colorType: 'standard'),
      Parcel(id: 'p2', row: 1, col: 2, direction: Direction.right, colorType: 'priority'),
      Parcel(id: 'p3', row: 2, col: 2, direction: Direction.down, colorType: 'standard'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.left, colorType: 'priority'),
      Parcel(id: 'p5', row: 0, col: 2, direction: Direction.up, colorType: 'eco'),
      Parcel(id: 'p6', row: 3, col: 1, direction: Direction.down, colorType: 'fragile'),
    ],
    exampleSolution: const ['p1', 'p3', 'p4', 'p5', 'p6', 'p2'],
  );
  levels.add(l6);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l6.rows, l6.cols, l6.parcels));

  // Level 7: Pinwheel (6 parcels)
  final l7 = LevelData(
    id: 7,
    name: 'Pinwheel Turn',
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 1, direction: Direction.left, colorType: 'express'),
      Parcel(id: 'p2', row: 1, col: 3, direction: Direction.up, colorType: 'standard'),
      Parcel(id: 'p3', row: 3, col: 2, direction: Direction.right, colorType: 'priority'),
      Parcel(id: 'p4', row: 2, col: 0, direction: Direction.down, colorType: 'eco'),
      Parcel(id: 'p5', row: 1, col: 1, direction: Direction.left, colorType: 'fragile'),
      Parcel(id: 'p6', row: 2, col: 2, direction: Direction.right, colorType: 'standard'),
    ],
    exampleSolution: const ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'],
  );
  levels.add(l7);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l7.rows, l7.cols, l7.parcels));

  // Level 8: Double Spiral (7 parcels)
  final l8 = LevelData(
    id: 8,
    name: 'Dual Conveyor',
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 0, direction: Direction.right, colorType: 'standard'),
      Parcel(id: 'p2', row: 0, col: 2, direction: Direction.down, colorType: 'priority'),
      Parcel(id: 'p3', row: 2, col: 2, direction: Direction.left, colorType: 'eco'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.down, colorType: 'fragile'),
      Parcel(id: 'p5', row: 3, col: 1, direction: Direction.down, colorType: 'standard'),
      Parcel(id: 'p6', row: 1, col: 0, direction: Direction.up, colorType: 'express'),
      Parcel(id: 'p7', row: 3, col: 3, direction: Direction.right, colorType: 'priority'),
    ],
    exampleSolution: const ['p5', 'p6', 'p7', 'p4', 'p3', 'p2', 'p1'],
  );
  levels.add(l8);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l8.rows, l8.cols, l8.parcels));

  // Level 9: Warehouse Grid (7 parcels)
  final l9 = LevelData(
    id: 9,
    name: 'Warehouse Aisle',
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    parcels: const [
      Parcel(id: 'p1', row: 1, col: 0, direction: Direction.right, colorType: 'standard'),
      Parcel(id: 'p2', row: 1, col: 2, direction: Direction.up, colorType: 'priority'),
      Parcel(id: 'p3', row: 0, col: 2, direction: Direction.right, colorType: 'eco'),
      Parcel(id: 'p4', row: 2, col: 1, direction: Direction.down, colorType: 'fragile'),
      Parcel(id: 'p5', row: 3, col: 1, direction: Direction.right, colorType: 'express'),
      Parcel(id: 'p6', row: 2, col: 3, direction: Direction.down, colorType: 'standard'),
      Parcel(id: 'p7', row: 3, col: 3, direction: Direction.right, colorType: 'priority'),
    ],
    exampleSolution: const ['p3', 'p2', 'p7', 'p6', 'p5', 'p4', 'p1'],
  );
  levels.add(l9);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l9.rows, l9.cols, l9.parcels));

  // Level 10: Dispatch Gate (8 parcels)
  final l10 = LevelData(
    id: 10,
    name: 'Dispatch Gate',
    rows: 4,
    cols: 4,
    difficulty: 'easy',
    parcels: const [
      Parcel(id: 'p1', row: 0, col: 1, direction: Direction.up, colorType: 'standard'),
      Parcel(id: 'p2', row: 1, col: 1, direction: Direction.up, colorType: 'priority'),
      Parcel(id: 'p3', row: 2, col: 1, direction: Direction.down, colorType: 'fragile'),
      Parcel(id: 'p4', row: 3, col: 1, direction: Direction.down, colorType: 'eco'),
      Parcel(id: 'p5', row: 1, col: 2, direction: Direction.right, colorType: 'standard'),
      Parcel(id: 'p6', row: 1, col: 3, direction: Direction.right, colorType: 'express'),
      Parcel(id: 'p7', row: 2, col: 2, direction: Direction.left, colorType: 'priority'),
      Parcel(id: 'p8', row: 2, col: 0, direction: Direction.left, colorType: 'standard'),
    ],
    exampleSolution: const ['p1', 'p4', 'p6', 'p8', 'p2', 'p3', 'p5', 'p7'],
  );
  levels.add(l10);
  signatures.addAll(LevelGenerator.computeSymmetrySignatures(l10.rows, l10.cols, l10.parcels));

  // --- LEVELS 11-30: Progressively deeper dependencies (4x4 to 5x5, 8 to 14 parcels) ---
  int currentSeed = 1001;
  for (int id = 11; id <= 30; id++) {
    final rows = id <= 18 ? 4 : 5;
    final cols = id <= 24 ? 5 : 5;
    // Target parcel counts scaled from 8 up to 14
    final targetCount = 8 + ((id - 11) * 6 / 19).round();

    final config = LevelGenerationConfig(
      seed: currentSeed,
      rows: rows,
      cols: cols,
      targetParcelCount: targetCount,
      difficulty: id <= 20 ? 'medium' : 'advanced',
    );

    final generated = LevelGenerator.generate(
      levelId: id,
      config: config,
      levelName: _getLevelName(id),
      existingSignatures: signatures,
    );

    levels.add(generated);
    signatures.addAll(LevelGenerator.computeSymmetrySignatures(rows, cols, generated.parcels));
    currentSeed += 313;
  }

  // --- LEVELS 31-50: Demanding layouts (5x5 to 6x6, 12 to 20 parcels) ---
  for (int id = 31; id <= 50; id++) {
    final rows = id <= 40 ? 5 : 6;
    final cols = id <= 40 ? 5 : 6;
    // Target parcel counts scaled from 13 up to 20
    final targetCount = 13 + ((id - 31) * 7 / 19).round();

    final config = LevelGenerationConfig(
      seed: currentSeed,
      rows: rows,
      cols: cols,
      targetParcelCount: targetCount,
      difficulty: id <= 42 ? 'hard' : 'master',
    );

    final generated = LevelGenerator.generate(
      levelId: id,
      config: config,
      levelName: _getLevelName(id),
      existingSignatures: signatures,
    );

    levels.add(generated);
    signatures.addAll(LevelGenerator.computeSymmetrySignatures(rows, cols, generated.parcels));
    currentSeed += 571;
  }

  // Verify ALL 50 levels with independent solver
  print('Validating all ${levels.length} levels with independent solver...');
  for (final level in levels) {
    final err = level.validateIntegrity();
    if (err != null) {
      throw StateError('Level ${level.id} integrity error: $err');
    }
    final res = PuzzleSolver.solve(
      rows: level.rows,
      cols: level.cols,
      parcels: level.parcels,
    );
    if (!res.isSolvable) {
      throw StateError('Level ${level.id} is NOT solvable! Stuck: ${res.deadlockedParcels}');
    }
    if (res.solutionOrder.length != level.parcels.length) {
      throw StateError('Level ${level.id} partial solve: ${res.solutionOrder.length}/${level.parcels.length}');
    }

    // Verify invariant: any branch preserves solvability
    final branchOk = PuzzleSolver.verifyAllRemovalOrdersSolvable(
      rows: level.rows,
      cols: level.cols,
      parcels: level.parcels,
      maxPaths: 30,
    );
    if (!branchOk) {
      throw StateError('Level ${level.id} violates invariant: alternative removal branch hit deadlock!');
    }
  }

  // Write frozen JSON
  final jsonMap = {
    'version': 1,
    'generatedAt': '2026-11-17T10:00:00Z',
    'totalLevels': levels.length,
    'levels': levels.map((l) => l.toJson()).toList(),
  };

  final outFile = File('assets/levels/levels.json');
  outFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonMap));
  print('Successfully generated and validated ${levels.length} levels into ${outFile.path} (${outFile.lengthSync()} bytes)');
}

String _getLevelName(int id) {
  const names = [
    'First Dispatch',
    'Sorting Facility',
    'Chain Delivery',
    'Crossroads Express',
    'Corner Depot',
    'Central Hub',
    'Pinwheel Turn',
    'Dual Conveyor',
    'Warehouse Aisle',
    'Dispatch Gate',
    'Cargo Maze',
    'Pallet Stacking',
    'Freight Transfer',
    'Shipping Corridor',
    'Package Cascade',
    'Interstate Depot',
    'Priority Loading',
    'Harbor Terminal',
    'Aviation Ramp',
    'Overnight Routing',
    'Cross-Dock Matrix',
    'Distribution Center',
    'Container Bay',
    'Forklift Grid',
    'Express Junction',
    'Rail Yard Switch',
    'Air Freight Dock',
    'Logistics Network',
    'Transit Terminal',
    'Cargo Labyrinth',
    'Metro Dispatch',
    'Sorting Carousel',
    'Deep Inventory',
    'Heavy Cargo Line',
    'Automated Conveyor',
    'High-Density Bay',
    'Supply Chain Rush',
    'Intermodal Depot',
    'Customs Clearance',
    'Transshipment Zone',
    'Master Courier',
    'Flight Deck Bay',
    'Strategic Dispatch',
    'Grand Warehouse',
    'Logistics Mastermind',
    'Peak Season Rush',
    'Apex Cargo Dock',
    'The Final Route',
    'Ultimate Escapement',
    'Grand Freight Finale',
  ];
  if (id >= 1 && id <= names.length) {
    return 'Level $id: ${names[id - 1]}';
  }
  return 'Level $id';
}

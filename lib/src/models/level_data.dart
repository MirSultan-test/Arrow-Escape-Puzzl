import 'parcel.dart';

/// Representation of a versioned level definition for Depot Challenge puzzles.
class LevelData {
  final int id;
  final String name;
  final String campaign; // 'depot' (previously 'windup')
  final int district; // 1..5 for Depot Challenge
  final int rows;
  final int cols;
  final List<Parcel> parcels;
  final String difficulty;
  final List<String> exampleSolution;
  final String? tutorialText;
  final List<String>? manifest; // Required sequence of category symbols
  final int rackCapacity; // Sorting rack slot count (default 2, up to 3)
  final List<int>? truckSizes; // Batch sizes per delivery truck (e.g. [2, 2])

  const LevelData({
    required this.id,
    required this.name,
    this.campaign = 'depot',
    this.district = 1,
    required this.rows,
    required this.cols,
    required this.parcels,
    required this.difficulty,
    required this.exampleSolution,
    this.tutorialText,
    this.manifest,
    this.rackCapacity = 2,
    this.truckSizes,
  });

  int get parcelCount => parcels.length;
  bool get hasGears => parcels.any((p) => p.hasGear);
  bool get hasManifest => manifest != null && manifest!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'campaign': campaign,
        'district': district,
        'rows': rows,
        'cols': cols,
        'parcels': parcels.map((p) => p.toJson()).toList(),
        'difficulty': difficulty,
        'exampleSolution': exampleSolution,
        if (tutorialText != null) 'tutorialText': tutorialText,
        if (manifest != null) 'manifest': manifest,
        'rackCapacity': rackCapacity,
        if (truckSizes != null) 'truckSizes': truckSizes,
      };

  factory LevelData.fromJson(Map<String, dynamic> json) {
    final rawParcels = (json['parcels'] as List<dynamic>?) ?? [];
    final parcelsList = rawParcels
        .map((p) => Parcel.fromJson(p as Map<String, dynamic>))
        .toList();

    final rawSolution = (json['exampleSolution'] as List<dynamic>?) ?? [];
    final solutionList = rawSolution.map((s) => s.toString()).toList();

    final rawManifest = (json['manifest'] as List<dynamic>?)
        ?.map((m) => m.toString())
        .toList();

    final rawTruckSizes = (json['truckSizes'] as List<dynamic>?)
        ?.map((s) => (s as num).toInt())
        .toList();

    return LevelData(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Level ${json['id']}',
      campaign: json['campaign'] as String? ?? 'depot',
      district: (json['district'] as num?)?.toInt() ?? 1,
      rows: json['rows'] as int,
      cols: json['cols'] as int,
      parcels: parcelsList,
      difficulty: json['difficulty'] as String? ?? 'standard',
      exampleSolution: solutionList,
      tutorialText: json['tutorialText'] as String?,
      manifest: rawManifest,
      rackCapacity: (json['rackCapacity'] as num?)?.toInt() ?? 2,
      truckSizes: rawTruckSizes,
    );
  }

  /// Validates level definition integrity:
  /// - rows and cols must be >= 1
  /// - parcels must not be empty
  /// - no two parcels share the same cell
  /// - no two parcels share the same ID
  /// - all parcel coordinates lie strictly within [0, rows) and [0, cols)
  /// - rackCapacity must be >= 2
  /// - if manifest is present, manifest item count and category distribution must match parcels
  /// - if truckSizes is present, sum must match parcels length
  String? validateIntegrity() {
    if (rows <= 0 || cols <= 0) {
      return 'Invalid grid dimensions: ${rows}x$cols';
    }
    if (parcels.isEmpty) {
      return 'Level has no parcels';
    }
    if (rackCapacity < 2) {
      return 'Rack capacity must be at least 2, found $rackCapacity';
    }
    final seenIds = <String>{};
    final seenPositions = <String>{};
    for (final p in parcels) {
      if (!seenIds.add(p.id)) {
        return 'Duplicate parcel ID found: ${p.id}';
      }
      if (p.row < 0 || p.row >= rows || p.col < 0 || p.col >= cols) {
        return 'Parcel ${p.id} position (${p.row}, ${p.col}) out of grid bounds (${rows}x$cols)';
      }
      final posKey = '${p.row},${p.col}';
      if (!seenPositions.add(posKey)) {
        return 'Multiple parcels occupy cell ($posKey)';
      }
    }

    if (manifest != null && manifest!.isNotEmpty) {
      if (manifest!.length != parcels.length) {
        return 'Manifest count (${manifest!.length}) does not match parcel count (${parcels.length})';
      }
      final manifestCounts = <String, int>{};
      for (final sym in manifest!) {
        manifestCounts[sym] = (manifestCounts[sym] ?? 0) + 1;
      }
      final parcelCounts = <String, int>{};
      for (final p in parcels) {
        final sym = p.manifestSymbol ?? 'star';
        parcelCounts[sym] = (parcelCounts[sym] ?? 0) + 1;
      }
      for (final entry in manifestCounts.entries) {
        if (parcelCounts[entry.key] != entry.value) {
          return 'Manifest count for category "${entry.key}" (${entry.value}) does not match parcels count (${parcelCounts[entry.key] ?? 0})';
        }
      }
    }

    if (truckSizes != null && truckSizes!.isNotEmpty) {
      final totalTruckCapacity = truckSizes!.fold<int>(0, (a, b) => a + b);
      if (totalTruckCapacity != parcels.length) {
        return 'Total truck capacity ($totalTruckCapacity) does not match parcel count (${parcels.length})';
      }
    }
    return null;
  }
}

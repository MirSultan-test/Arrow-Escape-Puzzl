import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/maze/maze_level.dart';

/// Loads and caches all 50 Food Maze Delivery Adventure levels from bundled JSON assets.
class MazeLevelRepository {
  static const String _assetPath = 'assets/levels/maze_levels.json';

  List<MazeLevel>? _cachedLevels;
  final List<MazeLevel>? _injectedLevels;

  MazeLevelRepository({List<MazeLevel>? injectedLevels})
      : _injectedLevels = injectedLevels;

  Future<List<MazeLevel>> loadAllLevels() async {
    if (_injectedLevels != null) return _injectedLevels;
    if (_cachedLevels != null) return _cachedLevels!;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = (decoded['levels'] as List<dynamic>)
        .map((e) => MazeLevel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    _cachedLevels = list;
    return list;
  }

  Future<MazeLevel?> getLevel(int id) async {
    final all = await loadAllLevels();
    for (final l in all) {
      if (l.id == id) return l;
    }
    return null;
  }
}

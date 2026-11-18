import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/level_data.dart';

/// Repository responsible for loading and querying frozen level definitions for both
/// the Wind-Up Depot campaign and Classic campaign.
class LevelRepository {
  static const String classicAssetPath = 'assets/levels/levels.json';
  static const String windupAssetPath = 'assets/levels/windup_levels.json';

  final List<LevelData> _classicLevels = [];
  final List<LevelData> _windupLevels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  int get totalLevels => _windupLevels.isNotEmpty ? _windupLevels.length : _classicLevels.length;

  /// Loads levels for both campaigns from the bundle.
  Future<List<LevelData>> loadLevels({
    String? customJsonString,
    String? customWindupJsonString,
  }) async {
    if (_isLoaded && customJsonString == null && customWindupJsonString == null) {
      return _windupLevels.isNotEmpty ? _windupLevels : _classicLevels;
    }

    // 1. Load Classic Levels
    String classicJson;
    if (customJsonString != null) {
      classicJson = customJsonString;
    } else {
      classicJson = await rootBundle.loadString(classicAssetPath);
    }
    final classicDecoded = jsonDecode(classicJson) as Map<String, dynamic>;
    final classicRawList = (classicDecoded['levels'] as List<dynamic>?) ?? [];
    _classicLevels.clear();
    for (final raw in classicRawList) {
      _classicLevels.add(LevelData.fromJson(raw as Map<String, dynamic>));
    }

    // 2. Load Wind-Up Levels
    String windupJson;
    if (customWindupJsonString != null) {
      windupJson = customWindupJsonString;
    } else {
      try {
        windupJson = await rootBundle.loadString(windupAssetPath);
      } catch (_) {
        windupJson = '[]';
      }
    }
    final dynamic windupDecoded = jsonDecode(windupJson);
    List<dynamic> windupRawList;
    if (windupDecoded is List) {
      windupRawList = windupDecoded;
    } else if (windupDecoded is Map<String, dynamic>) {
      windupRawList = (windupDecoded['levels'] as List<dynamic>?) ?? [];
    } else {
      windupRawList = [];
    }
    _windupLevels.clear();
    for (final raw in windupRawList) {
      _windupLevels.add(LevelData.fromJson(raw as Map<String, dynamic>));
    }

    _isLoaded = true;
    return _windupLevels.isNotEmpty ? _windupLevels : _classicLevels;
  }

  /// Synchronously populates the repository from an existing list (useful for tests).
  void populateFromList(List<LevelData> levels, {String campaign = 'classic'}) {
    if (campaign == 'windup') {
      _windupLevels.clear();
      _windupLevels.addAll(levels);
    } else {
      _classicLevels.clear();
      _classicLevels.addAll(levels);
      if (_windupLevels.isEmpty) {
        _windupLevels.addAll(levels);
      }
    }
    _isLoaded = true;
  }

  LevelData? getLevel(int id, {String? campaign}) {
    final camp = campaign ?? (_windupLevels.isNotEmpty ? 'windup' : 'classic');
    final targetList = camp == 'classic' ? _classicLevels : _windupLevels;
    if (id < 1 || id > targetList.length) {
      // Fallback
      if (camp == 'windup' && id <= _classicLevels.length) {
        return _classicLevels[id - 1];
      }
      return null;
    }
    return targetList[id - 1];
  }

  List<LevelData> getLevelsForCampaign(String campaign) {
    if (campaign == 'classic') return List.unmodifiable(_classicLevels);
    return List.unmodifiable(_windupLevels.isNotEmpty ? _windupLevels : _classicLevels);
  }

  List<LevelData> getAllLevels({String? campaign}) {
    if (campaign == 'classic') return List.unmodifiable(_classicLevels);
    return List.unmodifiable(_windupLevels.isNotEmpty ? _windupLevels : _classicLevels);
  }
}

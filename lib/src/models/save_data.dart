import 'dart:convert';
import 'dart:math' as math;
import 'parcel.dart';
import 'game_move.dart';

/// Persisted user save file supporting Schema Version 3 (Food Maze Adventure),
/// retaining recoverable backups of legacy Classic & Wind-Up Depot progress
/// while preserving privacy settings and reasonable access to unlocked levels.
class SaveData {
  static const int currentSchemaVersion = 3;

  final int schemaVersion;
  final String activeCampaign; // 'food_maze'

  // --- V3 Food Maze Adventure Campaign Progression ---
  final Set<int> mazeCompletedLevels;
  final int mazeHighestUnlockedLevel;
  final int mazeCurrentLevelId;
  final Map<int, int> mazeBestScores;
  final Map<int, int> mazeBestStars;
  final int totalCoins;
  final Set<int> mazeUnlockedPostcards; // 1..5
  final Set<String> unlockedCosmetics;

  // --- Legacy Backups (Retained safely, hidden from primary UI) ---
  final Set<int> completedLevels;
  final int highestUnlockedLevel;
  final int currentLevelId;
  final List<Parcel>? inProgressParcels;
  final List<GameMove>? inProgressMoves;

  final Set<int> windupCompletedLevels;
  final int windupHighestUnlockedLevel;
  final int windupCurrentLevelId;
  final List<Parcel>? windupInProgressParcels;
  final List<Parcel>? windupInProgressRack;
  final List<GameMove>? windupInProgressMoves;
  final int windupManifestIndex;
  final Set<int> unlockedMilestones;
  final Set<int> unlockedPostcards;
  final Set<int> windupNoHintLevels;
  final bool previewEnabled;

  // --- User Settings & Accessibility ---
  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final bool reducedMotion;
  final bool autoTargetEnabled;
  final String selectedThemeId;
  final bool tutorialCompleted;
  final int freeHintsRemaining;
  final int totalParcelsCleared;

  // --- Privacy & Ad Policy State (Strictly preserved even on reset) ---
  final bool ageGateCompleted;
  final String userAgeCategory; // 'unknown', 'child', 'neutral_adult'
  final bool? privacyConsentGiven;
  final int lastAdTimestampMs;
  final int levelsCompletedSinceLastAd;

  const SaveData({
    this.schemaVersion = currentSchemaVersion,
    this.activeCampaign = 'food_maze',
    this.mazeCompletedLevels = const {},
    this.mazeHighestUnlockedLevel = 1,
    this.mazeCurrentLevelId = 1,
    this.mazeBestScores = const {},
    this.mazeBestStars = const {},
    this.totalCoins = 0,
    this.mazeUnlockedPostcards = const {},
    this.unlockedCosmetics = const {},
    this.completedLevels = const {},
    this.highestUnlockedLevel = 1,
    this.currentLevelId = 1,
    this.inProgressParcels,
    this.inProgressMoves,
    this.windupCompletedLevels = const {},
    this.windupHighestUnlockedLevel = 1,
    this.windupCurrentLevelId = 1,
    this.windupInProgressParcels,
    this.windupInProgressRack,
    this.windupInProgressMoves,
    this.windupManifestIndex = 0,
    this.unlockedMilestones = const {},
    this.unlockedPostcards = const {},
    this.windupNoHintLevels = const {},
    this.previewEnabled = false,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.autoTargetEnabled = true,
    this.selectedThemeId = 'windup',
    this.tutorialCompleted = false,
    this.freeHintsRemaining = 3,
    this.totalParcelsCleared = 0,
    this.ageGateCompleted = false,
    this.userAgeCategory = 'unknown',
    this.privacyConsentGiven,
    this.lastAdTimestampMs = 0,
    this.levelsCompletedSinceLastAd = 0,
  });

  int get totalMazeStars =>
      mazeBestStars.values.fold<int>(0, (sum, s) => sum + s);

  SaveData copyWith({
    int? schemaVersion,
    String? activeCampaign,
    Set<int>? mazeCompletedLevels,
    int? mazeHighestUnlockedLevel,
    int? mazeCurrentLevelId,
    Map<int, int>? mazeBestScores,
    Map<int, int>? mazeBestStars,
    int? totalCoins,
    Set<int>? mazeUnlockedPostcards,
    Set<String>? unlockedCosmetics,
    Set<int>? completedLevels,
    int? highestUnlockedLevel,
    int? currentLevelId,
    List<Parcel>? inProgressParcels,
    bool clearClassicInProgress = false,
    bool clearInProgress = false,
    List<GameMove>? inProgressMoves,
    Set<int>? windupCompletedLevels,
    int? windupHighestUnlockedLevel,
    int? windupCurrentLevelId,
    List<Parcel>? windupInProgressParcels,
    List<Parcel>? windupInProgressRack,
    bool clearWindupInProgress = false,
    List<GameMove>? windupInProgressMoves,
    int? windupManifestIndex,
    Set<int>? unlockedMilestones,
    Set<int>? unlockedPostcards,
    Set<int>? windupNoHintLevels,
    bool? previewEnabled,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? hapticsEnabled,
    bool? reducedMotion,
    bool? autoTargetEnabled,
    String? selectedThemeId,
    bool? tutorialCompleted,
    int? freeHintsRemaining,
    int? totalParcelsCleared,
    bool? ageGateCompleted,
    String? userAgeCategory,
    bool? privacyConsentGiven,
    int? lastAdTimestampMs,
    int? levelsCompletedSinceLastAd,
  }) {
    final wipeClassic = clearClassicInProgress || clearInProgress;
    final wipeWindup = clearWindupInProgress || clearInProgress;
    return SaveData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      activeCampaign: activeCampaign ?? this.activeCampaign,
      mazeCompletedLevels: mazeCompletedLevels ?? this.mazeCompletedLevels,
      mazeHighestUnlockedLevel:
          mazeHighestUnlockedLevel ?? this.mazeHighestUnlockedLevel,
      mazeCurrentLevelId: mazeCurrentLevelId ?? this.mazeCurrentLevelId,
      mazeBestScores: mazeBestScores ?? this.mazeBestScores,
      mazeBestStars: mazeBestStars ?? this.mazeBestStars,
      totalCoins: totalCoins ?? this.totalCoins,
      mazeUnlockedPostcards:
          mazeUnlockedPostcards ?? this.mazeUnlockedPostcards,
      unlockedCosmetics: unlockedCosmetics ?? this.unlockedCosmetics,
      completedLevels: completedLevels ?? this.completedLevels,
      highestUnlockedLevel: highestUnlockedLevel ?? this.highestUnlockedLevel,
      currentLevelId: currentLevelId ?? this.currentLevelId,
      inProgressParcels: wipeClassic
          ? null
          : (inProgressParcels ?? this.inProgressParcels),
      inProgressMoves:
          wipeClassic ? null : (inProgressMoves ?? this.inProgressMoves),
      windupCompletedLevels:
          windupCompletedLevels ?? this.windupCompletedLevels,
      windupHighestUnlockedLevel:
          windupHighestUnlockedLevel ?? this.windupHighestUnlockedLevel,
      windupCurrentLevelId: windupCurrentLevelId ?? this.windupCurrentLevelId,
      windupInProgressParcels: wipeWindup
          ? null
          : (windupInProgressParcels ?? this.windupInProgressParcels),
      windupInProgressRack: wipeWindup
          ? null
          : (windupInProgressRack ?? this.windupInProgressRack),
      windupInProgressMoves: wipeWindup
          ? null
          : (windupInProgressMoves ?? this.windupInProgressMoves),
      windupManifestIndex: windupManifestIndex ?? this.windupManifestIndex,
      unlockedMilestones: unlockedMilestones ?? this.unlockedMilestones,
      unlockedPostcards: unlockedPostcards ?? this.unlockedPostcards,
      windupNoHintLevels: windupNoHintLevels ?? this.windupNoHintLevels,
      previewEnabled: previewEnabled ?? this.previewEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      autoTargetEnabled: autoTargetEnabled ?? this.autoTargetEnabled,
      selectedThemeId: selectedThemeId ?? this.selectedThemeId,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      freeHintsRemaining: freeHintsRemaining ?? this.freeHintsRemaining,
      totalParcelsCleared: totalParcelsCleared ?? this.totalParcelsCleared,
      ageGateCompleted: ageGateCompleted ?? this.ageGateCompleted,
      userAgeCategory: userAgeCategory ?? this.userAgeCategory,
      privacyConsentGiven: privacyConsentGiven ?? this.privacyConsentGiven,
      lastAdTimestampMs: lastAdTimestampMs ?? this.lastAdTimestampMs,
      levelsCompletedSinceLastAd:
          levelsCompletedSinceLastAd ?? this.levelsCompletedSinceLastAd,
    );
  }

  /// Resets active gameplay progress while strictly preserving privacy selections,
  /// age declarations, and user settings.
  SaveData resetProgressOnly() {
    return SaveData(
      schemaVersion: currentSchemaVersion,
      activeCampaign: 'food_maze',
      mazeCompletedLevels: const {},
      mazeHighestUnlockedLevel: 1,
      mazeCurrentLevelId: 1,
      mazeBestScores: const {},
      mazeBestStars: const {},
      totalCoins: 0,
      mazeUnlockedPostcards: const {},
      unlockedCosmetics: const {},
      completedLevels: const {},
      highestUnlockedLevel: 1,
      currentLevelId: 1,
      windupCompletedLevels: const {},
      windupHighestUnlockedLevel: 1,
      windupCurrentLevelId: 1,
      unlockedMilestones: const {},
      unlockedPostcards: const {},
      windupNoHintLevels: const {},
      previewEnabled: previewEnabled,
      soundEnabled: soundEnabled,
      musicEnabled: musicEnabled,
      hapticsEnabled: hapticsEnabled,
      reducedMotion: reducedMotion,
      autoTargetEnabled: autoTargetEnabled,
      selectedThemeId: selectedThemeId,
      tutorialCompleted: false,
      freeHintsRemaining: 3,
      totalParcelsCleared: 0,
      // Strictly preserved:
      ageGateCompleted: ageGateCompleted,
      userAgeCategory: userAgeCategory,
      privacyConsentGiven: privacyConsentGiven,
      lastAdTimestampMs: lastAdTimestampMs,
      levelsCompletedSinceLastAd: 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'activeCampaign': activeCampaign,
        'mazeCompletedLevels': mazeCompletedLevels.toList(),
        'mazeHighestUnlockedLevel': mazeHighestUnlockedLevel,
        'mazeCurrentLevelId': mazeCurrentLevelId,
        'mazeBestScores':
            mazeBestScores.map((k, v) => MapEntry(k.toString(), v)),
        'mazeBestStars':
            mazeBestStars.map((k, v) => MapEntry(k.toString(), v)),
        'totalCoins': totalCoins,
        'mazeUnlockedPostcards': mazeUnlockedPostcards.toList(),
        'unlockedCosmetics': unlockedCosmetics.toList(),
        // Historical backups
        'completedLevels': completedLevels.toList(),
        'highestUnlockedLevel': highestUnlockedLevel,
        'currentLevelId': currentLevelId,
        'inProgressParcels': inProgressParcels?.map((p) => p.toJson()).toList(),
        'inProgressMoves': inProgressMoves?.map((m) => m.toJson()).toList(),
        'windupCompletedLevels': windupCompletedLevels.toList(),
        'windupHighestUnlockedLevel': windupHighestUnlockedLevel,
        'windupCurrentLevelId': windupCurrentLevelId,
        'windupInProgressParcels':
            windupInProgressParcels?.map((p) => p.toJson()).toList(),
        'windupInProgressRack':
            windupInProgressRack?.map((p) => p.toJson()).toList(),
        'windupInProgressMoves':
            windupInProgressMoves?.map((m) => m.toJson()).toList(),
        'windupManifestIndex': windupManifestIndex,
        'unlockedMilestones': unlockedMilestones.toList(),
        'unlockedPostcards': unlockedPostcards.toList(),
        'windupNoHintLevels': windupNoHintLevels.toList(),
        'previewEnabled': previewEnabled,
        // Settings & privacy
        'soundEnabled': soundEnabled,
        'musicEnabled': musicEnabled,
        'hapticsEnabled': hapticsEnabled,
        'reducedMotion': reducedMotion,
        'autoTargetEnabled': autoTargetEnabled,
        'selectedThemeId': selectedThemeId,
        'tutorialCompleted': tutorialCompleted,
        'freeHintsRemaining': freeHintsRemaining,
        'totalParcelsCleared': totalParcelsCleared,
        'ageGateCompleted': ageGateCompleted,
        'userAgeCategory': userAgeCategory,
        'privacyConsentGiven': privacyConsentGiven,
        'lastAdTimestampMs': lastAdTimestampMs,
        'levelsCompletedSinceLastAd': levelsCompletedSinceLastAd,
      };

  factory SaveData.fromJson(Map<String, dynamic> json) {
    try {
      final rawSchema = (json['schemaVersion'] as num?)?.toInt() ?? 1;

      final classicCompleted = (json['completedLevels'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};
      final classicUnlocked =
          (json['highestUnlockedLevel'] as num?)?.toInt() ?? 1;
      final classicCurrent = (json['currentLevelId'] as num?)?.toInt() ?? 1;

      final windupCompleted = (json['windupCompletedLevels'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};
      final windupUnlocked =
          (json['windupHighestUnlockedLevel'] as num?)?.toInt() ?? 1;
      final windupCurrent =
          (json['windupCurrentLevelId'] as num?)?.toInt() ?? 1;

      // V3 Migration: keep historical puzzle completion records separate,
      // while preserving reasonable access to previously unlocked levels.
      final mazeCompleted = (json['mazeCompletedLevels'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};

      int mazeUnlocked;
      if (json.containsKey('mazeHighestUnlockedLevel')) {
        mazeUnlocked =
            (json['mazeHighestUnlockedLevel'] as num?)?.toInt() ?? 1;
      } else if (rawSchema < 3) {
        mazeUnlocked = math.max(1, math.max(windupUnlocked, classicUnlocked));
      } else {
        mazeUnlocked = 1;
      }

      final mazeCurrent =
          (json['mazeCurrentLevelId'] as num?)?.toInt() ?? 1;

      final bestScores = <int, int>{};
      if (json['mazeBestScores'] is Map) {
        (json['mazeBestScores'] as Map).forEach((k, v) {
          final parsedKey = int.tryParse(k.toString());
          if (parsedKey != null && v is num) {
            bestScores[parsedKey] = v.toInt();
          }
        });
      }

      final bestStars = <int, int>{};
      if (json['mazeBestStars'] is Map) {
        (json['mazeBestStars'] as Map).forEach((k, v) {
          final parsedKey = int.tryParse(k.toString());
          if (parsedKey != null && v is num) {
            bestStars[parsedKey] = v.toInt().clamp(0, 3);
          }
        });
      }

      final mazePostcards = (json['mazeUnlockedPostcards'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};

      final cosmetics = (json['unlockedCosmetics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{};

      final milestones = (json['unlockedMilestones'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};
      final postcards = (json['unlockedPostcards'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};
      final noHints = (json['windupNoHintLevels'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toSet() ??
          <int>{};

      return SaveData(
        schemaVersion: currentSchemaVersion,
        activeCampaign: 'food_maze',
        mazeCompletedLevels: mazeCompleted,
        mazeHighestUnlockedLevel: mazeUnlocked.clamp(1, 50),
        mazeCurrentLevelId: mazeCurrent.clamp(1, 50),
        mazeBestScores: bestScores,
        mazeBestStars: bestStars,
        totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
        mazeUnlockedPostcards: mazePostcards,
        unlockedCosmetics: cosmetics,
        completedLevels: classicCompleted,
        highestUnlockedLevel: classicUnlocked < 1 ? 1 : classicUnlocked,
        currentLevelId: classicCurrent < 1 ? 1 : classicCurrent,
        windupCompletedLevels: windupCompleted,
        windupHighestUnlockedLevel: windupUnlocked < 1 ? 1 : windupUnlocked,
        windupCurrentLevelId: windupCurrent < 1 ? 1 : windupCurrent,
        windupManifestIndex:
            (json['windupManifestIndex'] as num?)?.toInt() ?? 0,
        unlockedMilestones: milestones,
        unlockedPostcards: postcards,
        windupNoHintLevels: noHints,
        previewEnabled: json['previewEnabled'] as bool? ?? false,
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        musicEnabled: json['musicEnabled'] as bool? ?? true,
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        reducedMotion: json['reducedMotion'] as bool? ?? false,
        autoTargetEnabled: json['autoTargetEnabled'] as bool? ?? true,
        selectedThemeId: json['selectedThemeId'] as String? ?? 'windup',
        tutorialCompleted: json['tutorialCompleted'] as bool? ?? false,
        freeHintsRemaining:
            (json['freeHintsRemaining'] as num?)?.toInt() ?? 3,
        totalParcelsCleared:
            (json['totalParcelsCleared'] as num?)?.toInt() ?? 0,
        ageGateCompleted: json['ageGateCompleted'] as bool? ?? false,
        userAgeCategory: json['userAgeCategory'] as String? ?? 'unknown',
        privacyConsentGiven: json['privacyConsentGiven'] as bool?,
        lastAdTimestampMs:
            (json['lastAdTimestampMs'] as num?)?.toInt() ?? 0,
        levelsCompletedSinceLastAd:
            (json['levelsCompletedSinceLastAd'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const SaveData();
    }
  }

  static SaveData fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const SaveData();
    }
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return SaveData.fromJson(map);
      }
    } catch (_) {}
    return const SaveData();
  }

  String toJsonString() => jsonEncode(toJson());
}

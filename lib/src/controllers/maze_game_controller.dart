import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../engine/maze/maze_game_engine.dart';
import '../models/board_theme.dart';
import '../models/maze/delivery_state.dart';
import '../models/maze/maze_level.dart';
import '../models/save_data.dart';
import '../services/ad_service.dart';
import '../services/maze_level_repository.dart';
import '../services/sprite_atlas.dart';
import '../services/storage_service.dart';
import 'audio_controller.dart';

/// Central application controller for Parcel Escape: Food Maze Adventure.
/// Manages campaign progression, active maze engine, local persistence,
/// audio/haptics, privacy settings, and safe optional AdMob boundaries.
class MazeGameController extends ChangeNotifier {
  final StorageService storageService;
  final MazeLevelRepository levelRepository;
  final AdService adService;
  final AudioController audioController;
  final bool preloadSprites;

  SaveData _saveData = const SaveData();
  List<MazeLevel> _levels = const [];
  MazeLevel? _currentLevel;
  MazeGameEngine? _engine;

  // Lightweight 60 FPS canvas repaint notifier (avoids rebuilding full widget tree each frame!)
  final ValueNotifier<int> canvasRepaintTick = ValueNotifier<int>(0);
  double _hudSyncAccum = 0.0;
  int _lastHudHash = 0;

  // Idempotency guard per active level run so completion rewards can never duplicate
  int _runNonce = 0;
  int _lastRewardedRunNonce = -1;
  bool _isDisposed = false;

  // Newly unlocked district postcard ID on the latest victory (if any)
  int? _newlyUnlockedPostcardId;

  MazeGameController({
    required this.storageService,
    required this.levelRepository,
    required this.adService,
    required this.audioController,
    this.preloadSprites = true,
  });

  SaveData get saveData => _saveData;
  List<MazeLevel> get levels => _levels;
  MazeLevel? get currentLevel => _currentLevel;
  MazeGameEngine? get engine => _engine;
  int? get newlyUnlockedPostcardId => _newlyUnlockedPostcardId;

  BoardTheme get currentTheme => BoardTheme.fromId(_saveData.selectedThemeId);

  int get completedCount => _saveData.mazeCompletedLevels.length;
  int get totalStars => _saveData.totalMazeStars;
  int get totalCoins => _saveData.totalCoins;
  int get highestUnlockedLevel => _saveData.mazeHighestUnlockedLevel;

  /// Loads saved progress and all 50 validated Food Maze levels.
  Future<void> initialize() async {
    _saveData = await storageService.loadSaveData();
    audioController.soundEnabled = _saveData.soundEnabled;
    audioController.musicEnabled = _saveData.musicEnabled;
    audioController.hapticsEnabled = _saveData.hapticsEnabled;

    _levels = await levelRepository.loadAllLevels();
    if (preloadSprites) {
      await SpriteAtlas.instance.preloadAll();
    }
    await adService.initialize();

    final int targetId = _saveData.mazeCurrentLevelId
        .clamp(1, math.max(1, _levels.length))
        .toInt();
    selectLevel(targetId, persistSelection: false);
    _safeNotify();
  }

  MazeLevel? getLevelById(int id) {
    for (final l in _levels) {
      if (l.id == id) return l;
    }
    return _levels.isNotEmpty ? _levels.first : null;
  }

  bool isLevelUnlocked(int levelId) =>
      levelId <= _saveData.mazeHighestUnlockedLevel;

  int bestStarsForLevel(int levelId) => _saveData.mazeBestStars[levelId] ?? 0;

  int bestScoreForLevel(int levelId) => _saveData.mazeBestScores[levelId] ?? 0;

  /// Prepares [levelId] for a fresh playable run.
  void selectLevel(int levelId, {bool persistSelection = true}) {
    final level = getLevelById(levelId);
    if (level == null) return;

    _currentLevel = level;
    _runNonce++;
    _newlyUnlockedPostcardId = null;

    // Ensure the level's authentic 2.5D monster sprite is decoded and cached
    SpriteAtlas.instance.loadMonsterSprite(level.primaryPreviewPath);

    _engine = MazeGameEngine(
      level: level,
      autoTargetEnabled: _saveData.autoTargetEnabled,
      callbacks: MazeEngineCallbacks(
        onFoodPickup: (_) => audioController.playPickup(),
        onCargoFull: () => audioController.playWarning(),
        onMonsterAlert: (_) => audioController.playWarning(),
        onMonsterAttack: (_, __, ___) => audioController.playBite(),
        onWeaponFired: (_) => audioController.playTap(),
        onMonsterHit: (_, __, defeated) =>
            defeated ? audioController.playDeliver() : audioController.playBite(),
        onCombatPickup: (_) => audioController.playPickup(),
        onShieldBlocked: () => audioController.playDeliver(),
        onFoodDelivered: (_, __) => audioController.playDeliver(),
        onHealthRestored: (_, __) => audioController.playPickup(),
        onTruckEngineStart: () => audioController.playTruck(),
        onCageBreakOpen: () => audioController.playWarning(),
        onTruckDamaged: (_, __) => audioController.playBite(),
        onTruckRepaired: (_) => audioController.playPickup(),
        onBossHit: (_, defeated) =>
            defeated ? audioController.playDeliver() : audioController.playBite(),
        onAllySlash: () => audioController.playTap(),
        onCriticalTick: () => audioController.playTick(),
        onVictory: (breakdown) => _handleVictory(level, breakdown, _runNonce),
        onDefeat: (_) => audioController.playDefeat(),
      ),
    );
    _lastHudHash = 0;
    _hudSyncAccum = 0.0;

    if (persistSelection) {
      _saveData = _saveData.copyWith(mazeCurrentLevelId: level.id);
      storageService.persistSaveData(_saveData);
    }
    _safeNotify();
  }

  /// Restarts the active level immediately with zero penalties or ad gates.
  void restartCurrentLevel() {
    if (_currentLevel == null) return;
    selectLevel(_currentLevel!.id, persistSelection: false);
  }

  /// Steps the active real-time simulation at 60 FPS.
  /// Repaints the Maze CustomPainter every frame via [canvasRepaintTick] while
  /// rebuilding Flutter HUD widgets only when visible HUD values change (Section 14).
  void tickSimulation(double dtSeconds) {
    if (_isDisposed) return;
    final eng = _engine;
    if (eng == null) return;
    eng.step(dtSeconds);
    canvasRepaintTick.value++;

    _hudSyncAccum += dtSeconds;
    final td = eng.truckDefense;
    final hudHash = Object.hashAll([
      eng.phase,
      eng.activeDisplayRemainingTime.ceil(),
      eng.health,
      eng.hasShield,
      eng.carriedFoods.length,
      eng.deliveredFoods.length,
      eng.deliveredQuantityPercent,
      eng.hintMessage,
      eng.routeFeedbackMessage,
      eng.activePrimaryWeapon,
      eng.activeSpecialWeapon,
      eng.ammoFor(eng.activePrimaryWeapon),
      eng.activeSpecialWeapon != null
          ? eng.ammoFor(eng.activeSpecialWeapon!)
          : 0,
      eng.damageFlashTimer > 0,
      eng.healAnimTimer > 0,
      td.cageState,
      td.truck.hp,
      td.truck.tireCondition,
      td.truck.progressPercent,
      td.boss.hp,
      td.ally.hasKnifeDrawn,
    ]);

    final hasActiveCooldown =
        eng.weaponCooldowns.values.any((cd) => cd > 0.0) ||
            eng.damageFlashTimer > 0 ||
            eng.healAnimTimer > 0;

    if (hudHash != _lastHudHash || (hasActiveCooldown && _hudSyncAccum >= 0.08)) {
      _lastHudHash = hudHash;
      _hudSyncAccum = 0.0;
      _safeNotify();
    }
  }

  void triggerPrimaryAttack() {
    if (_engine == null) return;
    _engine!.triggerPrimaryAttack();
    canvasRepaintTick.value++;
    _safeNotify();
  }

  void triggerSpecialAttack() {
    if (_engine == null) return;
    _engine!.triggerSpecialAttack();
    canvasRepaintTick.value++;
    _safeNotify();
  }

  void cyclePrimaryWeapon() {
    if (_engine == null) return;
    audioController.playTap();
    _engine!.cyclePrimaryWeapon();
    canvasRepaintTick.value++;
    _safeNotify();
  }

  void cycleSpecialWeapon() {
    if (_engine == null) return;
    audioController.playTap();
    _engine!.cycleSpecialWeapon();
    canvasRepaintTick.value++;
    _safeNotify();
  }

  void pauseGame() {
    _engine?.pause();
    _safeNotify();
  }

  void resumeGame() {
    _engine?.resume();
    _safeNotify();
  }

  void requestHint() {
    if (_engine == null) return;
    audioController.playTap();
    _engine!.requestHint();
    _safeNotify();
  }

  void skipEscapeCutscene() {
    _engine?.skipEscapeCutscene();
    canvasRepaintTick.value++;
    _safeNotify();
  }

  void skipTruckAnimation() => skipEscapeCutscene();

  Future<void> _handleVictory(
    MazeLevel level,
    MazeScoreBreakdown breakdown,
    int nonce,
  ) async {
    // Strictly prevent duplicate rewards for the same completion event
    if (nonce == _lastRewardedRunNonce) return;
    _lastRewardedRunNonce = nonce;

    audioController.playWin();

    final completed = Set<int>.from(_saveData.mazeCompletedLevels)..add(level.id);
    final nextUnlocked = math.min(
      _levels.isNotEmpty ? _levels.length : 50,
      math.max(_saveData.mazeHighestUnlockedLevel, level.id + 1),
    );

    final scores = Map<int, int>.from(_saveData.mazeBestScores);
    final prevScore = scores[level.id] ?? 0;
    if (breakdown.totalScore > prevScore) {
      scores[level.id] = breakdown.totalScore;
    }

    final stars = Map<int, int>.from(_saveData.mazeBestStars);
    final prevStars = stars[level.id] ?? 0;
    if (breakdown.starsEarned > prevStars) {
      stars[level.id] = breakdown.starsEarned;
    }

    final postcards = Set<int>.from(_saveData.mazeUnlockedPostcards);
    _newlyUnlockedPostcardId = null;
    if (level.id % 10 == 0) {
      final districtId = level.id ~/ 10;
      if (!postcards.contains(districtId)) {
        postcards.add(districtId);
        _newlyUnlockedPostcardId = districtId;
      }
    }

    _saveData = _saveData.copyWith(
      mazeCompletedLevels: completed,
      mazeHighestUnlockedLevel: nextUnlocked,
      mazeCurrentLevelId: math.min(
        _levels.isNotEmpty ? _levels.length : 50,
        level.id + 1,
      ),
      mazeBestScores: scores,
      mazeBestStars: stars,
      totalCoins: _saveData.totalCoins + breakdown.coinsEarned,
      mazeUnlockedPostcards: postcards,
      levelsCompletedSinceLastAd: _saveData.levelsCompletedSinceLastAd + 1,
    );

    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  // --- Settings & Privacy (Preserving existing preferences & compliance) ---

  Future<void> setSoundEnabled(bool enabled) async {
    audioController.soundEnabled = enabled;
    _saveData = _saveData.copyWith(soundEnabled: enabled);
    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  Future<void> setMusicEnabled(bool enabled) async {
    audioController.musicEnabled = enabled;
    _saveData = _saveData.copyWith(musicEnabled: enabled);
    await audioController.syncBgm();
    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    audioController.hapticsEnabled = enabled;
    _saveData = _saveData.copyWith(hapticsEnabled: enabled);
    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  Future<void> setReducedMotion(bool enabled) async {
    _saveData = _saveData.copyWith(reducedMotion: enabled);
    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  Future<void> setAutoTargetEnabled(bool enabled) async {
    _engine?.autoTargetEnabled = enabled;
    _saveData = _saveData.copyWith(autoTargetEnabled: enabled);
    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  Future<void> setTheme(String themeId) async {
    _saveData = _saveData.copyWith(selectedThemeId: themeId);
    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  Future<void> setAgeGateCategory(String category) async {
    _saveData = _saveData.copyWith(
      ageGateCompleted: category != 'unknown',
      userAgeCategory: category,
    );
    await storageService.persistSaveData(_saveData);
    _safeNotify();
  }

  Future<void> resetProgress() async {
    _saveData = await storageService.resetProgressPreservingPrivacy();
    selectLevel(1, persistSelection: false);
    _safeNotify();
  }

  void handleAppBackgrounded() {
    pauseGame();
    audioController.pauseAll();
  }

  void handleAppResumed() {
    audioController.resumeAll();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    canvasRepaintTick.dispose();
    audioController.dispose();
    adService.dispose();
    super.dispose();
  }
}

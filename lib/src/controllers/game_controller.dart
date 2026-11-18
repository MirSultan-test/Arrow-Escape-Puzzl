import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine/puzzle_engine.dart';
import '../engine/state_space_solver.dart';
import '../models/board_theme.dart';
import '../models/direction.dart';
import '../models/level_data.dart';
import '../models/save_data.dart';
import '../services/ad_service.dart';
import '../services/level_repository.dart';
import '../services/storage_service.dart';
import 'audio_controller.dart';

/// Central game controller managing puzzle state, animations, progression, and storage.
/// Powers the single unified Depot Challenge campaign ("Think. Dispatch. Sort. Deliver. Build.").
class GameController extends ChangeNotifier {
  final StorageService storageService;
  final LevelRepository levelRepository;
  final AdService adService;
  final AudioController audioController;

  SaveData _saveData = const SaveData();
  LevelData? _currentLevel;
  PuzzleEngine? _engine;

  // Animation and Input Serialization State
  bool _isInputLocked = false;
  String? _animatingExitParcelId;
  Direction? _animatingExitDirection;
  String? _animatingBumpParcelId;
  Direction? _animatingBumpDirection;
  String? _manifestMismatchParcelId;
  String? _rackFullFeedbackParcelId;
  String? _animatingRackParcelId;
  bool _isTruckDeparting = false;
  String? _highlightedHintParcelId;

  // Stuck Route / Deadlock Detection
  bool _isRouteStuck = false;

  // Non-mutating Exit Preview State
  bool _isPreviewModeActive = false;
  ExitPreview? _currentPreview;

  // Level attempt state
  int _freeHintsThisAttempt = 1;
  bool _isDisposed = false;

  GameController({
    required this.storageService,
    required this.levelRepository,
    required this.adService,
    required this.audioController,
  });

  SaveData get saveData => _saveData;
  LevelData? get currentLevel => _currentLevel;
  PuzzleEngine? get engine => _engine;
  String get activeCampaign => 'windup'; // Single unified Depot Challenge campaign

  bool get isInputLocked => _isInputLocked;
  String? get animatingExitParcelId => _animatingExitParcelId;
  Direction? get animatingExitDirection => _animatingExitDirection;
  String? get animatingBumpParcelId => _animatingBumpParcelId;
  Direction? get animatingBumpDirection => _animatingBumpDirection;
  String? get manifestMismatchParcelId => _manifestMismatchParcelId;
  String? get rackFullFeedbackParcelId => _rackFullFeedbackParcelId;
  String? get animatingRackParcelId => _animatingRackParcelId;
  bool get isTruckDeparting => _isTruckDeparting;
  String? get highlightedHintParcelId => _highlightedHintParcelId;

  bool get isRouteStuck => _isRouteStuck;
  bool get isPreviewModeActive => _isPreviewModeActive;
  ExitPreview? get currentPreview => _currentPreview;

  bool get isCompleted => _engine?.isCompleted ?? false;
  int get remainingParcelsCount => _engine?.remainingCount ?? 0;
  int get totalParcelsCount => _engine?.initialCount ?? 0;
  int get freeHintsThisAttempt => _freeHintsThisAttempt;

  BoardTheme get currentTheme =>
      BoardTheme.fromId(_saveData.selectedThemeId);

  /// Initializes the controller by loading saved data and bootstrapping the initial level.
  Future<void> initialize() async {
    _saveData = await storageService.loadSaveData();
    audioController.soundEnabled = _saveData.soundEnabled;
    audioController.hapticsEnabled = _saveData.hapticsEnabled;

    if (!levelRepository.isLoaded) {
      await levelRepository.loadLevels();
    }

    final levelToLoad = _saveData.windupCurrentLevelId;
    await loadLevel(levelToLoad, restoreInProgress: true);
  }

  /// No-op campaign switcher maintaining backwards compatibility.
  Future<void> switchCampaign(String campaign) async {
    // Single unified Depot Challenge campaign
    notifyListeners();
  }

  /// Loads a level by ID for the Depot Challenge campaign.
  Future<void> loadLevel(
    int levelId, {
    String? campaign,
    bool restoreInProgress = false,
  }) async {
    final level = levelRepository.getLevel(levelId, campaign: 'windup');
    if (level == null) return;

    _currentLevel = level;
    _animatingExitParcelId = null;
    _animatingExitDirection = null;
    _animatingBumpParcelId = null;
    _animatingBumpDirection = null;
    _manifestMismatchParcelId = null;
    _rackFullFeedbackParcelId = null;
    _animatingRackParcelId = null;
    _isTruckDeparting = false;
    _highlightedHintParcelId = null;
    _currentPreview = null;
    _isInputLocked = false;
    _isRouteStuck = false;
    _freeHintsThisAttempt = 1;

    _engine = PuzzleEngine(
      rows: level.rows,
      cols: level.cols,
      parcels: level.parcels,
      manifest: level.manifest,
      rackCapacity: level.rackCapacity,
      truckSizes: level.truckSizes,
    );

    // If restoring saved in-progress puzzle for the exact same level
    if (restoreInProgress &&
        _saveData.windupCurrentLevelId == levelId &&
        _saveData.windupInProgressParcels != null &&
        _saveData.windupInProgressParcels!.isNotEmpty) {
      _engine!.restoreState(
        currentParcels: _saveData.windupInProgressParcels!,
        rackParcels: _saveData.windupInProgressRack,
        pastMoves: _saveData.windupInProgressMoves,
        manifestIndex: _saveData.windupManifestIndex,
      );
    } else {
      _saveData = _saveData.copyWith(
        windupCurrentLevelId: levelId,
        clearWindupInProgress: true,
      );
      await storageService.persistSaveData(_saveData);
    }

    _evaluateStuckState();
    if (!_isDisposed) notifyListeners();
  }

  /// Sets or clears the candidate parcel for non-mutating preview.
  void setPreviewParcel(String? parcelId) {
    if (_engine == null || parcelId == null) {
      _currentPreview = null;
    } else {
      _currentPreview = _engine!.previewExit(parcelId);
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Toggles preview inspection mode on or off.
  void togglePreviewMode() {
    _isPreviewModeActive = !_isPreviewModeActive;
    if (!_isPreviewModeActive) {
      _currentPreview = null;
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Handles user tapping on a parcel anywhere (on board or in sorting rack).
  Future<void> onParcelTapped(String parcelId) async {
    if (_isInputLocked || _engine == null || _engine!.isCompleted) {
      return;
    }

    // Check if parcel is on the board
    if (_engine!.matrix.getById(parcelId) != null) {
      await onBoardParcelTapped(parcelId);
      return;
    }

    // Check if parcel is in the sorting rack
    if (_engine!.rack.any((p) => p.id == parcelId)) {
      await onRackParcelTapped(parcelId);
      return;
    }
  }

  /// Handles tapping a parcel on the Arrow Board (dispatches it to the Sorting Rack).
  Future<void> onBoardParcelTapped(String parcelId) async {
    if (_isInputLocked || _engine == null || _engine!.isCompleted) return;

    final parcel = _engine!.matrix.getById(parcelId);
    if (parcel == null) return;

    final eval = _engine!.evaluateDispatch(parcelId);
    if (!eval.isLegal) {
      if (eval.legality == ExitLegality.blockedByRay) {
        // Gentle bump animation
        _animatingBumpParcelId = parcelId;
        _animatingBumpDirection = parcel.direction;
        audioController.playBump();
        if (!_isDisposed) notifyListeners();

        final bumpDuration = _saveData.reducedMotion ? 40 : 160;
        await Future.delayed(Duration(milliseconds: bumpDuration));

        if (_animatingBumpParcelId == parcelId) {
          _animatingBumpParcelId = null;
          _animatingBumpDirection = null;
          if (!_isDisposed) notifyListeners();
        }
      } else if (eval.legality == ExitLegality.rackFull) {
        // Sorting rack full feedback
        _rackFullFeedbackParcelId = parcelId;
        audioController.playBump();
        if (!_isDisposed) notifyListeners();

        await Future.delayed(const Duration(milliseconds: 250));
        if (_rackFullFeedbackParcelId == parcelId) {
          _rackFullFeedbackParcelId = null;
          if (!_isDisposed) notifyListeners();
        }
      }
      return;
    }

    // Legal dispatch: serialize input during animation
    _isInputLocked = true;
    _highlightedHintParcelId = null;
    _currentPreview = null;
    _animatingExitParcelId = parcelId;
    _animatingExitDirection = parcel.direction;
    audioController.playExit();
    if (!_isDisposed) notifyListeners();

    final exitDuration = _saveData.reducedMotion ? 50 : 250;
    await Future.delayed(Duration(milliseconds: exitDuration));

    if (_isDisposed) return;

    // Execute dispatch (adds to rack & rotates surviving board gears)
    _engine!.executeDispatch(parcelId);
    _animatingExitParcelId = null;
    _animatingExitDirection = null;
    _isInputLocked = false;

    await _persistCurrentProgress();
    _evaluateStuckState();
    if (!_isDisposed) notifyListeners();
  }

  /// Handles tapping a parcel in the Sorting Rack (loads it into the Delivery Truck).
  Future<void> onRackParcelTapped(String parcelId) async {
    if (_isInputLocked || _engine == null || _engine!.isCompleted) return;

    final matches = _engine!.rack.where((p) => p.id == parcelId);
    if (matches.isEmpty) return;

    final eval = _engine!.evaluateLoad(parcelId);
    if (!eval.isLegal) {
      if (eval.legality == ExitLegality.manifestMismatch) {
        // Mismatch feedback on rack parcel
        _manifestMismatchParcelId = parcelId;
        audioController.playBump();
        if (!_isDisposed) notifyListeners();

        await Future.delayed(const Duration(milliseconds: 250));
        if (_manifestMismatchParcelId == parcelId) {
          _manifestMismatchParcelId = null;
          if (!_isDisposed) notifyListeners();
        }
      }
      return;
    }

    // Legal load to truck
    _isInputLocked = true;
    _highlightedHintParcelId = null;
    _animatingRackParcelId = parcelId;
    audioController.playTap();
    if (!_isDisposed) notifyListeners();

    final loadDuration = _saveData.reducedMotion ? 50 : 220;
    await Future.delayed(Duration(milliseconds: loadDuration));

    if (_isDisposed) return;

    final prevTruckIndex = _engine!.currentTruckIndex;
    _engine!.executeLoad(parcelId);
    _animatingRackParcelId = null;
    _isInputLocked = false;

    // Check if the current truck just departed
    final currentTruckIndex = _engine!.currentTruckIndex;
    if (currentTruckIndex != prevTruckIndex || _engine!.isCompleted) {
      _isTruckDeparting = true;
      audioController.playExit();
      if (!_isDisposed) notifyListeners();

      final departDuration = _saveData.reducedMotion ? 100 : 450;
      await Future.delayed(Duration(milliseconds: departDuration));
      _isTruckDeparting = false;
    }

    if (_engine!.isCompleted) {
      await _handleLevelVictory();
    } else {
      await _persistCurrentProgress();
      _evaluateStuckState();
    }

    if (!_isDisposed) notifyListeners();
  }

  Future<void> _handleLevelVictory() async {
    audioController.playWin();
    _isRouteStuck = false;

    final currentId = _currentLevel?.id ?? 1;
    final updatedCompleted =
        Set<int>.from(_saveData.windupCompletedLevels)..add(currentId);
    final classicCompleted =
        Set<int>.from(_saveData.completedLevels)..add(currentId);

    int nextUnlocked = _saveData.windupHighestUnlockedLevel;
    if (currentId >= _saveData.windupHighestUnlockedLevel &&
        currentId < levelRepository.totalLevels) {
      nextUnlocked = currentId + 1;
    }

    final updatedMilestones = Set<int>.from(_saveData.unlockedMilestones);
    final updatedPostcards = Set<int>.from(_saveData.unlockedPostcards);

    if (currentId % 5 == 0) {
      final mId = currentId ~/ 5;
      updatedMilestones.add(mId);
    }
    if (currentId % 10 == 0) {
      final pId = currentId ~/ 10;
      updatedPostcards.add(pId);
    }

    _saveData = _saveData.copyWith(
      windupCompletedLevels: updatedCompleted,
      completedLevels: classicCompleted,
      windupHighestUnlockedLevel: nextUnlocked,
      highestUnlockedLevel: nextUnlocked,
      clearWindupInProgress: true,
      clearClassicInProgress: true,
      totalParcelsCleared: _saveData.totalParcelsCleared + 1,
      unlockedMilestones: updatedMilestones,
      unlockedPostcards: updatedPostcards,
      tutorialCompleted: currentId >= 3 ? true : _saveData.tutorialCompleted,
      levelsCompletedSinceLastAd: _saveData.levelsCompletedSinceLastAd + 1,
    );

    await storageService.persistSaveData(_saveData);
  }

  Future<void> _persistCurrentProgress() async {
    if (_engine == null) return;
    _saveData = _saveData.copyWith(
      windupInProgressParcels: _engine!.activeParcels,
      windupInProgressRack: _engine!.rack,
      windupInProgressMoves: _engine!.moves,
      windupManifestIndex: _engine!.manifestIndex,
      totalParcelsCleared: _saveData.totalParcelsCleared + 1,
    );
    await storageService.persistSaveData(_saveData);
  }

  void _evaluateStuckState() {
    if (_engine == null || _engine!.isCompleted) {
      _isRouteStuck = false;
      return;
    }

    if (_engine!.isDeadlocked) {
      _isRouteStuck = true;
      return;
    }

    // State space solver check for Depot Challenge puzzles
    const solver = StateSpaceSolver(maxStates: 2000);
    final res = solver.solve(_engine!);
    _isRouteStuck = res.isUnsolvable;
  }

  /// Undoes the last action (dispatch or load), restoring previous state atomically.
  Future<void> undo() async {
    if (_isInputLocked || _engine == null || _engine!.moves.isEmpty) return;
    _highlightedHintParcelId = null;
    _currentPreview = null;
    audioController.playTap();
    _engine!.undo();

    _saveData = _saveData.copyWith(
      windupInProgressParcels: _engine!.activeParcels,
      windupInProgressRack: _engine!.rack,
      windupInProgressMoves: _engine!.moves,
      windupManifestIndex: _engine!.manifestIndex,
    );
    await storageService.persistSaveData(_saveData);

    _evaluateStuckState();
    if (!_isDisposed) notifyListeners();
  }

  /// Restarts the current puzzle back to its pristine initial state.
  Future<void> restart() async {
    if (_isInputLocked || _engine == null) return;
    _highlightedHintParcelId = null;
    _currentPreview = null;
    _isRouteStuck = false;
    audioController.playTap();
    _engine!.restart();
    _freeHintsThisAttempt = 1;

    _saveData = _saveData.copyWith(clearInProgress: true);
    await storageService.persistSaveData(_saveData);
    if (!_isDisposed) notifyListeners();
  }

  /// Requests a dynamic solver-backed hint that highlights the next winning parcel.
  Future<void> requestHint({
    required void Function(String message) onMessage,
    required Future<bool> Function() requestRewardedAdConsent,
  }) async {
    if (_isInputLocked || _engine == null || _engine!.isCompleted) return;

    if (_isRouteStuck) {
      onMessage('Route is stuck. Use Undo to backtrack!');
      return;
    }

    const solver = StateSpaceSolver(maxStates: 5000);
    final bestMoveId = solver.findBestMove(_engine!);

    if (bestMoveId == null) {
      _isRouteStuck = true;
      onMessage('Route is stuck. Undo a move?');
      if (!_isDisposed) notifyListeners();
      return;
    }

    // 1. Free hint available for this attempt
    if (_freeHintsThisAttempt > 0) {
      _freeHintsThisAttempt--;
      _highlightedHintParcelId = bestMoveId;
      audioController.playTap();
      if (!_isDisposed) notifyListeners();
      return;
    }

    // 2. Free banked hints in save data
    if (_saveData.freeHintsRemaining > 0) {
      _saveData = _saveData.copyWith(
        freeHintsRemaining: _saveData.freeHintsRemaining - 1,
      );
      await storageService.persistSaveData(_saveData);
      _highlightedHintParcelId = bestMoveId;
      audioController.playTap();
      if (!_isDisposed) notifyListeners();
      return;
    }

    // 3. Rewarded ad opt-in
    final consent = await requestRewardedAdConsent();
    if (!consent) return;

    final adShown = await adService.showRewardedAd(
      onUserEarnedReward: () async {
        _saveData = _saveData.copyWith(
          freeHintsRemaining: _saveData.freeHintsRemaining + 1,
        );
        await storageService.persistSaveData(_saveData);
        _highlightedHintParcelId = bestMoveId;
        audioController.playTap();
        onMessage('Hint unlocked via delivery sponsor!');
        if (!_isDisposed) notifyListeners();
      },
      onAdFailedToShow: (err) {
        _highlightedHintParcelId = bestMoveId;
        onMessage('Delivery sponsor unavailable. Free hint granted!');
        if (!_isDisposed) notifyListeners();
      },
    );

    if (!adShown) {
      _highlightedHintParcelId = bestMoveId;
      onMessage('Delivery sponsor unavailable. Free hint granted!');
      if (!_isDisposed) notifyListeners();
    }
  }

  /// Evaluates whether an interstitial ad should be presented after completing a level.
  Future<void> maybeShowLevelTransitionAd() async {
    final shown = await adService.showInterstitialIfEligible(
      currentLevel: _currentLevel?.id ?? 1,
      levelsCompletedSinceLastAd: _saveData.levelsCompletedSinceLastAd,
      lastAdTimestampMs: _saveData.lastAdTimestampMs,
    );

    if (shown) {
      _saveData = _saveData.copyWith(
        lastAdTimestampMs: DateTime.now().millisecondsSinceEpoch,
        levelsCompletedSinceLastAd: 0,
      );
      await storageService.persistSaveData(_saveData);
    }
  }

  // Settings & Theme Updaters
  Future<void> setAgeGateCategory(String category) => setAgeGateCompleted(category);
  Future<void> resetProgress() => resetAllProgress();
  Future<void> setSoundEnabled(bool enabled) async {
    audioController.soundEnabled = enabled;
    _saveData = _saveData.copyWith(soundEnabled: enabled);
    await storageService.persistSaveData(_saveData);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    audioController.hapticsEnabled = enabled;
    _saveData = _saveData.copyWith(hapticsEnabled: enabled);
    await storageService.persistSaveData(_saveData);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setReducedMotion(bool enabled) async {
    _saveData = _saveData.copyWith(reducedMotion: enabled);
    await storageService.persistSaveData(_saveData);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setTheme(String themeId) async {
    _saveData = _saveData.copyWith(selectedThemeId: themeId);
    await storageService.persistSaveData(_saveData);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setAgeGateCompleted(String category) async {
    _saveData = _saveData.copyWith(
      ageGateCompleted: true,
      userAgeCategory: category,
    );
    await storageService.persistSaveData(_saveData);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> setPrivacyConsent(bool consent) async {
    _saveData = _saveData.copyWith(privacyConsentGiven: consent);
    await storageService.persistSaveData(_saveData);
    if (!_isDisposed) notifyListeners();
  }

  Future<void> resetAllProgress() async {
    _saveData = _saveData.resetProgressOnly();
    await storageService.persistSaveData(_saveData);
    await loadLevel(1);
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

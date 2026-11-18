import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../config/app_design_tokens.dart';
import '../controllers/maze_game_controller.dart';
import '../engine/maze/maze_game_engine.dart';
import '../models/maze/combat_models.dart';
import '../models/maze/delivery_state.dart';
import '../models/maze/food_item.dart';
import '../models/maze/truck_defense_models.dart';
import '../rendering/maze/food_illustrator.dart';
import '../rendering/maze/maze_canvas_painter.dart';
import '../rendering/maze/road_battle_painter.dart';
import '../rendering/maze/virtual_joystick.dart';
import 'defeat_dialog.dart';
import 'level_complete_dialog.dart';

/// Real-time Food Maze Delivery Adventure gameplay screen (V3.1).
/// Maximizes maze size, positions the compact Delivery Dock below the maze,
/// removes automatic startup hint banners, elevates a larger joystick, and animates health hearts.
class GameplayScreen extends StatefulWidget {
  final MazeGameController controller;

  const GameplayScreen({super.key, required this.controller});

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  bool _endDialogShown = false;
  Size _lastMazeSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.audioController.syncBgm();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      widget.controller.handleAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      widget.controller.handleAppResumed();
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final eng = widget.controller.engine;
    if (eng == null) return;

    widget.controller.tickSimulation(dt);

    if (!_endDialogShown &&
        (eng.phase == MazeGamePhase.victory ||
            eng.phase == MazeGamePhase.defeat)) {
      _endDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (eng.phase == MazeGamePhase.victory && eng.finalBreakdown != null) {
          _showVictoryDialog(eng.finalBreakdown!);
        } else if (eng.phase == MazeGamePhase.defeat) {
          _showDefeatDialog(eng.defeatReason);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  void _restartLevel() {
    _endDialogShown = false;
    widget.controller.restartCurrentLevel();
  }

  void _loadNextLevel() {
    final cur = widget.controller.currentLevel;
    if (cur == null) return;
    _endDialogShown = false;
    widget.controller.selectLevel(cur.id + 1);
  }

  void _openPauseMenu() {
    widget.controller.pauseGame();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PauseDialog(
        controller: widget.controller,
        onResume: () {
          Navigator.of(ctx).pop();
          widget.controller.resumeGame();
        },
        onRestart: () {
          Navigator.of(ctx).pop();
          _restartLevel();
        },
        onLevelMap: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showVictoryDialog(MazeScoreBreakdown breakdown) {
    final level = widget.controller.currentLevel!;
    final hasNext = level.id < widget.controller.levels.length;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LevelCompleteDialog(
        level: level,
        breakdown: breakdown,
        hasNextLevel: hasNext,
        unlockedPostcardId: widget.controller.newlyUnlockedPostcardId,
        onNextLevel: () {
          Navigator.of(ctx).pop();
          _loadNextLevel();
        },
        onReplay: () {
          Navigator.of(ctx).pop();
          _restartLevel();
        },
        onLevelMap: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showDefeatDialog(DefeatReason reason) {
    final eng = widget.controller.engine!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DefeatDialog(
        reason: reason,
        deliveredPercent: eng.deliveredQuantityPercent,
        requiredQuotaPercent: eng.level.minQuotaPercent,
        onRetry: () {
          Navigator.of(ctx).pop();
          _restartLevel();
        },
        onLevelMap: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _handleMazeTap(TapUpDetails details) {
    final eng = widget.controller.engine;
    if (eng == null || _lastMazeSize == Size.zero) return;

    if (eng.phase.isCutsceneOrLoading || eng.phase == MazeGamePhase.truckArrived) {
      widget.controller.skipEscapeCutscene();
      return;
    }
    if (eng.phase != MazeGamePhase.playing) return;

    final vp = MazeViewportTransform.compute(_lastMazeSize, eng);
    final tappedCell = vp.screenToCell(details.localPosition);
    if (eng.level.inBounds(tappedCell.col, tappedCell.row)) {
      eng.setTapTarget(tappedCell);
    } else if (tappedCell.row >= eng.level.rows) {
      // Tapping on the bottom collector/truck dock walks directly to the bottom exit!
      eng.setTapTarget(eng.level.exitCell);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final eng = widget.controller.engine;
        final level = widget.controller.currentLevel;
        if (eng == null || level == null) {
          return const Scaffold(
            backgroundColor: AppDesignTokens.warmCream,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final district = level.districtInfo;
        final reducedMotion = widget.controller.saveData.reducedMotion;
        final media = MediaQuery.of(context);
        final screenW = media.size.width;
        final screenH = media.size.height;

        return Scaffold(
          backgroundColor: Color(district.skyBgHex),
          body: SafeArea(
            child: Column(
              children: [
                // 1. COMPACT TOP HEADER BAR (Level, Timer, Animated Hearts, Pause)
                _buildTopHeader(eng, level.id, district.name, reducedMotion),

                // 2. SLIM STATUS BAR: Delivery Quota (Stage 1) OR Truck HP & Destination Progress (Stage 2)
                if (eng.phase.isRoadBattleView)
                  _buildTruckDefenseHudPanel(eng)
                else
                  _buildDeliveryProgressPanel(eng),

                // 3. CENTRAL GAMEPLAY VIEWPORT:
                // Smoothly transitions from Expanded Maze + Cage + Dock -> Full-Screen Road Battle Arena!
                Expanded(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          _lastMazeSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          final showRoadArena = eng.phase.isRoadBattleView;
                          final transitionT =
                              eng.truckDefense.arenaTransitionProgress;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: _handleMazeTap,
                            child: AnimatedSwitcher(
                              duration: Duration(
                                milliseconds: reducedMotion ? 0 : 420,
                              ),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.96, end: 1.0)
                                      .animate(anim),
                                  child: child,
                                ),
                              ),
                              child: showRoadArena
                                  ? RepaintBoundary(
                                      key: const ValueKey('road_battle_arena'),
                                      child: CustomPaint(
                                        painter: RoadBattlePainter(
                                          engine: eng,
                                          reducedMotion: reducedMotion,
                                          repaint: widget
                                              .controller.canvasRepaintTick,
                                        ),
                                        size: _lastMazeSize,
                                      ),
                                    )
                                  : Stack(
                                      key: const ValueKey('maze_stage_canvas'),
                                      fit: StackFit.expand,
                                      children: [
                                        RepaintBoundary(
                                          child: CustomPaint(
                                            painter: MazeCanvasPainter(
                                              engine: eng,
                                              reducedMotion: reducedMotion,
                                              repaint: widget
                                                  .controller.canvasRepaintTick,
                                            ),
                                            size: _lastMazeSize,
                                          ),
                                        ),
                                        // Smooth live camera-blend fade during final moments of Cage Escape Cutscene
                                        if (eng.phase ==
                                                MazeGamePhase
                                                    .cageEscapeCutscene &&
                                            transitionT > 0.25 &&
                                            !reducedMotion)
                                          Opacity(
                                            opacity: ((transitionT - 0.25) /
                                                    0.75)
                                                .clamp(0.0, 0.92),
                                            child: RepaintBoundary(
                                              child: CustomPaint(
                                                painter: RoadBattlePainter(
                                                  engine: eng,
                                                  reducedMotion: reducedMotion,
                                                  repaint: widget.controller
                                                      .canvasRepaintTick,
                                                ),
                                                size: _lastMazeSize,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),

                      // Subtle red damage vignette flash around edges on hit
                      if (eng.damageFlashTimer > 0 && !reducedMotion)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppDesignTokens.timerCritical.withOpacity(
                                  (eng.damageFlashTimer / 0.45).clamp(0.0, 1.0) *
                                      0.55,
                                ),
                                width: 5,
                              ),
                            ),
                          ),
                        ),

                      // ON-DEMAND FLOATING HINT OVERLAY ONLY (never auto-shown at startup!)
                      if (eng.hintMessage != null)
                        _buildOnDemandHintOverlay(eng),

                      // Cage Escape Cutscene Alert Banner (short & skippable!)
                      if (eng.phase.isCutsceneOrLoading)
                        Positioned(
                          bottom: 8,
                          left: 14,
                          right: 14,
                          child: GestureDetector(
                            onTap: widget.controller.skipEscapeCutscene,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE63946),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppDesignTokens.goldenYellow,
                                    width: 1.8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: AppDesignTokens.goldenYellow,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      eng.truckDefense.ally.hasKnifeDrawn
                                          ? 'Giant Boss Escaped! Defend the Truck! (Tap to Skip)'
                                          : 'Shipment Loaded! Watch the Monster Cage! (Tap to Skip)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Destination Arrival celebratory banner
                      if (eng.phase == MazeGamePhase.truckArrived)
                        Positioned(
                          bottom: 8,
                          left: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: widget.controller.skipEscapeCutscene,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppDesignTokens.freshGreen,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.flag_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Truck Reached Destination! Delivery Safe!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 4. IMPROVED ERGONOMIC BOTTOM CONTROLS (Larger & Higher Joystick + Bag + Actions)
                _buildBottomControls(eng, screenW, screenH),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(
    MazeGameEngine eng,
    int levelId,
    String districtName,
    bool reducedMotion,
  ) {
    final secondsLeft = eng.activeDisplayRemainingTime.ceil().clamp(0, 999);
    final mins = secondsLeft ~/ 60;
    final secs = (secondsLeft % 60).toString().padLeft(2, '0');
    final urgency = eng.timerUrgency;
    final isRoadPhase = eng.phase.isRoadBattleView;

    Color timerBg;
    switch (urgency) {
      case TimerUrgency.normal:
        timerBg = isRoadPhase
            ? const Color(0xFF0284C7)
            : AppDesignTokens.timerNormal;
        break;
      case TimerUrgency.warning:
        timerBg = AppDesignTokens.timerWarning;
        break;
      case TimerUrgency.critical:
        timerBg = AppDesignTokens.timerCritical;
        break;
    }

    final pulseScale = (!reducedMotion && urgency == TimerUrgency.critical)
        ? 1.0 + ((eng.elapsedTime * 4).remainder(1.0) < 0.5 ? 0.06 : 0.0)
        : 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: const Border(
          bottom: BorderSide(color: AppDesignTokens.surfaceBorder, width: 1.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppDesignTokens.deepNavy, size: 22),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back to Map',
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LV $levelId • $districtName',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppDesignTokens.deepNavy,
                    ),
                  ),
                  Text(
                    isRoadPhase
                        ? 'Truck Defense • ${eng.truckDefense.boss.type.displayName}'
                        : 'Score: ${eng.liveDeliveredFoodScore}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isRoadPhase
                          ? const Color(0xFFD62828)
                          : const Color(0xFF5A6B7F),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Prominent Countdown Timer Pill
          Transform.scale(
            scale: pulseScale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: timerBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: timerBg.withOpacity(0.32),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '$mins:$secs',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 7),

          // Animated 3-Heart Health Indicator + Optional Shield Badge
          _buildAnimatedHearts(eng, reducedMotion),
          if (eng.hasShield) ...[
            const SizedBox(width: 2),
            const Icon(Icons.shield_rounded,
                size: 17, color: Color(0xFF0EA5E9)),
          ],
          const SizedBox(width: 3),

          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.pause_circle_filled_rounded,
                  color: AppDesignTokens.deepNavy, size: 25),
              onPressed: _openPauseMenu,
              tooltip: 'Pause',
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the 3-heart health display with damage shake and heal pop animations.
  Widget _buildAnimatedHearts(MazeGameEngine eng, bool reducedMotion) {
    final isDamaged = eng.damageFlashTimer > 0;
    final isHealed = eng.healAnimTimer > 0;

    final shakeX = (!reducedMotion && isDamaged)
        ? math.sin(eng.elapsedTime * 55) * 3.0
        : 0.0;
    final healScale = (!reducedMotion && isHealed)
        ? 1.0 + math.sin((eng.healAnimTimer / 0.85) * math.pi) * 0.28
        : 1.0;

    return Transform.translate(
      offset: Offset(shakeX, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: isHealed
              ? AppDesignTokens.freshGreen.withOpacity(0.18)
              : (isDamaged
                  ? AppDesignTokens.timerCritical.withOpacity(0.15)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(eng.maxHealth, (i) {
            final alive = i < eng.health;
            final isNewlyHealedHeart = isHealed && i == eng.health - 1;
            return Transform.scale(
              scale: isNewlyHealedHeart ? healScale : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(
                  alive
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 19,
                  color: alive
                      ? AppDesignTokens.heartRed
                      : const Color(0xFFBCC6D4),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Compact Truck Health, Tire Condition & Destination Route Progress bar shown
  /// during the Full-Screen Road Battle Arena (Sections 8 & 13).
  Widget _buildTruckDefenseHudPanel(MazeGameEngine eng) {
    final td = eng.truckDefense;
    final truck = td.truck;
    final hpRatio = (truck.hp / math.max(1, truck.maxHp)).clamp(0.0, 1.0);
    final hpColor = truck.damageState == TruckDamageState.healthy
        ? AppDesignTokens.freshGreen
        : (truck.damageState == TruckDamageState.damaged
            ? AppDesignTokens.timerWarning
            : AppDesignTokens.timerCritical);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: AppDesignTokens.surfaceWarm,
      child: Row(
        children: [
          // Truck HP Bar + Exact Readout (Truck HP: 100/100)
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping_rounded,
                        size: 14, color: hpColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Truck HP: ${truck.hp}/${truck.maxHp}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppDesignTokens.deepNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (truck.isTireDamaged) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F1C).withOpacity(0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'TIRE!',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: hpRatio,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Destination Route Progress (reflects actual traveled distance!)
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.flag_rounded,
                        size: 13, color: Color(0xFF0284C7)),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Destination Progress: ${truck.progressPercent}%',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppDesignTokens.deepNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: truck.progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0284C7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryProgressPanel(MazeGameEngine eng) {
    final foods = eng.foods;
    final deliveredCount = eng.deliveredFoods.length;
    final deliveredPct = eng.deliveredQuantityPercent;
    final quotaPct = eng.level.minQuotaPercent;
    final quotaMet = deliveredPct >= quotaPct;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: AppDesignTokens.surfaceWarm,
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      size: 15, color: AppDesignTokens.freshGreen),
                  const SizedBox(width: 5),
                  Text(
                    'Delivered $deliveredCount/${foods.length}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: AppDesignTokens.deepNavy,
                    ),
                  ),
                  const SizedBox(width: 7),
                  for (final f in foods)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Opacity(
                        opacity: f.status == FoodStatus.delivered
                            ? 1.0
                            : (f.status == FoodStatus.consumed ? 0.2 : 0.45),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            FoodIllustrationWidget(
                              type: f.type,
                              size: 19,
                              conditionPercent: f.conditionPercent,
                            ),
                            if (f.status == FoodStatus.delivered)
                              const Positioned(
                                right: -1,
                                bottom: -1,
                                child: Icon(Icons.check_circle,
                                    size: 9, color: Color(0xFF2E7D32)),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: quotaMet
                  ? AppDesignTokens.freshGreen.withOpacity(0.18)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: quotaMet
                    ? AppDesignTokens.freshGreen
                    : AppDesignTokens.surfaceBorder,
              ),
            ),
            child: Text(
              'Quota: $deliveredPct% / $quotaPct%',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: quotaMet
                    ? const Color(0xFF2E7D32)
                    : AppDesignTokens.deepNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact floating Hint pill shown ONLY when the player taps the Hint button
  /// (auto-dismisses after ~3 seconds or on manual tap of close).
  Widget _buildOnDemandHintOverlay(MazeGameEngine eng) {
    return Positioned(
      top: 6,
      left: 14,
      right: 14,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppDesignTokens.goldenYellow.withOpacity(0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppDesignTokens.deepNavy.withOpacity(0.2)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_rounded,
                  color: AppDesignTokens.deepNavy, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eng.hintMessage!,
                  style: const TextStyle(
                    color: AppDesignTokens.deepNavy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  eng.dismissHint();
                  setState(() {});
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.close_rounded,
                      color: AppDesignTokens.deepNavy, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ergonomic two-thumb bottom control bar:
  /// - Left: Larger, elevated zero-latency Virtual Joystick
  /// - Center: Compact Courier Bag (+ compact Hint & Retry pills when combat is unlocked)
  /// - Right: Attack + Special + optional Weapon Switch thumb buttons (Level 4+) OR Hint/Retry (Levels 1-3)
  Widget _buildBottomControls(
    MazeGameEngine eng,
    double screenW,
    double screenH,
  ) {
    final carried = eng.carriedFoods;
    final capacity = eng.level.cargoCapacity;
    final combatReady = eng.hasCombatUnlocked;

    final bool isCompact = screenW < 350 || screenH < 640;
    final double joystickSize = isCompact
        ? 102.0
        : (screenW >= 380 && screenH >= 720 ? 126.0 : 116.0);

    final double bottomLift =
        screenH >= 740 ? 30.0 : (screenH >= 640 ? 16.0 : 8.0);

    return Container(
      padding: EdgeInsets.fromLTRB(10, 7, 10, bottomLift),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        border: const Border(
          top: BorderSide(color: AppDesignTokens.surfaceBorder, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppDesignTokens.deepNavy.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT THUMB: Larger, Elevated, Zero-Latency Virtual Joystick
          VirtualJoystick(
            size: joystickSize,
            hapticsEnabled: widget.controller.saveData.hapticsEnabled,
            onChanged: (dx, dy) => eng.setJoystickInput(dx, dy),
          ),
          const SizedBox(width: 8),

          // CENTER: Courier Bag (Maze Stage) OR Boss & Ally Status Card (Truck Defense Stage)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eng.phase.isRoadBattleView)
                  _buildRoadDefenseCenterCard(eng)
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.warmCream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: eng.isCargoFull
                            ? AppDesignTokens.coralPrimary
                            : AppDesignTokens.surfaceBorder,
                        width: 1.6,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                eng.isCargoFull ? 'BAG FULL!' : 'COURIER BAG',
                                style: TextStyle(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w900,
                                  color: eng.isCargoFull
                                      ? AppDesignTokens.coralPrimary
                                      : const Color(0xFF5A6B7F),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${carried.length}/$capacity',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppDesignTokens.deepNavy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(capacity, (idx) {
                            final item =
                                idx < carried.length ? carried[idx] : null;
                            return _buildCargoSlot(
                              item,
                              compact:
                                  isCompact || capacity >= 3 || combatReady,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                if (combatReady) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: _miniPillButton(
                          icon: Icons.lightbulb_rounded,
                          label: 'Hint',
                          bg: AppDesignTokens.goldenYellow,
                          onTap: widget.controller.requestHint,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: _miniPillButton(
                          icon: Icons.refresh_rounded,
                          label: 'Retry',
                          bg: AppDesignTokens.surfaceWarm,
                          onTap: _restartLevel,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // RIGHT THUMB: Combat Attack + Special + Switch (Levels 4+) or Hint/Retry (Levels 1-3)
          if (combatReady)
            _buildCombatButtons(eng, isCompact)
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roundControlButton(
                  icon: Icons.lightbulb_rounded,
                  label: 'Hint',
                  color: AppDesignTokens.goldenYellow,
                  iconColor: AppDesignTokens.deepNavy,
                  onTap: widget.controller.requestHint,
                ),
                const SizedBox(height: 8),
                _roundControlButton(
                  icon: Icons.refresh_rounded,
                  label: 'Retry',
                  color: AppDesignTokens.surfaceWarm,
                  iconColor: AppDesignTokens.deepNavy,
                  onTap: _restartLevel,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Ergonomic right-thumb Combat Cluster: Main Attack button, Special Ability button,
  /// and compact weapon switch toggles when multiple weapons/abilities are unlocked.
  Widget _buildRoadDefenseCenterCard(MazeGameEngine eng) {
    final td = eng.truckDefense;
    final boss = td.boss;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppDesignTokens.warmCream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: boss.isDefeated
              ? AppDesignTokens.freshGreen
              : const Color(0xFFE63946).withOpacity(0.55),
          width: 1.6,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  boss.isDefeated ? 'BOSS DEFEATED!' : boss.type.displayName,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: boss.isDefeated
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFD62828),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${boss.hp}/${boss.maxHp}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: AppDesignTokens.deepNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: boss.hpRatio,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                boss.isDefeated
                    ? AppDesignTokens.freshGreen
                    : const Color(0xFFE63946),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  size: 12, color: Color(0xFF0284C7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  td.ally.hasKnifeDrawn
                      ? 'Ally Guard Active'
                      : 'Ally Waiting',
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombatButtons(MazeGameEngine eng, bool isCompact) {
    final primary = eng.activePrimaryWeapon;
    final special = eng.activeSpecialWeapon;
    final primaryCd = eng.cooldownRatioFor(primary);
    final primaryAmmo = eng.ammoFor(primary);
    final canSwitchPrimary = eng.unlockedPrimaryWeapons.length > 1;
    final canSwitchSpecial = eng.unlockedSpecialAbilities.length > 1;

    final attackSize = isCompact ? 58.0 : 66.0;
    final specialSize = isCompact ? 42.0 : 46.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Attack Thumb Button (instant pointer-down fire!)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Listener(
              onPointerDown: (_) => widget.controller.triggerPrimaryAttack(),
              child: Container(
                width: attackSize,
                height: attackSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: primaryCd > 0
                        ? const [Color(0xFF94A3B8), Color(0xFF64748B)]
                        : [
                            Color(primary.colorHex),
                            Color(primary.colorHex).withOpacity(0.82),
                          ],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Color(primary.colorHex).withOpacity(0.38),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (primaryCd > 0)
                      SizedBox(
                        width: attackSize - 6,
                        height: attackSize - 6,
                        child: CircularProgressIndicator(
                          value: 1.0 - primaryCd,
                          strokeWidth: 3.5,
                          color: Colors.white70,
                        ),
                      ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_iconForWeapon(primary),
                            color: Colors.white, size: isCompact ? 21 : 24),
                        Text(
                          primary.startingAmmo > 0
                              ? '$primaryAmmo'
                              : 'ATK',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (canSwitchPrimary) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.controller.cyclePrimaryWeapon,
                child: Container(
                  width: 24,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surfaceWarm,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppDesignTokens.surfaceBorder),
                  ),
                  child: const Icon(Icons.swap_vert_rounded,
                      size: 16, color: AppDesignTokens.deepNavy),
                ),
              ),
            ],
          ],
        ),
        if (special != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Listener(
                onPointerDown: (_) => widget.controller.triggerSpecialAttack(),
                child: Container(
                  width: specialSize,
                  height: specialSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: eng.cooldownRatioFor(special) > 0
                        ? const Color(0xFF94A3B8)
                        : Color(special.colorHex),
                    border: Border.all(color: Colors.white, width: 2.0),
                    boxShadow: [
                      BoxShadow(
                        color: Color(special.colorHex).withOpacity(0.32),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_iconForWeapon(special),
                          color: Colors.white, size: 17),
                      Text(
                        special.startingAmmo > 0
                            ? '${eng.ammoFor(special)}'
                            : 'SP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (canSwitchSpecial) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: widget.controller.cycleSpecialWeapon,
                  child: Container(
                    width: 24,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surfaceWarm,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppDesignTokens.surfaceBorder),
                    ),
                    child: const Icon(Icons.sync_rounded,
                        size: 14, color: AppDesignTokens.deepNavy),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  IconData _iconForWeapon(WeaponType w) {
    switch (w) {
      case WeaponType.melee:
        return Icons.sports_martial_arts_rounded;
      case WeaponType.bow:
        return Icons.gps_fixed_rounded;
      case WeaponType.energyBlaster:
        return Icons.bolt_rounded;
      case WeaponType.freezeOrb:
        return Icons.ac_unit_rounded;
      case WeaponType.foodDecoy:
        return Icons.bakery_dining_rounded;
      case WeaponType.stunPulse:
        return Icons.radar_rounded;
    }
  }

  Widget _miniPillButton({
    required IconData icon,
    required String label,
    required Color bg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppDesignTokens.surfaceBorder, width: 1.2),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: AppDesignTokens.deepNavy),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppDesignTokens.deepNavy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCargoSlot(FoodItem? item, {bool compact = false}) {
    final slotW = compact ? 40.0 : 48.0;
    final slotH = compact ? 52.0 : 58.0;

    if (item == null) {
      return Container(
        width: slotW,
        height: slotH,
        decoration: BoxDecoration(
          color: AppDesignTokens.cellDepression.withOpacity(0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppDesignTokens.surfaceBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: const Icon(
          Icons.shopping_basket_outlined,
          size: 18,
          color: Color(0xFFA99B87),
        ),
      );
    }

    final pct = item.conditionPercent;
    final barColor = pct >= 75
        ? AppDesignTokens.freshGreen
        : (pct >= 40
            ? AppDesignTokens.timerWarning
            : AppDesignTokens.timerCritical);

    return Container(
      width: slotW,
      height: slotH,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor, width: 1.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FoodIllustrationWidget(
            type: item.type,
            size: compact ? 20 : 24,
            conditionPercent: pct,
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 4,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$pct%',
              style: TextStyle(
                fontSize: 9,
                height: 1.0,
                fontWeight: FontWeight.w900,
                color: barColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppDesignTokens.surfaceBorder, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseDialog extends StatelessWidget {
  final MazeGameController controller;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onLevelMap;

  const _PauseDialog({
    required this.controller,
    required this.onResume,
    required this.onRestart,
    required this.onLevelMap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final save = controller.saveData;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppDesignTokens.warmCream,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppDesignTokens.deepNavy, width: 2.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Game Paused',
                  textAlign: TextAlign.center,
                  style: AppDesignTokens.titleLarge,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Resume',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignTokens.freshGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Restart Level',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppDesignTokens.deepNavy,
                    side: const BorderSide(
                        color: AppDesignTokens.surfaceBorder, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignTokens.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        dense: true,
                        title: const Text('Sound Effects',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5)),
                        value: save.soundEnabled,
                        activeColor: AppDesignTokens.coralPrimary,
                        onChanged: controller.setSoundEnabled,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Music',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5)),
                        value: save.musicEnabled,
                        activeColor: AppDesignTokens.coralPrimary,
                        onChanged: controller.setMusicEnabled,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onLevelMap,
                  icon: const Icon(Icons.map_rounded),
                  label: const Text(
                    'Return to Level Map',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

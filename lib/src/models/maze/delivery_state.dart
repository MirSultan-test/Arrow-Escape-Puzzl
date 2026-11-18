import 'food_item.dart';

/// Authoritative top-level phase of an active Food Maze Adventure V3.3 level run:
/// MAZE_PLAYING -> FOOD_LOADING_COMPLETE -> CAGE_ESCAPE_CUTSCENE
/// -> TRUCK_DEFENSE_PLAYING -> TRUCK_ARRIVED / TRUCK_DESTROYED -> VICTORY / DEFEAT
enum MazeGamePhase {
  playing,
  paused,
  foodLoadingComplete,
  cageEscapeCutscene,
  truckDefensePlaying,
  truckArrived,
  truckDestroyed,
  victory,
  defeat;

  bool get isRoadBattleView =>
      this == MazeGamePhase.truckDefensePlaying ||
      this == MazeGamePhase.truckArrived ||
      this == MazeGamePhase.truckDestroyed;

  bool get isCutsceneOrLoading =>
      this == MazeGamePhase.foodLoadingComplete ||
      this == MazeGamePhase.cageEscapeCutscene;

  bool get isTerminal =>
      this == MazeGamePhase.victory || this == MazeGamePhase.defeat;
}

/// Specific, player-facing cause of defeat.
enum DefeatReason {
  none,
  timeExpired,
  healthDepleted,
  insufficientFood,
  truckDestroyed,
  defenseTimeExpired;

  String get title {
    switch (this) {
      case DefeatReason.none:
        return '';
      case DefeatReason.timeExpired:
        return 'Time Ran Out!';
      case DefeatReason.healthDepleted:
        return 'Courier Defeated!';
      case DefeatReason.insufficientFood:
        return 'Too Much Food Eaten!';
      case DefeatReason.truckDestroyed:
        return 'Delivery Failed — Truck Stopped!';
      case DefeatReason.defenseTimeExpired:
        return 'Delivery Failed — Truck Stopped!';
    }
  }

  String get message {
    switch (this) {
      case DefeatReason.none:
        return '';
      case DefeatReason.timeExpired:
        return 'The delivery truck had to leave before the shipment was ready.';
      case DefeatReason.healthDepleted:
        return 'Monsters knocked out your courier hearts.';
      case DefeatReason.insufficientFood:
        return 'Not enough edible food remains to meet this level\'s delivery quota.';
      case DefeatReason.truckDestroyed:
        return 'The escaped giant monster stopped the delivery truck before it could reach the destination.';
      case DefeatReason.defenseTimeExpired:
        return 'The truck could not reach the delivery station before time ran out.';
    }
  }
}

/// Timer visual urgency levels.
enum TimerUrgency {
  normal,
  warning,
  critical,
}

/// Animated state of the Dock Worker (peaceful before escape; knife fighter after escape!).
enum CollectorAnimState {
  waiting,
  receiving,
  carryingToTruck,
  surprised,
  combatReady,
  slashing,
  celebrating,
}

/// Animated state of the delivery truck at the dock and along the winding road.
enum TruckAnimState {
  waiting,
  loading,
  closingDoors,
  engineStart,
  drivingOnRoad,
  arrived,
  destroyed,
}

/// Floating popup feedback text rendered over the maze or road arena world.
class FloatingPopup {
  final String text;
  final double worldX;
  final double worldY;
  final int colorHex;
  double age;
  final double lifetime;

  FloatingPopup({
    required this.text,
    required this.worldX,
    required this.worldY,
    required this.colorHex,
    this.age = 0.0,
    this.lifetime = 1.15,
  });

  double get progress => (age / lifetime).clamp(0.0, 1.0);
  bool get isExpired => age >= lifetime;
}

/// Transparent scoring breakdown displayed upon victory (V3.3).
/// Total Score = Food Delivery Score + Maze Time Bonus + Truck Survival Bonus + Defense Performance Bonus (+ Courier Hearts).
class MazeScoreBreakdown {
  final int deliveredFoodScore;
  final int timeBonus;
  final int survivalBonus;
  final int truckSurvivalBonus;
  final int defensePerformanceBonus;
  final int totalScore;
  final int coinsEarned;
  final int starsEarned;
  final int deliveredPercent;
  final int remainingSeconds;
  final int remainingHealth;
  final int remainingTruckHp;
  final bool bossDefeated;
  final List<FoodItem> foodResults;

  const MazeScoreBreakdown({
    required this.deliveredFoodScore,
    required this.timeBonus,
    required this.survivalBonus,
    this.truckSurvivalBonus = 0,
    this.defensePerformanceBonus = 0,
    required this.totalScore,
    required this.coinsEarned,
    required this.starsEarned,
    required this.deliveredPercent,
    required this.remainingSeconds,
    required this.remainingHealth,
    this.remainingTruckHp = 100,
    this.bossDefeated = false,
    required this.foodResults,
  });
}

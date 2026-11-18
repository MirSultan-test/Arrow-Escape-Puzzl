import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/maze/delivery_state.dart';
import '../models/maze/food_item.dart';
import '../models/maze/maze_level.dart';
import '../rendering/maze/food_illustrator.dart';

/// Celebratory Level Completion overlay showing animated stars, transparent
/// score breakdown, coins earned, and per-item food condition report.
class LevelCompleteDialog extends StatefulWidget {
  final MazeLevel level;
  final MazeScoreBreakdown breakdown;
  final bool hasNextLevel;
  final int? unlockedPostcardId;
  final VoidCallback onNextLevel;
  final VoidCallback onReplay;
  final VoidCallback onLevelMap;

  const LevelCompleteDialog({
    super.key,
    required this.level,
    required this.breakdown,
    required this.hasNextLevel,
    this.unlockedPostcardId,
    required this.onNextLevel,
    required this.onReplay,
    required this.onLevelMap,
  });

  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _starAnim;

  @override
  void initState() {
    super.initState();
    _starAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _starAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.breakdown;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppDesignTokens.warmCream,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppDesignTokens.freshGreen, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppDesignTokens.deepNavy.withOpacity(0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.freshGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Delivery Complete!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Level ${widget.level.id} • ${widget.level.title}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8F9ED),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Animated 1-3 Stars
                AnimatedBuilder(
                  animation: _starAnim,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (idx) {
                        final earned = idx < b.starsEarned;
                        final delay = idx * 0.2;
                        final localT = ((_starAnim.value - delay) / 0.6)
                            .clamp(0.0, 1.0);
                        final scale = earned
                            ? Curves.elasticOut.transform(localT)
                            : 1.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Transform.scale(
                            scale: scale,
                            child: Icon(
                              earned
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: idx == 1 ? 48 : 38,
                              color: earned
                                  ? AppDesignTokens.goldenYellow
                                  : const Color(0xFFD5C8B5),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Score & Coins Summary Pills
                Row(
                  children: [
                    Expanded(
                      child: _metricTile(
                        label: 'TOTAL SCORE',
                        value: '${b.totalScore}',
                        icon: Icons.emoji_events_rounded,
                        color: AppDesignTokens.coralPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricTile(
                        label: 'COINS EARNED',
                        value: '+${b.coinsEarned}',
                        icon: Icons.monetization_on_rounded,
                        color: const Color(0xFFE09F1F),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Transparent Score Breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignTokens.surfaceBorder),
                  ),
                  child: Column(
                    children: [
                      _scoreLine('Food Delivered (${b.deliveredPercent}%)',
                          '+${b.deliveredFoodScore}'),
                      const SizedBox(height: 4),
                      _scoreLine('Maze Time Bonus (${b.remainingSeconds}s left)',
                          '+${b.timeBonus}'),
                      const SizedBox(height: 4),
                      _scoreLine('Truck Survival Bonus (${b.remainingTruckHp} HP)',
                          '+${b.truckSurvivalBonus}'),
                      if (b.defensePerformanceBonus > 0) ...[
                        const SizedBox(height: 4),
                        _scoreLine(
                          b.bossDefeated
                              ? 'Defense Bonus (Boss Defeated!)'
                              : 'Defense Performance Bonus',
                          '+${b.defensePerformanceBonus}',
                        ),
                      ],
                      const SizedBox(height: 4),
                      _scoreLine('Courier Hearts (${b.remainingHealth})',
                          '+${b.survivalBonus}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Per-Food Condition Breakdown
                const Text(
                  'FOOD CONDITION REPORT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF6B7B8F),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignTokens.surfaceBorder),
                  ),
                  child: Column(
                    children: b.foodResults.map(_buildFoodRow).toList(),
                  ),
                ),

                if (widget.unlockedPostcardId != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppDesignTokens.goldenYellow.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppDesignTokens.goldenYellow),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.markunread_mailbox_rounded,
                            color: AppDesignTokens.coralPrimary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'New District Postcard Unlocked!',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: AppDesignTokens.deepNavy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Primary Action: Next Level
                if (widget.hasNextLevel)
                  ElevatedButton.icon(
                    onPressed: widget.onNextLevel,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                    label: const Text(
                      'Next Level',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.coralPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onReplay,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Replay',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppDesignTokens.deepNavy,
                          side: const BorderSide(
                              color: AppDesignTokens.surfaceBorder, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onLevelMap,
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: const Text('Level Map',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppDesignTokens.deepNavy,
                          side: const BorderSide(
                              color: AppDesignTokens.surfaceBorder, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.45), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7B8F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A6B7F),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppDesignTokens.deepNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildFoodRow(FoodItem f) {
    final bool consumed = f.status == FoodStatus.consumed || f.conditionPercent == 0;
    final String statusText;
    final Color statusColor;
    if (consumed) {
      statusText = 'Completely eaten';
      statusColor = const Color(0xFFD62828);
    } else if (f.conditionPercent == 100) {
      statusText = '100% delivered';
      statusColor = const Color(0xFF2E7D32);
    } else {
      statusText = '${f.conditionPercent}% delivered, ${f.eatenPercent}% eaten';
      statusColor = const Color(0xFFD97706);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Opacity(
            opacity: consumed ? 0.35 : 1.0,
            child: FoodIllustrationWidget(
              type: f.type,
              size: 26,
              conditionPercent: consumed ? 25 : f.conditionPercent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.type.displayName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppDesignTokens.deepNavy,
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${f.earnedPoints}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: consumed ? Colors.grey : AppDesignTokens.deepNavy,
            ),
          ),
        ],
      ),
    );
  }
}

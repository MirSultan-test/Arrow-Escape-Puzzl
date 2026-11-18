import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../controllers/maze_game_controller.dart';
import '../models/maze/maze_level.dart';
import '../rendering/maze/home_diorama.dart';
import 'gameplay_screen.dart';
import 'level_select_screen.dart';
import 'postcards_screen.dart';
import 'settings_screen.dart';

/// Illustrated Home Screen for Parcel Escape: Food Maze Adventure.
class HomeScreen extends StatelessWidget {
  final MazeGameController controller;

  const HomeScreen({super.key, required this.controller});

  void _startCurrentLevel(BuildContext context) {
    controller.audioController.playTap();
    final targetId = controller.saveData.mazeCurrentLevelId
        .clamp(1, controller.levels.isNotEmpty ? controller.levels.length : 50);
    controller.selectLevel(targetId);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameplayScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final save = controller.saveData;
        final currentLevelId = save.mazeCurrentLevelId;
        final district = MazeDistrictInfo.forLevel(currentLevelId);

        return Scaffold(
          backgroundColor: AppDesignTokens.warmCream,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Bar: Coins, Stars, Settings
                  Row(
                    children: [
                      _statPill(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFE09F1F),
                        text: '${controller.totalStars}/150',
                      ),
                      const SizedBox(width: 8),
                      _statPill(
                        icon: Icons.monetization_on_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        text: '${controller.totalCoins}',
                      ),
                      const Spacer(),
                      _iconActionButton(
                        icon: Icons.settings_rounded,
                        tooltip: 'Settings',
                        onTap: () {
                          controller.audioController.playTap();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SettingsScreen(controller: controller),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Recognizable Game Title & Logo Badge
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppDesignTokens.freshGreen.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppDesignTokens.freshGreen),
                        ),
                        child: const Text(
                          'FOOD MAZE DELIVERY ADVENTURE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'PARCEL ESCAPE',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: AppDesignTokens.deepNavy,
                            letterSpacing: 1.0,
                            height: 1.05,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Collect fresh food • Outsmart monsters • Beat the clock!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5A6B7F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Illustrated Miniature Food-Delivery World Diorama
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppDesignTokens.surfaceBorder, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppDesignTokens.deepNavy.withOpacity(0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: HomeFoodDiorama(
                        reducedMotion: save.reducedMotion,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Current District & Level Progress Strip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppDesignTokens.surfaceBorder, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color(district.wallTopHex).withOpacity(0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.local_shipping_rounded,
                            color: Color(district.wallTopHex),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'District ${district.id}: ${district.name}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppDesignTokens.deepNavy,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${controller.completedCount} of 50 deliveries completed',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5A6B7F),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.warmCream,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'LV $currentLevelId',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppDesignTokens.coralPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Prominent Primary PLAY / CONTINUE Button
                  ElevatedButton.icon(
                    onPressed: () => _startCurrentLevel(context),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: Text(
                      controller.completedCount > 0
                          ? 'Continue Level $currentLevelId'
                          : 'Play Level 1',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesignTokens.coralPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 5,
                      shadowColor:
                          AppDesignTokens.coralPrimary.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary Navigation Row: World Map & Postcards
                  Row(
                    children: [
                      Expanded(
                        child: _secondaryButton(
                          icon: Icons.map_rounded,
                          label: 'Level Map',
                          color: AppDesignTokens.freshGreen,
                          onTap: () {
                            controller.audioController.playTap();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LevelSelectScreen(controller: controller),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _secondaryButton(
                          icon: Icons.markunread_mailbox_rounded,
                          label: 'Postcards',
                          color: AppDesignTokens.deepNavy,
                          onTap: () {
                            controller.audioController.playTap();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PostcardsScreen(controller: controller),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statPill({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignTokens.surfaceBorder, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: iconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppDesignTokens.deepNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppDesignTokens.surfaceBorder, width: 1.5),
          ),
          child: Icon(icon, color: AppDesignTokens.deepNavy, size: 22),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppDesignTokens.surfaceBorder, width: 1.8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../controllers/maze_game_controller.dart';

/// Modal bottom sheet presenting privacy disclosures, neutral age declaration, and offline notice.
class PrivacySheet extends StatelessWidget {
  final MazeGameController controller;

  const PrivacySheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, MazeGameController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PrivacySheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final save = controller.saveData;
        return Container(
          padding: EdgeInsets.only(
            top: 22,
            left: 22,
            right: 22,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: const BoxDecoration(
            color: AppDesignTokens.warmCream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppDesignTokens.surfaceBorder,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: AppDesignTokens.freshGreen,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Privacy & Data Transparency',
                        style: AppDesignTokens.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Parcel Escape: Food Maze Adventure is designed offline-first. Your campaign progression, star ratings, coins, and audio preferences are stored locally on your device.',
                  style: TextStyle(fontSize: 13.5, height: 1.45, color: AppDesignTokens.deepNavy),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surfaceWarm,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignTokens.surfaceBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Advertising SDK Disclosure',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: AppDesignTokens.deepNavy,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Advertising is DISABLED by default in this build. Retrying levels, using hints, and completing all 50 levels never require watching ads or making purchases.',
                        style: TextStyle(fontSize: 12, height: 1.4, color: AppDesignTokens.deepNavy),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Audience / Neutral Age Declaration:',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: AppDesignTokens.deepNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AgeChip(
                      label: 'General / Adult',
                      selected: save.userAgeCategory == 'neutral_adult',
                      onSelected: () =>
                          controller.setAgeGateCategory('neutral_adult'),
                    ),
                    _AgeChip(
                      label: 'Under 13 / Family',
                      selected: save.userAgeCategory == 'child',
                      onSelected: () => controller.setAgeGateCategory('child'),
                    ),
                    _AgeChip(
                      label: 'Not Declared',
                      selected: save.userAgeCategory == 'unknown',
                      onSelected: () => controller.setAgeGateCategory('unknown'),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignTokens.coralPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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

class _AgeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _AgeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppDesignTokens.freshGreen,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppDesignTokens.deepNavy,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
    );
  }
}

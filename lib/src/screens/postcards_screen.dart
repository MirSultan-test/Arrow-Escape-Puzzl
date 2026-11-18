import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../controllers/maze_game_controller.dart';
import '../models/district_milestone.dart';

/// Collectible postcards awarded upon mastering each Food Maze district.
class PostcardsScreen extends StatelessWidget {
  final MazeGameController controller;

  const PostcardsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final save = controller.saveData;
        return Scaffold(
          backgroundColor: AppDesignTokens.warmCream,
          appBar: AppBar(
            backgroundColor: AppDesignTokens.warmCream,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppDesignTokens.deepNavy),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Delivery Postcards',
                style: AppDesignTokens.titleMedium),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppDesignTokens.surfaceBorder, width: 1.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.markunread_mailbox_rounded,
                        color: AppDesignTokens.coralPrimary,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'District Souvenir Collection',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppDesignTokens.deepNavy,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Finish the finale level (10, 20, 30, 40, 50) of each district to unlock its illustrated postcard.',
                              style: TextStyle(
                                  fontSize: 11.5, color: Color(0xFF5A6B7F)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (final card in DistrictPostcard.all)
                  _buildCard(
                    card,
                    save.mazeUnlockedPostcards.contains(card.districtId) ||
                        save.mazeCompletedLevels.contains(card.levelRequired),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(DistrictPostcard card, bool unlocked) {
    if (!unlocked) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesignTokens.surfaceWarm,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignTokens.surfaceBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppDesignTokens.deepNavy.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: Color(0xFF7B8A9C)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.districtName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7B8F),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Complete Level ${card.levelRequired} to unlock',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8B99AA)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: card.stampColor.withOpacity(0.55), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppDesignTokens.deepNavy.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: card.stampColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          card.districtName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: card.stampColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppDesignTokens.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        card.postmarkDate,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7B8F),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 64,
                  decoration: BoxDecoration(
                    color: card.stampColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: card.stampColor, width: 2),
                  ),
                  child: Icon(card.stampIcon, color: card.stampColor, size: 30),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              '“${card.note}”',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.45,
                color: Color(0xFF42526B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../controllers/maze_game_controller.dart';
import 'privacy_sheet.dart';

/// Settings screen for configuring SFX, Music, Haptics, Accessibility, Privacy, and Progress Reset.
class SettingsScreen extends StatelessWidget {
  final MazeGameController controller;

  const SettingsScreen({super.key, required this.controller});

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
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppDesignTokens.deepNavy),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Settings', style: AppDesignTokens.titleMedium),
            centerTitle: true,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              children: [
                _buildSectionHeader('Audio & Feedback'),
                _buildCard(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Sound Effects',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.deepNavy),
                      ),
                      subtitle: const Text(
                          'Fruit pickups, monster alerts, deliveries & truck horn'),
                      value: save.soundEnabled,
                      activeColor: AppDesignTokens.coralPrimary,
                      onChanged: (val) => controller.setSoundEnabled(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text(
                        'Background Music',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.deepNavy),
                      ),
                      subtitle: const Text(
                          'Cheerful adventure marimba melody during deliveries'),
                      value: save.musicEnabled,
                      activeColor: AppDesignTokens.coralPrimary,
                      onChanged: (val) => controller.setMusicEnabled(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text(
                        'Haptic Feedback',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.deepNavy),
                      ),
                      subtitle: const Text(
                          'Tactile vibration on pickups, bites, and deliveries'),
                      value: save.hapticsEnabled,
                      activeColor: AppDesignTokens.coralPrimary,
                      onChanged: (val) => controller.setHapticsEnabled(val),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionHeader('Controls & Accessibility'),
                _buildCard(
                  children: [
                    SwitchListTile(
                      title: const Text(
                        'Auto-Target Enemies',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.deepNavy),
                      ),
                      subtitle: const Text(
                          'Automatically aim ranged attacks at the nearest visible monster'),
                      value: save.autoTargetEnabled,
                      activeColor: AppDesignTokens.coralPrimary,
                      onChanged: (val) => controller.setAutoTargetEnabled(val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text(
                        'Reduced Motion',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.deepNavy),
                      ),
                      subtitle: const Text(
                          'Reduces idle bobbing, diorama loops, and screen pulses'),
                      value: save.reducedMotion,
                      activeColor: AppDesignTokens.coralPrimary,
                      onChanged: (val) => controller.setReducedMotion(val),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionHeader('Privacy & Compliance'),
                _buildCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.shield_outlined,
                          color: AppDesignTokens.freshGreen),
                      title: const Text(
                        'Privacy Notice & Settings',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppDesignTokens.deepNavy),
                      ),
                      subtitle: const Text(
                          'Offline data policy & neutral age declaration'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => PrivacySheet.show(context, controller),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildSectionHeader('Data Management'),
                _buildCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.restart_alt_rounded,
                          color: Color(0xFFD62828)),
                      title: const Text(
                        'Reset Campaign Progress',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD62828)),
                      ),
                      subtitle: const Text(
                          'Resets levels, stars, and coins while keeping settings & privacy'),
                      onTap: () => _confirmReset(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: Color(0xFF6B7B8F),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppDesignTokens.surfaceBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppDesignTokens.deepNavy.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignTokens.warmCream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset All Progress?',
            style: AppDesignTokens.titleMedium),
        content: const Text(
          'This will clear completed maze levels, stars, and coins, returning you to Level 1. Your sound, music, and privacy settings will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.resetProgress();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Campaign progress reset to Level 1.'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

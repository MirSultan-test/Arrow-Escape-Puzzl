import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../engine/puzzle_engine.dart';
import '../models/board_theme.dart';

/// Interactive Delivery Truck dock widget showing truck cargo slots, needed symbols, and departure state.
class DeliveryTruckWidget extends StatelessWidget {
  final PuzzleEngine engine;
  final BoardTheme theme;
  final bool isTruckDeparting;

  const DeliveryTruckWidget({
    super.key,
    required this.engine,
    required this.theme,
    this.isTruckDeparting = false,
  });

  @override
  Widget build(BuildContext context) {
    final truckIndex = engine.currentTruckIndex;
    final totalTrucks = engine.totalTrucks;
    final capacity = engine.currentTruckCapacity;
    final loaded = engine.currentTruckLoadedCount;
    final manifestSlice = engine.currentTruckManifest;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.boardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.boardBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      size: 16,
                      color: AppDesignTokens.coralPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'TRUCK ${truckIndex + 1} OF $totalTrucks',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: AppDesignTokens.deepInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: loaded == capacity
                        ? AppDesignTokens.tealSecondary.withOpacity(0.18)
                        : AppDesignTokens.coralPrimary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    loaded == capacity ? 'READY TO DEPART' : '$loaded / $capacity CARGO LOADED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: loaded == capacity ? AppDesignTokens.tealSecondary : AppDesignTokens.coralPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Miniature Delivery Truck Dock Representation
          AnimatedSlide(
            offset: isTruckDeparting ? const Offset(1.2, 0.0) : Offset.zero,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppDesignTokens.surfaceWarm,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppDesignTokens.surfaceBorder),
              ),
              child: Row(
                children: [
                  // Cute Delivery Van Cabin
                  _buildTruckCabin(),
                  const SizedBox(width: 8),

                  // Cargo Compartments
                  Expanded(
                    child: Row(
                      children: List.generate(capacity, (index) {
                        final isLoaded = index < loaded;
                        final isNext = index == loaded;
                        final symbol = index < manifestSlice.length ? manifestSlice[index] : 'star';

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _buildCargoSlot(
                              isLoaded: isLoaded,
                              isNext: isNext,
                              symbol: symbol,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTruckCabin() {
    return Container(
      width: 44,
      height: 40,
      decoration: BoxDecoration(
        color: AppDesignTokens.coralPrimary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x20FF6F61),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Positioned(
            bottom: 3,
            child: Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppDesignTokens.deepInk,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCargoSlot({
    required bool isLoaded,
    required bool isNext,
    required String symbol,
  }) {
    Color borderColor = AppDesignTokens.surfaceBorder;
    Color bgColor = Colors.transparent;

    if (isLoaded) {
      borderColor = AppDesignTokens.tealSecondary;
      bgColor = AppDesignTokens.tealSecondary.withOpacity(0.15);
    } else if (isNext) {
      borderColor = AppDesignTokens.goldenYellow;
      bgColor = AppDesignTokens.goldenYellow.withOpacity(0.18);
    }

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isNext ? 2.0 : 1.0,
        ),
      ),
      child: Center(
        child: isLoaded
            ? const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppDesignTokens.tealSecondary,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSymbolIcon(symbol, isNext),
                  if (isNext)
                    const Text(
                      'NEXT',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: AppDesignTokens.deepInk,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildSymbolIcon(String symbol, bool isTarget) {
    IconData icon;
    Color color;

    switch (symbol.toLowerCase()) {
      case 'star':
        icon = Icons.star_rounded;
        color = AppDesignTokens.goldenYellow;
        break;
      case 'moon':
        icon = Icons.nightlight_round;
        color = AppDesignTokens.tealSecondary;
        break;
      case 'sun':
        icon = Icons.wb_sunny_rounded;
        color = AppDesignTokens.coralPrimary;
        break;
      case 'clover':
        icon = Icons.eco_rounded;
        color = const Color(0xFF4CAF50);
        break;
      case 'heart':
        icon = Icons.favorite_rounded;
        color = const Color(0xFFE91E63);
        break;
      case 'diamond':
        icon = Icons.diamond_rounded;
        color = const Color(0xFF2196F3);
        break;
      default:
        icon = Icons.circle_rounded;
        color = AppDesignTokens.deepInk;
    }

    return Icon(
      icon,
      size: isTarget ? 16 : 13,
      color: isTarget ? color : color.withOpacity(0.5),
    );
  }
}

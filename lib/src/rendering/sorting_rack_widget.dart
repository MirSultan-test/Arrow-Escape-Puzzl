import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../engine/puzzle_engine.dart';
import '../models/board_theme.dart';
import '../models/direction.dart';
import '../models/parcel.dart';

/// Interactive Sorting Rack widget displaying buffered parcels between the board and delivery trucks.
class SortingRackWidget extends StatelessWidget {
  final PuzzleEngine engine;
  final BoardTheme theme;
  final String? animatingRackParcelId;
  final String? highlightedHintParcelId;
  final String? manifestMismatchParcelId;
  final void Function(String parcelId) onRackParcelTapped;

  const SortingRackWidget({
    super.key,
    required this.engine,
    required this.theme,
    this.animatingRackParcelId,
    this.highlightedHintParcelId,
    this.manifestMismatchParcelId,
    required this.onRackParcelTapped,
  });

  @override
  Widget build(BuildContext context) {
    final rack = engine.rack;
    final capacity = engine.rackCapacity;
    final isFull = engine.isRackFull;
    final nextSymbol = engine.nextRequiredSymbol;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.boardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFull ? AppDesignTokens.coralPrimary : theme.boardBorder,
          width: isFull ? 2.0 : 1.5,
        ),
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
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 14,
                      color: AppDesignTokens.deepInk,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SORTING RACK',
                      style: TextStyle(
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
                    color: isFull
                        ? AppDesignTokens.coralPrimary.withOpacity(0.15)
                        : AppDesignTokens.tealSecondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isFull ? 'RACK FULL (${rack.length}/$capacity)' : '${rack.length} / $capacity SLOTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isFull ? AppDesignTokens.coralPrimary : AppDesignTokens.deepInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Slots Row
          Row(
            children: List.generate(capacity, (index) {
              final isOccupied = index < rack.length;
              final parcel = isOccupied ? rack[index] : null;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == capacity - 1 ? 0 : 4,
                  ),
                  child: parcel != null
                      ? _buildOccupiedSlot(context, parcel, nextSymbol)
                      : _buildEmptySlot(index + 1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySlot(int slotNumber) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppDesignTokens.warmPaper.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.boardBorder.withOpacity(0.6),
          style: BorderStyle.solid,
          width: 1.2,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: AppDesignTokens.deepInk.withOpacity(0.3),
            ),
            const SizedBox(height: 2),
            Text(
              'SLOT $slotNumber',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.deepInk.withOpacity(0.4),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupiedSlot(BuildContext context, Parcel parcel, String? nextRequiredSymbol) {
    final matches = nextRequiredSymbol == null || parcel.manifestSymbol == nextRequiredSymbol;
    final isHinted = highlightedHintParcelId == parcel.id;
    final isMismatch = manifestMismatchParcelId == parcel.id;
    final isAnimating = animatingRackParcelId == parcel.id;

    Color borderColor = theme.boardBorder;
    if (isMismatch) {
      borderColor = AppDesignTokens.coralPrimary;
    } else if (isHinted) {
      borderColor = AppDesignTokens.goldenYellow;
    } else if (matches) {
      borderColor = AppDesignTokens.tealSecondary;
    }

    return GestureDetector(
      onTap: () => onRackParcelTapped(parcel.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          color: matches
              ? AppDesignTokens.tealSecondary.withOpacity(0.12)
              : AppDesignTokens.surfaceWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: (matches || isHinted || isMismatch) ? 2.0 : 1.5,
          ),
          boxShadow: matches
              ? [
                  BoxShadow(
                    color: AppDesignTokens.tealSecondary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Direction Arrow Icon
                Icon(
                  _getDirectionIcon(parcel.direction),
                  size: 20,
                  color: AppDesignTokens.deepInk,
                ),
                const SizedBox(width: 6),
                // Manifest Category Symbol Badge
                _buildSymbolBadge(parcel.manifestSymbol ?? 'star'),
              ],
            ),

            // Gear Indicator Badge if parcel has gear
            if (parcel.hasGear)
              Positioned(
                top: 4,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.goldenYellow.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_rounded,
                    size: 11,
                    color: AppDesignTokens.deepInk,
                  ),
                ),
              ),

            // Status Ribbon (TAP TO LOAD vs HOLDING)
            Positioned(
              bottom: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: matches ? AppDesignTokens.tealSecondary : const Color(0xFF6B7893),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  matches ? 'TAP TO LOAD' : 'HOLDING',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            if (isAnimating)
              const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: Icon(Icons.arrow_downward_rounded, size: 18, color: AppDesignTokens.tealSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getDirectionIcon(Direction dir) {
    switch (dir) {
      case Direction.up:
        return Icons.arrow_upward_rounded;
      case Direction.down:
        return Icons.arrow_downward_rounded;
      case Direction.left:
        return Icons.arrow_back_rounded;
      case Direction.right:
        return Icons.arrow_forward_rounded;
    }
  }

  Widget _buildSymbolBadge(String symbol) {
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

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/maze/delivery_state.dart';

/// Clear, fair Defeat overlay displaying the exact cause of failure
/// with free immediate Retry and Level Map options.
class DefeatDialog extends StatelessWidget {
  final DefeatReason reason;
  final int deliveredPercent;
  final int requiredQuotaPercent;
  final VoidCallback onRetry;
  final VoidCallback onLevelMap;

  const DefeatDialog({
    super.key,
    required this.reason,
    required this.deliveredPercent,
    required this.requiredQuotaPercent,
    required this.onRetry,
    required this.onLevelMap,
  });

  IconData _iconForReason() {
    switch (reason) {
      case DefeatReason.timeExpired:
        return Icons.timer_off_rounded;
      case DefeatReason.healthDepleted:
        return Icons.heart_broken_rounded;
      case DefeatReason.insufficientFood:
        return Icons.no_food_rounded;
      case DefeatReason.truckDestroyed:
      case DefeatReason.defenseTimeExpired:
        return Icons.local_shipping_rounded;
      case DefeatReason.none:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppDesignTokens.warmCream,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppDesignTokens.coralPrimary, width: 3),
          boxShadow: [
            BoxShadow(
              color: AppDesignTokens.deepNavy.withOpacity(0.28),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: AppDesignTokens.coralPrimary.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForReason(),
                  color: const Color(0xFFD62828),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              reason.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppDesignTokens.deepNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Color(0xFF4B5C73),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppDesignTokens.surfaceBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Delivered vs Quota',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5A6B7F),
                    ),
                  ),
                  Text(
                    '$deliveredPercent% / $requiredQuotaPercent%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppDesignTokens.deepNavy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 22),
              label: const Text(
                'Retry Level',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
            OutlinedButton.icon(
              onPressed: onLevelMap,
              icon: const Icon(Icons.map_rounded, size: 20),
              label: const Text(
                'Back to Map',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
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
          ],
        ),
      ),
    );
  }
}

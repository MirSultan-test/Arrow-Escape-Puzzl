import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';
import '../models/board_theme.dart';

/// CustomPainter rendering the puzzle board tray with postage-stamp scalloped perforations
/// and inset cell depressions.
class BoardPainter extends CustomPainter {
  final int rows;
  final int cols;
  final BoardTheme theme;

  const BoardPainter({
    required this.rows,
    required this.cols,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outerRect = Offset.zero & size;
    final outerRadius = Radius.circular(size.width * 0.04);
    final outerRRect = RRect.fromRectAndRadius(outerRect, outerRadius);

    // 1. Scalloped Postage-Stamp Backing Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
    canvas.drawRRect(outerRRect.shift(const Offset(0, 4)), shadowPaint);

    // 2. Board surface
    final surfacePaint = Paint()
      ..color = theme.boardSurface
      ..style = PaintingStyle.fill;
    canvas.drawRRect(outerRRect, surfacePaint);

    // 3. Postage stamp scalloped perforations along border
    _drawStampPerforations(canvas, size);

    // 4. Board outer border rim
    final borderPaint = Paint()
      ..color = theme.boardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(outerRRect, borderPaint);

    // 5. Inset cell depressions
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;
    final cellPadding = cellWidth * 0.07;

    final cellPaint = Paint()
      ..color = theme.cellEmpty
      ..style = PaintingStyle.fill;

    final cellBorderPaint = Paint()
      ..color = theme.boardBorder.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cellRect = Rect.fromLTWH(
          c * cellWidth + cellPadding,
          r * cellHeight + cellPadding,
          cellWidth - (cellPadding * 2),
          cellHeight - (cellPadding * 2),
        );
        final cellRRect = RRect.fromRectAndRadius(
          cellRect,
          Radius.circular(cellWidth * 0.16),
        );

        canvas.drawRRect(cellRRect, cellPaint);
        canvas.drawRRect(cellRRect, cellBorderPaint);

        // Subtle depot cross-hatch centering dot
        final dotPaint = Paint()
          ..color = theme.boardBorder.withOpacity(0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(cellRect.center, 1.8, dotPaint);
      }
    }
  }

  void _drawStampPerforations(Canvas canvas, Size size) {
    final perfPaint = Paint()
      ..color = AppDesignTokens.warmPaper
      ..style = PaintingStyle.fill;

    const double radius = 3.5;
    const double step = 16.0;

    // Top and bottom edges
    for (double x = 12.0; x < size.width - 12.0; x += step) {
      canvas.drawCircle(Offset(x, 0), radius, perfPaint);
      canvas.drawCircle(Offset(x, size.height), radius, perfPaint);
    }

    // Left and right edges
    for (double y = 12.0; y < size.height - 12.0; y += step) {
      canvas.drawCircle(Offset(0, y), radius, perfPaint);
      canvas.drawCircle(Offset(size.width, y), radius, perfPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.theme != theme;
  }
}

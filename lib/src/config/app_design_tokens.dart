import 'package:flutter/material.dart';

/// Centralized design tokens for Parcel Escape: Food Maze Adventure.
/// Vibrant, playful 2.5D miniature food-delivery world palette.
class AppDesignTokens {
  AppDesignTokens._();

  // Primary Food Maze Palette (Section 13)
  static const Color warmCream = Color(0xFFFFF7E8);
  static const Color freshGreen = Color(0xFF5DBB75);
  static const Color coralPrimary = Color(0xFFFF715B);
  static const Color goldenYellow = Color(0xFFFFC857);
  static const Color deepNavy = Color(0xFF243447);
  static const Color skyBlue = Color(0xFF80CFF2);

  // Semantic & Surface Aliases
  static const Color warmPaper = warmCream;
  static const Color deepInk = deepNavy;
  static const Color tealSecondary = Color(0xFF26A69A);
  static const Color honeyHighlight = goldenYellow;

  static const Color surfaceWarm = Color(0xFFF9EFE0);
  static const Color surfaceBorder = Color(0xFFE4D4BC);
  static const Color cellDepression = Color(0xFFEDE0CE);
  static const Color stampEdge = Color(0xFFFAF0DD);
  static const Color roofTile = Color(0xFFB35446);
  static const Color timberBrown = Color(0xFF6D4C41);

  static const Color gearBrass = Color(0xFFD4AF37);
  static const Color gearShadow = Color(0xFF8C7322);
  static const Color brassGlow = Color(0xFFFFE082);

  // Legacy manifest symbol tokens (kept for historical model compatibility)
  static const Color symbolStar = Color(0xFFFFB300);
  static const Color symbolMoon = Color(0xFF5C6BC0);
  static const Color symbolSun = Color(0xFFFF7043);
  static const Color symbolBox = Color(0xFF26A69A);
  static const Color symbolDiamond = Color(0xFFAB47BC);

  // Status Colors
  static const Color timerNormal = freshGreen;
  static const Color timerWarning = Color(0xFFF59E0B);
  static const Color timerCritical = Color(0xFFE63946);
  static const Color heartRed = Color(0xFFFF4D6D);

  // Text Styles
  static const TextStyle titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: deepNavy,
    letterSpacing: 0.6,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: deepNavy,
    letterSpacing: 0.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: deepNavy,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Color(0xFF5A6B7F),
  );
}

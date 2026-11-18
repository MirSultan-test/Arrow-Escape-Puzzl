import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Visual theme for the puzzle board and parcels.
class BoardTheme {
  final String id;
  final String name;
  final String description;
  final int unlockAtLevel;
  final Color pageBackground;
  final Color boardSurface;
  final Color boardBorder;
  final Color cellEmpty;
  final Color defaultParcelBase;
  final Color defaultParcelBorder;
  final Color defaultTape;
  final Color arrowColor;
  final Color arrowShadow;
  final Color highlightGlow;
  final Map<String, Color> parcelTypeColors;

  const BoardTheme({
    required this.id,
    required this.name,
    required this.description,
    required this.unlockAtLevel,
    required this.pageBackground,
    required this.boardSurface,
    required this.boardBorder,
    required this.cellEmpty,
    required this.defaultParcelBase,
    required this.defaultParcelBorder,
    required this.defaultTape,
    required this.arrowColor,
    required this.arrowShadow,
    required this.highlightGlow,
    required this.parcelTypeColors,
  });

  bool isUnlocked(int completedLevelCount) =>
      completedLevelCount >= unlockAtLevel;

  Color parcelColorFor(String type) =>
      parcelTypeColors[type] ?? defaultParcelBase;

  static const BoardTheme windup = BoardTheme(
    id: 'windup',
    name: 'Wind-Up Depot',
    description: 'Brass cogwheels, warm parchment, and vintage courier crates.',
    unlockAtLevel: 0,
    pageBackground: AppDesignTokens.warmPaper,
    boardSurface: AppDesignTokens.surfaceWarm,
    boardBorder: AppDesignTokens.surfaceBorder,
    cellEmpty: AppDesignTokens.cellDepression,
    defaultParcelBase: Color(0xFFC88D4D),
    defaultParcelBorder: Color(0xFF7A4A1C),
    defaultTape: Color(0xFFEBD0A0),
    arrowColor: AppDesignTokens.deepInk,
    arrowShadow: Color(0x33000000),
    highlightGlow: AppDesignTokens.honeyHighlight,
    parcelTypeColors: {
      'standard': Color(0xFFC88D4D),
      'priority': AppDesignTokens.coralPrimary,
      'fragile': Color(0xFFE05244),
      'eco': AppDesignTokens.tealSecondary,
      'express': Color(0xFF8E44AD),
    },
  );

  static const BoardTheme classic = BoardTheme(
    id: 'classic',
    name: 'Classic Courier',
    description: 'Traditional kraft cardboard delivery packages.',
    unlockAtLevel: 0,
    pageBackground: Color(0xFFF7F4EE),
    boardSurface: Color(0xFFEBE3D5),
    boardBorder: Color(0xFFD3C5B1),
    cellEmpty: Color(0xFFDFD5C4),
    defaultParcelBase: Color(0xFFC99757),
    defaultParcelBorder: Color(0xFF9E6B2F),
    defaultTape: Color(0xFFEAD8AF),
    arrowColor: Color(0xFF2E1C0C),
    arrowShadow: Color(0x33000000),
    highlightGlow: Color(0xFFF59E0B),
    parcelTypeColors: {
      'standard': Color(0xFFC99757),
      'priority': Color(0xFF4A7AB5),
      'fragile': Color(0xFFD9534F),
      'eco': Color(0xFF5B8C5A),
      'express': Color(0xFF8E44AD),
    },
  );

  static const BoardTheme air = BoardTheme(
    id: 'air',
    name: 'Air Express',
    description: 'Sleek aeronautical freight containers.',
    unlockAtLevel: 10,
    pageBackground: Color(0xFFF0F4F8),
    boardSurface: Color(0xFFDCE5EE),
    boardBorder: Color(0xFFB8C8D8),
    cellEmpty: Color(0xFFCFDCea),
    defaultParcelBase: Color(0xFF2C4A6F),
    defaultParcelBorder: Color(0xFF1B324E),
    defaultTape: Color(0xFFE53935),
    arrowColor: Color(0xFFFFFFFF),
    arrowShadow: Color(0x44000000),
    highlightGlow: Color(0xFF00D2D3),
    parcelTypeColors: {
      'standard': Color(0xFF2C4A6F),
      'priority': Color(0xFF0288D1),
      'fragile': Color(0xFFE53935),
      'eco': Color(0xFF00897B),
      'express': Color(0xFF5E35B1),
    },
  );

  static const BoardTheme eco = BoardTheme(
    id: 'eco',
    name: 'Eco Cargo',
    description: 'Sustainable recycled cargo crates.',
    unlockAtLevel: 25,
    pageBackground: Color(0xFFF2F6F3),
    boardSurface: Color(0xFFDFEAE2),
    boardBorder: Color(0xFFBDD2C3),
    cellEmpty: Color(0xFFCFE0D4),
    defaultParcelBase: Color(0xFF4A7252),
    defaultParcelBorder: Color(0xFF325038),
    defaultTape: Color(0xFFBCAAA4),
    arrowColor: Color(0xFFF5FBF5),
    arrowShadow: Color(0x33000000),
    highlightGlow: Color(0xFF81C784),
    parcelTypeColors: {
      'standard': Color(0xFF4A7252),
      'priority': Color(0xFF397A8C),
      'fragile': Color(0xFFC2594F),
      'eco': Color(0xFF2E7D32),
      'express': Color(0xFF7B5E7B),
    },
  );

  static const List<BoardTheme> all = [windup, classic, air, eco];

  static BoardTheme fromId(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => windup);
  }
}

import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Represents a delivery category symbol in the Delivery Manifest.
enum ManifestSymbol {
  star,
  moon,
  sun,
  box,
  diamond;

  String get key => name;

  String get displayName {
    switch (this) {
      case ManifestSymbol.star:
        return 'Star';
      case ManifestSymbol.moon:
        return 'Moon';
      case ManifestSymbol.sun:
        return 'Sun';
      case ManifestSymbol.box:
        return 'Crate';
      case ManifestSymbol.diamond:
        return 'Gem';
    }
  }

  IconData get iconData {
    switch (this) {
      case ManifestSymbol.star:
        return Icons.star_rounded;
      case ManifestSymbol.moon:
        return Icons.nightlight_round;
      case ManifestSymbol.sun:
        return Icons.wb_sunny_rounded;
      case ManifestSymbol.box:
        return Icons.inventory_2_rounded;
      case ManifestSymbol.diamond:
        return Icons.diamond_rounded;
    }
  }

  Color get categoryColor {
    switch (this) {
      case ManifestSymbol.star:
        return AppDesignTokens.symbolStar;
      case ManifestSymbol.moon:
        return AppDesignTokens.symbolMoon;
      case ManifestSymbol.sun:
        return AppDesignTokens.symbolSun;
      case ManifestSymbol.box:
        return AppDesignTokens.symbolBox;
      case ManifestSymbol.diamond:
        return AppDesignTokens.symbolDiamond;
    }
  }

  static ManifestSymbol fromKey(String key) {
    switch (key.trim().toLowerCase()) {
      case 'moon':
        return ManifestSymbol.moon;
      case 'sun':
        return ManifestSymbol.sun;
      case 'box':
      case 'crate':
        return ManifestSymbol.box;
      case 'diamond':
      case 'gem':
        return ManifestSymbol.diamond;
      case 'star':
      default:
        return ManifestSymbol.star;
    }
  }
}

extension ManifestSymbolX on ManifestSymbol {
  Color get color => categoryColor;
  IconData get icon => iconData;
  static ManifestSymbol? fromKey(String key) => ManifestSymbol.fromKey(key);
}

import 'package:flutter/material.dart';
import '../config/app_design_tokens.dart';

/// Collectible postcard awarded upon completing each Food Maze Adventure district.
class DistrictPostcard {
  final int id;
  final int districtId;
  final int levelRequired;
  final String title;
  final String districtName;
  final String postmarkDate;
  final String note;
  final Color stampColor;
  final IconData stampIcon;

  const DistrictPostcard({
    required this.id,
    required this.districtId,
    required this.levelRequired,
    required this.title,
    required this.districtName,
    required this.postmarkDate,
    required this.note,
    required this.stampColor,
    required this.stampIcon,
  });

  static const List<DistrictPostcard> all = [
    DistrictPostcard(
      id: 1,
      districtId: 1,
      levelRequired: 10,
      title: 'Harvest Dawn at Sunny Orchard',
      districtName: 'District 1: Sunny Orchard',
      postmarkDate: 'ORCHARD ROUTE • 07:00 AM',
      note:
          'Crisp apples, golden mangoes, and strawberries loaded fresh off the orchard hedges before the sleepy guardians even blinked!',
      stampColor: AppDesignTokens.freshGreen,
      stampIcon: Icons.eco_rounded,
    ),
    DistrictPostcard(
      id: 2,
      districtId: 2,
      levelRequired: 20,
      title: 'Morning Rush at Garden Market',
      districtName: 'District 2: Garden Market',
      postmarkDate: 'MARKET SQUARE • 09:30 AM',
      note:
          'Weaving between cobblestone produce stalls with baskets of carrots and tomatoes — every crate reached the truck on time.',
      stampColor: AppDesignTokens.goldenYellow,
      stampIcon: Icons.storefront_rounded,
    ),
    DistrictPostcard(
      id: 3,
      districtId: 3,
      levelRequired: 30,
      title: 'Outrunning the Forest Hunters',
      districtName: 'District 3: Forest Food Trail',
      postmarkDate: 'PINE TRAIL • 02:15 PM',
      note:
          'Hungry woodland hunters sniffed the trail, yet clever corner detours kept every sweet berry safe for the collector.',
      stampColor: AppDesignTokens.tealSecondary,
      stampIcon: Icons.forest_rounded,
    ),
    DistrictPostcard(
      id: 4,
      districtId: 4,
      levelRequired: 40,
      title: 'Twilight Dash Through Monster Valley',
      districtName: 'District 4: Monster Valley',
      postmarkDate: 'VALLEY PASS • 06:45 PM',
      note:
          'Speedy imps darted down the canyon corridors, but reading their pauses turned a risky shortcut into a legendary delivery.',
      stampColor: Color(0xFF7B5EA7),
      stampIcon: Icons.terrain_rounded,
    ),
    DistrictPostcard(
      id: 5,
      districtId: 5,
      levelRequired: 50,
      title: 'Champion of Grand Delivery City',
      districtName: 'District 5: Grand Delivery City',
      postmarkDate: 'GRAND PLAZA • 12:00 PM',
      note:
          'Across fifty bustling mazes and five vibrant districts, the finest food courier in the land delivered the final grand shipment!',
      stampColor: AppDesignTokens.coralPrimary,
      stampIcon: Icons.emoji_events_rounded,
    ),
  ];
}

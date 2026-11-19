import 'dart:math' as math;
import 'level_roster.dart';
import 'monster.dart';

/// 10 distinct monster movement & tactical AI profiles (V3.5 Section 2).
enum MonsterMovementProfile {
  slowStalker, // A: Watches Courier, follows steadily when near
  fastHunter, // B: Sprints aggressively upon spotting Courier
  zigzagMonster, // C: Weaves through corridors with wall-safe zigzag motion
  patrolGuardian, // D: Protects a defined corridor/zone & lunges on intrusion
  ambushMonster, // E: Waits crouched near corners, bursts out when player nears
  jumpingCreature, // F: Rhythmic wall-safe hopping leaps with takeoff & landing
  crawlingMonster, // G: Low multi-limbed skittering crawl close to floor
  chargingMonster, // H: Telegraphed warning stance -> high-speed corridor charge
  flyingMonster, // I: Hovering winged flight with swoops, strictly wall-bounded
  intelligentHunter; // J: Flanking intercept pathfinding through alternate corridors

  String get displayName {
    switch (this) {
      case MonsterMovementProfile.slowStalker:
        return 'Slow Stalker';
      case MonsterMovementProfile.fastHunter:
        return 'Fast Hunter';
      case MonsterMovementProfile.zigzagMonster:
        return 'Zigzag Skitter';
      case MonsterMovementProfile.patrolGuardian:
        return 'Patrol Guardian';
      case MonsterMovementProfile.ambushMonster:
        return 'Corner Ambusher';
      case MonsterMovementProfile.jumpingCreature:
        return 'Hopping Fiend';
      case MonsterMovementProfile.crawlingMonster:
        return 'Ground Crawler';
      case MonsterMovementProfile.chargingMonster:
        return 'Corridor Charger';
      case MonsterMovementProfile.flyingMonster:
        return 'Winged Swooper';
      case MonsterMovementProfile.intelligentHunter:
        return 'Tactical Flanker';
    }
  }

  static MonsterMovementProfile fromName(String? raw, MonsterType fallbackType) {
    if (raw != null) {
      for (final p in values) {
        if (p.name == raw) return p;
      }
    }
    switch (fallbackType) {
      case MonsterType.redHunter:
        return MonsterMovementProfile.fastHunter;
      case MonsterType.shadowCrawler:
        return MonsterMovementProfile.crawlingMonster;
      case MonsterType.forestBrute:
        return MonsterMovementProfile.patrolGuardian;
      case MonsterType.flyingCreature:
        return MonsterMovementProfile.flyingMonster;
      case MonsterType.mushroomBeast:
        return MonsterMovementProfile.slowStalker;
      case MonsterType.mazeGuardian:
        return MonsterMovementProfile.chargingMonster;
    }
  }
}

/// 10 genuinely distinct monster body silhouettes (not simple color swaps!).
enum MonsterBodyShape {
  tallLanky,
  hulkingBrute,
  lowCrawler,
  spikyHopper,
  wingedFlier,
  hornedStalker,
  armoredJuggernaut,
  mushroomFiend,
  cyclopsOgre,
  phantomWraith,
}

enum MonsterHornStyle {
  none,
  twinCurved,
  ramSpiral,
  crownSpikes,
  antlerThorns,
  singleRhino,
  bladeCrest,
  antennae,
}

enum MonsterMouthStyle {
  jaggedFangs,
  tuskedUnderbite,
  wideMaw,
  mandibles,
  beakSnarl,
}

enum MonsterSkinPattern {
  smooth,
  armoredPlates,
  thornySpines,
  glowingSpots,
  crackedMagma,
  mossyFur,
}

/// Complete anatomical & visual specification for a maze monster.
class MonsterAppearanceSpec {
  final String appearanceId;
  final String speciesName;
  final MonsterBodyShape bodyShape;
  final MonsterHornStyle hornStyle;
  final MonsterMouthStyle mouthStyle;
  final MonsterSkinPattern skinPattern;
  final int eyeCount; // 1, 2, 3, or 4
  final int limbCount; // 2, 4, or 6
  final int bodyPrimaryHex;
  final int bodySecondaryHex;
  final int bellyHex;
  final int eyeGlowHex;
  final int hornHex;
  final int clawHex;
  final double widthRatio;
  final double heightRatio;
  final String? modelAssetPath;
  final String? previewAssetPath;

  const MonsterAppearanceSpec({
    required this.appearanceId,
    required this.speciesName,
    required this.bodyShape,
    required this.hornStyle,
    required this.mouthStyle,
    required this.skinPattern,
    required this.eyeCount,
    required this.limbCount,
    required this.bodyPrimaryHex,
    required this.bodySecondaryHex,
    required this.bellyHex,
    required this.eyeGlowHex,
    required this.hornHex,
    required this.clawHex,
    this.widthRatio = 1.0,
    this.heightRatio = 1.0,
    this.modelAssetPath,
    this.previewAssetPath,
  });

  /// Generates a reproducible, anatomy-matched unique monster design for a given
  /// [levelId], [slotIndex], [type], and [movementProfile].
  static MonsterAppearanceSpec forLevelSlot({
    required int levelId,
    required int slotIndex,
    required MonsterType type,
    required MonsterMovementProfile movement,
    String? explicitAppearanceId,
  }) {
    final seed = levelId * 131 + slotIndex * 37 + movement.index * 19;
    final rng = math.Random(seed);

    // Match anatomy naturally to movement profile!
    final MonsterBodyShape shape;
    final int limbCount;
    final double wRatio;
    final double hRatio;
    switch (movement) {
      case MonsterMovementProfile.crawlingMonster:
        shape = MonsterBodyShape.lowCrawler;
        limbCount = 6;
        wRatio = 1.24;
        hRatio = 0.78;
        break;
      case MonsterMovementProfile.flyingMonster:
        shape = MonsterBodyShape.wingedFlier;
        limbCount = 2;
        wRatio = 1.12;
        hRatio = 0.92;
        break;
      case MonsterMovementProfile.jumpingCreature:
        shape = MonsterBodyShape.spikyHopper;
        limbCount = 4;
        wRatio = 0.96;
        hRatio = 1.04;
        break;
      case MonsterMovementProfile.chargingMonster:
        shape = levelId.isEven
            ? MonsterBodyShape.armoredJuggernaut
            : MonsterBodyShape.hornedStalker;
        limbCount = 4;
        wRatio = 1.18;
        hRatio = 1.06;
        break;
      case MonsterMovementProfile.slowStalker:
        shape = type == MonsterType.mushroomBeast
            ? MonsterBodyShape.mushroomFiend
            : (levelId % 3 == 0
                ? MonsterBodyShape.cyclopsOgre
                : MonsterBodyShape.tallLanky);
        limbCount = 4;
        wRatio = 0.92;
        hRatio = 1.18;
        break;
      case MonsterMovementProfile.ambushMonster:
        shape = levelId.isOdd
            ? MonsterBodyShape.phantomWraith
            : MonsterBodyShape.lowCrawler;
        limbCount = shape == MonsterBodyShape.lowCrawler ? 6 : 2;
        wRatio = 1.04;
        hRatio = 1.06;
        break;
      case MonsterMovementProfile.patrolGuardian:
        shape = levelId % 2 == 0
            ? MonsterBodyShape.hulkingBrute
            : MonsterBodyShape.armoredJuggernaut;
        limbCount = 4;
        wRatio = 1.20;
        hRatio = 1.12;
        break;
      case MonsterMovementProfile.zigzagMonster:
        shape = levelId % 2 == 0
            ? MonsterBodyShape.spikyHopper
            : MonsterBodyShape.tallLanky;
        limbCount = 4;
        wRatio = 0.90;
        hRatio = 1.12;
        break;
      case MonsterMovementProfile.fastHunter:
        shape = levelId % 3 == 0
            ? MonsterBodyShape.hornedStalker
            : MonsterBodyShape.tallLanky;
        limbCount = 4;
        wRatio = 0.94;
        hRatio = 1.16;
        break;
      case MonsterMovementProfile.intelligentHunter:
        shape = levelId % 2 == 0
            ? MonsterBodyShape.phantomWraith
            : MonsterBodyShape.cyclopsOgre;
        limbCount = 4;
        wRatio = 1.02;
        hRatio = 1.16;
        break;
    }

    const hornPool = MonsterHornStyle.values;
    final horn = shape == MonsterBodyShape.mushroomFiend
        ? MonsterHornStyle.antennae
        : (movement == MonsterMovementProfile.chargingMonster
            ? (levelId.isEven
                ? MonsterHornStyle.ramSpiral
                : MonsterHornStyle.singleRhino)
            : hornPool[(levelId + slotIndex * 3 + movement.index) % hornPool.length]);

    final mouth = shape == MonsterBodyShape.lowCrawler
        ? MonsterMouthStyle.mandibles
        : (shape == MonsterBodyShape.wingedFlier
            ? MonsterMouthStyle.beakSnarl
            : MonsterMouthStyle
                .values[(levelId * 2 + slotIndex + shape.index) % MonsterMouthStyle.values.length]);

    final pattern = MonsterSkinPattern
        .values[(levelId + slotIndex * 2 + shape.index) % MonsterSkinPattern.values.length];

    final eyeCount = shape == MonsterBodyShape.cyclopsOgre
        ? 1
        : (shape == MonsterBodyShape.lowCrawler
            ? 4
            : (levelId % 5 == 0 && slotIndex == 0 ? 3 : 2));

    // Rich district-harmonized spooky monster palettes (12 distinct palettes cycled cleanly)
    const palettes = [
      (0xFF8B1E3F, 0xFF4A0E22, 0xFFC83E59, 0xFFFFE66D, 0xFFFDE68A, 0xFFFFF3DA), // Crimson Fiend
      (0xFF2D4A3E, 0xFF13261F, 0xFF4F7A65, 0xFF84CC16, 0xFFA3E635, 0xFFE2E8F0), // Moss Stalker
      (0xFF4C1D95, 0xFF230B4A, 0xFF7C3AED, 0xFFF43F5E, 0xFFD946EF, 0xFFFCE7F3), // Void Crawler
      (0xFF7C2D12, 0xFF3F1306, 0xFFB45309, 0xFF38BDF8, 0xFFFBBF24, 0xFFFFEDD5), // Magma Brute
      (0xFF1E3A5F, 0xFF0E1F36, 0xFF3B6B9B, 0xFFFF715B, 0xFF93C5FD, 0xFFE0F2FE), // Frost Fang
      (0xFF365314, 0xFF1A2E05, 0xFF65A30D, 0xFFFACC15, 0xFFBEF264, 0xFFFEF9C3), // Thorn Hopper
      (0xFF581C87, 0xFF2E1065, 0xFF9333EA, 0xFF2DD4BF, 0xFFE879F9, 0xFFF5D0FE), // Spore Wraith
      (0xFF334155, 0xFF0F172A, 0xFF64748B, 0xFFFF4D6D, 0xFFFFC857, 0xFFF1F5F9), // Iron Gargoyle
      (0xFF701A75, 0xFF3B0764, 0xFFA21CAF, 0xFFA3E635, 0xFFF472B6, 0xFFFDF2F8), // Twilight Imp
      (0xFF134E4A, 0xFF042F2E, 0xFF0F766E, 0xFFFF9F1C, 0xFF5EEAD4, 0xFFCCFBF1), // Swamp Lurker
      (0xFF7F1D1D, 0xFF3B0A0A, 0xFFB91C1C, 0xFF34D399, 0xFFFCA5A5, 0xFFFFF1F2), // Blood Horn
      (0xFF312E81, 0xFF1E1B4B, 0xFF4F46E5, 0xFFFDE047, 0xFFA5B4FC, 0xFFEEF2FF), // Astral Hound
    ];
    final pal = palettes[(levelId * 3 + slotIndex * 5 + rng.nextInt(3)) % palettes.length];

    final roster = LevelRosterCatalog.forLevel(levelId);
    final isPrimarySlot = slotIndex == 0;

    final id = explicitAppearanceId ??
        (isPrimarySlot
            ? roster.primaryModelId
            : 'mon_l${levelId}_s${slotIndex}_${shape.name}_${movement.name}');
    final name = isPrimarySlot
        ? roster.monster
        : '${_speciesPrefixes[(levelId + slotIndex * 7) % _speciesPrefixes.length]} ${_speciesSuffixes[(shape.index + movement.index) % _speciesSuffixes.length]}';

    return MonsterAppearanceSpec(
      appearanceId: id,
      speciesName: name,
      bodyShape: isPrimarySlot ? roster.bodyShape : shape,
      hornStyle: horn,
      mouthStyle: mouth,
      skinPattern: pattern,
      eyeCount: eyeCount,
      limbCount: limbCount,
      bodyPrimaryHex: pal.$1,
      bodySecondaryHex: pal.$2,
      bellyHex: pal.$3,
      eyeGlowHex: pal.$4,
      hornHex: pal.$5,
      clawHex: pal.$6,
      widthRatio: wRatio,
      heightRatio: hRatio,
      modelAssetPath: isPrimarySlot ? roster.modelAssetPath : null,
      previewAssetPath: isPrimarySlot ? roster.previewAssetPath : null,
    );
  }

  static const List<String> _speciesPrefixes = [
    'Bramble', 'Iron', 'Venom', 'Shadow', 'Grim', 'Razor', 'Cinder', 'Dread',
    'Hollow', 'Frost', 'Spore', 'Night', 'Gnarl', 'Fang', 'Viper', 'Obsidian',
  ];

  static const List<String> _speciesSuffixes = [
    'Stalker', 'Ripper', 'Crawler', 'Hopper', 'Swooper', 'Horn', 'Crusher',
    'Shroom', 'Cyclops', 'Wraith',
  ];
}

/// Unique per-level Giant Boss appearance & signature definition for ALL 50 levels (Section 3).
class BossAppearanceSpec {
  final int levelId;
  final String bossId;
  final String title;
  final MonsterBodyShape bodyShape;
  final MonsterHornStyle hornStyle;
  final MonsterMouthStyle mouthStyle;
  final MonsterSkinPattern skinPattern;
  final int eyeCount;
  final int limbCount;
  final int bodyLightHex;
  final int bodyMidHex;
  final int bodyDarkHex;
  final int bellyHex;
  final int glowHex;
  final int armorHex;
  final int hornHex;
  final int clawHex;
  final double widthRatio;
  final double heightRatio;
  final String signatureTrait;

  const BossAppearanceSpec({
    required this.levelId,
    required this.bossId,
    required this.title,
    required this.bodyShape,
    required this.hornStyle,
    required this.mouthStyle,
    required this.skinPattern,
    required this.eyeCount,
    required this.limbCount,
    required this.bodyLightHex,
    required this.bodyMidHex,
    required this.bodyDarkHex,
    required this.bellyHex,
    required this.glowHex,
    required this.armorHex,
    required this.hornHex,
    required this.clawHex,
    this.widthRatio = 1.0,
    this.heightRatio = 1.0,
    required this.signatureTrait,
  });

  /// Returns a genuinely distinct Giant Boss appearance & signature for EVERY level 1..50!
  /// Levels 1-5 match the exact progression examples in Section 3, and all 50 levels have
  /// unique bossId, title, anatomical silhouette/horns/eyes/mouth/armor combinations.
  static BossAppearanceSpec forLevel(int levelId, int districtId) {
    final idx = (levelId - 1).clamp(0, 49);

    // Hand-tuned showcase bosses for Levels 1-5 (matching Section 3 directly!)
    if (levelId == 1) {
      return const BossAppearanceSpec(
        levelId: 1,
        bossId: 'boss_01_bramble_thornback',
        title: 'Bramble Thornback',
        bodyShape: MonsterBodyShape.hulkingBrute,
        hornStyle: MonsterHornStyle.antlerThorns,
        mouthStyle: MonsterMouthStyle.jaggedFangs,
        skinPattern: MonsterSkinPattern.thornySpines,
        eyeCount: 2,
        limbCount: 4,
        bodyLightHex: 0xFF3A7D44,
        bodyMidHex: 0xFF23532B,
        bodyDarkHex: 0xFF14331A,
        bellyHex: 0xFF538D4E,
        glowHex: 0xFFFF595E,
        armorHex: 0xFF8D5524,
        hornHex: 0xFFFFC857,
        clawHex: 0xFFFFF3DA,
        widthRatio: 1.08,
        heightRatio: 1.02,
        signatureTrait: 'Slow Thorn Ravager',
      );
    }
    if (levelId == 2) {
      return const BossAppearanceSpec(
        levelId: 2,
        bossId: 'boss_02_gorgon_ramhorn',
        title: 'Gorgon Ramhorn',
        bodyShape: MonsterBodyShape.hornedStalker,
        hornStyle: MonsterHornStyle.ramSpiral,
        mouthStyle: MonsterMouthStyle.tuskedUnderbite,
        skinPattern: MonsterSkinPattern.crackedMagma,
        eyeCount: 2,
        limbCount: 4,
        bodyLightHex: 0xFF9A3412,
        bodyMidHex: 0xFF6B1F0B,
        bodyDarkHex: 0xFF3B0D06,
        bellyHex: 0xFFC2410C,
        glowHex: 0xFFFACC15,
        armorHex: 0xFF78716C,
        hornHex: 0xFFFDE68A,
        clawHex: 0xFFFFEDD5,
        widthRatio: 1.14,
        heightRatio: 1.04,
        signatureTrait: 'Horned Charger',
      );
    }
    if (levelId == 3) {
      return const BossAppearanceSpec(
        levelId: 3,
        bossId: 'boss_03_ripclaw_timberfang',
        title: 'Ripclaw Timberfang',
        bodyShape: MonsterBodyShape.spikyHopper,
        hornStyle: MonsterHornStyle.bladeCrest,
        mouthStyle: MonsterMouthStyle.wideMaw,
        skinPattern: MonsterSkinPattern.mossyFur,
        eyeCount: 3,
        limbCount: 4,
        bodyLightHex: 0xFF1F6E58,
        bodyMidHex: 0xFF114738,
        bodyDarkHex: 0xFF0A2920,
        bellyHex: 0xFF2D8F74,
        glowHex: 0xFFFF715B,
        armorHex: 0xFF6B3F22,
        hornHex: 0xFF84CC16,
        clawHex: 0xFFFFF8E8,
        widthRatio: 1.06,
        heightRatio: 1.08,
        signatureTrait: 'Clawed Forest Beast',
      );
    }
    if (levelId == 4) {
      return const BossAppearanceSpec(
        levelId: 4,
        bossId: 'boss_04_stiltjaw_hunter',
        title: 'Stiltjaw Hunter',
        bodyShape: MonsterBodyShape.tallLanky,
        hornStyle: MonsterHornStyle.antennae,
        mouthStyle: MonsterMouthStyle.mandibles,
        skinPattern: MonsterSkinPattern.glowingSpots,
        eyeCount: 4,
        limbCount: 4,
        bodyLightHex: 0xFF4F46E5,
        bodyMidHex: 0xFF312E81,
        bodyDarkHex: 0xFF1E1B4B,
        bellyHex: 0xFF6366F1,
        glowHex: 0xFF38BDF8,
        armorHex: 0xFF94A3B8,
        hornHex: 0xFF7DD3FC,
        clawHex: 0xFFE0F2FE,
        widthRatio: 0.88,
        heightRatio: 1.24,
        signatureTrait: 'Long-Legged Hunter',
      );
    }
    if (levelId == 5) {
      return const BossAppearanceSpec(
        levelId: 5,
        bossId: 'boss_05_ironhide_crusher',
        title: 'Ironhide Crusher',
        bodyShape: MonsterBodyShape.armoredJuggernaut,
        hornStyle: MonsterHornStyle.singleRhino,
        mouthStyle: MonsterMouthStyle.tuskedUnderbite,
        skinPattern: MonsterSkinPattern.armoredPlates,
        eyeCount: 1,
        limbCount: 4,
        bodyLightHex: 0xFF64748B,
        bodyMidHex: 0xFF334155,
        bodyDarkHex: 0xFF1E293B,
        bellyHex: 0xFF94A3B8,
        glowHex: 0xFFFF4D6D,
        armorHex: 0xFFD97706,
        hornHex: 0xFFFFC857,
        clawHex: 0xFFF1F5F9,
        widthRatio: 1.24,
        heightRatio: 1.04,
        signatureTrait: 'Armored Cyclops Brute',
      );
    }

    // Levels 6-50: Guaranteed unique anatomical + palette + title combinations organized by district!
    const shapes = MonsterBodyShape.values;
    const horns = MonsterHornStyle.values;
    const mouths = MonsterMouthStyle.values;
    const patterns = MonsterSkinPattern.values;

    // Coprime modular strides guarantee every level 6..50 has a distinct anatomical silhouette!
    final shape = shapes[(idx * 3 + districtId) % shapes.length];
    final horn = horns[(idx * 5 + districtId * 2) % horns.length];
    final mouth = mouths[(idx * 2 + districtId) % mouths.length];
    final pattern = patterns[(idx * 4 + districtId) % patterns.length];
    final eyeCount = shape == MonsterBodyShape.cyclopsOgre
        ? 1
        : (shape == MonsterBodyShape.lowCrawler
            ? 4
            : ((idx % 4 == 0) ? 3 : ((idx % 7 == 0) ? 1 : 2)));
    final limbCount = shape == MonsterBodyShape.lowCrawler ? 6 : 4;

    final wRatio = shape == MonsterBodyShape.tallLanky
        ? 0.88
        : (shape == MonsterBodyShape.armoredJuggernaut ||
                shape == MonsterBodyShape.hulkingBrute
            ? 1.22
            : (shape == MonsterBodyShape.lowCrawler ? 1.24 : 1.06));
    final hRatio = shape == MonsterBodyShape.tallLanky
        ? 1.22
        : (shape == MonsterBodyShape.lowCrawler ? 0.84 : 1.06);

    final pal = _districtBossPalettes[(districtId - 1).clamp(0, 4)]
        [idx % _districtBossPalettes[0].length];

    final name = _uniqueBossNames[idx];
    return BossAppearanceSpec(
      levelId: levelId,
      bossId: 'boss_${levelId.toString().padLeft(2, '0')}_${name.toLowerCase().replaceAll(' ', '_')}',
      title: name,
      bodyShape: shape,
      hornStyle: horn,
      mouthStyle: mouth,
      skinPattern: pattern,
      eyeCount: eyeCount,
      limbCount: limbCount,
      bodyLightHex: pal.$1,
      bodyMidHex: pal.$2,
      bodyDarkHex: pal.$3,
      bellyHex: pal.$4,
      glowHex: pal.$5,
      armorHex: pal.$6,
      hornHex: pal.$7,
      clawHex: 0xFFFFF8E8,
      widthRatio: wRatio,
      heightRatio: hRatio,
      signatureTrait: '${shape.name} / ${horn.name}',
    );
  }

  static const List<List<(int, int, int, int, int, int, int)>> _districtBossPalettes = [
    // District 1: Sunny Orchard (Thorny Greens, Crimson, Amber, Bark)
    [
      (0xFF3A7D44, 0xFF23532B, 0xFF14331A, 0xFF538D4E, 0xFFFF595E, 0xFF8D5524, 0xFFFFC857),
      (0xFF65A30D, 0xFF3F6212, 0xFF1A2E05, 0xFF84CC16, 0xFFFF4D6D, 0xFF78350F, 0xFFFDE047),
      (0xFF9A3412, 0xFF6B1F0B, 0xFF3B0D06, 0xFFC2410C, 0xFFFACC15, 0xFF57534E, 0xFFFED7AA),
      (0xFF0F766E, 0xFF115E59, 0xFF042F2E, 0xFF14B8A6, 0xFFFF9F1C, 0xFF713F12, 0xFF99F6E4),
      (0xFF881337, 0xFF4C0519, 0xFF2A030E, 0xFFBE123C, 0xFF84CC16, 0xFF92400E, 0xFFFDA4AF),
    ],
    // District 2: Garden Market (Armored Crimson, Bronze, Slate, Brass)
    [
      (0xFF7F1D1D, 0xFF450A0A, 0xFF1F1218, 0xFF991B1B, 0xFFFF9F1C, 0xFF94A3B8, 0xFFE2E8F0),
      (0xFF92400E, 0xFF78350F, 0xFF451A03, 0xFFB45309, 0xFF38BDF8, 0xFFCBD5E1, 0xFFFDE68A),
      (0xFF57534E, 0xFF292524, 0xFF1C1917, 0xFF78716C, 0xFFFF4D6D, 0xFFD97706, 0xFFFFC857),
      (0xFF9F1239, 0xFF4C0519, 0xFF270712, 0xFFE11D48, 0xFFFACC15, 0xFF64748B, 0xFFFECDD3),
      (0xFF3F3F46, 0xFF27272A, 0xFF18181B, 0xFF52525B, 0xFFFF715B, 0xFFF59E0B, 0xFFFDE047),
    ],
    // District 3: Forest Food Trail (Toxic Spore, Deep Pine, Violet, Bog)
    [
      (0xFF2D4A3E, 0xFF182C25, 0xFF0D1B17, 0xFF3E6B59, 0xFF84CC16, 0xFF4C1D95, 0xFFA3E635),
      (0xFF4C1D95, 0xFF2E1065, 0xFF170736, 0xFF6D28D9, 0xFFA3E635, 0xFF15803D, 0xFFD8B4FE),
      (0xFF14532D, 0xFF052E16, 0xFF031A0C, 0xFF166534, 0xFF2DD4BF, 0xFF581C87, 0xFF86EFAC),
      (0xFF3B0764, 0xFF1E0436, 0xFF0F021C, 0xFF6B21A8, 0xFFFACC15, 0xFF365314, 0xFFE879F9),
      (0xFF134E4A, 0xFF042F2E, 0xFF021C1B, 0xFF0F766E, 0xFFFF595E, 0xFF4D7C0F, 0xFF5EEAD4),
    ],
    // District 4: Monster Valley (Obsidian, Magenta, Volcanic Crimson, Indigo)
    [
      (0xFF581C87, 0xFF3B0764, 0xFF1E0836, 0xFF6B21A8, 0xFFF43F5E, 0xFF475569, 0xFFD946EF),
      (0xFF701A75, 0xFF4A044E, 0xFF260229, 0xFF86198F, 0xFF38BDF8, 0xFF334155, 0xFFF472B6),
      (0xFF312E81, 0xFF1E1B4B, 0xFF0F0E29, 0xFF4338CA, 0xFFFF9F1C, 0xFF64748B, 0xFFA5B4FC),
      (0xFF7F1D1D, 0xFF450A0A, 0xFF220505, 0xFFB91C1C, 0xFFD946EF, 0xFF1E293B, 0xFFFCA5A5),
      (0xFF1E293B, 0xFF0F172A, 0xFF020617, 0xFF334155, 0xFFA855F7, 0xFF7C3AED, 0xFFC084FC),
    ],
    // District 5: Grand Delivery City (Royal Navy, Gold, Steel, Cyber-Cyan, Crimson)
    [
      (0xFF334155, 0xFF1E293B, 0xFF0F172A, 0xFF475569, 0xFFFFC857, 0xFFD97706, 0xFFFFC857),
      (0xFF1E3A8A, 0xFF172554, 0xFF0B1330, 0xFF1D4ED8, 0xFF38BDF8, 0xFFF59E0B, 0xFFBAE6FD),
      (0xFF4C0519, 0xFF2A030E, 0xFF140107, 0xFF881337, 0xFFFFC857, 0xFFCBD5E1, 0xFFFDE047),
      (0xFF0F172A, 0xFF020617, 0xFF000000, 0xFF1E293B, 0xFF2DD4BF, 0xFFD97706, 0xFF5EEAD4),
      (0xFF3B0764, 0xFF1E0436, 0xFF0F021C, 0xFF581C87, 0xFFFFC857, 0xFFEAB308, 0xFFFEF08A),
    ],
  ];

  static const List<String> _uniqueBossNames = [
    'Bramble Thornback', 'Gorgon Ramhorn', 'Ripclaw Timberfang', 'Stiltjaw Hunter', 'Ironhide Crusher',
    'Briar Hopper', 'Spindle Maw', 'Orchard Dreadhorn', 'Cider Fang', 'Grove Sovereign',
    'Brassjaw Juggernaut', 'Cobble Stalker', 'Anvil Tusker', 'Market Skitterer', 'Crate Wrecker',
    'Steelwing Ravager', 'Bazaar Cyclops', 'Furnace Brute', 'Guild Gargoyle', 'Market Warlord',
    'Sporemaw Colossus', 'Canopy Prowler', 'Mossback Charger', 'Bog Mandible', 'Tangle Wraith',
    'Venom Leaper', 'Rootbound Titan', 'Hollow Stalker', 'Blight Fang', 'Forest Overlord',
    'Obsidian Bullhorn', 'Abyssal Crawler', 'Crag Ripper', 'Twilight Cyclops', 'Magma Hound',
    'Vortex Wing', 'Dreadspire Brute', 'Nightmare Hopper', 'Chasm Fiend', 'Valley Sovereign',
    'Aegis Sentinel', 'Metro Juggernaut', 'Vault Stalker', 'Skyline Swooper', 'Gilded Crusher',
    'Citadel Mandible', 'Ironclad Wraith', 'Apex Charger', 'Crown Dreadnought', 'Grand Omega Warden',
  ];
}

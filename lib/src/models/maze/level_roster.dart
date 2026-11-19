import 'monster_variants.dart';

/// Explicit model, art, gait, and signature attack identity for each level (1–50)
/// defined in `assets/art_kit/06_Implementation/level_roster.csv`.
class LevelRosterEntry {
  final int level;
  final String district;
  final String monster;
  final String anatomy;
  final String feature;
  final String intendedLocomotion;
  final String intendedAttack;
  final String model;
  final String preview;

  const LevelRosterEntry({
    required this.level,
    required this.district,
    required this.monster,
    required this.anatomy,
    required this.feature,
    required this.intendedLocomotion,
    required this.intendedAttack,
    required this.model,
    required this.preview,
  });

  /// Primary model identifier, e.g. "L01_pipjack", "L28_pinecone_pangolin".
  String get primaryModelId {
    final filename = model.split('/').last;
    return filename.endsWith('.glb')
        ? filename.substring(0, filename.length - 4)
        : filename;
  }

  /// Full Flutter asset path to the 3D GLB model.
  String get modelAssetPath => 'assets/art_kit/$model';

  /// Full Flutter asset path to the transparent 3D preview render.
  String get previewAssetPath => 'assets/art_kit/$preview';

  /// Maps the intended locomotion from the roster to the tactical movement behavior.
  MonsterMovementProfile get movementProfile {
    switch (intendedLocomotion.toLowerCase()) {
      case 'double hop':
      case 'crouch hop':
      case 'leap':
      case 'vault':
        return MonsterMovementProfile.jumpingCreature;
      case 'bound':
      case 'prowl':
      case 'slink':
      case 'gallop':
        return MonsterMovementProfile.fastHunter;
      case 'scuttle':
      case 'skitter':
      case 'slither':
      case 'belly crawl':
      case 'sidewind':
      case 'ripple march':
        return MonsterMovementProfile.crawlingMonster;
      case 'glide':
      case 'float':
      case 'shuffle':
      case 'trundle':
      case 'tiptoe':
      case 'dig walk':
        return MonsterMovementProfile.slowStalker;
      case 'flap':
      case 'flutter':
      case 'hover':
      case 'swoop':
      case 'glide flap':
      case 'bank':
      case 'undulate':
      case 'flying swim':
        return MonsterMovementProfile.flyingMonster;
      case 'sidestep':
      case 'skip':
      case 'highstep':
      case 'rock':
      case 'bob walk':
        return MonsterMovementProfile.zigzagMonster;
      case 'trot':
      case 'strut':
      case 'parade':
      case 'canter':
      case 'stalk':
      case 'low trot':
      case 'march':
      case 'royal stride':
        return MonsterMovementProfile.patrolGuardian;
      case 'waddle':
      case 'stomp':
      case 'heavy trot':
      case 'knuckle walk':
      case 'heave':
      case 'tramp':
      case 'pulse crawl':
        return MonsterMovementProfile.chargingMonster;
      case 'weave':
      case 'hover step':
        return MonsterMovementProfile.intelligentHunter;
      default:
        return MonsterMovementProfile.patrolGuardian;
    }
  }

  /// Maps the anatomy from the roster to the distinctive body silhouette.
  MonsterBodyShape get bodyShape {
    switch (anatomy.toLowerCase()) {
      case 'hare':
      case 'frog':
      case 'kangaroo':
        return MonsterBodyShape.spikyHopper;
      case 'wolf':
      case 'cat':
      case 'hound':
      case 'squirrel':
        return MonsterBodyShape.hornedStalker;
      case 'beetle':
      case 'crab':
      case 'scorpion':
      case 'octopus':
      case 'centipede':
      case 'spider':
      case 'armadillo':
        return MonsterBodyShape.lowCrawler;
      case 'snail':
      case 'chest':
      case 'turtle':
      case 'clam':
      case 'mole':
        return MonsterBodyShape.armoredJuggernaut;
      case 'bat':
      case 'moth':
      case 'bee':
      case 'dragon':
      case 'owl':
      case 'raptor':
      case 'ray':
      case 'crane':
      case 'fish':
      case 'griffin':
        return MonsterBodyShape.wingedFlier;
      case 'boar':
      case 'sheep':
      case 'bison':
      case 'walrus':
        return MonsterBodyShape.hulkingBrute;
      case 'golem':
      case 'gorilla':
      case 'totem':
      case 'robot':
        return MonsterBodyShape.cyclopsOgre;
      case 'snake':
      case 'gecko':
      case 'salamander':
      case 'eel':
      case 'hydra':
        return MonsterBodyShape.phantomWraith;
      case 'mushroom':
      case 'jelly':
      case 'imp':
        return MonsterBodyShape.mushroomFiend;
      case 'bird':
      case 'peacock':
      case 'deer':
        return MonsterBodyShape.tallLanky;
      default:
        return MonsterBodyShape.hornedStalker;
    }
  }
}

/// Authoritative catalog of the 50 level identities loaded from `level_roster.csv`.
class LevelRosterCatalog {
  LevelRosterCatalog._();

  static const List<LevelRosterEntry> entries = [
    LevelRosterEntry(level: 1, district: 'Sunny Orchard', monster: 'Pipjack', anatomy: 'hare', feature: 'sprout', intendedLocomotion: 'double hop', intendedAttack: 'spring kick', model: '01_Monsters/L01_pipjack.glb', preview: '01_Monsters/L01_pipjack.png'),
    LevelRosterEntry(level: 2, district: 'Sunny Orchard', monster: 'Acorn Tunneler', anatomy: 'beetle', feature: 'acorn', intendedLocomotion: 'scuttle', intendedAttack: 'horn scoop', model: '01_Monsters/L02_acorn_tunneler.glb', preview: '01_Monsters/L02_acorn_tunneler.png'),
    LevelRosterEntry(level: 3, district: 'Sunny Orchard', monster: 'Bramble Pup', anatomy: 'wolf', feature: 'thorns', intendedLocomotion: 'bound', intendedAttack: 'pounce', model: '01_Monsters/L03_bramble_pup.glb', preview: '01_Monsters/L03_bramble_pup.png'),
    LevelRosterEntry(level: 4, district: 'Sunny Orchard', monster: 'Dewdrop Snail', anatomy: 'snail', feature: 'dew', intendedLocomotion: 'glide', intendedAttack: 'shell shove', model: '01_Monsters/L04_dewdrop_snail.glb', preview: '01_Monsters/L04_dewdrop_snail.png'),
    LevelRosterEntry(level: 5, district: 'Sunny Orchard', monster: 'Cherrywing', anatomy: 'bat', feature: 'cherry', intendedLocomotion: 'flap', intendedAttack: 'dive', model: '01_Monsters/L05_cherrywing.glb', preview: '01_Monsters/L05_cherrywing.png'),
    LevelRosterEntry(level: 6, district: 'Sunny Orchard', monster: 'Puddle Pouncer', anatomy: 'frog', feature: 'lotus', intendedLocomotion: 'crouch hop', intendedAttack: 'tongue flick', model: '01_Monsters/L06_puddle_pouncer.glb', preview: '01_Monsters/L06_puddle_pouncer.png'),
    LevelRosterEntry(level: 7, district: 'Sunny Orchard', monster: 'Cider Tusk', anatomy: 'boar', feature: 'tusks', intendedLocomotion: 'trot', intendedAttack: 'ram', model: '01_Monsters/L07_cider_tusk.glb', preview: '01_Monsters/L07_cider_tusk.png'),
    LevelRosterEntry(level: 8, district: 'Sunny Orchard', monster: 'Peel Pincher', anatomy: 'crab', feature: 'peel', intendedLocomotion: 'sidestep', intendedAttack: 'pinch', model: '01_Monsters/L08_peel_pincher.glb', preview: '01_Monsters/L08_peel_pincher.png'),
    LevelRosterEntry(level: 9, district: 'Sunny Orchard', monster: 'Honeycomb Scout', anatomy: 'bee', feature: 'honey', intendedLocomotion: 'hover', intendedAttack: 'sting', model: '01_Monsters/L09_honeycomb_scout.glb', preview: '01_Monsters/L09_honeycomb_scout.png'),
    LevelRosterEntry(level: 10, district: 'Sunny Orchard', monster: 'Thistle Roller', anatomy: 'hedgehog', feature: 'spines', intendedLocomotion: 'waddle', intendedAttack: 'roll strike', model: '01_Monsters/L10_thistle_roller.glb', preview: '01_Monsters/L10_thistle_roller.png'),
    LevelRosterEntry(level: 11, district: 'Garden Market', monster: 'Copper Kettle', anatomy: 'golem', feature: 'kettle', intendedLocomotion: 'stomp', intendedAttack: 'hammer blow', model: '01_Monsters/L11_copper_kettle.glb', preview: '01_Monsters/L11_copper_kettle.png'),
    LevelRosterEntry(level: 12, district: 'Garden Market', monster: 'Lantern Moth', anatomy: 'moth', feature: 'lantern', intendedLocomotion: 'flutter', intendedAttack: 'wing flare', model: '01_Monsters/L12_lantern_moth.glb', preview: '01_Monsters/L12_lantern_moth.png'),
    LevelRosterEntry(level: 13, district: 'Garden Market', monster: 'Radish Rook', anatomy: 'bird', feature: 'radish', intendedLocomotion: 'strut', intendedAttack: 'beak peck', model: '01_Monsters/L13_radish_rook.glb', preview: '01_Monsters/L13_radish_rook.png'),
    LevelRosterEntry(level: 14, district: 'Garden Market', monster: 'Market Mimic', anatomy: 'chest', feature: 'latch', intendedLocomotion: 'shuffle', intendedAttack: 'lid snap', model: '01_Monsters/L14_market_mimic.glb', preview: '01_Monsters/L14_market_mimic.png'),
    LevelRosterEntry(level: 15, district: 'Garden Market', monster: 'Noodle Naga', anatomy: 'snake', feature: 'noodles', intendedLocomotion: 'slither', intendedAttack: 'coil lunge', model: '01_Monsters/L15_noodle_naga.glb', preview: '01_Monsters/L15_noodle_naga.png'),
    LevelRosterEntry(level: 16, district: 'Garden Market', monster: 'Spice Scorpion', anatomy: 'scorpion', feature: 'pepper', intendedLocomotion: 'skitter', intendedAttack: 'tail jab', model: '01_Monsters/L16_spice_scorpion.glb', preview: '01_Monsters/L16_spice_scorpion.png'),
    LevelRosterEntry(level: 17, district: 'Garden Market', monster: 'Cabbage Gripper', anatomy: 'octopus', feature: 'cabbage', intendedLocomotion: 'pulse crawl', intendedAttack: 'tentacle sweep', model: '01_Monsters/L17_cabbage_gripper.glb', preview: '01_Monsters/L17_cabbage_gripper.png'),
    LevelRosterEntry(level: 18, district: 'Garden Market', monster: 'Peppercap Imp', anatomy: 'imp', feature: 'pepper', intendedLocomotion: 'skip', intendedAttack: 'head feint', model: '01_Monsters/L18_peppercap_imp.glb', preview: '01_Monsters/L18_peppercap_imp.png'),
    LevelRosterEntry(level: 19, district: 'Garden Market', monster: 'Saffron Fan', anatomy: 'peacock', feature: 'fan', intendedLocomotion: 'parade', intendedAttack: 'fan sweep', model: '01_Monsters/L19_saffron_fan.glb', preview: '01_Monsters/L19_saffron_fan.png'),
    LevelRosterEntry(level: 20, district: 'Garden Market', monster: 'Scale Sentry', anatomy: 'turtle', feature: 'scale', intendedLocomotion: 'trundle', intendedAttack: 'shell bash', model: '01_Monsters/L20_scale_sentry.glb', preview: '01_Monsters/L20_scale_sentry.png'),
    LevelRosterEntry(level: 21, district: 'Forest Food Trail', monster: 'Moss Elk', anatomy: 'deer', feature: 'antlers', intendedLocomotion: 'canter', intendedAttack: 'antler swing', model: '01_Monsters/L21_moss_elk.glb', preview: '01_Monsters/L21_moss_elk.png'),
    LevelRosterEntry(level: 22, district: 'Forest Food Trail', monster: 'Fern Skipper', anatomy: 'mantis', feature: 'fern', intendedLocomotion: 'stalk', intendedAttack: 'sickle slash', model: '01_Monsters/L22_fern_skipper.glb', preview: '01_Monsters/L22_fern_skipper.png'),
    LevelRosterEntry(level: 23, district: 'Forest Food Trail', monster: 'Bark Centipede', anatomy: 'centipede', feature: 'bark', intendedLocomotion: 'ripple march', intendedAttack: 'body sweep', model: '01_Monsters/L23_bark_centipede.glb', preview: '01_Monsters/L23_bark_centipede.png'),
    LevelRosterEntry(level: 24, district: 'Forest Food Trail', monster: 'Ambercap', anatomy: 'mushroom', feature: 'spots', intendedLocomotion: 'bob walk', intendedAttack: 'cap slam', model: '01_Monsters/L24_ambercap.glb', preview: '01_Monsters/L24_ambercap.png'),
    LevelRosterEntry(level: 25, district: 'Forest Food Trail', monster: 'Glasswing Drake', anatomy: 'dragon', feature: 'crystal', intendedLocomotion: 'glide flap', intendedAttack: 'tail whip', model: '01_Monsters/L25_glasswing_drake.glb', preview: '01_Monsters/L25_glasswing_drake.png'),
    LevelRosterEntry(level: 26, district: 'Forest Food Trail', monster: 'Hollow Watcher', anatomy: 'owl', feature: 'hollow', intendedLocomotion: 'swoop', intendedAttack: 'talon rake', model: '01_Monsters/L26_hollow_watcher.glb', preview: '01_Monsters/L26_hollow_watcher.png'),
    LevelRosterEntry(level: 27, district: 'Forest Food Trail', monster: 'Brook Axolotl', anatomy: 'gecko', feature: 'gills', intendedLocomotion: 'belly crawl', intendedAttack: 'gill flare', model: '01_Monsters/L27_brook_axolotl.glb', preview: '01_Monsters/L27_brook_axolotl.png'),
    LevelRosterEntry(level: 28, district: 'Forest Food Trail', monster: 'Pinecone Pangolin', anatomy: 'armadillo', feature: 'scales', intendedLocomotion: 'low trot', intendedAttack: 'curl strike', model: '01_Monsters/L28_pinecone_pangolin.glb', preview: '01_Monsters/L28_pinecone_pangolin.png'),
    LevelRosterEntry(level: 29, district: 'Forest Food Trail', monster: 'Birch Longlegs', anatomy: 'spider', feature: 'birch', intendedLocomotion: 'highstep', intendedAttack: 'leg jab', model: '01_Monsters/L29_birch_longlegs.glb', preview: '01_Monsters/L29_birch_longlegs.png'),
    LevelRosterEntry(level: 30, district: 'Forest Food Trail', monster: 'Root Lantern', anatomy: 'jelly', feature: 'roots', intendedLocomotion: 'float', intendedAttack: 'root lash', model: '01_Monsters/L30_root_lantern.glb', preview: '01_Monsters/L30_root_lantern.png'),
    LevelRosterEntry(level: 31, district: 'Monster Valley', monster: 'Basalt Ram', anatomy: 'sheep', feature: 'curled horns', intendedLocomotion: 'heavy trot', intendedAttack: 'horn crash', model: '01_Monsters/L31_basalt_ram.glb', preview: '01_Monsters/L31_basalt_ram.png'),
    LevelRosterEntry(level: 32, district: 'Monster Valley', monster: 'Lava Bellows', anatomy: 'salamander', feature: 'vents', intendedLocomotion: 'prowl', intendedAttack: 'vent burst', model: '01_Monsters/L32_lava_bellows.glb', preview: '01_Monsters/L32_lava_bellows.png'),
    LevelRosterEntry(level: 33, district: 'Monster Valley', monster: 'Shale Hammer', anatomy: 'gorilla', feature: 'stone', intendedLocomotion: 'knuckle walk', intendedAttack: 'double pound', model: '01_Monsters/L33_shale_hammer.glb', preview: '01_Monsters/L33_shale_hammer.png'),
    LevelRosterEntry(level: 34, district: 'Monster Valley', monster: 'Gale Harrier', anatomy: 'raptor', feature: 'feathers', intendedLocomotion: 'bank', intendedAttack: 'wing cut', model: '01_Monsters/L34_gale_harrier.glb', preview: '01_Monsters/L34_gale_harrier.png'),
    LevelRosterEntry(level: 35, district: 'Monster Valley', monster: 'Frostwhisker', anatomy: 'walrus', feature: 'ice', intendedLocomotion: 'heave', intendedAttack: 'tusk thrust', model: '01_Monsters/L35_frostwhisker.glb', preview: '01_Monsters/L35_frostwhisker.png'),
    LevelRosterEntry(level: 36, district: 'Monster Valley', monster: 'Rift Ray', anatomy: 'ray', feature: 'rift', intendedLocomotion: 'undulate', intendedAttack: 'sweeping dive', model: '01_Monsters/L36_rift_ray.glb', preview: '01_Monsters/L36_rift_ray.png'),
    LevelRosterEntry(level: 37, district: 'Monster Valley', monster: 'Copperback Hydra', anatomy: 'hydra', feature: 'copper', intendedLocomotion: 'weave', intendedAttack: 'triple snap', model: '01_Monsters/L37_copperback_hydra.glb', preview: '01_Monsters/L37_copperback_hydra.png'),
    LevelRosterEntry(level: 38, district: 'Monster Valley', monster: 'Crag Lynx', anatomy: 'cat', feature: 'tufts', intendedLocomotion: 'slink', intendedAttack: 'claw swipe', model: '01_Monsters/L38_crag_lynx.glb', preview: '01_Monsters/L38_crag_lynx.png'),
    LevelRosterEntry(level: 39, district: 'Monster Valley', monster: 'Quake Clam', anatomy: 'clam', feature: 'pearl', intendedLocomotion: 'rock', intendedAttack: 'shell clap', model: '01_Monsters/L39_quake_clam.glb', preview: '01_Monsters/L39_quake_clam.png'),
    LevelRosterEntry(level: 40, district: 'Monster Valley', monster: 'Thunder Totem', anatomy: 'totem', feature: 'bolt', intendedLocomotion: 'hover step', intendedAttack: 'drop slam', model: '01_Monsters/L40_thunder_totem.glb', preview: '01_Monsters/L40_thunder_totem.png'),
    LevelRosterEntry(level: 41, district: 'Grand Delivery City', monster: 'Signal Cyclops', anatomy: 'robot', feature: 'aerial', intendedLocomotion: 'march', intendedAttack: 'piston punch', model: '01_Monsters/L41_signal_cyclops.glb', preview: '01_Monsters/L41_signal_cyclops.png'),
    LevelRosterEntry(level: 42, district: 'Grand Delivery City', monster: 'Neon Coil', anatomy: 'eel', feature: 'fins', intendedLocomotion: 'sidewind', intendedAttack: 'electric lunge', model: '01_Monsters/L42_neon_coil.glb', preview: '01_Monsters/L42_neon_coil.png'),
    LevelRosterEntry(level: 43, district: 'Grand Delivery City', monster: 'Rivet Hound', anatomy: 'hound', feature: 'rivets', intendedLocomotion: 'gallop', intendedAttack: 'jaw snap', model: '01_Monsters/L43_rivet_hound.glb', preview: '01_Monsters/L43_rivet_hound.png'),
    LevelRosterEntry(level: 44, district: 'Grand Delivery City', monster: 'Market Craner', anatomy: 'crane', feature: 'stripe', intendedLocomotion: 'tiptoe', intendedAttack: 'spear peck', model: '01_Monsters/L44_market_craner.glb', preview: '01_Monsters/L44_market_craner.png'),
    LevelRosterEntry(level: 45, district: 'Grand Delivery City', monster: 'Velvet Glider', anatomy: 'squirrel', feature: 'sail', intendedLocomotion: 'leap', intendedAttack: 'glide tackle', model: '01_Monsters/L45_velvet_glider.glb', preview: '01_Monsters/L45_velvet_glider.png'),
    LevelRosterEntry(level: 46, district: 'Grand Delivery City', monster: 'Boiler Bison', anatomy: 'bison', feature: 'steam', intendedLocomotion: 'tramp', intendedAttack: 'shoulder rush', model: '01_Monsters/L46_boiler_bison.glb', preview: '01_Monsters/L46_boiler_bison.png'),
    LevelRosterEntry(level: 47, district: 'Grand Delivery City', monster: 'Clockwork Koi', anatomy: 'fish', feature: 'gear', intendedLocomotion: 'flying swim', intendedAttack: 'fin slap', model: '01_Monsters/L47_clockwork_koi.glb', preview: '01_Monsters/L47_clockwork_koi.png'),
    LevelRosterEntry(level: 48, district: 'Grand Delivery City', monster: 'Night Hopper', anatomy: 'kangaroo', feature: 'visor', intendedLocomotion: 'vault', intendedAttack: 'heel kick', model: '01_Monsters/L48_night_hopper.glb', preview: '01_Monsters/L48_night_hopper.png'),
    LevelRosterEntry(level: 49, district: 'Grand Delivery City', monster: 'Metro Mole', anatomy: 'mole', feature: 'drill', intendedLocomotion: 'dig walk', intendedAttack: 'drill nudge', model: '01_Monsters/L49_metro_mole.glb', preview: '01_Monsters/L49_metro_mole.png'),
    LevelRosterEntry(level: 50, district: 'Grand Delivery City', monster: 'Crownwing Warden', anatomy: 'griffin', feature: 'crown', intendedLocomotion: 'royal stride', intendedAttack: 'crest dive', model: '01_Monsters/L50_crownwing_warden.glb', preview: '01_Monsters/L50_crownwing_warden.png'),
  ];

  static LevelRosterEntry forLevel(int levelId) {
    final idx = (levelId - 1).clamp(0, entries.length - 1);
    return entries[idx];
  }

  static LevelRosterEntry? byModelId(String id) {
    final clean = id.split('/').last.replaceAll('.glb', '').replaceAll('.png', '').toLowerCase();
    for (final e in entries) {
      if (e.primaryModelId.toLowerCase() == clean) return e;
    }
    return null;
  }
}

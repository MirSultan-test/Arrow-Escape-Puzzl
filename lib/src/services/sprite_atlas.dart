import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../models/maze/combat_models.dart';
import '../models/maze/level_roster.dart';
import '../models/maze/monster.dart';

/// Preloads and caches high-resolution painted 2.5D character and 50 Nightfall monster PNG sprites
/// as GPU-ready [ui.Image] textures for silky 60 FPS canvas rendering.
class SpriteAtlas {
  SpriteAtlas._();

  static final SpriteAtlas instance = SpriteAtlas._();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  ui.Image? heroCasual;
  ui.Image? heroArcher;
  ui.Image? heroBlaster;
  ui.Image? collector;
  final Map<MonsterType, ui.Image> monsters = {};
  final Map<String, ui.Image> _monsterArtKitSprites = {};

  /// Loads all bundled 2.5D character & 50 Nightfall monster sprites once at startup.
  /// Gracefully ignores missing assets in headless unit test environments.
  Future<void> preloadAll() async {
    if (_isLoaded) return;

    Future<ui.Image?> loadImg(String assetPath) async {
      try {
        final data = await rootBundle.load(assetPath);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        return frame.image;
      } catch (_) {
        return null;
      }
    }

    // 1. Preload Hero & Collector sprites
    final heroResults = await Future.wait<ui.Image?>([
      loadImg('assets/sprites/hero_casual.png'),
      loadImg('assets/sprites/hero_archer.png'),
      loadImg('assets/sprites/hero_blaster.png'),
      loadImg('assets/sprites/collector_worker.png'),
      loadImg('assets/sprites/monster_red_hunter.png'),
      loadImg('assets/sprites/monster_shadow_crawler.png'),
      loadImg('assets/sprites/monster_forest_brute.png'),
      loadImg('assets/sprites/monster_flying_creature.png'),
      loadImg('assets/sprites/monster_mushroom_beast.png'),
      loadImg('assets/sprites/monster_maze_guardian.png'),
    ]);

    heroCasual = heroResults[0];
    heroArcher = heroResults[1];
    heroBlaster = heroResults[2];
    collector = heroResults[3];

    if (heroResults[4] != null) monsters[MonsterType.redHunter] = heroResults[4]!;
    if (heroResults[5] != null) monsters[MonsterType.shadowCrawler] = heroResults[5]!;
    if (heroResults[6] != null) monsters[MonsterType.forestBrute] = heroResults[6]!;
    if (heroResults[7] != null) monsters[MonsterType.flyingCreature] = heroResults[7]!;
    if (heroResults[8] != null) monsters[MonsterType.mushroomBeast] = heroResults[8]!;
    if (heroResults[9] != null) monsters[MonsterType.mazeGuardian] = heroResults[9]!;

    // 2. Preload all 50 Nightfall L01–L50 Monster Sprites in parallel
    final monsterLoads = <Future<void>>[];
    for (final entry in LevelRosterCatalog.entries) {
      monsterLoads.add(() async {
        final img = await loadImg(entry.previewAssetPath);
        if (img != null) {
          _registerMonsterImage(entry.primaryModelId, img);
          _registerMonsterImage(entry.previewAssetPath, img);
          _registerMonsterImage(entry.preview, img);
        }
      }());
    }
    await Future.wait(monsterLoads);

    _isLoaded = true;
  }

  void _registerMonsterImage(String key, ui.Image img) {
    _monsterArtKitSprites[key] = img;
    final clean = key.split('/').last.replaceAll('.png', '').replaceAll('.glb', '');
    _monsterArtKitSprites[clean] = img;
  }

  /// Registers a pre-decoded monster image into the atlas cache.
  void registerMonsterImage(String key, ui.Image img) => _registerMonsterImage(key, img);

  /// Synchronously retrieves a preloaded 2.5D monster sprite texture by model ID or asset path.
  ui.Image? getMonsterArt(String? key) {
    if (key == null || key.isEmpty) return null;
    if (_monsterArtKitSprites.containsKey(key)) {
      return _monsterArtKitSprites[key];
    }
    final clean = key.split('/').last.replaceAll('.png', '').replaceAll('.glb', '');
    return _monsterArtKitSprites[clean];
  }

  /// Synchronously retrieves the authentic 2.5D monster sprite for a given level (1..50).
  ui.Image? monsterSpriteForLevel(int levelId) {
    final roster = LevelRosterCatalog.forLevel(levelId);
    return getMonsterArt(roster.primaryModelId);
  }

  /// On-demand loader with memory caching for specific level monster assets.
  Future<ui.Image?> loadMonsterSprite(String assetPath) async {
    final existing = getMonsterArt(assetPath);
    if (existing != null) return existing;
    try {
      final data = await rootBundle.load(assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final img = frame.image;
      _registerMonsterImage(assetPath, img);
      return img;
    } catch (_) {
      return null;
    }
  }

  /// Selects the matching painted 2.5D hero sprite based on active weapon or skin preference.
  ui.Image? heroSpriteFor({
    required WeaponType? equippedWeapon,
    String skinPreference = 'auto',
  }) {
    if (skinPreference == 'archer' && heroArcher != null) return heroArcher;
    if (skinPreference == 'casual' && heroCasual != null) {
      if (equippedWeapon == WeaponType.energyBlaster && heroBlaster != null) {
        return heroBlaster;
      }
      return heroCasual;
    }
    // Auto mode: dynamically matches hero pose to active weapon!
    if (equippedWeapon == WeaponType.energyBlaster && heroBlaster != null) {
      return heroBlaster;
    }
    if (equippedWeapon == WeaponType.bow && heroArcher != null) {
      return heroArcher;
    }
    return heroCasual ?? heroArcher;
  }

  ui.Image? monsterSpriteFor(MonsterType type) => monsters[type];
}

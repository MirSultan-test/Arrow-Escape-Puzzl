import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '../models/maze/combat_models.dart';
import '../models/maze/monster.dart';

/// Preloads and caches high-resolution painted 2.5D character and monster PNG sprites
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

  /// Loads all bundled 2.5D character & monster sprites once at startup.
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

    final results = await Future.wait<ui.Image?>([
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

    heroCasual = results[0];
    heroArcher = results[1];
    heroBlaster = results[2];
    collector = results[3];

    if (results[4] != null) monsters[MonsterType.redHunter] = results[4]!;
    if (results[5] != null) monsters[MonsterType.shadowCrawler] = results[5]!;
    if (results[6] != null) monsters[MonsterType.forestBrute] = results[6]!;
    if (results[7] != null) monsters[MonsterType.flyingCreature] = results[7]!;
    if (results[8] != null) monsters[MonsterType.mushroomBeast] = results[8]!;
    if (results[9] != null) monsters[MonsterType.mazeGuardian] = results[9]!;

    _isLoaded = true;
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

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Manages sound effects, background music, and tactile haptic feedback.
class AudioController {
  bool soundEnabled;
  bool musicEnabled;
  bool hapticsEnabled;
  final bool enableAudio;

  AudioPlayer? _sfxPlayer;
  AudioPlayer? _bgmPlayer;
  bool _isBackgrounded = false;
  bool _bgmStarted = false;

  AudioController({
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.hapticsEnabled = true,
    this.enableAudio = true,
    AudioPlayer? player,
    AudioPlayer? bgmPlayer,
  })  : _sfxPlayer = player,
        _bgmPlayer = bgmPlayer {
    if (enableAudio) {
      if (_sfxPlayer == null) {
        try {
          _sfxPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        } catch (_) {
          _sfxPlayer = null;
        }
      }
      if (_bgmPlayer == null) {
        try {
          _bgmPlayer = AudioPlayer()
            ..setReleaseMode(ReleaseMode.loop)
            ..setVolume(0.28);
        } catch (_) {
          _bgmPlayer = null;
        }
      }
    }
  }

  /// Starts or stops background music based on [musicEnabled] and lifecycle state.
  Future<void> syncBgm() async {
    if (_bgmPlayer == null || !enableAudio) return;
    try {
      if (musicEnabled && !_isBackgrounded) {
        if (!_bgmStarted) {
          _bgmStarted = true;
          await _bgmPlayer!.play(AssetSource('audio/bgm.wav'));
        } else {
          await _bgmPlayer!.resume();
        }
      } else {
        await _bgmPlayer!.pause();
      }
    } catch (_) {
      // Audio playback errors are non-fatal
    }
  }

  /// Called when the app transitions to background or an overlay pauses gameplay.
  void pauseAll() {
    _isBackgrounded = true;
    try {
      _sfxPlayer?.pause();
      _bgmPlayer?.pause();
    } catch (_) {}
  }

  /// Called when the app returns to foreground.
  void resumeAll() {
    _isBackgrounded = false;
    syncBgm();
  }

  Future<void> _playSfx(String path) async {
    if (!soundEnabled || _isBackgrounded || _sfxPlayer == null) return;
    try {
      await _sfxPlayer!.stop();
      await _sfxPlayer!.play(AssetSource(path));
    } catch (_) {
      // Non-fatal in headless or unavailable audio environments
    }
  }

  void _haptic(Future<void> Function() fn) {
    if (!hapticsEnabled || !enableAudio) return;
    try {
      fn();
    } catch (_) {}
  }

  Future<void> playTap() async {
    _haptic(HapticFeedback.selectionClick);
    await _playSfx('audio/tap.wav');
  }

  Future<void> playPickup() async {
    _haptic(HapticFeedback.lightImpact);
    await _playSfx('audio/pickup.wav');
  }

  Future<void> playWarning() async {
    _haptic(HapticFeedback.selectionClick);
    await _playSfx('audio/warning.wav');
  }

  Future<void> playBite() async {
    _haptic(HapticFeedback.heavyImpact);
    await _playSfx('audio/bite.wav');
  }

  Future<void> playDeliver() async {
    _haptic(HapticFeedback.mediumImpact);
    await _playSfx('audio/deliver.wav');
  }

  Future<void> playTruck() async {
    _haptic(HapticFeedback.lightImpact);
    await _playSfx('audio/truck.wav');
  }

  Future<void> playWin() async {
    _haptic(HapticFeedback.heavyImpact);
    await _playSfx('audio/win.wav');
  }

  Future<void> playDefeat() async {
    _haptic(HapticFeedback.mediumImpact);
    await _playSfx('audio/defeat.wav');
  }

  Future<void> playTick() async {
    await _playSfx('audio/tick.wav');
  }

  // Legacy aliases retained for compatibility
  Future<void> playExit() => playDeliver();
  Future<void> playBump() => playBite();

  void dispose() {
    try {
      _sfxPlayer?.dispose();
      _bgmPlayer?.dispose();
    } catch (_) {}
  }
}

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'preferences_service.dart';

class SoundService {
  static final _correctPlayer = AudioPlayer();
  static final _wrongPlayer = AudioPlayer();
  static final _levelUpPlayer = AudioPlayer();
  static final _gameOverPlayer = AudioPlayer();
  static final _bgMusicPlayer = AudioPlayer();
  static final _ticTocPlayer = AudioPlayer();

  static bool _initialized = false;

  /// Configures all players once.
  /// SFX players use AndroidAudioFocus.none so they never steal focus from
  /// the background music player — Android then mixes the streams together.
  static Future<void> _ensureInit() async {
    if (_initialized) return;

    final sfxContext = AudioContext(
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
        usageType: AndroidUsageType.game,
        contentType: AndroidContentType.sonification,
      ),
    );
    await _correctPlayer.setAudioContext(sfxContext);
    await _wrongPlayer.setAudioContext(sfxContext);
    await _levelUpPlayer.setAudioContext(sfxContext);
    await _gameOverPlayer.setAudioContext(sfxContext);
    await _ticTocPlayer.setAudioContext(sfxContext);

    await _bgMusicPlayer.setReleaseMode(ReleaseMode.loop);
    await _ticTocPlayer.setReleaseMode(ReleaseMode.loop);

    _initialized = true;
    debugPrint('[Sound] initialized');
  }

  static Future<void> playCorrect() async {
    try {
      if (!await PreferencesService.getSoundsEnabled()) return;
      await _ensureInit();
      await _correctPlayer.stop();
      await _correctPlayer.play(AssetSource('sounds/correct.wav'));
    } catch (e) {
      debugPrint('[Sound] playCorrect error: $e');
    }
  }

  static Future<void> playWrong() async {
    try {
      if (!await PreferencesService.getSoundsEnabled()) return;
      await _ensureInit();
      await _wrongPlayer.stop();
      await _wrongPlayer.play(AssetSource('sounds/wrong.mp3'));
    } catch (e) {
      debugPrint('[Sound] playWrong error: $e');
    }
  }

  static Future<void> playLevelUp() async {
    try {
      if (!await PreferencesService.getSoundsEnabled()) return;
      await _ensureInit();
      await _levelUpPlayer.stop();
      await _levelUpPlayer.play(AssetSource('sounds/levelup.wav'));
    } catch (e) {
      debugPrint('[Sound] playLevelUp error: $e');
    }
  }

  static Future<void> playGameOver() async {
    try {
      if (!await PreferencesService.getSoundsEnabled()) return;
      await _ensureInit();
      await _gameOverPlayer.stop();
      await _gameOverPlayer.play(AssetSource('sounds/gameover.wav'));
    } catch (e) {
      debugPrint('[Sound] playGameOver error: $e');
    }
  }

  static Future<void> startBackgroundMusic() async {
    try {
      if (!await PreferencesService.getMusicEnabled()) return;
      await _ensureInit();
      await _bgMusicPlayer.stop();
      await _bgMusicPlayer.setVolume(0.4);
      await _bgMusicPlayer.play(AssetSource('sounds/backgroundmusic.wav'));
    } catch (e) {
      debugPrint('[Sound] startBackgroundMusic error: $e');
    }
  }

  static Future<void> stopBackgroundMusic() async {
    try {
      await _bgMusicPlayer.stop();
    } catch (e) {
      debugPrint('[Sound] stopBackgroundMusic error: $e');
    }
  }

  static Future<void> startTicToc() async {
    try {
      if (!await PreferencesService.getSoundsEnabled()) return;
      await _ensureInit();
      await _ticTocPlayer.stop();
      await _ticTocPlayer.play(AssetSource('sounds/tictoc.wav'));
    } catch (e) {
      debugPrint('[Sound] startTicToc error: $e');
    }
  }

  static Future<void> stopTicToc() async {
    try {
      await _ticTocPlayer.stop();
    } catch (e) {
      debugPrint('[Sound] stopTicToc error: $e');
    }
  }

  /// Stops all active sounds when the game screen is dismissed.
  static Future<void> dispose() async {
    await _bgMusicPlayer.stop();
    await _ticTocPlayer.stop();
    await _correctPlayer.stop();
    await _wrongPlayer.stop();
    await _levelUpPlayer.stop();
    await _gameOverPlayer.stop();
  }
}

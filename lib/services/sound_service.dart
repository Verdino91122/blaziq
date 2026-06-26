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

  // Cached preference values — updated at game start and on every toggle change.
  // Synchronous checks here match the same pattern used for haptics per CLAUDE.md.
  static bool _soundsEnabled = true;
  static bool _musicEnabled = true;

  /// Load both preferences from disk. Call at game start and after Settings changes.
  static Future<void> syncPreferences() async {
    _soundsEnabled = await PreferencesService.getSoundsEnabled();
    _musicEnabled = await PreferencesService.getMusicEnabled();
  }

  /// Update cached values immediately (called by the Settings toggle before the
  /// async disk write completes, so play calls see the new state right away).
  static void applyPreferences({bool? soundsEnabled, bool? musicEnabled}) {
    if (soundsEnabled != null) _soundsEnabled = soundsEnabled;
    if (musicEnabled != null) _musicEnabled = musicEnabled;
  }

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
    if (!_soundsEnabled) return;
    try {
      await _ensureInit();
      await _correctPlayer.stop();
      await _correctPlayer.play(AssetSource('sounds/correct.wav'));
    } catch (e) {
      debugPrint('[Sound] playCorrect error: $e');
    }
  }

  static Future<void> playWrong() async {
    if (!_soundsEnabled) return;
    try {
      await _ensureInit();
      await _wrongPlayer.stop();
      await _wrongPlayer.play(AssetSource('sounds/wrong.mp3'));
    } catch (e) {
      debugPrint('[Sound] playWrong error: $e');
    }
  }

  static Future<void> playLevelUp() async {
    if (!_soundsEnabled) return;
    try {
      await _ensureInit();
      await _levelUpPlayer.stop();
      await _levelUpPlayer.play(AssetSource('sounds/levelup.wav'));
    } catch (e) {
      debugPrint('[Sound] playLevelUp error: $e');
    }
  }

  static Future<void> playGameOver() async {
    if (!_soundsEnabled) return;
    try {
      await _ensureInit();
      await _gameOverPlayer.stop();
      await _gameOverPlayer.play(AssetSource('sounds/gameover.wav'));
    } catch (e) {
      debugPrint('[Sound] playGameOver error: $e');
    }
  }

  static Future<void> startBackgroundMusic() async {
    if (!_musicEnabled) return;
    try {
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
    if (!_soundsEnabled) return;
    try {
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

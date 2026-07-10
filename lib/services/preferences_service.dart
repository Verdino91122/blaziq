import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keySounds = 'sounds_enabled';
  static const _keyMusic = 'music_enabled';
  static const _keyHaptics = 'haptics_enabled';
  static const _keyQuestionLanguage = 'preferred_question_language';

  /// Last question language the user picked ('en' or 'fr'). Default: English.
  static Future<String> getQuestionLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyQuestionLanguage) ?? 'en';
  }

  static Future<void> setQuestionLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuestionLanguage, language);
  }

  static Future<bool> getSoundsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keySounds) ?? true;
  }

  static Future<bool> getMusicEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMusic) ?? true;
  }

  static Future<bool> getHapticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHaptics) ?? true;
  }

  static Future<void> setSoundsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySounds, value);
  }

  static Future<void> setMusicEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMusic, value);
  }

  static Future<void> setHapticsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, value);
  }
}

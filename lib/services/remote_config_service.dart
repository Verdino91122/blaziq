import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Thin wrapper around Firebase Remote Config.
///
/// Used to gate Friend Mode behind a minimum app version so users on old
/// builds (with incompatible room data structures) see an update prompt
/// instead of a silent failure.
class RemoteConfigService {
  static const _keyMinFriendModeVersion = 'minimum_friend_mode_version';

  /// Initializes, sets in-app defaults, and fetches the latest config.
  /// Fire-and-forget from main() — swallows all errors so a Remote Config
  /// outage can never block app startup; the in-app default (1) applies.
  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.setDefaults(const {_keyMinFriendModeVersion: 1});
      await rc.fetchAndActivate();
    } catch (_) {
      // Defaults / last activated values still apply.
    }
  }

  /// Minimum app build number allowed to use Friend Mode.
  /// Returns the in-app default (1) if Remote Config is unavailable.
  static int getMinimumFriendModeVersion() {
    try {
      final value =
          FirebaseRemoteConfig.instance.getInt(_keyMinFriendModeVersion);
      return value > 0 ? value : 1;
    } catch (_) {
      return 1;
    }
  }
}

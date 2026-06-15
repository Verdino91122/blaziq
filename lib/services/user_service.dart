import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

class UserService {
  static final _db = FirebaseFirestore.instance;

  // ── Country detection ──────────────────────────────────────────────────────

  /// Calls ip-api.com to get the device's country code.
  /// Returns the ISO 3166-1 alpha-2 code (e.g. 'US', 'CA') or empty string on failure.
  /// ip-api.com free tier is HTTP-only; cleartext for that domain is permitted
  /// via android/app/src/main/res/xml/network_security_config.xml.
  static Future<String> _detectCountry() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json?fields=status,countryCode'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'success') {
          return (data['countryCode'] as String?) ?? '';
        }
      }
    } catch (_) {}
    return '';
  }

  /// Returns true if the device locale suggests the user is in Canada.
  /// Used to avoid re-detecting users who legitimately have country='CA'.
  static bool _localeIsCanada() {
    try {
      return PlatformDispatcher.instance.locale.countryCode == 'CA';
    } catch (_) {
      return false;
    }
  }

  /// Called on app launch for existing users whose country is 'CA'.
  /// 'CA' was hardcoded as the default before IP detection was added, so most
  /// users with 'CA' may not actually be in Canada. Re-detects via IP and
  /// updates Firestore if the real country differs — unless the device locale
  /// already confirms Canada, to avoid unnecessary API calls for real Canadians.
  static Future<void> refreshCountryIfStale(String uid) async {
    try {
      final ref = _db.collection('users').doc(uid);
      final doc = await ref.get();
      if (!doc.exists) return;
      final country = (doc.data()?['country'] as String?) ?? '';
      if (country != 'CA') return; // already properly detected
      if (_localeIsCanada()) return; // locale confirms Canada — trust it
      final detected = await _detectCountry();
      if (detected.isNotEmpty && detected != country) {
        await ref.update({'country': detected});
      }
    } catch (_) {}
  }

  // ── User doc ──────────────────────────────────────────────────────────────

  /// Creates the Firestore user doc on first sign-in. No-op if it already exists.
  /// Anonymous users get a minimal doc (no username/displayName — name picker fills those).
  /// Google users get a full doc with username from their Google profile.
  static Future<void> ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      final country = await _detectCountry();
      if (user.isAnonymous) {
        await ref.set({
          'email': '',
          'coins': 0,
          'jokers': 0,
          'xp': 0,
          'level': 1,
          'gamesPlayed': 0,
          'bestScore': 0,
          'country': country,
          'isAnonymous': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Reload to ensure the display name is available (can be null on first
        // sign-in before the token is fully propagated).
        await user.reload();
        final freshUser = FirebaseAuth.instance.currentUser;
        final username = freshUser?.displayName ??
            user.displayName ??
            user.email?.split('@')[0] ??
            'Player';
        await ref.set({
          'username': username,
          'email': user.email ?? '',
          'coins': 200,
          'jokers': 0,
          'xp': 0,
          'level': 1,
          'gamesPlayed': 0,
          'bestScore': 0,
          'country': country,
          'isAnonymous': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  /// Updates an existing (formerly anonymous) doc with Google identity fields
  /// and awards the 200-coin linking reward.
  static Future<void> upgradeToGoogle(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final email = user.email ?? '';
    final displayName = user.displayName;
    final username = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (email.isNotEmpty ? email.split('@')[0] : 'Player');
    await ref.update({
      'username': username,
      'email': email,
      'isAnonymous': false,
      'coins': FieldValue.increment(200),
    });
    try {
      await _db.collection('leaderboard').doc(user.uid).update({'username': username});
    } catch (_) {}
  }

  /// Merges an anonymous user's progress into an existing Google account doc
  /// after a link-credential-already-in-use fallback. Also awards the linking reward.
  static Future<void> mergeAnonData({
    required String googleUid,
    required Map<String, dynamic> anonData,
  }) async {
    final ref = _db.collection('users').doc(googleUid);
    final doc = await ref.get();
    if (!doc.exists) return;

    final existingData = doc.data()!;
    final anonXp = (anonData['xp'] as int?) ?? 0;
    final anonGames = (anonData['gamesPlayed'] as int?) ?? 0;
    final anonBest = (anonData['bestScore'] as int?) ?? 0;
    final currentXp = (existingData['xp'] as int?) ?? 0;
    final currentBest = (existingData['bestScore'] as int?) ?? 0;

    final newXp = currentXp + anonXp;
    final newLevel = levelForXp(newXp);

    final updates = <String, dynamic>{
      'xp': newXp,
      'level': newLevel,
      'gamesPlayed': FieldValue.increment(anonGames),
      'coins': FieldValue.increment(200), // linking reward
    };
    if (anonBest > currentBest) {
      updates['bestScore'] = anonBest;
    }

    await ref.update(updates);
  }

  /// Deletes the Firestore doc for a given UID (used to clean up orphaned anon docs).
  static Future<void> deleteUserDoc(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  /// Real-time stream of the user's Firestore document.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  /// One-shot fetch of user data.
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Updates the username field for a user.
  /// Uses set+merge so it works even if the doc hasn't been created yet.
  static Future<void> updateUsername(String uid, String username) async {
    await _db
        .collection('users')
        .doc(uid)
        .set({'username': username}, SetOptions(merge: true));
  }

  // ── Level / XP math ───────────────────────────────────────────────────────

  /// Cumulative XP needed to reach level [level] (level 1 = 0).
  static int xpThreshold(int level) {
    if (level <= 1) return 0;
    return (100 * level * 1.5).round();
  }

  /// Returns the level a player is at given their total XP.
  static int levelForXp(int totalXp) {
    int level = 1;
    while (xpThreshold(level + 1) <= totalXp) {
      level++;
    }
    return level;
  }

  /// Display title for a given level number.
  static String titleForLevel(int level) {
    if (level >= 50) return 'LEGEND';
    if (level >= 20) return 'MASTER';
    if (level >= 10) return 'EXPERT';
    if (level >= 5) return 'CHALLENGER';
    return 'ROOKIE';
  }

  // ── Daily bonus helper ────────────────────────────────────────────────────

  static String _todayString() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// True if the user has not yet played a game today.
  static bool isFirstGameToday(Map<String, dynamic>? data) {
    if (data == null) return true;
    final last = data['lastPlayedDate'] as String?;
    if (last == null) return true;
    return last != _todayString();
  }

  // ── Game result save ──────────────────────────────────────────────────────

  /// Writes game rewards to the user's Firestore document and updates the
  /// leaderboard if the score beats the player's previous best.
  static Future<void> saveGameResult({
    required String uid,
    required int score,
    required int xpEarned,
    required int coinsEarned,
    required bool isAnonymous,
    required String avatarUrl,
  }) async {
    final ref = _db.collection('users').doc(uid);

    // Lazy-creation fallback in case ensureUserDoc was never called.
    final doc = await ref.get();
    if (!doc.exists) {
      final country = await _detectCountry();
      await ref.set({
        if (!isAnonymous) 'username': 'Player',
        'email': '',
        'coins': 0,
        'jokers': 0,
        'xp': 0,
        'level': 1,
        'gamesPlayed': 0,
        'bestScore': 0,
        'country': country,
        'isAnonymous': isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final fresh = await ref.get();
    final data = fresh.data() ?? {};
    final currentXp = (data['xp'] as int?) ?? 0;
    final currentBest = (data['bestScore'] as int?) ?? 0;
    final newXp = currentXp + xpEarned;
    final newLevel = levelForXp(newXp);

    final updates = <String, dynamic>{
      'xp': newXp,
      'level': newLevel,
      'coins': FieldValue.increment(coinsEarned),
      'gamesPlayed': FieldValue.increment(1),
      'lastPlayedDate': _todayString(),
    };
    if (score > currentBest) {
      updates['bestScore'] = score;
    }

    await ref.update(updates);

    // Always sync the leaderboard using the effective best score.
    // Using max(score, currentBest) ensures existing users whose bestScore
    // predates Phase 4 get a leaderboard entry seeded immediately, even when
    // the current game doesn't beat their personal best.
    final effectiveBest = score > currentBest ? score : currentBest;
    if (effectiveBest > 0) {
      final displayName = (data['displayName'] as String?) ??
          (data['username'] as String?) ??
          'Player';
      final rawCountry = (data['country'] as String?) ?? '';
      final country = rawCountry.isNotEmpty ? rawCountry : await _detectCountry();
      await updateLeaderboard(
        uid: uid,
        score: effectiveBest,
        displayName: displayName,
        avatarUrl: avatarUrl,
        country: country,
      );
    }
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────

  /// Writes to the leaderboard collection only if [score] beats the existing
  /// entry. Safe to call redundantly — the check guards against unnecessary writes.
  static Future<void> updateLeaderboard({
    required String uid,
    required int score,
    required String displayName,
    required String avatarUrl,
    required String country,
  }) async {
    final ref = _db.collection('leaderboard').doc(uid);
    final existing = await ref.get();
    final currentScore = (existing.data()?['score'] as num?)?.toInt() ?? 0;
    if (!existing.exists || score > currentScore) {
      await ref.set({
        'displayName': displayName,
        'score': score,
        'country': country,
        'avatarUrl': avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Updates only the displayName field on an existing leaderboard doc.
  /// Safe to call after a name change — no-op if the doc doesn't exist yet.
  static Future<void> syncLeaderboardDisplayName(
      String uid, String displayName) async {
    try {
      await _db
          .collection('leaderboard')
          .doc(uid)
          .update({'displayName': displayName});
    } catch (_) {}
  }

  /// Live stream of the leaderboard collection ordered by score descending.
  static Stream<QuerySnapshot<Map<String, dynamic>>> leaderboardStream() {
    return _db
        .collection('leaderboard')
        .orderBy('score', descending: true)
        .snapshots();
  }

  // ── Username repair ───────────────────────────────────────────────────────

  /// Fixes a Google user's username if it was stored as 'Player' because
  /// Firebase Auth hadn't propagated the display name at sign-in time.
  /// Calls [User.reload] when displayName is null, then falls back to the
  /// email prefix so 'Player' is never kept as a permanent username.
  /// Updates the leaderboard entry too if it also shows 'Player'.
  /// Fire-and-forget safe — all errors are caught internally.
  static Future<void> fixPlayerUsername(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;

      final ref = _db.collection('users').doc(uid);
      final doc = await ref.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final currentUsername = (data['username'] as String?) ?? '';
      if (currentUsername.isNotEmpty && currentUsername != 'Player') return;

      // displayName can be null on launch if the token hasn't propagated yet.
      String? displayName = user.displayName;
      if (displayName == null || displayName.isEmpty) {
        await user.reload();
        displayName = FirebaseAuth.instance.currentUser?.displayName;
      }

      final email = user.email ?? (data['email'] as String?) ?? '';
      final chosen = (displayName != null && displayName.isNotEmpty)
          ? displayName
          : (email.isNotEmpty ? email.split('@')[0] : null);

      debugPrint('[Blaziq] fixPlayerUsername: '
          'current="$currentUsername" '
          'authDisplayName="$displayName" '
          'email="$email" '
          'chosen="${chosen ?? 'none — skipping'}"');

      if (chosen == null || chosen.isEmpty) return;

      await ref.update({'username': chosen});

      // Keep the leaderboard username in sync.
      try {
        await _db.collection('leaderboard').doc(uid).update({'username': chosen});
      } catch (_) {}
    } catch (e) {
      debugPrint('[Blaziq] fixPlayerUsername error: $e');
    }
  }
}

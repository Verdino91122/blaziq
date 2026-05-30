import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  // ── User doc ──────────────────────────────────────────────────────────────

  /// Creates the Firestore user doc on first sign-in. No-op if it already exists.
  /// Anonymous users get a generated username; Google users use their display name.
  static Future<void> ensureUserDoc(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      final username = user.isAnonymous
          ? 'Guest_${user.uid.substring(0, 6)}'
          : (user.displayName ?? 'Player');
      await ref.set({
        'username': username,
        'email': user.email ?? '',
        'coins': 200,
        'jokers': 0,
        'xp': 0,
        'level': 1,
        'gamesPlayed': 0,
        'bestScore': 0,
        'country': '',
        'isAnonymous': user.isAnonymous,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Updates an existing (formerly anonymous) doc with Google identity fields
  /// and awards the 200-coin linking reward.
  static Future<void> upgradeToGoogle(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    await ref.update({
      'username': user.displayName ?? 'Player',
      'email': user.email ?? '',
      'isAnonymous': false,
      'coins': FieldValue.increment(200),
    });
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

  /// Writes game rewards to the user's Firestore document:
  /// - Increments coins and gamesPlayed
  /// - Adds xpEarned to total XP and recalculates level
  /// - Updates bestScore only if [score] is higher
  /// - Stores lastPlayedDate for the daily coin bonus
  static Future<void> saveGameResult({
    required String uid,
    required int score,
    required int xpEarned,
    required int coinsEarned,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    final data = doc.data() ?? {};

    final currentXp = (data['xp'] as int?) ?? 0;
    final currentBest = (data['bestScore'] as int?) ?? 0;
    final newXp = currentXp + xpEarned;
    final newLevel = levelForXp(newXp);

    if (!doc.exists) {
      // Doc missing (e.g. ensureUserDoc never completed) — create it with
      // the starting 200 coins plus this game's rewards so nothing is lost.
      await ref.set({
        'username': 'Guest_${uid.substring(0, 6)}',
        'email': '',
        'coins': 200 + coinsEarned,
        'jokers': 0,
        'xp': newXp,
        'level': newLevel,
        'gamesPlayed': 1,
        'bestScore': score,
        'country': '',
        'isAnonymous': true,
        'lastPlayedDate': _todayString(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

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
  }
}

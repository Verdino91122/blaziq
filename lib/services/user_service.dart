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
      String username;
      if (user.isAnonymous) {
        username = 'Guest_${user.uid.substring(0, 6)}';
      } else {
        // Reload to ensure the display name is available (can be null on first
        // sign-in before the token is fully propagated).
        await user.reload();
        final freshUser = FirebaseAuth.instance.currentUser;
        username = freshUser?.displayName ??
            user.displayName ??
            user.email?.split('@')[0] ??
            'Player';
      }
      await ref.set({
        'username': username,
        'email': user.email ?? '',
        'coins': 200,
        'jokers': 0,
        'xp': 0,
        'level': 1,
        'gamesPlayed': 0,
        'bestScore': 0,
        'country': 'CA',
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

    // Lazy creation: create the Firestore doc on first completed game if it
    // doesn't exist yet. This is the only place docs are created for anon users.
    final doc = await ref.get();
    if (!doc.exists) {
      final username = isAnonymous ? 'Guest_${uid.substring(0, 6)}' : 'Player';
      await ref.set({
        'username': username,
        'email': '',
        'coins': 200,
        'jokers': 0,
        'xp': 0,
        'level': 1,
        'gamesPlayed': 0,
        'bestScore': 0,
        'country': 'CA',
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
      final username = (data['username'] as String?) ?? 'Player';
      final rawCountry = (data['country'] as String?) ?? '';
      final country = rawCountry.isNotEmpty ? rawCountry : 'CA';
      await updateLeaderboard(
        uid: uid,
        score: effectiveBest,
        username: username,
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
    required String username,
    required String avatarUrl,
    required String country,
  }) async {
    final ref = _db.collection('leaderboard').doc(uid);
    final existing = await ref.get();
    final currentScore = (existing.data()?['score'] as num?)?.toInt() ?? 0;
    if (!existing.exists || score > currentScore) {
      await ref.set({
        'username': username,
        'score': score,
        'country': country,
        'avatarUrl': avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Live stream of the leaderboard collection ordered by score descending.
  static Stream<QuerySnapshot<Map<String, dynamic>>> leaderboardStream() {
    return _db
        .collection('leaderboard')
        .orderBy('score', descending: true)
        .snapshots();
  }
}

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// ── Question model ─────────────────────────────────────────────────────────────

class FriendQuestion {
  final String id;
  final String difficulty;
  final String question;
  final String correctAnswer;
  final List<String> shuffledAnswers;

  const FriendQuestion({
    required this.id,
    required this.difficulty,
    required this.question,
    required this.correctAnswer,
    required this.shuffledAnswers,
  });

  factory FriendQuestion.fromAssetJson(Map<String, dynamic> json) {
    final correct = json['correct_answer'] as String;
    final incorrect = List<String>.from(json['incorrect_answers'] as List);
    final all = [correct, ...incorrect]..shuffle();
    return FriendQuestion(
      id: json['id'] as String,
      difficulty: json['difficulty'] as String,
      question: json['question'] as String,
      correctAnswer: correct,
      shuffledAnswers: all,
    );
  }

  factory FriendQuestion.fromFirestore(Map<String, dynamic> map) {
    return FriendQuestion(
      id: map['id'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'easy',
      question: map['question'] as String? ?? '',
      correctAnswer: map['correctAnswer'] as String? ?? '',
      shuffledAnswers: List<String>.from(map['shuffledAnswers'] as List? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'difficulty': difficulty,
        'question': question,
        'correctAnswer': correctAnswer,
        'shuffledAnswers': shuffledAnswers,
      };
}

// ── Room document model ────────────────────────────────────────────────────────

class RoomData {
  final String hostUid;
  final String hostName;
  final String hostAvatar;
  final int hostLevel;
  final int hostScore;
  final int hostCorrect;
  final bool hostReady;
  final Timestamp? hostConnected;

  final String? guestUid;
  final String? guestName;
  final String? guestAvatar;
  final int guestLevel;
  final int guestScore;
  final int guestCorrect;
  final bool guestReady;
  final Timestamp? guestConnected;

  final String category;
  final String status; // waiting | lobby | countdown | playing | finished
  final int currentQuestionIndex;
  final FriendQuestion? currentQuestion;
  final String phase; // buzzer | answering | inherited | transition | sudden_death | finished
  final String? buzzerWinner;
  final String? buzzerWrongAnswer;
  final String? winnerId;
  final String? quitUid; // set when a player confirms quit mid-game

  // Session stats (cumulative across rematches in this room)
  final int hostGamesWon;
  final int guestGamesWon;
  final int hostTotalScore;
  final int guestTotalScore;

  const RoomData({
    required this.hostUid,
    required this.hostName,
    required this.hostAvatar,
    required this.hostLevel,
    required this.hostScore,
    required this.hostCorrect,
    required this.hostReady,
    this.hostConnected,
    this.guestUid,
    this.guestName,
    this.guestAvatar,
    required this.guestLevel,
    required this.guestScore,
    required this.guestCorrect,
    required this.guestReady,
    this.guestConnected,
    required this.category,
    required this.status,
    required this.currentQuestionIndex,
    this.currentQuestion,
    required this.phase,
    this.buzzerWinner,
    this.buzzerWrongAnswer,
    this.winnerId,
    this.quitUid,
    required this.hostGamesWon,
    required this.guestGamesWon,
    required this.hostTotalScore,
    required this.guestTotalScore,
  });

  factory RoomData.fromSnapshot(Map<String, dynamic> d) {
    final qMap = d['currentQuestion'] as Map<String, dynamic>?;
    return RoomData(
      hostUid: d['hostUid'] as String? ?? '',
      hostName: d['hostName'] as String? ?? 'Player',
      hostAvatar: d['hostAvatar'] as String? ?? '',
      hostLevel: (d['hostLevel'] as num?)?.toInt() ?? 1,
      hostScore: (d['hostScore'] as num?)?.toInt() ?? 0,
      hostCorrect: (d['hostCorrect'] as num?)?.toInt() ?? 0,
      hostReady: d['hostReady'] as bool? ?? false,
      hostConnected: d['hostConnected'] as Timestamp?,
      guestUid: d['guestUid'] as String?,
      guestName: d['guestName'] as String?,
      guestAvatar: d['guestAvatar'] as String? ?? '',
      guestLevel: (d['guestLevel'] as num?)?.toInt() ?? 1,
      guestScore: (d['guestScore'] as num?)?.toInt() ?? 0,
      guestCorrect: (d['guestCorrect'] as num?)?.toInt() ?? 0,
      guestReady: d['guestReady'] as bool? ?? false,
      guestConnected: d['guestConnected'] as Timestamp?,
      category: d['category'] as String? ?? 'science',
      status: d['status'] as String? ?? 'waiting',
      currentQuestionIndex: (d['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      currentQuestion: qMap != null ? FriendQuestion.fromFirestore(qMap) : null,
      phase: d['phase'] as String? ?? 'buzzer',
      buzzerWinner: d['buzzerWinner'] as String?,
      buzzerWrongAnswer: d['buzzerWrongAnswer'] as String?,
      winnerId: d['winnerId'] as String?,
      quitUid: d['quitUid'] as String?,
      hostGamesWon: (d['hostGamesWon'] as num?)?.toInt() ?? 0,
      guestGamesWon: (d['guestGamesWon'] as num?)?.toInt() ?? 0,
      hostTotalScore: (d['hostTotalScore'] as num?)?.toInt() ?? 0,
      guestTotalScore: (d['guestTotalScore'] as num?)?.toInt() ?? 0,
    );
  }

  int gamesWonFor(String uid) => uid == hostUid ? hostGamesWon : guestGamesWon;
  int totalScoreFor(String uid) => uid == hostUid ? hostTotalScore : guestTotalScore;
  String nameFor(String uid) => uid == hostUid ? hostName : (guestName ?? 'Player');
  int scoreFor(String uid) => uid == hostUid ? hostScore : guestScore;
  int correctFor(String uid) => uid == hostUid ? hostCorrect : guestCorrect;
}

// ── Service ────────────────────────────────────────────────────────────────────

class RoomService {
  static final _db = FirebaseFirestore.instance;
  static final _rng = Random.secure();

  static String _generateRoomId() {
    final digits = List.generate(4, (_) => _rng.nextInt(10)).join();
    return 'BLAZIQ-$digits';
  }

  /// Loads questions from the bundled JSON asset.
  /// Returns questions sorted: easy first, then medium, then hard.
  static Future<List<FriendQuestion>> loadQuestionsForCategory(
      String category) async {
    final raw = await rootBundle
        .loadString('assets/data/questions_$category.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final questions = (json['questions'] as List)
        .map((e) => FriendQuestion.fromAssetJson(e as Map<String, dynamic>))
        .toList();
    final easy = questions.where((q) => q.difficulty == 'easy').toList()
      ..shuffle();
    final medium = questions.where((q) => q.difficulty == 'medium').toList()
      ..shuffle();
    final hard = questions.where((q) => q.difficulty == 'hard').toList()
      ..shuffle();
    return [...easy, ...medium, ...hard];
  }

  /// Creates a new room and returns the room ID.
  static Future<String> createRoom({
    required User host,
    required Map<String, dynamic> hostData,
    required String category,
  }) async {
    final roomId = _generateRoomId();
    final questions = await loadQuestionsForCategory(category);
    final firstQ = questions.first;

    await _db.collection('rooms').doc(roomId).set({
      'hostUid': host.uid,
      'hostName': hostData['displayName'] ?? hostData['username'] ?? 'Player',
      'hostAvatar': host.photoURL ?? '',
      'hostLevel': (hostData['level'] as num?)?.toInt() ?? 1,
      'hostScore': 0,
      'hostCorrect': 0,
      'hostReady': false,
      'hostConnected': FieldValue.serverTimestamp(),
      'guestUid': null,
      'guestName': null,
      'guestAvatar': null,
      'guestLevel': null,
      'guestScore': 0,
      'guestCorrect': 0,
      'guestReady': false,
      'guestConnected': null,
      'category': category,
      'status': 'waiting',
      'currentQuestionIndex': 0,
      'currentQuestion': firstQ.toMap(),
      'phase': 'buzzer',
      'buzzerWinner': null,
      'buzzerWrongAnswer': null,
      'winnerId': null,
      'quitUid': null,
      'hostGamesWon': 0,
      'guestGamesWon': 0,
      'hostTotalScore': 0,
      'guestTotalScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return roomId;
  }

  /// Adds guest to the room. Throws a descriptive string on failure.
  static Future<void> joinRoom({
    required String roomId,
    required User guest,
    required Map<String, dynamic> guestData,
  }) async {
    final ref = _db.collection('rooms').doc(roomId.toUpperCase());

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw 'Room $roomId not found.';
      final data = snap.data()!;
      if (data['guestUid'] != null) throw 'This room is already full.';
      if (data['status'] != 'waiting') {
        throw 'This room is no longer accepting players.';
      }
      tx.update(ref, {
        'guestUid': guest.uid,
        'guestName': guestData['displayName'] ?? guestData['username'] ?? 'Player',
        'guestAvatar': guest.photoURL ?? '',
        'guestLevel': (guestData['level'] as num?)?.toInt() ?? 1,
        'guestConnected': FieldValue.serverTimestamp(),
        'status': 'lobby',
      });
    });
  }

  /// Sets the player ready. When both ready → status becomes 'countdown'.
  static Future<void> setReady(String roomId, String uid) async {
    final ref = _db.collection('rooms').doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data()!;
      final isHost = d['hostUid'] == uid;
      final nowHostReady = isHost ? true : (d['hostReady'] as bool? ?? false);
      final nowGuestReady =
          isHost ? (d['guestReady'] as bool? ?? false) : true;
      final updates = <String, dynamic>{
        if (isHost) 'hostReady': true else 'guestReady': true,
        if (nowHostReady && nowGuestReady) 'status': 'countdown',
      };
      tx.update(ref, updates);
    });
  }

  /// Unsets the player ready (for UI toggle before game starts).
  static Future<void> setUnready(String roomId, String uid) async {
    final ref = _db.collection('rooms').doc(roomId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final isHost = snap.data()!['hostUid'] == uid;
    await ref.update({
      if (isHost) 'hostReady': false else 'guestReady': false,
      'status': 'lobby',
    });
  }

  /// Updates the category (host only, while in lobby).
  static Future<void> updateCategory(String roomId, String category) async {
    final questions = await loadQuestionsForCategory(category);
    await _db.collection('rooms').doc(roomId).update({
      'category': category,
      'currentQuestion': questions.first.toMap(),
      'currentQuestionIndex': 0,
      'hostReady': false,
      'guestReady': false,
    });
  }

  /// First-write-wins buzzer press. Returns true if this player won the buzzer.
  /// Works for both normal 'buzzer' phase and 'sudden_death' phase.
  static Future<bool> pressBuzzer(String roomId, String uid) async {
    final ref = _db.collection('rooms').doc(roomId);
    bool won = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data()!;
      if (d['buzzerWinner'] != null) return;
      final phase = d['phase'] as String? ?? '';
      if (phase != 'buzzer' && phase != 'sudden_death') return;
      // In sudden_death, keep the phase name but set the winner.
      // In normal play, advance to 'answering'.
      tx.update(ref, {
        'buzzerWinner': uid,
        if (phase == 'buzzer') 'phase': 'answering',
      });
      won = true;
    });
    return won;
  }

  /// Submits an answer for the current phase.
  /// Phase 'answering' → buzzer winner submitting.
  /// Phase 'inherited' → inheritor (non-buzzer-winner) submitting.
  static Future<void> submitAnswer({
    required String roomId,
    required String uid,
    required String? answer, // null = timeout
  }) async {
    final ref = _db.collection('rooms').doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data()!;
      final phase = d['phase'] as String? ?? '';
      final q = d['currentQuestion'] as Map<String, dynamic>?;
      if (q == null) return;
      final correct = q['correctAnswer'] as String;
      final isCorrect = answer != null && answer == correct;
      final isHost = d['hostUid'] == uid;
      final scoreField = isHost ? 'hostScore' : 'guestScore';
      final correctField = isHost ? 'hostCorrect' : 'guestCorrect';
      final currentScore = (d[scoreField] as num?)?.toInt() ?? 0;

      if (phase == 'answering') {
        if (isCorrect) {
          // Buzzer winner correct: +3 pts, move to transition
          tx.update(ref, {
            scoreField: currentScore + 3,
            correctField: FieldValue.increment(1),
            'phase': 'transition',
          });
        } else {
          // Buzzer winner wrong/timeout: -1 pt, move to inherited
          tx.update(ref, {
            scoreField: (currentScore - 1).clamp(0, 99999),
            'buzzerWrongAnswer': answer,
            'phase': 'inherited',
          });
        }
      } else if (phase == 'inherited') {
        if (isCorrect) {
          // Inheritor correct: +2 pts, move to transition
          tx.update(ref, {
            scoreField: currentScore + 2,
            correctField: FieldValue.increment(1),
            'phase': 'transition',
          });
        } else {
          // Inheritor wrong/timeout: 0 pts, move to transition
          tx.update(ref, {'phase': 'transition'});
        }
      } else if (phase == 'sudden_death') {
        if (isCorrect) {
          tx.update(ref, {
            scoreField: currentScore + 3,
            correctField: FieldValue.increment(1),
            'winnerId': uid,
            'status': 'finished',
            'phase': 'finished',
          });
        } else {
          // Wrong in sudden death → other player wins
          final otherUid = isHost ? d['guestUid'] : d['hostUid'];
          tx.update(ref, {
            'winnerId': otherUid,
            'status': 'finished',
            'phase': 'finished',
          });
        }
      }
    });
  }

  /// Advances to the next question. Call after the 'transition' overlay ends.
  /// Pre-loads the question before writing — no async inside Firestore tx.
  static Future<void> nextQuestion(String roomId) async {
    final snap = await _db.collection('rooms').doc(roomId).get();
    if (!snap.exists) return;
    final d = snap.data()!;
    final idx = (d['currentQuestionIndex'] as num?)?.toInt() ?? 0;
    final category = d['category'] as String? ?? 'science';
    final total = (d['totalQuestions'] as num?)?.toInt() ?? 20;

    final questions = await loadQuestionsForCategory(category);
    final nextIdx = idx + 1;

    if (nextIdx >= questions.length || nextIdx >= total) {
      await _endGameWithTieCheck(roomId, d);
      return;
    }

    final nextQ = questions[nextIdx];
    await _db.collection('rooms').doc(roomId).update({
      'currentQuestionIndex': nextIdx,
      'currentQuestion': nextQ.toMap(),
      'phase': 'buzzer',
      'buzzerWinner': null,
      'buzzerWrongAnswer': null,
    });
  }

  static Future<void> _endGameWithTieCheck(
      String roomId, Map<String, dynamic> d) async {
    final hostScore = (d['hostScore'] as num?)?.toInt() ?? 0;
    final guestScore = (d['guestScore'] as num?)?.toInt() ?? 0;

    if (hostScore == guestScore) {
      // Tie → sudden death
      final category = d['category'] as String? ?? 'science';
      final questions = await loadQuestionsForCategory(category);
      // Pick a random question for sudden death
      final sdQ = questions[_rng.nextInt(questions.length)];
      await _db.collection('rooms').doc(roomId).update({
        'phase': 'sudden_death',
        'currentQuestion': sdQ.toMap(),
        'buzzerWinner': null,
        'buzzerWrongAnswer': null,
      });
    } else {
      final winnerId =
          hostScore > guestScore ? d['hostUid'] : d['guestUid'];
      await endGame(roomId, winnerId: winnerId as String?);
    }
  }

  /// Sets status to finished, records the winner, and updates session stats.
  static Future<void> endGame(String roomId, {String? winnerId}) async {
    try {
      final ref = _db.collection('rooms').doc(roomId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final hostScore = (d['hostScore'] as num?)?.toInt() ?? 0;
      final guestScore = (d['guestScore'] as num?)?.toInt() ?? 0;
      final isWinnerHost =
          winnerId != null && d['hostUid'] == winnerId;
      final isWinnerGuest =
          winnerId != null && d['guestUid'] == winnerId;
      await ref.update({
        'status': 'finished',
        'phase': 'finished',
        'winnerId': winnerId,
        'hostTotalScore': FieldValue.increment(hostScore),
        'guestTotalScore': FieldValue.increment(guestScore),
        if (isWinnerHost) 'hostGamesWon': FieldValue.increment(1),
        if (isWinnerGuest) 'guestGamesWon': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Writes quitUid + finishes the game, awarding win to the other player.
  /// The opponent's client detects quitUid and shows the quit overlay.
  static Future<void> quitGame(String roomId, String uid) async {
    try {
      final ref = _db.collection('rooms').doc(roomId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final isHost = d['hostUid'] == uid;
      final otherId =
          isHost ? d['guestUid'] as String? : d['hostUid'] as String?;
      final hostScore = (d['hostScore'] as num?)?.toInt() ?? 0;
      final guestScore = (d['guestScore'] as num?)?.toInt() ?? 0;
      final isWinnerHost = otherId != null && d['hostUid'] == otherId;
      final isWinnerGuest = otherId != null && d['guestUid'] == otherId;
      await ref.update({
        'quitUid': uid,
        'winnerId': otherId,
        'status': 'finished',
        'phase': 'finished',
        'hostTotalScore': FieldValue.increment(hostScore),
        'guestTotalScore': FieldValue.increment(guestScore),
        if (isWinnerHost) 'hostGamesWon': FieldValue.increment(1),
        if (isWinnerGuest) 'guestGamesWon': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  /// Resets the room for a rematch: clears round state but keeps session stats.
  static Future<void> resetForRematch(String roomId) async {
    try {
      final ref = _db.collection('rooms').doc(roomId);
      final snap = await ref.get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final category = d['category'] as String? ?? 'science';
      final questions = await loadQuestionsForCategory(category);
      await ref.update({
        'status': 'lobby',
        'phase': 'buzzer',
        'hostScore': 0,
        'guestScore': 0,
        'hostCorrect': 0,
        'guestCorrect': 0,
        'hostReady': false,
        'guestReady': false,
        'currentQuestionIndex': 0,
        'currentQuestion': questions.first.toMap(),
        'buzzerWinner': null,
        'buzzerWrongAnswer': null,
        'winnerId': null,
        'quitUid': null,
      });
    } catch (_) {}
  }

  /// Writes heartbeat timestamp so the other player can detect disconnection.
  static Future<void> updateHeartbeat(String roomId, String uid) async {
    try {
      final snap = await _db.collection('rooms').doc(roomId).get();
      if (!snap.exists) return;
      final isHost = snap.data()!['hostUid'] == uid;
      await _db.collection('rooms').doc(roomId).update({
        if (isHost)
          'hostConnected': FieldValue.serverTimestamp()
        else
          'guestConnected': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Handles a player leaving. If host leaves before game, deletes room.
  static Future<void> leaveRoom(String roomId, String uid) async {
    try {
      final snap = await _db.collection('rooms').doc(roomId).get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final isHost = d['hostUid'] == uid;
      final status = d['status'] as String? ?? '';
      if (isHost && (status == 'waiting' || status == 'lobby')) {
        await _db.collection('rooms').doc(roomId).delete();
      } else {
        final otherId =
            isHost ? d['guestUid'] as String? : d['hostUid'] as String?;
        await endGame(roomId, winnerId: otherId);
      }
    } catch (_) {}
  }

  /// Saves friend game rewards to user Firestore doc.
  static Future<void> saveFriendGameResult({
    required String uid,
    required int correctAnswers,
    required bool isWinner,
  }) async {
    try {
      final xpEarned = (correctAnswers * 8) + (isWinner ? 20 : 0);
      final coinsEarned = correctAnswers * 2 + (isWinner ? 15 : 0);
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final currentXp = (d['xp'] as num?)?.toInt() ?? 0;
      final newXp = currentXp + xpEarned;
      // reuse level calculation constants inline
      int level = 1;
      while (_xpThreshold(level + 1) <= newXp) {
        level++;
      }
      await ref.update({
        'xp': newXp,
        'level': level,
        'coins': FieldValue.increment(coinsEarned),
        'gamesPlayed': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  static int _xpThreshold(int level) {
    if (level <= 1) return 0;
    return (100 * level * 1.5).round();
  }

  /// Real-time stream of a room document.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> roomStream(
      String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots();
  }
}

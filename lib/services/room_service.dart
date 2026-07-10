import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'question_service.dart';

// ── Question model ─────────────────────────────────────────────────────────────

/// Bilingual friend-mode question. All language versions are stored so each
/// player's device renders the question in their own chosen language.
///
/// Answers are identified by CANONICAL INDEX everywhere (Firestore + game
/// logic): 0 = correct_answer, 1..3 = incorrect_answers[0..2]. The index is
/// the same across languages, which makes cross-language answer display
/// trivial. [answerOrder] is the shared shuffled display order of those
/// indices, so both players see the same button layout.
class FriendQuestion {
  final String id;
  final String difficulty;

  /// {'en': {question, correct_answer, incorrect_answers}, 'fr': {...}}
  final Map<String, Map<String, dynamic>> translations;

  /// Shuffled canonical indices in display order (generated once by the host).
  final List<int> answerOrder;

  const FriendQuestion({
    required this.id,
    required this.difficulty,
    required this.translations,
    required this.answerOrder,
  });

  /// Builds from a QuestionService question, keeping every language map from
  /// the raw Firestore doc and shuffling the display order once.
  factory FriendQuestion.fromTrivia(TriviaQuestion q) {
    final translations = <String, Map<String, dynamic>>{};
    q.raw.forEach((key, value) {
      if (value is Map && value.containsKey('question')) {
        translations[key] = Map<String, dynamic>.from(value);
      }
    });
    if (translations.isEmpty) {
      // Legacy flat doc / local JSON fallback — English only.
      translations['en'] = {
        'question': q.question,
        'correct_answer': q.correctAnswer,
        'incorrect_answers': q.incorrectAnswers,
      };
    }
    final answerCount = 1 +
        ((translations['en'] ?? translations.values.first)['incorrect_answers']
                    as List? ??
                const [])
            .length;
    final order = List<int>.generate(answerCount, (i) => i)..shuffle();
    return FriendQuestion(
      id: q.id,
      difficulty: q.difficulty,
      translations: translations,
      answerOrder: order,
    );
  }

  factory FriendQuestion.fromFirestore(Map<String, dynamic> map) {
    final translations = <String, Map<String, dynamic>>{};
    (map['translations'] as Map?)?.forEach((key, value) {
      if (value is Map) {
        translations[key as String] = Map<String, dynamic>.from(value);
      }
    });
    return FriendQuestion(
      id: map['id'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'easy',
      translations: translations,
      answerOrder: ((map['answerOrder'] as List?) ?? const [0, 1, 2, 3])
          .map((e) => (e as num).toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'difficulty': difficulty,
        'translations': translations,
        'answerOrder': answerOrder,
      };

  Map<String, dynamic> _lang(String language) =>
      translations[language] ?? translations['en'] ?? const {};

  String questionFor(String language) =>
      _lang(language)['question'] as String? ?? '';

  /// Canonical answer pool: index 0 = correct, 1..3 = incorrect answers.
  List<String> answerPoolFor(String language) {
    final m = _lang(language);
    return [
      m['correct_answer'] as String? ?? '',
      ...List<String>.from(m['incorrect_answers'] as List? ?? const []),
    ];
  }

  /// Answer texts in the shared display order, in the given language.
  List<String> answersFor(String language) {
    final pool = answerPoolFor(language);
    return [
      for (final i in answerOrder)
        if (i < pool.length) pool[i],
    ];
  }
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
  final String hostLanguage; // 'en' | 'fr'
  final String guestLanguage; // 'en' | 'fr'
  final String status; // waiting | lobby | countdown | playing | finished
  final int currentQuestionIndex;
  final FriendQuestion? currentQuestion;
  final List<FriendQuestion> questions; // full session list (host-fetched)
  final String phase; // buzzer | answering | inherited | transition | sudden_death | finished
  final String? buzzerWinner;
  final int? buzzerWrongIndex; // canonical index of buzzer winner's wrong answer
  final String? winnerId;
  final String? quitUid; // set when a player confirms quit mid-game

  // Session stats (cumulative across rematches in this room)
  final int hostGamesWon;
  final int guestGamesWon;
  final int hostTotalScore;
  final int guestTotalScore;

  // Server timestamps for cross-device synchronization
  final Timestamp? gameStartedAt;
  final Timestamp? buzzerPressedAt;
  final Timestamp? nextQuestionAt;
  final Timestamp? inheritedDeadlineAt;

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
    this.hostLanguage = 'en',
    this.guestLanguage = 'en',
    required this.status,
    required this.currentQuestionIndex,
    this.currentQuestion,
    this.questions = const [],
    required this.phase,
    this.buzzerWinner,
    this.buzzerWrongIndex,
    this.winnerId,
    this.quitUid,
    required this.hostGamesWon,
    required this.guestGamesWon,
    required this.hostTotalScore,
    required this.guestTotalScore,
    this.gameStartedAt,
    this.buzzerPressedAt,
    this.nextQuestionAt,
    this.inheritedDeadlineAt,
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
      hostLanguage: d['hostLanguage'] as String? ?? 'en',
      guestLanguage: d['guestLanguage'] as String? ?? 'en',
      status: d['status'] as String? ?? 'waiting',
      currentQuestionIndex: (d['currentQuestionIndex'] as num?)?.toInt() ?? 0,
      currentQuestion: qMap != null ? FriendQuestion.fromFirestore(qMap) : null,
      questions: ((d['questions'] as List?) ?? [])
          .map((e) =>
              FriendQuestion.fromFirestore(Map<String, dynamic>.from(e as Map)))
          .toList(),
      phase: d['phase'] as String? ?? 'buzzer',
      buzzerWinner: d['buzzerWinner'] as String?,
      buzzerWrongIndex: (d['buzzerWrongIndex'] as num?)?.toInt(),
      winnerId: d['winnerId'] as String?,
      quitUid: d['quitUid'] as String?,
      hostGamesWon: (d['hostGamesWon'] as num?)?.toInt() ?? 0,
      guestGamesWon: (d['guestGamesWon'] as num?)?.toInt() ?? 0,
      hostTotalScore: (d['hostTotalScore'] as num?)?.toInt() ?? 0,
      guestTotalScore: (d['guestTotalScore'] as num?)?.toInt() ?? 0,
      gameStartedAt: d['gameStartedAt'] as Timestamp?,
      buzzerPressedAt: d['buzzerPressedAt'] as Timestamp?,
      nextQuestionAt: d['nextQuestionAt'] as Timestamp?,
      inheritedDeadlineAt: d['inheritedDeadlineAt'] as Timestamp?,
    );
  }

  String languageFor(String uid) =>
      uid == hostUid ? hostLanguage : guestLanguage;
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

  /// Fetches one session of questions (easy → medium → hard) from Firestore
  /// via QuestionService (with local JSON fallback), ready to store in the
  /// room document so both players play the exact same questions.
  static Future<List<FriendQuestion>> _fetchSessionQuestions(
      String category) async {
    final session = await QuestionService.getSessionQuestions(category);
    return session.map(FriendQuestion.fromTrivia).toList();
  }

  /// Reads the session question list stored in a room document.
  static List<Map<String, dynamic>> _storedQuestions(Map<String, dynamic> d) {
    return ((d['questions'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // All valid avatar group numbers (Group 45 is missing from the asset set).
  static const _avatarNums = [
    1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,
    21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,
    39,40,41,42,43,44,46,47,48,49,50,51,52,53,54,55,56,57,
    58,59,60,61,62,63,64,65,66,
  ];

  /// Resolves the avatar string to store in a room doc.
  /// Returns an `avatar_N` id for SVG assets, an HTTP URL for Google photos,
  /// or a deterministic default avatar for users who haven't picked one.
  static String _resolveAvatar(Map<String, dynamic> userData, User user) {
    final avatarId = (userData['avatarId'] as String?) ?? '';
    if (avatarId.startsWith('avatar_')) return avatarId;
    if (avatarId == 'google' || (user.photoURL?.isNotEmpty ?? false)) {
      return user.photoURL ?? '';
    }
    // No avatar configured: assign a deterministic one based on UID so every
    // player always shows a real avatar instead of invisible initials.
    final idx = user.uid.codeUnits.fold(0, (a, b) => a + b) % _avatarNums.length;
    return 'avatar_${_avatarNums[idx]}';
  }

  /// Re-syncs the current player's avatar into the room doc.
  /// Call this from LobbyScreen to fix stale data in rooms created before
  /// avatar support was added.
  static Future<void> syncPlayerAvatar({
    required String roomId,
    required User user,
    required Map<String, dynamic> userData,
    required bool isHost,
  }) async {
    final avatar = _resolveAvatar(userData, user);
    final field = isHost ? 'hostAvatar' : 'guestAvatar';
    await _db.collection('rooms').doc(roomId).update({field: avatar});
  }

  /// Creates a new room and returns the room ID.
  static Future<String> createRoom({
    required User host,
    required Map<String, dynamic> hostData,
    required String category,
    String language = 'en',
  }) async {
    final roomId = _generateRoomId();
    final questions = await _fetchSessionQuestions(category);
    final firstQ = questions.first;

    await _db.collection('rooms').doc(roomId).set({
      'hostUid': host.uid,
      'hostName': hostData['displayName'] ?? hostData['username'] ?? 'Player',
      'hostAvatar': _resolveAvatar(hostData, host),
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
      'hostLanguage': language,
      'guestLanguage': 'en',
      'status': 'waiting',
      'currentQuestionIndex': 0,
      'currentQuestion': firstQ.toMap(),
      'questions': questions.map((q) => q.toMap()).toList(),
      'totalQuestions': questions.length,
      'phase': 'buzzer',
      'buzzerWinner': null,
      'buzzerWrongIndex': null,
      'winnerId': null,
      'quitUid': null,
      'hostGamesWon': 0,
      'guestGamesWon': 0,
      'hostTotalScore': 0,
      'guestTotalScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'gameStartedAt': null,
      'buzzerPressedAt': null,
      'nextQuestionAt': null,
      'inheritedDeadlineAt': null,
    });

    return roomId;
  }

  /// Adds guest to the room. Throws a descriptive string on failure.
  static Future<void> joinRoom({
    required String roomId,
    required User guest,
    required Map<String, dynamic> guestData,
    String language = 'en',
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
        'guestAvatar': _resolveAvatar(guestData, guest),
        'guestLevel': (guestData['level'] as num?)?.toInt() ?? 1,
        'guestLanguage': language,
        'guestConnected': FieldValue.serverTimestamp(),
        'status': 'lobby',
      });
    });
  }

  /// Sets a player's question language ('en'/'fr') on the room document.
  static Future<void> setLanguage(
      String roomId, String uid, String language) async {
    final ref = _db.collection('rooms').doc(roomId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final isHost = snap.data()!['hostUid'] == uid;
    await ref.update({
      if (isHost) 'hostLanguage': language else 'guestLanguage': language,
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
    final questions = await _fetchSessionQuestions(category);
    await _db.collection('rooms').doc(roomId).update({
      'category': category,
      'currentQuestion': questions.first.toMap(),
      'questions': questions.map((q) => q.toMap()).toList(),
      'totalQuestions': questions.length,
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
        'buzzerPressedAt': FieldValue.serverTimestamp(),
        if (phase == 'buzzer') 'phase': 'answering',
      });
      won = true;
    });
    return won;
  }

  /// Submits an answer for the current phase.
  /// Phase 'answering' → buzzer winner submitting.
  /// Phase 'inherited' → inheritor (non-buzzer-winner) submitting.
  ///
  /// [answerIndex] is the CANONICAL answer index (0 = correct answer,
  /// 1..3 = incorrect_answers[0..2]), which is language-independent;
  /// null = timeout. Correctness is simply answerIndex == 0.
  static Future<void> submitAnswer({
    required String roomId,
    required String uid,
    required int? answerIndex, // null = timeout
  }) async {
    final ref = _db.collection('rooms').doc(roomId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data()!;
      final phase = d['phase'] as String? ?? '';
      final q = d['currentQuestion'] as Map<String, dynamic>?;
      if (q == null) return;
      final isCorrect = answerIndex == 0;
      final isHost = d['hostUid'] == uid;
      final scoreField = isHost ? 'hostScore' : 'guestScore';
      final correctField = isHost ? 'hostCorrect' : 'guestCorrect';
      final currentScore = (d[scoreField] as num?)?.toInt() ?? 0;

      // Shared deadline used for all transitions to the next question.
      // Both clients count down to this absolute timestamp so they advance in sync.
      final nextQuestionAt = Timestamp.fromMillisecondsSinceEpoch(
        DateTime.now().millisecondsSinceEpoch + 4800,
      );

      if (phase == 'answering') {
        if (isCorrect) {
          // Buzzer winner correct: +3 pts, move to transition
          tx.update(ref, {
            scoreField: currentScore + 3,
            correctField: FieldValue.increment(1),
            'phase': 'transition',
            'nextQuestionAt': nextQuestionAt,
          });
        } else {
          // Buzzer winner wrong/timeout: -1 pt, move to inherited
          tx.update(ref, {
            scoreField: (currentScore - 1).clamp(0, 99999),
            'buzzerWrongIndex': answerIndex,
            'phase': 'inherited',
            'inheritedDeadlineAt': Timestamp.fromMillisecondsSinceEpoch(
              DateTime.now().millisecondsSinceEpoch + 10000,
            ),
          });
        }
      } else if (phase == 'inherited') {
        if (isCorrect) {
          // Inheritor correct: +2 pts, move to transition
          tx.update(ref, {
            scoreField: currentScore + 2,
            correctField: FieldValue.increment(1),
            'phase': 'transition',
            'nextQuestionAt': nextQuestionAt,
          });
        } else {
          // Inheritor wrong/timeout: 0 pts, move to transition
          tx.update(ref, {
            'phase': 'transition',
            'nextQuestionAt': nextQuestionAt,
          });
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

  /// Advances to the next question, reading from the session question list
  /// stored in the room document so both players see the same questions.
  static Future<void> nextQuestion(String roomId) async {
    final snap = await _db.collection('rooms').doc(roomId).get();
    if (!snap.exists) return;
    final d = snap.data()!;
    final idx = (d['currentQuestionIndex'] as num?)?.toInt() ?? 0;
    final total = (d['totalQuestions'] as num?)?.toInt() ?? 20;

    final questions = _storedQuestions(d);
    final nextIdx = idx + 1;

    if (nextIdx >= questions.length || nextIdx >= total) {
      await _endGameWithTieCheck(roomId, d);
      return;
    }

    final nextQ = questions[nextIdx];
    await _db.collection('rooms').doc(roomId).update({
      'currentQuestionIndex': nextIdx,
      'currentQuestion': nextQ,
      'phase': 'buzzer',
      'buzzerWinner': null,
      'buzzerWrongIndex': null,
      'phaseStartedAt': FieldValue.serverTimestamp(),
      'buzzerPressedAt': null,
      'nextQuestionAt': null,
      'inheritedDeadlineAt': null,
    });
  }

  static Future<void> _endGameWithTieCheck(
      String roomId, Map<String, dynamic> d) async {
    final hostScore = (d['hostScore'] as num?)?.toInt() ?? 0;
    final guestScore = (d['guestScore'] as num?)?.toInt() ?? 0;

    if (hostScore == guestScore) {
      // Tie → sudden death. Prefer an unshown question from the stored
      // session list; fall back to any stored question, then a fresh fetch.
      final stored = _storedQuestions(d);
      Map<String, dynamic> sdQ;
      if (stored.isNotEmpty) {
        final idx = (d['currentQuestionIndex'] as num?)?.toInt() ?? 0;
        final unshown =
            idx + 1 < stored.length ? stored.sublist(idx + 1) : stored;
        sdQ = unshown[_rng.nextInt(unshown.length)];
      } else {
        final category = d['category'] as String? ?? 'science';
        final questions = await _fetchSessionQuestions(category);
        sdQ = questions[_rng.nextInt(questions.length)].toMap();
      }
      await _db.collection('rooms').doc(roomId).update({
        'phase': 'sudden_death',
        'currentQuestion': sdQ,
        'buzzerWinner': null,
        'buzzerWrongIndex': null,
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
      final questions = await _fetchSessionQuestions(category);
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
        'questions': questions.map((q) => q.toMap()).toList(),
        'totalQuestions': questions.length,
        'buzzerWinner': null,
        'buzzerWrongIndex': null,
        'winnerId': null,
        'quitUid': null,
        'gameStartedAt': null,
        'buzzerPressedAt': null,
        'nextQuestionAt': null,
        'inheritedDeadlineAt': null,
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

  /// Handles a player leaving the room.
  ///
  /// Pre-game (waiting / lobby):
  ///   - Guest leaves → clear guest slot, reset to 'waiting' so anyone can rejoin.
  ///   - Host leaves with guest present → promote guest to host, keep room alive.
  ///   - Host leaves with no guest → delete the room.
  ///
  /// Mid-game: award win to the other player (existing behaviour).
  static Future<void> leaveRoom(String roomId, String uid) async {
    try {
      final snap = await _db.collection('rooms').doc(roomId).get();
      if (!snap.exists) return;
      final d = snap.data()!;
      final isHost = d['hostUid'] == uid;
      final status = d['status'] as String? ?? '';
      final guestUid = d['guestUid'] as String?;

      if (status == 'waiting' || status == 'lobby') {
        if (!isHost) {
          // Guest leaves pre-game — clear guest slot, reopen room for someone new.
          // Also clears hostReady so a new guest doesn't trigger an instant countdown.
          await _db.collection('rooms').doc(roomId).update({
            'guestUid': null,
            'guestName': null,
            'guestAvatar': null,
            'guestLevel': null,
            'guestScore': 0,
            'guestCorrect': 0,
            'guestReady': false,
            'guestConnected': null,
            'hostReady': false,
            'status': 'waiting',
          });
        } else if (guestUid != null) {
          // Host leaves with guest present — promote the guest to host so the
          // room stays alive with the same room code.
          await _db.collection('rooms').doc(roomId).update({
            'hostUid': guestUid,
            'hostName': d['guestName'],
            'hostAvatar': d['guestAvatar'],
            'hostLevel': d['guestLevel'] ?? 1,
            'hostScore': 0,
            'hostCorrect': 0,
            'hostReady': false,
            'hostConnected': d['guestConnected'],
            'guestUid': null,
            'guestName': null,
            'guestAvatar': null,
            'guestLevel': null,
            'guestScore': 0,
            'guestCorrect': 0,
            'guestReady': false,
            'guestConnected': null,
            'status': 'waiting',
          });
        } else {
          // Host leaves with no guest — delete the room entirely.
          await _db.collection('rooms').doc(roomId).delete();
        }
      } else {
        // Game in progress — award win to the remaining player.
        final otherId =
            isHost ? guestUid : (d['hostUid'] as String?);
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

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── HTML entity decoder ────────────────────────────────────────────────────────

String _decodeHtml(String text) {
  var s = text
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#039;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&ldquo;', '“')
      .replaceAll('&rdquo;', '”')
      .replaceAll('&lsquo;', '‘')
      .replaceAll('&rsquo;', '’')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&nbsp;', ' ');
  s = s.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!)),
  );
  s = s.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
  );
  return s;
}

// ── Models ─────────────────────────────────────────────────────────────────────

class TriviaQuestion {
  final String id;
  final String category;
  final String difficulty; // easy | medium | hard
  final String question; // in the requested language
  final String correctAnswer; // in the requested language
  final List<String> incorrectAnswers; // in the requested language

  /// The full raw Firestore document (root fields + 'en'/'fr' language maps).
  /// Friend mode stores this in the room so each player can render the
  /// question in their own language.
  final Map<String, dynamic> raw;

  const TriviaQuestion({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
    required this.raw,
  });

  /// Extracts the requested language map ('en'/'fr') from a bilingual
  /// Firestore doc. Falls back to 'en' if the language is missing, and to
  /// flat root fields for legacy docs / the local JSON assets (English only).
  factory TriviaQuestion.fromMap(
      String id, String categoryId, Map<String, dynamic> map, String language) {
    final langEntry = (map[language] ?? map['en']) as Map?;
    final src = langEntry != null
        ? Map<String, dynamic>.from(langEntry)
        : map; // legacy flat structure
    return TriviaQuestion(
      id: id,
      category: map['category'] as String? ?? categoryId,
      difficulty: map['difficulty'] as String? ?? 'easy',
      question: _decodeHtml(src['question'] as String? ?? ''),
      correctAnswer: _decodeHtml(src['correct_answer'] as String? ?? ''),
      incorrectAnswers: List<String>.from(src['incorrect_answers'] as List? ?? [])
          .map(_decodeHtml)
          .toList(),
      raw: map,
    );
  }
}

class QuizCategory {
  final String id;
  final String name;
  final String emoji;
  final bool isHot;
  final int totalQuestions;
  final List<String> supportedLanguages;

  const QuizCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isHot,
    required this.totalQuestions,
    this.supportedLanguages = const ['en'],
  });

  factory QuizCategory.fromFirestore(String id, Map<String, dynamic> d) {
    return QuizCategory(
      id: id,
      name: d['name'] as String? ?? id,
      emoji: d['emoji'] as String? ?? '❓',
      isHot: d['isHot'] as bool? ?? false,
      totalQuestions: (d['totalQuestions'] as num?)?.toInt() ?? 0,
      supportedLanguages:
          List<String>.from(d['supportedLanguages'] as List? ?? ['en']),
    );
  }
}

// ── Service ────────────────────────────────────────────────────────────────────

/// All question fetching for solo and friend modes.
///
/// Primary source: Firestore (questions/{categoryId}/items). Falls back to the
/// bundled JSON assets in assets/data/ if Firestore is unreachable.
/// Tracks seen question IDs per category in shared_preferences so players
/// don't get repeats; the seen lists reset every 60 days.
class QuestionService {
  static final _db = FirebaseFirestore.instance;

  static const _easyCount = 7;
  static const _mediumCount = 5;
  static const _hardCount = 3;
  static const _seenResetDays = 30;
  static const _seenResetKey = 'seen_reset_date';

  // ── Remote config (question bank version + adaptive difficulty rules) ────
  //
  // Cached once per app launch — call initConfig() at startup, not per game.

  static const _defaultTiers = [
    'beginner', 'easy', 'medium', 'advanced', 'hard', 'expert',
  ];

  static String _questionBankVersion = 'v1';
  static Map<String, dynamic> _difficultyRules = const {};
  static Future<void>? _configFuture;

  /// Fetches config/app_settings and config/difficulty_rules once and caches
  /// the results for the lifetime of the app. Safe to call multiple times —
  /// only the first call triggers a fetch. Never throws; falls back to
  /// defaults ('v1' bank, hardcoded tier rules) if Firestore is unreachable.
  static Future<void> initConfig() {
    return _configFuture ??= _loadConfig();
  }

  static Future<void> _loadConfig() async {
    try {
      final doc = await _db.collection('config').doc('app_settings').get();
      _questionBankVersion =
          doc.data()?['question_bank_version'] as String? ?? 'v1';
    } catch (_) {
      _questionBankVersion = 'v1';
    }
    try {
      final doc = await _db.collection('config').doc('difficulty_rules').get();
      _difficultyRules = doc.data() ?? const {};
    } catch (_) {
      _difficultyRules = const {};
    }
  }

  /// Root questions collection name for the currently cached bank version.
  static String get _questionsRoot =>
      _questionBankVersion == 'v2' ? 'questions_v2' : 'questions';

  static CollectionReference<Map<String, dynamic>> _itemsCollection(
      String categoryId) {
    return _db
        .collection(_questionsRoot)
        .doc(categoryId)
        .collection('items');
  }

  /// Ordered tier names, beginner → expert. Accepts either 'tiers' or
  /// 'tier_order' as the Firestore field name — the generation tooling used
  /// the latter, this service originally expected the former.
  static List<String> get tierOrder => List<String>.from(
      (_difficultyRules['tiers'] ?? _difficultyRules['tier_order']) as List? ??
          _defaultTiers);

  static int get advancementThreshold =>
      (_difficultyRules['advancement_threshold'] as num?)?.toInt() ?? 3;

  static int get regressionThreshold =>
      (_difficultyRules['regression_threshold'] as num?)?.toInt() ?? -3;

  static int get minQuestionsPerTier =>
      (_difficultyRules['min_questions_per_tier'] as num?)?.toInt() ?? 3;

  static int get familiarCategoryGames =>
      (_difficultyRules['familiar_category_games'] as num?)?.toInt() ?? 4;

  static int get familiarStartingCounter =>
      (_difficultyRules['familiar_starting_counter'] as num?)?.toInt() ?? 1;

  // ── Seen questions tracking ──────────────────────────────────────────────

  /// Returns the prefs instance after applying the 30-day seen-list reset.
  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    final resetMillis = prefs.getInt(_seenResetKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (resetMillis == null) {
      await prefs.setInt(_seenResetKey, now);
    } else if (now - resetMillis >= const Duration(days: _seenResetDays).inMilliseconds) {
      final seenKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('seen_') && k != _seenResetKey)
          .toList();
      for (final key in seenKeys) {
        await prefs.remove(key);
      }
      await prefs.setInt(_seenResetKey, now);
    }
    return prefs;
  }

  /// Seen IDs are stored prefixed with the question bank version they were
  /// seen under (e.g. 'v1:science_easy_0001') so that switching
  /// question_bank_version (v1 → v2) automatically gives every user a fresh
  /// start — old-version entries simply stop matching, they're never read.
  static String get _versionPrefix => '$_questionBankVersion:';

  static Future<List<String>> getSeenIds(String categoryId) async {
    await initConfig();
    final prefs = await _prefs();
    final stored = prefs.getStringList('seen_$categoryId') ?? [];
    final prefix = _versionPrefix;
    return stored
        .where((e) => e.startsWith(prefix))
        .map((e) => e.substring(prefix.length))
        .toList();
  }

  /// Marks a single question as seen. Only correct answers should ever be
  /// marked seen — [wasCorrect] gates the write so wrong-answered questions
  /// stay eligible to reappear (and be re-fetched preferentially) until the
  /// player gets them right.
  static Future<void> markSeen(
    String categoryId,
    String questionId, {
    required bool wasCorrect,
  }) {
    if (!wasCorrect) return Future.value();
    return markSeenAll(categoryId, [questionId]);
  }

  /// Marks a batch of questions as seen (used after a friend game where the
  /// guest receives the shown IDs from the room document).
  static Future<void> markSeenAll(
      String categoryId, List<String> questionIds) async {
    final ids = questionIds.where((id) => id.isNotEmpty);
    if (ids.isEmpty) return;
    await initConfig();
    final prefs = await _prefs();
    final key = 'seen_$categoryId';
    final stored = prefs.getStringList(key) ?? [];
    final prefixedNew = ids.map((id) => '$_versionPrefix$id');
    final merged = {...stored, ...prefixedNew};
    if (merged.length == stored.length) return;
    await prefs.setStringList(key, merged.toList());
  }

  // ── Session fetching ─────────────────────────────────────────────────────

  /// Fetches one game session for a category: 7 easy + 5 medium + 3 hard,
  /// shuffled within each difficulty group, in easy → medium → hard order.
  /// Seen questions are excluded; if a difficulty runs out of unseen
  /// questions it is topped up with seen ones so the game never fails to
  /// start. Falls back to the bundled JSON assets if Firestore fails.
  ///
  /// [language] selects which language map ('en'/'fr') the returned question
  /// text comes from; question IDs and seen tracking are language-agnostic.
  /// [excludeIds] additionally excludes not-yet-answered questions from the
  /// current session (used by solo mode prefetch to avoid duplicates).
  static Future<List<TriviaQuestion>> getSessionQuestions(
    String categoryId, {
    String language = 'en',
    Set<String> excludeIds = const {},
  }) async {
    await initConfig();
    final seen = (await getSeenIds(categoryId)).toSet();
    try {
      final session = [
        ...await _fetchDifficulty(categoryId, 'easy', _easyCount, language, seen, excludeIds),
        ...await _fetchDifficulty(categoryId, 'medium', _mediumCount, language, seen, excludeIds),
        ...await _fetchDifficulty(categoryId, 'hard', _hardCount, language, seen, excludeIds),
      ];
      if (session.isEmpty) throw Exception('No questions in Firestore');
      return session;
    } catch (_) {
      // Local JSON assets are English-only — acceptable last-resort fallback.
      return _loadLocalSession(categoryId, language, seen, excludeIds);
    }
  }

  static Future<List<TriviaQuestion>> _fetchDifficulty(
    String categoryId,
    String difficulty,
    int count,
    String language,
    Set<String> seen,
    Set<String> exclude,
  ) async {
    // The fetch window grows with the seen list so unseen questions stay
    // reachable without reading the whole category every session.
    final limit = count * 4 + seen.length + exclude.length;
    final snap = await _itemsCollection(categoryId)
        .where('difficulty', isEqualTo: difficulty)
        .limit(limit)
        .get();
    final all = snap.docs
        .map((doc) =>
            TriviaQuestion.fromMap(doc.id, categoryId, doc.data(), language))
        .toList();
    return _pickForSession(all, count, seen, exclude);
  }

  /// Prefers unseen questions; tops up with seen ones if there aren't enough.
  static List<TriviaQuestion> _pickForSession(
    List<TriviaQuestion> pool,
    int count,
    Set<String> seen,
    Set<String> exclude,
  ) {
    final unseen = pool
        .where((q) => !seen.contains(q.id) && !exclude.contains(q.id))
        .toList()
      ..shuffle();
    if (unseen.length >= count) return unseen.take(count).toList();
    final fallback = pool
        .where((q) => seen.contains(q.id) && !exclude.contains(q.id))
        .toList()
      ..shuffle();
    return [...unseen, ...fallback].take(count).toList();
  }

  /// Last-resort offline fallback: bundled JSON assets in assets/data/.
  /// Only the original 4 categories ship as assets; other categories rethrow.
  static Future<List<TriviaQuestion>> _loadLocalSession(
    String categoryId,
    String language,
    Set<String> seen,
    Set<String> exclude,
  ) async {
    final raw =
        await rootBundle.loadString('assets/data/questions_$categoryId.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final all = (json['questions'] as List)
        .map((e) => TriviaQuestion.fromMap(
            (e as Map<String, dynamic>)['id'] as String? ?? '',
            categoryId,
            e,
            language))
        .toList();
    List<TriviaQuestion> group(String difficulty, int count) => _pickForSession(
        all.where((q) => q.difficulty == difficulty).toList(),
        count,
        seen,
        exclude);
    return [
      ...group('easy', _easyCount),
      ...group('medium', _mediumCount),
      ...group('hard', _hardCount),
    ];
  }

  // ── Adaptive difficulty: on-demand single-question fetching ──────────────

  /// Fetches one question at [tier] for the adaptive difficulty system.
  /// Unlike [getSessionQuestions] this never batches — the solo game screen
  /// calls it once per question so the tier can change between every draw.
  ///
  /// Fallback order (never automatically drops to an easier tier — only the
  /// caller's counter logic may change [tier]):
  ///   1. Unseen questions at [tier], excluding [excludeIds] (on-screen /
  ///      prefetched questions in this session).
  ///   2. Questions previously answered wrong at this tier ([wrongIds]) that
  ///      still aren't seen — re-served for reinforcement even if excluded.
  ///   3. Any question at [tier], ignoring the seen filter entirely.
  /// Returns null only if the tier has no questions at all (category/tier
  /// combination is empty) — the caller should surface an error in that case.
  static Future<TriviaQuestion?> getQuestionForTier(
    String categoryId,
    String tier, {
    String language = 'en',
    Set<String> seenIds = const {},
    Set<String> wrongIds = const {},
    Set<String> excludeIds = const {},
  }) async {
    await initConfig();
    List<TriviaQuestion> pool;
    try {
      pool = await _fetchTierPool(categoryId, tier, language);
    } catch (_) {
      pool = await _loadLocalTierPool(categoryId, tier, language);
    }
    if (pool.isEmpty) return null;

    var candidates = pool
        .where((q) => !seenIds.contains(q.id) && !excludeIds.contains(q.id))
        .toList();

    if (candidates.isEmpty) {
      candidates = pool
          .where((q) => wrongIds.contains(q.id) && !seenIds.contains(q.id))
          .toList();
    }

    if (candidates.isEmpty) {
      candidates = pool.where((q) => !excludeIds.contains(q.id)).toList();
    }

    if (candidates.isEmpty) candidates = pool;

    candidates.shuffle();
    return candidates.first;
  }

  static Future<List<TriviaQuestion>> _fetchTierPool(
    String categoryId, String tier, String language) async {
    final snap = await _itemsCollection(categoryId)
        .where('difficulty', isEqualTo: tier)
        .limit(50)
        .get();
    return snap.docs
        .map((doc) =>
            TriviaQuestion.fromMap(doc.id, categoryId, doc.data(), language))
        .toList();
  }

  /// Offline fallback for the adaptive fetch — only the original 4 categories
  /// ship as JSON assets, and only with 'easy'/'medium'/'hard' difficulty
  /// values, so unrecognized tiers/categories simply yield an empty pool.
  static Future<List<TriviaQuestion>> _loadLocalTierPool(
    String categoryId, String tier, String language) async {
    try {
      final raw = await rootBundle
          .loadString('assets/data/questions_$categoryId.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['questions'] as List)
          .map((e) => TriviaQuestion.fromMap(
              (e as Map<String, dynamic>)['id'] as String? ?? '',
              categoryId,
              e,
              language))
          .where((q) => q.difficulty == tier)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Categories ───────────────────────────────────────────────────────────

  /// All enabled categories, hot categories first (then alphabetical).
  static Future<List<QuizCategory>> getCategories() async {
    final snap = await _db
        .collection('categories')
        .where('enabled', isEqualTo: true)
        .get();
    final cats = snap.docs
        .map((d) => QuizCategory.fromFirestore(d.id, d.data()))
        .toList();
    cats.sort((a, b) {
      if (a.isHot != b.isHot) return a.isHot ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return cats;
  }
}

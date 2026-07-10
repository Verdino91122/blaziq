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
  final String question;
  final String correctAnswer;
  final List<String> incorrectAnswers;

  const TriviaQuestion({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.question,
    required this.correctAnswer,
    required this.incorrectAnswers,
  });

  /// Works for both Firestore docs and local JSON entries — the field names
  /// are identical (question, correct_answer, incorrect_answers, difficulty).
  factory TriviaQuestion.fromMap(
      String id, String categoryId, Map<String, dynamic> map) {
    return TriviaQuestion(
      id: id,
      category: map['category'] as String? ?? categoryId,
      difficulty: map['difficulty'] as String? ?? 'easy',
      question: _decodeHtml(map['question'] as String? ?? ''),
      correctAnswer: _decodeHtml(map['correct_answer'] as String? ?? ''),
      incorrectAnswers: List<String>.from(map['incorrect_answers'] as List? ?? [])
          .map(_decodeHtml)
          .toList(),
    );
  }
}

class QuizCategory {
  final String id;
  final String name;
  final String emoji;
  final bool isHot;
  final int totalQuestions;

  const QuizCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isHot,
    required this.totalQuestions,
  });

  factory QuizCategory.fromFirestore(String id, Map<String, dynamic> d) {
    return QuizCategory(
      id: id,
      name: d['name'] as String? ?? id,
      emoji: d['emoji'] as String? ?? '❓',
      isHot: d['isHot'] as bool? ?? false,
      totalQuestions: (d['totalQuestions'] as num?)?.toInt() ?? 0,
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
  static const _seenResetDays = 60;
  static const _seenResetKey = 'seen_reset_date';

  // ── Seen questions tracking ──────────────────────────────────────────────

  /// Returns the prefs instance after applying the 60-day seen-list reset.
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

  static Future<List<String>> getSeenIds(String categoryId) async {
    final prefs = await _prefs();
    return prefs.getStringList('seen_$categoryId') ?? [];
  }

  /// Marks a single question as seen. Call after each question is answered.
  static Future<void> markSeen(String categoryId, String questionId) =>
      markSeenAll(categoryId, [questionId]);

  /// Marks a batch of questions as seen (used after a friend game where the
  /// guest receives the shown IDs from the room document).
  static Future<void> markSeenAll(
      String categoryId, List<String> questionIds) async {
    final ids = questionIds.where((id) => id.isNotEmpty);
    if (ids.isEmpty) return;
    final prefs = await _prefs();
    final key = 'seen_$categoryId';
    final seen = prefs.getStringList(key) ?? [];
    final merged = {...seen, ...ids};
    if (merged.length == seen.length) return;
    await prefs.setStringList(key, merged.toList());
  }

  // ── Session fetching ─────────────────────────────────────────────────────

  /// Fetches one game session for a category: 7 easy + 5 medium + 3 hard,
  /// shuffled within each difficulty group, in easy → medium → hard order.
  /// Seen questions are excluded; if a difficulty runs out of unseen
  /// questions it is topped up with seen ones so the game never fails to
  /// start. Falls back to the bundled JSON assets if Firestore fails.
  ///
  /// [excludeIds] additionally excludes not-yet-answered questions from the
  /// current session (used by solo mode prefetch to avoid duplicates).
  static Future<List<TriviaQuestion>> getSessionQuestions(
    String categoryId, {
    Set<String> excludeIds = const {},
  }) async {
    final seen = (await getSeenIds(categoryId)).toSet();
    try {
      final session = [
        ...await _fetchDifficulty(categoryId, 'easy', _easyCount, seen, excludeIds),
        ...await _fetchDifficulty(categoryId, 'medium', _mediumCount, seen, excludeIds),
        ...await _fetchDifficulty(categoryId, 'hard', _hardCount, seen, excludeIds),
      ];
      if (session.isEmpty) throw Exception('No questions in Firestore');
      return session;
    } catch (_) {
      return _loadLocalSession(categoryId, seen, excludeIds);
    }
  }

  static Future<List<TriviaQuestion>> _fetchDifficulty(
    String categoryId,
    String difficulty,
    int count,
    Set<String> seen,
    Set<String> exclude,
  ) async {
    // The fetch window grows with the seen list so unseen questions stay
    // reachable without reading the whole category every session.
    final limit = count * 4 + seen.length + exclude.length;
    final snap = await _db
        .collection('questions')
        .doc(categoryId)
        .collection('items')
        .where('difficulty', isEqualTo: difficulty)
        .limit(limit)
        .get();
    final all = snap.docs
        .map((doc) => TriviaQuestion.fromMap(doc.id, categoryId, doc.data()))
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
    Set<String> seen,
    Set<String> exclude,
  ) async {
    final raw =
        await rootBundle.loadString('assets/data/questions_$categoryId.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final all = (json['questions'] as List)
        .map((e) => TriviaQuestion.fromMap(
            (e as Map<String, dynamic>)['id'] as String? ?? '', categoryId, e))
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

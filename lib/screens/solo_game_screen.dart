import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

// ── HTML entity decoder ──────────────────────────────────────────────────────

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
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&eacute;', 'é')
      .replaceAll('&egrave;', 'è')
      .replaceAll('&ecirc;', 'ê')
      .replaceAll('&ntilde;', 'ñ')
      .replaceAll('&uuml;', 'ü')
      .replaceAll('&ouml;', 'ö')
      .replaceAll('&auml;', 'ä')
      .replaceAll('&oacute;', 'ó')
      .replaceAll('&iacute;', 'í')
      .replaceAll('&aacute;', 'á')
      .replaceAll('&uacute;', 'ú')
      .replaceAll('&ccedil;', 'ç')
      .replaceAll('&szlig;', 'ß');
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

// ── Data model ───────────────────────────────────────────────────────────────

class _Question {
  final String text;
  final List<String> answers; // shuffled
  final String correct;

  const _Question({
    required this.text,
    required this.answers,
    required this.correct,
  });

  factory _Question.fromJson(Map<String, dynamic> json) {
    final correct = _decodeHtml(json['correct_answer'] as String);
    final answers = [
      correct,
      ...(json['incorrect_answers'] as List).map((a) => _decodeHtml(a as String)),
    ]..shuffle(Random());
    return _Question(
      text: _decodeHtml(json['question'] as String),
      answers: answers,
      correct: correct,
    );
  }
}

// ── Enums ────────────────────────────────────────────────────────────────────

enum _GamePhase { loading, playing, result, error }

enum _Difficulty { easy, medium, hard }

enum _AnswerState { idle, correct, wrong }

// ── Cheat callbacks ───────────────────────────────────────────────────────────

class _CheatCallbacks {
  final VoidCallback addTime;
  final VoidCallback forceCorrect;
  final VoidCallback forceWrong;
  final VoidCallback setHard;
  final VoidCallback setEasy;

  const _CheatCallbacks({
    required this.addTime,
    required this.forceCorrect,
    required this.forceWrong,
    required this.setHard,
    required this.setEasy,
  });
}

// ── Screen ───────────────────────────────────────────────────────────────────

class SoloGameScreen extends StatefulWidget {
  final bool cheatMode;

  const SoloGameScreen({super.key, this.cheatMode = false});

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen>
    with SingleTickerProviderStateMixin {
  // ── Phase ─────────────────────────────────────────────────────────────────
  _GamePhase _phase = _GamePhase.loading;
  String _errorMessage = '';
  bool _loadingNextBatch = false;

  // ── Questions ─────────────────────────────────────────────────────────────
  List<_Question> _questions = [];
  int _qIndex = 0;
  List<_Question> _nextBatch = [];
  bool _prefetching = false;
  _Difficulty _difficulty = _Difficulty.easy;

  // ── Timer ─────────────────────────────────────────────────────────────────
  int _timeRemaining = 30;
  Timer? _countdownTimer;

  // ── Scoring ───────────────────────────────────────────────────────────────
  int _finalScore = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  int _currentStreak = 0;
  int _highestStreak = 0;
  int _xpEarned = 0;
  int _coinsEarned = 0;
  int _xpBefore = 0;
  Map<String, dynamic>? _userDataSnapshot;

  // ── Pre-game countdown ────────────────────────────────────────────────────
  bool _countingDown = false;
  int _countdownValue = 3;
  bool _countdownOverlayVisible = false;
  int _countdownGeneration = 0; // guards against stale async callbacks

  // ── Answer state ──────────────────────────────────────────────────────────
  String? _selectedAnswer;
  bool _answered = false;
  Timer? _feedbackTimer;

  // ── Timer bump ────────────────────────────────────────────────────────────
  late final AnimationController _timerBumpCtrl;
  Color _timerBumpColor = AppTheme.blazeGold;

  // ── API ───────────────────────────────────────────────────────────────────

  static const _apiBase =
      'https://opentdb.com/api.php?amount=10&type=multiple';

  Future<List<_Question>> _fetchBatch(_Difficulty difficulty) async {
    final baseUrl = '$_apiBase&difficulty=${difficulty.name}';
    final url = kIsWeb ? 'https://corsproxy.io/?$baseUrl' : baseUrl;
    var response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    // OpenTDB rate-limits to ~1 req/5s; retry once automatically instead of
    // surfacing an error to the user (common when restarting a game quickly).
    if (response.statusCode == 429) {
      await Future.delayed(const Duration(seconds: 5));
      response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
    }
    if (response.statusCode != 200) {
      throw Exception('Server error (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final code = json['response_code'] as int;
    if (code == 5) throw Exception('Too many requests — please wait a moment.');
    if (code != 0) throw Exception('Could not load questions (code $code).');
    return (json['results'] as List)
        .map((q) => _Question.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  // ── Game flow ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _timerBumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0, // start settled — no bump on init
    );
    _startGame();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _timerBumpCtrl.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _countdownGeneration++;
    setState(() {
      _phase = _GamePhase.loading;
      _errorMessage = '';
      _questions = [];
      _qIndex = 0;
      _nextBatch = [];
      _prefetching = false;
      _difficulty = _Difficulty.easy;
      _timeRemaining = 30;
      _finalScore = 0;
      _correctCount = 0;
      _wrongCount = 0;
      _currentStreak = 0;
      _highestStreak = 0;
      _xpEarned = 0;
      _coinsEarned = 0;
      _xpBefore = 0;
      _userDataSnapshot = null;
      _selectedAnswer = null;
      _answered = false;
      _loadingNextBatch = false;
      _countingDown = false;
      _countdownValue = 3;
      _countdownOverlayVisible = false;
    });

    // Pre-fetch user data so _endGame() can check firstGameToday without delay.
    final user = AuthService.currentUser;
    if (user != null) {
      UserService.getUserData(user.uid).then((data) {
        _userDataSnapshot = data;
      }).catchError((_) {});
    }

    try {
      final questions = await _fetchBatch(_Difficulty.easy);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _phase = _GamePhase.playing;
        _countingDown = true;
        _countdownValue = 3;
        _countdownOverlayVisible = true;
      });
      _maybePrefetch();
      _runCountdown(_countdownGeneration);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _GamePhase.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        _countdownTimer?.cancel();
        _endGame();
      }
    });
  }

  Future<void> _runCountdown(int generation) async {
    for (final val in [3, 2, 1]) {
      if (!mounted || _countdownGeneration != generation) return;
      setState(() => _countdownValue = val);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted || _countdownGeneration != generation) return;
    setState(() => _countdownValue = 0); // GO!
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _countdownGeneration != generation) return;
    setState(() => _countdownOverlayVisible = false); // begin fade-out
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _countdownGeneration != generation) return;
    setState(() => _countingDown = false);
    _startCountdown();
  }

  void _endGame() {
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();

    final base = _correctCount * 100;
    final streakBonus = _highestStreak * 50;
    final timeBonus = _timeRemaining.clamp(0, 9999) * 10;
    final score = base + streakBonus + timeBonus;

    final xp = (_correctCount * 10) + 5 + (_highestStreak * 3);

    final firstGameToday = UserService.isFirstGameToday(_userDataSnapshot);
    final coins = 10 +
        (_correctCount * 2) +
        (_highestStreak >= 5 ? 15 : 0) +
        (firstGameToday ? 20 : 0);

    final xpBefore = (_userDataSnapshot?['xp'] as int?) ?? 0;

    // Save to Firestore — fire-and-forget
    final user = AuthService.currentUser;
    if (user != null) {
      UserService.saveGameResult(
        uid: user.uid,
        score: score,
        xpEarned: xp,
        coinsEarned: coins,
        isAnonymous: user.isAnonymous,
        avatarUrl: user.photoURL ?? '',
      ).catchError((_) {});
    }

    setState(() {
      _finalScore = score;
      _xpEarned = xp;
      _coinsEarned = coins;
      _xpBefore = xpBefore;
      _phase = _GamePhase.result;
    });
  }

  void _onAnswer(String answer) {
    if (_answered || _phase != _GamePhase.playing) return;
    _countdownTimer?.cancel(); // pause while showing feedback

    final isCorrect = answer == _questions[_qIndex].correct;
    int newTime = _timeRemaining;

    if (isCorrect) {
      _correctCount++;
      _currentStreak++;
      if (_currentStreak > _highestStreak) { _highestStreak = _currentStreak; }
      final int bonus;
      if (_currentStreak >= 5) {
        bonus = 10;
      } else if (_currentStreak == 4) {
        bonus = 8;
      } else if (_currentStreak == 3) {
        bonus = 6;
      } else {
        bonus = 4;
      }
      newTime += bonus;
      final streakLabel = _currentStreak >= 3 ? '🔥 x$_currentStreak STREAK!' : null;
      _showFeedback('+${bonus}s', AppTheme.blazeGold, streakLabel: streakLabel);
    } else {
      _wrongCount++;
      _currentStreak = 0;
      newTime -= 3;
      _showFeedback('-3s', AppTheme.sparkPink);
    }

    setState(() {
      _answered = true;
      _selectedAnswer = answer;
      _timeRemaining = newTime.clamp(0, 9999);
    });

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (newTime <= 0) {
        _endGame();
      } else {
        _advanceQuestion();
      }
    });
  }

  Future<void> _advanceQuestion() async {
    if (!mounted) return;

    // Difficulty escalation
    _Difficulty newDiff = _difficulty;
    if (_correctCount >= 10) { newDiff = _Difficulty.hard; }
    else if (_correctCount >= 5) { newDiff = _Difficulty.medium; }

    if (newDiff != _difficulty) {
      _difficulty = newDiff;
      _nextBatch = [];
      _prefetching = false;
    }

    _qIndex++;

    if (_qIndex >= _questions.length) {
      if (_nextBatch.isNotEmpty) {
        setState(() {
          _questions = _nextBatch;
          _nextBatch = [];
          _qIndex = 0;
          _prefetching = false;
          _selectedAnswer = null;
          _answered = false;
        });
        _startCountdown();
        _maybePrefetch();
      } else {
        // Pre-fetch wasn't ready — pause and fetch now
        setState(() {
          _loadingNextBatch = true;
          _selectedAnswer = null;
          _answered = false;
        });
        try {
          final batch = await _fetchBatch(_difficulty);
          if (!mounted) return;
          setState(() {
            _questions = batch;
            _qIndex = 0;
            _loadingNextBatch = false;
          });
          _startCountdown();
          _maybePrefetch();
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _phase = _GamePhase.error;
            _errorMessage = 'Failed to load more questions.';
            _loadingNextBatch = false;
          });
        }
      }
    } else {
      setState(() {
        _selectedAnswer = null;
        _answered = false;
      });
      _startCountdown();
      _maybePrefetch();
    }
  }

  // ── Floating feedback ─────────────────────────────────────────────────────

  void _showFeedback(String text, Color color, {String? streakLabel}) {
    final overlay = Overlay.of(context);
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => _FeedbackAnimation(
        text: text,
        color: color,
        streakLabel: streakLabel,
        onDone: () => entry?.remove(),
      ),
    );
    overlay.insert(entry);
    // Bump the timer when the floating text reaches it (~500ms into animation)
    final flashColor = color == AppTheme.blazeGold ? Colors.white : color;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _timerBumpColor = flashColor);
      _timerBumpCtrl.forward(from: 0);
    });
  }

  // ── Cheat methods ─────────────────────────────────────────────────────────

  void _cheatAddTime() {
    setState(() => _timeRemaining = (_timeRemaining + 30).clamp(0, 9999));
  }

  void _cheatForceCorrect() {
    if (_answered || _phase != _GamePhase.playing) return;
    _onAnswer(_questions[_qIndex].correct);
  }

  void _cheatForceWrong() {
    if (_answered || _phase != _GamePhase.playing) return;
    final wrong = _questions[_qIndex].answers
        .firstWhere((a) => a != _questions[_qIndex].correct);
    _onAnswer(wrong);
  }

  void _cheatSetHard() => setState(() => _difficulty = _Difficulty.hard);

  void _cheatSetEasy() => setState(() => _difficulty = _Difficulty.easy);

  void _maybePrefetch() {
    if (_prefetching || _nextBatch.isNotEmpty) return;
    if (_questions.length - _qIndex > 3) return;
    _prefetching = true;
    _fetchBatch(_difficulty).then((batch) {
      if (!mounted) return;
      setState(() {
        _nextBatch = batch;
        _prefetching = false;
      });
    }).catchError((_) {
      _prefetching = false;
    });
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _cancelCountdown() {
    _countdownGeneration++;
    _countdownTimer?.cancel();
    if (mounted) Navigator.pop(context);
  }

  void _showQuitDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Quit Game?',
            style: AppTheme.subheading.copyWith(fontSize: 22),
            textAlign: TextAlign.center),
        content: Text(
          'Your progress will be lost.',
          style: AppTheme.bodyMuted,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.blazeGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Keep Playing',
                      textAlign: TextAlign.center,
                      style: AppTheme.buttonLabel),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.mutedText.withAlpha(80)),
                  ),
                  child: Text('Quit',
                      textAlign: TextAlign.center,
                      style: AppTheme.buttonLabel
                          .copyWith(color: AppTheme.mutedText)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  int get _liveScore => _correctCount * 100;

  int get _totalAnswered => _correctCount + _wrongCount;

  int get _accuracy =>
      _totalAnswered == 0 ? 0 : (_correctCount / _totalAnswered * 100).round();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // During countdown: cancel button handles navigation; back button blocked
        if (_countingDown) return;
        if (_phase == _GamePhase.playing) _showQuitDialog();
      },
      child: Scaffold(
        backgroundColor: AppTheme.arenaBlack,
        body: switch (_phase) {
          _GamePhase.loading => const _LoadingView(),
          _GamePhase.error => _ErrorView(
              message: _errorMessage,
              onRetry: _startGame,
            ),
          _GamePhase.result => _ResultsView(
              score: _finalScore,
              correctCount: _correctCount,
              highestStreak: _highestStreak,
              accuracy: _accuracy,
              xpEarned: _xpEarned,
              coinsEarned: _coinsEarned,
              xpBefore: _xpBefore,
              isSignedIn: AuthService.currentUser != null,
              onPlayAgain: _startGame,
              onHome: () => Navigator.pop(context),
            ),
          _GamePhase.playing => Stack(
              children: [
                _GameView(
                  question: _questions[_qIndex],
                  difficulty: _difficulty,
                  liveScore: _liveScore,
                  timeRemaining: _timeRemaining,
                  currentStreak: _currentStreak,
                  selectedAnswer: _selectedAnswer,
                  answered: _answered,
                  loadingNextBatch: _loadingNextBatch,
                  onAnswer: _onAnswer,
                  onQuit: _showQuitDialog,
                  timerBumpCtrl: _timerBumpCtrl,
                  timerBumpColor: _timerBumpColor,
                  cheats: widget.cheatMode
                      ? _CheatCallbacks(
                          addTime: _cheatAddTime,
                          forceCorrect: _cheatForceCorrect,
                          forceWrong: _cheatForceWrong,
                          setHard: _cheatSetHard,
                          setEasy: _cheatSetEasy,
                        )
                      : null,
                ),
                if (_countingDown)
                  AnimatedOpacity(
                    opacity: _countdownOverlayVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: _CountdownOverlay(
                      value: _countdownValue,
                      onCancel: _cancelCountdown,
                    ),
                  ),
              ],
            ),
        },
      ),
    );
  }
}

// ── Loading view ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.blazeGold,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          Text('Loading questions…', style: AppTheme.bodyMuted),
        ],
      ),
    );
  }
}

// ── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppTheme.mutedText, size: 56),
              const SizedBox(height: 20),
              Text(
                'Could Not Load Questions',
                textAlign: TextAlign.center,
                style: AppTheme.subheading.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center, style: AppTheme.bodyMuted),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.blazeGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('TRY AGAIN', style: AppTheme.buttonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Game view ────────────────────────────────────────────────────────────────

class _GameView extends StatelessWidget {
  final _Question question;
  final _Difficulty difficulty;
  final int liveScore;
  final int timeRemaining;
  final int currentStreak;
  final String? selectedAnswer;
  final bool answered;
  final bool loadingNextBatch;
  final ValueChanged<String> onAnswer;
  final VoidCallback onQuit;
  final _CheatCallbacks? cheats;
  final AnimationController? timerBumpCtrl;
  final Color? timerBumpColor;

  const _GameView({
    required this.question,
    required this.difficulty,
    required this.liveScore,
    required this.timeRemaining,
    required this.currentStreak,
    required this.selectedAnswer,
    required this.answered,
    required this.loadingNextBatch,
    required this.onAnswer,
    required this.onQuit,
    this.cheats,
    this.timerBumpCtrl,
    this.timerBumpColor,
  });

  Color get _difficultyColor => switch (difficulty) {
        _Difficulty.easy => AppTheme.difficultyEasy,
        _Difficulty.medium => AppTheme.difficultyMedium,
        _Difficulty.hard => AppTheme.difficultyHard,
      };

  _AnswerState _stateFor(String answer) {
    if (!answered) return _AnswerState.idle;
    if (answer == question.correct) return _AnswerState.correct;
    if (answer == selectedAnswer) return _AnswerState.wrong;
    return _AnswerState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final letters = ['A', 'B', 'C', 'D'];

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onQuit,
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.whiteText, size: 22),
                ),
                const Spacer(),
                // Difficulty badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _difficultyColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _difficultyColor.withAlpha(120), width: 1),
                  ),
                  child: Text(
                    difficulty.name.toUpperCase(),
                    style: AppTheme.difficultyBadge
                        .copyWith(color: _difficultyColor),
                  ),
                ),
                const Spacer(),
                // Score
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppTheme.blazeGold, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      '$liveScore',
                      style: AppTheme.statValue
                          .copyWith(fontSize: 16, color: AppTheme.blazeGold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Circular timer ────────────────────────────────────────────────
          Center(
            child: _CircularTimer(
              timeRemaining: timeRemaining,
              bumpCtrl: timerBumpCtrl,
              bumpColor: timerBumpColor,
            ),
          ),

          // ── Cheat bar (dev mode only) ─────────────────────────────────────
          if (cheats != null) _CheatBar(cheats: cheats!),

          const SizedBox(height: 16),

          // ── Question card ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: loadingNextBatch
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppTheme.divider, width: 1),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppTheme.blazeGold,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 14),
                            Text('Loading next questions…',
                                style: AppTheme.bodyMuted),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppTheme.divider, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          question.text,
                          textAlign: TextAlign.center,
                          style: AppTheme.questionText,
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Answer buttons ────────────────────────────────────────────────
          if (!loadingNextBatch)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  for (int i = 0; i < question.answers.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _AnswerButton(
                      letter: letters[i],
                      text: question.answers[i],
                      state: _stateFor(question.answers[i]),
                      onTap: answered
                          ? null
                          : () => onAnswer(question.answers[i]),
                    ),
                  ],
                ],
              ),
            ),

          if (loadingNextBatch) const SizedBox(height: 20),
        ],
      ),
    ),
    if (currentStreak >= 2)
      Positioned(
        top: 137,
        left: 0,
        right: 0,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppTheme.blazeGold, size: 18),
              const SizedBox(width: 4),
              Text('x$currentStreak STREAK', style: AppTheme.streakText),
            ],
          ),
        ),
      ),
  ],
  ),
);
  }
}

// ── Countdown overlay ─────────────────────────────────────────────────────────

class _CountdownOverlay extends StatelessWidget {
  final int value; // 3, 2, 1 = number; 0 = GO!
  final VoidCallback onCancel;

  const _CountdownOverlay({required this.value, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.arenaBlack,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.35, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              ),
              child: Text(
                key: ValueKey(value),
                value > 0 ? '$value' : 'GO!',
                style: AppTheme.storeTitle.copyWith(
                  fontSize: value > 0 ? 96 : 80,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.blazeGold,
                  letterSpacing: value > 0 ? 2.0 : 8.0,
                ),
              ),
            ),
            const SizedBox(height: 48),
            if (value > 0)
              GestureDetector(
                onTap: onCancel,
                child: Text(
                  'CANCEL',
                  style: AppTheme.sectionHeader.copyWith(
                    color: AppTheme.mutedText,
                    letterSpacing: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Circular timer ────────────────────────────────────────────────────────────

class _CircularTimer extends StatefulWidget {
  final int timeRemaining;
  final AnimationController? bumpCtrl;
  final Color? bumpColor;

  const _CircularTimer({
    required this.timeRemaining,
    this.bumpCtrl,
    this.bumpColor,
  });

  @override
  State<_CircularTimer> createState() => _CircularTimerState();
}

class _CircularTimerState extends State<_CircularTimer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  Animation<double>? _bumpScale;
  late Listenable _animListenable;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.09).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _updateBumpAnim();
    _updatePulse();
  }

  void _updateBumpAnim() {
    if (widget.bumpCtrl != null) {
      _bumpScale = Tween<double>(begin: 1.15, end: 1.0).animate(
        CurvedAnimation(parent: widget.bumpCtrl!, curve: Curves.elasticOut),
      );
      _animListenable = Listenable.merge([_pulseAnim, _bumpScale!]);
    } else {
      _bumpScale = null;
      _animListenable = _pulseAnim;
    }
  }

  @override
  void didUpdateWidget(_CircularTimer old) {
    super.didUpdateWidget(old);
    if (old.timeRemaining != widget.timeRemaining) _updatePulse();
    if (old.bumpCtrl != widget.bumpCtrl) _updateBumpAnim();
  }

  void _updatePulse() {
    if (widget.timeRemaining <= 8 && widget.timeRemaining > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUrgent = widget.timeRemaining <= 8;
    final baseColor = isUrgent ? AppTheme.sparkPink : AppTheme.blazeGold;
    final progress = (widget.timeRemaining / 30.0).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animListenable,
      builder: (context, _) {
        final pulseScale = isUrgent ? _pulseAnim.value : 1.0;
        final bumpScaleVal = _bumpScale?.value ?? 1.0;

        // Lerp from flash color → base color as bump settles (t: 0→1)
        final Color timerColor;
        if (_bumpScale != null && widget.bumpColor != null) {
          final t = _bumpScale!.value.clamp(0.0, 1.0);
          timerColor = Color.lerp(widget.bumpColor!, baseColor, t) ?? baseColor;
        } else {
          timerColor = baseColor;
        }

        return Transform.scale(
          scale: pulseScale * bumpScaleVal,
          child: SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CustomPaint(
                    painter: _ArcPainter(
                      progress: progress,
                      color: timerColor,
                      bgColor: AppTheme.cardSurface,
                    ),
                  ),
                ),
                Text(
                  '${widget.timeRemaining}',
                  style: AppTheme.timerText.copyWith(color: timerColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Arc painter ───────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -pi / 2; // 12 o'clock

    // Background arc — full circle
    canvas.drawArc(
      rect,
      startAngle,
      2 * pi,
      false,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Foreground arc — remaining time
    if (progress > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.bgColor != bgColor;
}

// ── Answer button ─────────────────────────────────────────────────────────────

class _AnswerButton extends StatelessWidget {
  final String letter;
  final String text;
  final _AnswerState state;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = state == _AnswerState.correct;
    final isWrong = state == _AnswerState.wrong;
    final isAnswered = isCorrect || isWrong;

    final Color accent =
        isCorrect ? AppTheme.blazeGold : AppTheme.sparkPink;
    final Color bg =
        isAnswered ? accent.withAlpha(30) : AppTheme.cardSurface;
    final Color borderColor =
        isAnswered ? accent : AppTheme.divider;
    final double borderWidth = isAnswered ? 2.0 : 1.0;
    final Color textColor =
        isAnswered ? accent : AppTheme.whiteText;
    final Color letterBg = isCorrect
        ? AppTheme.blazeGold
        : isWrong
            ? AppTheme.sparkPink.withAlpha(200)
            : AppTheme.voidBlack;
    final Color letterText =
        isCorrect ? AppTheme.voidBlack : AppTheme.whiteText;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: letterBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: AppTheme.answerText.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: letterText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTheme.answerText.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results view ──────────────────────────────────────────────────────────────

class _ResultsView extends StatelessWidget {
  final int score;
  final int correctCount;
  final int highestStreak;
  final int accuracy;
  final int xpEarned;
  final int coinsEarned;
  final int xpBefore;
  final bool isSignedIn;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const _ResultsView({
    required this.score,
    required this.correctCount,
    required this.highestStreak,
    required this.accuracy,
    required this.xpEarned,
    required this.coinsEarned,
    required this.xpBefore,
    required this.isSignedIn,
    required this.onPlayAgain,
    required this.onHome,
  });

  String get _headline {
    if (correctCount >= 13) return 'UNSTOPPABLE!';
    if (correctCount >= 8) return 'ON FIRE!';
    if (correctCount >= 4) return 'GOOD WORK';
    return 'KEEP PRACTICING';
  }

  @override
  Widget build(BuildContext context) {
    final xpAfter = xpBefore + xpEarned;
    final levelBefore = UserService.levelForXp(xpBefore);
    final levelAfter = UserService.levelForXp(xpAfter);
    final didLevelUp = levelAfter > levelBefore;

    final currThreshold = UserService.xpThreshold(levelAfter);
    final nextThreshold = UserService.xpThreshold(levelAfter + 1);
    final rangeSize = nextThreshold - currThreshold;
    final xpInLevel = xpAfter - currThreshold;

    final beginProgress = (didLevelUp || rangeSize == 0)
        ? 0.0
        : ((xpBefore - currThreshold) / rangeSize).clamp(0.0, 1.0);
    final endProgress =
        rangeSize > 0 ? (xpInLevel / rangeSize).clamp(0.0, 1.0) : 1.0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 36),

            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                  color: AppTheme.blazeGold, shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppTheme.voidBlack, size: 48),
            ),
            const SizedBox(height: 16),
            Text(_headline, style: AppTheme.storeTitle),
            const SizedBox(height: 4),
            Text('GAME OVER', style: AppTheme.sectionHeader),
            const SizedBox(height: 24),

            // Stats card
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.blazeGold.withAlpha(80), width: 1),
              ),
              child: Column(
                children: [
                  _ResultRow(
                    label: 'FINAL SCORE',
                    value: '$score',
                    valueStyle:
                        AppTheme.storeTitle.copyWith(color: AppTheme.blazeGold),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.divider, height: 1),
                  const SizedBox(height: 12),
                  _ResultRow(label: 'CORRECT ANSWERS', value: '$correctCount'),
                  const SizedBox(height: 8),
                  _ResultRow(label: 'HIGHEST STREAK', value: '$highestStreak'),
                  const SizedBox(height: 8),
                  _ResultRow(label: 'ACCURACY', value: '$accuracy%'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Rewards card
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REWARDS EARNED', style: AppTheme.sectionHeader),
                  const SizedBox(height: 14),

                  _RewardRow(
                    icon: Icons.star_rounded,
                    label: 'SCORE',
                    value: score,
                    suffix: ' pts',
                  ),
                  const SizedBox(height: 10),
                  _RewardRow(
                    icon: Icons.toll_rounded,
                    label: 'COINS',
                    value: coinsEarned,
                    suffix: '',
                  ),
                  const SizedBox(height: 14),

                  // XP row with progress bar
                  Row(
                    children: [
                      const Icon(Icons.flash_on_rounded,
                          color: AppTheme.blazeGold, size: 18),
                      const SizedBox(width: 8),
                      Text('XP', style: AppTheme.sectionHeader),
                      const Spacer(),
                      if (didLevelUp)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.blazeGold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'LEVEL UP! → Lv.$levelAfter',
                            style: AppTheme.caption.copyWith(
                                color: AppTheme.voidBlack,
                                fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: xpEarned),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOut,
                          builder: (_, val, _) =>
                              Text('+$val xp', style: AppTheme.rewardText),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween:
                        Tween<double>(begin: beginProgress, end: endProgress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOut,
                    builder: (_, val, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: val,
                        minHeight: 10,
                        backgroundColor: AppTheme.voidBlack,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.blazeGold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lv.$levelAfter · ${UserService.titleForLevel(levelAfter)}',
                        style: AppTheme.caption,
                      ),
                      Text('$xpInLevel / $rangeSize xp',
                          style: AppTheme.caption),
                    ],
                  ),
                ],
              ),
            ),

            // Sign-in prompt
            if (!isSignedIn) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.blazeGold.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.blazeGold.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: AppTheme.blazeGold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sign in to save your score and rewards',
                        style: AppTheme.caption
                            .copyWith(color: AppTheme.blazeGold, fontSize: 12),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppTheme.blazeGold, size: 14),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            GestureDetector(
              onTap: onPlayAgain,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.blazeGold,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('PLAY AGAIN',
                    textAlign: TextAlign.center,
                    style: AppTheme.buttonLabel.copyWith(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onHome,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider, width: 1),
                ),
                child: Text('HOME',
                    textAlign: TextAlign.center,
                    style: AppTheme.buttonLabel
                        .copyWith(color: AppTheme.mutedText, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Reward row ────────────────────────────────────────────────────────────────

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final String suffix;

  const _RewardRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.blazeGold, size: 18),
        const SizedBox(width: 8),
        Text(label, style: AppTheme.sectionHeader),
        const Spacer(),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (_, val, _) =>
              Text('+$val$suffix', style: AppTheme.rewardText),
        ),
      ],
    );
  }
}

// ── Cheat bar ─────────────────────────────────────────────────────────────────

class _CheatBar extends StatelessWidget {
  final _CheatCallbacks cheats;

  const _CheatBar({required this.cheats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CheatButton(label: '+30s', onTap: cheats.addTime),
          _CheatButton(label: '✓ Force', onTap: cheats.forceCorrect),
          _CheatButton(label: '✗ Force', onTap: cheats.forceWrong),
          _CheatButton(label: 'HARD', onTap: cheats.setHard),
          _CheatButton(label: 'EASY', onTap: cheats.setEasy),
        ],
      ),
    );
  }
}

class _CheatButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CheatButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.sparkPink.withAlpha(100), width: 1),
        ),
        child: Text(
          label,
          style: AppTheme.caption.copyWith(
            color: AppTheme.sparkPink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ── Floating feedback animation ───────────────────────────────────────────────

class _FeedbackAnimation extends StatefulWidget {
  final String text;
  final Color color;
  final String? streakLabel;
  final VoidCallback onDone;

  const _FeedbackAnimation({
    required this.text,
    required this.color,
    this.streakLabel,
    required this.onDone,
  });

  @override
  State<_FeedbackAnimation> createState() => _FeedbackAnimationState();
}

class _FeedbackAnimationState extends State<_FeedbackAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _offsetY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Pop: 0.6 → 1.2 over first 300ms, settle to 1.0 over next 100ms, hold
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 37.5,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 12.5,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
    ]).animate(_ctrl);

    // Float upward 0 → -150px over 600ms then hold
    _offsetY = Tween<double>(begin: 0, end: -150).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );

    // Fade out during last 300ms (t = 0.625 → 1.0)
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.625, 1.0, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, _offsetY.value),
            child: Transform.scale(
              scale: _scale.value,
              child: Opacity(
                opacity: _opacity.value.clamp(0.0, 1.0),
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.text,
                        style: AppTheme.modeTitle.copyWith(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                          height: 1.0,
                        ),
                      ),
                      if (widget.streakLabel != null)
                        Text(
                          widget.streakLabel!,
                          style: AppTheme.streakText.copyWith(
                            fontSize: 20,
                            color: widget.color,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  const _ResultRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.sectionHeader),
        Text(
          value,
          style: valueStyle ??
              AppTheme.statValue.copyWith(color: AppTheme.whiteText),
        ),
      ],
    );
  }
}

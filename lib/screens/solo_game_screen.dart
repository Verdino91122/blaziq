import 'dart:async';
import 'dart:math';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../services/question_service.dart';
import '../services/sound_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

// ── Data model ───────────────────────────────────────────────────────────────

class _Question {
  final String id;
  final String difficulty;
  final String text;
  final List<String> answers;
  final String correct;

  const _Question({
    required this.id,
    required this.difficulty,
    required this.text,
    required this.answers,
    required this.correct,
  });

  factory _Question.fromTrivia(TriviaQuestion q) {
    final answers = [q.correctAnswer, ...q.incorrectAnswers]..shuffle(Random());
    return _Question(
      id: q.id,
      difficulty: q.difficulty,
      text: q.question,
      answers: answers,
      correct: q.correctAnswer,
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
  final String categoryId;
  final bool cheatMode;
  const SoloGameScreen({
    super.key,
    required this.categoryId,
    this.cheatMode = false,
  });

  @override
  State<SoloGameScreen> createState() => _SoloGameScreenState();
}

class _SoloGameScreenState extends State<SoloGameScreen>
    with TickerProviderStateMixin {
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

  // ── Audio / haptic state ──────────────────────────────────────────────────
  bool _urgentSoundActive = false;
  bool _hapticsEnabled = true;

  // ── Pre-game countdown ────────────────────────────────────────────────────
  bool _countingDown = false;
  int _countdownValue = 3;
  bool _countdownOverlayVisible = false;
  int _countdownGeneration = 0;

  // ── Answer state ──────────────────────────────────────────────────────────
  String? _selectedAnswer;
  bool _answered = false;
  Timer? _feedbackTimer;

  // ── Timer bump ────────────────────────────────────────────────────────────
  late final AnimationController _timerBumpCtrl;
  Color _timerBumpColor = AppTheme.electricBlue;

  // ── Streak bounce ─────────────────────────────────────────────────────────
  late final AnimationController _streakBounceCtrl;
  late final Animation<double> _streakBounceAnim;

  // ── Question fetching (Firestore via QuestionService) ────────────────────

  /// Fetches one session (7 easy + 5 medium + 3 hard) from Firestore.
  /// Questions currently on screen are excluded so a prefetched session
  /// never repeats an unanswered question from the active one.
  Future<List<_Question>> _fetchSession() async {
    final exclude = {
      ..._questions.map((q) => q.id),
      ..._nextBatch.map((q) => q.id),
    };
    final session = await QuestionService.getSessionQuestions(
      widget.categoryId,
      excludeIds: exclude,
    );
    if (session.isEmpty) throw Exception('No questions available.');
    return session.map(_Question.fromTrivia).toList();
  }

  // ── Game flow ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _timerBumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    // Basketball-style vertical bounce: drop down → snap up → settle → rest
    _streakBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );
    _streakBounceAnim = TweenSequence<double>([
      // 0–40%: drop down 8px (gravity accelerates)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 8.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      // 40–70%: snap back up past rest to -4px (elastic rebound)
      TweenSequenceItem(
        tween: Tween<double>(begin: 8.0, end: -4.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      // 70–85%: settle back down to 2px (losing energy)
      TweenSequenceItem(
        tween: Tween<double>(begin: -4.0, end: 2.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      // 85–100%: return to rest at 0px
      TweenSequenceItem(
        tween: Tween<double>(begin: 2.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
    ]).animate(_streakBounceCtrl);

    PreferencesService.getHapticsEnabled().then((v) => _hapticsEnabled = v);
    _startGame();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _timerBumpCtrl.dispose();
    _streakBounceCtrl.dispose();
    SoundService.dispose();
    super.dispose();
  }

  Future<void> _startGame() async {
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _countdownGeneration++;
    _streakBounceCtrl.stop();
    _streakBounceCtrl.reset();
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
      _urgentSoundActive = false;
      _countingDown = false;
      _countdownValue = 3;
      _countdownOverlayVisible = false;
    });

    PreferencesService.getHapticsEnabled().then((v) => _hapticsEnabled = v);
    SoundService.syncPreferences();  // prime the cache before game starts

    final user = AuthService.currentUser;
    if (user != null) {
      UserService.getUserData(user.uid).then((data) => _userDataSnapshot = data).catchError((_) => null);
    }

    try {
      final questions = await _fetchSession();
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _difficulty = _difficultyOf(questions.first);
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
        return;
      }
      if (_timeRemaining == 8 && !_urgentSoundActive) {
        _urgentSoundActive = true;
        SoundService.stopBackgroundMusic();
        SoundService.startTicToc();
      }
      if (_timeRemaining <= 8 && _hapticsEnabled) {
        HapticFeedback.selectionClick();
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
    setState(() => _countdownValue = 0);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || _countdownGeneration != generation) return;
    setState(() => _countdownOverlayVisible = false);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _countdownGeneration != generation) return;
    setState(() => _countingDown = false);
    SoundService.startBackgroundMusic();
    _startCountdown();
  }

  void _endGame() {
    _countdownTimer?.cancel();
    _feedbackTimer?.cancel();
    _streakBounceCtrl.stop();

    // Timer can run out with an unanswered question on screen — mark it too.
    if (!_answered && _qIndex < _questions.length) {
      QuestionService.markSeen(widget.categoryId, _questions[_qIndex].id);
    }
    SoundService.stopTicToc();
    SoundService.stopBackgroundMusic();
    SoundService.playGameOver();

    final base = _correctCount * 100;
    final streakBonus = _highestStreak * 50;
    final timeBonus = _timeRemaining.clamp(0, 9999) * 10;
    final score = base + streakBonus + timeBonus;
    final xp = (_correctCount * 10) + 5 + (_highestStreak * 3);
    final firstGameToday = UserService.isFirstGameToday(_userDataSnapshot);
    final coins = 10 + (_correctCount * 2) + (_highestStreak >= 5 ? 15 : 0) + (firstGameToday ? 20 : 0);
    final xpBefore = (_userDataSnapshot?['xp'] as int?) ?? 0;

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
    _countdownTimer?.cancel();

    // Never show this question again on this device (fire-and-forget).
    QuestionService.markSeen(widget.categoryId, _questions[_qIndex].id);

    final isCorrect = answer == _questions[_qIndex].correct;
    int newTime = _timeRemaining;

    if (isCorrect) {
      _correctCount++;
      _currentStreak++;
      if (_currentStreak > _highestStreak) _highestStreak = _currentStreak;

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
      _showFeedback('+${bonus}s', AppTheme.electricBlue, streakLabel: streakLabel);

      SoundService.playCorrect();
      if (_hapticsEnabled) {
        if (_currentStreak == 3 || _currentStreak == 5) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }

      if (_urgentSoundActive && newTime > 8) {
        _urgentSoundActive = false;
        SoundService.stopTicToc();
        SoundService.startBackgroundMusic();
      }

      // Start/continue streak bounce
      if (_currentStreak >= 2 && !_streakBounceCtrl.isAnimating) {
        _streakBounceCtrl.repeat();
      }
    } else {
      _wrongCount++;
      _currentStreak = 0;
      newTime -= 3;
      _showFeedback('-3s', AppTheme.blazeOrange);

      SoundService.playWrong();
      if (_hapticsEnabled) HapticFeedback.heavyImpact();

      // Stop streak bounce
      _streakBounceCtrl.stop();
      _streakBounceCtrl.reset();
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

  /// Difficulty pill follows the current question (sessions come pre-ordered
  /// easy → medium → hard from QuestionService).
  static _Difficulty _difficultyOf(_Question q) => switch (q.difficulty) {
    'hard' => _Difficulty.hard,
    'medium' => _Difficulty.medium,
    _ => _Difficulty.easy,
  };

  Future<void> _advanceQuestion() async {
    if (!mounted) return;

    _qIndex++;

    if (_qIndex >= _questions.length) {
      if (_nextBatch.isNotEmpty) {
        setState(() {
          _questions = _nextBatch;
          _nextBatch = [];
          _qIndex = 0;
          _prefetching = false;
          _difficulty = _difficultyOf(_questions[0]);
          _selectedAnswer = null;
          _answered = false;
        });
        _startCountdown();
        _maybePrefetch();
      } else {
        setState(() {
          _loadingNextBatch = true;
          _selectedAnswer = null;
          _answered = false;
        });
        try {
          final batch = await _fetchSession();
          if (!mounted) return;
          setState(() {
            _questions = batch;
            _qIndex = 0;
            _difficulty = _difficultyOf(batch[0]);
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
        _difficulty = _difficultyOf(_questions[_qIndex]);
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
    final flashColor = color == AppTheme.electricBlue ? Colors.white : color;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _timerBumpColor = flashColor);
      _timerBumpCtrl.forward(from: 0);
    });
  }

  // ── Cheat methods ─────────────────────────────────────────────────────────

  void _cheatAddTime() => setState(() => _timeRemaining = (_timeRemaining + 30).clamp(0, 9999));
  void _cheatForceCorrect() {
    if (_answered || _phase != _GamePhase.playing) return;
    _onAnswer(_questions[_qIndex].correct);
  }
  void _cheatForceWrong() {
    if (_answered || _phase != _GamePhase.playing) return;
    final wrong = _questions[_qIndex].answers.firstWhere((a) => a != _questions[_qIndex].correct);
    _onAnswer(wrong);
  }
  void _cheatSetHard() => setState(() => _difficulty = _Difficulty.hard);
  void _cheatSetEasy() => setState(() => _difficulty = _Difficulty.easy);

  void _maybePrefetch() {
    if (_prefetching || _nextBatch.isNotEmpty) return;
    if (_questions.length - _qIndex > 3) return;
    _prefetching = true;
    _fetchSession()
        .then((batch) {
          if (!mounted) return;
          setState(() {
            _nextBatch = batch;
            _prefetching = false;
          });
        })
        .catchError((_) {
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Quit Game?', style: AppTheme.subheading.copyWith(fontSize: 20), textAlign: TextAlign.center),
        content: Text('Your progress will be lost.', style: AppTheme.bodyMuted, textAlign: TextAlign.center),
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
                    color: AppTheme.electricBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Keep Playing', textAlign: TextAlign.center, style: AppTheme.buttonLabel),
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
                    color: AppTheme.softGrey,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.deepGrey),
                  ),
                  child: Text('Quit', textAlign: TextAlign.center, style: AppTheme.buttonLabel.copyWith(color: AppTheme.steel)),
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
  int get _accuracy => _totalAnswered == 0 ? 0 : (_correctCount / _totalAnswered * 100).round();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_countingDown) return;
        if (_phase == _GamePhase.playing) _showQuitDialog();
      },
      child: Scaffold(
        backgroundColor: AppTheme.cloudWhite,
        body: switch (_phase) {
          _GamePhase.loading => const _LoadingView(),
          _GamePhase.error => _ErrorView(message: _errorMessage, onRetry: _startGame),
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
                streakBounceAnim: _streakBounceAnim,
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
                  child: _CountdownOverlay(value: _countdownValue, onCancel: _cancelCountdown),
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
          const CircularProgressIndicator(color: AppTheme.electricBlue, strokeWidth: 3),
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
              const Icon(Icons.wifi_off_rounded, color: AppTheme.steel, size: 56),
              const SizedBox(height: 20),
              Text('Could Not Load Questions', textAlign: TextAlign.center, style: AppTheme.subheading.copyWith(fontSize: 20)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMuted),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.electricBlue, borderRadius: BorderRadius.circular(12)),
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
  final Animation<double>? streakBounceAnim;

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
    this.streakBounceAnim,
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

  static BorderRadius _borderRadiusForIndex(int i) => switch (i) {
    0 => const BorderRadius.only(topLeft: Radius.circular(16)),
    1 => const BorderRadius.only(topRight: Radius.circular(16)),
    2 => const BorderRadius.only(bottomLeft: Radius.circular(16)),
    _ => const BorderRadius.only(bottomRight: Radius.circular(16)),
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 32 - 8) / 2; // 16px pad each side + 8px gap
    final buttonAspectRatio = buttonWidth / 72.0;

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top bar ─────────────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // X quit button
                      GestureDetector(
                        onTap: onQuit,
                        child: const Icon(Icons.close_rounded, color: AppTheme.ink, size: 22),
                      ),
                      const Spacer(),
                      // Difficulty pill: small dot + label in ink
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.softGrey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _difficultyColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              difficulty.name.toUpperCase(),
                              style: AppTheme.difficultyBadge,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Score pill: softGrey bg, orange star + orange score
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.softGrey,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: AppTheme.blazeOrange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '$liveScore',
                              style: AppTheme.statValue.copyWith(color: AppTheme.blazeOrange),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Timer (sits directly on cloudWhite background) ───────────
                Center(
                  child: _CircularTimer(
                    timeRemaining: timeRemaining,
                    bumpCtrl: timerBumpCtrl,
                    bumpColor: timerBumpColor,
                  ),
                ),

                // Cheat bar (dev mode only)
                if (cheats != null) _CheatBar(cheats: cheats!),

                const SizedBox(height: 44), // space for streak indicator overlay

                // ── Question card (Expanded) ──────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: loadingNextBatch
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.ink.withAlpha(20),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: AppTheme.electricBlue,
                                    strokeWidth: 3,
                                  ),
                                  const SizedBox(height: 14),
                                  Text('Loading next questions…', style: AppTheme.bodyMuted),
                                ],
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.ink.withAlpha(20),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: AutoSizeText(
                                  question.text,
                                  style: AppTheme.questionText,
                                  textAlign: TextAlign.center,
                                  minFontSize: 13,
                                  maxFontSize: 19,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Answer grid (2×2) ─────────────────────────────────────────
                if (!loadingNextBatch)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: buttonAspectRatio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (int i = 0; i < question.answers.length; i++)
                          _AnswerButton(
                            text: question.answers[i],
                            state: _stateFor(question.answers[i]),
                            onTap: answered ? null : () => onAnswer(question.answers[i]),
                            borderRadius: _borderRadiusForIndex(i),
                          ),
                      ],
                    ),
                  ),

                if (loadingNextBatch) const SizedBox(height: 20),
              ],
            ),
          ),

          // ── Streak indicator (floating pill, centered in gap below timer) ──
          if (currentStreak >= 2)
            Builder(
              builder: (context) {
                // Named heights so the center calculation stays readable.
                const double kTopBar = 46.0;   // vertical:12 pad × 2 + icon 22
                const double kTimerGap = 16.0; // SizedBox before timer
                const double kTimer = 90.0;    // _CircularTimer SizedBox height
                const double kBelowTimer = 44.0; // SizedBox(height: 44) gap
                const double kPillHeight = 34.0; // pill padding + text height
                const double top = kTopBar + kTimerGap + kTimer
                    + (kBelowTimer / 2) - (kPillHeight / 2);

                return Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: streakBounceAnim != null
                        ? AnimatedBuilder(
                            animation: streakBounceAnim!,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, streakBounceAnim!.value),
                              child: child,
                            ),
                            child: _StreakPill(streak: currentStreak),
                          )
                        : _StreakPill(streak: currentStreak),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Streak pill ───────────────────────────────────────────────────────────────

class _StreakPill extends StatelessWidget {
  final int streak;
  const _StreakPill({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.softOrange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('🔥 x$streak', style: AppTheme.streakText),
    );
  }
}

// ── Countdown overlay ─────────────────────────────────────────────────────────

class _CountdownOverlay extends StatelessWidget {
  final int value;
  final VoidCallback onCancel;

  const _CountdownOverlay({required this.value, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.cloudWhite,
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
                  color: AppTheme.electricBlue,
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
                  style: AppTheme.sectionHeader.copyWith(color: AppTheme.steel, letterSpacing: 3),
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

  const _CircularTimer({required this.timeRemaining, this.bumpCtrl, this.bumpColor});

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
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
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
    final baseColor = isUrgent ? AppTheme.blazeOrange : AppTheme.electricBlue;
    final progress = (widget.timeRemaining / 30.0).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _animListenable,
      builder: (context, _) {
        final pulseScale = isUrgent ? _pulseAnim.value : 1.0;
        final bumpScaleVal = _bumpScale?.value ?? 1.0;

        final Color arcColor;
        if (_bumpScale != null && widget.bumpColor != null) {
          final t = _bumpScale!.value.clamp(0.0, 1.0);
          arcColor = Color.lerp(widget.bumpColor!, baseColor, t) ?? baseColor;
        } else {
          arcColor = baseColor;
        }

        return Transform.scale(
          scale: pulseScale * bumpScaleVal,
          child: SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CustomPaint(
                    painter: _ArcPainter(
                      progress: progress,
                      color: arcColor,
                      bgColor: AppTheme.deepGrey,
                    ),
                  ),
                ),
                // Number always ink colored per design spec
                Text('${widget.timeRemaining}', style: AppTheme.timerText),
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

  const _ArcPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 6.0;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -pi / 2;

    canvas.drawArc(
      rect, startAngle, 2 * pi, false,
      Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect, startAngle, 2 * pi * progress, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color || old.bgColor != bgColor;
}

// ── Answer button (2×2 grid, asymmetric corners, press scale) ─────────────────

class _AnswerButton extends StatefulWidget {
  final String text;
  final _AnswerState state;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const _AnswerButton({
    required this.text,
    required this.state,
    this.onTap,
    required this.borderRadius,
  });

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isCorrect = widget.state == _AnswerState.correct;
    final isWrong = widget.state == _AnswerState.wrong;

    final Color bg;
    final Color borderColor;
    final double borderWidth;
    final Color textColor;

    if (isCorrect) {
      bg = AppTheme.skyBlue;
      borderColor = AppTheme.electricBlue;
      borderWidth = 2.0;
      textColor = AppTheme.electricBlue;
    } else if (isWrong) {
      bg = AppTheme.softOrange;
      borderColor = AppTheme.blazeOrange;
      borderWidth = 2.0;
      textColor = AppTheme.blazeOrange;
    } else {
      bg = Colors.white;
      borderColor = AppTheme.deepGrey;
      borderWidth = 1.5;
      textColor = AppTheme.ink;
    }

    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null) setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: widget.borderRadius,
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: AutoSizeText(
                widget.text,
                style: AppTheme.answerText.copyWith(color: textColor),
                textAlign: TextAlign.center,
                minFontSize: 11,
                maxFontSize: 15,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
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
    final endProgress = rangeSize > 0 ? (xpInLevel / rangeSize).clamp(0.0, 1.0) : 1.0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 14),

            // ── Title ────────────────────────────────────────────────
            Text(_headline, style: AppTheme.storeTitle, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text('GAME OVER', style: AppTheme.sectionHeader, textAlign: TextAlign.center),
            const SizedBox(height: 12),

            // ── Stats card ───────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.electricBlue.withAlpha(80), width: 1),
                  boxShadow: [BoxShadow(color: AppTheme.ink.withAlpha(12), blurRadius: 12, offset: const Offset(0, 3))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ResultRow(
                      label: 'FINAL SCORE',
                      value: '$score',
                      valueStyle: AppTheme.subheading.copyWith(color: AppTheme.electricBlue, fontSize: 22),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: AppTheme.deepGrey, height: 1),
                    const SizedBox(height: 10),
                    _ResultRow(label: 'CORRECT ANSWERS', value: '$correctCount'),
                    const SizedBox(height: 6),
                    _ResultRow(label: 'HIGHEST STREAK', value: '$highestStreak'),
                    const SizedBox(height: 6),
                    _ResultRow(label: 'ACCURACY', value: '$accuracy%'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Rewards card ─────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.deepGrey, width: 1),
                  boxShadow: [BoxShadow(color: AppTheme.ink.withAlpha(12), blurRadius: 12, offset: const Offset(0, 3))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REWARDS EARNED', style: AppTheme.sectionHeader),
                    const SizedBox(height: 10),
                    _RewardRow(icon: Icons.star_rounded, label: 'SCORE', value: score, suffix: ' pts'),
                    const SizedBox(height: 8),
                    _RewardRow(icon: Icons.toll_rounded, label: 'COINS', value: coinsEarned, suffix: ''),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, color: AppTheme.electricBlue, size: 18),
                        const SizedBox(width: 8),
                        Text('XP', style: AppTheme.sectionHeader),
                        const Spacer(),
                        if (didLevelUp)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.electricBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LEVEL UP! → Lv.$levelAfter',
                              style: AppTheme.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          )
                        else
                          TweenAnimationBuilder<int>(
                            tween: IntTween(begin: 0, end: xpEarned),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOut,
                            builder: (_, val, _) => Text('+$val xp', style: AppTheme.rewardText),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: beginProgress, end: endProgress),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOut,
                      builder: (_, val, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: val,
                          minHeight: 10,
                          backgroundColor: AppTheme.deepGrey,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.electricBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lv.$levelAfter · ${UserService.titleForLevel(levelAfter)}', style: AppTheme.caption),
                        Text('$xpInLevel / $rangeSize xp', style: AppTheme.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Sign-in banner (guests only) ─────────────────────────
            if (!isSignedIn) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.electricBlue.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: AppTheme.electricBlue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sign in to save your score and rewards',
                        style: AppTheme.caption.copyWith(color: AppTheme.electricBlue, fontSize: 12),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.electricBlue, size: 12),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Buttons ──────────────────────────────────────────────
            GestureDetector(
              onTap: onPlayAgain,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('PLAY AGAIN', textAlign: TextAlign.center, style: AppTheme.buttonLabel.copyWith(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onHome,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.deepGrey, width: 1.5),
                ),
                child: Text('HOME', textAlign: TextAlign.center, style: AppTheme.buttonLabel.copyWith(color: AppTheme.steel, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
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

  const _RewardRow({required this.icon, required this.label, required this.value, required this.suffix});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.electricBlue, size: 18),
        const SizedBox(width: 8),
        Text(label, style: AppTheme.sectionHeader),
        const Spacer(),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (_, val, _) => Text('+$val$suffix', style: AppTheme.rewardText),
        ),
      ],
    );
  }
}

// ── Result row ────────────────────────────────────────────────────────────────

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
        Text(value, style: valueStyle ?? AppTheme.statValue),
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
          color: AppTheme.softOrange,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.blazeOrange.withAlpha(100), width: 1),
        ),
        child: Text(label, style: AppTheme.caption.copyWith(color: AppTheme.blazeOrange, fontWeight: FontWeight.w800)),
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

  const _FeedbackAnimation({required this.text, required this.color, this.streakLabel, required this.onDone});

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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 1.2).chain(CurveTween(curve: Curves.easeOut)), weight: 37.5),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 12.5),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 50),
    ]).animate(_ctrl);

    _offsetY = Tween<double>(begin: 0, end: -150).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.75, curve: Curves.easeOut)),
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.625, 1.0, curve: Curves.easeIn)),
    );

    _ctrl.forward().then((_) { if (mounted) widget.onDone(); });
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
                        Text(widget.streakLabel!, style: AppTheme.streakText.copyWith(fontSize: 20, color: widget.color)),
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

import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/room_service.dart';
import '../theme/app_theme.dart';
import 'lobby_screen.dart';

class FriendGameScreen extends StatefulWidget {
  final String roomId;
  final String myUid;
  final bool isHost;
  final String hostName;
  final String guestName;

  const FriendGameScreen({
    super.key,
    required this.roomId,
    required this.myUid,
    required this.isHost,
    required this.hostName,
    required this.guestName,
  });

  @override
  State<FriendGameScreen> createState() => _FriendGameScreenState();
}

class _FriendGameScreenState extends State<FriendGameScreen>
    with TickerProviderStateMixin {
  // ── Timers ─────────────────────────────────────────────────────────────────
  Timer? _gameTimer;
  Timer? _answerTimer;
  Timer? _heartbeatTimer;
  Timer? _getReadyTimer;
  Timer? _disconnectTimer;

  // ── Game state ─────────────────────────────────────────────────────────────
  int _gameSecondsLeft = 180;
  int _answerSecondsLeft = 0;
  int _getReadyCount = 3;
  bool _showGetReady = false;
  bool _showSuddenDeathBanner = false;
  bool _gameStarted = false;
  bool _gameEnded = false;
  bool _navigating = false;
  String? _myAnswer;
  bool _answered = false;
  String? _lastQuestionId;
  String? _lastPhase;
  String? _lastBuzzerWinner;
  bool _isDisconnected = false;
  String _disconnectedName = '';
  int _disconnectSecondsLeft = 20;

  // ── Quit overlay ───────────────────────────────────────────────────────────
  bool _showQuitOverlay = false;
  String _quitOverlayName = '';
  Timer? _quitOverlayTimer;
  bool _quitOverlayTriggered = false;

  // ── Buzzer countdown (tenths of second, visual only) ───────────────────────
  Timer? _buzzerCountdownTimer;
  double _buzzerCountdownSecs = 0.0;
  bool _showBuzzerCountdown = false;

  // ── Answer reveal flash ────────────────────────────────────────────────────
  bool _revealCorrect = false;

  // ── Floating score animation ───────────────────────────────────────────────
  String? _floatingText;
  bool _floatOnMyCard = true;
  Color _floatColor = const Color(0xFF2563EB);
  int _trackedMyScore = 0;
  int _trackedOpScore = 0;
  String? _pendingFloatText;
  bool _pendingFloatOnMyCard = true;
  Color _pendingFloatColor = const Color(0xFF2563EB);
  Timer? _transitionSequenceTimer;

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _buzzerShakeCtrl;
  late final AnimationController _buzzerScaleCtrl;
  late final AnimationController _winnerGlowCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _buzzerShakeAnim;
  late final Animation<double> _buzzerScaleAnim;
  late final Animation<double> _winnerGlowAnim;
  late final Animation<double> _floatSlideAnim;
  late final Animation<double> _floatFadeAnim;
  late final Animation<double> _floatScaleAnim;

  String get _myName =>
      widget.isHost ? widget.hostName : widget.guestName;

  @override
  void initState() {
    super.initState();

    // Shake: rapid ±3 px left-right while buzzer is active
    _buzzerShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..repeat();
    _buzzerShakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3.0, end: 0.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -3.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 1),
    ]).animate(_buzzerShakeCtrl);

    _buzzerScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _buzzerScaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _buzzerScaleCtrl, curve: Curves.easeOut),
    );

    // Floating score animation
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _floatSlideAnim = Tween<double>(begin: 0.0, end: -70.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeOut),
    );
    _floatFadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 5),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 3),
    ]).animate(_floatCtrl);
    _floatScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 2),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 5),
    ]).animate(_floatCtrl);

    _winnerGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _winnerGlowAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _winnerGlowCtrl, curve: Curves.easeInOut),
    );

    // Heartbeat every 5 seconds
    RoomService.updateHeartbeat(widget.roomId, widget.myUid);
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      RoomService.updateHeartbeat(widget.roomId, widget.myUid);
    });

    // Host immediately sets status to 'playing'
    if (widget.isHost) {
      _startGameAsHost();
    }
  }

  Future<void> _startGameAsHost() async {
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .update({'status': 'playing'});
    } catch (_) {}
    _beginGameTimer();
  }

  void _beginGameTimer() {
    if (_gameStarted) return;
    _gameStarted = true;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_gameSecondsLeft > 0) {
          _gameSecondsLeft--;
        } else {
          _triggerGameEnd();
        }
      });
    });
  }

  void _triggerGameEnd() {
    if (_gameEnded) return;
    _gameEnded = true;
    _gameTimer?.cancel();
    _answerTimer?.cancel();
    RoomService.endGame(widget.roomId);
  }

  void _startAnswerTimer(int seconds) {
    _answerTimer?.cancel();
    setState(() => _answerSecondsLeft = seconds);
    _answerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_answerSecondsLeft > 0) {
          _answerSecondsLeft--;
        } else {
          _answerTimer?.cancel();
          _onAnswerTimeout();
        }
      });
    });
  }

  void _onAnswerTimeout() {
    if (_answered) return;
    setState(() {
      _answered = true;
      _myAnswer = null;
    });
    RoomService.submitAnswer(
      roomId: widget.roomId,
      uid: widget.myUid,
      answer: null,
    );
  }

  void _startGetReady() {
    if (_showGetReady) return;
    setState(() {
      _showGetReady = true;
      _getReadyCount = 3;
    });
    _getReadyTimer?.cancel();
    _getReadyTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_getReadyCount <= 1) {
        t.cancel();
        setState(() => _showGetReady = false);
        if (widget.isHost) {
          RoomService.nextQuestion(widget.roomId);
        }
      } else {
        setState(() => _getReadyCount--);
      }
    });
  }

  void _onPhaseChanged(String newPhase, RoomData room) {
    _lastPhase = newPhase;

    switch (newPhase) {
      case 'answering':
        if (room.buzzerWinner == widget.myUid) {
          _startAnswerTimer(3);
          _startBuzzerCountdown(3.0);
        } else {
          _answerTimer?.cancel();
          _stopBuzzerCountdown();
          setState(() => _answerSecondsLeft = 0);
        }
        break;

      case 'inherited':
        _stopBuzzerCountdown();
        final iAmInheritor = room.buzzerWinner != widget.myUid;
        // Play the -1 penalty float immediately (buzzer winner just got penalized),
        // then start the inheritor's 10s timer after the animation completes.
        if (_pendingFloatText != null) {
          setState(() {
            _floatingText = _pendingFloatText;
            _floatOnMyCard = _pendingFloatOnMyCard;
            _floatColor = _pendingFloatColor;
            _pendingFloatText = null;
          });
          _floatCtrl.forward(from: 0);
          if (iAmInheritor) {
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted && !_gameEnded) _startAnswerTimer(10);
            });
          } else {
            _answerTimer?.cancel();
            setState(() => _answerSecondsLeft = 0);
          }
        } else {
          // Fallback: no pending float, start timer immediately
          if (iAmInheritor) {
            _startAnswerTimer(10);
          } else {
            _answerTimer?.cancel();
            setState(() => _answerSecondsLeft = 0);
          }
        }
        break;

      case 'transition':
        _answerTimer?.cancel();
        _stopBuzzerCountdown();
        setState(() => _answerSecondsLeft = 0);
        _startTransitionSequence();
        break;

      case 'sudden_death':
        _answerTimer?.cancel();
        setState(() {
          _answerSecondsLeft = 0;
          _myAnswer = null;
          _answered = false;
          _showSuddenDeathBanner = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showSuddenDeathBanner = false);
        });
        break;

      case 'finished':
        _gameEnded = true;
        _gameTimer?.cancel();
        _answerTimer?.cancel();
        break;
    }
  }

  void _onBuzzerWinnerChanged(String? newWinner, RoomData room) {
    _lastBuzzerWinner = newWinner;

    // In sudden_death, when I win the buzzer, start an answer timer
    if (room.phase == 'sudden_death' && newWinner == widget.myUid) {
      _startAnswerTimer(10);
    }
  }

  void _onQuestionChanged(RoomData room) {
    _answerTimer?.cancel();
    _getReadyTimer?.cancel();
    _transitionSequenceTimer?.cancel();
    _stopBuzzerCountdown();
    if (_buzzerShakeCtrl.isAnimating == false) _buzzerShakeCtrl.repeat();
    setState(() {
      _myAnswer = null;
      _answered = false;
      _lastQuestionId = room.currentQuestion?.id;
      _answerSecondsLeft = 0;
      _showGetReady = false;
      _revealCorrect = false;
      _floatingText = null;
    });
  }

  void _startBuzzerCountdown(double seconds) {
    _buzzerShakeCtrl.stop();
    _buzzerCountdownTimer?.cancel();
    setState(() {
      _buzzerCountdownSecs = seconds;
      _showBuzzerCountdown = true;
    });
    _buzzerCountdownTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_buzzerCountdownSecs > 0.11) {
          _buzzerCountdownSecs = (_buzzerCountdownSecs - 0.1).clamp(0.0, seconds);
        } else {
          _buzzerCountdownSecs = 0.0;
          _showBuzzerCountdown = false;
          t.cancel();
        }
      });
    });
  }

  void _stopBuzzerCountdown() {
    _buzzerCountdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _showBuzzerCountdown = false;
        _buzzerCountdownSecs = 0.0;
      });
    }
    if (!_buzzerShakeCtrl.isAnimating) _buzzerShakeCtrl.repeat();
  }

  void _startTransitionSequence() {
    _transitionSequenceTimer?.cancel();
    // Trigger floating score if one is pending
    if (_pendingFloatText != null) {
      setState(() {
        _floatingText = _pendingFloatText;
        _floatOnMyCard = _pendingFloatOnMyCard;
        _floatColor = _pendingFloatColor;
        _pendingFloatText = null;
      });
      _floatCtrl.forward(from: 0);
    }
    // After float animation: reveal correct answer for 1 second, then Get Ready
    _transitionSequenceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _floatingText = null;
        _revealCorrect = true;
      });
      _transitionSequenceTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() => _revealCorrect = false);
        _startGetReady();
      });
    });
  }

  void _checkDisconnection(RoomData room) {
    final now = DateTime.now();
    const threshold = Duration(seconds: 12);

    final hostTs = room.hostConnected?.toDate();
    final guestJoined = room.guestUid != null;
    final guestTs = room.guestConnected?.toDate();

    bool disconnected = false;
    String name = '';

    if (hostTs != null && now.difference(hostTs) > threshold &&
        widget.myUid != room.hostUid) {
      disconnected = true;
      name = room.hostName;
    } else if (guestJoined &&
        guestTs != null &&
        now.difference(guestTs) > threshold &&
        widget.myUid != room.guestUid) {
      disconnected = true;
      name = room.guestName ?? 'Opponent';
    }

    if (disconnected && !_isDisconnected) {
      setState(() {
        _isDisconnected = true;
        _disconnectedName = name;
        _disconnectSecondsLeft = 20;
      });
      _disconnectTimer?.cancel();
      _disconnectTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          if (_disconnectSecondsLeft > 0) {
            _disconnectSecondsLeft--;
          } else {
            t.cancel();
            _triggerGameEnd();
          }
        });
      });
    } else if (!disconnected && _isDisconnected) {
      _disconnectTimer?.cancel();
      setState(() => _isDisconnected = false);
    }
  }

  Future<void> _tapBuzzer() async {
    _buzzerShakeCtrl.stop();
    await _buzzerScaleCtrl.forward();
    await _buzzerScaleCtrl.reverse();
    await RoomService.pressBuzzer(widget.roomId, widget.myUid);
  }

  void _tapAnswer(String answer, RoomData room) {
    if (_answered) return;
    final phase = room.phase;
    final iAmAllowedToAnswer =
        (phase == 'answering' && room.buzzerWinner == widget.myUid) ||
        (phase == 'inherited' && room.buzzerWinner != widget.myUid) ||
        (phase == 'sudden_death' && room.buzzerWinner == widget.myUid);
    if (!iAmAllowedToAnswer) return;

    setState(() {
      _myAnswer = answer;
      _answered = true;
    });
    _answerTimer?.cancel();
    RoomService.submitAnswer(
      roomId: widget.roomId,
      uid: widget.myUid,
      answer: answer,
    );
  }

  void _handleOpponentQuit(RoomData room) {
    if (_quitOverlayTriggered || _navigating) return;
    _quitOverlayTriggered = true;
    _gameEnded = true;
    _gameTimer?.cancel();
    _answerTimer?.cancel();

    final quitterName = room.nameFor(room.quitUid!);
    setState(() {
      _showQuitOverlay = true;
      _quitOverlayName = quitterName;
    });
    _winnerGlowCtrl.repeat(reverse: true);

    _quitOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _navigating = true;
      final myScore = room.scoreFor(widget.myUid);
      final opponentUid =
          widget.isHost ? room.guestUid : room.hostUid;
      final opponentScore =
          opponentUid != null ? room.scoreFor(opponentUid) : 0;
      final opponentName =
          widget.isHost ? (room.guestName ?? 'Opponent') : room.hostName;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _FriendResultsScreen(
            myUid: widget.myUid,
            myName: _myName,
            opponentName: opponentName,
            myScore: myScore,
            opponentScore: opponentScore,
            isWinner: true,
            isTie: false,
            correctAnswers: room.correctFor(widget.myUid),
            roomId: widget.roomId,
            isHost: widget.isHost,
            hostName: widget.hostName,
            guestName: widget.guestName,
          ),
        ),
      );
    });
  }

  void _navigateToResults(RoomData room) {
    if (_navigating || _showQuitOverlay) return;
    _navigating = true;
    _gameEnded = true;
    _gameTimer?.cancel();
    _answerTimer?.cancel();

    final myScore = room.scoreFor(widget.myUid);
    final opponentUid =
        widget.myUid == room.hostUid ? room.guestUid : room.hostUid;
    final opponentScore =
        opponentUid != null ? room.scoreFor(opponentUid) : 0;
    final opponentName = widget.isHost
        ? (room.guestName ?? 'Opponent')
        : room.hostName;
    final isWinner = myScore > opponentScore;
    final isTie = myScore == opponentScore;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _FriendResultsScreen(
          myUid: widget.myUid,
          myName: _myName,
          opponentName: opponentName,
          myScore: myScore,
          opponentScore: opponentScore,
          isWinner: isWinner,
          isTie: isTie,
          correctAnswers: room.correctFor(widget.myUid),
          roomId: widget.roomId,
          isHost: widget.isHost,
          hostName: widget.hostName,
          guestName: widget.guestName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _buzzerShakeCtrl.dispose();
    _buzzerScaleCtrl.dispose();
    _winnerGlowCtrl.dispose();
    _floatCtrl.dispose();
    _gameTimer?.cancel();
    _answerTimer?.cancel();
    _heartbeatTimer?.cancel();
    _getReadyTimer?.cancel();
    _disconnectTimer?.cancel();
    _quitOverlayTimer?.cancel();
    _buzzerCountdownTimer?.cancel();
    _transitionSequenceTimer?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _confirmQuit(),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: RoomService.roomStream(widget.roomId),
        builder: (context, snap) {
          if (!snap.hasData || snap.data?.data() == null) {
            return const Scaffold(
              backgroundColor: AppTheme.cloudWhite,
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snap.data!.data()!;
          final room = RoomData.fromSnapshot(data);

          // Guest starts game timer once host sets status to 'playing'
          if (!_gameStarted && room.status == 'playing' && !widget.isHost) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _beginGameTimer());
          }

          // Detect question change
          if (room.currentQuestion != null &&
              room.currentQuestion!.id != _lastQuestionId) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) {
              if (mounted) _onQuestionChanged(room);
            });
          }

          // Detect score changes → queue floating score for transition sequence
          if (_gameStarted) {
            final newMyScore = room.scoreFor(widget.myUid);
            final opUid = widget.isHost ? room.guestUid : room.hostUid;
            final newOpScore = opUid != null ? room.scoreFor(opUid) : 0;
            if (newMyScore != _trackedMyScore) {
              final delta = newMyScore - _trackedMyScore;
              _trackedMyScore = newMyScore;
              _pendingFloatText = delta > 0 ? '+$delta' : '$delta';
              _pendingFloatOnMyCard = true;
              _pendingFloatColor = delta > 0 ? AppTheme.electricBlue : AppTheme.blazeOrange;
            } else if (newOpScore != _trackedOpScore) {
              final delta = newOpScore - _trackedOpScore;
              _trackedOpScore = newOpScore;
              _pendingFloatText = delta > 0 ? '+$delta' : '$delta';
              _pendingFloatOnMyCard = false;
              _pendingFloatColor = delta > 0 ? AppTheme.electricBlue : AppTheme.blazeOrange;
            }
          }

          // Detect phase change
          if (room.phase != _lastPhase && !_gameEnded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_gameEnded) _onPhaseChanged(room.phase, room);
            });
          }

          // Detect buzzer winner change (for sudden_death answer timer)
          if (room.buzzerWinner != _lastBuzzerWinner) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onBuzzerWinnerChanged(room.buzzerWinner, room);
            });
          }

          // Disconnection monitoring
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _gameStarted) _checkDisconnection(room);
          });

          // Detect opponent quit
          if (room.quitUid != null &&
              room.quitUid != widget.myUid &&
              !_quitOverlayTriggered &&
              !_navigating) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _handleOpponentQuit(room);
            });
          }

          // Navigate to results when finished (only if not showing quit overlay)
          if (room.status == 'finished' && !_navigating && !_quitOverlayTriggered) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) {
              if (mounted) _navigateToResults(room);
            });
          }

          return Scaffold(
            backgroundColor: AppTheme.cloudWhite,
            body: SafeArea(
              child: Stack(
                children: [
                  _buildBody(room),
                  if (_showGetReady) _buildGetReadyOverlay(),
                  if (_showSuddenDeathBanner) _buildSuddenDeathOverlay(),
                  if (_isDisconnected) _buildDisconnectBanner(),
                  if (_showQuitOverlay) _buildQuitOverlay(),
                  if (_floatingText != null) _buildFloatingScore(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Game body ──────────────────────────────────────────────────────────────

  Widget _buildBody(RoomData room) {
    return Column(
      children: [
        _buildTopBar(room),
        const SizedBox(height: 8),
        _buildScoreRow(room),
        const SizedBox(height: 10),
        Expanded(
          flex: 3,
          child: _buildQuestionCard(room),
        ),
        const SizedBox(height: 6),
        _buildPhaseMessage(room),
        const SizedBox(height: 6),
        if (room.currentQuestion != null)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAnswerGrid(room, room.currentQuestion!),
            ),
          ),
        const SizedBox(height: 12),
        _buildBuzzer(room),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTopBar(RoomData room) {
    final mins = _gameSecondsLeft ~/ 60;
    final secs = (_gameSecondsLeft % 60).toString().padLeft(2, '0');
    final isSuddenDeath = room.phase == 'sudden_death';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _confirmQuit,
            child: const Icon(Icons.close_rounded, color: AppTheme.steel),
          ),
          const Spacer(),
          Column(
            children: [
              if (isSuddenDeath)
                Text(
                  'SUDDEN DEATH',
                  style: AppTheme.sectionHeader.copyWith(
                    color: AppTheme.blazeOrange,
                    letterSpacing: 1.5,
                  ),
                )
              else
                Text(
                  '$mins:$secs',
                  style: AppTheme.statValue.copyWith(
                    fontSize: 16,
                    color: _gameSecondsLeft <= 30
                        ? AppTheme.blazeOrange
                        : AppTheme.steel,
                  ),
                ),
              Text(
                room.category == 'geography' ? '🌍 Geography' : '🔬 Science',
                style: AppTheme.caption.copyWith(color: AppTheme.steel),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.softGrey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Q${room.currentQuestionIndex + 1}',
              style: AppTheme.caption.copyWith(color: AppTheme.steel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(RoomData room) {
    final opponentUid =
        widget.isHost ? room.guestUid : room.hostUid;
    final opponentScore =
        opponentUid != null ? room.scoreFor(opponentUid) : 0;
    final myScore = room.scoreFor(widget.myUid);
    final opponentName =
        widget.isHost ? (room.guestName ?? '...') : room.hostName;
    final myAvatar =
        widget.isHost ? room.hostAvatar : (room.guestAvatar ?? '');
    final opponentAvatar =
        widget.isHost ? (room.guestAvatar ?? '') : room.hostAvatar;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _ScoreCard(
              name: _myName,
              avatarUrl: myAvatar,
              score: myScore,
              isMine: true,
              isWinning: myScore > opponentScore,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('VS',
                style: AppTheme.sectionHeader
                    .copyWith(color: AppTheme.steel)),
          ),
          Expanded(
            child: _ScoreCard(
              name: opponentName,
              avatarUrl: opponentAvatar,
              score: opponentScore,
              isMine: false,
              isWinning: opponentScore > myScore,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(RoomData room) {
    final q = room.currentQuestion;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Center(
          child: AutoSizeText(
            q?.question ?? '',
            style: AppTheme.questionText,
            textAlign: TextAlign.center,
            minFontSize: 13,
            maxFontSize: 19,
            maxLines: 5,
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseMessage(RoomData room) {
    final phase = room.phase;
    String msg = '';
    Color color = AppTheme.steel;

    if (phase == 'answering') {
      if (room.buzzerWinner == widget.myUid) {
        msg = 'YOU BUZZED! — $_answerSecondsLeft s';
        color = AppTheme.electricBlue;
      } else {
        final who = widget.isHost
            ? (room.guestName ?? 'Opponent')
            : room.hostName;
        msg = '$who is answering...';
      }
    } else if (phase == 'inherited') {
      if (room.buzzerWinner != widget.myUid) {
        msg = 'Your turn! — $_answerSecondsLeft s';
        color = AppTheme.blazeOrange;
      } else {
        final who = widget.isHost
            ? (room.guestName ?? 'Opponent')
            : room.hostName;
        msg = '$who gets the inherited question...';
      }
    } else if (phase == 'sudden_death') {
      if (room.buzzerWinner == widget.myUid) {
        msg = 'YOU BUZZED! — $_answerSecondsLeft s';
        color = AppTheme.blazeOrange;
      } else if (room.buzzerWinner != null) {
        msg = 'Opponent buzzed first!';
      } else {
        msg = 'Press the buzzer!';
        color = AppTheme.blazeOrange;
      }
    } else if (phase == 'buzzer') {
      msg = 'Press the buzzer first!';
    }

    if (msg.isEmpty) return const SizedBox(height: 18);

    return SizedBox(
      height: 18,
      child: Text(
        msg,
        style: AppTheme.caption.copyWith(color: color, fontSize: 12),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildAnswerGrid(RoomData room, FriendQuestion q) {
    final answers = q.shuffledAnswers;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(answers.length > 4 ? 4 : answers.length, (i) {
        final answer = answers[i];
        final state = _answerStateFor(answer, room, q);
        return _AnswerButton(
          text: answer,
          state: state,
          borderRadius: _borderRadiusFor(i),
          onTap: state == 'active' ? () => _tapAnswer(answer, room) : null,
          // 'idle' has null onTap — white styling but non-tappable (buzzer phase)
        );
      }),
    );
  }

  String _answerStateFor(String answer, RoomData room, FriendQuestion q) {
    final phase = room.phase;
    final correct = q.correctAnswer;

    // Reveal flash: briefly show correct before Get Ready overlay
    if (_revealCorrect && answer == correct) return 'correct';

    // After I've answered — show result immediately
    if (_answered) {
      if (answer == _myAnswer) {
        return answer == correct ? 'correct' : 'wrong';
      }
      // Do NOT reveal correct answer here — only reveal during _revealCorrect flash
      if (answer == room.buzzerWrongAnswer && phase == 'inherited') {
        return 'crossed';
      }
      return 'greyed';
    }

    final iWonBuzzer = room.buzzerWinner == widget.myUid;

    switch (phase) {
      case 'buzzer':
        return 'idle'; // looks active, but onTap is null until buzzer won
      case 'answering':
        return iWonBuzzer ? 'active' : 'greyed';
      case 'inherited':
        if (answer == room.buzzerWrongAnswer) return 'crossed';
        if (!iWonBuzzer) return 'active'; // I am the inheritor
        return 'greyed';
      case 'sudden_death':
        if (room.buzzerWinner == null) return 'greyed';
        return iWonBuzzer ? 'active' : 'greyed';
      default:
        return 'greyed';
    }
  }

  BorderRadius _borderRadiusFor(int i) {
    const r = Radius.circular(14);
    switch (i) {
      case 0: return const BorderRadius.only(topLeft: r);
      case 1: return const BorderRadius.only(topRight: r);
      case 2: return const BorderRadius.only(bottomLeft: r);
      case 3: return const BorderRadius.only(bottomRight: r);
      default: return BorderRadius.circular(14);
    }
  }

  Widget _buildBuzzer(RoomData room) {
    final phase = room.phase;
    final buzzerActive = (phase == 'buzzer' && room.buzzerWinner == null) ||
        (phase == 'sudden_death' && room.buzzerWinner == null);
    final iWonBuzzer = room.buzzerWinner == widget.myUid;
    final opponentWon = room.buzzerWinner != null && !iWonBuzzer;

    Color bgColor;
    if (buzzerActive) {
      bgColor = const Color(0xFFDC2626);
    } else if (iWonBuzzer) {
      bgColor = _showBuzzerCountdown ? AppTheme.electricBlue : const Color(0xFF16A34A);
    } else {
      bgColor = AppTheme.deepGrey;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: buzzerActive ? _tapBuzzer : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_buzzerShakeAnim, _buzzerScaleAnim]),
            builder: (context2, child2) {
              final shake = buzzerActive ? _buzzerShakeAnim.value : 0.0;
              final scale = _buzzerScaleAnim.value;
              return Transform.translate(
                offset: Offset(shake, 0),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bgColor,
                    ),
                    child: Center(
                      child: _showBuzzerCountdown && iWonBuzzer
                          ? Text(
                              _buzzerCountdownSecs.toStringAsFixed(1),
                              style: const TextStyle(
                                fontFamily: 'FiraSans',
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            )
                          : _buildBuzzerInner(
                              buzzerActive: buzzerActive,
                              iWonBuzzer: iWonBuzzer,
                              opponentWon: opponentWon,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (opponentWon)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Too slow!',
              style: AppTheme.caption.copyWith(
                color: AppTheme.steel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBuzzerInner({
    required bool buzzerActive,
    required bool iWonBuzzer,
    required bool opponentWon,
  }) {
    if (buzzerActive) {
      return Text(
        'BUZZ!',
        style: const TextStyle(
          fontFamily: 'FiraSans',
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      );
    } else if (iWonBuzzer) {
      return const Icon(Icons.check_rounded, color: Colors.white, size: 36);
    } else if (opponentWon) {
      return const Icon(Icons.lock_rounded, color: AppTheme.steel, size: 32);
    } else {
      return const Icon(Icons.bolt_rounded, color: AppTheme.steel, size: 32);
    }
  }

  // ── Overlays ───────────────────────────────────────────────────────────────

  Widget _buildGetReadyOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.cloudWhite.withAlpha(245),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NEXT QUESTION',
              style: AppTheme.sectionHeader
                  .copyWith(color: AppTheme.steel, letterSpacing: 3),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$_getReadyCount',
                key: ValueKey(_getReadyCount),
                style: AppTheme.timerText
                    .copyWith(fontSize: 80, color: AppTheme.electricBlue),
              ),
            ),
            const SizedBox(height: 20),
            Text('Get ready...', style: AppTheme.bodyMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildSuddenDeathOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.cloudWhite.withAlpha(230),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.whatshot_rounded,
                  color: AppTheme.blazeOrange, size: 56),
              const SizedBox(height: 12),
              Text(
                'SUDDEN DEATH',
                style: AppTheme.screenTitle
                    .copyWith(color: AppTheme.blazeOrange, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                "It's a tie! First correct answer wins.",
                style: AppTheme.bodyMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingScore() {
    // Anchored in the score row area (~140px from top). Floats upward 70px.
    final isLeft = _floatOnMyCard;
    return AnimatedBuilder(
      animation: _floatCtrl,
      builder: (_, child) => Positioned(
        top: 100 + _floatSlideAnim.value,
        left: isLeft ? 32 : null,
        right: isLeft ? null : 32,
        child: Opacity(
          opacity: _floatFadeAnim.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _floatScaleAnim.value,
            child: Text(
              _floatingText ?? '',
              style: TextStyle(
                fontFamily: 'FiraSans',
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _floatColor,
                shadows: [
                  Shadow(
                    color: _floatColor.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuitOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.ink.withAlpha(210),
        child: Center(
          child: AnimatedBuilder(
            animation: _winnerGlowAnim,
            builder: (_, child) {
              final glow = _winnerGlowAnim.value;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withAlpha((120 * glow).toInt()),
                      blurRadius: 24 + glow * 20,
                      spreadRadius: 2 + glow * 4,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                Text(
                  '$_quitOverlayName has left the game.',
                  style: AppTheme.subheading.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You win!',
                  style: AppTheme.storeTitle.copyWith(color: AppTheme.electricBlue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Redirecting to results...',
                  style: AppTheme.bodyMuted,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDisconnectBanner() {
    return Positioned(
      top: 72,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.blazeOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_disconnectedName disconnected',
              style: AppTheme.statValue.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            Text(
              'Ending in $_disconnectSecondsLeft s...',
              style:
                  AppTheme.caption.copyWith(color: Colors.white.withAlpha(200)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Quit dialog ────────────────────────────────────────────────────────────

  Future<void> _confirmQuit() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.softGrey,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Quit Game?',
          style: AppTheme.subheading.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Your opponent will win if you leave.',
          style: AppTheme.bodyMuted,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.electricBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Keep Playing',
                        textAlign: TextAlign.center,
                        style: AppTheme.buttonLabel),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.deepGrey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Quit',
                      textAlign: TextAlign.center,
                      style:
                          AppTheme.buttonLabel.copyWith(color: AppTheme.steel),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await RoomService.quitGame(widget.roomId, widget.myUid);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _QuitResultsScreen(
            myUid: widget.myUid,
            roomId: widget.roomId,
            isHost: widget.isHost,
          ),
        ),
      );
    }
  }
}

// ── Answer button ──────────────────────────────────────────────────────────────

class _AnswerButton extends StatefulWidget {
  final String text;
  final String state; // active | greyed | correct | wrong | crossed
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.text,
    required this.state,
    required this.borderRadius,
    required this.onTap,
  });

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    Color bg, border, textColor;
    bool strikethrough = false;

    switch (widget.state) {
      case 'correct':
        bg = AppTheme.skyBlue;
        border = AppTheme.electricBlue;
        textColor = AppTheme.electricBlue;
        break;
      case 'wrong':
        bg = AppTheme.softOrange;
        border = AppTheme.blazeOrange;
        textColor = AppTheme.blazeOrange;
        break;
      case 'crossed':
        bg = AppTheme.softGrey;
        border = AppTheme.deepGrey;
        textColor = AppTheme.steel;
        strikethrough = true;
        break;
      case 'greyed':
        bg = AppTheme.softGrey.withAlpha(160);
        border = AppTheme.deepGrey.withAlpha(80);
        textColor = AppTheme.steel.withAlpha(140);
        break;
      case 'idle':
      default: // active or idle — white, fully styled, no press handler on idle
        bg = Colors.white;
        border = AppTheme.deepGrey;
        textColor = AppTheme.ink;
    }

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: widget.borderRadius,
            border: Border.all(color: border, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Center(
            child: AutoSizeText(
              widget.text,
              style: AppTheme.answerText.copyWith(
                color: textColor,
                decoration:
                    strikethrough ? TextDecoration.lineThrough : null,
              ),
              textAlign: TextAlign.center,
              minFontSize: 11,
              maxFontSize: 15,
              maxLines: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Score card ─────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final int score;
  final bool isMine;
  final bool isWinning;

  const _ScoreCard({
    required this.name,
    required this.avatarUrl,
    required this.score,
    required this.isMine,
    required this.isWinning,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isMine
            ? AppTheme.electricBlue.withAlpha(12)
            : AppTheme.softGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? AppTheme.electricBlue.withAlpha(80)
              : AppTheme.deepGrey,
          width: isMine ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.electricBlue.withAlpha(40),
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTheme.caption
                        .copyWith(color: AppTheme.electricBlue),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.split(' ').first,
                  style: AppTheme.caption.copyWith(color: AppTheme.steel),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$score',
                  style: AppTheme.subheading.copyWith(
                    fontSize: 18,
                    color: isWinning
                        ? AppTheme.electricBlue
                        : AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
          if (isWinning)
            const Icon(Icons.arrow_upward_rounded,
                color: AppTheme.electricBlue, size: 14),
        ],
      ),
    );
  }
}

// ── Results screen ─────────────────────────────────────────────────────────────

class _FriendResultsScreen extends StatefulWidget {
  final String myUid;
  final String myName;
  final String opponentName;
  final int myScore;
  final int opponentScore;
  final bool isWinner;
  final bool isTie;
  final int correctAnswers;
  final String roomId;
  final bool isHost;
  final String hostName;
  final String guestName;

  const _FriendResultsScreen({
    required this.myUid,
    required this.myName,
    required this.opponentName,
    required this.myScore,
    required this.opponentScore,
    required this.isWinner,
    required this.isTie,
    required this.correctAnswers,
    required this.roomId,
    required this.isHost,
    required this.hostName,
    required this.guestName,
  });

  @override
  State<_FriendResultsScreen> createState() => _FriendResultsScreenState();
}

class _FriendResultsScreenState extends State<_FriendResultsScreen> {
  bool _returningToLobby = false;

  @override
  void initState() {
    super.initState();
    RoomService.saveFriendGameResult(
      uid: widget.myUid,
      correctAnswers: widget.correctAnswers,
      isWinner: widget.isWinner,
    );
  }

  Future<void> _navigateToLobby() async {
    if (_returningToLobby) return;
    setState(() => _returningToLobby = true);
    await RoomService.resetForRematch(widget.roomId);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          roomId: widget.roomId,
          myUid: widget.myUid,
          isHost: widget.isHost,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final xpEarned = widget.correctAnswers * 8 + (widget.isWinner ? 20 : 0);
    final coinsEarned = widget.correctAnswers * 2 + (widget.isWinner ? 15 : 0);

    final headline = widget.isTie
        ? "It's a Tie!"
        : widget.isWinner
            ? 'You Win!'
            : 'Good Game!';

    final headlineColor = widget.isTie
        ? AppTheme.steel
        : widget.isWinner
            ? AppTheme.electricBlue
            : AppTheme.ink;

    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                headline,
                style: AppTheme.storeTitle.copyWith(color: headlineColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                'GAME OVER',
                style: AppTheme.sectionHeader,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Scores card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: AppTheme.ink.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )],
                ),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Column(
                  children: [
                    Text('FINAL SCORES', style: AppTheme.sectionHeader),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ScoreColumn(
                          name: widget.myName,
                          score: widget.myScore,
                          highlight: widget.isWinner || widget.isTie,
                        ),
                        Text('VS',
                            style: AppTheme.sectionHeader
                                .copyWith(color: AppTheme.steel)),
                        _ScoreColumn(
                          name: widget.opponentName,
                          score: widget.opponentScore,
                          highlight: !widget.isWinner || widget.isTie,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Rewards card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: AppTheme.ink.withAlpha(10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )],
                ),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Column(
                  children: [
                    Text('REWARDS', style: AppTheme.sectionHeader),
                    const SizedBox(height: 12),
                    _RewardRow(
                      icon: Icons.bolt_rounded,
                      color: AppTheme.electricBlue,
                      label: 'XP EARNED',
                      value: '+$xpEarned',
                    ),
                    const SizedBox(height: 8),
                    _RewardRow(
                      icon: Icons.star_rounded,
                      color: AppTheme.blazeOrange,
                      label: 'COINS EARNED',
                      value: '+$coinsEarned',
                    ),
                    const SizedBox(height: 8),
                    _RewardRow(
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF16A34A),
                      label: 'CORRECT ANSWERS',
                      value: '${widget.correctAnswers}',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // PLAY AGAIN
              GestureDetector(
                onTap: _returningToLobby ? null : _navigateToLobby,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _returningToLobby
                        ? AppTheme.electricBlue.withAlpha(120)
                        : AppTheme.electricBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _returningToLobby
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('PLAY AGAIN', style: AppTheme.buttonLabel),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // LEAVE TO LOBBY (same action as Play Again — both return to room lobby)
              GestureDetector(
                onTap: _returningToLobby ? null : _navigateToLobby,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.electricBlue, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'LEAVE TO LOBBY',
                      style: AppTheme.buttonLabel
                          .copyWith(color: AppTheme.electricBlue),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // HOME
              GestureDetector(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.deepGrey),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'HOME',
                      style: AppTheme.buttonLabel.copyWith(color: AppTheme.steel),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String name;
  final int score;
  final bool highlight;

  const _ScoreColumn({
    required this.name,
    required this.score,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name.split(' ').first,
          style: AppTheme.bodyMuted.copyWith(color: AppTheme.steel),
        ),
        const SizedBox(height: 4),
        Text(
          '$score',
          style: AppTheme.subheading.copyWith(
            fontSize: 36,
            color: highlight ? AppTheme.electricBlue : AppTheme.ink,
          ),
        ),
        Text('pts', style: AppTheme.caption.copyWith(color: AppTheme.steel)),
      ],
    );
  }
}

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _RewardRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTheme.sectionHeader),
        ),
        Text(
          value,
          style: AppTheme.statValue.copyWith(color: color, fontSize: 16),
        ),
      ],
    );
  }
}

// ── Quitter's own results screen ───────────────────────────────────────────────

class _QuitResultsScreen extends StatefulWidget {
  final String myUid;
  final String roomId;
  final bool isHost;

  const _QuitResultsScreen({
    required this.myUid,
    required this.roomId,
    required this.isHost,
  });

  @override
  State<_QuitResultsScreen> createState() => _QuitResultsScreenState();
}

class _QuitResultsScreenState extends State<_QuitResultsScreen> {
  bool _returningToLobby = false;

  Future<void> _goToLobby() async {
    if (_returningToLobby) return;
    setState(() => _returningToLobby = true);
    await RoomService.resetForRematch(widget.roomId);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          roomId: widget.roomId,
          myUid: widget.myUid,
          isHost: widget.isHost,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Icon(Icons.flag_rounded, color: AppTheme.steel, size: 56),
              const SizedBox(height: 20),
              Text(
                'You Left',
                style: AppTheme.storeTitle.copyWith(color: AppTheme.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your opponent wins this round.',
                style: AppTheme.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              GestureDetector(
                onTap: _returningToLobby ? null : _goToLobby,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: _returningToLobby
                        ? AppTheme.electricBlue.withAlpha(120)
                        : AppTheme.electricBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _returningToLobby
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('GO TO LOBBY', style: AppTheme.buttonLabel),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.deepGrey),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'GO HOME',
                      style: AppTheme.buttonLabel.copyWith(color: AppTheme.steel),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'friend_game_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomId;
  final String myUid;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomId,
    required this.myUid,
    required this.isHost,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  Timer? _countdownTimer;
  int _countdownValue = 3;
  bool _showCountdown = false;
  bool _navigated = false;
  String _pendingCategory = 'science';
  bool _myReady = false;

  // Role tracking: starts from widget.isHost; updates when the current user
  // gets promoted from guest to host after the original host leaves the lobby.
  bool _amHost = false;
  bool _promotionTriggered = false;

  // Guest departure notification: track the last known guest UID/name so we
  // can show a snackbar when they leave.
  String? _trackedGuestUid;
  String? _trackedGuestName;

  @override
  void initState() {
    super.initState();
    _amHost = widget.isHost;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _syncAvatar();
  }

  Future<void> _syncAvatar() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final userData = await UserService.getUserData(user.uid);
    if (userData == null) return;
    await RoomService.syncPlayerAvatar(
      roomId: widget.roomId,
      user: user,
      userData: userData,
      isHost: widget.isHost,
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(RoomData room) {
    if (_showCountdown || _navigated) return;
    setState(() {
      _showCountdown = true;
      _countdownValue = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_countdownValue <= 1) {
        t.cancel();
        _navigateToGame(room);
      } else {
        setState(() => _countdownValue--);
      }
    });
  }

  void _navigateToGame(RoomData room) {
    if (_navigated) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FriendGameScreen(
          roomId: widget.roomId,
          myUid: widget.myUid,
          isHost: _amHost,
          hostName: room.hostName,
          guestName: room.guestName ?? 'Player',
        ),
      ),
    );
  }

  Future<void> _toggleReady(RoomData room) async {
    if (_myReady) {
      setState(() => _myReady = false);
      await RoomService.setUnready(widget.roomId, widget.myUid);
    } else {
      setState(() => _myReady = true);
      await RoomService.setReady(widget.roomId, widget.myUid);
    }
  }

  Future<void> _confirmLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.softGrey,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Leave Room?',
            style: AppTheme.subheading.copyWith(fontSize: 20),
            textAlign: TextAlign.center),
        content: Text(
          _amHost
              ? 'Leaving will delete the room for everyone.'
              : 'You will leave the room.',
          style: AppTheme.bodyMuted,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.deepGrey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Stay',
                      textAlign: TextAlign.center,
                      style: AppTheme.buttonLabel
                          .copyWith(color: AppTheme.steel)),
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
                    color: AppTheme.blazeOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Leave',
                      textAlign: TextAlign.center,
                      style: AppTheme.buttonLabel),
                ),
              ),
            ),
          ]),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await RoomService.leaveRoom(widget.roomId, widget.myUid);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  static String _categoryEmoji(String? cat) => switch (cat) {
    'geography' => '🌍',
    'history' => '📜',
    'general_knowledge' => '🧠',
    _ => '🔬',
  };

  static String _categoryLabel(String? cat) => switch (cat) {
    'geography' => 'Geography',
    'history' => 'History',
    'general_knowledge' => 'General Knowledge',
    _ => 'Science',
  };

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Room code ${widget.roomId} copied!'),
        backgroundColor: AppTheme.electricBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _confirmLeave(),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: RoomService.roomStream(widget.roomId),
        builder: (context, snap) {
          // Room deleted (host left)
          if (snap.hasData && !snap.data!.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_navigated) {
                _navigated = true;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('The host left the room.'),
                  backgroundColor: AppTheme.blazeOrange,
                ));
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            });
          }

          final data = snap.data?.data();
          final room = data != null ? RoomData.fromSnapshot(data) : null;

          if (room != null) {
            // ── Guest departure notification (host sees opponent leave) ──────
            if (_amHost &&
                _trackedGuestUid != null &&
                room.guestUid == null) {
              final leaverName = _trackedGuestName ?? 'Your opponent';
              _trackedGuestUid = null;
              _trackedGuestName = null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$leaverName left the room.'),
                    backgroundColor: AppTheme.blazeOrange,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ));
                }
              });
            }
            // Keep guest tracking up to date
            if (room.guestUid != null) {
              _trackedGuestUid = room.guestUid;
              _trackedGuestName = room.guestName;
            }

            // ── Host-leaves promotion: current user becomes the new host ─────
            if (!_amHost &&
                !_promotionTriggered &&
                room.hostUid == widget.myUid) {
              _promotionTriggered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _amHost = true);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('The host left. You are now the host!'),
                    backgroundColor: AppTheme.electricBlue,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ));
                }
              });
            }
          }

          // Sync local ready state from Firestore on first load
          if (room != null && !_showCountdown) {
            final firestoreReady = _amHost ? room.hostReady : room.guestReady;
            if (firestoreReady != _myReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _myReady = firestoreReady);
              });
            }
          }

          // Sync pending category from Firestore
          if (room != null && room.category != _pendingCategory) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _pendingCategory = room.category);
            });
          }

          // Trigger countdown when status == 'countdown'
          if (room != null &&
              room.status == 'countdown' &&
              !_showCountdown &&
              !_navigated) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _startCountdown(room));
          }

          return Scaffold(
            backgroundColor: AppTheme.cloudWhite,
            body: SafeArea(
              child: Stack(
                children: [
                  _buildBody(room),
                  if (_showCountdown) _buildCountdownOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(RoomData? room) {
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.ink),
                onPressed: _confirmLeave,
              ),
              const Spacer(),
              Text('LOBBY', style: AppTheme.appBarTitle),
              const Spacer(),
              const SizedBox(width: 48), // balance
            ],
          ),
        ),

        // Room code banner
        GestureDetector(
          onTap: _copyRoomCode,
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tag_rounded, color: Colors.white54, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.roomId,
                  style: AppTheme.subheading.copyWith(
                    color: Colors.white,
                    letterSpacing: 2,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.copy_rounded, color: Colors.white54, size: 16),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Tap to copy · Share with your friend',
            textAlign: TextAlign.center,
            style: AppTheme.caption.copyWith(color: AppTheme.steel),
          ),
        ),

        const SizedBox(height: 24),

        // Players section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('PLAYERS', style: AppTheme.sectionHeader),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Host card — Stack wrapper holds the HOST badge overlay
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.passthrough,
                    children: [
                      _PlayerSlot(
                        name: room?.hostName ?? '...',
                        avatarUrl: room?.hostAvatar ?? '',
                        level: room?.hostLevel ?? 1,
                        isReady: room?.hostReady ?? false,
                        isCurrentUser: widget.myUid == (room?.hostUid ?? ''),
                        pulse: false,
                      ),
                      Positioned(
                        top: -10,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.blazeOrange,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.blazeOrange.withAlpha(80),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            'HOST',
                            style: AppTheme.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Guest card — identical Stack wrapper, no badge
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.passthrough,
                    children: [
                      room?.guestUid != null
                          ? _PlayerSlot(
                              name: room!.guestName ?? 'Player',
                              avatarUrl: room.guestAvatar ?? '',
                              level: room.guestLevel,
                              isReady: room.guestReady,
                              isCurrentUser: widget.myUid == room.guestUid,
                              pulse: false,
                            )
                          : _WaitingSlot(pulseCtrl: _pulseCtrl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Session scoreboard — only shown after at least one game completed
        if (room != null &&
            (room.hostGamesWon > 0 || room.guestGamesWon > 0)) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('SESSION', style: AppTheme.sectionHeader),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.deepGrey),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.ink.withAlpha(8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _SessionStatCol(
                      name: room.hostName.split(' ').first,
                      gamesWon: room.hostGamesWon,
                      totalScore: room.hostTotalScore,
                      isCurrentUser: widget.myUid == room.hostUid,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: AppTheme.deepGrey,
                  ),
                  Expanded(
                    child: _SessionStatCol(
                      name: room.guestName?.split(' ').first ?? '...',
                      gamesWon: room.guestGamesWon,
                      totalScore: room.guestTotalScore,
                      isCurrentUser: room.guestUid != null &&
                          widget.myUid == room.guestUid,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Category section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text('CATEGORY', style: AppTheme.sectionHeader),
        ),
        const SizedBox(height: 12),
        if (_amHost)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CategoryChip(
                        emoji: '🔬',
                        label: 'Science',
                        selected: _pendingCategory == 'science',
                        onTap: () async {
                          if (_pendingCategory == 'science') return;
                          setState(() => _pendingCategory = 'science');
                          await RoomService.updateCategory(
                              widget.roomId, 'science');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CategoryChip(
                        emoji: '🌍',
                        label: 'Geography',
                        selected: _pendingCategory == 'geography',
                        onTap: () async {
                          if (_pendingCategory == 'geography') return;
                          setState(() => _pendingCategory = 'geography');
                          await RoomService.updateCategory(
                              widget.roomId, 'geography');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CategoryChip(
                        emoji: '📜',
                        label: 'History',
                        selected: _pendingCategory == 'history',
                        onTap: () async {
                          if (_pendingCategory == 'history') return;
                          setState(() => _pendingCategory = 'history');
                          await RoomService.updateCategory(
                              widget.roomId, 'history');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CategoryChip(
                        emoji: '🧠',
                        label: 'General Knowledge',
                        selected: _pendingCategory == 'general_knowledge',
                        onTap: () async {
                          if (_pendingCategory == 'general_knowledge') return;
                          setState(
                              () => _pendingCategory = 'general_knowledge');
                          await RoomService.updateCategory(
                              widget.roomId, 'general_knowledge');
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.softGrey,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.deepGrey),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _categoryEmoji(room?.category),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _categoryLabel(room?.category),
                    style: AppTheme.rowLabel,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 24),

        // Ready button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: GestureDetector(
            onTap: room?.guestUid == null
                ? null
                : () => _toggleReady(room!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 56,
              decoration: BoxDecoration(
                color: room?.guestUid == null
                    ? AppTheme.deepGrey
                    : _myReady
                        ? AppTheme.softGrey
                        : AppTheme.electricBlue,
                borderRadius: BorderRadius.circular(14),
                border: _myReady
                    ? Border.all(color: AppTheme.electricBlue, width: 2)
                    : null,
              ),
              child: Center(
                child: Text(
                  room?.guestUid == null
                      ? 'Waiting for player...'
                      : _myReady
                          ? 'Waiting for opponent...'
                          : 'READY TO START',
                  style: AppTheme.buttonLabel.copyWith(
                    color: _myReady ? AppTheme.electricBlue : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Leave button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: GestureDetector(
            onTap: _confirmLeave,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.deepGrey),
              ),
              child: Center(
                child: Text(
                  'LEAVE ROOM',
                  style: AppTheme.buttonLabel
                      .copyWith(color: AppTheme.steel, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppTheme.cloudWhite.withAlpha(240),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GET READY',
              style: AppTheme.sectionHeader.copyWith(
                  color: AppTheme.steel, letterSpacing: 4),
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                '$_countdownValue',
                key: ValueKey(_countdownValue),
                style: AppTheme.timerText.copyWith(
                    fontSize: 96, color: AppTheme.electricBlue),
              ),
            ),
            const SizedBox(height: 24),
            Text('Game starting...', style: AppTheme.bodyMuted),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _PlayerSlot extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final int level;
  final bool isReady;
  final bool isCurrentUser;
  final bool pulse;

  const _PlayerSlot({
    required this.name,
    required this.avatarUrl,
    required this.level,
    required this.isReady,
    required this.isCurrentUser,
    required this.pulse,
  });

  static Widget _buildAvatar(String avatar, String name, double radius) {
    if (avatar.startsWith('avatar_')) {
      return UserAvatar(avatarId: avatar, radius: radius, initial: name.isNotEmpty ? name[0] : '?');
    }
    if (avatar.startsWith('http')) {
      return UserAvatar(avatarId: 'google', googlePhotoUrl: avatar, radius: radius, initial: name.isNotEmpty ? name[0] : '?');
    }
    return UserAvatar(
      radius: radius,
      initial: name.isNotEmpty ? name[0] : '?',
      backgroundColor: AppTheme.electricBlue.withAlpha(180),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.electricBlue.withAlpha(12)
            : AppTheme.softGrey,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser ? AppTheme.electricBlue : AppTheme.deepGrey,
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAvatar(avatarUrl, name, 24),
          const SizedBox(height: 8),
          Text(
            name.split(' ').first,
            style: AppTheme.rowLabel,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.softGrey,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.deepGrey),
            ),
            child: Text('Lv.$level',
                style: AppTheme.caption.copyWith(color: AppTheme.steel)),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isReady
                  ? AppTheme.electricBlue.withAlpha(20)
                  : AppTheme.deepGrey.withAlpha(80),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isReady ? '✓ Ready' : 'Not ready',
              style: AppTheme.caption.copyWith(
                color: isReady ? AppTheme.electricBlue : AppTheme.steel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingSlot extends StatelessWidget {
  final AnimationController pulseCtrl;

  const _WaitingSlot({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.softGrey
              .withAlpha((20 + (pulseCtrl.value * 20)).toInt()),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.deepGrey
                .withAlpha((100 + (pulseCtrl.value * 80).toInt())),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  AppTheme.deepGrey.withAlpha(100 + (pulseCtrl.value * 60).toInt()),
              child: Icon(Icons.person_add_outlined,
                  color: AppTheme.steel
                      .withAlpha((120 + (pulseCtrl.value * 80).toInt())),
                  size: 24),
            ),
            const SizedBox(height: 8),
            Text('Waiting...',
                style: AppTheme.rowLabel.copyWith(color: AppTheme.steel)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.deepGrey.withAlpha(80),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('—',
                  style:
                      AppTheme.caption.copyWith(color: AppTheme.steel)),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.deepGrey.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Empty',
                  style: AppTheme.caption.copyWith(color: AppTheme.steel)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionStatCol extends StatelessWidget {
  final String name;
  final int gamesWon;
  final int totalScore;
  final bool isCurrentUser;

  const _SessionStatCol({
    required this.name,
    required this.gamesWon,
    required this.totalScore,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: AppTheme.caption.copyWith(
            color: isCurrentUser ? AppTheme.electricBlue : AppTheme.steel,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_rounded,
                color: Color(0xFFF59E0B), size: 14),
            const SizedBox(width: 3),
            Text(
              '$gamesWon W',
              style: AppTheme.statValue.copyWith(
                color: isCurrentUser ? AppTheme.electricBlue : AppTheme.ink,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$totalScore pts',
          style: AppTheme.caption.copyWith(color: AppTheme.steel),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.electricBlue.withAlpha(15)
              : AppTheme.softGrey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.electricBlue : AppTheme.deepGrey,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.rowLabel.copyWith(
                  color: selected ? AppTheme.electricBlue : AppTheme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

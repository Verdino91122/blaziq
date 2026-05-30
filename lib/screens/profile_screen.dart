import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;

  Future<void> _handleSignIn() async {
    setState(() => _loading = true);
    final cred = await AuthService.signInWithGoogle();
    if (!mounted) return;
    if (cred == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.cardSurface,
          content: Text('Sign-in cancelled or failed.', style: AppTheme.snackText),
        ),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleSignOut() async {
    await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTheme.voidBlack, AppTheme.arenaBlack, AppTheme.headerBar],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: user == null || user.isAnonymous
                  ? _AnonView(user: user, loading: _loading, onSignIn: _handleSignIn)
                  : _SignedInView(user: user, onSignOut: _handleSignOut),
            ),
          ),
        );
      },
    );
  }
}

// ── Anonymous / guest view ────────────────────────────────────────────────────

class _AnonView extends StatelessWidget {
  final User? user;
  final bool loading;
  final VoidCallback onSignIn;

  const _AnonView({
    required this.user,
    required this.loading,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Save progress banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.blazeGold.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.blazeGold.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    color: AppTheme.blazeGold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAVE YOUR PROGRESS!',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.blazeGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign in to unlock leaderboards & challenge friends.',
                        style: AppTheme.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Guest avatar
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppTheme.mutedText.withAlpha(80), width: 2),
            ),
            child: const CircleAvatar(
              radius: 45,
              backgroundColor: AppTheme.cardSurface,
              child: Icon(Icons.person, color: AppTheme.mutedText, size: 44),
            ),
          ),

          const SizedBox(height: 16),

          // Username + stats from Firestore (if signed in anonymously)
          if (user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: UserService.userStream(user!.uid),
              builder: (context, snap) {
                final data = snap.data?.data();
                final username = (data?['username'] as String?) ?? 'Guest';
                return Column(
                  children: [
                    Text(username,
                        style: AppTheme.subheading,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text('Guest account', style: AppTheme.bodyMuted),
                    const SizedBox(height: 24),
                    _StatsGrid(data: data),
                  ],
                );
              },
            )
          else ...[
            Text('Guest', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.sparkPink.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.sparkPink.withAlpha(80)),
              ),
              child: Text(
                'Anonymous sign-in failed.\nGo to Firebase Console → Authentication → Sign-in method → Anonymous → Enable it.',
                style: AppTheme.caption.copyWith(
                    color: AppTheme.sparkPink, fontSize: 11, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Google sign-in button
          _SignInButton(
            onTap: loading ? null : onSignIn,
            backgroundColor: Colors.white,
            iconWidget: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.googleButtonText),
                  )
                : const _GoogleIcon(),
            label: loading ? 'Signing in…' : 'Sign in with Google',
            textColor: AppTheme.googleButtonText,
          ),

          const SizedBox(height: 16),

          // Linking reward note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blazeGold.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.blazeGold.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: AppTheme.blazeGold, size: 20),
                const SizedBox(width: 8),
                Text('Reward: +200 coins for linking!',
                    style: AppTheme.rewardText),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Signed-in (Google) view ───────────────────────────────────────────────────

class _SignedInView extends StatelessWidget {
  final User user;
  final VoidCallback onSignOut;

  const _SignedInView({required this.user, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: UserService.userStream(user.uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _Avatar(user: user),
              const SizedBox(height: 16),
              Text(
                (data?['username'] as String?) ?? user.displayName ?? 'Player',
                style: AppTheme.subheading,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(user.email ?? '', style: AppTheme.bodyMuted),
              const SizedBox(height: 32),
              _StatsGrid(data: data),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: onSignOut,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.sparkPink.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.sparkPink.withAlpha(80)),
                  ),
                  child: Text(
                    'SIGN OUT',
                    textAlign: TextAlign.center,
                    style:
                        AppTheme.buttonLabel.copyWith(color: AppTheme.sparkPink),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final User user;
  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoURL;
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.blazeGold, width: 2),
      ),
      child: CircleAvatar(
        radius: 45,
        backgroundColor: AppTheme.cardSurface,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? const Icon(Icons.person, color: AppTheme.mutedText, size: 44)
            : null,
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final games = data?['gamesPlayed'] as int? ?? 0;
    final best = data?['bestScore'] as int? ?? 0;
    final coins = data?['coins'] as int? ?? 0;
    final xp = data?['xp'] as int? ?? 0;
    final level = data?['level'] as int? ?? 1;

    final stats = [
      _StatEntry(
          icon: Icons.sports_esports_rounded, label: 'GAMES', value: '$games'),
      _StatEntry(
          icon: Icons.star_rounded, label: 'BEST SCORE', value: '$best'),
      _StatEntry(icon: Icons.toll_rounded, label: 'COINS', value: '$coins'),
      _StatEntry(
          icon: Icons.flash_on_rounded, label: 'LEVEL $level', value: '${xp}xp'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: stats.map((s) => _StatCard(entry: s)).toList(),
    );
  }
}

class _StatEntry {
  final IconData icon;
  final String label;
  final String value;
  const _StatEntry(
      {required this.icon, required this.label, required this.value});
}

class _StatCard extends StatelessWidget {
  final _StatEntry entry;
  const _StatCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Row(
        children: [
          Icon(entry.icon, color: AppTheme.blazeGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(entry.value,
                    style: AppTheme.statValue.copyWith(fontSize: 17),
                    overflow: TextOverflow.ellipsis),
                Text(entry.label,
                    style: AppTheme.caption.copyWith(letterSpacing: 0.8),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Widget iconWidget;
  final String label;
  final Color textColor;

  const _SignInButton({
    required this.onTap,
    required this.backgroundColor,
    required this.iconWidget,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color:
              onTap == null ? backgroundColor.withAlpha(180) : backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(label, style: AppTheme.signInLabel(textColor)),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    const strokeW = 3.5;
    const pi = 3.14159265;

    const colors = [
      AppTheme.googleBlue,
      AppTheme.googleGreen,
      AppTheme.googleYellow,
      AppTheme.googleRed,
    ];

    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        -pi / 4 + i * pi / 2,
        pi / 2,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - strokeW / 2, r - strokeW / 2, strokeW),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_GoogleIconPainter old) => false;
}


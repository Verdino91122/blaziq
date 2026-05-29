import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 48),
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppTheme.blazeGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology_rounded, color: AppTheme.voidBlack, size: 48),
                ),
                const SizedBox(height: 32),
                Text('SAVE YOUR PROGRESS!', textAlign: TextAlign.center, style: AppTheme.subheading),
                const SizedBox(height: 12),
                Text(
                  'Sign in to save your game, unlock the\nglobal leaderboards and challenge\nyour friends.',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyMuted,
                ),
                const SizedBox(height: 40),
                _SignInButton(
                  onTap: () {},
                  backgroundColor: Colors.white,
                  iconWidget: const _GoogleIcon(),
                  label: 'Sign in with Google',
                  textColor: AppTheme.googleButtonText,
                ),
                const SizedBox(height: 28),
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
                      const Icon(Icons.star_rounded, color: AppTheme.blazeGold, size: 20),
                      const SizedBox(width: 8),
                      Text('Reward: +200 coins for linking!', style: AppTheme.rewardText),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TextLink(label: 'Link manually (Email)', onTap: () {}),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('|', style: AppTheme.caption.copyWith(fontSize: 14)),
                    ),
                    _TextLink(label: 'Terms of Service', onTap: () {}),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onTap;
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
          color: backgroundColor,
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

class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: AppTheme.footerLink),
    );
  }
}

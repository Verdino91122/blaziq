import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'main_shell.dart';
import 'name_picker_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _loading = false;

  Future<void> _continueWithGoogle() async {
    setState(() => _loading = true);
    final cred = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);

    if (cred == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in cancelled or failed.', style: AppTheme.snackText),
          backgroundColor: AppTheme.softGrey,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Returning Google users who already picked a name skip the picker.
    final data = await UserService.getUserData(user.uid);
    if (!mounted) return;
    final hasDisplayName = (data?['displayName'] as String? ?? '').isNotEmpty;

    if (hasDisplayName) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NamePickerScreen(prefill: user.displayName),
        ),
      );
    }
  }

  void _continueAsGuest() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NamePickerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.cloudWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),

                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/inapp_logo.png',
                    width: 96,
                    height: 96,
                  ),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  'WELCOME TO BLAZIQ',
                  style: AppTheme.screenTitle.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Tagline
                Text(
                  'TRIVIA · BATTLE · WIN',
                  style: AppTheme.sectionHeader.copyWith(
                    color: AppTheme.electricBlue,
                    fontSize: 13,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const Spacer(flex: 2),

                // Continue with Google
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.electricBlue),
                  )
                else
                  _GoogleButton(onTap: _continueWithGoogle),

                const SizedBox(height: 14),

                // Continue as Guest
                if (!_loading)
                  GestureDetector(
                    onTap: _continueAsGuest,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.deepGrey),
                      ),
                      child: Center(
                        child: Text(
                          'Continue as Guest',
                          style: AppTheme.signInLabel(AppTheme.ink),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.deepGrey),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(painter: _GoogleIconPainter()),
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: AppTheme.signInLabel(AppTheme.googleButtonText),
            ),
          ],
        ),
      ),
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

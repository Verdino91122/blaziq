import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version.isNotEmpty ? info.version : '1.0.0');
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = '1.0.0');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      // URL could not be launched on this platform
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Scaffold(
          backgroundColor: AppTheme.cloudWhite,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      MediaQuery.of(context).padding.bottom + 24,
                    ),
                    child: Column(
                      children: [
                        _IdentityBlock(version: _version),
                        const SizedBox(height: 16),
                        const _StoryCard(),
                        const SizedBox(height: 16),
                        const _DifferentCard(),
                        const SizedBox(height: 16),
                        const _BuiltByCard(),
                        const SizedBox(height: 16),
                        _ContactCard(onLaunch: _launch),
                        const SizedBox(height: 24),
                        _LegalFooter(onLaunch: _launch),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('ABOUT', style: AppTheme.appBarTitle),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.softGrey,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.steel,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card shell ─────────────────────────────────────────────────────────

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Card header (emoji + title) ───────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final String emoji;
  final String title;

  const _CardHeader({required this.emoji, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.firaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Top identity block ────────────────────────────────────────────────────────

class _IdentityBlock extends StatelessWidget {
  final String version;
  const _IdentityBlock({required this.version});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Image.asset(
          'assets/images/inapp_logo.png',
          width: 80,
          height: 80,
        ),
        const SizedBox(height: 12),
        Text(
          'BLAZIQ',
          style: GoogleFonts.firaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
            letterSpacing: 3.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'THINK FAST. WIN MORE.',
          style: GoogleFonts.firaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.electricBlue,
            letterSpacing: 1.2,
          ),
        ),
        if (version.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Version $version',
            style: GoogleFonts.firaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppTheme.steel,
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Card 1 — The Story ────────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  const _StoryCard();

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        children: [
          const _CardHeader(emoji: '📖', title: 'The Story'),
          const SizedBox(height: 14),
          Text(
            'Blaziq started as a simple classroom trivia game — flash cards, a buzzer, and a lot of competitive energy. What began as a fun way to test knowledge between friends quickly became something everyone wanted to keep playing.',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.steel,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'That energy is what Blaziq is built on: fast thinking, friendly competition, and the rush of beating the clock.',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.steel,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Card 2 — What Makes Blaziq Different ─────────────────────────────────────

class _DifferentCard extends StatelessWidget {
  const _DifferentCard();

  @override
  Widget build(BuildContext context) {
    return const _CardContainer(
      child: Column(
        children: [
          _CardHeader(emoji: '⚡', title: 'What Makes Blaziq Different'),
          SizedBox(height: 14),
          _DiffBullet(
            'Endless survival-style Solo mode — no fixed question count, just you against the clock',
          ),
          SizedBox(height: 8),
          _DiffBullet(
            'Real buzzer mechanics in Friend Mode — inspired by classic game shows',
          ),
          SizedBox(height: 8),
          _DiffBullet(
            'A global leaderboard where every game counts',
          ),
        ],
      ),
    );
  }
}

class _DiffBullet extends StatelessWidget {
  final String text;
  const _DiffBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 10),
          decoration: const BoxDecoration(
            color: AppTheme.electricBlue,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.steel,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Card 3 — Built By ─────────────────────────────────────────────────────────

class _BuiltByCard extends StatelessWidget {
  const _BuiltByCard();

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        children: [
          const _CardHeader(emoji: '👨‍💻', title: 'Built By'),
          const SizedBox(height: 14),
          Text(
            'Blaziq is built and maintained by Allaa Eddine Ikhlef, an independent developer who loves trivia, fast-paced games, and clean design. New features and modes are added regularly based on player feedback.',
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.steel,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Card 4 — Get In Touch ─────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final Future<void> Function(String) onLaunch;
  const _ContactCard({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return _CardContainer(
      child: Column(
        children: [
          const _CardHeader(emoji: '💬', title: 'Get In Touch'),
          const SizedBox(height: 14),
          Text(
            "Have feedback or found a bug? We'd love to hear from you!",
            style: GoogleFonts.firaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppTheme.steel,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => onLaunch(
              'mailto:blaziqsupport@gmail.com?subject=Blaziq%20Feedback',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.softGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mail_outline_rounded,
                    color: AppTheme.electricBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'blaziqsupport@gmail.com',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.electricBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legal footer ──────────────────────────────────────────────────────────────

class _LegalFooter extends StatelessWidget {
  final Future<void> Function(String) onLaunch;
  const _LegalFooter({required this.onLaunch});

  static const _privacyUrl =
      'https://doc-hosting.flycricket.io/blaziq-privacy-policy/11284ce3-7a2f-4a89-9d8b-33129af162b5/privacy';
  static const _termsUrl =
      'https://doc-hosting.flycricket.io/blaziq-terms-of-use/7bd62b5d-fd5d-412d-992c-5b4105c59595/terms';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => onLaunch(_privacyUrl),
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricBlue,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.electricBlue,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '·',
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  color: AppTheme.steel,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => onLaunch(_termsUrl),
              child: Text(
                'Terms of Use',
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.electricBlue,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.electricBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '© 2026 Blaziq. All rights reserved.',
          textAlign: TextAlign.center,
          style: GoogleFonts.firaSans(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppTheme.steel,
          ),
        ),
      ],
    );
  }
}

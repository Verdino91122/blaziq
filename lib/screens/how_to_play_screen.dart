import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                    child: const Column(
                      children: [
                        _SoloSection(),
                        SizedBox(height: 16),
                        _FriendSection(),
                        SizedBox(height: 16),
                        _ScoringSection(),
                        SizedBox(height: 16),
                        _TipsSection(),
                        SizedBox(height: 24),
                        _ClosingLine(),
                        SizedBox(height: 24),
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
          Text('HOW TO PLAY', style: AppTheme.appBarTitle),
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

// ── Shared section header (emoji + title + subtitle) ─────────────────────────

class _CardHeader extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const _CardHeader({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

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
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.firaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.electricBlue,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Bullet row (emoji + bold keyword + muted description) ────────────────────

class _BulletRow extends StatelessWidget {
  final String emoji;
  final String bold;
  final String rest;

  const _BulletRow({
    required this.emoji,
    required this.bold,
    required this.rest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(emoji, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$bold ',
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  TextSpan(
                    text: rest,
                    style: GoogleFonts.firaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.steel,
                      height: 1.4,
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

// ── Goal line at the bottom of a section ─────────────────────────────────────

class _GoalLine extends StatelessWidget {
  final String text;
  const _GoalLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: GoogleFonts.firaSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.electricBlue,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Section 1 — Solo Mode ─────────────────────────────────────────────────────

class _SoloSection extends StatelessWidget {
  const _SoloSection();

  @override
  Widget build(BuildContext context) {
    return const _CardContainer(
      child: Column(
        children: [
          _CardHeader(
            emoji: '⚡',
            title: 'Race Against the Clock',
            subtitle: 'Solo Mode',
          ),
          SizedBox(height: 16),
          _BulletRow(
            emoji: '⏱️',
            bold: 'Start with',
            rest: '30 seconds on the clock',
          ),
          _BulletRow(
            emoji: '✅',
            bold: 'Correct answer',
            rest: '→ +4 seconds (and your streak grows!)',
          ),
          _BulletRow(
            emoji: '❌',
            bold: 'Wrong answer',
            rest: '→ -3 seconds (streak resets)',
          ),
          _BulletRow(
            emoji: '🔥',
            bold: 'Streak of 3',
            rest: '→ +6s · Streak of 4 → +8s · Streak of 5+ → +10s',
          ),
          _BulletRow(
            emoji: '📈',
            bold: 'Questions get harder',
            rest: 'as you go — Easy → Medium → Hard',
          ),
          _BulletRow(
            emoji: '💀',
            bold: 'Game ends',
            rest: 'when the timer hits zero',
          ),
          SizedBox(height: 4),
          _GoalLine('Survive as long as you can and rack up the highest score!'),
        ],
      ),
    );
  }
}

// ── Section 2 — Friend Mode ───────────────────────────────────────────────────

class _FriendSection extends StatelessWidget {
  const _FriendSection();

  @override
  Widget build(BuildContext context) {
    return const _CardContainer(
      child: Column(
        children: [
          _CardHeader(
            emoji: '🎮',
            title: 'Buzz First, Win Big',
            subtitle: 'Friend Mode',
          ),
          SizedBox(height: 16),
          _BulletRow(
            emoji: '🏠',
            bold: 'One player hosts',
            rest: 'a room and shares a code',
          ),
          _BulletRow(
            emoji: '🔑',
            bold: 'The other player',
            rest: 'joins using that code',
          ),
          _BulletRow(
            emoji: '📚',
            bold: 'Host picks a category',
            rest: '— Science, Geography, History, or General Knowledge',
          ),
          _BulletRow(
            emoji: '⏰',
            bold: 'Each match lasts',
            rest: '3 minutes',
          ),
          _BulletRow(
            emoji: '🔴',
            bold: 'Whoever buzzes first',
            rest: 'gets to answer',
          ),
          _BulletRow(
            emoji: '✅',
            bold: 'Correct answer',
            rest: '→ +3 points',
          ),
          _BulletRow(
            emoji: '❌',
            bold: 'Wrong/timeout',
            rest: '→ -1 point, question passes to your opponent!',
          ),
          _BulletRow(
            emoji: '🎯',
            bold: 'Opponent answers correctly',
            rest: '→ they get +2 points',
          ),
          _BulletRow(
            emoji: '⚖️',
            bold: 'Tied at the end?',
            rest: 'Sudden Death! First correct answer wins',
          ),
          SizedBox(height: 4),
          _GoalLine('Outscore your opponent before time runs out!'),
        ],
      ),
    );
  }
}

// ── Section 3 — Scoring, XP & Coins ─────────────────────────────────────────

class _ScoringSection extends StatelessWidget {
  const _ScoringSection();

  @override
  Widget build(BuildContext context) {
    return const _CardContainer(
      child: Column(
        children: [
          _CardHeader(
            emoji: '🏆',
            title: 'Level Up As You Play',
            subtitle: 'Scoring, XP & Coins',
          ),
          SizedBox(height: 16),
          _SubBlock(
            emoji: '⭐',
            heading: 'Score',
            body:
                'Your best Solo score is saved to the leaderboard. Beat your personal best to climb the ranks!',
          ),
          SizedBox(height: 12),
          _SubBlock(
            emoji: '⚡',
            heading: 'XP & Levels',
            body:
                'Earn XP from correct answers and streaks. Level titles: Rookie (1-4), Challenger (5-9), Expert (10-19), Master (20-49), Legend (50+)',
          ),
          SizedBox(height: 12),
          _SubBlock(
            emoji: '🪙',
            heading: 'Coins',
            body:
                'Earn coins after every game — play your first game of the day for a bonus! Coins unlock power-ups and store items soon.',
          ),
        ],
      ),
    );
  }
}

class _SubBlock extends StatelessWidget {
  final String emoji;
  final String heading;
  final String body;

  const _SubBlock({
    required this.emoji,
    required this.heading,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.softGrey,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: GoogleFonts.firaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: GoogleFonts.firaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.steel,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section 4 — Quick Tips ────────────────────────────────────────────────────

class _TipsSection extends StatelessWidget {
  const _TipsSection();

  @override
  Widget build(BuildContext context) {
    return const _CardContainer(
      child: Column(
        children: [
          _CardHeader(
            emoji: '💡',
            title: 'Quick Tips',
            subtitle: 'Pro strategies to win',
          ),
          SizedBox(height: 16),
          _BulletRow(
            emoji: '🎯',
            bold: 'In Solo Mode,',
            rest: "don't rush — a wrong answer costs more time than a slow correct one",
          ),
          _BulletRow(
            emoji: '🔥',
            bold: 'Keep your streak alive',
            rest: 'in Solo Mode for huge time bonuses',
          ),
          _BulletRow(
            emoji: '⚡',
            bold: 'In Friend Mode,',
            rest: "buzz only when you're confident — losing the buzzer costs you a point",
          ),
          _BulletRow(
            emoji: '🌍',
            bold: 'Sign in with Google',
            rest: 'to save your progress and appear on the worldwide leaderboard',
          ),
        ],
      ),
    );
  }
}

// ── Closing line ──────────────────────────────────────────────────────────────

class _ClosingLine extends StatelessWidget {
  const _ClosingLine();

  @override
  Widget build(BuildContext context) {
    return Text(
      '"Now go show everyone how fast you really are. ⚡"',
      textAlign: TextAlign.center,
      style: GoogleFonts.firaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.electricBlue,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

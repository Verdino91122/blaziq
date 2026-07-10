import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/question_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/hot_badge.dart';
import '../widgets/user_avatar.dart';
import 'friend_mode_screen.dart';
import 'solo_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;
  bool _cheatMode = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onModeTap(int index) {
    if (index == 0) {
      _showSoloCategoryPicker();
    } else if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FriendModeScreen()),
      );
    }
    // Online card (index 2) not yet available — ribbon makes it clear
  }

  void _showSoloCategoryPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _SoloCategorySheet(
        onSelected: (category) {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SoloGameScreen(
                categoryId: category.id,
                cheatMode: _cheatMode,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 52% of the SafeArea-adjusted available height goes to the card
              // carousel. Percentage-based so it adapts to any screen size without
              // relying on a brittle fixed-content estimate.
              final cardHeight = (constraints.maxHeight * 0.48).clamp(
                220.0,
                460.0,
              );
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  children: [
                    const _HeaderBar(),
                    const SizedBox(height: 28),
                    _BrainLogoSection(
                      cheatMode: _cheatMode,
                      onCheatToggle: () =>
                          setState(() => _cheatMode = !_cheatMode),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: cardHeight,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: 3,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemBuilder: (context, index) => _ModeCard(
                          index: index,
                          onTap: () => _onModeTap(index),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DotIndicator(count: 3, current: _currentPage),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) {
          return _buildBar(
            context,
            coins: 0,
            xp: 0,
            level: 1,
            avatarId: null,
            googlePhotoUrl: null,
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: UserService.userStream(user.uid),
          builder: (context, snap) {
            final data = snap.data?.data();
            return _buildBar(
              context,
              coins: (data?['coins'] as int?) ?? 0,
              xp: (data?['xp'] as int?) ?? 0,
              level: (data?['level'] as int?) ?? 1,
              avatarId: data?['avatarId'] as String?,
              googlePhotoUrl: user.photoURL,
            );
          },
        );
      },
    );
  }

  Widget _buildBar(
    BuildContext context, {
    required int coins,
    required int xp,
    required int level,
    required String? avatarId,
    required String? googlePhotoUrl,
  }) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 10),
      color: AppTheme.headerBar,
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.blazeGold, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: UserAvatar(
                avatarId: avatarId,
                googlePhotoUrl: googlePhotoUrl,
                radius: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Coins
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppTheme.blazeGold,
                size: 16,
              ),
              const SizedBox(width: 3),
              Text('$coins', style: AppTheme.statValue),
            ],
          ),
          const Spacer(),
          // XP progress bar
          _XpBar(xp: xp, level: level),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  final int xp;
  final int level;

  const _XpBar({required this.xp, required this.level});

  @override
  Widget build(BuildContext context) {
    final currThreshold = UserService.xpThreshold(level);
    final nextThreshold = UserService.xpThreshold(level + 1);
    final rangeSize = nextThreshold - currThreshold;
    final xpInLevel = xp - currThreshold;
    final progress = rangeSize > 0
        ? (xpInLevel / rangeSize).clamp(0.0, 1.0)
        : 1.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.flash_on_rounded, color: AppTheme.blazeGold, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Lv.$level · ${UserService.titleForLevel(level)}',
              style: AppTheme.caption,
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 72,
              height: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.cardSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.blazeGold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '$xpInLevel / $rangeSize xp',
              style: AppTheme.caption.copyWith(fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrainLogoSection extends StatefulWidget {
  final bool cheatMode;
  final VoidCallback onCheatToggle;

  const _BrainLogoSection({
    required this.cheatMode,
    required this.onCheatToggle,
  });

  @override
  State<_BrainLogoSection> createState() => _BrainLogoSectionState();
}

class _BrainLogoSectionState extends State<_BrainLogoSection> {
  int _tapCount = 0;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _onLogoTap() {
    _tapCount++;
    _resetTimer?.cancel();
    if (_tapCount >= 7) {
      _tapCount = 0;
      widget.onCheatToggle();
      return;
    }
    // Reset counter if no tap within 3 seconds
    _resetTimer = Timer(const Duration(seconds: 3), () {
      _tapCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _onLogoTap,
          child: Image.asset(
            'assets/images/inapp_logo.png',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 14),
        Text('SELECT A MODE', style: AppTheme.selectModeLabel),
        if (widget.cheatMode)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'DEV MODE',
              style: AppTheme.sectionHeader.copyWith(color: AppTheme.sparkPink),
            ),
          ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final int index;
  final VoidCallback onTap;

  const _ModeCard({required this.index, required this.onTap});

  static const _cards = [
    _CardData(
      icon: Icons.person_rounded,
      title: 'SOLO',
      description: 'Play a solo game against the clock',
      gradientColors: [AppTheme.modeCardStart, AppTheme.modeCardEnd],
      accentColor: AppTheme.blazeGold,
    ),
    _CardData(
      icon: Icons.people_rounded,
      title: 'WITH A FRIEND',
      description: 'Create or join a private room',
      gradientColors: [AppTheme.modeCardStart, AppTheme.modeCardEnd],
      accentColor: AppTheme.whiteText,
    ),
    _CardData(
      icon: Icons.public_rounded,
      title: 'ONLINE',
      description: 'Random matchmaking vs a live opponent',
      gradientColors: [AppTheme.modeCardStart, AppTheme.modeCardEnd],
      accentColor: AppTheme.whiteText,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final card = _cards[index];
    final hasPlayButton = index == 0 || index == 1;
    final isComingSoon = index == 2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: card.gradientColors,
          ),
          border: Border.all(color: card.accentColor.withAlpha(60), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Grid texture
              Positioned.fill(child: CustomPaint(painter: _GridPainter())),
              // Card content
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: card.accentColor.withAlpha(30),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: card.accentColor.withAlpha(100),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          card.icon,
                          color: card.accentColor,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        card.title,
                        style: AppTheme.modeTitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.description,
                        textAlign: TextAlign.center,
                        style: AppTheme.bodyMuted.copyWith(
                          letterSpacing: 0.5,
                          height: 1.4,
                        ),
                      ),
                      if (hasPlayButton) ...[
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: card.accentColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('PLAY', style: AppTheme.buttonLabel),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Diagonal "COMING SOON" ribbon — Online mode only
              if (isComingSoon)
                Positioned(
                  top: 16,
                  right: -52,
                  child: Transform.rotate(
                    angle: 0.7854,
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: AppTheme.sparkPink,
                      child: Text(
                        'COMING SOON',
                        textAlign: TextAlign.center,
                        style: AppTheme.ribbonLabel.copyWith(fontSize: 12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final Color accentColor;

  const _CardData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
    required this.accentColor,
  });
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.deepGrey.withAlpha(120)
      ..strokeWidth = 0.5;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

// ── Solo category picker sheet ────────────────────────────────────────────────

class _SoloCategorySheet extends StatefulWidget {
  final ValueChanged<QuizCategory> onSelected;

  const _SoloCategorySheet({required this.onSelected});

  @override
  State<_SoloCategorySheet> createState() => _SoloCategorySheetState();
}

class _SoloCategorySheetState extends State<_SoloCategorySheet> {
  late Future<List<QuizCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = QuestionService.getCategories();
  }

  void _retry() {
    setState(() => _categoriesFuture = QuestionService.getCategories());
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.65;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        // Right padding lives partly inside the GridView so corner badges
        // (top: -14 / right: -8) aren't clipped by the scroll viewport.
        padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SELECT CATEGORY',
              textAlign: TextAlign.center,
              style: AppTheme.appBarTitle,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: FutureBuilder<List<QuizCategory>>(
                future: _categoriesFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.electricBlue,
                          strokeWidth: 3,
                        ),
                      ),
                    );
                  }
                  if (snap.hasError || (snap.data?.isEmpty ?? true)) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: AppTheme.steel,
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load categories',
                            style: AppTheme.bodyMuted,
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: _retry,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.electricBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'TRY AGAIN',
                                style: AppTheme.buttonLabel,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final categories = snap.data!;
                  return GridView.count(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(
                      top: 14,
                      right: 8,
                      bottom: 4,
                    ),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      for (final category in categories)
                        _SoloCategoryCard(
                          category: category,
                          onTap: () => widget.onSelected(category),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoloCategoryCard extends StatelessWidget {
  final QuizCategory category;
  final VoidCallback onTap;

  const _SoloCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.softGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.deepGrey),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.rowLabel.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (category.isHot)
              const Positioned(top: -14, right: -8, child: HotBadge()),
          ],
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? AppTheme.blazeGold
                : AppTheme.mutedText.withAlpha(100),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SoloGameScreen(cheatMode: _cheatMode),
        ),
      );
    }
    // Friend and Online cards are not yet available — ribbon makes it clear
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.arenaBlack,
      body: SafeArea(
        child: Column(
          children: [
            const _HeaderBar(),
            const SizedBox(height: 28),
            _BrainLogoSection(
              cheatMode: _cheatMode,
              onCheatToggle: () => setState(() => _cheatMode = !_cheatMode),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 3,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) =>
                    _ModeCard(index: index, onTap: () => _onModeTap(index)),
              ),
            ),
            const SizedBox(height: 16),
            _DotIndicator(count: 3, current: _currentPage),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppTheme.headerBar,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.blazeGold, width: 1.5),
            ),
            child: const Icon(
              Icons.person,
              color: AppTheme.mutedText,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const _StatChip(
            icon: Icons.star_rounded,
            iconColor: AppTheme.blazeGold,
            value: '67',
          ),
          const SizedBox(width: 6),
          const _StatChip(
            icon: Icons.extension,
            iconColor: AppTheme.blazeGold,
            value: '6',
          ),
          const SizedBox(width: 6),
          const _StatChip(
            icon: Icons.bolt,
            iconColor: AppTheme.blazeGold,
            value: '4',
          ),
          const SizedBox(width: 6),
          const _StatChip(
            icon: Icons.shield_rounded,
            iconColor: AppTheme.blazeGold,
            value: '6',
          ),
          const Spacer(),
          const _XpBar(current: 150, max: 500),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 2),
        Text(value, style: AppTheme.statValue),
      ],
    );
  }
}

class _XpBar extends StatelessWidget {
  final int current;
  final int max;
  const _XpBar({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.flash_on_rounded, color: AppTheme.blazeGold, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$current/$max', style: AppTheme.caption),
            const SizedBox(height: 2),
            SizedBox(
              width: 56,
              height: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: current / max,
                  backgroundColor: AppTheme.cardSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.blazeGold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrainLogoSection extends StatelessWidget {
  final bool cheatMode;
  final VoidCallback onCheatToggle;

  const _BrainLogoSection({
    required this.cheatMode,
    required this.onCheatToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Outer Column: circle row on top, "SELECT A MODE" text below.
    // Separating the text from the circle row means the mirror spacer
    // is always exactly 88px (8 gap + 80 tap zone), regardless of text width,
    // so the tap zone is always 8px past the circle's right edge.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row: mirror spacer | circle | gap | invisible tap zone
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mirror spacer — matches (gap 8 + tap zone 80) so circle stays centered
            const SizedBox(width: 88),
            // Brain logo circle
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.blazeGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: AppTheme.voidBlack,
                size: 48,
              ),
            ),
            // Gap
            const SizedBox(width: 8),
            // Invisible tap zone + optional DEV badge below it
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCheatToggle,
                  child: const SizedBox(width: 80, height: 80),
                ),
                if (cheatMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'DEV',
                      style: AppTheme.sectionHeader.copyWith(
                        color: AppTheme.sparkPink,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('SELECT A MODE', style: AppTheme.selectModeLabel),
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
      description: 'Play alone vs the clock',
      gradientColors: [AppTheme.modeCardStart, AppTheme.modeCardEnd],
      accentColor: AppTheme.blazeGold,
    ),
    _CardData(
      icon: Icons.people_rounded,
      title: 'WITH FRIEND',
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
    final isSolo = index == 0;
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
              // Card content — Positioned.fill gives the Column full height so
              // mainAxisAlignment.center actually works inside the Stack
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
                      if (isSolo) ...[
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
              // Diagonal "COMING SOON" ribbon — clipped by parent ClipRRect
              if (!isSolo)
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
      ..color = Colors.white.withAlpha(8)
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

import 'dart:async' show unawaited;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rank_screen.dart';
import 'screens/store_screen.dart';
import 'screens/menu_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // Keep the native splash visible until Firebase + auth are ready.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authError = await AuthService.ensureAnonymousSignIn();
  if (authError != null) debugPrint('[Blaziq] Anonymous auth failed: $authError');

  // Silently fix existing Google users whose username was saved as 'Player'.
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      final displayName = user.displayName;
      if (displayName != null && displayName.isNotEmpty) {
        final ref =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final doc = await ref.get();
        if (doc.exists) {
          final current = (doc.data()?['username'] as String?) ?? '';
          if (current.isEmpty || current == 'Player') {
            await ref.update({'username': displayName});
          }
        }
      }
    }
  } catch (_) {}

  // Fire-and-forget: fix country for existing users who got the old 'CA' default.
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) unawaited(UserService.refreshCountryIfStale(uid));

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  ));

  FlutterNativeSplash.remove();
  runApp(const BlaziQApp());
}

class BlaziQApp extends StatelessWidget {
  const BlaziQApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blaziq',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 2;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const ProfileScreen(),
      const RankScreen(),
      const HomeScreen(),
      const StoreScreen(),
      MenuScreen(onNavigateToProfile: () => setState(() => _currentIndex = 0)),
    ];
  }

  static const _navItems = [
    _NavItem(Icons.person_outline, Icons.person),
    _NavItem(Icons.emoji_events_outlined, Icons.emoji_events),
    _NavItem(Icons.home_outlined, Icons.home),
    _NavItem(Icons.storefront_outlined, Icons.storefront),
    _NavItem(Icons.menu, Icons.menu),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: _navItems,
      ),
    );
  }
}

class _NavItem {
  final IconData outlineIcon;
  final IconData filledIcon;
  const _NavItem(this.outlineIcon, this.filledIcon);
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_NavItem> items;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: 80.0 + bottomPad,
      child: CustomPaint(
        painter: const _NavBarPainter(),
        child: Column(
          children: [
            SizedBox(
              height: 80,
              child: Row(
                children: List.generate(items.length, (i) {
                  final selected = currentIndex == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Align(
                        alignment: const Alignment(0, -0.5),
                        child: Icon(
                          selected ? items[i].filledIcon : items[i].outlineIcon,
                          color: Colors.white.withAlpha(selected ? 255 : 178),
                          size: selected ? 28.0 : 26.0,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: bottomPad),
          ],
        ),
      ),
    );
  }
}

// Paints the nav bar background with true transparent V-notch cutouts between
// sections, plus a gradient stroke (white → transparent) on each section's
// top and side edges to create a "raised card" lit-edge effect.
class _NavBarPainter extends CustomPainter {
  static const double _notchDepth = 6.0;
  static const double _notchHalfWidth = 8.0;
  static const double _strokeWidth = 1.5;
  // Background: blue-grey at top fading to transparent at bottom.
  static const Color _bgTop = Color(0xFF7688A0);
  static const Color _bgBottom = Color(0xFF3F4348);
  // Stroke: white at top fading to transparent at bottom.
  static const Color _strokeTop = Color(0xFFFFFFFF);
  static const Color _strokeBottom = Color(0x003F4348);

  const _NavBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double sW = size.width / 5;
    const double nD = _notchDepth;
    const double nHW = _notchHalfWidth;
    final Rect full = Offset.zero & size;

    // ── 1. Background gradient fill with transparent notch holes ───────────
    canvas.saveLayer(full, Paint());

    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [_bgTop, _bgBottom],
        ).createShader(full),
    );

    final clearPaint = Paint()..blendMode = BlendMode.clear;

    // Half-notch at the very left outer edge (top-left corner triangle)
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(nHW, 0)
        ..lineTo(0, nD)
        ..close(),
      clearPaint,
    );

    // Full V-notches at each of the 4 inner section boundaries
    for (int i = 0; i < 4; i++) {
      final double x = (i + 1) * sW;
      canvas.drawPath(
        Path()
          ..moveTo(x - nHW, 0)
          ..lineTo(x, nD)
          ..lineTo(x + nHW, 0)
          ..close(),
        clearPaint,
      );
    }

    // Half-notch at the very right outer edge (top-right corner triangle)
    canvas.drawPath(
      Path()
        ..moveTo(size.width - nHW, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, nD)
        ..close(),
      clearPaint,
    );

    canvas.restore();

    // ── 2. Gradient stroke along each section's top + side edges ───────────
    for (int i = 0; i < 5; i++) {
      final double l = i * sW;

      final path = Path()
        ..moveTo(l, size.height)
        ..lineTo(l, nD)
        ..lineTo(l + nHW, 0)
        ..lineTo(l + sW - nHW, 0)
        ..lineTo(l + sW, nD)
        ..lineTo(l + sW, size.height);

      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [_strokeTop, _strokeBottom],
      ).createShader(Rect.fromLTWH(l, 0, sW, size.height));

      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_NavBarPainter old) => false;
}

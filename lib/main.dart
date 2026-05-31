import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
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

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
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

  static const List<Widget> _screens = [
    ProfileScreen(),
    RankScreen(),
    HomeScreen(),
    StoreScreen(),
    MenuScreen(),
  ];

  static const _navItems = [
    _NavItem(Icons.person_outline, Icons.person, 'Profile'),
    _NavItem(Icons.emoji_events_outlined, Icons.emoji_events, 'Rank'),
    _NavItem(Icons.home_outlined, Icons.home, 'Home'),
    _NavItem(Icons.storefront_outlined, Icons.storefront, 'Shop'),
    _NavItem(Icons.menu, Icons.menu, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
  final String label;
  const _NavItem(this.outlineIcon, this.filledIcon, this.label);
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.voidBlack,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = currentIndex == i;
              final isHome = i == 2;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 64,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isHome)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.blazeGold : AppTheme.cardSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            selected ? item.filledIcon : item.outlineIcon,
                            color: selected ? AppTheme.voidBlack : AppTheme.mutedText,
                            size: 26,
                          ),
                        )
                      else ...[
                        Icon(
                          selected ? item.filledIcon : item.outlineIcon,
                          color: selected ? AppTheme.blazeGold : AppTheme.mutedText,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: AppTheme.navLabel.copyWith(
                            color: selected ? AppTheme.blazeGold : AppTheme.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

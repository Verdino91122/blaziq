import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'rank_screen.dart';
import 'store_screen.dart';
import 'menu_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return AnimatedBackground(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CurvedNavigationBar(
              index: _currentIndex,
              color: Colors.white,
              buttonBackgroundColor: AppTheme.electricBlue,
              backgroundColor: Colors.transparent,
              animationDuration: const Duration(milliseconds: 300),
              animationCurve: Curves.easeInOut,
              height: 60,
              items: [
                Icon(Icons.person, size: 22,
                    color: _currentIndex == 0 ? Colors.white : AppTheme.ink),
                Icon(Icons.emoji_events, size: 22,
                    color: _currentIndex == 1 ? Colors.white : AppTheme.ink),
                Icon(Icons.home, size: 22,
                    color: _currentIndex == 2 ? Colors.white : AppTheme.ink),
                Icon(Icons.storefront, size: 22,
                    color: _currentIndex == 3 ? Colors.white : AppTheme.ink),
                Icon(Icons.settings, size: 22,
                    color: _currentIndex == 4 ? Colors.white : AppTheme.ink),
              ],
              onTap: (index) => setState(() => _currentIndex = index),
            ),
            Container(
              height: bottomPadding,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
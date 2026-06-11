import 'dart:async' show unawaited;
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
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
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authError = await AuthService.ensureAnonymousSignIn();
  if (authError != null) debugPrint('[Blaziq] Anonymous auth failed: $authError');

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    unawaited(UserService.fixPlayerUsername(uid));
    unawaited(UserService.refreshCountryIfStale(uid));
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom,
        ),
        child: CurvedNavigationBar(
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
      ),
    );
  }
}

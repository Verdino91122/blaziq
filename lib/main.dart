import 'dart:async' show unawaited;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/welcome_screen.dart';
import 'screens/name_picker_screen.dart';
import 'screens/avatar_picker_screen.dart';

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

class BlaziQApp extends StatefulWidget {
  const BlaziQApp({super.key});

  @override
  State<BlaziQApp> createState() => _BlaziQAppState();
}

class _BlaziQAppState extends State<BlaziQApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    AuthService.onSignOut = () {
      _navKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    };
  }

  @override
  void dispose() {
    AuthService.onSignOut = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blaziq',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorKey: _navKey,
      home: const _AppRouter(),
    );
  }
}

/// Checks whether the current user has already picked a display name.
/// Routes to WelcomeScreen (anon), NamePickerScreen (Google), or MainShell.
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  late final Future<Widget> _routeFuture;

  @override
  void initState() {
    super.initState();
    _routeFuture = _resolveRoute();
  }

  Future<Widget> _resolveRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const MainShell();

    final data = await UserService.getUserData(user.uid);
    final hasDisplayName = (data?['displayName'] as String? ?? '').isNotEmpty;

    if (!hasDisplayName) {
      if (user.isAnonymous) return const WelcomeScreen();
      return NamePickerScreen(prefill: user.displayName, isOnboarding: true);
    }

    // Google users who completed name picker but haven't chosen an avatar yet
    // are sent to the avatar picker as the final onboarding step.
    if (!user.isAnonymous && (data?['avatarId'] as String? ?? '').isEmpty) {
      return AvatarPickerScreen(
        uid: user.uid,
        googlePhotoUrl: user.photoURL,
      );
    }

    return const MainShell();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _routeFuture,
      builder: (context, snap) {
        if (snap.hasData) return snap.data!;
        return const Scaffold(
          backgroundColor: AppTheme.cloudWhite,
          body: Center(
            child: CircularProgressIndicator(color: AppTheme.electricBlue),
          ),
        );
      },
    );
  }
}

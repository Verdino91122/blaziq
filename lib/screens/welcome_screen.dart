import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';
import '../services/display_name_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
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
          content: Text(
            'Sign-in cancelled or failed.',
            style: AppTheme.snackText,
          ),
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _GuestPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
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
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'WELCOME TO BLAZIQ',
                    style: AppTheme.screenTitle.copyWith(fontSize: 22),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

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
                        color: AppTheme.electricBlue,
                      ),
                    )
                  else
                    _WelcomeButton(
                      onTap: _continueWithGoogle,
                      iconPath: 'assets/icons/google.svg',
                      label: 'Continue with Google',
                      subtitle:
                          'Save your progress and appear on the global leaderboard',
                      borderColor: AppTheme.electricBlue,
                    ),

                  const SizedBox(height: 14),

                  // Continue as Guest
                  if (!_loading)
                    _WelcomeButton(
                      onTap: _continueAsGuest,
                      iconPath: 'assets/icons/guest.svg',
                      label: 'Continue as Guest',
                      subtitle: 'Progress will be lost if you sign out',
                      borderColor: AppTheme.deepGrey,
                    ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared button widget ──────────────────────────────────────────────────────

class _WelcomeButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String iconPath;
  final String label;
  final String subtitle;
  final Color borderColor;

  const _WelcomeButton({
    required this.onTap,
    required this.iconPath,
    required this.label,
    required this.subtitle,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            SvgPicture.asset(iconPath, width: 28, height: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTheme.rowLabel.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.steel,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guest name picker bottom sheet ────────────────────────────────────────────

class _GuestPickerSheet extends StatefulWidget {
  const _GuestPickerSheet();

  @override
  State<_GuestPickerSheet> createState() => _GuestPickerSheetState();
}

class _GuestPickerSheetState extends State<_GuestPickerSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;

  String? _validationError;
  bool _checking = false;
  bool? _isAvailable;
  List<String> _suggestions = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  void _onChanged() {
    final text = _ctrl.text;
    final err = DisplayNameService.validateDisplayName(text);
    setState(() {
      _validationError = err;
      _isAvailable = null;
      _checking = false;
      _suggestions = [];
    });
    if (err != null) {
      _debounce?.cancel();
      return;
    }
    _debounce?.cancel();
    setState(() => _checking = true);
    _debounce = Timer(
      const Duration(milliseconds: 600),
      () => _triggerCheck(text),
    );
  }

  Future<void> _triggerCheck(String name) async {
    if (!mounted) return;
    final uid = AuthService.currentUser?.uid ?? '';
    final available = await DisplayNameService.isAvailable(uid, name);
    if (!mounted || _ctrl.text != name) return;
    setState(() {
      _isAvailable = available;
      _checking = false;
      _suggestions = available
          ? []
          : DisplayNameService.generateSuggestions(name);
    });
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (DisplayNameService.validateDisplayName(name) != null) return;
    if (_isAvailable != true) return;
    setState(() => _submitting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _submitting = false);
      return;
    }

    await UserService.ensureUserDoc(user);
    final result = await DisplayNameService.claimName(user.uid, name);
    if (!mounted) return;

    if (result == ClaimResult.success) {
      try {
        await UserService.syncLeaderboardDisplayName(user.uid, name);
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else if (result == ClaimResult.taken) {
      setState(() {
        _isAvailable = false;
        _suggestions = DisplayNameService.generateSuggestions(name);
        _submitting = false;
      });
    } else {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  void _fillSuggestion(String name) {
    _ctrl.text = name;
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: name.length),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _validationError == null &&
      _isAvailable == true &&
      _ctrl.text.isNotEmpty &&
      !_submitting;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top row: X button + handle bar
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppTheme.softGrey,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.steel,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.deepGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                // Balance the X button width
                const SizedBox(width: 30),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'CHOOSE YOUR NAME',
              style: AppTheme.screenTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This is how other players will see you',
              style: AppTheme.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Input field
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _validationError != null
                      ? AppTheme.blazeOrange
                      : _isAvailable == true
                      ? AppTheme.electricBlue
                      : AppTheme.deepGrey,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                maxLength: 20,
                style: AppTheme.rowLabel.copyWith(fontSize: 17),
                decoration: InputDecoration(
                  hintText: 'YourName123',
                  hintStyle: AppTheme.bodyMuted,
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: _suffixIcon(),
                ),
              ),
            ),

            const SizedBox(height: 6),
            _statusRow(),

            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _validationError!,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.blazeOrange,
                    fontSize: 12,
                  ),
                ),
              ),

            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('AVAILABLE NAMES', style: AppTheme.sectionHeader),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions
                    .map(
                      (s) => GestureDetector(
                        onTap: () => _fillSuggestion(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.softGrey,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.deepGrey),
                          ),
                          child: Text(
                            s,
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.electricBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            const SizedBox(height: 28),

            // CONTINUE button
            GestureDetector(
              onTap: _canSubmit ? _submit : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 56,
                decoration: BoxDecoration(
                  color: _canSubmit ? AppTheme.electricBlue : AppTheme.deepGrey,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text('CONTINUE', style: AppTheme.buttonLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suffixIcon() {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.electricBlue,
          ),
        ),
      );
    }
    if (_isAvailable == true) {
      return const Icon(
        Icons.check_circle_rounded,
        color: AppTheme.electricBlue,
        size: 22,
      );
    }
    if (_isAvailable == false) {
      return const Icon(
        Icons.cancel_rounded,
        color: AppTheme.blazeOrange,
        size: 22,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _statusRow() {
    if (_checking) {
      return Text(
        'Checking availability...',
        style: AppTheme.caption.copyWith(color: AppTheme.steel),
      );
    }
    if (_isAvailable == true) {
      return Text(
        '✓ Available',
        style: AppTheme.caption.copyWith(
          color: AppTheme.electricBlue,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (_isAvailable == false) {
      return Text(
        '✗ Taken',
        style: AppTheme.caption.copyWith(
          color: AppTheme.blazeOrange,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return const SizedBox(height: 14);
  }
}

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/display_name_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import 'avatar_picker_screen.dart';
import 'main_shell.dart';

class NamePickerScreen extends StatefulWidget {
  final String? prefill;
  /// When true (new Google sign-ins), navigates to AvatarPickerScreen after
  /// a successful name claim instead of going directly to MainShell.
  final bool isOnboarding;

  const NamePickerScreen({super.key, this.prefill, this.isOnboarding = false});

  @override
  State<NamePickerScreen> createState() => _NamePickerScreenState();
}

class _NamePickerScreenState extends State<NamePickerScreen> {
  late final TextEditingController _ctrl;
  Timer? _debounce;

  String? _validationError;
  bool _checking = false;
  bool? _isAvailable;
  List<String> _suggestions = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final prefill = _sanitize(widget.prefill ?? '');
    _ctrl = TextEditingController(text: prefill);
    _ctrl.addListener(_onChanged);
    if (prefill.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _triggerCheck(prefill));
    }
  }

  String _sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    return cleaned.substring(0, cleaned.length.clamp(0, 20));
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
      _suggestions =
          available ? [] : DisplayNameService.generateSuggestions(name);
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

    // Ensure user doc exists before claiming the name.
    await UserService.ensureUserDoc(user);

    final result = await DisplayNameService.claimName(user.uid, name);
    if (!mounted) return;

    if (result == ClaimResult.success) {
      try {
        await UserService.syncLeaderboardDisplayName(user.uid, name);
      } catch (_) {}
      if (!mounted) return;
      if (widget.isOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AvatarPickerScreen(
              uid: user.uid,
              googlePhotoUrl: user.photoURL,
            ),
          ),
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      }
    } else if (result == ClaimResult.taken) {
      setState(() {
        _isAvailable = false;
        _suggestions = DisplayNameService.generateSuggestions(name);
        _submitting = false;
      });
    } else {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    }
  }

  void _fillSuggestion(String name) {
    _ctrl.text = name;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: name.length));
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBackground(
          child: SafeArea(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                Text(
                  'CHOOSE YOUR NAME',
                  style: AppTheme.screenTitle.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'This is how other players will see you',
                  style: AppTheme.bodyMuted,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

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
                          horizontal: 16, vertical: 16),
                      suffixIcon: _suffixIcon(),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
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
                  const SizedBox(height: 20),
                  Text('AVAILABLE NAMES', style: AppTheme.sectionHeader),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestions
                        .map((s) => _SuggestionChip(
                              name: s,
                              onTap: () => _fillSuggestion(s),
                            ))
                        .toList(),
                  ),
                ],

                const SizedBox(height: 40),

                // CONTINUE button
                GestureDetector(
                  onTap: _canSubmit ? _submit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 56,
                    decoration: BoxDecoration(
                      color: _canSubmit
                          ? AppTheme.electricBlue
                          : AppTheme.deepGrey,
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

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
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
      return const Icon(Icons.check_circle_rounded,
          color: AppTheme.electricBlue, size: 22);
    }
    if (_isAvailable == false) {
      return const Icon(Icons.cancel_rounded,
          color: AppTheme.blazeOrange, size: 22);
    }
    return const SizedBox.shrink();
  }

  Widget _statusRow() {
    if (_checking) {
      return Text('Checking availability...',
          style: AppTheme.caption.copyWith(color: AppTheme.steel));
    }
    if (_isAvailable == true) {
      return Text('✓ Available',
          style: AppTheme.caption.copyWith(
            color: AppTheme.electricBlue,
            fontWeight: FontWeight.w700,
          ));
    }
    if (_isAvailable == false) {
      return Text('✗ Taken',
          style: AppTheme.caption.copyWith(
            color: AppTheme.blazeOrange,
            fontWeight: FontWeight.w700,
          ));
    }
    return const SizedBox(height: 14);
  }
}

class _SuggestionChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _SuggestionChip({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.softGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.deepGrey),
        ),
        child: Text(
          name,
          style: AppTheme.caption.copyWith(
            color: AppTheme.electricBlue,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

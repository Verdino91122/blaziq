import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/display_name_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/user_avatar.dart';
import 'avatar_picker_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;

  Future<void> _handleSignIn() async {
    setState(() => _loading = true);
    final cred = await AuthService.signInWithGoogle();
    if (!mounted) return;
    if (cred == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.cardSurface,
          content: Text(
            'Sign-in cancelled or failed.',
            style: AppTheme.snackText,
          ),
        ),
      );
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleSignOut() async {
    await AuthService.signOut();
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Account?',
          style: AppTheme.subheading.copyWith(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'This will permanently delete your progress, coins, XP, and leaderboard ranking. '
          'This cannot be undone.',
          style: AppTheme.bodyMuted,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.softGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: AppTheme.buttonLabel
                        .copyWith(color: AppTheme.mutedText),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFDC2626).withAlpha(80)),
                  ),
                  child: Text(
                    'Delete Account',
                    textAlign: TextAlign.center,
                    style: AppTheme.buttonLabel
                        .copyWith(color: const Color(0xFFDC2626)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AuthService.deleteAccount();
    // onSignOut callback inside deleteAccount() navigates to WelcomeScreen.
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: SafeArea(
              bottom: false,
              child: user == null || user.isAnonymous
                  ? _AnonView(
                      user: user,
                      loading: _loading,
                      onSignIn: _handleSignIn,
                    )
                  : _SignedInView(
                      user: user,
                      onSignOut: _handleSignOut,
                      onDeleteAccount: _handleDeleteAccount,
                    ),
            ),
          ),
        );
      },
    );
  }
}

// ── Anonymous / guest view ────────────────────────────────────────────────────

class _AnonView extends StatelessWidget {
  final User? user;
  final bool loading;
  final VoidCallback onSignIn;

  const _AnonView({
    required this.user,
    required this.loading,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Save progress banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.blazeGold.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.blazeGold.withAlpha(80)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: AppTheme.blazeGold,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SAVE YOUR PROGRESS!',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.blazeGold,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sign in to unlock leaderboards & challenge friends.',
                        style: AppTheme.caption.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Avatar + name + stats from Firestore
          if (user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: UserService.userStream(user!.uid),
              builder: (context, snap) {
                final data = snap.data?.data();
                final displayName =
                    (data?['displayName'] as String?) ??
                    (data?['username'] as String?) ??
                    'Guest_${user!.uid.substring(0, 6)}';
                return Column(
                  children: [
                    _ProfileAvatarSection(
                      uid: user!.uid,
                      avatarId: data?['avatarId'] as String?,
                      googlePhotoUrl: null,
                    ),
                    const SizedBox(height: 16),
                    _NameRow(
                      uid: user!.uid,
                      displayName: displayName,
                      data: data,
                    ),
                    const SizedBox(height: 4),
                    Text('Guest account', style: AppTheme.bodyMuted),
                    const SizedBox(height: 24),
                    _StatsGrid(data: data),
                  ],
                );
              },
            )
          else ...[
            Text('Guest', style: AppTheme.subheading),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.sparkPink.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.sparkPink.withAlpha(80)),
              ),
              child: Text(
                'Anonymous sign-in failed.\nGo to Firebase Console → Authentication → Sign-in method → Anonymous → Enable it.',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.sparkPink,
                  fontSize: 11,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Google sign-in button
          _SignInButton(
            onTap: loading ? null : onSignIn,
            backgroundColor: Colors.white,
            iconWidget: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.googleButtonText,
                    ),
                  )
                : const _GoogleIcon(),
            label: loading ? 'Signing in…' : 'Sign in with Google',
            textColor: AppTheme.googleButtonText,
          ),

          const SizedBox(height: 16),

          // Linking reward note
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.blazeGold.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.blazeGold.withAlpha(60)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color.fromARGB(255, 255, 255, 255),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Reward: +200 coins for linking!',
                  style: AppTheme.rewardText,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Signed-in (Google) view ───────────────────────────────────────────────────

class _SignedInView extends StatelessWidget {
  final User user;
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  const _SignedInView({
    required this.user,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  void _confirmSignOut(BuildContext context, VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sign Out?',
          style: AppTheme.subheading.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'You will need to choose a new nickname to continue as a guest.',
          style: AppTheme.bodyMuted,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.mutedText.withAlpha(80)),
                  ),
                  child: Text(
                    'Cancel',
                    textAlign: TextAlign.center,
                    style: AppTheme.buttonLabel.copyWith(
                      color: AppTheme.mutedText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppTheme.sparkPink.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.sparkPink.withAlpha(80)),
                  ),
                  child: Text(
                    'Sign Out',
                    textAlign: TextAlign.center,
                    style: AppTheme.buttonLabel.copyWith(
                      color: AppTheme.sparkPink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: UserService.userStream(user.uid),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final displayName =
            (data?['displayName'] as String?) ??
            (data?['username'] as String?) ??
            user.displayName ??
            'Player';
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 40),
              _ProfileAvatarSection(
                uid: user.uid,
                avatarId: data?['avatarId'] as String?,
                googlePhotoUrl: user.photoURL,
              ),
              const SizedBox(height: 16),
              _NameRow(uid: user.uid, displayName: displayName, data: data),
              const SizedBox(height: 4),
              Text(user.email ?? '', style: AppTheme.bodyMuted),
              const SizedBox(height: 32),
              _StatsGrid(data: data),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => _confirmSignOut(context, onSignOut),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.sparkPink.withAlpha(80),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.sparkPink.withAlpha(30)),
                  ),
                  child: Text(
                    'SIGN OUT',
                    textAlign: TextAlign.center,
                    style: AppTheme.buttonLabel.copyWith(
                      color: const Color.fromARGB(255, 249, 111, 22),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onDeleteAccount,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Delete Account',
                        textAlign: TextAlign.center,
                        style: AppTheme.buttonLabel.copyWith(
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ── Name row with edit button ─────────────────────────────────────────────────

class _NameRow extends StatelessWidget {
  final String uid;
  final String displayName;
  final Map<String, dynamic>? data;

  const _NameRow({
    required this.uid,
    required this.displayName,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            displayName,
            style: AppTheme.subheading,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _openChangeNameSheet(context),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppTheme.softGrey,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_rounded,
              size: 16,
              color: AppTheme.steel,
            ),
          ),
        ),
      ],
    );
  }

  void _openChangeNameSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ChangeNameSheet(uid: uid, currentDisplayName: displayName),
    );
  }
}

// ── Change name bottom sheet ──────────────────────────────────────────────────

class _ChangeNameSheet extends StatefulWidget {
  final String uid;
  final String currentDisplayName;

  const _ChangeNameSheet({required this.uid, required this.currentDisplayName});

  @override
  State<_ChangeNameSheet> createState() => _ChangeNameSheetState();
}

class _ChangeNameSheetState extends State<_ChangeNameSheet> {
  late final TextEditingController _ctrl;
  Timer? _debounce;

  bool _loadingCooldown = true;
  bool _canChange = true;
  int _daysLeft = 0;

  String? _validationError;
  bool _checking = false;
  bool? _isAvailable;
  List<String> _suggestions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.currentDisplayName);
    _ctrl.addListener(_onChanged);
    _checkCooldown();
  }

  Future<void> _checkCooldown() async {
    final canChange = await DisplayNameService.canChangeName(widget.uid);
    if (!mounted) return;

    int daysLeft = 0;
    if (!canChange) {
      final doc = await UserService.getUserData(widget.uid);
      final last = doc?['lastNameChange'] as Timestamp?;
      if (last != null) {
        daysLeft = DisplayNameService.daysUntilCanChange(last);
      }
    }
    setState(() {
      _canChange = canChange;
      _daysLeft = daysLeft;
      _loadingCooldown = false;
    });

    // Pre-check availability for the prefilled name if cooldown allows
    if (canChange && widget.currentDisplayName.isNotEmpty) {
      _triggerCheck(widget.currentDisplayName);
    }
  }

  void _onChanged() {
    if (!_canChange) return;
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
    final available = await DisplayNameService.isAvailable(widget.uid, name);
    if (!mounted || _ctrl.text != name) return;
    setState(() {
      _isAvailable = available;
      _checking = false;
      _suggestions = available
          ? []
          : DisplayNameService.generateSuggestions(name);
    });
  }

  Future<void> _save() async {
    final newName = _ctrl.text.trim();
    if (DisplayNameService.validateDisplayName(newName) != null) return;
    if (_isAvailable != true) return;
    if (newName == widget.currentDisplayName) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);

    await DisplayNameService.releaseName(widget.uid, widget.currentDisplayName);
    final result = await DisplayNameService.claimName(widget.uid, newName);
    if (!mounted) return;

    if (result == ClaimResult.success) {
      try {
        await UserService.syncLeaderboardDisplayName(widget.uid, newName);
      } catch (_) {}
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Name changed to $newName', style: AppTheme.snackText),
          backgroundColor: AppTheme.cardSurface,
        ),
      );
    } else if (result == ClaimResult.taken) {
      setState(() {
        _isAvailable = false;
        _suggestions = DisplayNameService.generateSuggestions(newName);
        _saving = false;
      });
    } else {
      setState(() => _saving = false);
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

  bool get _canSave =>
      _canChange &&
      _validationError == null &&
      _isAvailable == true &&
      _ctrl.text.isNotEmpty &&
      !_saving;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: _loadingCooldown
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppTheme.electricBlue),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.deepGrey,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'CHANGE DISPLAY NAME',
                  style: AppTheme.sectionHeader.copyWith(
                    fontSize: 13,
                    letterSpacing: 2,
                    color: AppTheme.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                if (!_canChange) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.softOrange,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.blazeOrange.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timer_rounded,
                          color: AppTheme.blazeOrange,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You can change your name in $_daysLeft day${_daysLeft == 1 ? '' : 's'}',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.blazeOrange,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Text field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_canChange
                          ? AppTheme.deepGrey
                          : _validationError != null
                          ? AppTheme.blazeOrange
                          : _isAvailable == true
                          ? AppTheme.electricBlue
                          : AppTheme.deepGrey,
                      width: 1.5,
                    ),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    enabled: _canChange,
                    autofocus: _canChange,
                    maxLength: 20,
                    style: AppTheme.rowLabel.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      suffixIcon: _canChange ? _suffixIcon() : null,
                    ),
                  ),
                ),

                if (_canChange) ...[
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
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions
                          .map(
                            (s) => GestureDetector(
                              onTap: () => _fillSuggestion(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.softGrey,
                                  borderRadius: BorderRadius.circular(16),
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
                ],

                const SizedBox(height: 20),

                // Save button
                GestureDetector(
                  onTap: _canSave ? _save : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 52,
                    decoration: BoxDecoration(
                      color: _canSave
                          ? AppTheme.electricBlue
                          : AppTheme.deepGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text('SAVE CHANGES', style: AppTheme.buttonLabel),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _suffixIcon() {
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.all(13),
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
        size: 20,
      );
    }
    if (_isAvailable == false) {
      return const Icon(
        Icons.cancel_rounded,
        color: AppTheme.blazeOrange,
        size: 20,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _statusRow() {
    if (_checking) {
      return Text(
        'Checking...',
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

class _ProfileAvatarSection extends StatelessWidget {
  final String uid;
  final String? avatarId;
  final String? googlePhotoUrl;

  const _ProfileAvatarSection({
    required this.uid,
    required this.avatarId,
    required this.googlePhotoUrl,
  });

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerSheet(
        uid: uid,
        currentAvatarId: avatarId,
        googlePhotoUrl: googlePhotoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.blazeGold, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: UserAvatar(
                avatarId: avatarId,
                googlePhotoUrl: googlePhotoUrl,
                radius: 43,
              ),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.electricBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.edit_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic>? data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final games = data?['gamesPlayed'] as int? ?? 0;
    final best = data?['bestScore'] as int? ?? 0;
    final coins = data?['coins'] as int? ?? 0;
    final xp = data?['xp'] as int? ?? 0;
    final level = data?['level'] as int? ?? 1;

    final stats = [
      _StatEntry(
        icon: Icons.sports_esports_rounded,
        label: 'GAMES',
        value: '$games',
      ),
      _StatEntry(icon: Icons.star_rounded, label: 'BEST SCORE', value: '$best'),
      _StatEntry(icon: Icons.toll_rounded, label: 'COINS', value: '$coins'),
      _StatEntry(
        icon: Icons.flash_on_rounded,
        label: 'LEVEL $level',
        value: '${xp}xp',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: stats.map((s) => _StatCard(entry: s)).toList(),
    );
  }
}

class _StatEntry {
  final IconData icon;
  final String label;
  final String value;
  const _StatEntry({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _StatCard extends StatelessWidget {
  final _StatEntry entry;
  const _StatCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Row(
        children: [
          Icon(entry.icon, color: AppTheme.blazeGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.value,
                  style: AppTheme.statValue.copyWith(fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  entry.label,
                  style: AppTheme.caption.copyWith(letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Widget iconWidget;
  final String label;
  final Color textColor;

  const _SignInButton({
    required this.onTap,
    required this.backgroundColor,
    required this.iconWidget,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: onTap == null
              ? backgroundColor.withAlpha(180)
              : backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.deepGrey, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Text(label, style: AppTheme.signInLabel(textColor)),
          ],
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    const strokeW = 3.5;
    const pi = 3.14159265;

    const colors = [
      AppTheme.googleBlue,
      AppTheme.googleGreen,
      AppTheme.googleYellow,
      AppTheme.googleRed,
    ];

    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        -pi / 4 + i * pi / 2,
        pi / 2,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.butt,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - strokeW / 2, r - strokeW / 2, strokeW),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_GoogleIconPainter old) => false;
}

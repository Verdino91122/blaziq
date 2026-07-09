import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import 'about_screen.dart';
import 'how_to_play_screen.dart';

class MenuScreen extends StatefulWidget {
  final VoidCallback onNavigateToProfile;

  const MenuScreen({super.key, required this.onNavigateToProfile});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _soundEffects = true;
  bool _bgMusic = true;
  bool _haptics = true;
  bool _pushNotifications = true;
  bool _inAppNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final sounds = await PreferencesService.getSoundsEnabled();
    final music = await PreferencesService.getMusicEnabled();
    final haptics = await PreferencesService.getHapticsEnabled();
    SoundService.applyPreferences(soundsEnabled: sounds, musicEnabled: music);
    if (!mounted) return;
    setState(() {
      _soundEffects = sounds;
      _bgMusic = music;
      _haptics = haptics;
    });
  }

  Future<void> _rateApp() async {
    final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.blaziq.blaziq');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Check out Blaziq — a fast-paced trivia game where you race against the clock! 🧠⚡\n\nhttps://play.google.com/store/apps/details?id=com.blaziq.blaziq',
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Account?',
            style: AppTheme.subheading.copyWith(fontSize: 20),
            textAlign: TextAlign.center),
        content: Text(
          'This will permanently delete your progress, coins, XP, and leaderboard ranking. '
          'This cannot be undone.',
          style: AppTheme.bodyMuted,
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.mutedText.withAlpha(80)),
                    ),
                    child: Text('Cancel',
                        textAlign: TextAlign.center,
                        style: AppTheme.buttonLabel
                            .copyWith(color: AppTheme.mutedText)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Delete',
                        textAlign: TextAlign.center,
                        style: AppTheme.buttonLabel),
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

  void _confirmSignOut() {
    final user = AuthService.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are playing as a guest — no account to sign out of.',
              style: AppTheme.bodyMuted.copyWith(color: AppTheme.whiteText)),
          backgroundColor: AppTheme.cardSurface,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out?',
            style: AppTheme.subheading.copyWith(fontSize: 20),
            textAlign: TextAlign.center),
        content: Text('You will need to choose a new nickname to continue as a guest.',
            style: AppTheme.bodyMuted, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.mutedText.withAlpha(80)),
                    ),
                    child: Text('Cancel',
                        textAlign: TextAlign.center,
                        style: AppTheme.buttonLabel
                            .copyWith(color: AppTheme.mutedText)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    await AuthService.signOut();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppTheme.blazeGold,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Sign Out',
                        textAlign: TextAlign.center,
                        style: AppTheme.buttonLabel),
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
              children: [
                const SizedBox(height: 20),
                Text('SETTINGS', style: AppTheme.screenTitle),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom),
                children: [
                  _SectionHeader('AUDIO & HAPTICS'),
                  _ToggleRow(
                    icon: Icons.volume_up_rounded,
                    label: 'Sound Effects',
                    value: _soundEffects,
                    onChanged: (v) {
                      setState(() => _soundEffects = v);
                      SoundService.applyPreferences(soundsEnabled: v);
                      PreferencesService.setSoundsEnabled(v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.music_note_rounded,
                    label: 'Background Music',
                    value: _bgMusic,
                    onChanged: (v) {
                      setState(() => _bgMusic = v);
                      SoundService.applyPreferences(musicEnabled: v);
                      PreferencesService.setMusicEnabled(v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.vibration_rounded,
                    label: 'Haptics',
                    value: _haptics,
                    onChanged: (v) {
                      setState(() => _haptics = v);
                      PreferencesService.setHapticsEnabled(v);
                    },
                  ),
                  const SizedBox(height: 8),
                  _SectionHeader('NOTIFICATIONS'),
                  _ToggleRow(
                    icon: Icons.notifications_rounded,
                    label: 'Push Notifications',
                    value: _pushNotifications,
                    onChanged: (v) => setState(() => _pushNotifications = v),
                  ),
                  _ToggleRow(
                    icon: Icons.notifications_active_rounded,
                    label: 'In-App Notifications',
                    value: _inAppNotifications,
                    onChanged: (v) => setState(() => _inAppNotifications = v),
                  ),
                  const SizedBox(height: 8),
                  _SectionHeader('ACCOUNT'),
                  _ArrowRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit Profile',
                    onTap: widget.onNavigateToProfile,
                  ),
                  _ArrowRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    onTap: _confirmSignOut,
                  ),
                  _ArrowRow(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete Account',
                    onTap: _confirmDeleteAccount,
                    destructive: true,
                  ),
                  const SizedBox(height: 8),
                  _SectionHeader('SUPPORT & INFORMATION'),
                  _ArrowRow(
                    icon: Icons.help_outline_rounded,
                    label: 'How To Play',
                    onTap: () => showGeneralDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: Colors.transparent,
                      pageBuilder: (context, anim1, anim2) =>
                          const HowToPlayScreen(),
                    ),
                  ),
                  _ArrowRow(
                    icon: Icons.info_outline_rounded,
                    label: 'About',
                    onTap: () => showGeneralDialog(
                      context: context,
                      barrierDismissible: false,
                      barrierColor: Colors.transparent,
                      pageBuilder: (context, anim1, anim2) =>
                          const AboutScreen(),
                    ),
                  ),
                  _ArrowRow(
                    icon: Icons.star_border_rounded,
                    label: 'Rate App',
                    onTap: _rateApp,
                  ),
                  _ArrowRow(
                    icon: Icons.share_rounded,
                    label: 'Share App',
                    onTap: _shareApp,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4),
      child: Text(title, style: AppTheme.sectionHeader),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.mutedText, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTheme.rowLabel)),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ArrowRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _ArrowRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    final iconColor = destructive ? red : AppTheme.mutedText;
    final labelStyle = destructive
        ? AppTheme.rowLabel.copyWith(color: red)
        : AppTheme.rowLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: labelStyle)),
            Icon(Icons.chevron_right_rounded, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}

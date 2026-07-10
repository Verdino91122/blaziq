import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/remote_config_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'host_screen.dart';
import 'join_screen.dart';
import 'name_picker_screen.dart';

class FriendModeScreen extends StatefulWidget {
  const FriendModeScreen({super.key});

  @override
  State<FriendModeScreen> createState() => _FriendModeScreenState();
}

class _FriendModeScreenState extends State<FriendModeScreen> {
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.blaziq.blaziq';

  bool _checkingUsername = true;
  bool _hasValidUsername = false;
  bool _updateRequired = false;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    await _checkVersion();
    if (!mounted) return;
    if (_updateRequired) {
      // Old build — don't bother with the nickname flow, just show the prompt.
      setState(() => _checkingUsername = false);
      return;
    }
    await _checkUsername();
  }

  /// Compares this build's version code against the Remote Config minimum.
  /// If the version can't be determined (e.g. PackageInfo throwing on Chrome
  /// debug), the user is NOT blocked.
  Future<void> _checkVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber);
      final minimum = RemoteConfigService.getMinimumFriendModeVersion();
      if (current != null && current < minimum) {
        _updateRequired = true;
      }
    } catch (_) {
      // Unknown version — let the user through.
    }
  }

  Future<void> _openPlayStore() async {
    try {
      await launchUrl(
        Uri.parse(_playStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _checkUsername() async {
    final user = AuthService.currentUser;
    if (user == null) {
      setState(() => _checkingUsername = false);
      return;
    }
    final data = await UserService.getUserData(user.uid);
    final displayName = (data?['displayName'] as String?) ?? '';
    final username = (data?['username'] as String?) ?? '';
    final activeName = displayName.isNotEmpty ? displayName : username;
    final valid = activeName.isNotEmpty &&
        activeName != 'Player' &&
        !activeName.startsWith('Guest_');
    setState(() {
      _hasValidUsername = valid;
      _checkingUsername = false;
    });
    if (!valid && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNicknamePicker();
      });
    }
  }

  Future<void> _showNicknamePicker() async {
    // Push the full-screen name picker. On success it navigates to MainShell
    // (clearing the stack), so the user re-enters friend mode with a name set.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NamePickerScreen()),
    );
    // Reached only if the user somehow backs out — re-check state.
    if (mounted) await _checkUsername();
  }

  Future<void> _navigateTo(Widget screen) async {
    if (!_hasValidUsername) {
      await _showNicknamePicker();
      if (!_hasValidUsername) return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Back button row
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.ink),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.electricBlue.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.electricBlue.withAlpha(80), width: 2),
              ),
              child: const Icon(Icons.people_rounded,
                  color: AppTheme.electricBlue, size: 40),
            ),
            const SizedBox(height: 20),
            Text('WITH A FRIEND', style: AppTheme.screenTitle),
            const SizedBox(height: 8),
            Text(
              'Create a private room or join\na friend\'s game with a code.',
              style: AppTheme.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            if (_checkingUsername)
              const CircularProgressIndicator(color: AppTheme.electricBlue)
            else if (_updateRequired)
              _UpdateRequiredCard(onUpdate: _openPlayStore)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ModeButton(
                      icon: Icons.add_circle_outline_rounded,
                      label: 'HOST A GAME',
                      subtitle: 'Create a room and share the code',
                      color: AppTheme.electricBlue,
                      onTap: () => _navigateTo(const HostScreen()),
                    ),
                    const SizedBox(height: 16),
                    _ModeButton(
                      icon: Icons.login_rounded,
                      label: 'JOIN A GAME',
                      subtitle: 'Enter a room code from your friend',
                      color: AppTheme.ink,
                      onTap: () => _navigateTo(const JoinScreen()),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Update required card ─────────────────────────────────────────────────────

class _UpdateRequiredCard extends StatelessWidget {
  final VoidCallback onUpdate;

  const _UpdateRequiredCard({required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.deepGrey),
          boxShadow: [
            BoxShadow(
              color: AppTheme.ink.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update_rounded,
                color: AppTheme.electricBlue, size: 48),
            const SizedBox(height: 16),
            Text(
              'Update Required',
              style: AppTheme.subheading
                  .copyWith(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Friend Mode requires the latest version of Blaziq. '
              'Please update to continue playing with friends.',
              style: AppTheme.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onUpdate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Update Now',
                  textAlign: TextAlign.center,
                  style: AppTheme.buttonLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTheme.buttonLabel
                          .copyWith(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTheme.bodyMuted.copyWith(
                          color: Colors.white.withAlpha(180), fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

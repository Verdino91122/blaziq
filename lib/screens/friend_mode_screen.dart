import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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
  bool _checkingUsername = true;
  bool _hasValidUsername = false;

  @override
  void initState() {
    super.initState();
    _checkUsername();
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

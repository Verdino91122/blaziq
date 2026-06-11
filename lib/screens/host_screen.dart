import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/room_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'lobby_screen.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  String _category = 'science';
  bool _loading = false;

  Future<void> _createRoom() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final userData = await UserService.getUserData(user.uid);
      final roomId = await RoomService.createRoom(
        host: user,
        hostData: userData ?? {},
        category: _category,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomId: roomId,
            myUid: user.uid,
            isHost: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create room: $e'),
          backgroundColor: AppTheme.blazeOrange,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cloudWhite,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Back button
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.ink),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('HOST A GAME', style: AppTheme.screenTitle),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Choose a category to get started.',
                  style: AppTheme.bodyMuted),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('SELECT CATEGORY', style: AppTheme.sectionHeader),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          emoji: '🔬',
                          label: 'Science',
                          selected: _category == 'science',
                          onTap: () => setState(() => _category = 'science'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CategoryCard(
                          emoji: '🌍',
                          label: 'Geography',
                          selected: _category == 'geography',
                          onTap: () => setState(() => _category = 'geography'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _CategoryCard(
                          emoji: '📜',
                          label: 'History',
                          selected: _category == 'history',
                          onTap: () => setState(() => _category = 'history'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _CategoryCard(
                          emoji: '🧠',
                          label: 'General Knowledge',
                          selected: _category == 'general_knowledge',
                          onTap: () =>
                              setState(() => _category = 'general_knowledge'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GestureDetector(
                onTap: _loading ? null : _createRoom,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: _loading
                        ? AppTheme.electricBlue.withAlpha(120)
                        : AppTheme.electricBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text('CREATE ROOM', style: AppTheme.buttonLabel),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.electricBlue.withAlpha(15)
              : AppTheme.softGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.electricBlue : AppTheme.deepGrey,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.rowLabel.copyWith(
                color: selected ? AppTheme.electricBlue : AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../services/question_service.dart';
import '../services/room_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hot_badge.dart';
import 'lobby_screen.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  List<QuizCategory>? _categories;
  bool _categoriesFailed = false;
  String? _category;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _categories = null;
      _categoriesFailed = false;
    });
    try {
      final cats = await QuestionService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _category ??= cats.isNotEmpty ? cats.first.id : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _categoriesFailed = true);
    }
  }

  Future<void> _createRoom() async {
    final user = AuthService.currentUser;
    if (user == null || _category == null) return;
    setState(() => _loading = true);
    try {
      final userData = await UserService.getUserData(user.uid);
      final roomId = await RoomService.createRoom(
        host: user,
        hostData: userData ?? {},
        category: _category!,
        language: await PreferencesService.getQuestionLanguage(),
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

  Widget _buildCategoryGrid() {
    if (_categoriesFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppTheme.steel, size: 40),
            const SizedBox(height: 12),
            Text('Could not load categories', style: AppTheme.bodyMuted),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadCategories,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('TRY AGAIN', style: AppTheme.buttonLabel),
              ),
            ),
          ],
        ),
      );
    }
    final categories = _categories;
    if (categories == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.electricBlue,
          strokeWidth: 3,
        ),
      );
    }
    return GridView.count(
      padding: const EdgeInsets.only(top: 14, right: 8, bottom: 8),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        for (final category in categories)
          _CategoryCard(
            category: category,
            selected: _category == category.id,
            onTap: () => setState(() => _category = category.id),
          ),
      ],
    );
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
            Expanded(
              child: Padding(
                // Right padding lives partly inside the GridView so corner
                // badges (top: -14 / right: -8) aren't clipped by the viewport.
                padding: const EdgeInsets.only(left: 24, right: 16),
                child: _buildCategoryGrid(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: GestureDetector(
                onTap: (_loading || _category == null) ? null : _createRoom,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: (_loading || _category == null)
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
  final QuizCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
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
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.emoji, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.rowLabel.copyWith(
                        color: selected ? AppTheme.electricBlue : AppTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (category.isHot)
              const Positioned(top: -14, right: -8, child: HotBadge()),
          ],
        ),
      ),
    );
  }
}

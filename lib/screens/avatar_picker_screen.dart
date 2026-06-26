import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/user_avatar.dart';
import 'main_shell.dart';

/// Full-screen avatar picker shown during onboarding after name selection
/// (new Google sign-ins only). Pre-selects "google" when a photo is available.
class AvatarPickerScreen extends StatefulWidget {
  final String uid;
  final String? googlePhotoUrl;

  const AvatarPickerScreen({
    super.key,
    required this.uid,
    this.googlePhotoUrl,
  });

  @override
  State<AvatarPickerScreen> createState() => _AvatarPickerScreenState();
}

class _AvatarPickerScreenState extends State<AvatarPickerScreen> {
  late String _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final hasPhoto = (widget.googlePhotoUrl?.isNotEmpty ?? false);
    _selectedId = hasPhoto ? 'google' : 'avatar_1';
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    await UserService.updateAvatar(
      uid: widget.uid,
      avatarId: _selectedId,
      googlePhotoUrl: widget.googlePhotoUrl ?? '',
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ids = avatarPickerIds(
      hasGooglePhoto: widget.googlePhotoUrl?.isNotEmpty ?? false,
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),

                Text(
                  'CHOOSE YOUR AVATAR',
                  style: AppTheme.screenTitle.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can always change this later',
                  style: AppTheme.bodyMuted,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 28),

                // Large preview of selected avatar
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.electricBlue,
                        width: 3,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: UserAvatar(
                        avatarId: _selectedId,
                        googlePhotoUrl: widget.googlePhotoUrl,
                        radius: 47,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Avatar grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1,
                      ),
                      itemCount: ids.length,
                      itemBuilder: (context, index) {
                        final id = ids[index];
                        final selected = _selectedId == id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedId = id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? AppTheme.electricBlue
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: _AvatarGridItem(
                                avatarId: id,
                                googlePhotoUrl: widget.googlePhotoUrl,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: GestureDetector(
                    onTap: _saving ? null : _continue,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.electricBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: _saving
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders a single avatar item in the picker grid.
class _AvatarGridItem extends StatelessWidget {
  final String avatarId;
  final String? googlePhotoUrl;

  const _AvatarGridItem({
    required this.avatarId,
    this.googlePhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      avatarId: avatarId,
      googlePhotoUrl: googlePhotoUrl,
      radius: 30,
    );
  }
}

/// Reusable bottom sheet content for picking/changing an avatar from profile.
class AvatarPickerSheet extends StatefulWidget {
  final String uid;
  final String? currentAvatarId;
  final String? googlePhotoUrl;

  const AvatarPickerSheet({
    super.key,
    required this.uid,
    this.currentAvatarId,
    this.googlePhotoUrl,
  });

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  late String _selectedId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final hasPhoto = (widget.googlePhotoUrl?.isNotEmpty ?? false);
    _selectedId = widget.currentAvatarId?.isNotEmpty == true
        ? widget.currentAvatarId!
        : (hasPhoto ? 'google' : 'avatar_1');
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await UserService.updateAvatar(
      uid: widget.uid,
      avatarId: _selectedId,
      googlePhotoUrl: widget.googlePhotoUrl ?? '',
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ids = avatarPickerIds(
      hasGooglePhoto: widget.googlePhotoUrl?.isNotEmpty ?? false,
    );
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.cloudWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
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
                const SizedBox(height: 16),
                Text(
                  'CHANGE AVATAR',
                  style: AppTheme.sectionHeader.copyWith(
                    fontSize: 13,
                    letterSpacing: 2,
                    color: AppTheme.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Avatar grid — constrained height so it doesn't overflow
          SizedBox(
            height: 320,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: ids.length,
                itemBuilder: (context, index) {
                  final id = ids[index];
                  final selected = _selectedId == id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedId = id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppTheme.electricBlue
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: _AvatarGridItem(
                          avatarId: id,
                          googlePhotoUrl: widget.googlePhotoUrl,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Save button
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.electricBlue,
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
                      : Text('SAVE AVATAR', style: AppTheme.buttonLabel),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

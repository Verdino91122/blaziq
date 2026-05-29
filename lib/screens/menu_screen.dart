import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.arenaBlack,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text('SETTINGS', style: AppTheme.screenTitle),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _SectionHeader('AUDIO & HAPTICS'),
                  _ToggleRow(
                    icon: Icons.volume_up_rounded,
                    label: 'Sound Effects',
                    value: _soundEffects,
                    onChanged: (v) => setState(() => _soundEffects = v),
                  ),
                  _ToggleRow(
                    icon: Icons.music_note_rounded,
                    label: 'Background Music',
                    value: _bgMusic,
                    onChanged: (v) => setState(() => _bgMusic = v),
                  ),
                  _ToggleRow(
                    icon: Icons.vibration_rounded,
                    label: 'Haptics',
                    value: _haptics,
                    onChanged: (v) => setState(() => _haptics = v),
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
                  _ArrowRow(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () {}),
                  _ArrowRow(icon: Icons.logout_rounded, label: 'Sign Out', onTap: () {}),
                  const SizedBox(height: 8),
                  _SectionHeader('SUPPORT & INFORMATION'),
                  _ArrowRow(icon: Icons.help_outline_rounded, label: 'How To Play', onTap: () {}),
                  _ArrowRow(icon: Icons.info_outline_rounded, label: 'About', onTap: () {}),
                  _ArrowRow(icon: Icons.star_border_rounded, label: 'Rate App', onTap: () {}),
                  _ArrowRow(icon: Icons.share_rounded, label: 'Share App', onTap: () {}),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
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
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ArrowRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ArrowRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
            Icon(icon, color: AppTheme.mutedText, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTheme.rowLabel)),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.mutedText, size: 22),
          ],
        ),
      ),
    );
  }
}

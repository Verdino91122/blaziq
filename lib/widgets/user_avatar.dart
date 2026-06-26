import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Avatar group numbers available as assets (Group 45 is missing from the set).
const List<int> kAvatarGroups = [
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38,
  39, 40, 41, 42, 43, 44, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57,
  58, 59, 60, 61, 62, 63, 64, 65, 66,
];

/// Returns the ordered list of avatar IDs for a picker.
/// - "google"   appears first when [hasGooglePhoto] is true
/// - "avatar_N" for every SVG in the asset set
List<String> avatarPickerIds({required bool hasGooglePhoto}) {
  return [
    if (hasGooglePhoto) 'google',
    ...kAvatarGroups.map((n) => 'avatar_$n'),
  ];
}

/// Returns the asset path for an avatarId like "avatar_5".
String avatarSvgPath(String avatarId) {
  final n = avatarId.substring('avatar_'.length);
  return 'assets/avatars/Group $n.svg';
}

/// Renders a user avatar based on [avatarId]:
/// - "avatar_N" → SVG from assets/avatars/Group N.svg
/// - "google"   → NetworkImage from [googlePhotoUrl]
/// - null/empty → initials or person icon
class UserAvatar extends StatelessWidget {
  final String? avatarId;
  final String? googlePhotoUrl;
  final double radius;
  final String? initial;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.avatarId,
    this.googlePhotoUrl,
    required this.radius,
    this.initial,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final id = avatarId ?? '';

    if (id.startsWith('avatar_')) {
      return ClipOval(
        child: SvgPicture.asset(
          avatarSvgPath(id),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = (id == 'google') ? googlePhotoUrl : null;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? AppTheme.cardSurface,
        backgroundImage: NetworkImage(url),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.cardSurface,
      child: (initial?.isNotEmpty ?? false)
          ? Text(
              initial!.toUpperCase(),
              style: TextStyle(
                fontSize: radius * 0.85,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            )
          : Icon(Icons.person, color: AppTheme.mutedText, size: radius * 1.1),
    );
  }
}

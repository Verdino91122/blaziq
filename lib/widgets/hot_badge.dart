import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "HOT NOW" flame badge (assets/icons/hot_now_badge.svg) shown on category
/// cards where isHot == true. Position with Stack/Positioned in the parent
/// using negative offsets so it sits ON the card corner, not inside it — the
/// parent Stack needs clipBehavior: Clip.none (same pattern as the HOST badge
/// in the lobby).
class HotBadge extends StatelessWidget {
  final double height;

  const HotBadge({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/hot_now_badge.svg',
      height: height,
    );
  }
}

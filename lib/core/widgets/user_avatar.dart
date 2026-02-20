import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AvatarPreset {
  final String key;
  final Color bgStart;
  final Color bgEnd;
  final IconData icon;
  final Color iconColor;

  const AvatarPreset({
    required this.key,
    required this.bgStart,
    required this.bgEnd,
    required this.icon,
    required this.iconColor,
  });
}

class UserAvatar extends StatelessWidget {
  final String? avatarKey;
  final double size;
  final double borderWidth;

  const UserAvatar({
    super.key,
    required this.avatarKey,
    this.size = 56,
    this.borderWidth = 2,
  });

  static const List<AvatarPreset> presets = [
    AvatarPreset(
      key: 'a01',
      bgStart: Color(0xFFFFE082),
      bgEnd: Color(0xFFFFCA28),
      icon: Icons.sentiment_very_satisfied_rounded,
      iconColor: Color(0xFF4E342E),
    ),
    AvatarPreset(
      key: 'a02',
      bgStart: Color(0xFFB3E5FC),
      bgEnd: Color(0xFF4FC3F7),
      icon: Icons.face_rounded,
      iconColor: Color(0xFF0D47A1),
    ),
    AvatarPreset(
      key: 'a03',
      bgStart: Color(0xFFC8E6C9),
      bgEnd: Color(0xFF66BB6A),
      icon: Icons.emoji_emotions_rounded,
      iconColor: Color(0xFF1B5E20),
    ),
    AvatarPreset(
      key: 'a04',
      bgStart: Color(0xFFFFCDD2),
      bgEnd: Color(0xFFEF5350),
      icon: Icons.emoji_people_rounded,
      iconColor: Color(0xFF880E4F),
    ),
    AvatarPreset(
      key: 'a05',
      bgStart: Color(0xFFD1C4E9),
      bgEnd: Color(0xFF9575CD),
      icon: Icons.face_3_rounded,
      iconColor: Color(0xFF311B92),
    ),
    AvatarPreset(
      key: 'a06',
      bgStart: Color(0xFFFFE0B2),
      bgEnd: Color(0xFFFFA726),
      icon: Icons.mood_rounded,
      iconColor: Color(0xFFE65100),
    ),
    AvatarPreset(
      key: 'a07',
      bgStart: Color(0xFFB2DFDB),
      bgEnd: Color(0xFF26A69A),
      icon: Icons.emoji_nature_rounded,
      iconColor: Color(0xFF004D40),
    ),
    AvatarPreset(
      key: 'a08',
      bgStart: Color(0xFFFFF59D),
      bgEnd: Color(0xFFFFEE58),
      icon: Icons.rocket_launch_rounded,
      iconColor: Color(0xFF5D4037),
    ),
    AvatarPreset(
      key: 'a09',
      bgStart: Color(0xFFFFCCBC),
      bgEnd: Color(0xFFFF8A65),
      icon: Icons.whatshot_rounded,
      iconColor: Color(0xFFBF360C),
    ),
    AvatarPreset(
      key: 'a10',
      bgStart: Color(0xFFCFD8DC),
      bgEnd: Color(0xFF90A4AE),
      icon: Icons.psychology_alt_rounded,
      iconColor: Color(0xFF263238),
    ),
    AvatarPreset(
      key: 'a11',
      bgStart: Color(0xFFD7CCC8),
      bgEnd: Color(0xFFA1887F),
      icon: Icons.auto_awesome_rounded,
      iconColor: Color(0xFF3E2723),
    ),
    AvatarPreset(
      key: 'a12',
      bgStart: Color(0xFFFFF9C4),
      bgEnd: Color(0xFFFFF176),
      icon: Icons.sports_esports_rounded,
      iconColor: Color(0xFF5D4037),
    ),
  ];

  static AvatarPreset resolve(String? key) {
    final target = key ?? 'a01';
    return presets.firstWhere(
      (p) => p.key == target,
      orElse: () => presets.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = resolve(avatarKey);
    final iconSize = size * 0.52;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: borderWidth),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [preset.bgStart, preset.bgEnd],
        ),
      ),
      child: Icon(preset.icon, color: preset.iconColor, size: iconSize),
    );
  }
}

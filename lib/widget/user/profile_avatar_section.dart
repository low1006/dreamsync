import 'package:flutter/material.dart';
import 'package:dreamsync/widget/custom/user_avatar.dart';

class ProfileAvatarSection extends StatelessWidget {
  final String avatarPath;
  final String username;
  final String email;
  final String uidText;
  final Color accent;
  final Color surface;

  const ProfileAvatarSection({
    super.key,
    required this.avatarPath,
    required this.username,
    required this.email,
    required this.uidText,
    required this.accent,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UserAvatar(
          avatarPath: avatarPath,
          size: 100,
          borderColor: accent.withOpacity(0.5),
          borderWidth: 2,
          borderPadding: 4,
        ),
        const SizedBox(height: 16),
        Text(
          username,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          email,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(0.2)),
          ),
          child: SelectableText(
            'UID: $uidText',
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
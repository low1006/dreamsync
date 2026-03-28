import 'package:flutter/material.dart';
import 'package:dreamsync/models/friend_profile_model.dart';
import 'package:dreamsync/widget/custom/user_avatar.dart';

class FriendCard extends StatelessWidget {
  final FriendProfile friend;
  final Color surface;
  final Color text;
  final Color accent;
  final VoidCallback onTap;

  const FriendCard({
    super.key,
    required this.friend,
    required this.surface,
    required this.text,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: text.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            UserAvatar(
              avatarPath: friend.avatarAssetPath,
              size: 48,
              borderColor: accent.withOpacity(0.5),
              borderWidth: 2,
              fallbackIconColor: accent,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.username,
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    friend.email,
                    style: TextStyle(
                      color: text.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: text.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:dreamsync/models/friend_profile_model.dart';

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
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.5), width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: accent.withOpacity(0.1),
                child: Text(
                  friend.username[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accent,
                    fontSize: 20,
                  ),
                ),
              ),
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
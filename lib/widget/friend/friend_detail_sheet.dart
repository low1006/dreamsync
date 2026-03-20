import 'package:flutter/material.dart';
import 'package:dreamsync/models/friend_profile_model.dart';

class FriendDetailSheet extends StatelessWidget {
  final FriendProfile friend;
  final Color surface;
  final Color text;
  final Color accent;

  const FriendDetailSheet({
    super.key,
    required this.friend,
    required this.surface,
    required this.text,
    required this.accent,
  });

  static void show(
      BuildContext context, {
        required FriendProfile friend,
        required Color surface,
        required Color text,
        required Color accent,
      }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FriendDetailSheet(
        friend: friend,
        surface: surface,
        text: text,
        accent: accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: text.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          CircleAvatar(
            radius: 36,
            backgroundColor: accent.withOpacity(0.1),
            child: Text(
              friend.username[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: accent,
                fontSize: 28,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            friend.username,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(
            "UID: ${friend.uidText ?? 'Unknown'}",
            style: TextStyle(color: text.withOpacity(0.5), fontSize: 14),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                Icons.bedtime,
                "${friend.sleepGoalHours}h",
                "Sleep Goal",
                text,
                accent,
              ),
              Container(width: 1, height: 40, color: text.withOpacity(0.1)),
              _buildStatItem(
                Icons.local_fire_department,
                "${friend.streak}",
                "Day Streak",
                text,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent.withOpacity(0.1),
                foregroundColor: accent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Close",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon,
      String value,
      String label,
      Color text,
      Color iconColor,
      ) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: text.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/models/friend_profile_model.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';
import 'package:dreamsync/widget/custom/user_avatar.dart';

class RequestCard extends StatelessWidget {
  final FriendProfile request;
  final Color surface;
  final Color text;
  final Color accent;

  const RequestCard({
    super.key,
    required this.request,
    required this.surface,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<FriendViewModel>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarPath: request.avatarAssetPath,
            size: 48,
            borderColor: Colors.orange.withOpacity(0.5),
            borderWidth: 2,
            fallbackIconColor: Colors.orange,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.username,
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Wants to connect",
                  style: TextStyle(
                    color: text.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              final achievementVM = context.read<AchievementViewModel>();
              vm.acceptRequest(request.senderId, achievementVM);
            },
            child: const Text("Accept"),
          ),
        ],
      ),
    );
  }
}
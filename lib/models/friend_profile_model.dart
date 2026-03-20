class FriendProfile {
  final String username;
  final String email;
  final String? uidText;
  final double sleepGoalHours;
  final int streak;
  final String senderId;
  final String receiverId;

  FriendProfile({
    required this.username,
    required this.email,
    this.uidText,
    this.sleepGoalHours = 8.0,
    this.streak = 0,
    required this.senderId,
    required this.receiverId,
  });

  factory FriendProfile.fromFriendshipRow({
    required Map<String, dynamic> profileData,
    required String senderId,
    required String receiverId,
  }) {
    return FriendProfile(
      username: profileData['username'] ?? '',
      email: profileData['email'] ?? '',
      uidText: profileData['uid_text'],
      sleepGoalHours: (profileData['sleep_goal_hours'] as num?)?.toDouble() ?? 8.0,
      streak: (profileData['streak'] as num?)?.toInt() ?? 0,
      senderId: senderId,
      receiverId: receiverId,
    );
  }
}
import 'achievement_model.dart';

class UserAchievementModel {
  final String userAchievementId;
  final String userId;
  final String achievementId;
  final double currentProgress;
  final bool isUnlocked;
  final bool isClaimed;
  final DateTime? dateClaim;
  final AchievementModel? achievement;

  UserAchievementModel({
    required this.userAchievementId,
    required this.userId,
    required this.achievementId,
    required this.currentProgress,
    required this.isUnlocked,
    required this.isClaimed,
    this.dateClaim,
    this.achievement,
  });

  factory UserAchievementModel.fromJson(Map<String, dynamic> json) {
    return UserAchievementModel(
      userAchievementId: json['user_achievement_id']?.toString() ?? '',
      // ✅ FIXED: was json['id'] — must be json['user_id']
      userId: json['user_id']?.toString() ?? '',
      achievementId: json['achievement_id']?.toString() ?? '',
      currentProgress: (json['current_progress'] as num?)?.toDouble() ?? 0.0,
      isUnlocked: json['is_unlocked'] ?? false,
      isClaimed: json['is_claimed'] ?? false,
      dateClaim: json['date_claimed'] != null
          ? DateTime.parse(json['date_claimed'])
          : null,
      achievement: json['achievement'] != null
          ? AchievementModel.fromJson(json['achievement'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_achievement_id': userAchievementId,
      'user_id': userId,
      'achievement_id': achievementId,
      'current_progress': currentProgress,
      'is_unlocked': isUnlocked,
      'is_claimed': isClaimed,
      if (dateClaim != null) 'date_claimed': dateClaim!.toIso8601String(),
    };
  }
}
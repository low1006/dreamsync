import "package:dreamsync/util/parsers.dart";
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
      userId: json['user_id']?.toString() ?? '',
      achievementId: json['achievement_id']?.toString() ?? '',
      currentProgress: Parsers.toDouble(json['current_progress']),
      isUnlocked: Parsers.toBool(json['is_unlocked']),
      isClaimed: Parsers.toBool(json['is_claimed']),
      dateClaim:  _parseDate(json['date_claimed']),
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

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
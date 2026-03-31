import "package:dreamsync/util/parsers.dart";
class AchievementModel {
  final String achievementID;
  final String title;
  final String description;
  final String category;
  final String criteriaType;
  final double criteriaValue;
  final double xpReward;

  AchievementModel({
    required this.achievementID,
    required this.title,
    required this.description,
    required this.category,
    required this.criteriaType,
    required this.criteriaValue,
    required this.xpReward,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      achievementID: (json['achievement_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      criteriaType: (json['criteria_type'] ?? '').toString(),
      criteriaValue: Parsers.toDouble(json['criteria_value']),
      xpReward: Parsers.toDouble(json['xp_reward']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'achievement_id': achievementID,
      'title': title,
      'description': description,
      'category': category,
      'criteria_type': criteriaType,
      'criteria_value': criteriaValue,
      'xp_reward': xpReward,
    };
  }
}
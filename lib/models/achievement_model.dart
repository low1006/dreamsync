class AchievementModel {
  final String achievementID;
  final String title;
  final String description;
  final String category;
  final String criteriaType;
  final double criteriaValue;
  final double xpReward;
  final String iconPath;

  AchievementModel({
    required this.achievementID,
    required this.title,
    required this.description,
    required this.category,
    required this.criteriaType,
    required this.criteriaValue,
    required this.xpReward,
    required this.iconPath
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
        achievementID: json['achievement_id'].toString(),
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        category: json['category'] ?? '',
        criteriaType: json['criteria_type'] ?? '',
        criteriaValue: (json['criteria_value'] as num?)?.toDouble() ?? 0.0,
        xpReward: (json['xp_reward'] as num?)?.toDouble() ?? 0.0,
        iconPath: json['icon_path'] ?? ''
    );
  }
}
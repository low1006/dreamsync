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
      criteriaValue: _toDouble(json['criteria_value']),
      xpReward: _toDouble(json['xp_reward']),
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

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
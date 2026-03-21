class DailyActivityModel {
  final String? id; // maps to activity_id in local DB
  final String userId;
  final String date;
  final int exerciseMinutes;
  final int foodCalories;
  final int screenTimeMinutes;

  const DailyActivityModel({
    this.id,
    required this.userId,
    required this.date,
    required this.exerciseMinutes,
    required this.foodCalories,
    required this.screenTimeMinutes,
  });

  factory DailyActivityModel.fromJson(Map<String, dynamic> json) {
    return DailyActivityModel(
      id: (json['activity_id'] ?? json['id'])?.toString(),
      userId: (json['user_id'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      exerciseMinutes: _toInt(json['exercise_minutes']),
      foodCalories: _toInt(json['food_calories']),
      screenTimeMinutes: _toInt(json['screen_time_minutes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'activity_id': id,
      'user_id': userId,
      'date': date,
      'exercise_minutes': exerciseMinutes,
      'food_calories': foodCalories,
      'screen_time_minutes': screenTimeMinutes,
    };
  }

  DailyActivityModel copyWith({
    String? id,
    String? userId,
    String? date,
    int? exerciseMinutes,
    int? foodCalories,
    int? screenTimeMinutes,
  }) {
    return DailyActivityModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      foodCalories: foodCalories ?? this.foodCalories,
      screenTimeMinutes: screenTimeMinutes ?? this.screenTimeMinutes,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}
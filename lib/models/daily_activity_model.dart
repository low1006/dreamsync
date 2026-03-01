class DailyActivityModel {
  final String? id;
  final String userId;
  final String date;
  final int exerciseMinutes;
  final int foodCalories;
  final int screenTimeMinutes;

  DailyActivityModel({
    this.id,
    required this.userId,
    required this.date,
    this.exerciseMinutes = 0,
    this.foodCalories = 0,
    this.screenTimeMinutes = 0,
  });

  factory DailyActivityModel.fromJson(Map<String, dynamic> json) {
    return DailyActivityModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      date: json['date'] as String,
      exerciseMinutes: json['exercise_minutes'] as int? ?? 0,
      foodCalories: json['food_calories'] as int? ?? 0,
      screenTimeMinutes: json['screen_time_minutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'exercise_minutes': exerciseMinutes,
      'food_calories': foodCalories,
      'screen_time_minutes': screenTimeMinutes,
    };
  }
}
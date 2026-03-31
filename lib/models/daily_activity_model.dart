import "package:dreamsync/util/parsers.dart";
class DailyActivityModel {
  final String? id;
  final String userId;
  final String date;
  final int exerciseMinutes;
  final int foodCalories;
  final int screenTimeMinutes;
  final int burnedCalories;
  final double caffeineIntakeMg;
  final double sugarIntakeG;
  final double alcoholIntakeG;

  const DailyActivityModel({
    this.id,
    required this.userId,
    required this.date,
    required this.exerciseMinutes,
    required this.foodCalories,
    required this.screenTimeMinutes,
    required this.burnedCalories,
    this.caffeineIntakeMg = 0,
    this.sugarIntakeG = 0,
    this.alcoholIntakeG = 0,
  });

  factory DailyActivityModel.fromJson(Map<String, dynamic> json) {
    return DailyActivityModel(
      id: (json['activity_id'] ?? json['id'])?.toString(),
      userId: (json['user_id'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      exerciseMinutes: Parsers.toInt(json['exercise_minutes']),
      foodCalories: Parsers.toInt(json['food_calories']),
      screenTimeMinutes: Parsers.toInt(json['screen_time_minutes']),
      burnedCalories: Parsers.toInt(json['burned_calories']),
      caffeineIntakeMg: Parsers.toDouble(json['caffeine_intake_mg']),
      sugarIntakeG: Parsers.toDouble(json['sugar_intake_g']),
      alcoholIntakeG: Parsers.toDouble(json['alcohol_intake_g']),
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
      'burned_calories': burnedCalories,
      'caffeine_intake_mg': caffeineIntakeMg,
      'sugar_intake_g': sugarIntakeG,
      'alcohol_intake_g': alcoholIntakeG,
    };
  }

  DailyActivityModel copyWith({
    String? id,
    String? userId,
    String? date,
    int? exerciseMinutes,
    int? foodCalories,
    int? screenTimeMinutes,
    int? burnedCalories,
    double? caffeineIntakeMg,
    double? sugarIntakeG,
    double? alcoholIntakeG,
  }) {
    return DailyActivityModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      foodCalories: foodCalories ?? this.foodCalories,
      screenTimeMinutes: screenTimeMinutes ?? this.screenTimeMinutes,
      burnedCalories: burnedCalories ?? this.burnedCalories,
      caffeineIntakeMg: caffeineIntakeMg ?? this.caffeineIntakeMg,
      sugarIntakeG: sugarIntakeG ?? this.sugarIntakeG,
      alcoholIntakeG: alcoholIntakeG ?? this.alcoholIntakeG,
    );
  }

}
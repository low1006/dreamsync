class SleepRecommendationCacheModel {
  final String userId;
  final String date;
  final int recommendedMinutes;
  final double expectedScore;
  final int simDeepMinutes;
  final int simRemMinutes;
  final double simDeepPct;
  final double simRemPct;
  final String explanation;
  final String? message;
  final String generatedAt;

  SleepRecommendationCacheModel({
    required this.userId,
    required this.date,
    required this.recommendedMinutes,
    required this.expectedScore,
    required this.simDeepMinutes,
    required this.simRemMinutes,
    required this.simDeepPct,
    required this.simRemPct,
    required this.explanation,
    this.message,
    required this.generatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'date': date,
      'recommended_minutes': recommendedMinutes,
      'expected_score': expectedScore,
      'sim_deep_minutes': simDeepMinutes,
      'sim_rem_minutes': simRemMinutes,
      'sim_deep_pct': simDeepPct,
      'sim_rem_pct': simRemPct,
      'explanation': explanation,
      'message': message,
      'generated_at': generatedAt,
    };
  }

  factory SleepRecommendationCacheModel.fromMap(Map<String, dynamic> map) {
    return SleepRecommendationCacheModel(
      userId: map['user_id'] as String,
      date: map['date'] as String,
      recommendedMinutes: (map['recommended_minutes'] as num).toInt(),
      expectedScore: (map['expected_score'] as num).toDouble(),
      simDeepMinutes: (map['sim_deep_minutes'] as num).toInt(),
      simRemMinutes: (map['sim_rem_minutes'] as num).toInt(),
      simDeepPct: (map['sim_deep_pct'] as num).toDouble(),
      simRemPct: (map['sim_rem_pct'] as num).toDouble(),
      explanation: map['explanation'] as String,
      message: map['message'] as String?,
      generatedAt: map['generated_at'] as String,
    );
  }
}
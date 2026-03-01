class SleepRecordModel {
  final String? id;
  final String userId;
  final String date;
  final int totalMinutes;
  final int sleepScore;

  SleepRecordModel({
    this.id,
    required this.userId,
    required this.date,
    required this.totalMinutes,
    required this.sleepScore,
  });

  factory SleepRecordModel.fromJson(Map<String, dynamic> json) {
    return SleepRecordModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      date: json['date'] as String,
      totalMinutes: json['total_minutes'] as int,
      sleepScore: json['sleep_score'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'total_minutes': totalMinutes,
      'sleep_score': sleepScore,
    };
  }
}
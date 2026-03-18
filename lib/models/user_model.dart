class UserModel {
  final String userId;
  final String username;
  final String email;
  final String gender;
  final String dateBirth;
  double weight;
  double height;
  final String uidText;
  int currentPoints;
  double sleepGoalHours;
  final int streak;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.gender,
    required this.dateBirth,
    required this.weight,
    required this.height,
    required this.uidText,
    required this.currentPoints,
    this.sleepGoalHours = 8.0,
    this.streak = 0,
  });

  int get age {
    if (dateBirth.isEmpty) return 0;

    try {
      final now = DateTime.now();
      final birthDate = DateTime.parse(dateBirth);

      int age = now.year - birthDate.year;

      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }

      return age;
    } catch (e) {
      return 0;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? 'Unknown',
      email: json['email'] ?? '',
      gender: json['gender'] ?? '',
      dateBirth: json['date_birth'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      height: (json['height'] ?? 0).toDouble(),
      uidText: json['uid_text'] ?? '',
      currentPoints: json['current_points'] ?? 0,
      sleepGoalHours: (json['sleep_goal_hours'] ?? 8.0).toDouble(),
      streak: json['streak'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'email': email,
      'gender': gender,
      'date_birth': dateBirth,
      'weight': weight,
      'height': height,
      'uid_text': uidText,
      'current_points': currentPoints,
      'sleep_goal_hours': sleepGoalHours,
      'streak': streak,
    };
  }
}
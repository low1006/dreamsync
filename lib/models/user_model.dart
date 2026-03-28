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
  int streak;
  String? avatarAssetPath;

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
    this.avatarAssetPath,
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
    } catch (_) {
      return 0;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final avatarRaw = json['avatar_asset_path'];
    final avatar = avatarRaw?.toString().trim();

    return UserModel(
      userId: (json['user_id'] ?? '').toString(),
      username: (json['username'] ?? 'Unknown').toString(),
      email: (json['email'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      dateBirth: (json['date_birth'] ?? '').toString(),
      weight: _toDouble(json['weight']),
      height: _toDouble(json['height']),
      uidText: (json['uid_text'] ?? '').toString(),
      currentPoints: _toInt(json['current_points']),
      sleepGoalHours: _toDouble(json['sleep_goal_hours'], fallback: 8.0),
      streak: _toInt(json['streak']),
      avatarAssetPath: (avatar == null || avatar.isEmpty) ? null : avatar,
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
      'avatar_asset_path': avatarAssetPath,
    };
  }

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }
}

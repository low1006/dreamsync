class UserModel {
  final String userId;
  final String username;
  final String email;
  final String gender;
  final String dateBirth;
  final double weight;
  final double height;
  final String uidText;
  final int currentPoints;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.gender,
    required this.dateBirth,
    required this.weight,
    required this.height,
    required this.uidText,
    required this.currentPoints
  });

  int get age {
    if(dateBirth.isEmpty) return 0;

    try {
      final now = DateTime.now();
      final birthDate = DateTime.parse(dateBirth);

      int age = now.year - birthDate.year;

      if(now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)){
        age--;
      }

      return age;
    } catch (e){
      return 0;
    }
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      gender: json['gender'] ?? '',
      dateBirth: json['date_birth'] ?? '',
      weight: (json['weight'] ?? 0.0).toDouble(),
      height: (json['height'] ?? 0.0).toDouble(),
      uidText: json['uid_text'] ?? '',
      currentPoints: json['current_points'] ?? 0,
    );
  }

  Map<String, dynamic> toJson(){
    return{
      'user_id':userId,
      'username':username,
      'email':email,
      'gender':gender,
      'date_birth':dateBirth,
      'weight':weight,
      'height':height,
      'uid_text':uidText,
      'current_points':currentPoints,
    };
  }
}

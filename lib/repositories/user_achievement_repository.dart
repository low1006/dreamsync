import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'base_repository.dart';

class UserAchievementRepository extends BaseRepository<UserAchievementModel>{
  UserAchievementRepository(SupabaseClient client)
      :super(
        client,
        'user_achievement',
        'user_achievement_id',
        (json) => UserAchievementModel.fromJson(json)
  ) ;

  Future<List<UserAchievementModel>> fetchUserAchievements (String userID)  async{
    try{
      final data = await client.from('user_achievement').select('*, achievement(*)').eq('user_id', userID);
      return data.map((json) => UserAchievementModel.fromJson(json)).toList();
    }catch(e){
      print("Error fetching user achievement: $e");
      return [];
    }
  }
}
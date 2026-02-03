import 'package:dreamsync/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/achievement_model.dart';

class AchievementRepository extends BaseRepository <AchievementModel>{
  AchievementRepository(SupabaseClient client)
  : super(client, 'achievement', 'achievement_id', (json) => AchievementModel.fromJson(json)
  );

  Future<List<AchievementModel>> fetchAllAchievements() async {
    return await getAll();
  }


}
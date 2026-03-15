import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'base_repository.dart';

class UserAchievementRepository extends BaseRepository<UserAchievementModel> {
  UserAchievementRepository(SupabaseClient client)
      : super(
    client,
    'user_achievement',
    'user_achievement_id',
        (json) => UserAchievementModel.fromJson(json),
  );

  Future<List<UserAchievementModel>> getByUserId(String userId) async {
    final data = await client
        .from(tableName)
        .select('*, achievement(*)')
        .eq('user_id', userId);

    return (data as List)
        .map((json) => UserAchievementModel.fromJson(json))
        .toList();
  }

  Future<UserAchievementModel> createUserAchievement({
    required String userId,
    required dynamic achievementId,
    required int currentProgress,
    required bool isUnlocked,
    bool isClaimed = false,
  }) async {
    final response = await client
        .from(tableName)
        .insert({
      'user_id': userId,
      'achievement_id': achievementId,
      'current_progress': currentProgress,
      'is_unlocked': isUnlocked,
      'is_claimed': isClaimed,
    })
        .select('*, achievement(*)')
        .single();

    return UserAchievementModel.fromJson(response);
  }

  Future<void> updateProgress({
    required String userAchievementId,
    required int currentProgress,
    required bool isUnlocked,
  }) async {
    await client.from(tableName).update({
      'current_progress': currentProgress,
      'is_unlocked': isUnlocked,
    }).eq('user_achievement_id', userAchievementId);
  }

  Future<void> markAsClaimed(String userAchievementId) async {
    await client.from(tableName).update({
      'is_claimed': true,
      'date_claim': DateTime.now().toIso8601String(),
    }).eq('user_achievement_id', userAchievementId);
  }
}
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_model.dart';
import 'base_repository.dart';
import 'package:flutter/foundation.dart';

class UserRepository extends BaseRepository<UserModel> {
  UserRepository(SupabaseClient client)
      : super(client, 'profile', 'user_id', (json) => UserModel.fromJson(json));

  Future<void> createUser(UserModel user) async {
    await create(user.toJson());
  }


  Future<void> deleteAccount() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Soft delete — marks deleted_at, real deletion after 30 days
      await client.rpc('delete_user_account');
      await client.auth.signOut();
    } catch (e) {
      debugPrint("DELETE ERROR: $e");
      await client.auth.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> updateProfileData({
    required String userId,
    required double weight,
    required double height,
    required double sleepGoalHours,
  }) async {
    await client.from(tableName).update({
      'weight': weight,
      'height': height,
      'sleep_goal_hours': sleepGoalHours,
    }).eq('user_id', userId);
  }

  Future<void> updatePoints(String userId, int newPoints) async {
    await client
        .from(tableName)
        .update({'current_points': newPoints}).eq('user_id', userId);
  }

  Future<UserModel?> getCurrentUser() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    return getById(userId);
  }
}
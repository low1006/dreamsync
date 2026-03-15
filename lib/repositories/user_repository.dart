import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'base_repository.dart';

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

  Future<UserModel?> getProfileSafe(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final isOnline = await NetworkHelper.isOnline();

      if (isOnline) {
        debugPrint("🌐 Online: Fetching profile from Supabase...");

        final user = await getById(userId).timeout(const Duration(seconds: 5));

        if (user != null) {
          await prefs.setString(
            'cached_user_profile_$userId',
            jsonEncode(user.toJson()),
          );
        }

        return user;
      } else {
        debugPrint("📴 Offline: Attempting to load profile from cache...");
        return _getCachedProfile(userId, prefs);
      }
    } catch (e) {
      debugPrint("⚠️ Network or timeout error: $e. Falling back to local cache.");
      return _getCachedProfile(userId, prefs);
    }
  }

  UserModel? _getCachedProfile(String userId, SharedPreferences prefs) {
    final cachedString = prefs.getString('cached_user_profile_$userId');

    if (cachedString != null) {
      debugPrint("✅ Loaded profile from local cache.");
      return UserModel.fromJson(jsonDecode(cachedString));
    }

    debugPrint("❌ No cached profile found.");
    return null;
  }

  Future<void> updateProfileData({
    required String userId,
    required double weight,
    required double height,
  }) async {
    try {
      final isOnline = await NetworkHelper.isOnline();

      if (!isOnline) {
        debugPrint("📴 Offline: Cannot update profile to Supabase right now.");
        return;
      }

      await client
          .from(tableName)
          .update({
        'weight': weight,
        'height': height,
      })
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("❌ Failed to update profile data: $e");
    }
  }

  Future<void> updateSleepGoal({
    required String userId,
    required double sleepGoalHours,
  }) async {
    try {
      final isOnline = await NetworkHelper.isOnline();

      if (!isOnline) {
        debugPrint("📴 Offline: Cannot update sleep goal right now.");
        return;
      }

      await client
          .from(tableName)
          .update({
        'sleep_goal_hours': sleepGoalHours,
      })
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("❌ Failed to update sleep goal: $e");
    }
  }

  Future<void> updatePoints(String userId, int newPoints) async {
    try {
      final isOnline = await NetworkHelper.isOnline();

      if (!isOnline) {
        debugPrint("📴 Offline: Cannot update points right now.");
        return;
      }

      await client
          .from(tableName)
          .update({'current_points': newPoints})
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("❌ Failed to update points: $e");
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfileSafe(userId);
  }

  Future<void> updateStreak(String userId, int streak) async {
    try {
      final isOnline = await NetworkHelper.isOnline();

      if (!isOnline) {
        debugPrint('📴 Offline: Cannot update streak right now.');
        return;
      }

      await client
          .from(tableName)
          .update({'streak': streak})
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));

      debugPrint('✅ Profile streak updated: $streak');
    } catch (e) {
      debugPrint('❌ Failed to update streak: $e');
    }
  }
}
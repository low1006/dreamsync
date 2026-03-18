import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository<UserModel> {
  UserRepository({SupabaseClient? client})
      : super(client ?? Supabase.instance.client, 'profile', 'user_id', (json) => UserModel.fromJson(json));

  Future<void> createUser(UserModel user) async {
    if (user.sleepGoalHours <= 0) {
      user.sleepGoalHours = 8.0;
    }
    await create(user.toJson());
    await _cacheProfile(user);
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
        final user = await getById(userId).timeout(const Duration(seconds: 5));
        if (user != null) await _cacheProfile(user);
        return user;
      } else {
        return _getCachedProfile(userId, prefs);
      }
    } catch (e) {
      return _getCachedProfile(userId, prefs);
    }
  }

  UserModel? _getCachedProfile(String userId, SharedPreferences prefs) {
    final cachedString = prefs.getString('cached_user_profile_$userId');
    if (cachedString != null) return UserModel.fromJson(jsonDecode(cachedString));
    return null;
  }

  Future<void> _cacheProfile(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_profile_${user.userId}', jsonEncode(user.toJson()));
  }

  Future<UserModel?> getCachedProfileOnly(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _getCachedProfile(userId, prefs);
  }

  Future<void> updateProfileData({required String userId, required double weight, required double height}) async {
    try {
      UserModel? current = await getCachedProfileOnly(userId);
      current ??= await getProfileSafe(userId);
      if (current == null) return;

      current.weight = weight;
      current.height = height;

      if (await NetworkHelper.isOnline()) {
        await client.from(tableName).update({'weight': weight, 'height': height}).eq('user_id', userId).timeout(const Duration(seconds: 5));
      }
      await _cacheProfile(current);
    } catch (e) {
      debugPrint("❌ Failed to update profile data: $e");
    }
  }

  Future<void> updateSleepGoal({required String userId, required double sleepGoalHours}) async {
    try {
      UserModel? current = await getCachedProfileOnly(userId);
      current ??= await getProfileSafe(userId);
      if (current == null) return;

      current.sleepGoalHours = sleepGoalHours;

      if (await NetworkHelper.isOnline()) {
        await client.from(tableName).update({'sleep_goal_hours': sleepGoalHours}).eq('user_id', userId).timeout(const Duration(seconds: 5));
      }
      await _cacheProfile(current);
    } catch (e) {
      debugPrint("❌ Failed to update sleep goal: $e");
    }
  }

  Future<void> updatePoints(String userId, int newPoints) async {
    try {
      if (!await NetworkHelper.isOnline()) return;
      await client.from(tableName).update({'current_points': newPoints}).eq('user_id', userId).timeout(const Duration(seconds: 5));
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
      if (!await NetworkHelper.isOnline()) return;
      await client.from(tableName).update({'streak': streak}).eq('user_id', userId).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('❌ Failed to update streak: $e');
    }
  }
}
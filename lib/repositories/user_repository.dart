import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamsync/models/user_model.dart';
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

  // 🔥 NEW: Safe profile fetching with strict timeouts and local caching
  Future<UserModel?> getProfileSafe(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // 2-second strict timeout for connectivity check
      final result = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2));
      bool isOnline = result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;

      if (isOnline) {
        debugPrint("🌐 Online: Fetching profile from Supabase...");
        // 5-second strict timeout for Supabase fetch to prevent UI hanging
        final user = await getById(userId).timeout(const Duration(seconds: 5));

        if (user != null) {
          // Cache it locally so it's ready for the next offline session
          await prefs.setString('cached_user_profile_$userId', jsonEncode(user.toJson()));
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

  // Helper method to read the cached user profile
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
    required double sleepGoalHours,
  }) async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2));
      if (result == ConnectivityResult.none) {
        debugPrint("📴 Offline: Cannot update profile to Supabase right now.");
        return;
      }

      await client.from(tableName).update({
        'weight': weight,
        'height': height,
        'sleep_goal_hours': sleepGoalHours,
      }).eq('user_id', userId).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("❌ Failed to update profile data: $e");
    }
  }

  Future<void> updatePoints(String userId, int newPoints) async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2));
      if (result == ConnectivityResult.none) return;

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
    return getProfileSafe(userId); // Now uses the safe offline fetch
  }
}
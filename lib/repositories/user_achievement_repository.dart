import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/util/local_database.dart';
import 'base_repository.dart';

class UserAchievementRepository extends BaseRepository<UserAchievementModel> {
  UserAchievementRepository(SupabaseClient client)
      : super(
    client,
    'user_achievement',
    'user_achievement_id',
        (json) => UserAchievementModel.fromJson(json),
  );

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2));
      return result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;
    } catch (_) {
      return false;
    }
  }

  Future<List<UserAchievementModel>> fetchUserAchievements(String userID) async {
    if (await _isOnline()) {
      try {
        final data = await client.from('user_achievement').select('*, achievement(*)').eq('user_id', userID);

        // Cache basic data to local database
        for (var json in data) {
          final localData = Map<String, dynamic>.from(json);
          localData['id'] = localData['user_achievement_id'];
          localData.remove('achievement'); // Nested objects crash SQLite, remove before caching
          await LocalDatabase.instance.insertRecord('user_achievement', localData, isSynced: true);
        }

        return data.map((json) => UserAchievementModel.fromJson(json)).toList();
      } catch (e) {
        debugPrint("❌ Error fetching user achievement online: $e");
        return _getOfflineAchievements(userID);
      }
    } else {
      debugPrint("📴 Offline: Loading user achievements from cache.");
      return _getOfflineAchievements(userID);
    }
  }

  Future<List<UserAchievementModel>> _getOfflineAchievements(String userId) async {
    try {
      final localRecords = await LocalDatabase.instance.getAllByUser('user_achievement', userId);
      return localRecords.map((json) {
        final map = Map<String, dynamic>.from(json);
        map['user_achievement_id'] = map['id'];

        // Return without the joined 'achievement(*)' data.
        // This prevents breaking, but nested fields will be null offline.
        return UserAchievementModel.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint("❌ Error loading offline achievements: $e");
      return [];
    }
  }

  // Method to sync offline unlocked achievements to cloud
  Future<void> syncOfflineData() async {
    final unsynced = await LocalDatabase.instance.getUnsyncedRecords('user_achievement');
    for (var record in unsynced) {
      try {
        final supabaseData = Map<String, dynamic>.from(record)..remove('is_synced')..remove('id');
        await client.from('user_achievement').update(supabaseData).eq('user_achievement_id', record['id']);
        await LocalDatabase.instance.markAsSynced('user_achievement', record['id']);
      } catch (e) {
        debugPrint("❌ Failed to sync achievement: $e");
      }
    }
  }
}
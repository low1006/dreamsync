import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'base_repository.dart';

class UserRepository extends BaseRepository<UserModel> {
  UserRepository({SupabaseClient? client})
      : super(
    client ?? Supabase.instance.client,
    'profile',
    'user_id',
        (json) => UserModel.fromJson(json),
  );

  String _cacheKey(String userId) => 'cached_profile_$userId';

  Future<Database> get _db async => LocalDatabase.instance.database;

  Future<void> _cacheProfile(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(user.userId), jsonEncode(user.toJson()));

      final db = await _db;
      await db.insert(
        'profile',
        {
          'user_id': user.userId,
          'username': user.username,
          'email': user.email,
          'gender': user.gender,
          'date_birth': user.dateBirth,
          'weight': user.weight,
          'height': user.height,
          'uid_text': user.uidText,
          'current_points': user.currentPoints,
          'sleep_goal_hours': user.sleepGoalHours,
          'streak': user.streak,
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to cache profile: $e');
    }
  }

  Future<UserModel?> _getCachedProfile(String userId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'profile',
        where: 'user_id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return UserModel.fromJson(Map<String, dynamic>.from(rows.first));
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(userId));
      if (raw == null || raw.isEmpty) return null;

      final user = UserModel.fromJson(jsonDecode(raw));

      await db.insert(
        'profile',
        {
          'user_id': user.userId,
          'username': user.username,
          'email': user.email,
          'gender': user.gender,
          'date_birth': user.dateBirth,
          'weight': user.weight,
          'height': user.height,
          'uid_text': user.uidText,
          'current_points': user.currentPoints,
          'sleep_goal_hours': user.sleepGoalHours,
          'streak': user.streak,
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return user;
    } catch (e) {
      debugPrint('⚠️ Failed to read cached profile: $e');
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    if (user.sleepGoalHours <= 0) {
      user.sleepGoalHours = 8.0;
    }

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      throw Exception('Cannot create a new cloud profile while offline.');
    }

    await create(user.toJson());
    await _cacheProfile(user);
  }

  Future<void> deleteAccount() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final online = await NetworkHelper.hasInternet();
      if (online) {
        await client.rpc('delete_user_account');
      }
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
    final online = await NetworkHelper.hasInternet();

    if (!online) {
      final cached = await _getCachedProfile(userId);
      if (cached != null) {
        debugPrint('⚠️ Offline mode: using cached profile.');
        return cached;
      }
      debugPrint('⚠️ Offline mode: no cached profile found.');
      return null;
    }

    try {
      final profile = await getById(userId);
      if (profile != null) {
        await _cacheProfile(profile);
      }
      return profile;
    } catch (e) {
      debugPrint("❌ Failed to get profile from cloud: $e");
      final cached = await _getCachedProfile(userId);
      return cached;
    }
  }

  Future<UserModel?> getCurrentUser() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfileSafe(userId);
  }

  Future<void> updateProfileData({
    required String userId,
    required double weight,
    required double height,
  }) async {
    final current = await _getCachedProfile(userId);
    if (current != null) {
      current.weight = weight;
      current.height = height;
      await _cacheProfile(current);
    }

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: profile update cached locally only.');
      return;
    }

    try {
      await client
          .from(tableName)
          .update({'weight': weight, 'height': height})
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("❌ Failed to update profile data: $e");
      rethrow;
    }
  }

  Future<void> updateSleepGoal({
    required String userId,
    required double sleepGoalHours,
  }) async {
    final current = await _getCachedProfile(userId);
    if (current != null) {
      current.sleepGoalHours = sleepGoalHours;
      await _cacheProfile(current);
    }

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: sleep goal update cached locally only.');
      return;
    }

    try {
      await client
          .from(tableName)
          .update({'sleep_goal_hours': sleepGoalHours})
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("❌ Failed to update sleep goal: $e");
      rethrow;
    }
  }

  Future<void> updatePoints(String userId, int newPoints) async {
    final current = await _getCachedProfile(userId);
    if (current != null) {
      current.currentPoints = newPoints;
      await _cacheProfile(current);
    }

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: points update cached locally only.');
      return;
    }

    try {
      await client
          .from(tableName)
          .update({'current_points': newPoints})
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("❌ Failed to update points: $e");
      rethrow;
    }
  }

  Future<void> updateStreak(String userId, int streak) async {
    final current = await _getCachedProfile(userId);
    if (current != null) {
      final updated = UserModel(
        userId: current.userId,
        username: current.username,
        email: current.email,
        gender: current.gender,
        dateBirth: current.dateBirth,
        weight: current.weight,
        height: current.height,
        uidText: current.uidText,
        currentPoints: current.currentPoints,
        sleepGoalHours: current.sleepGoalHours,
        streak: streak,
      );
      await _cacheProfile(updated);
    }

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: streak update cached locally only.');
      return;
    }

    try {
      await client
          .from(tableName)
          .update({'streak': streak})
          .eq('user_id', userId)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('❌ Failed to update streak: $e');
      rethrow;
    }
  }
}
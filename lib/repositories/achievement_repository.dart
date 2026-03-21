import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dreamsync/models/achievement_model.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/repositories/user_achievement_repository.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';

class AchievementRepository {
  final SupabaseClient _client = Supabase.instance.client;
  late final UserAchievementRepository _userAchievementRepository =
  UserAchievementRepository(_client);

  Future<Database> get _db async => LocalDatabase.instance.database;

  Future<void> resetDailyAchievementsIfNeeded(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastResetStr = prefs.getString('last_daily_reset_$userId');

    if (lastResetStr == todayStr) return;

    try {
      final db = await _db;

      final dailyRows = await db.query(
        'achievement',
        columns: ['achievement_id'],
        where: 'category = ?',
        whereArgs: ['Daily'],
      );

      final dailyIds = dailyRows
          .map((e) => e['achievement_id']?.toString())
          .whereType<String>()
          .toList();

      if (dailyIds.isEmpty) {
        final online = await NetworkHelper.hasInternet();
        if (online) {
          await refreshAchievementDefinitionsFromCloud();
        }

        final refreshed = await db.query(
          'achievement',
          columns: ['achievement_id'],
          where: 'category = ?',
          whereArgs: ['Daily'],
        );

        dailyIds.addAll(
          refreshed
              .map((e) => e['achievement_id']?.toString())
              .whereType<String>(),
        );
      }

      if (dailyIds.isEmpty) return;

      final batch = db.batch();
      for (final achievementId in dailyIds) {
        batch.update(
          'user_achievement',
          {
            'current_progress': 0,
            'is_unlocked': 0,
            'is_claimed': 0,
            'date_claimed': null,
            'is_synced': 0,
          },
          where: 'user_id = ? AND achievement_id = ?',
          whereArgs: [userId, achievementId],
        );
      }
      await batch.commit(noResult: true);

      final online = await NetworkHelper.hasInternet();
      if (online) {
        await _userAchievementRepository.syncPendingForUser(userId);
      }

      await prefs.setString('last_daily_reset_$userId', todayStr);
      debugPrint('✅ Daily achievements reset for $todayStr');
    } catch (e) {
      debugPrint('❌ Failed to reset daily achievements: $e');
      rethrow;
    }
  }

  Future<void> claimAchievement(String userAchievementId) async {
    await _userAchievementRepository.markAsClaimed(userAchievementId);
  }

  Future<List<UserAchievementModel>> fetchAchievements(String userId) async {
    try {
      final online = await NetworkHelper.hasInternet();
      if (online) {
        await refreshAchievementDefinitionsFromCloud();
        await _userAchievementRepository.restoreFromCloud(userId);
      }

      final db = await _db;

      final menuResponse = await db.query('achievement');
      final List<AchievementModel> allAchievements = menuResponse
          .map((e) => AchievementModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (allAchievements.isEmpty) return [];

      final existingProgress =
      await _userAchievementRepository.getByUserId(userId);

      final List<UserAchievementModel> combinedList = [];

      for (final achievement in allAchievements) {
        final userEntry = existingProgress
            .where((u) => u.achievementId == achievement.achievementID)
            .cast<UserAchievementModel?>()
            .firstWhere((e) => e != null, orElse: () => null);

        combinedList.add(userEntry ?? _createGhostEntry(userId, achievement));
      }

      return combinedList;
    } catch (e) {
      debugPrint('❌ fetchAchievements error: $e');
      rethrow;
    }
  }

  Future<UserAchievementModel> persistProgress(
      UserAchievementModel current,
      double newProgress,
      bool shouldUnlock,
      ) async {
    final isGhost = current.userAchievementId.startsWith('temp_');

    if (isGhost) {
      return await _userAchievementRepository.createUserAchievement(
        userId: current.userId,
        achievementId: current.achievementId,
        currentProgress: newProgress.toInt(),
        isUnlocked: shouldUnlock,
        isClaimed: false,
      );
    } else {
      await _userAchievementRepository.updateProgress(
        userAchievementId: current.userAchievementId,
        currentProgress: newProgress.toInt(),
        isUnlocked: shouldUnlock,
      );

      return UserAchievementModel(
        userAchievementId: current.userAchievementId,
        userId: current.userId,
        achievementId: current.achievementId,
        currentProgress: newProgress,
        isUnlocked: shouldUnlock,
        isClaimed: current.isClaimed,
        dateClaim: current.dateClaim,
        achievement: current.achievement,
      );
    }
  }

  Future<void> refreshAchievementDefinitionsFromCloud() async {
    final online = await NetworkHelper.hasInternet();
    if (!online) return;

    try {
      final response = await _client.from('achievement').select();

      final db = await _db;
      final batch = db.batch();

      for (final row in (response as List)) {
        batch.insert(
          'achievement',
          {
            'achievement_id': row['achievement_id']?.toString(),
            'title': row['title'],
            'description': row['description'],
            'criteria_type': row['criteria_type'],
            'criteria_value': row['criteria_value'],
            'category': row['category'],
            'xp_reward': row['xp_reward'] ?? 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      debugPrint('✅ Achievement definitions refreshed from cloud');
    } catch (e) {
      debugPrint('⚠️ Failed to refresh achievement definitions: $e');
    }
  }

  UserAchievementModel _createGhostEntry(
      String userId,
      AchievementModel achievement,
      ) {
    return UserAchievementModel(
      userAchievementId: 'temp_${achievement.achievementID}',
      userId: userId,
      achievementId: achievement.achievementID,
      currentProgress: 0.0,
      isUnlocked: false,
      isClaimed: false,
      achievement: achievement,
    );
  }
}
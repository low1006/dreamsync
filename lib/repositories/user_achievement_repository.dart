import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'base_repository.dart';

class UserAchievementRepository extends BaseRepository<UserAchievementModel> {
  UserAchievementRepository(SupabaseClient client)
      : super(
    client,
    'user_achievement',
    'user_achievement_id',
        (json) => UserAchievementModel.fromJson(json),
  );

  Future<Database> get _db async => LocalDatabase.instance.database;

  Future<List<UserAchievementModel>> getByUserId(String userId) async {
    final db = await _db;

    final localRows = await db.rawQuery('''
      SELECT ua.*, 
             a.achievement_id AS a_achievement_id,
             a.title AS a_title,
             a.description AS a_description,
             a.criteria_type AS a_criteria_type,
             a.criteria_value AS a_criteria_value,
             a.category AS a_category,
             a.xp_reward AS a_xp_reward
      FROM user_achievement ua
      LEFT JOIN achievement a
        ON ua.achievement_id = a.achievement_id
      WHERE ua.user_id = ?
    ''', [userId]);

    return localRows.map((row) {
      final mapped = Map<String, dynamic>.from(row);

      final achievementExists = mapped['a_achievement_id'] != null;
      if (achievementExists) {
        mapped['achievement'] = {
          'achievement_id': mapped['a_achievement_id'],
          'title': mapped['a_title'],
          'description': mapped['a_description'],
          'criteria_type': mapped['a_criteria_type'],
          'criteria_value': mapped['a_criteria_value'],
          'category': mapped['a_category'],
          'xp_reward': mapped['a_xp_reward'],
        };
      }

      mapped['current_progress'] = mapped['current_progress'];
      mapped['date_claim'] = mapped['date_claimed'];

      return UserAchievementModel.fromJson(mapped);
    }).toList();
  }

  Future<UserAchievementModel> createUserAchievement({
    required String userId,
    required dynamic achievementId,
    required int currentProgress,
    required bool isUnlocked,
    bool isClaimed = false,
  }) async {
    final achievementIdStr = achievementId.toString();
    final localId = '${userId}_$achievementIdStr';

    final db = await _db;
    await db.insert(
      'user_achievement',
      {
        'user_achievement_id': localId,
        'user_id': userId,
        'achievement_id': achievementIdStr,
        'current_progress': currentProgress,
        'is_unlocked': isUnlocked ? 1 : 0,
        'is_claimed': isClaimed ? 1 : 0,
        'date_claimed': null,
        'is_synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final online = await NetworkHelper.hasInternet();
    if (online) {
      await syncPendingForUser(userId);
    }

    final rows = await getByUserId(userId);
    return rows.firstWhere((e) => e.userAchievementId == localId);
  }

  Future<void> updateProgress({
    required String userAchievementId,
    required int currentProgress,
    required bool isUnlocked,
  }) async {
    final db = await _db;

    await db.update(
      'user_achievement',
      {
        'current_progress': currentProgress,
        'is_unlocked': isUnlocked ? 1 : 0,
        'is_synced': 0,
      },
      where: 'user_achievement_id = ?',
      whereArgs: [userAchievementId],
    );

    final row = await db.query(
      'user_achievement',
      where: 'user_achievement_id = ?',
      whereArgs: [userAchievementId],
      limit: 1,
    );

    if (row.isEmpty) return;

    final userId = row.first['user_id']?.toString();
    if (userId == null) return;

    final online = await NetworkHelper.hasInternet();
    if (online) {
      await syncPendingForUser(userId);
    }
  }

  Future<void> markAsClaimed(String userAchievementId) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'user_achievement',
      {
        'is_claimed': 1,
        'date_claimed': now,
        'is_synced': 0,
      },
      where: 'user_achievement_id = ?',
      whereArgs: [userAchievementId],
    );

    final row = await db.query(
      'user_achievement',
      where: 'user_achievement_id = ?',
      whereArgs: [userAchievementId],
      limit: 1,
    );

    if (row.isEmpty) return;

    final userId = row.first['user_id']?.toString();
    if (userId == null) return;

    final online = await NetworkHelper.hasInternet();
    if (online) {
      await syncPendingForUser(userId);
    }
  }

  Future<void> syncPendingForUser(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) return;

    final db = await _db;
    final rows = await db.query(
      'user_achievement',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );

    for (final row in rows) {
      try {
        await client.from(tableName).upsert({
          'user_id': row['user_id'],
          'achievement_id': row['achievement_id'],
          'current_progress': row['current_progress'],
          'is_unlocked': (row['is_unlocked'] ?? 0) == 1,
          'is_claimed': (row['is_claimed'] ?? 0) == 1,
          'date_claimed': row['date_claimed'],
        }, onConflict: 'user_id,achievement_id');

        await db.update(
          'user_achievement',
          {'is_synced': 1},
          where: 'user_achievement_id = ?',
          whereArgs: [row['user_achievement_id']],
        );
      } catch (e) {
        debugPrint('⚠️ Failed syncing user achievement ${row['user_achievement_id']}: $e');
      }
    }
  }

  Future<void> restoreFromCloud(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) return;

    try {
      final data = await client
          .from(tableName)
          .select('*, achievement(*)')
          .eq('user_id', userId);

      final db = await _db;
      final batch = db.batch();

      for (final raw in (data as List)) {
        final row = Map<String, dynamic>.from(raw);
        final achievement = row['achievement'];

        if (achievement is Map<String, dynamic>) {
          batch.insert(
            'achievement',
            {
              'achievement_id': achievement['achievement_id']?.toString(),
              'title': achievement['title'],
              'description': achievement['description'],
              'criteria_type': achievement['criteria_type'],
              'criteria_value': achievement['criteria_value'],
              'category': achievement['category'],
              'xp_reward': achievement['xp_reward'] ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        batch.insert(
          'user_achievement',
          {
            'user_achievement_id':
            '${row['user_id']}_${row['achievement_id']}',
            'user_id': row['user_id'],
            'achievement_id': row['achievement_id']?.toString(),
            'current_progress': row['current_progress'] ?? 0,
            'is_unlocked': (row['is_unlocked'] == true) ? 1 : 0,
            'is_claimed': (row['is_claimed'] == true) ? 1 : 0,
            'date_claimed': row['date_claimed'],
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('⚠️ Failed restoring user achievements: $e');
    }
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/models/achievement_model.dart';
import 'package:dreamsync/repositories/user_achievement_repository.dart';

class AchievementRepository {
  final SupabaseClient _client = Supabase.instance.client;
  late final UserAchievementRepository _userAchievementRepository =
  UserAchievementRepository(_client);

  // ─────────────────────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────────────────────
  Future<List<UserAchievementModel>> fetchAchievements(String userId) async {
    try {
      if (await NetworkHelper.isOnline()) {
        final menuResponse = await _client.from('achievement').select();
        if (menuResponse.isEmpty) return [];

        final List<AchievementModel> allAchievements = (menuResponse as List)
            .map((e) => AchievementModel.fromJson(e))
            .toList();

        for (final rawRow in menuResponse) {
          await _cacheDefinitionLocally(Map<String, dynamic>.from(rawRow));
        }

        final existingProgress =
        await _userAchievementRepository.getByUserId(userId);

        for (final ua in existingProgress) {
          await _cacheAchievementLocally(ua);
        }

        final List<UserAchievementModel> combinedList = [];
        for (final achievement in allAchievements) {
          final userEntry = existingProgress
              .where((u) => u.achievementId == achievement.achievementID)
              .firstOrNull;

          combinedList.add(
            userEntry ?? _createGhostEntry(userId, achievement),
          );
        }

        return combinedList;
      } else {
        debugPrint("📴 Offline: Loading achievements from SQLite...");
        return await _loadCachedAchievements(userId);
      }
    } catch (e) {
      debugPrint("❌ fetchAchievements error: $e");
      return await _loadCachedAchievements(userId);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PERSIST
  // ─────────────────────────────────────────────────────────────
  Future<UserAchievementModel> persistProgress(
      UserAchievementModel current,
      double newProgress,
      bool shouldUnlock,
      ) async {
    final isGhost = current.userAchievementId.startsWith('temp_');
    final optimisticModel =
    _getOptimisticModel(current, newProgress, shouldUnlock);

    if (await NetworkHelper.isOnline()) {
      try {
        if (isGhost) {
          final realModel =
          await _userAchievementRepository.createUserAchievement(
            userId: current.userId,
            achievementId:
            int.tryParse(current.achievementId) ?? current.achievementId,
            currentProgress: newProgress.toInt(),
            isUnlocked: shouldUnlock,
            isClaimed: false,
          );

          await _cacheAchievementLocally(realModel);
          return realModel;
        } else {
          await _userAchievementRepository.updateProgress(
            userAchievementId: current.userAchievementId,
            currentProgress: newProgress.toInt(),
            isUnlocked: shouldUnlock,
          );

          await _updateCachedAchievement(
            current.userAchievementId,
            newProgress,
            shouldUnlock,
          );

          return optimisticModel;
        }
      } catch (e) {
        debugPrint("❌ persistProgress error: $e");
        await _queueLocalAchievement(current, newProgress, shouldUnlock);
        return optimisticModel;
      }
    } else {
      debugPrint("📴 Offline: Queuing achievement progress...");
      await _queueLocalAchievement(current, newProgress, shouldUnlock);
      return optimisticModel;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SYNC
  // ─────────────────────────────────────────────────────────────
  Future<void> syncOfflineAchievements() async {
    if (!await NetworkHelper.isOnline()) return;

    final unsynced =
    await LocalDatabase.instance.getUnsyncedRecords('user_achievement');

    for (final row in unsynced) {
      try {
        final id = row['id']?.toString() ?? '';
        final isGhost = id.startsWith('temp_');
        final currentProgress = (row['progress'] as num?)?.toInt() ?? 0;
        final isUnlocked = row['is_unlocked'] == 1;

        if (isGhost) {
          await _userAchievementRepository.createUserAchievement(
            userId: row['user_id']?.toString() ?? '',
            achievementId:
            int.tryParse(row['achievement_id']?.toString() ?? '') ??
                row['achievement_id'],
            currentProgress: currentProgress,
            isUnlocked: isUnlocked,
            isClaimed: false,
          );
        } else {
          await _userAchievementRepository.updateProgress(
            userAchievementId: id,
            currentProgress: currentProgress,
            isUnlocked: isUnlocked,
          );
        }

        await LocalDatabase.instance.markAsSynced('user_achievement', id);
      } catch (e) {
        debugPrint("❌ Failed to sync achievement row: $e");
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────
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

  UserAchievementModel _getOptimisticModel(
      UserAchievementModel current,
      double newProgress,
      bool shouldUnlock,
      ) {
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

  Future<void> _cacheAchievementLocally(UserAchievementModel ua) async {
    await LocalDatabase.instance.insertRecord(
      'user_achievement',
      {
        'id': ua.userAchievementId,
        'user_id': ua.userId,
        'achievement_id': ua.achievementId,
        'progress': ua.currentProgress,
        'is_unlocked': ua.isUnlocked ? 1 : 0,
      },
      isSynced: true,
    );
  }

  Future<void> _cacheDefinitionLocally(Map<String, dynamic> raw) async {
    final id = raw['achievement_id']?.toString() ?? '';
    if (id.isEmpty) return;

    final db = await LocalDatabase.instance.database;
    await db.insert(
      'achievement_definition',
      {
        'id': id,
        'title': raw['title']?.toString() ?? '',
        'description': raw['description']?.toString() ?? '',
        'criteria_type': raw['criteria_type']?.toString() ?? '',
        'criteria_value': (raw['criteria_value'] as num?)?.toDouble() ?? 0.0,
        'category': raw['category']?.toString() ?? '',
        'xp_reward': (raw['xp_reward'] as num?)?.toInt() ?? 0,
        'icon_path': raw['icon_path']?.toString() ?? '',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _updateCachedAchievement(
      String id,
      double progress,
      bool isUnlocked,
      ) async {
    final db = await LocalDatabase.instance.database;
    await db.update(
      'user_achievement',
      {
        'progress': progress,
        'is_unlocked': isUnlocked ? 1 : 0,
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _queueLocalAchievement(
      UserAchievementModel current,
      double progress,
      bool isUnlocked,
      ) async {
    await LocalDatabase.instance.insertRecord(
      'user_achievement',
      {
        'id': current.userAchievementId,
        'user_id': current.userId,
        'achievement_id': current.achievementId,
        'progress': progress,
        'is_unlocked': isUnlocked ? 1 : 0,
      },
      isSynced: false,
    );
  }

  Future<List<UserAchievementModel>> _loadCachedAchievements(
      String userId,
      ) async {
    try {
      final db = await LocalDatabase.instance.database;
      final defRows = await db.query('achievement_definition');
      if (defRows.isEmpty) return [];

      final definitions = {
        for (final row in defRows)
          row['id'].toString(): AchievementModel.fromJson({
            'achievement_id': row['id'],
            'title': row['title'],
            'description': row['description'],
            'criteria_type': row['criteria_type'],
            'criteria_value': row['criteria_value'],
            'category': row['category'],
            'xp_reward': row['xp_reward'],
            'icon_path': row['icon_path'],
          }),
      };

      final progressRows =
      await LocalDatabase.instance.getAllByUser('user_achievement', userId);

      final progressMap = {
        for (final row in progressRows) row['achievement_id'].toString(): row,
      };

      return definitions.entries.map((entry) {
        final defId = entry.key;
        final achievement = entry.value;
        final progressRow = progressMap[defId];

        if (progressRow != null) {
          return UserAchievementModel(
            userAchievementId: progressRow['id']?.toString() ?? 'temp_$defId',
            userId: userId,
            achievementId: defId,
            currentProgress:
            (progressRow['progress'] as num?)?.toDouble() ?? 0.0,
            isUnlocked: progressRow['is_unlocked'] == 1,
            isClaimed: false,
            achievement: achievement,
          );
        } else {
          return _createGhostEntry(userId, achievement);
        }
      }).toList();
    } catch (e) {
      debugPrint("❌ _loadCachedAchievements error: $e");
      return [];
    }
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_achievement_model.dart';
import '../models/achievement_model.dart';
import '../repositories/user_achievement_repository.dart';

class AchievementViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  late final UserAchievementRepository _userAchievementRepo =
  UserAchievementRepository(_client);

  List<UserAchievementModel> userAchievements = [];
  bool isLoading = false;

  // ─────────────────────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────────────────────
  Future<void> fetchUserAchievements(String userId) async {
    debugPrint("🚀 Fetching achievements for $userId...");
    isLoading = true;
    notifyListeners();

    try {
      final menuResponse = await _client.from('achievement').select();

      if (menuResponse.isEmpty) {
        debugPrint("⚠️ achievement table is empty");
        userAchievements = [];
        isLoading = false;
        notifyListeners();
        return;
      }

      final List<AchievementModel> allAchievements = (menuResponse as List)
          .map((e) => AchievementModel.fromJson(e))
          .toList();

      final userResponse = await _client
          .from('user_achievement')
          .select('*, achievement(*)')
          .eq('user_id', userId);

      final List<UserAchievementModel> existingProgress =
      (userResponse as List)
          .map((e) => UserAchievementModel.fromJson(e))
          .toList();

      final List<UserAchievementModel> combinedList = [];

      for (final achievement in allAchievements) {
        final userEntry = existingProgress
            .where((u) => u.achievementId == achievement.achievementID)
            .firstOrNull;

        if (userEntry != null) {
          combinedList.add(userEntry);
        } else {
          combinedList.add(_createGhostEntry(userId, achievement));
        }
      }

      userAchievements = combinedList;
    } catch (e) {
      debugPrint("❌ fetchUserAchievements error: $e");
    }

    isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // GHOST ENTRY
  // ─────────────────────────────────────────────────────────────
  UserAchievementModel _createGhostEntry(
      String userId, AchievementModel achievement) {
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

  // ─────────────────────────────────────────────────────────────
  // HELPER
  // ─────────────────────────────────────────────────────────────
  List<UserAchievementModel> getByType(String criteriaType) {
    return userAchievements
        .where((ua) => ua.achievement?.criteriaType == criteriaType)
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // BACKGROUND PROCESSOR
  // Call this from your AlarmService after fetching sleep data to
  // ensure all criteria types run in the background.
  // ─────────────────────────────────────────────────────────────
  Future<void> processDailySleepMetrics({
    required double hoursSlept,
    required double sleepScore,
    required bool wokeUpEarly,
    required bool consistentBedtime,
    required bool noScreenTime,
    required bool isConsecutiveDay,
  }) async {
    // Duration: Nap Snatcher, Hibernator, Sleep Marathon
    for (var ua in getByType('total_hours')) {
      await updateProgress(ua.userAchievementId, hoursSlept);
    }

    // Quality: Good Night, Deep Dreamer, Perfect Rest
    for (var ua in getByType('sleep_score')) {
      await setProgress(ua.userAchievementId, sleepScore);
    }

    // Milestone: Dream Beginner
    for (var ua in getByType('total_logs')) {
      await updateProgress(ua.userAchievementId, 1.0);
    }

    // Streak: Three Peat, Week Warrior, Monthly Master
    for (var ua in getByType('streak_days')) {
      if (isConsecutiveDay) {
        await updateProgress(ua.userAchievementId, 1.0);
      } else {
        await setProgress(ua.userAchievementId, 0.0); // Reset streak
      }
    }

    // Schedule: Early Bird
    for (var ua in getByType('early_wake_streak')) {
      if (wokeUpEarly) await updateProgress(ua.userAchievementId, 1.0);
      else await setProgress(ua.userAchievementId, 0.0);
    }

    // Schedule: On The Dot
    for (var ua in getByType('bedtime_consistency')) {
      if (consistentBedtime) await updateProgress(ua.userAchievementId, 1.0);
    }

    // Habit: Phone Down
    for (var ua in getByType('no_screen_time')) {
      if (noScreenTime) await updateProgress(ua.userAchievementId, 1.0);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE / SET PROGRESS
  // ─────────────────────────────────────────────────────────────
  Future<void> updateProgress(
      String userAchievementId, double amountToAdd) async {
    final index = userAchievements
        .indexWhere((ua) => ua.userAchievementId == userAchievementId);
    if (index == -1) return;

    final current = userAchievements[index];
    if (current.isUnlocked) return;

    final newProgress = current.currentProgress + amountToAdd;
    final target = current.achievement?.criteriaValue ?? 100.0;
    final shouldUnlock = newProgress >= target;

    await _persist(index, current, newProgress, shouldUnlock);
  }

  Future<void> setProgress(
      String userAchievementId, double newValue) async {
    final index = userAchievements
        .indexWhere((ua) => ua.userAchievementId == userAchievementId);
    if (index == -1) return;

    final current = userAchievements[index];
    if (current.isUnlocked) return;

    final target = current.achievement?.criteriaValue ?? 100.0;
    final shouldUnlock = newValue >= target;

    await _persist(index, current, newValue, shouldUnlock);
  }

  // ─────────────────────────────────────────────────────────────
  // PERSIST
  // ─────────────────────────────────────────────────────────────
  Future<void> _persist(
      int index,
      UserAchievementModel current,
      double newProgress,
      bool shouldUnlock,
      ) async {
    // ✅ FIX 1: Cast double to int using .toInt() to fix the bigint error (22P02)
    final Map<String, dynamic> data = {
      'current_progress': newProgress.toInt(),
      'is_unlocked': shouldUnlock,
    };

    // ✅ FIX 2: Removed 'date_unlocked' to fix the missing column error (PGRST204).
    // Supabase will rely on your model's 'date_claimed' or 'created_at' instead.

    final isGhost = current.userAchievementId.startsWith('temp_');

    try {
      if (isGhost) {
        data['user_id'] = current.userId;
        // ✅ FIX 3: Parse achievementId to int safely in case DB expects a bigint for the Foreign Key
        data['achievement_id'] = int.tryParse(current.achievementId) ?? current.achievementId;
        data['is_claimed'] = false;

        final response = await _client
            .from('user_achievement')
            .insert(data)
            .select('*, achievement(*)')
            .single();

        userAchievements[index] = UserAchievementModel.fromJson(response);
      } else {
        await _userAchievementRepo.update(
            current.userAchievementId, data);

        userAchievements[index] = UserAchievementModel(
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

      if (shouldUnlock) {
        debugPrint(
            "🏆 UNLOCKED: ${current.achievement?.title ?? current.achievementId}");
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ _persist error: $e");
    }
  }
}
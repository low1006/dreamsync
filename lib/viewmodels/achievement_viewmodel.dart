import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/repositories/achievement_repository.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';

class AchievementViewModel extends ChangeNotifier {
  final AchievementRepository _repo = AchievementRepository();

  List<UserAchievementModel> userAchievements = [];
  bool isLoading = false;

  Future<void> fetchUserAchievements(String userId) async {
    debugPrint("🚀 Fetching achievements for $userId...");
    isLoading = true;
    notifyListeners();

    try {
      // ✅ Automatically resets Daily Tasks if a new day has started
      await _repo.resetDailyAchievementsIfNeeded(userId);

      // ✅ Then fetches the fresh list
      userAchievements = await _repo.fetchAchievements(userId);
    } catch (e) {
      debugPrint("❌ fetchUserAchievements error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ✅ New method to handle when a user taps the "Claim" button
  Future<void> claimReward(String userAchievementId, UserViewModel userVM) async {
    final index = userAchievements.indexWhere(
          (ua) => ua.userAchievementId == userAchievementId,
    );
    if (index == -1) return;

    final current = userAchievements[index];

    // Only allow claiming if unlocked and not already claimed
    if (!current.isUnlocked || current.isClaimed) return;

    final xpReward = current.achievement?.xpReward ?? 0.0;
    if (xpReward <= 0) return;

    try {
      // 1. Mark as claimed in Database
      await _repo.claimAchievement(userAchievementId);

      // 2. Add points to the User's Profile
      final currentUser = userVM.userProfile;
      if (currentUser != null) {
        final newPoints = (currentUser.currentPoints ?? 0) + xpReward.toInt();
        await userVM.updatePoints(newPoints);
      }

      // 3. Update the UI locally so the button turns into a checkmark immediately
      userAchievements[index] = UserAchievementModel(
        userAchievementId: current.userAchievementId,
        userId: current.userId,
        achievementId: current.achievementId,
        currentProgress: current.currentProgress,
        isUnlocked: true,
        isClaimed: true,
        dateClaim: DateTime.now(),
        achievement: current.achievement,
      );

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error claiming reward: $e");
    }
  }

  Future<void> syncOfflineAchievements() async {
    try {
      await _repo.syncOfflineAchievements();
    } catch (e) {
      debugPrint("❌ syncOfflineAchievements error: $e");
    }
  }

  List<UserAchievementModel> getByType(String criteriaType) {
    return userAchievements
        .where((ua) => ua.achievement?.criteriaType == criteriaType)
        .toList();
  }

  Future<void> processDailySleepMetrics({
    required double hoursSlept,
    required double sleepScore,
    required bool wokeUpEarly,
    required bool consistentBedtime,
    required bool noScreenTime,
    required bool isConsecutiveDay,
  }) async {

    // --- Permanent Milestones ---
    for (final ua in getByType('sleep_score')) {
      await setProgress(ua.userAchievementId, sleepScore);
    }
    for (final ua in getByType('total_logs')) {
      await updateProgress(ua.userAchievementId, 1.0);
    }
    for (final ua in getByType('streak_days')) {
      if (isConsecutiveDay) {
        await updateProgress(ua.userAchievementId, 1.0);
      } else {
        await setProgress(ua.userAchievementId, 0.0);
      }
    }
    for (final ua in getByType('early_wake_streak')) {
      if (wokeUpEarly) {
        await updateProgress(ua.userAchievementId, 1.0);
      } else {
        await setProgress(ua.userAchievementId, 0.0);
      }
    }
    for (final ua in getByType('bedtime_consistency')) {
      if (consistentBedtime) {
        await updateProgress(ua.userAchievementId, 1.0);
      }
    }
    for (final ua in getByType('no_screen_time')) {
      if (noScreenTime) {
        await updateProgress(ua.userAchievementId, 1.0);
      }
    }

    // --- NEW: Daily Repeatable Tasks ---
    for (final ua in getByType('daily_log')) {
      await updateProgress(ua.userAchievementId, 1.0);
    }
    for (final ua in getByType('daily_sleep_score')) {
      await setProgress(ua.userAchievementId, sleepScore >= 85 ? 85 : 0);
    }
    for (final ua in getByType('daily_wake_on_time')) {
      if (wokeUpEarly) {
        await updateProgress(ua.userAchievementId, 1.0);
      }
    }
    for (final ua in getByType('daily_no_screen')) {
      if (noScreenTime) {
        await updateProgress(ua.userAchievementId, 1.0);
      }
    }
  }

  Future<void> updateProgress(
      String userAchievementId,
      double amountToAdd,
      ) async {
    final index = userAchievements.indexWhere(
          (ua) => ua.userAchievementId == userAchievementId,
    );
    if (index == -1) return;

    final current = userAchievements[index];
    if (current.isUnlocked) return;

    final newProgress = current.currentProgress + amountToAdd;
    final target = current.achievement?.criteriaValue ?? 100.0;
    final shouldUnlock = newProgress >= target;

    await _delegateToRepo(index, current, newProgress, shouldUnlock);
  }

  Future<void> setProgress(
      String userAchievementId,
      double newValue,
      ) async {
    final index = userAchievements.indexWhere(
          (ua) => ua.userAchievementId == userAchievementId,
    );
    if (index == -1) return;

    final current = userAchievements[index];
    final target = current.achievement?.criteriaValue ?? 100.0;
    final shouldUnlock = newValue >= target;

    if (current.currentProgress == newValue &&
        current.isUnlocked == shouldUnlock) {
      return;
    }

    await _delegateToRepo(index, current, newValue, shouldUnlock);
  }

  Future<void> _delegateToRepo(
      int index,
      UserAchievementModel current,
      double newProgress,
      bool shouldUnlock,
      ) async {
    final updatedModel =
    await _repo.persistProgress(current, newProgress, shouldUnlock);

    userAchievements[index] = updatedModel;
    notifyListeners();

    if (shouldUnlock && !current.isUnlocked) {
      debugPrint(
        "🏆 UNLOCKED: ${current.achievement?.title ?? current.achievementId}",
      );
    }
  }
}
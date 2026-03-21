import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/repositories/achievement_repository.dart';
import 'package:dreamsync/repositories/friend_repository.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';

class AchievementViewModel extends ChangeNotifier {
  final AchievementRepository _repo = AchievementRepository();
  final FriendRepository _friendRepo = FriendRepository();

  List<UserAchievementModel> userAchievements = [];
  bool isLoading = false;

  // --- Leaderboard State ---
  List<UserModel> leaderboardUsers = [];

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

  // =========================================================
  // LEADERBOARD
  // =========================================================
  Future<void> loadLeaderboard() async {

    try {
      leaderboardUsers = await _friendRepo.fetchLeaderboard();
      leaderboardUsers.sort((a, b) => b.streak.compareTo(a.streak));
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
    }
  }

  // ✅ New method to handle when a user taps the "Claim" button
  Future<void> claimReward(String userAchievementId, ProfileViewModel userVM) async {
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

  List<UserAchievementModel> getByType(String criteriaType) {
    return userAchievements
        .where((ua) => ua.achievement?.criteriaType == criteriaType)
        .toList();
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
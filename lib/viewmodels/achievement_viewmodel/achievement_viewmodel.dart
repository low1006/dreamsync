import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/models/user_achievement_model.dart';
import 'package:dreamsync/repositories/achievement_repository.dart';
import 'package:dreamsync/repositories/friend_repository.dart';
import 'package:dreamsync/services/sleep_achievement_service.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';

class AchievementViewModel extends ChangeNotifier {
  final AchievementRepository _repo = AchievementRepository();
  final FriendRepository _friendRepo = FriendRepository();
  final SleepAchievementService _achievementService = SleepAchievementService();

  List<UserAchievementModel> userAchievements = [];
  bool isLoading = false;

  // Leaderboard
  List<UserModel> leaderboardUsers = [];

  Future<void> fetchUserAchievements(String userId) async {
    debugPrint("🚀 Fetching achievements for $userId.");
    isLoading = true;
    notifyListeners();

    try {
      await _repo.resetDailyAchievementsIfNeeded(userId);
      userAchievements = await _repo.fetchAchievements(userId);

      // Keep friend-count achievements synced from the same source
      // that powers the friend system / leaderboard.
      await refreshFriendCountAchievements();
    } catch (e) {
      debugPrint("❌ fetchUserAchievements error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLeaderboard() async {
    try {
      leaderboardUsers = await _friendRepo.fetchLeaderboard();
      leaderboardUsers.sort((a, b) => b.streak.compareTo(a.streak));
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error loading leaderboard: $e");
    }
  }

  Future<int> fetchFriendCount() async {
    try {
      final result = await _friendRepo.fetchFriendships();
      final friends = result['friends'] ?? [];
      return friends.length;
    } catch (e) {
      debugPrint("❌ fetchFriendCount error: $e");
      return 0;
    }
  }

  Future<void> refreshFriendCountAchievements() async {
    try {
      final friendCount = await fetchFriendCount();

      await _achievementService.updateFriendAchievements(
        friendCount: friendCount,
        achievementVM: this,
      );

      notifyListeners();
    } catch (e) {
      debugPrint("❌ refreshFriendCountAchievements error: $e");
    }
  }

  Future<void> claimReward(
      String userAchievementId,
      ProfileViewModel userVM,
      ) async {
    final index = userAchievements.indexWhere(
          (ua) => ua.userAchievementId == userAchievementId,
    );
    if (index == -1) return;

    final current = userAchievements[index];

    if (!current.isUnlocked || current.isClaimed) return;

    final xpReward = current.achievement?.xpReward ?? 0.0;
    if (xpReward <= 0) return;

    try {
      await _repo.claimAchievement(userAchievementId);

      final currentUser = userVM.userProfile;
      if (currentUser != null) {
        final newPoints = (currentUser.currentPoints ?? 0) + xpReward.toInt();
        await userVM.updatePoints(newPoints);
      }

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

  Future<void> setProgress(String userAchievementId, double newValue) async {
    final index = userAchievements.indexWhere(
          (ua) => ua.userAchievementId == userAchievementId,
    );
    if (index == -1) return;

    final current = userAchievements[index];
    final achievement = current.achievement;
    if (achievement == null) return;

    final cappedValue = newValue < 0 ? 0.0 : newValue;
    final isUnlockedNow = cappedValue >= achievement.criteriaValue;

    try {
      final updated = await _repo.persistProgress(
        current,
        cappedValue,
        isUnlockedNow,
      );

      userAchievements[index] = UserAchievementModel(
        userAchievementId: updated.userAchievementId,
        userId: updated.userId,
        achievementId: updated.achievementId,
        currentProgress: updated.currentProgress,
        isUnlocked: updated.isUnlocked,
        isClaimed: current.isClaimed,
        dateClaim: current.dateClaim,
        achievement: current.achievement,
      );

      notifyListeners();
    } catch (e) {
      debugPrint("❌ setProgress error: $e");
    }
  }
}
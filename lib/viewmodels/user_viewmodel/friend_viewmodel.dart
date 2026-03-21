import 'package:flutter/material.dart';
import 'package:dreamsync/models/friend_profile_model.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/friend_repository.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';

class FriendViewModel extends ChangeNotifier {
  final FriendRepository _repo = FriendRepository();

  // --- Friend List State ---
  List<FriendProfile> friends = [];
  List<FriendProfile> pendingRequests = [];
  bool isLoading = false;
  String? errorMessage;

  // --- Search State ---
  UserModel? searchedUser;
  String? friendshipStatus;

  // --- Badge State ---
  int pendingRequestCount = 0;

  // =========================================================
  // PENDING REQUEST COUNT (for red dot badge)
  // =========================================================
  Future<void> loadPendingRequestCount() async {
    try {
      pendingRequestCount = await _repo.fetchPendingRequestCount();
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Failed to load pending request count: $e");
    }
  }

  // =========================================================
  // LOAD FRIENDS & PENDING REQUESTS
  // =========================================================
  Future<void> loadFriendListData() async {
    isLoading = true;
    notifyListeners();

    try {
      final result = await _repo.fetchFriendships();
      friends = result['friends'] ?? [];
      pendingRequests = result['pending'] ?? [];
    } catch (e) {
      debugPrint("LOAD ERROR: $e");
      errorMessage = 'Error loading friends';
    }

    isLoading = false;
    notifyListeners();
  }

  // =========================================================
  // SEARCH USER
  // =========================================================
  Future<bool> searchUserByUid(String uid) async {
    isLoading = true;
    errorMessage = null;
    searchedUser = null;
    notifyListeners();

    try {
      searchedUser = await _repo.searchByUid(uid);

      if (searchedUser == null) {
        errorMessage = "User not found. Check the UID and try again.";
        isLoading = false;
        notifyListeners();
        return false;
      }

      final myId = _repo.currentUserId;
      if (searchedUser!.userId == myId) {
        errorMessage = "You cannot add yourself as a friend.";
        isLoading = false;
        notifyListeners();
        return false;
      }

      friendshipStatus = await _repo.checkFriendshipStatus(searchedUser!.userId);

      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("SEARCH ERROR: $e");
      errorMessage = "Connection error. Please try again.";
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // =========================================================
  // SEND FRIEND REQUEST
  // =========================================================
  Future<void> sendFriendRequestToSearchedUser() async {
    if (searchedUser == null) return;

    try {
      await _repo.sendFriendRequest(searchedUser!.userId);
      friendshipStatus = 'pending';
      notifyListeners();
      loadFriendListData();
    } catch (e) {
      errorMessage = 'Could not send request.';
      notifyListeners();
    }
  }

  // =========================================================
  // ACCEPT FRIEND REQUEST
  // =========================================================
  Future<void> acceptRequest(
      String senderId,
      AchievementViewModel achievementVM,
      ) async {

    try {
      await _repo.acceptFriendRequest(senderId);
      await loadFriendListData();
      await _checkFriendAchievements(achievementVM);
    } catch (e) {
      errorMessage = 'Failed to accept request.';
      notifyListeners();
    }
  }

  // =========================================================
  // PRIVATE
  // =========================================================
  Future<void> _checkFriendAchievements(
      AchievementViewModel achievementVM) async {
    final count = friends.length.toDouble();
    for (final a in achievementVM.getByType('friends_count')) {
      await achievementVM.setProgress(a.userAchievementId, count);
    }
  }
}
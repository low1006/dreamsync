import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

class FriendViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;

  // --- Friend List State ---
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> pendingRequests = [];
  bool isLoading = false;
  String? errorMessage;

  // Search state
  UserModel? searchedUser;
  String? friendshipStatus; // 'none', 'pending', 'accepted'

  // --- Leaderboard State ---
  List<UserModel> leaderboardUsers = [];

  // =========================================================
  // 1. LOAD FRIENDS
  // =========================================================
  Future<void> loadFriendListData() async {
    isLoading = true;
    notifyListeners();

    final myId = _client.auth.currentUser!.id;

    try {
      final response = await _client.from('friendships').select('''
            *,
            sender:profile!sender_id(username, email, uid_text, sleep_goal_hours, streak),
            receiver:profile!receiver_id(username, email, uid_text, sleep_goal_hours, streak)
          ''').or('sender_id.eq.$myId,receiver_id.eq.$myId');

      final data = List<Map<String, dynamic>>.from(response);

      friends.clear();
      pendingRequests.clear();

      for (var item in data) {
        if (item['sender'] == null || item['receiver'] == null) continue;

        if (item['status'] == 'accepted') {
          final isMeSender = item['sender_id'] == myId;
          final friendProfile =
          isMeSender ? item['receiver'] : item['sender'];
          friendProfile['friendship_id'] = item['id'];
          friends.add(friendProfile);
        } else if (item['status'] == 'pending' &&
            item['receiver_id'] == myId) {
          final senderProfile = item['sender'];
          if (senderProfile != null) {
            senderProfile['friendship_id'] = item['id'];
            pendingRequests.add(senderProfile);
          }
        }
      }
    } catch (e) {
      debugPrint("LOAD ERROR: $e");
      errorMessage = 'Error loading friends';
    }

    isLoading = false;
    notifyListeners();
  }

  // =========================================================
  // 2. LOAD LEADERBOARD
  // =========================================================
  Future<void> loadLeaderboard() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    try {
      final response = await _client
          .from('friendships')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.${currentUser.id},receiver_id.eq.${currentUser.id}')
          .eq('status', 'accepted');

      List<String> userIds = [];
      for (var record in response) {
        if (record['sender_id'] == currentUser.id) {
          userIds.add(record['receiver_id']);
        } else {
          userIds.add(record['sender_id']);
        }
      }

      userIds.add(currentUser.id);

      final profilesData = await _client
          .from('profile')
          .select()
          .inFilter('user_id', userIds);

      leaderboardUsers = (profilesData as List)
          .map((data) => UserModel.fromJson(data))
          .toList();

      leaderboardUsers.sort((a, b) => b.streak.compareTo(a.streak));

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
    }
  }

  // =========================================================
  // 3. SEARCH USER
  // =========================================================
  Future<bool> searchUserByUid(String shortUid) async {
    isLoading = true;
    errorMessage = null;
    searchedUser = null;
    notifyListeners();

    try {
      final myId = _client.auth.currentUser!.id;

      final List<dynamic> response = await _client.rpc(
        'search_user_by_uid',
        params: {'search_uid': shortUid},
      );

      if (response.isEmpty) {
        errorMessage = "User not found. Check the UID and try again.";
        isLoading = false;
        notifyListeners();
        return false;
      }

      searchedUser = UserModel.fromJson(response.first);

      if (searchedUser!.userId == myId) {
        errorMessage = "You cannot add yourself as a friend.";
        isLoading = false;
        notifyListeners();
        return false;
      }

      final connection = await _client
          .from('friendships')
          .select('status')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .or(
          'sender_id.eq.${searchedUser!.userId},receiver_id.eq.${searchedUser!.userId}')
          .maybeSingle();

      friendshipStatus = connection != null ? connection['status'] : 'none';

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
  // 4. SEND FRIEND REQUEST
  // =========================================================
  Future<void> sendFriendRequestToSearchedUser() async {
    if (searchedUser == null) return;

    final myId = _client.auth.currentUser!.id;

    try {
      await _client.from('friendships').insert({
        'sender_id': myId,
        'receiver_id': searchedUser!.userId,
        'status': 'pending',
      });

      friendshipStatus = 'pending';
      notifyListeners();
      loadFriendListData();
    } catch (e) {
      errorMessage = 'Could not send request.';
      notifyListeners();
    }
  }

  // =========================================================
  // 5. ACCEPT FRIEND REQUEST
  // ✅ UPDATED: Now accepts AchievementViewModel to trigger
  // the Social Butterfly (friends_count) achievement check
  // immediately after the friendship is confirmed.
  // =========================================================
  Future<void> acceptRequest(
      String friendshipId,
      AchievementViewModel achievementVM,
      ) async {
    try {
      await _client
          .from('friendships')
          .update({'status': 'accepted'}).eq('id', friendshipId);

      // Reload so the friends list reflects the newly accepted friendship
      await loadFriendListData();

      // ── friends_count ─────────────────────────────────────────
      // Social Butterfly: Add your first friend on DreamSync.
      // setProgress (absolute) ensures the count always mirrors
      // the true number of accepted friends — handles both adds
      // and future removals correctly.
      await _checkFriendAchievements(achievementVM);
    } catch (e) {
      errorMessage = 'Failed to accept request.';
      notifyListeners();
    }
  }

  // =========================================================
  // PRIVATE — Check friends_count achievements
  // =========================================================
  Future<void> _checkFriendAchievements(
      AchievementViewModel achievementVM) async {
    final count = friends.length.toDouble();
    for (final a in achievementVM.getByType('friends_count')) {
      await achievementVM.setProgress(a.userAchievementId, count);
    }
  }
}
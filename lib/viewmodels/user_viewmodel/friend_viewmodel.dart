import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;

  // --- ORIGINAL VARIABLES (For Friend List Screen) ---
  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> pendingRequests = [];
  bool isLoading = false;
  String? errorMessage;

  // Search state variables
  UserModel? searchedUser;
  String? friendshipStatus; // 'none', 'pending', 'accepted'

  // --- NEW VARIABLE (For Leaderboard Screen) ---
  List<UserModel> leaderboardUsers = [];

  // =========================================================
  // 1. ORIGINAL FUNCTION: LOAD FRIENDS
  // =========================================================
  Future<void> loadFriendListData() async {
    isLoading = true;
    notifyListeners();

    final myId = _client.auth.currentUser!.id;

    try {
      // Fetch all Friends
      // MODIFIED: Added sleep_goal_hours and streak to the nested join query
      final response = await _client.from('friendships')
          .select('''
            *,
            sender:profile!sender_id(username, email, uid_text, sleep_goal_hours, streak),
            receiver:profile!receiver_id(username, email, uid_text, sleep_goal_hours, streak)
          ''')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId');

      final data = List<Map<String, dynamic>>.from(response);

      friends.clear();
      pendingRequests.clear();

      for (var item in data) {
        // If profile is restricted (null), we skip it to prevent crash
        if (item['sender'] == null || item['receiver'] == null) continue;

        if (item['status'] == 'accepted') {
          final isMeSender = item['sender_id'] == myId;
          final friendProfile = isMeSender ? item['receiver'] : item['sender'];
          friendProfile['friendship_id'] = item['id'];
          friends.add(friendProfile);

        } else if (item['status'] == 'pending' && item['receiver_id'] == myId) {
          // REQUEST FOR ME: The sender is the one asking
          final senderProfile = item['sender'];
          // CRITICAL: We need the sender's data to display the request card
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
  // 2. NEW FUNCTION: LOAD LEADERBOARD (Added for Achievement Screen)
  // =========================================================
  Future<void> loadLeaderboard() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    // Note: We don't set global isLoading = true here to avoid flickering
    // the FriendList screen if they are running simultaneously.

    try {
      // 1. Fetch Friend IDs (Accepted only)
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

      // 2. Add Current User to list (so you appear on the board)
      userIds.add(currentUser.id);

      // 3. Fetch Full Profiles (to get 'streak' and 'username')
      final profilesData = await _client
          .from('profile')
          .select()
          .inFilter('user_id', userIds);

      // 4. Map to UserModel
      leaderboardUsers = (profilesData as List)
          .map((data) => UserModel.fromJson(data))
          .toList();

      // 5. Sort by Streak Descending
      // (Ensure your UserModel has the 'streak' field as added in the previous step)
      leaderboardUsers.sort((a, b) => b.streak.compareTo(a.streak));

      notifyListeners();

    } catch (e) {
      debugPrint("Error loading leaderboard: $e");
    }
  }

  // =========================================================
  // 3. ORIGINAL SEARCH & REQUEST FUNCTIONS
  // =========================================================

  // Search User
  Future<bool> searchUserByUid(String shortUid) async {
    isLoading = true;
    errorMessage = null;
    searchedUser = null;
    notifyListeners();

    try {
      final myId = _client.auth.currentUser!.id;

      final List<dynamic> response = await _client.rpc('search_user_by_uid', params: {
        'search_uid': shortUid,
      });

      if (response.isEmpty) {
        errorMessage = "User not found. Check the UID and try again.";
        isLoading = false;
        notifyListeners();
        return false;
      }

      final data = response.first;
      searchedUser = UserModel.fromJson(data);

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
          .or('sender_id.eq.${searchedUser!.userId},receiver_id.eq.${searchedUser!.userId}')
          .maybeSingle();

      if (connection != null) {
        friendshipStatus = connection['status'];
      } else {
        friendshipStatus = 'none';
      }

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

  // Send Request
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
      loadFriendListData(); // Reload list to reflect changes
    } catch (e) {
      errorMessage = 'Could not send request.';
      notifyListeners();
    }
  }

  // Accept Request
  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);

      await loadFriendListData();
    } catch (e) {
      errorMessage = 'Failed to accept request.';
      notifyListeners();
    }
  }
}
import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class FriendViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> friends = [];
  List<Map<String, dynamic>> pendingRequests = [];
  bool isLoading = false;
  String? errorMessage;

  // Search state variables
  UserModel? searchedUser;
  String? friendshipStatus; // 'none', 'pending', 'accepted'

  Future<void> loadFriendListData() async {
    isLoading = true;
    notifyListeners();

    final myId = _client.auth.currentUser!.id;

    try {
      // Fetch all Friends
      final response = await _client.from('friendships')
          .select('''
            *,
            sender:profile!sender_id(username, email, uid_text),
            receiver:profile!receiver_id(username, email, uid_text)
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
      print("LOAD ERROR: $e");
      errorMessage = 'Error loading friends';
    }

    isLoading = false;
    notifyListeners();
  }

  // Search User
  Future<bool> searchUserByUid(String shortUid) async {
    isLoading = true;
    errorMessage = null;
    searchedUser = null;
    notifyListeners();

    try {
      final myId = _client.auth.currentUser!.id;

      // 1. CHANGE THIS: Get a List instead of .maybeSingle()
      // This prevents the "406 Not Acceptable" crash
      final List<dynamic> response = await _client.rpc('search_user_by_uid', params: {
        'search_uid': shortUid,
      });

      // 2. CHECK MANUALLY: Is the list empty?
      if (response.isEmpty) {
        errorMessage = "User not found. Check the UID and try again.";
        isLoading = false;
        notifyListeners();
        return false;
      }

      // 3. GET DATA: Take the first item safely
      final data = response.first;

      searchedUser = UserModel.fromJson(data);

      // CASE 2: The user is YOU
      if (searchedUser!.userId == myId) {
        errorMessage = "You cannot add yourself as a friend.";
        isLoading = false;
        notifyListeners();
        return false;
      }

      // CASE 3: Valid User Found -> Check Friend Status
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
        'receiver_id': searchedUser!.userId, // Use the long UUID
        'status': 'pending',
      });

      friendshipStatus = 'pending'; // Update UI instantly
      notifyListeners();

      // Optionally reload data
      loadFriendListData();
    } catch (e) {
      errorMessage = 'Could not send request.';
      notifyListeners();
    }
  }

  // --- 4. Accept Request (MISSING FUNCTION ADDED HERE) ---
  Future<void> acceptRequest(String friendshipId) async {
    try {
      await _client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);

      // Refresh the list to move them from Pending -> Friends
      await loadFriendListData();
    } catch (e) {
      errorMessage = 'Failed to accept request.';
      notifyListeners();
    }
  }
}
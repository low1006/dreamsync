import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/models/friend_profile_model.dart';

class FriendRepository {
  final SupabaseClient _client;

  FriendRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ─────────────────────────────────────────────────────────────
  // PENDING REQUEST COUNT
  // ─────────────────────────────────────────────────────────────
  Future<int> fetchPendingRequestCount() async {
    final myId = currentUserId;
    if (myId == null) return 0;

    final response = await _client
        .from('friendships')
        .select('sender_id')
        .eq('receiver_id', myId)
        .eq('status', 'pending');

    return (response as List).length;
  }

  // ─────────────────────────────────────────────────────────────
  // LOAD ALL FRIENDSHIPS (friends + pending requests)
  // ─────────────────────────────────────────────────────────────
  Future<Map<String, List<FriendProfile>>> fetchFriendships() async {
    final myId = currentUserId;
    if (myId == null) return {'friends': [], 'pending': []};

    final response = await _client.from('friendships').select('''
      *,
      sender:profile!sender_id(username, email, uid_text, sleep_goal_hours, streak),
      receiver:profile!receiver_id(username, email, uid_text, sleep_goal_hours, streak)
    ''').or('sender_id.eq.$myId,receiver_id.eq.$myId');

    final data = List<Map<String, dynamic>>.from(response);

    final List<FriendProfile> friends = [];
    final List<FriendProfile> pending = [];

    for (var item in data) {
      if (item['sender'] == null || item['receiver'] == null) continue;

      final senderId = item['sender_id'] as String;
      final receiverId = item['receiver_id'] as String;

      if (item['status'] == 'accepted') {
        final isMeSender = senderId == myId;
        final profileData = isMeSender ? item['receiver'] : item['sender'];
        friends.add(FriendProfile.fromFriendshipRow(
          profileData: profileData,
          senderId: senderId,
          receiverId: receiverId,
        ));
      } else if (item['status'] == 'pending' && receiverId == myId) {
        final senderProfile = item['sender'];
        if (senderProfile != null) {
          pending.add(FriendProfile.fromFriendshipRow(
            profileData: senderProfile,
            senderId: senderId,
            receiverId: receiverId,
          ));
        }
      }
    }

    return {'friends': friends, 'pending': pending};
  }

  // ─────────────────────────────────────────────────────────────
  // LEADERBOARD
  // ─────────────────────────────────────────────────────────────
  Future<List<UserModel>> fetchLeaderboard() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final response = await _client
        .from('friendships')
        .select('sender_id, receiver_id')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .eq('status', 'accepted');

    List<String> userIds = [];
    for (var record in response) {
      if (record['sender_id'] == myId) {
        userIds.add(record['receiver_id']);
      } else {
        userIds.add(record['sender_id']);
      }
    }
    userIds.add(myId);

    final profilesData = await _client
        .from('profile')
        .select()
        .inFilter('user_id', userIds);

    return (profilesData as List)
        .map((data) => UserModel.fromJson(data))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH USER
  // ─────────────────────────────────────────────────────────────
  Future<UserModel?> searchByUid(String uid) async {
    final List<dynamic> response = await _client.rpc(
      'search_user_by_uid',
      params: {'search_uid': uid},
    );

    if (response.isEmpty) return null;
    return UserModel.fromJson(response.first);
  }

  // ─────────────────────────────────────────────────────────────
  // CHECK FRIENDSHIP STATUS
  // ─────────────────────────────────────────────────────────────
  Future<String> checkFriendshipStatus(String otherUserId) async {
    final myId = currentUserId;
    if (myId == null) return 'none';

    final connection = await _client
        .from('friendships')
        .select('status')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .or('sender_id.eq.$otherUserId,receiver_id.eq.$otherUserId')
        .maybeSingle();

    return connection != null ? connection['status'] : 'none';
  }

  // ─────────────────────────────────────────────────────────────
  // SEND FRIEND REQUEST
  // ─────────────────────────────────────────────────────────────
  Future<void> sendFriendRequest(String receiverId) async {
    final myId = currentUserId;
    if (myId == null) return;

    await _client.from('friendships').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  // ─────────────────────────────────────────────────────────────
  // ACCEPT FRIEND REQUEST
  // ─────────────────────────────────────────────────────────────
  Future<void> acceptFriendRequest(String senderId) async {
    final myId = currentUserId;
    if (myId == null) return;

    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('sender_id', senderId)
        .eq('receiver_id', myId);
  }
}
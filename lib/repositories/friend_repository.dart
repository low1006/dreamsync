import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dreamsync/models/friend_profile_model.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';

class FriendRepository {
  final SupabaseClient _client;

  FriendRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;
  Future<Database> get _db async => LocalDatabase.instance.database;

  Future<int> fetchPendingRequestCount() async {
    final myId = currentUserId;
    if (myId == null) return 0;

    final online = await NetworkHelper.hasInternet();
    if (!online) return 0;

    final response = await _client
        .from('friendships')
        .select('sender_id')
        .eq('receiver_id', myId)
        .eq('status', 'pending');

    return (response as List).length;
  }

  Future<Map<String, List<FriendProfile>>> fetchFriendships() async {
    final myId = currentUserId;
    if (myId == null) return {'friends': [], 'pending': []};

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      return _fetchFriendshipsFromCache(myId);
    }

    try {
      final response = await _client.from('friendships').select('''
        *,
        sender:profile!sender_id(user_id, username, email, uid_text, sleep_goal_hours, streak),
        receiver:profile!receiver_id(user_id, username, email, uid_text, sleep_goal_hours, streak)
      ''').or('sender_id.eq.$myId,receiver_id.eq.$myId');

      final data = List<Map<String, dynamic>>.from(response);

      final List<FriendProfile> friends = [];
      final List<FriendProfile> pending = [];

      for (final item in data) {
        if (item['sender'] == null || item['receiver'] == null) continue;

        final senderId = item['sender_id'] as String;
        final receiverId = item['receiver_id'] as String;

        if (item['status'] == 'accepted') {
          final isMeSender = senderId == myId;
          final profileData = isMeSender ? item['receiver'] : item['sender'];

          final friend = FriendProfile.fromFriendshipRow(
            profileData: profileData,
            senderId: senderId,
            receiverId: receiverId,
          );

          friends.add(friend);
          await _cacheFriend(myId, profileData);
        } else if (item['status'] == 'pending' && receiverId == myId) {
          final senderProfile = item['sender'];
          pending.add(FriendProfile.fromFriendshipRow(
            profileData: senderProfile,
            senderId: senderId,
            receiverId: receiverId,
          ));
        }
      }

      return {'friends': friends, 'pending': pending};
    } catch (e) {
      debugPrint('⚠️ Failed to fetch friendships online, using cache: $e');
      return _fetchFriendshipsFromCache(myId);
    }
  }

  Future<List<UserModel>> fetchLeaderboard() async {
    final myId = currentUserId;
    if (myId == null) return [];

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      return _fetchLeaderboardFromCache(myId);
    }

    try {
      final response = await _client
          .from('friendships')
          .select('sender_id, receiver_id')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .eq('status', 'accepted');

      final userIds = <String>{myId};
      for (final record in response) {
        if (record['sender_id'] == myId) {
          userIds.add(record['receiver_id']);
        } else {
          userIds.add(record['sender_id']);
        }
      }

      final profilesData = await _client
          .from('profile')
          .select()
          .inFilter('user_id', userIds.toList());

      final users = (profilesData as List)
          .map((data) => UserModel.fromJson(data))
          .toList();

      // cache accepted friends only; self is not stored in friend_cache
      for (final user in users) {
        if (user.userId != myId) {
          await _cacheLeaderboardUser(myId, user);
        }
      }

      return users;
    } catch (e) {
      debugPrint('⚠️ Failed to fetch leaderboard online, using cache: $e');
      return _fetchLeaderboardFromCache(myId);
    }
  }

  Future<UserModel?> searchByUid(String uid) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) return null;

    final List<dynamic> response = await _client.rpc(
      'search_user_by_uid',
      params: {'search_uid': uid},
    );

    if (response.isEmpty) return null;
    return UserModel.fromJson(response.first);
  }

  Future<String> checkFriendshipStatus(String otherUserId) async {
    final myId = currentUserId;
    if (myId == null) return 'none';

    final online = await NetworkHelper.hasInternet();
    if (!online) return 'none';

    final connection = await _client
        .from('friendships')
        .select('status')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .or('sender_id.eq.$otherUserId,receiver_id.eq.$otherUserId')
        .maybeSingle();

    return connection != null ? connection['status'] : 'none';
  }

  Future<void> sendFriendRequest(String receiverId) async {
    final myId = currentUserId;
    if (myId == null) return;

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      throw Exception('Friend requests require internet.');
    }

    await _client.from('friendships').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  Future<void> acceptFriendRequest(String senderId) async {
    final myId = currentUserId;
    if (myId == null) return;

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      throw Exception('Accepting friend requests requires internet.');
    }

    await _client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('sender_id', senderId)
        .eq('receiver_id', myId);
  }

  Future<void> warmCache() async {
    final myId = currentUserId;
    if (myId == null) return;
    await fetchFriendships();
    await fetchLeaderboard();
  }

  Future<void> _cacheFriend(String myId, Map<String, dynamic> profileData) async {
    final db = await _db;
    await db.insert(
      'friend_cache',
      {
        'id': '${myId}_${profileData['user_id']}',
        'user_id': myId,
        'friend_id': profileData['user_id'],
        'friend_name': profileData['username'] ?? 'Unknown',
        'friend_avatar': null,
        'email': profileData['email'] ?? '',
        'uid_text': profileData['uid_text'] ?? '',
        'sleep_goal_hours': profileData['sleep_goal_hours'] ?? 0,
        'streak': profileData['streak'] ?? 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _cacheLeaderboardUser(String myId, UserModel user) async {
    final db = await _db;
    await db.insert(
      'friend_cache',
      {
        'id': '${myId}_${user.userId}',
        'user_id': myId,
        'friend_id': user.userId,
        'friend_name': user.username,
        'friend_avatar': null,
        'email': user.email,
        'uid_text': user.uidText,
        'sleep_goal_hours': user.sleepGoalHours,
        'streak': user.streak,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, List<FriendProfile>>> _fetchFriendshipsFromCache(
      String myId,
      ) async {
    final db = await _db;
    final rows = await db.query(
      'friend_cache',
      where: 'user_id = ?',
      whereArgs: [myId],
    );

    final friends = rows.map((row) {
      return FriendProfile(
        username: row['friend_name']?.toString() ?? 'Unknown',
        email: row['email']?.toString() ?? '',
        uidText: row['uid_text']?.toString() ?? '',
        sleepGoalHours: (row['sleep_goal_hours'] as num?)?.toDouble() ?? 0,
        streak: (row['streak'] as num?)?.toInt() ?? 0,
        senderId: '',
        receiverId: '',
      );
    }).toList();

    return {'friends': friends, 'pending': []};
  }

  Future<List<UserModel>> _fetchLeaderboardFromCache(String myId) async {
    final db = await _db;

    final friendRows = await db.query(
      'friend_cache',
      where: 'user_id = ?',
      whereArgs: [myId],
    );

    final friends = friendRows.map((row) {
      return UserModel(
        userId: row['friend_id']?.toString() ?? '',
        username: row['friend_name']?.toString() ?? 'Unknown',
        email: row['email']?.toString() ?? '',
        gender: '',
        dateBirth: '',
        weight: 0,
        height: 0,
        uidText: row['uid_text']?.toString() ?? '',
        currentPoints: 0,
        sleepGoalHours: (row['sleep_goal_hours'] as num?)?.toDouble() ?? 0,
        streak: (row['streak'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    final selfRows = await db.query(
      'profile',
      where: 'user_id = ?',
      whereArgs: [myId],
      limit: 1,
    );

    if (selfRows.isNotEmpty) {
      final self = UserModel.fromJson(Map<String, dynamic>.from(selfRows.first));
      friends.add(self);
    }

    return friends;
  }
}
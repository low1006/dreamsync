import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/repositories/base_repository.dart';
import 'package:dreamsync/models/chat_message_model.dart';

class ChatRepository extends BaseRepository<ChatMessageModel> {
  ChatRepository(SupabaseClient client)
      : super(
    client,
    'chat_messages',
    'id',
        (json) => ChatMessageModel.fromMap(json),
  );

  String? get currentUserId => client.auth.currentUser?.id;

  Future<List<ChatMessageModel>> fetchMessagesBySession(String sessionId) async {
    try {
      final data = await client
          .from(tableName)
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Error fetching session messages: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserSessions() async {
    if (currentUserId == null) return [];

    try {
      final data = await client
          .from('chat_sessions')
          .select()
          .eq('user_id', currentUserId!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error fetching chat sessions: $e");
      rethrow;
    }
  }

  Future<String?> createNewSession() async {
    if (currentUserId == null) return null;

    try {
      final response = await client
          .from('chat_sessions')
          .insert({
        'user_id': currentUserId,
        'title': 'Chat ${DateTime.now().minute}',
      })
          .select()
          .single();

      return response['id'];
    } catch (e) {
      print("Error creating new session: $e");
      rethrow;
    }
  }

  Future<void> updateSessionTitle(String sessionId, String newTitle) async {
    try {
      await client
          .from('chat_sessions')
          .update({'title': newTitle})
          .eq('id', sessionId);
    } catch (e) {
      print("Error updating session title: $e");
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await client.from('chat_sessions').delete().eq('id', sessionId);
    } catch (e) {
      print("Error deleting session: $e");
      rethrow;
    }
  }
}
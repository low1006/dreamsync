import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/repositories/base_repository.dart';
import 'package:dreamsync/models/chat_message_model.dart';

class ChatRepository extends BaseRepository<ChatMessageModel> {
  // 1. Initialize BaseRepository for the 'chat_messages' table
  ChatRepository(SupabaseClient client)
      : super(
    client,
    'chat_messages', // Table Name
    'id',            // ID Column
        (json) => ChatMessageModel.fromMap(json), // Mapper
  );

  String? get currentUserId => client.auth.currentUser?.id;

  // --- CUSTOM MESSAGE METHODS ---

  // We need a specific fetch because BaseRepository.getAll() gets EVERYTHING.
  // We only want messages for a specific session, sorted by time.
  Future<List<ChatMessageModel>> fetchMessagesBySession(String sessionId) async {
    try {
      final data = await client
          .from(tableName) // 'chat_messages'
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true); // Sort Oldest -> Newest

      return (data as List)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Error fetching session messages: $e");
      return [];
    }
  }

  // --- SESSION METHODS (Handling the second table) ---
  // Since these use a different table ('chat_sessions'), we write raw queries here.

  // Get list of past chats
  Future<List<Map<String, dynamic>>> fetchUserSessions() async {
    if (currentUserId == null) return [];

    final data = await client
        .from('chat_sessions')
        .select()
        .eq('user_id', currentUserId!)
        .order('created_at', ascending: false); // Newest chats first

    return List<Map<String, dynamic>>.from(data);
  }

  // Create a new chat folder
  Future<String?> createNewSession() async {
    if (currentUserId == null) return null;

    final response = await client.from('chat_sessions').insert({
      'user_id': currentUserId,
      'title': 'Chat ${DateTime.now().minute}', // You can make this smarter later
    }).select().single();

    return response['id'];
  }

  Future<void> updateSessionTitle(String sessionId, String newTitle) async {
    try {
      await client
          .from('chat_sessions')
          .update({'title': newTitle})
          .eq('id', sessionId);

    } catch (e) {
      print("Error updating session title: $e");
    }
  }
}
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/chat_message_model.dart';
import 'package:dreamsync/repositories/chat_repository.dart';
import 'dart:math';


class ChatViewModel extends ChangeNotifier {
  static const List<String> _apiKeys = [
    'AIzaSyAzPlvJ5GfS0jHpMsSaRob_9DGbrQ-VFxs', 'AIzaSyAtPOUG4mGcznimCB5qyW6om_L7pY4tQa0','AIzaSyDkryl-Lmphq472DQ0XjThn7yIzoUlmJQ0', 'AIzaSyD04XYaBc0UwzwBlE2AgHnjyxGXIIwh3uo','AIzaSyD3LeAfZRFfywHiY7Sm4LTxU2-r0m5vYzQ'];

  // static const String _apiKeys = "AIzaSyAzPlvJ5GfS0jHpMsSaRob_9DGbrQ-VFxs";

  // 1. Use the Repository instead of raw Supabase calls
  final ChatRepository _repository = ChatRepository(Supabase.instance.client);

  late final GenerativeModel _model;
  late ChatSession _chatSession;

  String? currentSessionId;
  List<Map<String, dynamic>> sessions = [];
  List<ChatMessageModel> messages = [];
  bool isLoading = false;
  final ScrollController scrollController = ScrollController();

  ChatViewModel() {
    _initModel();
    loadChatSessions();
  }

  void _initModel() {
    final randomKey = _apiKeys[Random().nextInt(_apiKeys.length)];
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: randomKey,
      systemInstruction: Content.system(
          "You are DreamSync, an expert Sleep Health Assistant. "
              "Your only job is to help users improve their sleep quality, analyze dreams, "
              "and discuss sleep disorders. "
              "If a user asks about anything NOT related to sleep, dreams, or health, "
              "politely refuse and guide them back to sleep topics."
      ),
    );
    _chatSession = _model.startChat();
  }

  // --- ACTIONS ---

  Future<void> loadChatSessions() async {
    // Use Repository to fetch sessions
    sessions = await _repository.fetchUserSessions();
    notifyListeners();
  }

  Future<void> startNewSession() async {
    isLoading = true;
    notifyListeners();

    // Use Repository to create session
    final newId = await _repository.createNewSession();

    if (newId != null) {
      currentSessionId = newId;
      messages.clear();
      _chatSession = _model.startChat(); // Reset AI memory
      await loadChatSessions(); // Refresh sidebar list
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> openSession(String sessionId) async {
    currentSessionId = sessionId;
    notifyListeners();
    await _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    if (currentSessionId == null) return;

    try {
      isLoading = true;
      notifyListeners();

      // Use Repository to get messages (Sorted by DB)
      messages = await _repository.fetchMessagesBySession(currentSessionId!);

      _scrollToBottom();
    } catch (e) {
      print("Error loading history: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    bool isFirstMessage = messages.isEmpty;

    // A. Ensure Session Exists
    if (currentSessionId == null) {
      await startNewSession();
    }

    final userId = _repository.currentUserId; // Use getter from repo
    if (userId == null) return;

    // B. Add User Message to UI (Instant Feedback)
    messages.add(ChatMessageModel(
      text: text,
      isUser: true,
    ));
    notifyListeners();
    _scrollToBottom();

    // C. Save User Message to DB using Repository
    // BaseRepository.create takes a Map
    await _repository.create({
      'user_id': userId,
      'session_id': currentSessionId,
      'text': text,
      'is_user': true,
    });

    try {
      isLoading = true;
      notifyListeners();

      // D. Get AI Response
      final response = await _chatSession.sendMessage(Content.text(text));
      final aiText = response.text ?? "I couldn't understand that.";

      // E. Add AI Message to UI
      messages.add(ChatMessageModel(
        text: aiText,
        isUser: false,
      ));

      // F. Save AI Message to DB using Repository
      await _repository.create({
        'user_id': userId,
        'session_id': currentSessionId,
        'text': aiText,
        'is_user': false,
      });

    } catch (e) {
      messages.add(ChatMessageModel(
        text: "Error: ${e.toString()}",
        isUser: false,
      ));
    } finally {
      isLoading = false;
      notifyListeners();
      _scrollToBottom();
    }

    if (isFirstMessage && currentSessionId != null) {
      _generateSessionTitle(text);
    }
  }

  Future<void> _generateSessionTitle(String firstMessage) async {
    try {
      final titleResponse = await _model.generateContent([
        Content.text(
            "Analyze this message: '$firstMessage'. "
                "Generate a short title (max 4 words) for this chat session. "

                "Rules:"
                "1. If the message is just a greeting (like 'Hi', 'Hello', 'Good Morning') or too short to have a topic, return exactly 'KEEP_DEFAULT'."
                "2. Do not use quotes, bold, markdown, or special characters."
                "3. If it is a real topic, return just the title."
        )
      ]);

      final newTitle = titleResponse.text?.trim() ?? "Sleep Chat";
      final cleanTitle = newTitle.replaceAll('*', '').replaceAll('#', '').trim();

      if (currentSessionId != null) {
        await _repository.updateSessionTitle(currentSessionId!, cleanTitle);
      }

      await loadChatSessions();

    } catch (e) {
      print("Error generating title: $e");
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      await _repository.deleteSession(sessionId);

      // Logic: If we deleted the CURRENTLY open chat, reset the UI
      if (currentSessionId == sessionId) {
        messages.clear();
        currentSessionId = null;
        _chatSession = _model.startChat();
      }

      await loadChatSessions();

    } catch (e) {
      print("Error deleting session in VM: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
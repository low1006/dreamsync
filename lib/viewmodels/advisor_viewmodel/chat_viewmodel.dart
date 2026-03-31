import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dreamsync/models/chat_message_model.dart';
import 'package:dreamsync/repositories/chat_repository.dart';
import 'package:dreamsync/services/chat_api_service.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository(Supabase.instance.client);
  final ChatApiService _chatApiService = ChatApiService();

  String? currentSessionId;
  List<Map<String, dynamic>> sessions = [];
  List<ChatMessageModel> messages = [];
  bool isLoading = false;
  final ScrollController scrollController = ScrollController();

  String? currentSuggestion;

  ChatViewModel() {
    _initializeViewModel();
  }

  Future<void> _initializeViewModel() async {
    isLoading = true;
    notifyListeners();

    final userId = _repository.currentUserId;
    await _chatApiService.initialize(userId);
    await loadChatSessions();
    await _generateInitialGreetingAndSuggestion();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _generateInitialGreetingAndSuggestion() async {
    final userId = _repository.currentUserId;
    if (userId == null) return;

    if (messages.isEmpty) {
      messages.add(ChatMessageModel(
        text: "Hello! I'm DreamSync, your AI Sleep Advisor. "
            "How can I help you improve your rest today?",
        isUser: false,
      ));
    }

    try {
      currentSuggestion = await _chatApiService.generateSuggestion(userId);
    } catch (e) {
      currentSuggestion = "How can I sleep better tonight?";
    }
    notifyListeners();
  }

  void selectSuggestion() {
    if (currentSuggestion != null) {
      sendMessage(currentSuggestion!);
      currentSuggestion = null;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || !_chatApiService.isReady) return;

    if (currentSessionId == null) await startNewSession();
    final userId = _repository.currentUserId;
    if (userId == null) return;

    final isFirstMessage = messages.where((m) => m.isUser).isEmpty;

    // Add user message
    messages.add(ChatMessageModel(text: text, isUser: true));
    notifyListeners();
    _scrollToBottom();

    await _repository.create({
      'user_id': userId,
      'session_id': currentSessionId,
      'text': text,
      'is_user': true,
    });

    // Get AI response
    try {
      isLoading = true;
      notifyListeners();

      final aiText = await _chatApiService.sendMessage(text);

      messages.add(ChatMessageModel(text: aiText, isUser: false));

      await _repository.create({
        'user_id': userId,
        'session_id': currentSessionId,
        'text': aiText,
        'is_user': false,
      });

      // Auto-generate title after first user message
      if (isFirstMessage && currentSessionId != null) {
        _autoGenerateTitle(text);
      }
    } catch (e) {
      messages.add(ChatMessageModel(text: "Error: $e", isUser: false));
    } finally {
      isLoading = false;
      notifyListeners();
      _scrollToBottom();
    }
  }

  /// Generates a title in the background without blocking the UI.
  Future<void> _autoGenerateTitle(String firstMessage) async {
    try {
      final title = await _chatApiService.generateSessionTitle(firstMessage);
      if (currentSessionId != null && title.isNotEmpty) {
        await _repository.updateSessionTitle(currentSessionId!, title);
        await loadChatSessions();
      }
    } catch (e) {
      debugPrint('⚠️ Auto-title generation failed: $e');
    }
  }

  // --- Standard session management ---

  Future<void> loadChatSessions() async {
    sessions = await _repository.fetchUserSessions();
    notifyListeners();
  }

  Future<void> startNewSession() async {
    isLoading = true;
    notifyListeners();

    final newId = await _repository.createNewSession();
    if (newId != null) {
      currentSessionId = newId;
      messages.clear();

      // Reinitialize with fresh context
      final userId = _repository.currentUserId;
      await _chatApiService.initialize(userId);
      await _generateInitialGreetingAndSuggestion();
      await loadChatSessions();
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
      messages = await _repository.fetchMessagesBySession(currentSessionId!);
      _scrollToBottom();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    await _repository.deleteSession(sessionId);
    if (currentSessionId == sessionId) {
      messages.clear();
      currentSessionId = null;
      _chatApiService.resetSession();
    }
    await loadChatSessions();
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
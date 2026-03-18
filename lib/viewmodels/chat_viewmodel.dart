import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dreamsync/models/chat_message_model.dart';
import 'package:dreamsync/repositories/chat_repository.dart';
import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/repositories/daily_activity_repository.dart';
import 'package:dreamsync/repositories/recommendation_cache_repository.dart';

class ChatViewModel extends ChangeNotifier {
  static final List<String> _apiKeys = (dotenv.env['GEMINI_API_KEYS'] ?? '')
      .split(',')
      .map((key) => key.trim())
      .toList();

  final ChatRepository _repository = ChatRepository(Supabase.instance.client);
  final SleepRepository _sleepRepo = SleepRepository();
  final DailyActivityRepository _activityRepo = DailyActivityRepository();
  final RecommendationCacheRepository _recommendationRepo = RecommendationCacheRepository();

  GenerativeModel? _model;
  ChatSession? _chatSession;

  String? currentSessionId;
  List<Map<String, dynamic>> sessions = [];
  List<ChatMessageModel> messages = [];
  bool isLoading = false;
  final ScrollController scrollController = ScrollController();

  // --- NEW FIELDS ---
  String? currentSuggestion;

  ChatViewModel() {
    _initializeViewModel();
  }

  Future<void> _initializeViewModel() async {
    isLoading = true;
    notifyListeners();

    await _initModelWithContext();
    await loadChatSessions();

    // Trigger initial greeting and suggestion generation
    await _generateInitialGreetingAndSuggestion();

    isLoading = false;
    notifyListeners();
  }

  Future<void> _generateInitialGreetingAndSuggestion() async {
    final userId = _repository.currentUserId;
    if (userId == null) return;

    // 1. Add Greeting if session is empty
    if (messages.isEmpty) {
      messages.add(ChatMessageModel(
        text: "Hello! I'm DreamSync, your AI Sleep Advisor. How can I help you improve your rest today?",
        isUser: false,
      ));
    }

    // 2. Build suggestion based on ML Recommendation Cache
    try {
      final mlData = await _recommendationRepo.getLatestRecommendation(userId);
      if (mlData != null) {
        final hours = (mlData.recommendedMinutes / 60).toStringAsFixed(1);
        currentSuggestion = "How can I hit my $hours hour sleep goal?";
      } else {
        currentSuggestion = "Give me tips to improve my sleep quality.";
      }
    } catch (e) {
      currentSuggestion = "How can I sleep better tonight?";
    }
    notifyListeners();
  }

  void selectSuggestion() {
    if (currentSuggestion != null) {
      sendMessage(currentSuggestion!);
      currentSuggestion = null; // Hide after use
      notifyListeners();
    }
  }

  Future<void> _initModelWithContext() async {
    final randomKey = _apiKeys[Random().nextInt(_apiKeys.length)];
    final userId = _repository.currentUserId;

    String userContext = "No personal data available right now.";
    if (userId != null) {
      userContext = await _buildUserContextString(userId);
    }

    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: randomKey,
      systemInstruction: Content.system(
          "You are DreamSync, a proactive and expert Sleep Health Advisor. "
              "Analyze the user's sleep data, activities, and Machine Learning (ML) recommended target. "
              "Provide empathetic, actionable advice to help them hit their ML target.\n\n"
              "$userContext"
      ),
    );
    _chatSession = _model!.startChat();
  }

  Future<String> _buildUserContextString(String userId) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final yesterdayStr = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

    String contextString = "CURRENT USER DATA:\n";

    try {
      final mlData = await _recommendationRepo.getLatestRecommendation(userId);
      if (mlData != null) {
        final hours = (mlData.recommendedMinutes / 60).toStringAsFixed(1);
        contextString += "- ML Recommended Sleep Target: $hours hours\n";
        contextString += "- ML Explanation: ${mlData.explanation}\n";
      }
    } catch (_) {}

    try {
      final sleepRecords = await _sleepRepo.getSleepRecordsByDateRange(userId, yesterdayStr, todayStr);
      if (sleepRecords.isNotEmpty) {
        contextString += "- Last Logged Sleep Date: ${sleepRecords.last.date}\n";
      }
    } catch (_) {}

    try {
      final activity = await _activityRepo.getTodayActivity(userId, todayStr);
      if (activity != null) {
        contextString += "- Today's Exercise: ${activity.exerciseMinutes} mins\n";
        contextString += "- Today's Screen Time: ${activity.screenTimeMinutes} mins\n";
      }
    } catch (_) {}

    return contextString;
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _chatSession == null) return;

    if (currentSessionId == null) await startNewSession();
    final userId = _repository.currentUserId;
    if (userId == null) return;

    messages.add(ChatMessageModel(text: text, isUser: true));
    notifyListeners();
    _scrollToBottom();

    await _repository.create({
      'user_id': userId,
      'session_id': currentSessionId,
      'text': text,
      'is_user': true,
    });

    try {
      isLoading = true;
      notifyListeners();

      final response = await _chatSession!.sendMessage(Content.text(text));
      final aiText = response.text ?? "I couldn't understand that.";

      messages.add(ChatMessageModel(text: aiText, isUser: false));

      await _repository.create({
        'user_id': userId,
        'session_id': currentSessionId,
        'text': aiText,
        'is_user': false,
      });
    } catch (e) {
      messages.add(ChatMessageModel(text: "Error: $e", isUser: false));
    } finally {
      isLoading = false;
      notifyListeners();
      _scrollToBottom();
    }
  }

  // --- STANDARD ACTIONS ---
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
      await _initModelWithContext();
      await _generateInitialGreetingAndSuggestion();
      await loadChatSessions();
    }
    isLoading = false;
    notifyListeners();
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
      if (_model != null) _chatSession = _model!.startChat();
    }
    await loadChatSessions();
  }
}
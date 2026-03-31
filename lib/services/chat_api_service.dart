import "package:dreamsync/util/parsers.dart";
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/repositories/daily_activity_repository.dart';
import 'package:dreamsync/repositories/recommendation_cache_repository.dart';

/// Handles all Gemini AI interactions for the sleep advisor chatbot.
class ChatApiService {
  static final List<String> _apiKeys = (dotenv.env['GEMINI_API_KEYS'] ?? '')
      .split(',')
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toList();

  final SleepRepository _sleepRepo = SleepRepository();
  final DailyActivityRepository _activityRepo = DailyActivityRepository();
  final RecommendationCacheRepository _recommendationRepo =
  RecommendationCacheRepository();

  GenerativeModel? _model;
  ChatSession? _chatSession;

  bool get isReady => _chatSession != null;

  /// Initializes the Gemini model with compact user context.
  Future<void> initialize(String? userId) async {
    if (_apiKeys.isEmpty) {
      debugPrint('⚠️ No Gemini API keys configured.');
      return;
    }

    final randomKey = _apiKeys[Random().nextInt(_apiKeys.length)];

    String context = '';
    if (userId != null) {
      context = await buildContextSummary(userId);
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: randomKey,
      systemInstruction: Content.system(_buildSystemPrompt(context)),
    );
    _chatSession = _model!.startChat();
  }

  /// Reinitializes chat session without rebuilding model.
  void resetSession() {
    if (_model != null) {
      _chatSession = _model!.startChat();
    }
  }

  /// Sends a message and returns the AI response text.
  /// No rigid template — lets the system prompt guide the response naturally.
  Future<String> sendMessage(String text) async {
    if (_chatSession == null) {
      return "Chat not initialized. Please try again.";
    }

    try {
      final response = await _chatSession!.sendMessage(
        Content.text(text),
      );
      return response.text ?? "I couldn't understand that.";
    } catch (e) {
      debugPrint('❌ ChatService.sendMessage error: $e');
      return "Sorry, I'm having trouble responding right now. Please try again.";
    }
  }

  /// Generates a short title for a chat session based on the first message.
  /// Evaluates if the message is on-topic before generating a specific title.
  Future<String> generateSessionTitle(String firstUserMessage) async {
    if (_apiKeys.isEmpty) return 'New Chat';

    try {
      final randomKey = _apiKeys[Random().nextInt(_apiKeys.length)];

      final titleModel = GenerativeModel(
        model: 'gemini-2.5-flash', // Can also use gemini-2.5-flash if available
        apiKey: randomKey,
      );

      final response = await titleModel.generateContent([
        Content.text(
          'You are generating a title for a sleep and health advisor app.\n'
              'User Message: "$firstUserMessage"\n'
              'Rule 1: If the message is related to sleep, fitness, food, or health, generate a short, relevant chat title (3-6 words, no quotes).\n'
              'Rule 2: If the message is completely unrelated to those topics, reply EXACTLY with the text: Unrelated Topic\n'
              'Return ONLY the title text, nothing else.',
        ),
      ]);

      final title = (response.text ?? 'New Chat')
          .trim()
          .replaceAll('"', '')
          .replaceAll("'", '');

      // Cap at 40 chars
      return title.length > 40 ? title.substring(0, 40) : title;
    } catch (e) {
      debugPrint('⚠️ generateSessionTitle error: $e');
      return 'New Chat';
    }
  }

  /// Generates a contextual suggestion based on ML recommendation + user data.
  Future<String> generateSuggestion(String userId) async {
    try {
      final mlData =
      await _recommendationRepo.getLatestRecommendation(userId);

      if (mlData != null) {
        final duration = Parsers.formatMinutes(
          mlData.recommendedMinutes.round(),
        );
        return "How can I reach my $duration sleep goal tonight?";
      }

      final todayStr = Parsers.todayKey();
      final activity =
      await _activityRepo.getTodayActivity(userId, todayStr);

      if (activity != null && activity.caffeineIntakeMg > 200) {
        return "I had a lot of caffeine today. Will it affect my sleep?";
      }
      if (activity != null && activity.alcoholIntakeG > 0) {
        return "How does alcohol affect my sleep quality?";
      }

      return "Give me tips to improve my sleep tonight.";
    } catch (e) {
      return "How can I sleep better tonight?";
    }
  }

  /// Builds a compact context summary.
  Future<String> buildContextSummary(String userId) async {
    final lines = <String>[];
    final todayStr = Parsers.todayKey();
    final yesterdayStr = Parsers.dateKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    // Previous completed sleep
    try {
      final records = await _sleepRepo.getSleepRecordsByDateRange(
        userId,
        yesterdayStr,
        '$todayStr 23:59:59',
      );

      if (records.isNotEmpty) {
        final r = records.first;
        lines.add('LAST SLEEP (${r.date}):');
        lines.add(
          '  ${Parsers.formatMinutes(r.totalMinutes)}, score ${r.sleepScore}/100, '
              'deep ${r.deepMinutes}m, REM ${r.remMinutes}m, '
              'light ${r.lightMinutes}m, awake ${r.awakeMinutes}m',
        );
      }
    } catch (_) {}

    // Today's activity + substances
    try {
      final a = await _activityRepo.getTodayActivity(userId, todayStr);
      if (a != null) {
        final parts = <String>[];
        if (a.exerciseMinutes > 0) parts.add('exercise ${a.exerciseMinutes}m');
        if (a.screenTimeMinutes > 0) parts.add('screen ${a.screenTimeMinutes}m');
        if (a.foodCalories > 0) parts.add('food ${a.foodCalories}kcal');
        if (a.burnedCalories > 0) parts.add('burned ${a.burnedCalories}kcal');
        if (a.caffeineIntakeMg > 0) parts.add('caffeine ${a.caffeineIntakeMg.round()}mg');
        if (a.sugarIntakeG > 0) parts.add('sugar ${a.sugarIntakeG.round()}g');
        if (a.alcoholIntakeG > 0) parts.add('alcohol ${a.alcoholIntakeG.toStringAsFixed(1)}g');
        if (parts.isNotEmpty) {
          lines.add('TODAY: ${parts.join(", ")}');
        }
      }
    } catch (_) {}

    // ML target
    try {
      final ml = await _recommendationRepo.getLatestRecommendation(userId);
      if (ml != null) {
        lines.add(
          'TONIGHT TARGET: ${Parsers.formatMinutes(ml.recommendedMinutes.round())} '
              '(expected score ${ml.expectedScore.round()})',
        );
      }
    } catch (_) {}

    return lines.isEmpty ? 'No user data available.' : lines.join('\n');
  }

  /// System prompt — flexible, answers based on what the user actually asks.
  /// System prompt — flexible, answers based on what the user actually asks.
  String _buildSystemPrompt(String context) {
    return 'You are DreamSync, an expert AI Sleep Advisor.\n\n'
        'RULES:\n'
        '- MANDATORY CONSTRAINT: You are strictly limited to discussing sleep, exercise, fitness, food, diet, and nutrition.\n'
        '- If the user asks a question unrelated to these topics (e.g., coding, history, math, general chat, coding), you MUST politely decline to answer. Use a phrase like: "As an AI Sleep Advisor, I can only assist you with topics related to sleep, exercise, and nutrition." Do NOT provide the answer to the off-topic question.\n'
        '- Answer the user\'s actual question directly. Do NOT always start with a sleep summary.\n'
        '- Only reference the user\'s sleep data when it is relevant to their question.\n'
        '- For general knowledge questions (e.g. "how does caffeine affect sleep"), '
        'answer with sleep science knowledge first, then briefly relate it to the user\'s data if relevant.\n'
        '- For personal questions (e.g. "how was my sleep last night", "what should I do tonight"), '
        'use the user data to give a personalized answer.\n'
        '- Be detailed and supportive, but stay focused on what was asked.\n'
        '- Never diagnose medical conditions. Suggest seeing a doctor for persistent issues.\n\n'
        'SLEEP SCIENCE:\n'
        '- Adults need 7-9h sleep. Teens need 8-10h.\n'
        '- Caffeine has a 6h half-life. 200mg+ after noon disrupts sleep.\n'
        '- Alcohol reduces REM sleep by up to 40%.\n'
        '- Sugar before bed spikes blood glucose, causing nighttime awakenings.\n'
        '- Screen time within 1h of bed suppresses melatonin by 50%.\n'
        '- Exercise improves deep sleep, but intense exercise within 2h of bed can delay onset.\n'
        '- Sleep score: 80+ good, 60-79 fair, below 60 needs attention.\n'
        '- Deep sleep (15-20% of total) is for physical recovery.\n'
        '- REM sleep (20-25% of total) is for memory and mood.\n\n'
        'USER DATA:\n'
        '$context';
  }
}
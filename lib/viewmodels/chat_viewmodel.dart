import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:dreamsync/models/chat_message_model.dart';

class ChatViewModel extends ChangeNotifier{
  static const _apiKey = "AIzaSyAYh3yiL2T28zLDXEj1kP7BBNBFVCiiIuM";

  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  List<ChatMessageModel> messages = [];
  bool isLoading = false;
  final ScrollController scrollController = ScrollController();

  ChatViewModel(){
    _initModel();
  }

  void _initModel(){
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
        apiKey: _apiKey,
    );
    _chatSession = _model.startChat();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessageModel(
        text: text,
        isUser: true,
        timestamp: DateTime.now()
    );
    messages.add(userMsg);
    isLoading = true;
    notifyListeners();
    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      final aiText = response.text ?? "I couldn't understand that.";

      final aiMsg = ChatMessageModel(
          text: aiText,
          isUser: false,
          timestamp: DateTime.now()
      );
      messages.add(aiMsg);

    } catch (e) {
      messages.add(ChatMessageModel(
          text: "Error: ${e.toString()}", // Helpful for debugging
          isUser: false,
          timestamp: DateTime.now()
      ));
    } finally {
      isLoading = false;
      notifyListeners();
      _scrollToBottom();
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
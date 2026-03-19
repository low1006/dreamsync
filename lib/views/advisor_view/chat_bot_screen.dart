import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dreamsync/viewmodels/advisor_viewmodel/chat_viewmodel.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isOffline = false;
  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkInternet();

    // Listen for network changes while the screen is open
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (mounted) {
        setState(() {
          _isOffline = result == ConnectivityResult.none;
        });
      }
    });
  }

  Future<void> _checkInternet() async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isOffline = result == ConnectivityResult.none;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Backgrounds
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    // Text Colors
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Brand Colors
    const primaryBrand = Color(0xFF1E3A8A);
    const accentBrand = Color(0xFF3B82F6);

    // 🔥 OFFLINE UI OVERRIDE
    if (_isOffline) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text("DreamSync AI", style: TextStyle(color: primaryText, fontWeight: FontWeight.bold)),
          backgroundColor: scaffoldBg,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryText),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 80, color: secondaryText.withOpacity(0.5)),
                const SizedBox(height: 20),
                Text(
                  "The AI Advisor is Resting",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryText),
                ),
                const SizedBox(height: 10),
                Text(
                  "DreamSync requires an active internet connection to chat with the AI. Please connect to Wi-Fi or Mobile Data to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText, fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _checkInternet,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry Connection"),
                )
              ],
            ),
          ),
        ),
      );
    }

    // 🌐 ONLINE UI (Your normal chat screen)
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel()..loadChatSessions(),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text(
            "DreamSync AI",
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
          ),
          backgroundColor: scaffoldBg,
          elevation: 0,
          iconTheme: IconThemeData(color: primaryText),
        ),
        drawer: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Drawer(
              backgroundColor: surfaceColor,
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white54),
                    child: Center(
                      child: Text(
                        "Chat History",
                        style: TextStyle(color: primaryText, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_circle_outline, color: accentBrand),
                    title: const Text(
                      "New Chat",
                      style: TextStyle(color: accentBrand, fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      viewModel.startNewSession();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(color: secondaryText.withOpacity(0.3)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: viewModel.sessions.length,
                      itemBuilder: (context, index) {
                        final session = viewModel.sessions[index];
                        final isSelected = session['id'] == viewModel.currentSessionId;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? accentBrand.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              session['title'] ?? "Chat",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? accentBrand : primaryText,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onTap: () {
                              viewModel.openSession(session['id']);
                              Navigator.pop(context);
                            },
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline, color: secondaryText, size: 20),
                              onPressed: () {
                                _showDeleteDialog(context, viewModel, session['id'], isDark, surfaceColor, primaryText);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        ),
        body: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: viewModel.scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: viewModel.messages.length,
                    itemBuilder: (context, index) {
                      final msg = viewModel.messages[index];
                      return _buildMessageBubble(msg, isDark, primaryBrand, surfaceColor, primaryText);
                    },
                  ),
                ),

                // --- SUGGESTION CHIP ---
                if (viewModel.currentSuggestion != null && !viewModel.isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => viewModel.selectSuggestion(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: accentBrand.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accentBrand.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.lightbulb_outline, size: 18, color: accentBrand),
                              const SizedBox(width: 8),
                              Text(
                                viewModel.currentSuggestion!,
                                style: const TextStyle(
                                  color: accentBrand,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: accentBrand),
                  ),
                _buildInputArea(context, viewModel, isDark, surfaceColor, primaryText, secondaryText, accentBrand),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatViewModel vm, String id, bool isDark, Color bg, Color text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete Chat?", style: TextStyle(color: text)),
        content: Text(
          "This conversation will be permanently removed.",
          style: TextStyle(color: text.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: text)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.deleteSession(id);
            },
            child: const Text("Delete", style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(msg, bool isDark, Color brandColor, Color surfaceColor, Color textColor) {
    final isUser = msg.isUser;
    final bubbleColor = isUser ? brandColor : surfaceColor;
    final bubbleText = isUser ? Colors.white : textColor;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: const BoxConstraints(maxWidth: 300),
        child: MarkdownBody(
          data: msg.text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: bubbleText, fontSize: 16, height: 1.4),
            strong: TextStyle(color: bubbleText, fontWeight: FontWeight.bold),
            listBullet: TextStyle(color: bubbleText),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatViewModel viewModel, bool isDark, Color bg, Color text, Color hint, Color focus) {
    final TextEditingController _controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: text),
              decoration: InputDecoration(
                hintText: "Ask about your sleep...",
                hintStyle: TextStyle(color: hint),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                viewModel.sendMessage(value);
                _controller.clear();
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: focus,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: focus.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: () {
                viewModel.sendMessage(_controller.text);
                _controller.clear();
              },
            ),
          ),
        ],
      ),
    );
  }
}
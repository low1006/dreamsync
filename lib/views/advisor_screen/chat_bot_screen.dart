import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/chat_viewmodel.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Theme Logic (Matches your CustomTextField)
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Backgrounds
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Colors.white; // Main BG
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9); // Card/Drawer BG

    // Text Colors
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Brand Colors
    const primaryBrand = Color(0xFF1E3A8A); // Deep Blue
    const accentBrand = Color(0xFF3B82F6);  // Bright Blue

    return ChangeNotifierProvider(
      create: (_) => ChatViewModel()..loadChatSessions(),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text(
            "DreamSync AI",
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
          ),
          backgroundColor: scaffoldBg, // Seamless header
          elevation: 0,
          iconTheme: IconThemeData(color: primaryText),
        ),

        // --- SIDEBAR DRAWER (Themed) ---
        drawer: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Drawer(
              backgroundColor: surfaceColor, // Matches CustomTextField background
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white54,
                    ),
                    child: Center(
                      child: Text(
                        "Chat History",
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // "New Chat" Button
                  ListTile(
                    leading: Icon(Icons.add_circle_outline, color: accentBrand),
                    title: Text(
                      "New Chat",
                      style: TextStyle(
                        color: accentBrand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      viewModel.startNewSession();
                      Navigator.pop(context);
                    },
                  ),
                  Divider(color: secondaryText.withOpacity(0.3)),

                  // Session List
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

                            // Delete Button (Themed)
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: secondaryText, // Muted Grey
                                size: 20,
                              ),
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
                // --- CHAT MESSAGES ---
                Expanded(
                  child: ListView.builder(
                    controller: viewModel.scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: viewModel.messages.length,
                    itemBuilder: (context, index) {
                      final msg = viewModel.messages[index];
                      // Pass theme colors to bubbles
                      return _buildMessageBubble(msg, isDark, primaryBrand, surfaceColor, primaryText);
                    },
                  ),
                ),

                // --- LOADING ---
                if (viewModel.isLoading)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: accentBrand),
                  ),

                // --- INPUT AREA ---
                _buildInputArea(context, viewModel, isDark, surfaceColor, primaryText, secondaryText, accentBrand),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- THEMED DIALOG ---
  void _showDeleteDialog(BuildContext context, ChatViewModel vm, String id, bool isDark, Color bg, Color text) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg, // Matches CustomTextField
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
            child: const Text("Delete", style: TextStyle(color: Color(0xFFEF4444))), // Red error color
          ),
        ],
      ),
    );
  }

  // --- THEMED BUBBLES ---
  Widget _buildMessageBubble(msg, bool isDark, Color brandColor, Color surfaceColor, Color textColor) {
    final isUser = msg.isUser;

    // User: Deep Blue (Brand) | AI: Surface Color (Slate/White)
    final bubbleColor = isUser ? brandColor : surfaceColor;

    // User: White Text | AI: Main Text Color
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

  // --- THEMED INPUT AREA ---
  Widget _buildInputArea(BuildContext context, ChatViewModel viewModel, bool isDark, Color bg, Color text, Color hint, Color focus) {
    final TextEditingController _controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg, // Matches CustomTextField background
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
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100], // Inner input background
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

          // Send Button
          Container(
            decoration: BoxDecoration(
              color: focus, // Bright Blue
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
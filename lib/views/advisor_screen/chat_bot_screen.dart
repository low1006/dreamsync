import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/chat_viewmodel.dart';
import 'package:flutter_markdown/flutter_markdown.dart';


class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // We create the ViewModel here so it lives as long as the screen
    return ChangeNotifierProvider(
      create: (_) => ChatViewModel()..loadChatSessions(),
      child: Scaffold(
        appBar: AppBar(title: const Text("DreamSync AI")),
        body: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                // --- CHAT HISTORY ---
                Expanded(
                  child: ListView.builder(
                    controller: viewModel.scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: viewModel.messages.length,
                    itemBuilder: (context, index) {
                      final msg = viewModel.messages[index];
                      return _buildMessageBubble(msg);
                    },
                  ),
                ),

                // --- LOADING INDICATOR ---
                if (viewModel.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),

                // --- INPUT FIELD ---
                _buildInputArea(context, viewModel),
              ],
            );
          },
        ),

        drawer: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Drawer(
              child: Column(
                children: [
                  const DrawerHeader(child: Center(child: Text("Chat History"))),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text("New Chat"),
                    onTap: () {
                      viewModel.startNewSession();
                      Navigator.pop(context); // Close drawer
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: viewModel.sessions.length,
                      itemBuilder: (context, index) {
                        final session = viewModel.sessions[index];
                        return ListTile(
                          title: Text(session['title'] ?? "Chat"),
                          // Highlight the currently active chat
                          selected: session['id'] == viewModel.currentSessionId,
                          onTap: () {
                            viewModel.openSession(session['id']);
                            Navigator.pop(context); // Close drawer
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? const Color(0xFF1E3A8A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        constraints: const BoxConstraints(maxWidth: 300),
        child: MarkdownBody(
          data: msg.text,

          styleSheet: MarkdownStyleSheet(
            p:TextStyle(
              color: msg.isUser ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            strong: TextStyle(
              color: msg.isUser ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            )
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ChatViewModel viewModel) {
    final TextEditingController _controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Ask about your sleep...",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (value) {
                viewModel.sendMessage(value);
                _controller.clear();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF1E3A8A)),
            onPressed: () {
              viewModel.sendMessage(_controller.text);
              _controller.clear();
            },
          ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dreamsync/viewmodels/advisor_viewmodel/chat_viewmodel.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  bool _isOffline = false;
  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkInternet();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
          if (mounted) {
            setState(() => _isOffline = result == ConnectivityResult.none);
          }
        });
  }

  Future<void> _checkInternet() async {
    try {
      final result = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isOffline = result == ConnectivityResult.none);
      }
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send(ChatViewModel vm) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    vm.sendMessage(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOffline) return _buildOfflineScreen(context);

    return ChangeNotifierProvider(
      create: (_) => ChatViewModel()..loadChatSessions(),
      child: Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(
                    'assets/icons/dreamSync_app_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Sleep Advisor",
                style: TextStyle(
                    color: AppTheme.text(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ],
          ),
          backgroundColor: AppTheme.bg(context),
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.text(context)),
          actions: [
            Consumer<ChatViewModel>(
              builder: (context, vm, _) => IconButton(
                icon: const Icon(Icons.add_comment_outlined, size: 22),
                tooltip: 'New Chat',
                onPressed: () => vm.startNewSession(),
              ),
            ),
          ],
        ),
        drawer: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) =>
              _buildDrawer(context, viewModel),
        ),
        body: Consumer<ChatViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                Expanded(
                  child: viewModel.messages.isEmpty && !viewModel.isLoading
                      ? _buildEmptyState(context)
                      : ListView.builder(
                    controller: viewModel.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: viewModel.messages.length +
                        (viewModel.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == viewModel.messages.length &&
                          viewModel.isLoading) {
                        return _buildTypingIndicator(context);
                      }
                      return _buildMessageBubble(
                          context, viewModel.messages[index]);
                    },
                  ),
                ),
                if (viewModel.currentSuggestion != null &&
                    !viewModel.isLoading)
                  _buildSuggestionChip(context, viewModel),
                _buildInputArea(context, viewModel),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadow(context),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  'assets/icons/dreamSync_app_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Your Sleep Advisor",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.subText(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Ask me anything about your sleep patterns,\nhabits, or how to improve your rest.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.subText(context).withOpacity(0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Typing indicator ──────────────────────────────────────────────────
  Widget _buildTypingIndicator(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8, right: 80),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _aiAvatar(context),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadow(context),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _TypingDots(color: AppTheme.subText(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── AI avatar ──────────────────────────────────────────────────────────
  Widget _aiAvatar(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Image.asset(
          'assets/icons/dreamSync_app_icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ─── Message bubble ─────────────────────────────────────────────────────
  Widget _buildMessageBubble(BuildContext context, msg) {
    final isUser = msg.isUser;
    final bubbleColor =
    isUser ? AppTheme.accent : AppTheme.surface(context);
    final bubbleText =
    isUser ? Colors.white : AppTheme.text(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _aiAvatar(context),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadow(context),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: MarkdownBody(
                data: msg.text,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                      color: bubbleText, fontSize: 15, height: 1.45),
                  strong: TextStyle(
                      color: bubbleText, fontWeight: FontWeight.bold),
                  listBullet: TextStyle(color: bubbleText),
                  em: TextStyle(
                      color: bubbleText, fontStyle: FontStyle.italic),
                  code: TextStyle(
                    color: bubbleText,
                    backgroundColor: Colors.black.withOpacity(0.1),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }

  // ─── Suggestion chip ────────────────────────────────────────────────────
  Widget _buildSuggestionChip(BuildContext context, ChatViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => viewModel.selectSuggestion(),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 16, color: AppTheme.accent.withOpacity(0.8)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    viewModel.currentSuggestion!,
                    style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios,
                    size: 12, color: AppTheme.accent.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Input area ─────────────────────────────────────────────────────────
  Widget _buildInputArea(BuildContext context, ChatViewModel viewModel) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: AppTheme.bg(context),
        border: Border(
          top: BorderSide(color: AppTheme.border(context)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface(context),
                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: TextStyle(color: AppTheme.text(context), fontSize: 15),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: "Ask about your sleep...",
                  hintStyle: TextStyle(
                      color: AppTheme.subText(context).withOpacity(0.6),
                      fontSize: 15),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(viewModel),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => _send(viewModel),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Drawer ─────────────────────────────────────────────────────────────
  Widget _buildDrawer(BuildContext context, ChatViewModel viewModel) {
    return Drawer(
      backgroundColor: AppTheme.bg(context),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 24, 20, 20),
            decoration: const BoxDecoration(
              color: AppTheme.accent, // Set the background back to the theme blue
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Image.asset(
                      'assets/icons/dreamSync_app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Chat History",
                  style: TextStyle(
                      color: Colors.white, // White text against the blue background
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Your sleep advisor conversations",
                  style: TextStyle(color: Colors.white70, fontSize: 13), // Subdued white for subtitle
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              onTap: () {
                viewModel.startNewSession();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppTheme.accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "New Chat",
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: viewModel.sessions.isEmpty
                ? Center(
              child: Text(
                "No conversations yet",
                style: TextStyle(
                    color: AppTheme.subText(context), fontSize: 14),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: viewModel.sessions.length,
              itemBuilder: (context, index) {
                final session = viewModel.sessions[index];
                final isSelected =
                    session['id'] == viewModel.currentSessionId;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accent.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius:
                    BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.subText(context),
                    ),
                    title: Text(
                      session['title'] ?? "Chat",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accent
                            : AppTheme.text(context),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      viewModel.openSession(session['id']);
                      Navigator.pop(context);
                    },
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color:
                          AppTheme.subText(context).withOpacity(0.5),
                          size: 18),
                      onPressed: () {
                        _showDeleteDialog(context, viewModel,
                            session['id']);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Offline screen ─────────────────────────────────────────────────────
  Widget _buildOfflineScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Sleep Advisor",
            style: TextStyle(
                color: AppTheme.text(context), fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.subText(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                ),
                child: Icon(Icons.cloud_off,
                    size: 40,
                    color: AppTheme.subText(context).withOpacity(0.5)),
              ),
              const SizedBox(height: 24),
              Text(
                "No Connection",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text(context)),
              ),
              const SizedBox(height: 8),
              Text(
                "The Sleep Advisor needs an internet\nconnection to help you.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.subText(context),
                    fontSize: 15,
                    height: 1.5),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 180,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppTheme.radiusRound)),
                    elevation: 0,
                  ),
                  onPressed: _checkInternet,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Retry",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Delete dialog ──────────────────────────────────────────────────────
  void _showDeleteDialog(
      BuildContext context, ChatViewModel vm, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        title: Text("Delete Chat?",
            style: TextStyle(color: AppTheme.text(context))),
        content: Text(
          "This conversation will be permanently removed.",
          style: TextStyle(color: AppTheme.subText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel",
                style: TextStyle(
                    color: AppTheme.subText(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              vm.deleteSession(id);
            },
            child: const Text("Delete",
                style: TextStyle(
                    color: AppTheme.error,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Animated typing dots
// ═══════════════════════════════════════════════════════════════════════════════
class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );

    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: c, curve: Curves.easeInOut),
    ))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _animations[i].value),
            child: Container(
              width: 7,
              height: 7,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}
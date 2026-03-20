import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/widget/friend/cards/friend_card.dart';
import 'package:dreamsync/widget/friend/cards/request_card.dart';
import 'package:dreamsync/widget/friend/friend_detail_sheet.dart';
import 'package:dreamsync/widget/friend/add_friend_dialogs.dart';

class FriendListScreen extends StatefulWidget {
  const FriendListScreen({super.key});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FriendViewModel>(context, listen: false).loadFriendListData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<FriendViewModel>(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);
    final surface = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
        title: Text(
          "My Friends",
          style: TextStyle(color: text, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: text.withOpacity(0.5),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          dividerColor: text.withOpacity(0.1),
          tabs: [
            const Tab(text: "Friends"),
            Tab(text: "Requests (${viewModel.pendingRequests.length})"),
          ],
        ),
      ),
      body: viewModel.isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : TabBarView(
        controller: _tabController,
        children: [
          // Friends Tab
          viewModel.friends.isEmpty
              ? _buildEmptyState("No friends yet. Add someone!", text)
              : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: viewModel.friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final friend = viewModel.friends[index];
              return FriendCard(
                friend: friend,
                surface: surface,
                text: text,
                accent: accent,
                onTap: () => FriendDetailSheet.show(
                  context,
                  friend: friend,
                  surface: surface,
                  text: text,
                  accent: accent,
                ),
              );
            },
          ),

          // Requests Tab
          viewModel.pendingRequests.isEmpty
              ? _buildEmptyState("No pending requests.", text)
              : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: viewModel.pendingRequests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final req = viewModel.pendingRequests[index];
              return RequestCard(
                request: req,
                surface: surface,
                text: text,
                accent: accent,
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () => AddFriendDialog.show(
          context,
          viewModel: viewModel,
          bg: bg,
          surface: surface,
          text: text,
          accent: accent,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, Color text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: text.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            msg,
            style: TextStyle(color: text.withOpacity(0.4), fontSize: 16),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
// Ensure this import points to your actual CustomTextField location
import 'package:dreamsync/widget/custom/custom_text_field.dart';

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

    // --- THEME COLORS (Matching Schedule Screen) ---
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
        title: Text(
            "My Friends",
            style: TextStyle(color: text, fontWeight: FontWeight.bold)
        ),
        iconTheme: IconThemeData(color: text),
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
          // --- TAB 1: FRIENDS LIST ---
          viewModel.friends.isEmpty
              ? _buildEmptyState("No friends yet. Add someone!", text)
              : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: viewModel.friends.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final friend = viewModel.friends[index];
              return _buildFriendCard(friend, surface, text, accent);
            },
          ),

          // --- TAB 2: PENDING REQUESTS ---
          viewModel.pendingRequests.isEmpty
              ? _buildEmptyState("No pending requests.", text)
              : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: viewModel.pendingRequests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final req = viewModel.pendingRequests[index];
              return _buildRequestCard(req, viewModel, surface, text, accent);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () => _showAddFriendDialog(context, viewModel, bg, surface, text, accent),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildFriendCard(Map<String, dynamic> friend, Color surface, Color text, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: text.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.5), width: 2),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: accent.withOpacity(0.1),
              child: Text(
                friend['username'][0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.bold, color: accent, fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['username'],
                  style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  friend['email'],
                  style: TextStyle(color: text.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chat_bubble_outline, color: text.withOpacity(0.3)),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req, FriendViewModel vm, Color surface, Color text, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3)), // Slight orange tint for requests
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.waving_hand, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  req['username'],
                  style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  "Wants to connect",
                  style: TextStyle(color: text.withOpacity(0.5), fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => vm.acceptRequest(req['friendship_id']),
            child: const Text("Accept"),
          ),
        ],
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

  // --- DIALOGS ---

  void _showAddFriendDialog(
      BuildContext context,
      FriendViewModel viewModel,
      Color bg,
      Color surface,
      Color text,
      Color accent
      ) {
    final uidController = TextEditingController();
    viewModel.searchedUser = null;
    viewModel.errorMessage = null;

    showDialog(
      context: context,
      builder: (context) {
        return ChangeNotifierProvider.value(
          value: viewModel,
          child: Consumer<FriendViewModel>(
            builder: (context, model, child) {
              return AlertDialog(
                backgroundColor: surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text("Add Friend", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Styled Input
                    Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: text.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: uidController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: text),
                        decoration: InputDecoration(
                          hintText: "Enter UID (e.g. 1234)",
                          hintStyle: TextStyle(color: text.withOpacity(0.4)),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text("User#", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (model.isLoading)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(color: accent),
                      ),

                    if (model.errorMessage != null && !model.isLoading)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          model.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // --- SEARCH RESULT CARD ---
                    if (model.searchedUser != null && !model.isLoading)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: accent.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: accent,
                                child: Text(
                                  model.searchedUser!.username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                model.searchedUser!.username,
                                style: TextStyle(color: text, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "UID: ${model.searchedUser!.uidText}",
                                style: TextStyle(color: text.withOpacity(0.5), fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getButtonColor(model.friendshipStatus, accent),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: model.friendshipStatus == 'none'
                                    ? () async {
                                  await model.sendFriendRequestToSearchedUser();
                                }
                                    : null, // Disable if already friends/pending
                                child: Text(_getButtonText(model.friendshipStatus)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close", style: TextStyle(color: text.withOpacity(0.6))),
                  ),
                  if (model.searchedUser == null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final inputNumber = uidController.text.trim();
                        if (inputNumber.isEmpty) return;
                        model.searchUserByUid("User#$inputNumber");
                      },
                      child: const Text("Search"),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // --- Helpers ---

  Color _getButtonColor(String? status, Color accent) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'pending': return Colors.orange;
      default: return accent;
    }
  }

  String _getButtonText(String? status) {
    switch (status) {
      case 'accepted': return "Already Friends";
      case 'pending': return "Request Sent";
      default: return "Add Friend";
    }
  }
}
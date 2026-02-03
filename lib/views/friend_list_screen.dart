import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/friend_viewmodel.dart';
import 'package:dreamsync/widget/custom_text_field.dart';

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
    // Load data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FriendViewModel>(context, listen: false).loadFriendListData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<FriendViewModel>(context);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("My Friends"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6), // Brand Blue
          labelColor: const Color(0xFF3B82F6),
          unselectedLabelColor: Colors.grey,
          tabs: [
            const Tab(text: "Friend Lists"),
            Tab(text: "Requests (${viewModel.pendingRequests.length})"),
          ],
        ),
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // --- Tab 1: Friends List ---
                viewModel.friends.isEmpty
                    ? _buildEmptyState("No friends yet. Add someone!")
                    : ListView.builder(
                        itemCount: viewModel.friends.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final friend = viewModel.friends[index];
                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueAccent.withOpacity(
                                  0.2,
                                ),
                                child: Text(
                                  friend['username'][0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                              title: Text(
                                friend['username'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(friend['email']),
                            ),
                          );
                        },
                      ),

                // --- Tab 2: Pending Requests ---
                viewModel.pendingRequests.isEmpty
                    ? _buildEmptyState("No pending requests.")
                    : ListView.builder(
                        itemCount: viewModel.pendingRequests.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final req = viewModel.pendingRequests[index];
                          return Card(
                            color: cardColor,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.orangeAccent,
                                child: Icon(
                                  Icons.person_add,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(req['username']),
                              subtitle: const Text("Wants to be your friend"),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  viewModel.acceptRequest(req['friendship_id']);
                                },
                                child: const Text("Accept"),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddFriendDialog(context, viewModel),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Text(
        msg,
        style: const TextStyle(color: Colors.grey, fontSize: 16),
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context, FriendViewModel viewModel) {
    final uidController = TextEditingController();

    // Reset previous search results before opening
    viewModel.searchedUser = null;
    viewModel.errorMessage = null;

    showDialog(
      context: context,
      builder: (context) {
        // Theme colors
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final mutedColor = isDark ? Colors.white54 : Colors.black54;

        return ChangeNotifierProvider.value(
          value: viewModel,
          child: Consumer<FriendViewModel>(
            builder: (context, model, child) {
              return AlertDialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text("Add Friend", style: TextStyle(color: textColor)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 20),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      controller: uidController,
                      label: "User UID",
                      keyboardType: TextInputType.number, // Show number pad
                      prefixText: "User#",
                      prefixStyle: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (model.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),

                    if (model.errorMessage != null && !model.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          model.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    if (model.searchedUser != null && !model.isLoading)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: Colors.blueAccent,
                                child: Text(
                                  model.searchedUser!.username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                model.searchedUser!.username,
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "UID: ${model.searchedUser!.uidText}",
                                style: TextStyle(color: mutedColor, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getButtonColor(model.friendshipStatus),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: model.friendshipStatus == 'none'
                                    ? () async {
                                  await model.sendFriendRequestToSearchedUser();
                                }
                                    : null,
                                child: Text(_getButtonText(model.friendshipStatus)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                actions: [
                  if (model.searchedUser == null)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: textColor,
                        ),
                      ),
                    ),

                  if (model.searchedUser == null)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                      onPressed: () {
                        final inputNumber = uidController.text.trim();
                        if (inputNumber.isEmpty) return;
                        model.searchUserByUid("User#$inputNumber");
                      },
                      child: const Text("Search", style: TextStyle(color: Colors.white)),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Done",
                        style: TextStyle(color: textColor),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

// --- Helper Functions for Button Styling ---

  Color _getButtonColor(String? status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'pending': return Colors.orange;
      default: return const Color(0xFF3B82F6); // Blue for 'Add Friend'
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

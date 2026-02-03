import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel.dart';
import 'package:dreamsync/widget/custom_button.dart';
import 'package:dreamsync/views/friend_list_screen.dart';
import 'package:dreamsync/viewmodels/friend_viewmodel.dart';


class UserScreen extends StatelessWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<UserViewModel>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Smart Colors that change automatically
    final surfaceColor = Theme.of(context).cardColor;
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final mutedText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : viewModel.userProfile == null
          ? const Center(child: Text('Could not load profile.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // --- 1. Avatar & Header ---
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: surfaceColor,
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.userProfile!.username,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                  Text(
                    viewModel.userProfile!.email,
                    style: TextStyle(fontSize: 14, color: mutedText),
                  ),

                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha:0.3)),
                    ),
                    child: SelectableText(
                      "UID: ${viewModel.userProfile!.uidText}",
                      style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 8),
                  // --- 2. Data Card ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTile(
                          context,
                          'Gender',
                          viewModel.userProfile!.gender,
                        ),
                        _divider(context),
                        _buildTile(
                          context,
                          'Age',
                          '${viewModel.userProfile!.age} years',
                        ),
                        _divider(context),
                        _buildTile(
                          context,
                          'Birth Date',
                          viewModel.userProfile!.dateBirth,
                        ),
                        _divider(context),
                        _buildTile(
                          context,
                          'Height',
                          '${viewModel.userProfile!.height} cm',
                        ),
                        _divider(context),
                        _buildTile(
                          context,
                          'Weight',
                          '${viewModel.userProfile!.weight} kg',
                        ),
                        _divider(context),
                        _buildTile(
                          context,
                          'Points',
                          '${viewModel.userProfile!.currentPoints} pts',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- 3. Custom Buttons ---
                  CustomButton(
                    text: "My Friends",
                    textColor: Colors.white,
                    onPressed: () {
                      // Navigate to Friend Screen with Provider
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChangeNotifierProvider(
                            create: (_) => FriendViewModel(),
                            child: const FriendListScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  CustomButton(
                    text: "Logout",
                    textColor: Colors.white,
                    onPressed: () async => await viewModel.signOut(),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: "Delete Account",
                    backgroundColor: const Color(0xFFEF4444), // Specific Color
                    textColor: Colors.white,
                    onPressed: () => _showDeleteConfirm(context, viewModel),
                  ),
                ],
              ),
            ),
    );
  }

  // Helper Methods
  Widget _buildTile(BuildContext context, String label, String value) {
    // Determine colors based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final valueColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      color: Theme.of(context).dividerColor.withValues(alpha:0.1),
      thickness: 1,
      height: 24,
    );
  }

  void _showDeleteConfirm(BuildContext context, UserViewModel viewModel) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgColor,
        title: Text("Delete Account?", style: TextStyle(color: textColor)),
        content: Text(
          "This is permanent. All sleep logs and points will be erased.",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              viewModel.deleteUserAccount();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

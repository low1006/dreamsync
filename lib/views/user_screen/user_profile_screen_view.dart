import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/views/user_screen/friend_list_screen.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  // --- STATE VARIABLES (Matching ScheduleScreen pattern) ---
  bool _isEditing = false;
  bool _isInit = true;

  // Local temporary variables to hold changes before saving
  late double _tempWeight;
  late double _tempHeight;
  late double _tempSleepGoal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize local state only once when the screen loads
    if (_isInit) {
      final user = Provider.of<UserViewModel>(context, listen: false).userProfile;
      if (user != null) {
        _tempWeight = user.weight;
        _tempHeight = user.height;
        _tempSleepGoal = user.sleepGoalHours;
      } else {
        // Default fallbacks preventing null errors
        _tempWeight = 70.0;
        _tempHeight = 170.0;
        _tempSleepGoal = 8.0;
      }
      _isInit = false;
    }
  }

  // --- LOGIC METHODS ---

  void _toggleEditMode() {
    if (_isEditing) {
      // If we were editing, now we save
      _saveProfile();
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    final viewModel = Provider.of<UserViewModel>(context, listen: false);

    // Call the update method in ViewModel
    await viewModel.updateUserProfile(
      weight: _tempWeight,
      height: _tempHeight,
      sleepGoal: _tempSleepGoal,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile saved successfully"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<UserViewModel>(context);

    // Theme & Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);
    final surface = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text("My Profile", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (viewModel.userProfile != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                onPressed: _toggleEditMode,
                // Swaps icon between Edit (Pencil) and Save (Check)
                icon: Icon(
                  _isEditing ? Icons.check_circle : Icons.edit,
                  color: accent,
                  size: 28,
                ),
                tooltip: _isEditing ? "Save Changes" : "Edit Profile",
              ),
            ),
        ],
      ),
      body: viewModel.isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : viewModel.userProfile == null
          ? Center(child: Text('Could not load profile.', style: TextStyle(color: text)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- 1. AVATAR & HEADER ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.5), width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: surface,
                child: Icon(Icons.person, size: 50, color: accent),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              viewModel.userProfile!.username,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: text),
            ),
            Text(
              viewModel.userProfile!.email,
              style: TextStyle(fontSize: 14, color: text.withOpacity(0.6)),
            ),
            const SizedBox(height: 12),

            // UID Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.2)),
              ),
              child: SelectableText(
                "UID: ${viewModel.userProfile!.uidText}",
                style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),

            const SizedBox(height: 30),

            // --- 2. DATA CARD (Handles both Static & Edit views) ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  // Highlights border when editing
                  color: _isEditing ? accent.withOpacity(0.5) : text.withOpacity(0.05),
                  width: _isEditing ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  // Static Fields (Gender/Age/Birth)
                  _buildTile(context, 'Gender', viewModel.userProfile!.gender, text, accent),
                  _divider(text),
                  _buildTile(context, 'Age', '${viewModel.userProfile!.age} years', text, accent),
                  _divider(text),
                  _buildTile(context, 'Birth Date', viewModel.userProfile!.dateBirth, text, accent),

                  _divider(text),

                  // --- EDITABLE FIELDS ---

                  // Height
                  _buildEditableRow(
                    label: "Height",
                    value: _tempHeight,
                    unit: "cm",
                    min: 100, max: 220,
                    text: text, accent: accent,
                    onChanged: (val) => setState(() => _tempHeight = val),
                  ),

                  _divider(text),

                  // Weight
                  _buildEditableRow(
                    label: "Weight",
                    value: _tempWeight,
                    unit: "kg",
                    min: 30, max: 150,
                    text: text, accent: accent,
                    onChanged: (val) => setState(() => _tempWeight = val),
                  ),

                  _divider(text),

                  // Sleep Goal
                  _buildEditableRow(
                    label: "Sleep Goal",
                    value: _tempSleepGoal,
                    unit: "hrs",
                    min: 4, max: 12,
                    text: text, accent: accent,
                    onChanged: (val) => setState(() => _tempSleepGoal = val),
                  ),

                  _divider(text),

                  // Points (Static)
                  _buildTile(context, 'Points', '${viewModel.userProfile!.currentPoints} pts', text, accent, isHighlight: true),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- 3. HELPER MESSAGE ---
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: Text(
                  "Tap the checkmark above to save changes.",
                  style: TextStyle(color: text.withOpacity(0.5), fontStyle: FontStyle.italic),
                ),
              ),

            // --- 4. ACTION BUTTONS ---
            // We dim these when editing to focus user on the task
            _buildActionButton(
                context, "My Friends", Icons.people, accent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangeNotifierProvider(create: (_) => FriendViewModel(), child: const FriendListScreen())))
            ),

            const SizedBox(height: 12),

            _buildActionButton(
                context, "Logout", Icons.logout, text.withOpacity(0.7),
                    () async => await viewModel.signOut()
            ),

            const SizedBox(height: 12),

            _buildActionButton(
                context, "Delete Account", Icons.delete_forever, const Color(0xFFEF4444),
                    () => _showDeleteConfirm(context, viewModel),
                isDestructive: true
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  // 1. The Magic Row: Switches between Text and Slider based on _isEditing
  Widget _buildEditableRow({
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required Color text,
    required Color accent,
    required Function(double) onChanged,
  }) {
    // If NOT editing, show standard tile
    if (!_isEditing) {
      return _buildTile(context, label, "${value.toStringAsFixed(1)} $unit", text, accent);
    }

    // IF EDITING, show Slider UI
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                "${value.toStringAsFixed(1)} $unit",
                style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: accent.withOpacity(0.2),
              thumbColor: accent,
              overlayColor: accent.withOpacity(0.1),
              trackHeight: 4.0,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) * 2).toInt(), // 0.5 steps
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // 2. Standard Static Tile
  Widget _buildTile(BuildContext context, String label, String value, Color text, Color accent, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: text.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? accent : text,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color text) {
    return Divider(color: text.withOpacity(0.05), thickness: 1, height: 1);
  }

  // 3. Action Buttons
  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap, {bool isDestructive = false}) {
    // Dim buttons while editing
    final opacity = _isEditing ? 0.3 : 1.0;

    return IgnorePointer(
      ignoring: _isEditing,
      child: Opacity(
        opacity: opacity,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
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
        title: Text("Delete Account?", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              viewModel.deleteUserAccount();
              Navigator.pop(context);
            },
            child: const Text("Delete Forever"),
          ),
        ],
      ),
    );
  }
}
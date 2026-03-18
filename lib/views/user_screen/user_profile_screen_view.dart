import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:health/health.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/views/user_screen/friend_list_screen.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/util/time_formatter.dart';
import 'package:dreamsync/models/user_model.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with WidgetsBindingObserver {
  bool _isEditing = false;
  bool _isInit = true;
  bool _isRefreshingProfile = false;
  String? _lastRefreshedUserId;

  late double _tempWeight;
  late double _tempHeight;

  bool? _isHealthConnected;
  final Health _health = Health();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkHealthStatus();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final viewModel = context.read<UserViewModel>();
      final userId = viewModel.userProfile?.userId;
      if (userId != null) {
        await _refreshProfileSilently(userId, force: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final viewModel = context.read<UserViewModel>();
      final userId = viewModel.userProfile?.userId;
      if (userId != null) {
        _refreshProfileSilently(userId, force: true);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final user = Provider.of<UserViewModel>(context, listen: false).userProfile;

    if (_isInit) {
      if (user != null) {
        _syncTempFromUser(user);
        _lastRefreshedUserId = user.userId;
      } else {
        _tempWeight = 70.0;
        _tempHeight = 170.0;
      }

      _isInit = false;
    } else if (!_isEditing && user != null) {
      _syncTempFromUser(user);
    }
  }

  // ADDED: The missing method to sync local state with the user model
  void _syncTempFromUser(UserModel user) {
    _tempWeight = user.weight;
    _tempHeight = user.height;
  }

  Future<void> _refreshProfileSilently(
      String userId, {
        bool force = false,
      }) async {
    if (_isRefreshingProfile) return;
    if (!force && _lastRefreshedUserId == userId) return;

    _isRefreshingProfile = true;
    try {
      await context.read<UserViewModel>().fetchProfile(userId);
      _lastRefreshedUserId = userId;
    } catch (e) {
      debugPrint("❌ Failed to refresh profile: $e");
    } finally {
      _isRefreshingProfile = false;
    }
  }

  Future<void> _checkHealthStatus() async {
    final types = [
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_SESSION,
    ];

    try {
      bool? hasPermissions = await _health.hasPermissions(types);
      if (mounted) {
        setState(() {
          _isHealthConnected = hasPermissions ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isHealthConnected = false);
      }
    }
  }

  Future<void> _requestHealthAccess() async {
    final types = [
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_SESSION,
    ];

    try {
      bool authorized = await _health.requestAuthorization(types);
      if (mounted) {
        setState(() {
          _isHealthConnected = authorized;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authorized ? "Health Connect Linked!" : "Permission Denied",
            ),
            backgroundColor: authorized ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Health Auth Error: $e");
    }
  }

  void _toggleEditMode() {
    if (_isEditing) {
      _saveProfile();
    }

    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    final viewModel = Provider.of<UserViewModel>(context, listen: false);

    // This updates Supabase, caches it, and mutates the local state immediately
    await viewModel.updateProfileData(
      weight: _tempWeight,
      height: _tempHeight,
    );

    // REMOVED: Redundant _refreshProfileSilently call.
    // The ViewModel already has the latest data.

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

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<UserViewModel>(context);
    final user = viewModel.userProfile;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);
    final surface = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    // Ensures sliders sync to the latest database values if not currently editing
    if (!_isEditing && user != null) {
      _syncTempFromUser(user);

      // REMOVED: The problematic code block that forced a refresh inside build()
      // which often causes infinite rebuild loops in Flutter.
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          "My Profile",
          style: TextStyle(color: text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                onPressed: _toggleEditMode,
                icon: Icon(
                  _isEditing ? Icons.save : Icons.edit,
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
          : user == null
          ? Center(
        child: Text(
          'Could not load profile.',
          style: TextStyle(color: text),
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          await _refreshProfileSilently(user.userId, force: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: surface,
                  child: Icon(Icons.person, size: 50, color: accent),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.username,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
              Text(
                user.email,
                style: TextStyle(
                  fontSize: 14,
                  color: text.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withOpacity(0.2)),
                ),
                child: SelectableText(
                  "UID: ${user.uidText}",
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isEditing
                        ? accent.withOpacity(0.5)
                        : text.withOpacity(0.05),
                    width: _isEditing ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  children: [
                    _buildTile(
                      context,
                      'Gender',
                      user.gender,
                      text,
                      accent,
                    ),
                    _divider(text),
                    _buildTile(
                      context,
                      'Age',
                      '${user.age} years',
                      text,
                      accent,
                    ),
                    _divider(text),
                    _buildTile(
                      context,
                      'Birth Date',
                      user.dateBirth,
                      text,
                      accent,
                    ),
                    _divider(text),
                    _buildHealthConnectTile(text, accent),
                    _divider(text),
                    _buildEditableRow(
                      label: "Height",
                      value: _tempHeight,
                      unit: "cm",
                      min: 100,
                      max: 220,
                      text: text,
                      accent: accent,
                      onChanged: (val) =>
                          setState(() => _tempHeight = val),
                    ),
                    _divider(text),
                    _buildEditableRow(
                      label: "Weight",
                      value: _tempWeight,
                      unit: "kg",
                      min: 30,
                      max: 150,
                      text: text,
                      accent: accent,
                      onChanged: (val) =>
                          setState(() => _tempWeight = val),
                    ),
                    _divider(text),
                    _buildTile(
                      context,
                      'Sleep Goal',
                      TimeFormatter.formatHours(user.sleepGoalHours),
                      text,
                      accent,
                      isHighlight: true,
                    ),
                    _divider(text),
                    _buildTile(
                      context,
                      'Points',
                      '${user.currentPoints} pts',
                      text,
                      accent,
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Text(
                    "Tap the checkmark above to save changes.",
                    style: TextStyle(
                      color: text.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              _buildActionButton(
                context,
                "My Friends",
                Icons.people,
                accent,
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => FriendViewModel(),
                      child: const FriendListScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                "Logout",
                Icons.logout,
                text.withOpacity(0.7),
                    () async => await viewModel.signOut(),
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                context,
                "Delete Account",
                Icons.delete_forever,
                const Color(0xFFEF4444),
                    () => _showDeleteConfirm(context, viewModel),
                isDestructive: true,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthConnectTile(Color text, Color accent) {
    String statusText = _isHealthConnected == null
        ? "Checking..."
        : (_isHealthConnected! ? "Connected" : "Not Connected");

    Color statusColor = _isHealthConnected == null
        ? text.withOpacity(0.5)
        : (_isHealthConnected! ? Colors.green : Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                "Health Connect",
                style: TextStyle(
                  color: text.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isHealthConnected == false && !_isEditing) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: _requestHealthAccess,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sync, size: 16, color: accent),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

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
    if (!_isEditing) {
      return _buildTile(
        context,
        label,
        "${value.toStringAsFixed(1)} $unit",
        text,
        accent,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${value.toStringAsFixed(1)} $unit",
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
              divisions: ((max - min) * 2).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
      BuildContext context,
      String label,
      String value,
      Color text,
      Color accent, {
        bool isHighlight = false,
      }) {
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isHighlight ? accent : text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color text) {
    return Divider(color: text.withOpacity(0.05), thickness: 1, height: 1);
  }

  Widget _buildActionButton(
      BuildContext context,
      String label,
      IconData icon,
      Color color,
      VoidCallback onTap, {
        bool isDestructive = false,
      }) {
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
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
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
        title: Text(
          "Delete Account?",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This is permanent. All sleep logs and points will be erased after 30 days of inactivity.",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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
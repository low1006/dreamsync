import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:health/health.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
// Added AuthViewModel import so we can clear errors safely before navigating
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/views/user_view/friend_list_screen.dart';
import 'package:dreamsync/views/auth_view/reset_password_screen.dart';
import 'package:dreamsync/widget/user/cards/avatar_picker_card.dart';
import 'package:dreamsync/widget/user/profile_action_button.dart';
import 'package:dreamsync/widget/user/profile_avatar_section.dart';
import 'package:dreamsync/widget/user/cards/profile_info_card.dart';
import 'package:dreamsync/widget/custom/user_avatar.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:dreamsync/widget/custom/onboarding_dialog.dart';

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with WidgetsBindingObserver {
  bool _isEditing = false;
  bool _isInit = true;
  bool _isRefreshingProfile = false;
  bool _isLoadingOwnedAvatars = false;

  String? _lastRefreshedUserId;
  String? _selectedAvatarAssetPath;

  late double _tempWeight;
  late double _tempHeight;

  List<String> _availableAvatarPaths = [];

  bool? _isHealthConnected;
  final Health _health = Health();
  final FriendViewModel _friendVM = FriendViewModel();
  final InventoryRepository _inventoryRepository = InventoryRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkHealthStatus();
    _friendVM.addListener(_onFriendVMChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final profileVM = context.read<ProfileViewModel>();
      final userId = profileVM.userProfile?.userId;
      if (userId != null) {
        await _refreshProfileSilently(userId, force: true);
        await _loadAvailableAvatars(userId);
      }
      _friendVM.loadPendingRequestCount();
    });
  }

  @override
  void dispose() {
    _friendVM.removeListener(_onFriendVMChanged);
    _friendVM.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onFriendVMChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      final profileVM = context.read<ProfileViewModel>();
      final userId = profileVM.userProfile?.userId;
      if (userId != null) {
        _refreshProfileSilently(userId, force: true);
        _loadAvailableAvatars(userId);
      }
      _friendVM.loadPendingRequestCount();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final user = context.read<ProfileViewModel>().userProfile;
    if (_isInit) {
      if (user != null) {
        _syncTempFromUser(user);
        _selectedAvatarAssetPath =
            _sanitizeAvatarPath(user.avatarAssetPath) ?? UserAvatar.defaultPath;
        _lastRefreshedUserId = user.userId;
      } else {
        _tempWeight = 70.0;
        _tempHeight = 170.0;
        _selectedAvatarAssetPath = UserAvatar.defaultPath;
      }
      _isInit = false;
    } else if (!_isEditing && user != null) {
      _syncTempFromUser(user);
      _selectedAvatarAssetPath =
          _sanitizeAvatarPath(user.avatarAssetPath) ?? UserAvatar.defaultPath;
    }
  }

  void _syncTempFromUser(UserModel user) {
    _tempWeight = user.weight;
    _tempHeight = user.height;
  }

  String? _sanitizeAvatarPath(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    return path.trim();
  }

  Future<void> _refreshProfileSilently(String userId, {bool force = false}) async {
    if (_isRefreshingProfile) return;
    if (!force && _lastRefreshedUserId == userId) return;

    _isRefreshingProfile = true;
    try {
      await context.read<ProfileViewModel>().fetchProfile(userId);
      _lastRefreshedUserId = userId;
    } finally {
      _isRefreshingProfile = false;
    }
  }

  Future<void> _loadAvailableAvatars(String userId) async {
    if (_isLoadingOwnedAvatars) return;
    setState(() => _isLoadingOwnedAvatars = true);

    try {
      final avatars = await _inventoryRepository.fetchOwnedAvatars(userId);
      if (!mounted) return;

      final purchasedPaths = avatars
          .where((e) => e.assetPath.isNotEmpty)
          .map((e) => e.assetPath)
          .toList();

      final merged = <String>[
        UserAvatar.defaultPath,
        ...purchasedPaths.where((path) => path != UserAvatar.defaultPath),
      ];

      setState(() {
        _availableAvatarPaths = merged;
        _selectedAvatarAssetPath ??=
            _sanitizeAvatarPath(context.read<ProfileViewModel>().userProfile?.avatarAssetPath) ??
                UserAvatar.defaultPath;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingOwnedAvatars = false);
      }
    }
  }

  Future<void> _checkHealthStatus() async {
    final types = [
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_SESSION,
    ];

    try {
      final hasPermissions = await _health.hasPermissions(types);
      if (mounted) {
        setState(() => _isHealthConnected = hasPermissions ?? false);
      }
    } catch (_) {
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
      final authorized = await _health.requestAuthorization(types);
      if (!mounted) return;

      setState(() => _isHealthConnected = authorized);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authorized ? 'Health Connect Linked!' : 'Permission Denied',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {}
  }

  Future<void> _toggleEditMode() async {
    if (_isEditing) {
      await _saveProfile();
      if (!mounted) return;
      setState(() => _isEditing = false);
      return;
    }

    final userId = context.read<ProfileViewModel>().userProfile?.userId;
    if (userId != null) {
      await _loadAvailableAvatars(userId);
    }

    if (!mounted) return;
    setState(() => _isEditing = true);
  }

  Future<void> _saveProfile() async {
    final viewModel = context.read<ProfileViewModel>();

    await viewModel.updateProfileData(
      weight: _tempWeight,
      height: _tempHeight,
    );

    await viewModel.updateAvatar(
      _sanitizeAvatarPath(_selectedAvatarAssetPath) ?? UserAvatar.defaultPath,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openFriends() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => FriendViewModel(),
          child: const FriendListScreen(),
        ),
      ),
    );
    _friendVM.loadPendingRequestCount();
  }

  void _showDeleteConfirm(ProfileViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.card(context),
        title: Text(
          'Delete Account?',
          style: TextStyle(color: AppTheme.text(context), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This is permanent. All sleep logs and points will be erased after 30 days of inactivity.',
          style: TextStyle(
            color: AppTheme.subText(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              viewModel.deleteUserAccount();
              Navigator.pop(context);
            },
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileVM = context.watch<ProfileViewModel>();
    final user = profileVM.userProfile;

    final bg = AppTheme.bg(context);
    final text = AppTheme.text(context);
    final accent = AppTheme.accent;
    final surface = AppTheme.surface(context);

    if (!_isEditing && user != null) {
      _syncTempFromUser(user);
      _selectedAvatarAssetPath =
          _sanitizeAvatarPath(user.avatarAssetPath) ?? UserAvatar.defaultPath;
    }

    final avatarPath =
        _sanitizeAvatarPath(_selectedAvatarAssetPath ?? user?.avatarAssetPath) ??
            UserAvatar.defaultPath;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
        title: Text(
          'My Profile',
          style: TextStyle(color: text, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => OnboardingDialog.show(context),
            icon: Icon(Icons.help_outline, color: AppTheme.subText(context), size: 26),
            tooltip: 'Help & Guide',
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: _toggleEditMode,
                icon: Icon(
                  _isEditing ? Icons.save : Icons.edit,
                  color: accent,
                  size: 28,
                ),
                tooltip: _isEditing ? 'Save Changes' : 'Edit Profile',
              ),
            ),
        ],
      ),
      body: profileVM.isLoading
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
          await _loadAvailableAvatars(user.userId);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ProfileAvatarSection(
                avatarPath: avatarPath,
                username: user.username,
                email: user.email,
                uidText: user.uidText,
                accent: accent,
                surface: surface,
              ),
              if (_isEditing) ...[
                const SizedBox(height: 14),
                AvatarPickerCard(
                  avatarPaths: _availableAvatarPaths,
                  isLoading: _isLoadingOwnedAvatars,
                  selectedAvatarAssetPath: avatarPath,
                  accent: accent,
                  text: text,
                  surface: surface,
                  onAvatarSelected: (path) {
                    setState(() => _selectedAvatarAssetPath = path);
                  },
                ),
              ],
              const SizedBox(height: 24),
              ProfileInfoCard(
                user: user,
                isEditing: _isEditing,
                tempHeight: _tempHeight,
                tempWeight: _tempWeight,
                isHealthConnected: _isHealthConnected,
                text: text,
                accent: accent,
                onHeightChanged: (value) {
                  setState(() => _tempHeight = value);
                },
                onWeightChanged: (value) {
                  setState(() => _tempWeight = value);
                },
                onRequestHealthAccess: _requestHealthAccess,
              ),
              const SizedBox(height: 32),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    'Tap the save icons above to save changes.',
                    style: TextStyle(
                      color: text.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileActionButton(
                    label: 'My Friends',
                    icon: Icons.people,
                    color: accent,
                    isEditing: _isEditing,
                    onTap: _openFriends,
                  ),
                  if (_friendVM.pendingRequestCount > 0)
                    Positioned(
                      right: 12,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          '${_friendVM.pendingRequestCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Change Password Button (CRASH FIX APPLIED HERE) ──
              ProfileActionButton(
                label: 'Change Password',
                icon: Icons.lock_reset,
                color: text.withOpacity(0.7),
                isEditing: _isEditing,
                onTap: () {
                  // 1. Close the keyboard to prevent view overflow errors during pop
                  FocusScope.of(context).unfocus();

                  // 2. Pre-clear state before navigating so we don't accidentally notifyListeners() while returning
                  context.read<AuthViewModel>().clearError();

                  // 3. Force push directly to the root navigator (escapes the bottom tabs to prevent back-stack crashing)
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => const ResetPasswordScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),
              ProfileActionButton(
                label: 'Logout',
                icon: Icons.logout,
                color: text.withOpacity(0.7),
                isEditing: _isEditing,
                onTap: () => profileVM.signOut(),
              ),
              const SizedBox(height: 12),
              ProfileActionButton(
                label: 'Delete Account',
                icon: Icons.delete_forever,
                color: AppTheme.error,
                isEditing: _isEditing,
                isDestructive: true,
                onTap: () => _showDeleteConfirm(profileVM),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
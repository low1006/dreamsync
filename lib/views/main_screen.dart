import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Services (Added PermissionService)
import 'package:dreamsync/services/permission_service.dart';

// Screens
import 'package:dreamsync/views/achievement_view/achievement_screen.dart';
import 'package:dreamsync/views/schedule_view/schedule_screen.dart';
import 'package:dreamsync/views/user_view/user_profile_screen.dart';
import 'package:dreamsync/views/advisor_view/chat_bot_screen.dart';
import 'package:dreamsync/views/sleep_dashboard_view/sleep_dashboard_screen.dart';

// ViewModels
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'package:dreamsync/widget/custom/offline_status_banner.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:dreamsync/widget/custom/onboarding_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;
  bool _hasFetchedInitialData = false;
  bool _hasCheckedOnboarding = false;

  final List<Widget> _pages = const [
    ScheduleScreen(),
    ChatBotScreen(),
    SleepDashboardScreen(),
    AchievementScreen(),
    UserScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NetworkHelper.startMonitoring();
  }

  @override
  void dispose() {
    NetworkHelper.stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasFetchedInitialData) return;

    final profileVM = context.read<ProfileViewModel>();
    final user = profileVM.userProfile;

    if (user == null) return;

    _hasFetchedInitialData = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupSequence(user.userId);
    });
  }

  /// Runs onboarding first (if needed), requests permissions, then prefetches data.
  /// This prevents the onboarding dialog and system permission
  /// dialogs from colliding on first launch.
  Future<void> _startupSequence(String userId) async {
    // Step 1: Show onboarding if first launch (blocks until dismissed)
    await _showOnboardingIfNeeded();

    // Step 2: Request necessary app permissions after onboarding is out of the way
    if (!mounted) return;
    await PermissionService.requestAppStartupPermissions(context);

    // Step 3: Only after onboarding and permissions are done, start data fetch
    if (!mounted) return;
    await _prefetchInitialData(userId);
  }

  Future<void> _prefetchInitialData(String userId) async {
    if (!mounted) return;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await context.read<AchievementViewModel>().fetchUserAchievements(userId);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await context.read<AchievementViewModel>().loadLeaderboard();
    } catch (e) {
      debugPrint("❌ Background prefetch error: $e");
    }
  }

  Future<void> _showOnboardingIfNeeded() async {
    if (_hasCheckedOnboarding) return;
    _hasCheckedOnboarding = true;

    final shouldDisplay = await OnboardingDialog.shouldShow();
    if (!shouldDisplay || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    OnboardingDialog.show(context);
    await OnboardingDialog.markAsSeen();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<ProfileViewModel, dynamic>(
          (vm) => vm.userProfile,
    );

    if (!_hasFetchedInitialData && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasFetchedInitialData) return;

        _hasFetchedInitialData = true;
        _startupSequence(user.userId);
      });
    }

    final bg = AppTheme.bg(context);
    final accent = AppTheme.accent;
    final unselected = AppTheme.subText(context);

    return Scaffold(
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: bg,
        selectedItemColor: accent,
        unselectedItemColor: unselected,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'Advisor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bedtime_outlined),
            activeIcon: Icon(Icons.bedtime),
            label: 'Sleep',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Achievements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
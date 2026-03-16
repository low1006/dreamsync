import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens
import 'package:dreamsync/views/achievement_screen.dart';
import 'package:dreamsync/views/schedule_screen.dart';
import 'package:dreamsync/views/user_screen/user_profile_screen_view.dart';
import 'package:dreamsync/views/advisor_screen/chat_bot_screen.dart';
import 'package:dreamsync/views/sleep_dashboard_screen/sleep_dashboard_screen_view.dart';

// ViewModels
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;
  bool _hasFetchedInitialData = false;

  final List<Widget> _pages = const [
    ScheduleScreen(),
    ChatScreen(),
    SleepDashboardScreen(),
    AchievementScreen(),
    UserScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasFetchedInitialData) return;

    final profileVM = context.read<UserViewModel>();
    final user = profileVM.userProfile;

    if (user == null) return;

    _hasFetchedInitialData = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchInitialData(user.userId);
    });
  }

  Future<void> _prefetchInitialData(String userId) async {
    if (!mounted) return;

    debugPrint("🚀 Background prefetch started...");

    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await context.read<AchievementViewModel>().fetchUserAchievements(userId);

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      await context.read<FriendViewModel>().loadLeaderboard();

      debugPrint("✅ Background prefetch completed.");
    } catch (e) {
      debugPrint("❌ Background prefetch error: $e");
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<UserViewModel, dynamic>(
          (vm) => vm.userProfile,
    );

    if (!_hasFetchedInitialData && user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasFetchedInitialData) return;

        _hasFetchedInitialData = true;
        _prefetchInitialData(user.userId);
      });
    }

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E3A8A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
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
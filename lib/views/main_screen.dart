import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens
import 'package:dreamsync/views/achievement_view/achievement_screen.dart';
import 'package:dreamsync/views/schedule_view/schedule_screen.dart';
import 'package:dreamsync/views/user_view/user_profile_screen.dart';
import 'package:dreamsync/views/advisor_view/chat_bot_screen.dart';
import 'package:dreamsync/views/sleep_dashboard_view/sleep_dashboard_screen.dart';

// ViewModels
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';
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

    final profileVM = context.read<ProfileViewModel>();
    final user = profileVM.userProfile;

    if (user == null) return;

    _hasFetchedInitialData = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchInitialData(user.userId);
    });
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
        _prefetchInitialData(user.userId);
      });
    }

    // ✅ Match exact Achievement Screen logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final accent = const Color(0xFF3B82F6);
    final unselected = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      body: _pages[_selectedIndex],
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
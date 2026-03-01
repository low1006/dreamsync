import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // NEW: Imported provider

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
import 'package:dreamsync/viewmodels/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 2;

  // NEW: Flag to make sure we only fetch data ONCE when they log in
  bool _hasFetchedInitialData = false;

  final List<Widget> _pages = [
    const ScheduleScreen(),
    const ChatScreen(),
    const SleepDashboardScreen(),
    const AchievementScreen(),
    const UserScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Watch for the user profile to finish loading
    final profileVM = context.watch<UserViewModel>();
    final user = profileVM.userProfile;

    // NEW: If user exists and we haven't fetched yet, trigger everything!
    if (user != null && !_hasFetchedInitialData) {
      _hasFetchedInitialData = true; // Lock it so it doesn't run again

      WidgetsBinding.instance.addPostFrameCallback((_) {
        print("🚀 BACKGROUND FETCH: Loading all app data now...");

        // 1. Fetch Achievements & Leaderboard in the background
        context.read<AchievementViewModel>().fetchUserAchievements(user.userId);
        context.read<FriendViewModel>().loadLeaderboard();

        // 2. You can also pre-fetch Schedule or Inventory here!
        // (Uncomment these if you have fetch functions inside them)
        // context.read<ScheduleViewModel>().fetchSchedule(user.userId);
        // context.read<InventoryViewModel>().fetchInventory(user.userId);
      });
    }

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E3A8A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_outlined),
            activeIcon: Icon(Icons.verified),
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
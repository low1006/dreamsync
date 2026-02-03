import 'package:flutter/material.dart';
import 'package:dreamsync/views/achievement_screen.dart';
// Import other screens here as you build them
// import 'package:dreamsync/views/calendar_screen.dart';
// import 'package:dreamsync/views/home_screen.dart';
// import 'package:dreamsync/views/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 1. Track which tab is currently selected
  int _selectedIndex = 2; // Default to index 2 (Home) - change if you want

  // 2. Define your list of pages
  // We use "Placeholder" widgets for pages you haven't built yet
  final List<Widget> _pages = [
    const Center(child: Text("Calendar Screen")), // Index 0
    const Center(child: Text("AI Chat Screen")),  // Index 1
    const Center(child: Text("Home Screen")),     // Index 2
    const AchievementScreen(),                    // Index 3 (Your actual Achievement Screen!)
    const ProfileScreenPlaceholder(),             // Index 4 (The Profile UI from your image)
  ];

  // 3. Function to handle tapping a tab
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 4. The Body switches based on the index
      body: _pages[_selectedIndex],

      // 5. The Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Required for 4+ items
        backgroundColor: const Color(0xFF1E3A8A), // Dark Blue from your theme
        selectedItemColor: Colors.white,          // Color of the active icon
        unselectedItemColor: Colors.white60,      // Color of inactive icons
        showSelectedLabels: false,                // Hide text labels (like your design)
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          // Index 0: Calendar
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          // Index 1: Robot/Chat
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'Chat',
          ),
          // Index 2: Home
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          // Index 3: Achievement (The Ribbon/Medal)
          BottomNavigationBarItem(
            icon: Icon(Icons.verified_outlined), // Or Icons.emoji_events
            activeIcon: Icon(Icons.verified),
            label: 'Achievements',
          ),
          // Index 4: Profile
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

// Temporary Placeholder for your Profile Screen (to match your image)
class ProfileScreenPlaceholder extends StatelessWidget {
  const ProfileScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            const Text("NAME", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("UID: 123456"),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Deactivate Account", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
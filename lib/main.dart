import 'dart:convert'; // Add this import
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/util/global.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ViewModels
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';

// Screens
import 'package:dreamsync/views/auth_screen/login_screen.dart';
import 'package:dreamsync/views/main_screen.dart';
import 'package:dreamsync/views/alarm_ring_screen.dart';

const String supabaseURL = 'https://xagpcogenalviktbsmap.supabase.co';
const String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhhZ3Bjb2dlbmFsdmlrdGJzbWFwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjgzMTQxNDksImV4cCI6MjA4Mzg5MDE0OX0.8IrDPy-BYywk6A53q6M7gSSEdDqwNK6x6f-TYG93rds';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: supabaseURL, anonKey: supabaseKey);
  await AndroidAlarmManager.initialize();
  await NotificationService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    _checkNotificationLaunch();

    NotificationService().onAlarmFired.listen((payload) {
      _navigateToAlarm(payload);
    });
  }

  void _navigateToAlarm(String? payload) {
    if (payload == null) return;

    int id = 0;
    bool isSmartAlarm = false;
    bool isSnoozeOn = true;
    int snoozeCount = 0;
    String soundFile = "classic.mp3";

    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      id = data['id'];
      isSmartAlarm = data['isSmartAlarm'] ?? false;
      isSnoozeOn = data['isSnoozeOn'] ?? true;
      snoozeCount = data['snoozeCount'] ?? 0;
      soundFile = data['soundFile'] ?? "classic.mp3"; // <--- Parse sound
    } catch (e) {
      id = int.tryParse(payload) ?? 0;
    }

    navigatorKey.currentState?.pushNamed('/alarm_ring', arguments: {
      'id': id,
      'isSmartAlarm': isSmartAlarm,
      'isSnoozeOn': isSnoozeOn,
      'snoozeCount': snoozeCount,
      'soundFile': soundFile,
    });
  }

  Future<void> _checkNotificationLaunch() async {
    final NotificationAppLaunchDetails? details =
    await NotificationService().flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (details != null && details.didNotificationLaunchApp) {
      String? payload = details.notificationResponse?.payload;
      // Delay needed for context to be ready
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToAlarm(payload);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DreamSync',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      routes: {
        '/alarm_ring': (context) => const AlarmRingScreen(),
      },

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFF3B82F6),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFF3B82F6),
        ),
      ),

      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final session = snapshot.data?.session;

          if (session != null) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => UserViewModel()..fetchProfile(session.user.id)),
                ChangeNotifierProvider(create: (_) => AchievementViewModel()),
                ChangeNotifierProvider(create: (_) => ScheduleViewModel()),
                ChangeNotifierProvider(create: (_) => InventoryViewModel()),
              ],
              child: const MainScreen(),
            );
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
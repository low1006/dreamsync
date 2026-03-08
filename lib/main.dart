import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async'; // Required for StreamSubscription
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/util/global.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ViewModels
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/friend_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';

// Repositories for Syncing
import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/repositories/schedule_repository.dart';
import 'package:dreamsync/repositories/user_achievement_repository.dart';
// Note: Ensure you have your other repositories imported here if you created sync methods for them

// Screens
import 'package:dreamsync/views/auth_screen/login_screen.dart';
import 'package:dreamsync/views/main_screen.dart';
import 'package:dreamsync/views/alarm_ring_screen.dart';


// 🔥 GLOBAL MESSENGER: Allows SnackBars to show anywhere across the app
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load the .env file
  try {
    await dotenv.load(fileName: ".env");
    print("✅ .env loaded. Keys found: ${dotenv.env.keys}");
  } catch (e) {
    print("❌ Error loading .env: $e");
  }

  // 2. Initialize Supabase using the loaded keys
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // If this prints 'null', your .env file is empty or keys are named differently
  print("Supabase URL: ${dotenv.env['SUPABASE_URL']}");



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
  // 🔥 Variables for internet tracking
  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationLaunch();

    NotificationService().onAlarmFired.listen((payload) {
      _navigateToAlarm(payload);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAllPermissions();
    });

    // 🔥 Check internet right at launch
    Connectivity().checkConnectivity().then(_updateConnectionStatus);

    // 🔥 Continuously listen for network changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // 🔥 Logic for handling network state changes and global syncing
  void _updateConnectionStatus(ConnectivityResult result) {
    bool offline = result == ConnectivityResult.none;

    // Only trigger if state actually changes
    if (offline != _isOffline) {
      setState(() { _isOffline = offline; });

      // Hide previous snackbars
      rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();

      if (offline) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('📴 Offline Mode. Data will sync later.')),
              ],
            ),
            backgroundColor: Colors.redAccent,
            duration: Duration(days: 365), // Persists until internet returns
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi, color: Colors.white),
                SizedBox(width: 10),
                Text('🌐 Internet restored! Syncing data...'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 🔥 Trigger all offline data pushes to Supabase here!
        debugPrint("🌐 Triggering global background sync...");
        SleepRepository().syncOfflineData();
        ScheduleRepository().syncOfflineData();
        UserAchievementRepository(Supabase.instance.client).syncOfflineData();
        // DailyActivityRepository().syncOfflineData(); // Uncomment if you made this repo
      }
    }
  }

  Future<void> _requestAllPermissions() async {
    await Future.delayed(const Duration(seconds: 1));
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final Health _health = Health();
    final types = [HealthDataType.SLEEP_SESSION];

    bool? hasHealthPermissions = await _health.hasPermissions(types);
    if (hasHealthPermissions == null || !hasHealthPermissions) {
      try {
        await _health.requestAuthorization(types);
      } catch (e) {
        debugPrint("Health Connect Error: $e");
      }
    }

    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }

    if (Platform.isAndroid) {
      if (await Permission.scheduleExactAlarm.isDenied) {
        bool? goToSettings = await _showExplanationBottomSheet(
          context,
          "Exact Alarms Required",
          "To ensure your alarm rings exactly on time, we need this permission. Please allow it on the next screen.",
        );
        if (goToSettings == true) await Permission.scheduleExactAlarm.request();
      }

      if (await Permission.systemAlertWindow.isDenied) {
        bool? goToSettings = await _showExplanationBottomSheet(
          context,
          "Display Over Other Apps",
          "We need this to wake your screen up and show the alarm when your phone is locked. Please allow it on the next screen.",
        );
        if (goToSettings == true) await Permission.systemAlertWindow.request();
      }

      bool hasDnd = await NotificationService().hasDndAccess();
      if (!hasDnd) {
        bool? goToSettings = await _showExplanationBottomSheet(
          context,
          "Do Not Disturb Access",
          "To automatically silence distractions during bedtime, we need Do Not Disturb access. Please allow it on the next screen.",
        );
        if (goToSettings == true) await NotificationService().openDndSettings();
      }
    }
  }

  Future<bool?> _showExplanationBottomSheet(BuildContext context, String title, String content) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.settings_suggest, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Go To Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Maybe Later", style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
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
      soundFile = data['soundFile'] ?? "classic.mp3";
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
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToAlarm(payload);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey, // 🔥 Attach Global Messenger Key
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
                ChangeNotifierProvider(create: (_) => SleepViewModel()),
                ChangeNotifierProvider(create: (_) => ScheduleViewModel()),
                ChangeNotifierProvider(create: (_) => InventoryViewModel()),
                ChangeNotifierProvider(create: (_) => FriendViewModel()),
                ChangeNotifierProvider(create: (_) => DailyActivityViewModel()),
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
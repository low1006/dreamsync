import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

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
import 'package:dreamsync/viewmodels/recommendation_viewmodel.dart';
import 'package:dreamsync/viewmodels/reward_store_viewmodel.dart';

// Repositories
import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/repositories/schedule_repository.dart';
import 'package:dreamsync/repositories/achievement_repository.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';
import 'package:dreamsync/repositories/user_repository.dart';

// Screens
import 'package:dreamsync/views/auth_screen/login_screen.dart';
import 'package:dreamsync/views/main_screen.dart';
import 'package:dreamsync/views/alarm_ring_screen.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ .env loaded. Keys found: ${dotenv.env.keys}");
  } catch (e) {
    debugPrint("❌ Error loading .env: $e");
  }

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  debugPrint("Supabase URL: ${dotenv.env['SUPABASE_URL']}");

  await AndroidAlarmManager.initialize();
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => UserViewModel()),
        ChangeNotifierProvider(create: (_) => AchievementViewModel()),
        ChangeNotifierProvider(create: (_) => SleepViewModel()),
        ChangeNotifierProvider(create: (_) => ScheduleViewModel()),
        ChangeNotifierProvider(create: (_) => InventoryViewModel()),
        ChangeNotifierProvider(create: (_) => FriendViewModel()),
        ChangeNotifierProvider(create: (_) => DailyActivityViewModel()),
        ChangeNotifierProvider(create: (_) => RecommendationViewModel()),
        ChangeNotifierProvider(
          create: (_) => RewardStoreViewModel(
            inventoryRepository: InventoryRepository(),
            userRepository: UserRepository(),
          ),
        ),
      ],
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
  late final StreamSubscription<ConnectivityResult> _connectivitySubscription;
  late final StreamSubscription<String?> _alarmSubscription;

  bool _isOffline = false;
  bool _isSyncing = false;
  String? _lastFetchedUserId;

  @override
  void initState() {
    super.initState();

    _checkNotificationLaunch();

    _alarmSubscription = NotificationService().onAlarmFired.listen((payload) {
      _navigateToAlarm(payload);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestAllPermissions();
    });

    Connectivity().checkConnectivity().then(_updateConnectionStatus);
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _alarmSubscription.cancel();
    super.dispose();
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final offline = result == ConnectivityResult.none;

    if (offline != _isOffline) {
      setState(() {
        _isOffline = offline;
      });

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
            duration: Duration(days: 365),
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
                Expanded(child: Text('🌐 Internet restored! Syncing data...')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        _runBackgroundSync();
      }
    }
  }

  Future<void> _runBackgroundSync() async {
    if (_isSyncing) {
      debugPrint("⏳ Sync already running. Skipping duplicate trigger.");
      return;
    }

    _isSyncing = true;

    try {
      debugPrint("🌐 Triggering global background sync...");

      await Future<void>.delayed(const Duration(milliseconds: 150));
      await SleepRepository().syncOfflineData();

      await Future<void>.delayed(const Duration(milliseconds: 250));
      await ScheduleRepository().syncOfflineData();

      await Future<void>.delayed(const Duration(milliseconds: 250));
      await AchievementRepository().syncOfflineAchievements();

      debugPrint("✅ Background sync completed.");
    } catch (e) {
      debugPrint("❌ Background sync error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _requestAllPermissions() async {
    await Future.delayed(const Duration(seconds: 1));

    final context = navigatorKey.currentContext;
    if (context == null) return;

    final health = Health();

    final types = <HealthDataType>[
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_ASLEEP,
    ];

    final permissions = List<HealthDataAccess>.filled(
      types.length,
      HealthDataAccess.READ,
    );

    try {
      final status = await health.getHealthConnectSdkStatus();

      if (status == HealthConnectSdkStatus.sdkAvailable) {
        final hasHealthPermissions = await health.hasPermissions(
          types,
          permissions: permissions,
        );

        if (hasHealthPermissions != true) {
          await health.requestAuthorization(
            types,
            permissions: permissions,
          );
        }
      } else {
        debugPrint("⚠️ Health Connect not available: $status");
      }
    } catch (e) {
      debugPrint("❌ Health Connect Error: $e");
    }

    try {
      if (await Permission.activityRecognition.isDenied) {
        await Permission.activityRecognition.request();
      }
    } catch (e) {
      debugPrint("❌ Activity recognition permission error: $e");
    }

    if (Platform.isAndroid) {
      try {
        if (await Permission.scheduleExactAlarm.isDenied) {
          final goToSettings = await _showExplanationBottomSheet(
            context,
            "Exact Alarms Required",
            "To ensure your alarm rings exactly on time, we need this permission. Please allow it on the next screen.",
          );

          if (goToSettings == true) {
            await Permission.scheduleExactAlarm.request();
          }
        }
      } catch (e) {
        debugPrint("❌ Exact alarm permission error: $e");
      }

      try {
        if (await Permission.systemAlertWindow.isDenied) {
          final goToSettings = await _showExplanationBottomSheet(
            context,
            "Display Over Other Apps",
            "We need this to wake your screen up and show the alarm when your phone is locked. Please allow it on the next screen.",
          );

          if (goToSettings == true) {
            await Permission.systemAlertWindow.request();
          }
        }
      } catch (e) {
        debugPrint("❌ Overlay permission error: $e");
      }

      try {
        final hasDnd = await NotificationService().hasDndAccess();
        if (!hasDnd) {
          final goToSettings = await _showExplanationBottomSheet(
            context,
            "Do Not Disturb Access",
            "To automatically silence distractions during bedtime, we need Do Not Disturb access. Please allow it on the next screen.",
          );

          if (goToSettings == true) {
            await NotificationService().openDndSettings();
          }
        }
      } catch (e) {
        debugPrint("❌ DND permission error: $e");
      }
    }
  }

  Future<bool?> _showExplanationBottomSheet(
      BuildContext context,
      String title,
      String content,
      ) {
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
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
                child: const Text(
                  "Go To Settings",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Maybe Later",
                  style: TextStyle(color: Colors.grey),
                ),
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
      id = data['id'] ?? 0;
      isSmartAlarm = data['isSmartAlarm'] ?? false;
      isSnoozeOn = data['isSnoozeOn'] ?? true;
      snoozeCount = data['snoozeCount'] ?? 0;
      soundFile = data['soundFile'] ?? "classic.mp3";
    } catch (e) {
      id = int.tryParse(payload) ?? 0;
    }

    navigatorKey.currentState?.pushNamed(
      '/alarm_ring',
      arguments: {
        'id': id,
        'isSmartAlarm': isSmartAlarm,
        'isSnoozeOn': isSnoozeOn,
        'snoozeCount': snoozeCount,
        'soundFile': soundFile,
      },
    );
  }

  Future<void> _checkNotificationLaunch() async {
    final NotificationAppLaunchDetails? details = await NotificationService()
        .flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();

    if (details != null && details.didNotificationLaunchApp) {
      final payload = details.notificationResponse?.payload;
      Future.delayed(const Duration(milliseconds: 500), () {
        _navigateToAlarm(payload);
      });
    }
  }

  void _ensureProfileLoaded(String userId) {
    if (_lastFetchedUserId == userId) return;
    _lastFetchedUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserViewModel>().fetchProfile(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
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
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final session = snapshot.data?.session;

          if (session != null) {
            _ensureProfileLoaded(session.user.id);
            return const MainScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
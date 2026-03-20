import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'package:dreamsync/services/permission_service.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/util/global.dart';

import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/auth_viewmodel.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/recommendation_viewmodel.dart';
import 'package:dreamsync/viewmodels/advisor_viewmodel/chat_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/reward_store_viewmodel.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';
import 'package:dreamsync/repositories/user_repository.dart';

import 'package:dreamsync/views/schedule_view/alarm_ring_screen.dart';
import 'package:dreamsync/views/main_screen.dart';
import 'package:dreamsync/views/auth_view/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await AndroidAlarmManager.initialize();
  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => AchievementViewModel()),
        ChangeNotifierProvider(create: (_) => ScheduleViewModel()),
        ChangeNotifierProvider(create: (_) => InventoryViewModel()),
        ChangeNotifierProvider(create: (_) => SleepViewModel()),
        ChangeNotifierProvider(create: (_) => DailyActivityViewModel()),
        ChangeNotifierProvider(create: (_) => RecommendationViewModel()),
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
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
  StreamSubscription<String>? _alarmSubscription;
  bool _alarmScreenOpen = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionService.requestAppStartupPermissions(context);
      await _setupAlarmNavigation();
    });
  }

  Future<void> _setupAlarmNavigation() async {
    final notificationService = NotificationService();

    final initialPayload = await notificationService.getLaunchPayload();
    if (initialPayload != null && initialPayload.isNotEmpty) {
      _openAlarmScreen(initialPayload);
    }

    _alarmSubscription?.cancel();
    _alarmSubscription = notificationService.onAlarmFired.listen((payload) {
      _openAlarmScreen(payload);
    });
  }

  void _openAlarmScreen(String payload) {
    if (_alarmScreenOpen) return;

    try {
      final Map<String, dynamic> args =
      jsonDecode(payload) as Map<String, dynamic>;

      _alarmScreenOpen = true;

      navigatorKey.currentState
          ?.pushNamed('/alarm_ring', arguments: args)
          .then((_) {
        _alarmScreenOpen = false;
      });
    } catch (e) {
      debugPrint('Failed to parse alarm payload: $e');
      _alarmScreenOpen = false;
    }
  }

  void _ensureProfileLoaded(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final profileVM = Provider.of<ProfileViewModel>(context, listen: false);
      if (profileVM.userProfile == null) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          profileVM.fetchProfile(userId);
        }
      }
    });
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dreamSyncAccent = Color(0xFF3B82F6);

    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'DreamSync',

      theme: ThemeData(
        useMaterial3: true,
        primaryColor: dreamSyncAccent,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: dreamSyncAccent,
          primary: dreamSyncAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          centerTitle: true,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: dreamSyncAccent,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: dreamSyncAccent,
          primary: dreamSyncAccent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system,

      routes: {
        '/alarm_ring': (context) => const AlarmRingScreen(),
      },
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;

          if (session != null) {
            _ensureProfileLoaded(context);
            return const MainScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
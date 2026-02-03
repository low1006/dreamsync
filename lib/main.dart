import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORTS FOR VIEWMODELS ---
import 'viewmodels/user_viewmodel.dart';
import 'viewmodels/achievement_viewmodel.dart';

// --- IMPORTS FOR SCREENS ---
import 'views/auth_screen/login_screen.dart';
import 'views/user_profile_screen_view.dart';
import 'views/achievement_screen.dart';
import 'views/main_screen.dart';

const String supabaseURL = 'https://xagpcogenalviktbsmap.supabase.co';
// ⚠️ SECURITY WARNING: Avoid putting 'sb_secret' keys in client-side code.
// Use the 'anon' public key starting with 'eyJ...' for Flutter apps.
const String supabaseKey = 'sb_secret_dO-O0OWnCTpUeymnCgF6RA_Pvu5dnoF';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseURL, anonKey: supabaseKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamSync',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // --- LIGHT THEME ---
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        cardColor: const Color(0xFFF1F5F9),
        primaryColor: const Color(0xFF1E3A8A),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFFF8FAFC),
          onSurface: Color(0xFF1E293B),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
          titleTextStyle: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 20,
              fontWeight: FontWeight.bold
          ),
        ),
      ),

      // --- DARK THEME ---
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        primaryColor: const Color(0xFF1E3A8A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFF3B82F6),
          surface: Color(0xFF1E293B),
          onSurface: Color(0xFFF1F5F9),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
          titleTextStyle: TextStyle(
              color: Color(0xFFF1F5F9),
              fontSize: 20,
              fontWeight: FontWeight.bold
          ),
        ),
      ),

      // --- AUTH FLOW ---
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
            return MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => UserViewModel()..fetchProfile(session.user.id),
                ),
                ChangeNotifierProvider(
                  create: (_) => AchievementViewModel(),
                ),
              ],
              // CHANGE THIS: Point to MainScreen instead of AchievementScreen
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
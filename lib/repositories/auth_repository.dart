import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  // Defaults to Supabase.instance.client so the ViewModel doesn't have to pass it
  AuthRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // LOGIN & AUTO-RESTORE
  // ---------------------------------------------------------------------------
  Future<void> signInWithPasswordAndRestore(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
          email: email,
          password: password
      );

      final userId = response.user?.id;

      if (userId != null) {
        try {
          // Check if the account was pending deletion
          final row = await _client
              .from('profile')
              .select('deleted_at')
              .eq('user_id', userId)
              .maybeSingle();

          if (row != null && row['deleted_at'] != null) {
            debugPrint("🔄 Pending deletion detected — auto-restoring account...");
            await _client.rpc('restore_deleted_account');
            debugPrint("✅ Account auto-restored successfully");
          }
        } catch (e) {
          debugPrint("❌ handleSoftDelete error: $e");
        }
      }
    } on AuthException catch (e) {
      // We attach a specific tag so the ViewModel knows it's an Auth error
      // (like wrong password) vs a general network error
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // REQUEST ACCOUNT DELETION
  // ---------------------------------------------------------------------------
  Future<void> requestAccountDeletion() async {
    await _client.rpc('delete_user_account');
    await _client.auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // SEND OTP
  // ---------------------------------------------------------------------------
  Future<void> sendVerificationOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
          email: email,
          shouldCreateUser: true
      );
    } on AuthException catch (e) {
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // VERIFY OTP & CREATE PROFILE
  // ---------------------------------------------------------------------------
  Future<void> verifyOtpAndRegister({
    required String email,
    required String token,
    required String password,
    required String username,
    required String gender,
    required String dateBirth,
    required double weight,
    required double height,
    required double sleepGoal,
  }) async {
    try {
      final verifyResponse = await _client.auth.verifyOTP(
          token: token,
          type: OtpType.email,
          email: email
      );

      if (verifyResponse.session == null) {
        throw Exception("Invalid OTP code. Please try again.");
      }

      final userId = verifyResponse.user!.id;

      // Update auth user with their actual password
      await _client.auth.updateUser(UserAttributes(password: password));

      // Create their profile record
      await _client.from('profile').upsert({
        'user_id': userId,
        'username': username,
        'email': email,
        'gender': gender,
        'date_birth': dateBirth,
        'weight': weight,
        'height': height,
        'sleep_goal_hours': sleepGoal,
        'streak': 0,
        'current_points': 0,
        'deleted_at': null,
      });

    } on AuthException catch (e) {
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
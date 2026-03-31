import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<void> signInWithPasswordAndRestore(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;

      if (userId != null) {
        try {
          final row = await _client
              .from('profile')
              .select('deleted_at')
              .eq('user_id', userId)
              .maybeSingle();

          if (row != null && row['deleted_at'] != null) {
            debugPrint("🔄 Pending deletion detected — auto-restoring account.");
            await _client.rpc('restore_deleted_account');
            debugPrint("✅ Account auto-restored successfully");
          }
        } catch (e) {
          debugPrint("❌ handleSoftDelete error: $e");
        }
      }
    } on AuthException catch (e) {
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> requestAccountDeletion() async {
    await _client.rpc('delete_user_account');
    await _client.auth.signOut();
  }

  Future<void> sendVerificationOtp({required String email, required String password}) async {
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('user already registered')) {
        throw Exception("AUTH_ERROR:An account with this email already exists. Please login.");
      }
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> resendSignupOtp({required String email}) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
    } on AuthException catch (e) {
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

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
        token: token.trim(),
        type: OtpType.signup,
        email: email.trim(),
      );

      if (verifyResponse.session == null) {
        throw Exception("Invalid OTP code. Please try again.");
      }

      final userId = verifyResponse.user!.id;

      await _client.from('profile').upsert({
        'user_id': userId,
        'username': username,
        'email': email.trim(),
        'gender': gender,
        'date_birth': dateBirth,
        'weight': weight,
        'height': height,
        'sleep_goal_hours': sleepGoal,
        'streak': 0,
        'current_points': 0,
        'deleted_at': null,
        'avatar_asset_path': 'assets/images/avatar/default_avatar.jpg',
      });
    } on AuthException catch (e) {
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> sendPasswordResetOtp(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (e) {
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> verifyResetOtpAndUpdatePassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final verifyResponse = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.recovery,
      );

      if (verifyResponse.session == null) {
        throw Exception("Invalid reset OTP code. Please try again.");
      }

      try {
        await _client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
      } on AuthException catch (e) {
        // 🔴 FIX: Explicitly catch the "same password" error and send it to the UI
        if (e.message.toLowerCase().contains("different from the old password") ||
            e.message.toLowerCase().contains("should be different")) {
          throw Exception("AUTH_ERROR:New password must be different from your old password.");
        } else {
          rethrow;
        }
      }

      // Ensures the user is logged out after a password change to force re-authentication
      await _client.auth.signOut();

    } on AuthException catch (e) {
      throw Exception("AUTH_ERROR:${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  late final UserRepository _repository = UserRepository(_client);

  bool isLoading = false;
  String? errorMessage;
  bool _isDisposed = false;

  // --- Login Attempt Tracking ---
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 3);

  // --- Registration Form Properties ---
  double weight = 70.0;
  double height = 175.0;
  double sleepGoal = 8.0;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return;
    isLoading = loading;
    if (loading) errorMessage = null;
    notifyListeners();
  }

  void _setError(String? message) {
    if (_isDisposed) return;
    errorMessage = message;
    notifyListeners();
  }

  void updateAttribute(String attribute, double value) {
    if (attribute == 'weight') weight = value;
    else if (attribute == 'height') height = value;
    else if (attribute == 'sleepGoal') sleepGoal = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // LOGIN
  //
  // Two scenarios:
  //
  // 1. Login within 30 days of deletion request:
  //    → signInWithPassword succeeds
  //    → _handleSoftDelete detects deleted_at, auto-restores via RPC
  //    → user enters app normally
  //
  // 2. Login after 30 days:
  //    → cron job already deleted auth.users row
  //    → signInWithPassword FAILS with AuthException
  //    → "Invalid email or password" shown
  //    → never reaches _handleSoftDelete
  // ---------------------------------------------------------------------------
  Future<void> signIn(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check persisted lockout
    final lockoutTimestamp = prefs.getInt('lockout_timestamp');
    if (lockoutTimestamp != null) {
      final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
      if (DateTime.now().isBefore(lockoutTime)) {
        final remaining = lockoutTime.difference(DateTime.now());
        final minutesLeft = remaining.inMinutes + 1;
        _setError("Too many failed attempts. Try again in $minutesLeft minutes.");
        return;
      } else {
        await prefs.remove('lockout_timestamp');
        _failedAttempts = 0;
      }
    }

    _setLoading(true);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      _failedAttempts = 0;
      await prefs.remove('lockout_timestamp');

      // 2. Auto-restore if account was pending deletion
      await _handleSoftDelete(response.user?.id);

      // 3. Auth state listener fires → navigates to home

    } on AuthException catch (_) {
      // Covers both wrong password AND permanently deleted accounts
      // (deleted accounts no longer exist in auth.users after 30 days)
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        final lockoutTime = DateTime.now().add(_lockoutDuration);
        await prefs.setInt(
            'lockout_timestamp', lockoutTime.millisecondsSinceEpoch);
        _setError("Too many failed attempts. You are blocked for 3 minutes.");
      } else {
        _setError("Invalid email or password.");
      }
    } catch (e) {
      _setError(e.toString());
    }
    _setLoading(false);
  }

  // ---------------------------------------------------------------------------
  // _handleSoftDelete
  //
  // Only runs when signInWithPassword already SUCCEEDED — meaning the user
  // still exists in auth.users (i.e. within the 30-day grace window).
  //
  // If deleted_at is set → auto-restore silently and let them in.
  // If deleted_at is null → normal account, do nothing.
  //
  // The "after 30 days" case is never reached here because the cron job
  // deletes auth.users first, causing signInWithPassword to fail above.
  // ---------------------------------------------------------------------------
  Future<void> _handleSoftDelete(String? userId) async {
    if (userId == null) return;

    try {
      final row = await _client
          .from('profile')
          .select('deleted_at')
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint("🔍 _handleSoftDelete row: $row");

      // No deleted_at → active account, nothing to do
      if (row == null || row['deleted_at'] == null) return;

      // deleted_at is set → user logged in within 30-day grace period
      // Auto-restore their account silently
      debugPrint("🔄 Pending deletion detected — auto-restoring account...");
      await _client.rpc('restore_deleted_account');
      debugPrint("✅ Account auto-restored successfully");

    } catch (e) {
      // Non-fatal: log but allow login to proceed
      debugPrint("❌ _handleSoftDelete error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // REQUEST ACCOUNT DELETION  (called from settings / account screen)
  // Sets deleted_at via RPC then signs out.
  // Cron job hard-deletes after 30 days automatically.
  // ---------------------------------------------------------------------------
  Future<bool> requestAccountDeletion() async {
    _setLoading(true);
    try {
      await _client.rpc('delete_user_account');
      _setLoading(false);
      await _client.auth.signOut();
      return true;
    } catch (e) {
      debugPrint("Request deletion failed: $e");
      _setError("Failed to request account deletion.");
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // REGISTRATION STEP 1: Send OTP
  // ---------------------------------------------------------------------------
  Future<bool> sendVerificationOtp(String email) async {
    _setLoading(true);
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      );
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to send OTP.');
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // REGISTRATION STEP 2: Verify OTP → set password → upsert profile
  // ---------------------------------------------------------------------------
  Future<bool> verifyOtpAndRegister({
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
    _setLoading(true);
    try {
      final verifyResponse = await _client.auth.verifyOTP(
        token: token.trim(),
        type: OtpType.email,
        email: email.trim(),
      );

      if (verifyResponse.session == null) {
        _setError("Invalid OTP code. Please try again.");
        _setLoading(false);
        return false;
      }

      final userId = verifyResponse.user!.id;

      await _client.auth.updateUser(
        UserAttributes(password: password),
      );

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
        'uid_text': userId.substring(0, 8),
        'deleted_at': null,
      });

      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError('Auth: ${e.message} (${e.statusCode})');
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Registration failed. Please try again.');
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // RESEND OTP
  // ---------------------------------------------------------------------------
  Future<void> resendOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      );
    } catch (e) {
      _setError("Failed to resend OTP.");
    }
  }

  // ---------------------------------------------------------------------------
  // VALIDATION HELPERS
  // ---------------------------------------------------------------------------
  String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a username';
    if (value.length < 3) return 'Username is too short';
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(
        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Must contain a lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    if (!value.contains(RegExp(r'[!@#\$&*~^%(),.?":{}|<>]'))) {
      return 'Must contain a symbol';
    }
    return null;
  }

  String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != originalPassword) return 'Passwords do not match';
    return null;
  }

  String? validateGender(String? value) {
    if (value == null || value.isEmpty) return 'Please select a gender';
    return null;
  }

  String? validateDateBirth(String? value) {
    if (value == null || value.isEmpty) return 'Please select a date of birth';
    try {
      final birthDate = DateTime.parse(value);
      final today = DateTime.now();
      if (birthDate.isAfter(today)) return 'Date cannot be in the future';
      final twelveYearsAgo =
      DateTime(today.year - 12, today.month, today.day);
      if (birthDate.isAfter(twelveYearsAgo)) {
        return 'You must be at least 12 years old';
      }
    } catch (e) {
      return 'Invalid date format';
    }
    return null;
  }
}
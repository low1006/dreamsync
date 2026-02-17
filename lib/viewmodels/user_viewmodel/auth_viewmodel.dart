import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  late final UserRepository _repository = UserRepository(_client);

  bool isLoading = false;
  String? errorMessage;

  // --- Login Attempt Tracking ---
  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 3);

  // --- Registration Form Properties ---
  double weight = 70.0;
  double height = 175.0;
  double sleepGoal = 8.0;

  // Set loading state
  void _setLoading(bool loading) {
    isLoading = loading;
    if (loading) errorMessage = null;
    notifyListeners();
  }

  // Set error message
  void _setError(String? message) {
    errorMessage = message;
    notifyListeners();
  }

  // Update profile attributes
  void updateAttribute(String attribute, double value) {
    if (attribute == 'weight') weight = value;
    else if (attribute == 'height') height = value;
    else if (attribute == 'sleepGoal') sleepGoal = value;
    notifyListeners();
  }

  // =================================================
  // LOGIN FUNCTION (With 3-Attempt Lockout)
  // =================================================
  Future<void> signIn(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Check Persisted Lockout
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
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // 2. Success: Reset Counters
      _failedAttempts = 0;
      await prefs.remove('lockout_timestamp');

    } on AuthException catch (_) {
      // 3. Failure: Increment & Lockout
      _failedAttempts++;

      if (_failedAttempts >= _maxAttempts) {
        final lockoutTime = DateTime.now().add(_lockoutDuration);
        await prefs.setInt('lockout_timestamp', lockoutTime.millisecondsSinceEpoch);
        _setError("Too many failed attempts. You are blocked for 3 minutes.");
      } else {
        _setError("Invalid email or password.");
      }
    } catch (e) {
      _setError('An unexpected error occurred.');
    }
    _setLoading(false);
  }

  // =================================================
  // REGISTRATION STEP 1: SEND OTP
  // =================================================
  Future<bool> startRegistration({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      // Supabase sends the OTP automatically upon sign-up if Email Confirm is on
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      // If session is null, it means OTP is required (Success)
      if (response.session == null && response.user != null) {
        _setLoading(false);
        return true;
      }
      // If session exists, they are just logged in (e.g. email confirm disabled)
      else if (response.session != null) {
        _setLoading(false);
        return true;
      }

      return false;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains("already registered")) {
        _setError("Account already exists. Please login.");
      } else {
        _setError("Invalid Email Format"); // [A1: Invalid Email Format]
      }
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred.');
      _setLoading(false);
      return false;
    }
  }

  // =================================================
  // REGISTRATION STEP 2: VERIFY OTP & SAVE DATA
  // =================================================
  Future<bool> verifyOtpAndCompleteRegistration({
    required String email,
    required String token,
    required String username,
    required String gender,
    required String dateBirth,
    required double weight,
    required double height,
    required double sleepGoal,
  }) async {
    _setLoading(true);
    try {
      // 1. Verify OTP
      final response = await _client.auth.verifyOTP(
        token: token,
        type: OtpType.signup,
        email: email,
      );

      if (response.session != null) {
        // 2. Create User Record in Database
        final newUser = UserModel(
          userId: response.user!.id,
          username: username,
          email: email,
          gender: gender,
          dateBirth: dateBirth,
          weight: weight,
          height: height,
          uidText: response.user!.id.substring(0, 8),
          currentPoints: 0,
          sleepGoalHours: sleepGoal,
        );

        await _repository.create(newUser.toJson());
        _setLoading(false);
        return true;
      } else {
        _setError("Invalid OTP code."); // [A4: Invalid OTP code]
        _setLoading(false);
        return false;
      }
    } on AuthException catch (e) {
      _setError("Invalid OTP code.");
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Failed to verify OTP.');
      _setLoading(false);
      return false;
    }
  }

  // =================================================
  // RESEND OTP
  // =================================================
  Future<void> resendOtp(String email) async {
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } catch (e) {
      _setError("Failed to resend OTP.");
    }
  }

  // --- Validation Helpers ---
  String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a username';
    if (value.length < 3) return 'Username is too short';
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    if (!value.contains('@')) return 'Please enter a valid email';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a password';
    if (value.length < 8) return 'Must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!value.contains(RegExp(r'[a-z]'))) return 'Must contain a lowercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    if (!value.contains(RegExp(r'[!@#\$&*~^%(),.?":{}|<>]'))) return 'Must contain a symbol';
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
      if(birthDate.isAfter(today)) return 'Date cannot be in the future';
      final twelveYearsAgo = DateTime(today.year - 12, today.month, today.day);
      if(birthDate.isAfter(twelveYearsAgo)) return 'You must be at least 12 years old';
    } catch(e) {
      return 'Invalid date format';
    }
    return null;
  }
}
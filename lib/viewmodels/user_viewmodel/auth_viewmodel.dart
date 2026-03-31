import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dreamsync/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  bool isLoading = false;
  String? errorMessage;
  bool _isDisposed = false;

  int _failedAttempts = 0;
  static const int _maxAttempts = 3;
  static const Duration _lockoutDuration = Duration(minutes: 3);

  double weight = 70.0;
  double height = 175.0;

  static const double defaultSleepGoal = 8.0;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return;
    isLoading = loading;
    if (loading) {
      errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String? message) {
    if (_isDisposed) return;
    errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    if (_isDisposed) return;
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  void resetAuthState() {
    if (_isDisposed) return;
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  void updateAttribute(String attribute, double value) {
    if (attribute == 'weight') {
      weight = value;
    } else if (attribute == 'height') {
      height = value;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    clearError();

    final prefs = await SharedPreferences.getInstance();

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
      await _repository.signInWithPasswordAndRestore(email.trim(), password);
      _failedAttempts = 0;
      await prefs.remove('lockout_timestamp');
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('AUTH_ERROR')) {
        _failedAttempts++;
        if (_failedAttempts >= _maxAttempts) {
          final lockoutTime = DateTime.now().add(_lockoutDuration);
          await prefs.setInt(
            'lockout_timestamp',
            lockoutTime.millisecondsSinceEpoch,
          );
          _setError("Too many failed attempts. You are blocked for 3 minutes.");
        } else {
          _setError("Invalid email or password.");
        }
      } else {
        _setError(errorStr.replaceAll('Exception: ', ''));
      }
    } finally {
      _setLoading(false);
    }
  }

  // UPDATED: Now requires password so we can use proper signUp
  Future<bool> sendVerificationOtp({required String email, required String password}) async {
    clearError();
    _setLoading(true);
    try {
      await _repository.sendVerificationOtp(email: email.trim(), password: password);
      return true;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('AUTH_ERROR')) {
        _setError(errorStr.split('AUTH_ERROR:').last.trim());
      } else {
        _setError('Failed to send OTP.');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

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
    clearError();
    _setLoading(true);
    try {
      await _repository.verifyOtpAndRegister(
        email: email.trim(),
        token: token.trim(),
        password: password,
        username: username,
        gender: gender,
        dateBirth: dateBirth,
        weight: weight,
        height: height,
        sleepGoal: sleepGoal,
      );
      return true;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('AUTH_ERROR')) {
        _setError(errorStr.split('AUTH_ERROR:').last.trim());
      } else {
        _setError(errorStr.replaceAll('Exception: ', ''));
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // UPDATED: Calls the new proper resend logic
  Future<void> resendOtp(String email) async {
    clearError();
    try {
      await _repository.resendSignupOtp(email: email.trim());
    } catch (e) {
      _setError("Failed to resend OTP.");
    }
  }

  Future<bool> sendResetPasswordOtp(String email) async {
    clearError();
    _setLoading(true);
    try {
      await _repository.sendPasswordResetOtp(email.trim());
      return true;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('AUTH_ERROR')) {
        _setError(errorStr.split('AUTH_ERROR:').last.trim());
      } else {
        _setError('Failed to send reset OTP.');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyResetOtpAndUpdatePassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    clearError();
    _setLoading(true);
    try {
      await _repository.verifyResetOtpAndUpdatePassword(
        email: email.trim(),
        token: token.trim(),
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('AUTH_ERROR')) {
        _setError(errorStr.split('AUTH_ERROR:').last.trim());
      } else {
        _setError(errorStr.replaceAll('Exception: ', ''));
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resendResetPasswordOtp(String email) async {
    clearError();
    try {
      await _repository.sendPasswordResetOtp(email.trim());
    } catch (e) {
      _setError("Failed to resend reset OTP.");
    }
  }

  String? validateUsername(String? value) {
    if (value == null || value.isEmpty) return 'Please enter a username';
    if (value.length < 3) return 'Username is too short';
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );
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

  String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the OTP';
    }
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
      final twelveYearsAgo = DateTime(today.year - 12, today.month, today.day);
      if (birthDate.isAfter(twelveYearsAgo)) {
        return 'You must be at least 12 years old';
      }
    } catch (e) {
      return 'Invalid date format';
    }
    return null;
  }
}
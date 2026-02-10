import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  late final UserRepository _repository = UserRepository(_client);

  bool isLoading = false;
  String? errorMessage;

  // Properties for the registration form
  double weight = 70.0; // Default value
  double height = 175.0; // Default value
  double sleepGoal = 8.0;// Default value

  // Set loading state and notify listeners
  void _setLoading(bool loading) {
    isLoading = loading;
    errorMessage = null; // Clear previous errors
    notifyListeners();
  }

  // Set error message and notify listeners
  void _setError(String? message) {
    errorMessage = message;
    notifyListeners();
  }

  // Update weight or height and notify listeners
  void updateAttribute(String attribute, double value) {
    if (attribute == 'weight') {
      weight = value;
    } else if (attribute == 'height') {
      height = value;
    } else if (attribute == 'sleepGoal') {
      sleepGoal = value;
    }
    notifyListeners();
  }

  // Sign in with email and password
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred.');
    }
    _setLoading(false);
  }

  //================================================
  // REGISTER VALIDATION
  //================================================
  String? validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a username';
    }
    if (value.length < 3) {
      return 'Username is too short';
    }
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
    try{
      final birthDate = DateTime.parse(value);
      final today = DateTime.now();

      if(birthDate.isAfter(today)){
        return 'Date cannot be in the future';
      }

      final twelveYearsAgo = DateTime(today.year - 12, today.month, today.day);

      if(birthDate.isAfter(twelveYearsAgo)){
        return 'You must be at least 12 years old';
      }
    }catch(e){
      return 'Invalid date format';
    }

    return null;
  }



  //================================================
  // SIGN UP NEW USER
  //================================================
  Future<void> signUp({
    required String email,
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
      // 1. Create the user in Supabase Auth
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      // 2. If sign-up is successful, create a profile in the public table
      if (response.user != null) {
        final newUser = UserModel(
          userId: response.user!.id,
          username: username,
          email: email,
          gender: gender,
          dateBirth: dateBirth,
          weight: weight,
          height: height,
          uidText: response.user!.id.substring(0, 8), // Example short ID
          currentPoints: 0,
          sleepGoalHours: sleepGoal,
        );
        await _repository.create(newUser.toJson());
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred during sign-up.');
    }
    _setLoading(false);
  }

  //================================================
  // SIGN OUT CURRENT USER
  //================================================
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred.');
    }
    _setLoading(false);
  }
}

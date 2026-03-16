import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepository _repository =
  UserRepository(Supabase.instance.client);

  UserModel? _userProfile;
  bool _isLoading = false;

  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  double get sleepGoalHours => _userProfile?.sleepGoalHours ?? 8.0;

  Future<void> fetchProfile(String userId) async {
    _isLoading = true;
    notifyListeners();

    _userProfile = await _repository.getProfileSafe(userId);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfileData({
    required double weight,
    required double height,
  }) async {
    final userId = _userProfile?.userId;
    if (userId == null) return;

    await _repository.updateProfileData(
      userId: userId,
      weight: weight,
      height: height,
    );

    _userProfile = _userProfile?.copyWith(
      weight: weight,
      height: height,
    );

    notifyListeners();
  }

  Future<void> updateSleepGoal(double hours) async {
    final userId = _userProfile?.userId;
    if (userId == null) return;

    await _repository.updateSleepGoal(
      userId: userId,
      sleepGoalHours: hours,
    );

    _userProfile = _userProfile?.copyWith(
      sleepGoalHours: hours,
    );

    notifyListeners();
  }

  Future<void> deleteUserAccount() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.deleteAccount();
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _repository.signOut();
      _userProfile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
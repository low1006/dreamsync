import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/user_repository.dart';
import 'package:dreamsync/services/encryption_service.dart';
import 'package:dreamsync/util/local_database.dart';

class ProfileViewModel extends ChangeNotifier {
  final UserRepository _repository = UserRepository();

  UserModel? _userProfile;
  bool _isLoading = false;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  double get sleepGoalHours => _userProfile?.sleepGoalHours ?? 8.0;

  Future<void> fetchProfile(String userId) async {
    _isLoading = true;
    _safeNotify();

    _userProfile = await _repository.getProfileSafe(userId);

    _isLoading = false;
    _safeNotify();
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

    if (_userProfile != null) {
      _userProfile!.weight = weight;
      _userProfile!.height = height;
    }

    _safeNotify();
  }

  Future<void> updateSleepGoal(double hours) async {
    final userId = _userProfile?.userId;
    if (userId == null) return;

    await _repository.updateSleepGoal(
      userId: userId,
      sleepGoalHours: hours,
    );

    if (_userProfile != null) {
      _userProfile!.sleepGoalHours = hours;
    }

    _safeNotify();
  }

  Future<void> deleteUserAccount() async {
    _isLoading = true;
    _safeNotify();

    try {
      await LocalDatabase.instance.closeDatabase();
      EncryptionService.instance.clearCache();
      await _repository.deleteAccount();
      _userProfile = null;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    _safeNotify();

    try {
      await LocalDatabase.instance.closeDatabase();
      EncryptionService.instance.clearCache();
      await _repository.signOut();
      _userProfile = null;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> updatePoints(int newPoints) async {
    final userId = _userProfile?.userId;
    if (userId == null) return;

    await _repository.updatePoints(userId, newPoints);

    if (_userProfile != null) {
      _userProfile!.currentPoints = newPoints;
    }

    _safeNotify();
  }
}
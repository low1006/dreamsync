import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class UserViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  late final UserRepository _repository = UserRepository(_client);
  UserModel? userProfile;
  bool isLoading = false;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  Future<void> fetchProfile(String userId) async {
    isLoading = true;
    _safeNotify();

    try {
      // 🔥 Now uses the safe fetch method that won't hang without internet
      userProfile = await _repository.getProfileSafe(userId);
    } catch (e) {
      debugPrint("❌ ViewModel Error fetching profile: $e");
    } finally {
      // 🔥 The finally block GUARANTEES the loading spinner stops no matter what
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> updateUserProfile({
    required double weight,
    required double height,
    required double sleepGoal,
  }) async {
    if (userProfile == null) return;

    isLoading = true;
    _safeNotify();
    try {
      await _repository.updateProfileData(
        userId: userProfile!.userId,
        weight: weight,
        height: height,
      );
      // Fetch again to update the local SharedPreferences cache
      await fetchProfile(userProfile!.userId);
    } catch (e) {
      debugPrint("Error updating profile: $e");
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<void> deleteUserAccount() async {
    isLoading = true;
    _safeNotify();
    try {
      // This calls delete_user_account() SQL function
      // which deletes auth.users row → CASCADE deletes profile
      await _repository.deleteAccount();
    } catch (e) {
      debugPrint("Error deleting account: $e");
    }
    // ← No finally notifyListeners here — ViewModel is
    //   already disposed after signOut, so we use _safeNotify
    isLoading = false;
    _safeNotify();
  }
}
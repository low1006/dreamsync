import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class UserViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  late final UserRepository _repository = UserRepository(_client);
  UserModel? userProfile;
  bool isLoading = false;

  Future<void> fetchProfile(String userId) async {
    isLoading = true;
    notifyListeners();
    userProfile = await _repository.getById(userId);
    isLoading = false;
    notifyListeners();
  }

  // logic for account actions
  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<void> deleteUserAccount() async {
    isLoading = true;
    notifyListeners();
    try {
      await _repository.deleteAccount();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

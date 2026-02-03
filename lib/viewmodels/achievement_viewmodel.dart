import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_achievement_model.dart';
import '../models/achievement_model.dart'; // Import this!
import '../repositories/user_achievement_repository.dart';

class AchievementViewModel extends ChangeNotifier {
  final _client = Supabase.instance.client;
  late final UserAchievementRepository _userAchievementRepo = UserAchievementRepository(_client);

  List<UserAchievementModel> userAchievements = [];
  bool isLoading = false;

  // inside achievement_viewmodel.dart

// ==================================================
// NEW FETCH LOGIC (Merge Master List + User Progress)
// ==================================================
  Future<void> fetchUserAchievements(String userId) async {
    print("🚀 STARTED: Fetching achievements...");
    isLoading = true;
    notifyListeners();

    try {
      // STEP 1: Get the "Menu" (All possible achievements from system)
      final menuResponse = await _client.from('achievement').select();
      print("✅ MENU FETCHED: Found ${menuResponse.length} items in 'achievement' table");

      // If the Master List is empty, stop here.
      if (menuResponse.isEmpty) {
        print("⚠️ WARNING: Your 'achievement' table in Supabase is empty!");
        userAchievements = [];
        isLoading = false;
        notifyListeners();
        return;
      }

      final List<AchievementModel> allAchievements = (menuResponse as List)
          .map((e) => AchievementModel.fromJson(e))
          .toList();

      // STEP 2: Get the "Receipt" (What this user has actually done)
      final userResponse = await _client
          .from('user_achievement')
          .select('*, achievement(*)')
          .eq('user_id', userId);
      print("✅ USER DATA FETCHED: Found ${userResponse.length} items for this user");

      final List<UserAchievementModel> existingProgress = (userResponse as List)
          .map((e) => UserAchievementModel.fromJson(e))
          .toList();

      // STEP 3: The Merge (Create the final list)
      List<UserAchievementModel> combinedList = [];

      for (var achievement in allAchievements) {
        // Check if user has started this specific achievement
        // We look for a match between the Master ID and the User's Achievement ID
        try {
          final userEntry = existingProgress.firstWhere(
                (u) => u.achievementId == achievement.achievementID,
          );
          combinedList.add(userEntry); // Found it! Use the real progress.
        } catch (e) {
          // Not found? Create a "Ghost" entry (0% progress)
          combinedList.add(_createGhostEntry(userId, achievement));
        }
      }

      print("🎉 DONE: Final list has ${combinedList.length} items");
      userAchievements = combinedList;

    } catch (e) {
      print("❌ ERROR in fetchUserAchievements: $e");
    }

    isLoading = false;
    notifyListeners();
  }

// Helper to create a "Ghost" (Empty) entry for display
  UserAchievementModel _createGhostEntry(String userId, AchievementModel achievement) {
    return UserAchievementModel(
      userAchievementId: 'temp_${achievement.achievementID}', // Fake ID
      userId: userId,
      achievementId: achievement.achievementID,
      currentProgress: 0.0,
      isUnlocked: false,
      isClaimed: false,
      achievement: achievement, // Attach details so UI can show Title
    );
  }

  // ==================================================
  // 2. UPDATED UPDATE LOGIC (Handle "First Time")
  // ==================================================
  Future<void> updateProgress(String userAchievementId, double amountToAdd) async {
    // Find the item in our local list
    final index = userAchievements.indexWhere((ua) => ua.userAchievementId == userAchievementId);
    if (index == -1) return;

    final currentItem = userAchievements[index];

    // LOGIC: Check if this is a "Ghost" entry (First time starting)
    bool isFirstTime = userAchievementId.startsWith('temp_');

    // ... (Calculate new progress as before) ...
    double newProgress = currentItem.currentProgress + amountToAdd;
    double target = currentItem.achievement?.criteriaValue ?? 100.0;

    bool shouldUnlock = newProgress >= target && !currentItem.isUnlocked;

    // ... (Prepare data) ...
    Map<String, dynamic> data = {
      'current_progress': newProgress,
      'is_unlocked': shouldUnlock ? true : currentItem.isUnlocked,
    };
    if (shouldUnlock) data['date_unlocked'] = DateTime.now().toIso8601String();

    try {
      if (isFirstTime) {
        // CASE A: INSERT (First time user is touching this achievement)
        // We must include the required IDs to create the row
        data['user_id'] = currentItem.userId;
        data['achievement_id'] = currentItem.achievementId;
        data['is_claimed'] = false;

        final response = await _client
            .from('user_achievement')
            .insert(data)
            .select('*, achievement(*)') // Get back the REAL ID
            .single();

        // Update local list with the REAL record from DB
        userAchievements[index] = UserAchievementModel.fromJson(response);

      } else {
        // CASE B: UPDATE (User already has this row)
        await _userAchievementRepo.update(userAchievementId, data);

        // Update local list manually (as before)
        userAchievements[index] = UserAchievementModel(
          userAchievementId: currentItem.userAchievementId,
          userId: currentItem.userId,
          achievementId: currentItem.achievementId,
          currentProgress: newProgress,
          isUnlocked: shouldUnlock,
          isClaimed: currentItem.isClaimed,
          achievement: currentItem.achievement,
        );
      }
      notifyListeners();

    } catch (e) {
      print("Error updating progress: $e");
    }
  }
}
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/services/recommendation_service.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class RecommendationViewModel extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';
  SleepRecommendation? currentRecommendation;

  final UserRepository _userRepository =
  UserRepository(Supabase.instance.client);

  DateTime? _lastLoadedAt;
  String? _lastUserId;

  bool shouldReuseCache(String userId) {
    return _lastUserId == userId &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(minutes: 10) &&
        currentRecommendation != null;
  }

  Future<void> loadRecommendation({
    required String userId,
    String? hypnogramJson,
    int exerciseMinutes = 0,
    int foodCalories = 0,
    int screenMinutes = 0,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && shouldReuseCache(userId)) {
      debugPrint('⏭️ Recommendation cache hit.');
      return;
    }

    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final rec = await RecommendationService.getRecommendation(
        userId: userId,
        hypnogramJson: hypnogramJson,
        exerciseMinutes: exerciseMinutes,
        foodCalories: foodCalories,
        screenMinutes: screenMinutes,
        forceRefresh: forceRefresh,
      );

      if (rec == null) {
        currentRecommendation = null;
        errorMessage = 'No recommendation available yet.';
      } else {
        currentRecommendation = rec;
        _lastLoadedAt = DateTime.now();
        _lastUserId = userId;
        errorMessage = '';

        await _userRepository.updateSleepGoal(
          userId: userId,
          sleepGoalHours: rec.recommendedHours,
        );
      }
    } catch (e) {
      currentRecommendation = null;
      errorMessage = 'Failed to load recommendation: $e';
      debugPrint('❌ RecommendationViewModel error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    currentRecommendation = null;
    errorMessage = '';
    _lastLoadedAt = null;
    _lastUserId = null;
    notifyListeners();
  }
}
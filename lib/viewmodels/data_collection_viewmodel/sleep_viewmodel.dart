import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'package:dreamsync/models/sleep_model/mood_feedback.dart';
import 'package:dreamsync/models/sleep_model/sleep_chart_point.dart';
import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/services/health_connect_helper.dart';
import 'package:dreamsync/services/sleep_achievement_service.dart';
import 'package:dreamsync/services/sleep_health_service.dart';
import 'package:dreamsync/services/sleep_summary_service.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

enum SleepFilter { daily, weekly }

class SleepViewModel extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';
  bool isDataPendingSync = false;

  final SleepRepository _repository;
  final SleepHealthService _healthService;
  final SleepSummaryService _summaryService;
  final SleepAchievementService _achievementService;

  SleepViewModel({
    SleepRepository? repository,
    SleepHealthService? healthService,
    SleepSummaryService? summaryService,
    SleepAchievementService? achievementService,
  })  : _repository = repository ?? SleepRepository(),
        _healthService = healthService ?? SleepHealthService(),
        _summaryService = summaryService ?? SleepSummaryService(),
        _achievementService = achievementService ?? SleepAchievementService();

  SleepFilter currentFilter = SleepFilter.daily;

  List<HealthDataPoint> _rawHealthData = [];
  Map<String, DateTime> _wakeTimeByDay = {};

  String? _lastLoadedUserId;
  DateTime? _lastLoadedAt;
  bool _isCurrentlyLoading = false;

  String dailyTotalSleepDuration = '0h 0m';
  int dailySleepScore = 0;
  String dailyDeepSleep = '0h 0m';
  String dailyLightSleep = '0h 0m';
  String dailyRemSleep = '0h 0m';
  List<SleepChartPoint> hypnogramData = [];

  String weeklyTotalSleepDuration = '0h 0m';
  int weeklySleepScore = 0;

  List<SleepRecordModel> weeklyData = [];

  SleepRecordModel? latestSleepRecord;
  String? pendingFeedbackDate;
  bool showMoodFeedbackPrompt = false;
  bool isSubmittingMoodFeedback = false;

  Future<void> loadSleepData({
    BuildContext? context,
    required String userId,
    required AchievementViewModel achievementVM,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _lastLoadedUserId == userId &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(seconds: 20)) {
      debugPrint('⏭️ SleepViewModel: recent cache hit, skipping reload.');
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
      return;
    }

    if (_isCurrentlyLoading) {
      debugPrint('⏳ SleepViewModel: already loading, skipping duplicate.');
      return;
    }

    _isCurrentlyLoading = true;
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final status = await _healthService.getSdkStatus();

      if (status == HealthConnectSdkStatus.sdkUnavailable ||
          status ==
              HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        if (context != null && context.mounted) {
          await HealthConnectHelper.showInstallDialog(context);
        } else {
          debugPrint('⚠️ Background sync: Health Connect not available.');
        }
        return;
      }

      final hasPermission = await _healthService.ensurePermissions(
        requestIfNeeded: context != null && context.mounted,
      );

      if (!hasPermission) {
        errorMessage = 'Permission denied.';
        return;
      }

      _rawHealthData = await _healthService.fetchLast30DaysSleepData();

      final dashboard =
      _summaryService.rebuildDashboardStateFromRawData(_rawHealthData);
      _applyDashboardState(dashboard);

      final existingRecords = await _repository.getAllSleepRecords(userId);
      final existingByDate = <String, SleepRecordModel>{
        for (final record in existingRecords)
          _summaryService.normalizeDateKey(record.date): record,
      };

      final summaries = _summaryService.buildDailySummaries(
        _rawHealthData,
        userId,
        existingByDate: existingByDate,
      );

      await _repository.saveDailySummaries(summaries);
      await _repository.syncOfflineData();

      await fetchWeeklyDataFromDatabase(userId);
      await _prepareMoodFeedbackPrompt(userId);

      final allRecords = await _repository.getAllSleepRecords(userId);
      await _achievementService.updateAchievements(
        allRecords: allRecords,
        wakeTimeByDay: _wakeTimeByDay,
        dailySleepScore: dailySleepScore,
        achievementVM: achievementVM,
      );

      _lastLoadedUserId = userId;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      debugPrint('❌ Error fetching from Health Connect: $e');
      errorMessage = 'Failed to sync with Health Connect. Ensure data exists.';
    } finally {
      _isCurrentlyLoading = false;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData({
    BuildContext? context,
    required String userId,
    required AchievementViewModel achievementVM,
  }) async {
    await loadSleepData(
      context: context,
      userId: userId,
      achievementVM: achievementVM,
      forceRefresh: true,
    );
  }

  Future<void> _prepareMoodFeedbackPrompt(String userId) async {
    try {
      final allRecords = await _repository.getAllSleepRecords(userId);
      if (allRecords.isEmpty) {
        latestSleepRecord = null;
        pendingFeedbackDate = null;
        showMoodFeedbackPrompt = false;
        return;
      }

      final validRecords = allRecords.where((e) => e.totalMinutes > 0).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      if (validRecords.isEmpty) {
        latestSleepRecord = null;
        pendingFeedbackDate = null;
        showMoodFeedbackPrompt = false;
        return;
      }

      latestSleepRecord = validRecords.last;
      final latestDate =
      _summaryService.normalizeDateKey(latestSleepRecord!.date);

      final parsedLatest = DateTime.tryParse(latestDate);
      if (parsedLatest == null) {
        pendingFeedbackDate = null;
        showMoodFeedbackPrompt = false;
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final latestMidnight =
      DateTime(parsedLatest.year, parsedLatest.month, parsedLatest.day);

      final isRecent = latestMidnight == today || latestMidnight == yesterday;

      if (isRecent &&
          (latestSleepRecord!.moodFeedback == null ||
              latestSleepRecord!.moodFeedback!.isEmpty)) {
        pendingFeedbackDate = latestDate;
        showMoodFeedbackPrompt = true;
      } else {
        pendingFeedbackDate = null;
        showMoodFeedbackPrompt = false;
      }
    } catch (e) {
      debugPrint('❌ Error preparing mood feedback prompt: $e');
      latestSleepRecord = null;
      pendingFeedbackDate = null;
      showMoodFeedbackPrompt = false;
    }
  }

  Future<void> submitMoodFeedback(MoodFeedback mood) async {
    if (_lastLoadedUserId == null || pendingFeedbackDate == null) return;

    try {
      isSubmittingMoodFeedback = true;
      notifyListeners();

      final userId = _lastLoadedUserId!;
      final date = pendingFeedbackDate!;

      final allRecords = await _repository.getAllSleepRecords(userId);
      final existing = allRecords.where((e) {
        return _summaryService.normalizeDateKey(e.date) == date;
      }).toList();

      if (existing.isEmpty) {
        debugPrint('⚠️ No matching sleep record found for feedback date $date');
        return;
      }

      final updated = existing.first.copyWith(
        moodFeedback: mood.name,
      );

      await _repository.saveDailySummaries([updated]);

      latestSleepRecord = updated;
      showMoodFeedbackPrompt = false;
      pendingFeedbackDate = null;

      await fetchWeeklyDataFromDatabase(userId);
    } catch (e) {
      debugPrint('❌ Error submitting mood feedback: $e');
    } finally {
      isSubmittingMoodFeedback = false;
      notifyListeners();
    }
  }

  void dismissMoodFeedbackPrompt() {
    showMoodFeedbackPrompt = false;
    notifyListeners();
  }

  Future<void> fetchWeeklyDataFromDatabase(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));

      final startDateStr = _summaryService.dateKey(weekStart);
      final endDateStr = '${_summaryService.dateKey(now)} 23:59:59';

      final records = await _repository.getSleepRecordsByDateRange(
        userId,
        startDateStr,
        endDateStr,
      );

      final Map<String, SleepRecordModel> byDate = {
        for (final record in records)
          _summaryService.normalizeDateKey(record.date): record,
      };

      final List<SleepRecordModel> filledRecords = [];

      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final targetKey = _summaryService.dateKey(targetDate);

        final existing = byDate[targetKey];
        if (existing != null) {
          filledRecords.add(existing);
        } else {
          filledRecords.add(
            SleepRecordModel(
              userId: userId,
              date: targetKey,
              totalMinutes: 0,
              sleepScore: 0,
            ),
          );
        }
      }

      weeklyData = filledRecords;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error fetching weekly data from DB: $e');
    }
  }

  void changeFilter(SleepFilter newFilter) {
    if (currentFilter != newFilter) {
      currentFilter = newFilter;
      notifyListeners();
    }
  }

  void _applyDashboardState(SleepSummaryResult dashboard) {
    isDataPendingSync = dashboard.isDataPendingSync;
    dailyTotalSleepDuration = dashboard.dailyTotalSleepDuration;
    dailySleepScore = dashboard.dailySleepScore;
    dailyDeepSleep = dashboard.dailyDeepSleep;
    dailyLightSleep = dashboard.dailyLightSleep;
    dailyRemSleep = dashboard.dailyRemSleep;
    hypnogramData = dashboard.hypnogramData;
    weeklyTotalSleepDuration = dashboard.weeklyTotalSleepDuration;
    weeklySleepScore = dashboard.weeklySleepScore;
    _wakeTimeByDay = dashboard.wakeTimeByDay;
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dreamsync/models/sleep_model/sleep_chart_point.dart';
import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/models/sleep_model/mood_feedback.dart';

import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/repositories/user_repository.dart';

import 'package:dreamsync/services/sleep_health_service.dart';
import 'package:dreamsync/services/sleep_summary_service.dart';
import 'package:dreamsync/services/sleep_achievement_service.dart';
import 'package:dreamsync/services/health_connect_helper.dart';
import 'package:dreamsync/util/local_database.dart';

import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

enum SleepFilter { daily, weekly }

class SleepViewModel extends ChangeNotifier {
  final SleepRepository _repository = SleepRepository();
  final UserRepository _userRepository =
  UserRepository(Supabase.instance.client);
  final SleepHealthService _healthService = SleepHealthService();
  final SleepSummaryService _summaryService = SleepSummaryService();
  final SleepAchievementService _achievementService =
  SleepAchievementService();

  bool isLoading = false;
  String errorMessage = '';
  bool isDataPendingSync = false;
  bool _isCurrentlyLoading = false;

  String? _lastLoadedUserId;
  DateTime? _lastLoadedAt;

  SleepFilter currentFilter = SleepFilter.daily;

  Map<String, DateTime> _wakeTimeByDay = {};

  String dailyTotalSleepDuration = '0h 0m';
  int dailySleepScore = 0;
  String dailyDeepSleep = '0h 0m';
  String dailyLightSleep = '0h 0m';
  String dailyRemSleep = '0h 0m';
  List<SleepChartPoint> hypnogramData = [];

  String weeklyTotalSleepDuration = '0h 0m';
  int weeklySleepScore = 0;
  List<SleepRecordModel> weeklyData = [];

  bool showMoodFeedbackPrompt = false;
  String? pendingFeedbackDate;
  bool isSubmittingMoodFeedback = false;

  Future<void> loadFromDatabase({
    required String userId,
  }) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      await _loadDailyFromDatabase(userId);
      await _fetchWeeklyDataFromDatabase(userId);
      await _checkMoodFeedbackNeeded(userId);
    } catch (e) {
      debugPrint('❌ SleepViewModel.loadFromDatabase: $e');
      errorMessage = 'Failed to load local sleep data.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSleepData({
    BuildContext? context,
    required String userId,
    required AchievementViewModel achievementVM,
    bool forceRefresh = false,
  }) async {
    await _performHealthSync(
      context: context,
      userId: userId,
      achievementVM: achievementVM,
      forceRefresh: forceRefresh,
      showLoading: true,
    );
  }

  Future<void> syncInBackground({
    BuildContext? context,
    required String userId,
    required AchievementViewModel achievementVM,
  }) async {
    await _performHealthSync(
      context: context,
      userId: userId,
      achievementVM: achievementVM,
      forceRefresh: true,
      showLoading: false,
    );
  }

  Future<void> _performHealthSync({
    BuildContext? context,
    required String userId,
    required AchievementViewModel achievementVM,
    required bool forceRefresh,
    required bool showLoading,
  }) async {
    if (!forceRefresh &&
        _lastLoadedUserId == userId &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) <
            const Duration(seconds: 20)) {
      debugPrint('⏭️ SleepViewModel: cache hit, skipping reload.');
      if (showLoading && isLoading) {
        isLoading = false;
        notifyListeners();
      }
      return;
    }

    if (_isCurrentlyLoading) {
      debugPrint('⏳ SleepViewModel: already loading.');
      return;
    }

    _isCurrentlyLoading = true;
    if (showLoading) {
      isLoading = true;
      errorMessage = '';
      notifyListeners();
    }

    try {
      final status = await _healthService.getSdkStatus();
      if (status == HealthConnectSdkStatus.sdkUnavailable ||
          status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        if (context != null && context.mounted) {
          await HealthConnectHelper.showInstallDialog(context);
        } else {
          debugPrint('⚠️ Background sync: Health Connect unavailable.');
        }
        return;
      }

      final granted = await _healthService.ensurePermissions(
        requestIfNeeded: context != null,
      );
      if (!granted) {
        if (showLoading) {
          errorMessage = context != null ? 'Permission denied.' : '';
        }
        if (context == null) {
          debugPrint('⚠️ Background sync aborted: no permissions.');
        }
        return;
      }

      final rawData = await _healthService.fetchLast30DaysSleepData();

      final result = _summaryService.rebuildDashboardStateFromRawData(rawData);
      isDataPendingSync = result.isDataPendingSync;
      dailyTotalSleepDuration = result.dailyTotalSleepDuration;
      dailySleepScore = result.dailySleepScore;
      dailyDeepSleep = result.dailyDeepSleep;
      dailyLightSleep = result.dailyLightSleep;
      dailyRemSleep = result.dailyRemSleep;
      hypnogramData = result.hypnogramData;
      weeklyTotalSleepDuration = result.weeklyTotalSleepDuration;
      weeklySleepScore = result.weeklySleepScore;
      _wakeTimeByDay = result.wakeTimeByDay;

      final existing = await _repository.getSleepRecordsByDateRange(
        userId,
        _dateKey(DateTime.now().subtract(const Duration(days: 30))),
        '${_dateKey(DateTime.now())} 23:59:59',
      );
      final existingByDate = {
        for (final r in existing) _normalizeDateKey(r.date): r,
      };
      final summaries = _summaryService.buildDailySummaries(
        rawData,
        userId,
        existingByDate: existingByDate,
      );
      await _repository.saveDailySummaries(summaries);

      await _fetchWeeklyDataFromDatabase(userId);

      final allRecords = await _repository.getAllSleepRecords(userId);
      final streak = await _achievementService.updateAchievements(
        allRecords: allRecords,
        wakeTimeByDay: _wakeTimeByDay,
        dailySleepScore: dailySleepScore,
        achievementVM: achievementVM,
      );
      await _userRepository.updateStreak(userId, streak);

      await _checkMoodFeedbackNeeded(userId);

      _lastLoadedUserId = userId;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      debugPrint('❌ SleepViewModel._performHealthSync: $e');
      if (showLoading) {
        errorMessage =
        'Failed to sync with Health Connect. Ensure data exists.';
      }
    } finally {
      _isCurrentlyLoading = false;
      if (showLoading) {
        isLoading = false;
      }
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

  void changeFilter(SleepFilter newFilter) {
    if (currentFilter != newFilter) {
      currentFilter = newFilter;
      notifyListeners();
    }
  }

  Future<void> _loadDailyFromDatabase(String userId) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT *
      FROM sleep_record
      WHERE user_id = ? AND total_minutes > 0
      ORDER BY date DESC
      LIMIT 1
    ''', [userId]);

    if (rows.isEmpty) {
      dailyTotalSleepDuration = '0h 0m';
      dailySleepScore = 0;
      dailyDeepSleep = '0h 0m';
      dailyLightSleep = '0h 0m';
      dailyRemSleep = '0h 0m';
      hypnogramData = [];
      isDataPendingSync = false;
      return;
    }

    final row = rows.first;
    final totalMinutes = (row['total_minutes'] as num?)?.toInt() ?? 0;
    final deepMinutes = (row['deep_minutes'] as num?)?.toInt() ?? 0;
    final lightMinutes = (row['light_minutes'] as num?)?.toInt() ?? 0;
    final remMinutes = (row['rem_minutes'] as num?)?.toInt() ?? 0;
    final sleepScore = (row['sleep_score'] as num?)?.toInt() ?? 0;
    final isSynced = ((row['is_synced'] as num?)?.toInt() ?? 1) == 1;

    dailyTotalSleepDuration = _formatMinutes(totalMinutes);
    dailySleepScore = sleepScore;
    dailyDeepSleep = _formatMinutes(deepMinutes);
    dailyLightSleep = _formatMinutes(lightMinutes);
    dailyRemSleep = _formatMinutes(remMinutes);
    isDataPendingSync = !isSynced;

    final hypnogramJson = row['hypnogram_json'] as String?;
    hypnogramData = _parseHypnogram(hypnogramJson);
  }

  Future<void> _fetchWeeklyDataFromDatabase(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));
      final startStr = _dateKey(weekStart);
      final endStr = '${_dateKey(now)} 23:59:59';

      final records = await _repository.getSleepRecordsByDateRange(
        userId,
        startStr,
        endStr,
      );

      final byDate = {
        for (final r in records) _normalizeDateKey(r.date): r,
      };

      weeklyData = [
        for (int i = 6; i >= 0; i--)
          byDate[_dateKey(now.subtract(Duration(days: i)))] ??
              SleepRecordModel(
                userId: userId,
                date: _dateKey(now.subtract(Duration(days: i))),
                totalMinutes: 0,
                sleepScore: 0,
              ),
      ];

      if (weeklyData.isNotEmpty) {
        final total = weeklyData.fold<int>(0, (sum, e) => sum + e.totalMinutes);
        final avgMinutes = (total / weeklyData.length).round();
        final avgScore = (weeklyData.fold<int>(0, (sum, e) => sum + e.sleepScore) /
            weeklyData.length)
            .round();

        weeklyTotalSleepDuration = _formatMinutes(avgMinutes);
        weeklySleepScore = avgScore;
      } else {
        weeklyTotalSleepDuration = '0h 0m';
        weeklySleepScore = 0;
      }
    } catch (e) {
      debugPrint('❌ _fetchWeeklyDataFromDatabase: $e');
    }
  }

  Future<void> _checkMoodFeedbackNeeded(String userId) async {
    try {
      final db = await LocalDatabase.instance.database;
      final cutoff = _dateKey(DateTime.now().subtract(const Duration(days: 1)));

      final rows = await db.rawQuery('''
        SELECT date, mood_feedback
        FROM sleep_record
        WHERE user_id = ? AND date >= ? AND total_minutes > 0
        ORDER BY date DESC
        LIMIT 1
      ''', [userId, cutoff]);

      if (rows.isEmpty) {
        showMoodFeedbackPrompt = false;
        pendingFeedbackDate = null;
        return;
      }

      final latestDate = rows.first['date'] as String;
      final existingMood = rows.first['mood_feedback'] as String?;

      showMoodFeedbackPrompt = existingMood == null || existingMood.isEmpty;
      pendingFeedbackDate = showMoodFeedbackPrompt ? latestDate : null;
    } catch (e) {
      debugPrint('❌ _checkMoodFeedbackNeeded: $e');
      showMoodFeedbackPrompt = false;
    }
  }

  Future<void> submitMoodFeedback(MoodFeedback mood) async {
    final date = pendingFeedbackDate;
    final userId = _lastLoadedUserId;
    if (date == null || userId == null) return;

    isSubmittingMoodFeedback = true;
    notifyListeners();

    try {
      await _repository.saveMoodFeedback(
        userId: userId,
        date: date,
        mood: mood.name,
      );

      showMoodFeedbackPrompt = false;
      pendingFeedbackDate = null;
    } catch (e) {
      debugPrint('❌ submitMoodFeedback: $e');
    } finally {
      isSubmittingMoodFeedback = false;
      notifyListeners();
    }
  }

  List<SleepChartPoint> _parseHypnogram(String? raw) {
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded.map<SleepChartPoint>((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return SleepChartPoint.fromJson(map);
      }).toList();
    } catch (e) {
      debugPrint('⚠️ Failed to parse hypnogram_json: $e');
      return [];
    }
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _normalizeDateKey(String rawDate) =>
      rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
}
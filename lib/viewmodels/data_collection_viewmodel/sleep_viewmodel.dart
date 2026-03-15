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
  // ── Dependencies ──────────────────────────────────────────────────────────
  final SleepRepository         _repository         = SleepRepository();
  final UserRepository          _userRepository     = UserRepository(Supabase.instance.client);
  final SleepHealthService      _healthService      = SleepHealthService();
  final SleepSummaryService     _summaryService     = SleepSummaryService();
  final SleepAchievementService _achievementService = SleepAchievementService();

  // ── Loading state ─────────────────────────────────────────────────────────
  bool   isLoading           = false;
  String errorMessage        = '';
  bool   isDataPendingSync   = false;
  bool   _isCurrentlyLoading = false;

  // ── Cache control ─────────────────────────────────────────────────────────
  String?   _lastLoadedUserId;
  DateTime? _lastLoadedAt;

  // ── Filter ────────────────────────────────────────────────────────────────
  SleepFilter currentFilter = SleepFilter.daily;

  // ── Internal ──────────────────────────────────────────────────────────────
  Map<String, DateTime> _wakeTimeByDay = {};

  // ── Daily display state ───────────────────────────────────────────────────
  String                dailyTotalSleepDuration = '0h 0m';
  int                   dailySleepScore         = 0;
  String                dailyDeepSleep          = '0h 0m';
  String                dailyLightSleep         = '0h 0m';
  String                dailyRemSleep           = '0h 0m';
  List<SleepChartPoint> hypnogramData           = [];

  // ── Weekly display state ──────────────────────────────────────────────────
  String                 weeklyTotalSleepDuration = '0h 0m';
  int                    weeklySleepScore          = 0;
  List<SleepRecordModel> weeklyData               = [];

  // ── Mood feedback state ───────────────────────────────────────────────────
  bool    showMoodFeedbackPrompt   = false;
  String? pendingFeedbackDate;
  bool    isSubmittingMoodFeedback = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Load / Refresh
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> loadSleepData({
    BuildContext?         context,
    required String       userId,
    required AchievementViewModel achievementVM,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _lastLoadedUserId == userId &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < const Duration(seconds: 20)) {
      debugPrint('⏭️ SleepViewModel: cache hit, skipping reload.');
      if (isLoading) { isLoading = false; notifyListeners(); }
      return;
    }

    if (_isCurrentlyLoading) {
      debugPrint('⏳ SleepViewModel: already loading.');
      return;
    }

    _isCurrentlyLoading = true;
    isLoading           = true;
    errorMessage        = '';
    notifyListeners();

    try {
      // 1. SDK status check
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

      // 2. Permissions
      final granted = await _healthService.ensurePermissions(
        requestIfNeeded: context != null,
      );
      if (!granted) {
        errorMessage = context != null ? 'Permission denied.' : '';
        if (context == null) {
          debugPrint('⚠️ Background sync aborted: no permissions.');
        }
        return;
      }

      // 3. Fetch raw data
      final rawData = await _healthService.fetchLast30DaysSleepData();

      // 4. Build dashboard state
      final result = _summaryService.rebuildDashboardStateFromRawData(rawData);
      isDataPendingSync        = result.isDataPendingSync;
      dailyTotalSleepDuration  = result.dailyTotalSleepDuration;
      dailySleepScore          = result.dailySleepScore;
      dailyDeepSleep           = result.dailyDeepSleep;
      dailyLightSleep          = result.dailyLightSleep;
      dailyRemSleep            = result.dailyRemSleep;
      hypnogramData            = result.hypnogramData;
      weeklyTotalSleepDuration = result.weeklyTotalSleepDuration;
      weeklySleepScore         = result.weeklySleepScore;
      _wakeTimeByDay           = result.wakeTimeByDay;

      // 5. Save summaries to SQLite — preserve existing mood_feedback
      final existing = await _repository.getSleepRecordsByDateRange(
        userId,
        _dateKey(DateTime.now().subtract(const Duration(days: 30))),
        '${_dateKey(DateTime.now())} 23:59:59',
      );
      final existingByDate = {
        for (final r in existing) _normalizeDateKey(r.date): r,
      };
      final summaries = _summaryService.buildDailySummaries(
        rawData, userId, existingByDate: existingByDate,
      );
      await _repository.saveDailySummaries(summaries);

      // 6. Weekly data from DB
      await _fetchWeeklyDataFromDatabase(userId);

      // 7. Achievements + streak
      final allRecords = await _repository.getAllSleepRecords(userId);
      final streak = await _achievementService.updateAchievements(
        allRecords      : allRecords,
        wakeTimeByDay   : _wakeTimeByDay,
        dailySleepScore : dailySleepScore,
        achievementVM   : achievementVM,
      );
      await _userRepository.updateStreak(userId, streak);

      // 8. Mood feedback check
      await _checkMoodFeedbackNeeded(userId);

      _lastLoadedUserId = userId;
      _lastLoadedAt     = DateTime.now();
    } catch (e) {
      debugPrint('❌ SleepViewModel.loadSleepData: $e');
      errorMessage = 'Failed to sync with Health Connect. Ensure data exists.';
    } finally {
      _isCurrentlyLoading = false;
      isLoading           = false;
      notifyListeners();
    }
  }

  Future<void> refreshData({
    BuildContext?         context,
    required String       userId,
    required AchievementViewModel achievementVM,
  }) async {
    await loadSleepData(
      context      : context,
      userId       : userId,
      achievementVM: achievementVM,
      forceRefresh : true,
    );
  }

  void changeFilter(SleepFilter newFilter) {
    if (currentFilter != newFilter) {
      currentFilter = newFilter;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Weekly data from SQLite
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchWeeklyDataFromDatabase(String userId) async {
    try {
      final now       = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));
      final startStr  = _dateKey(weekStart);
      final endStr    = '${_dateKey(now)} 23:59:59';

      final records = await _repository.getSleepRecordsByDateRange(
        userId, startStr, endStr,
      );

      final byDate = {
        for (final r in records) _normalizeDateKey(r.date): r,
      };

      weeklyData = [
        for (int i = 6; i >= 0; i--)
          byDate[_dateKey(now.subtract(Duration(days: i)))] ??
              SleepRecordModel(
                userId       : userId,
                date         : _dateKey(now.subtract(Duration(days: i))),
                totalMinutes : 0,
                sleepScore   : 0,
              ),
      ];
    } catch (e) {
      debugPrint('❌ _fetchWeeklyDataFromDatabase: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mood Feedback
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkMoodFeedbackNeeded(String userId) async {
    try {
      final db     = await LocalDatabase.instance.database;
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
        pendingFeedbackDate    = null;
        return;
      }

      final latestDate   = rows.first['date']          as String;
      final existingMood = rows.first['mood_feedback'] as String?;

      showMoodFeedbackPrompt = existingMood == null || existingMood.isEmpty;
      pendingFeedbackDate    = showMoodFeedbackPrompt ? latestDate : null;
    } catch (e) {
      debugPrint('❌ _checkMoodFeedbackNeeded: $e');
      showMoodFeedbackPrompt = false;
    }
  }

  Future<void> submitMoodFeedback(MoodFeedback mood) async {
    final date   = pendingFeedbackDate;
    final userId = _lastLoadedUserId;
    if (date == null || userId == null) return;

    isSubmittingMoodFeedback = true;
    notifyListeners();

    try {
      await _repository.saveMoodFeedback(
        userId : userId,
        date   : date,
        mood   : mood.name,   // 'sad' | 'neutral' | 'happy'
      );

      showMoodFeedbackPrompt = false;
      pendingFeedbackDate    = null;
    } catch (e) {
      debugPrint('❌ submitMoodFeedback: $e');
    } finally {
      isSubmittingMoodFeedback = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _normalizeDateKey(String rawDate) =>
      rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
}
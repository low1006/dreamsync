import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/models/sleep_model/mood_feedback.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';
import 'package:dreamsync/services/permission_service.dart';
import 'package:dreamsync/views/sleep_dashboard_view/sleep_dashboard_daily_tab.dart';
import 'package:dreamsync/views/sleep_dashboard_view/sleep_dashboard_weekly_tab.dart';
import 'package:dreamsync/widget/sleep_dashboard/states/sleep_dashboard_loading.dart';
import 'package:dreamsync/widget/sleep_dashboard/states/sleep_dashboard_error.dart';
import 'package:dreamsync/util/app_theme.dart';
import 'package:dreamsync/util/parsers.dart';
import 'package:dreamsync/widget/custom/onboarding_dialog.dart';

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({super.key});

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _screenTime = "Fetching...";
  bool _hasFetchedData = false;
  bool _isInitialLoadDone = false;
  bool _hasStartedBackgroundSync = false;
  bool _isBackgroundSyncRunning = false;
  DateTime? _lastBackgroundSyncAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final vm = context.read<SleepViewModel>();
      if (_tabController.index == 0) {
        vm.changeFilter(SleepFilter.daily);
      } else {
        vm.changeFilter(SleepFilter.weekly);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _syncBehaviouralHealthData(String userId) async {
    // Skip HC permission dialog if onboarding guide is still showing
    // (prevents two dialogs colliding on first launch).
    // HC sync will happen on next pull-to-refresh or background sync.
    final onboardingPending = await OnboardingDialog.shouldShow();
    if (onboardingPending) {
      debugPrint('⏭️ Skipping Health Connect permission — onboarding in progress.');
      return false;
    }

    final dailyVM = context.read<DailyActivityViewModel>();

    final hasHealthPermission =
    await PermissionService.requestHealthPermission(context);

    if (!hasHealthPermission) {
      debugPrint(
        '⚠️ Health Connect permission not granted. Exercise and burned calories not refreshed.',
      );
      return false;
    }

    await dailyVM.fetchAndSaveExerciseFromHealthConnect(userId);
    await dailyVM.fetchAndSaveBurnedCaloriesFromHealthConnect(userId);
    await dailyVM.loadTodayData(userId);
    await dailyVM.loadWeeklyData(userId);
    return true;
  }

  Future<void> _bootstrap(String userId) async {
    final sleepVM = context.read<SleepViewModel>();
    final dailyVM = context.read<DailyActivityViewModel>();
    final achievementVM = context.read<AchievementViewModel>();

    try {
      await sleepVM.loadFromDatabase(userId: userId);
      await dailyVM.loadTodayData(userId);
      await dailyVM.loadWeeklyData(userId);

      if (!mounted) return;
      setState(() {
        _screenTime = Parsers.formatScreenTime(dailyVM.screenTimeMinutes);
        _isInitialLoadDone = true;
      });

      final liveScreenTime =
      await dailyVM.fetchAndSaveScreenTime(userId, achievementVM);

      final didSync = await _syncBehaviouralHealthData(userId);

      if (!mounted) return;
      setState(() {
        _screenTime = liveScreenTime;
      });

      // Show sync complete toast only if HC sync actually ran
      if (mounted && didSync) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Health Connect sync complete'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (!_hasStartedBackgroundSync) {
        _hasStartedBackgroundSync = true;
        unawaited(_backgroundRefresh(userId));
      }
    } catch (e) {
      debugPrint("❌ Sleep dashboard bootstrap error: $e");
      if (!mounted) return;
      setState(() => _isInitialLoadDone = true);
    }
  }

  Future<void> _backgroundRefresh(String userId) async {
    if (_isBackgroundSyncRunning) return;

    final now = DateTime.now();
    if (_lastBackgroundSyncAt != null &&
        now.difference(_lastBackgroundSyncAt!) < const Duration(minutes: 5)) {
      debugPrint('⏭️ Background sync skipped: recently synced.');
      return;
    }

    _isBackgroundSyncRunning = true;
    _lastBackgroundSyncAt = now;

    final sleepVM = context.read<SleepViewModel>();
    final dailyVM = context.read<DailyActivityViewModel>();
    final achievementVM = context.read<AchievementViewModel>();

    try {
      await sleepVM.syncInBackground(
        context: context,
        userId: userId,
        achievementVM: achievementVM,
      );

      await dailyVM.loadTodayData(userId);
      await dailyVM.loadWeeklyData(userId);

      if (!mounted) return;
      setState(() {
        _screenTime = Parsers.formatScreenTime(dailyVM.screenTimeMinutes);
      });
    } catch (e) {
      debugPrint("❌ Sleep dashboard background refresh error: $e");
    } finally {
      _isBackgroundSyncRunning = false;
    }
  }

  List<String> _getLast7DaysLabels() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      switch (date.weekday) {
        case 1:
          return "Mon";
        case 2:
          return "Tue";
        case 3:
          return "Wed";
        case 4:
          return "Thu";
        case 5:
          return "Fri";
        case 6:
          return "Sat";
        case 7:
          return "Sun";
        default:
          return "";
      }
    });
  }

  Future<void> _submitMood(MoodFeedback mood) async {
    final vm = context.read<SleepViewModel>();
    await vm.submitMoodFeedback(mood);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Mood feedback saved."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _fullRefresh() async {
    final user = context.read<ProfileViewModel>().userProfile;
    if (user == null) return;

    final sleepVM = context.read<SleepViewModel>();
    final dailyVM = context.read<DailyActivityViewModel>();
    final achievementVM = context.read<AchievementViewModel>();

    await sleepVM.refreshData(
      context: context,
      userId: user.userId,
      achievementVM: achievementVM,
    );

    await dailyVM.loadTodayData(user.userId);
    await dailyVM.loadWeeklyData(user.userId);

    final liveScreenTime =
    await dailyVM.fetchAndSaveScreenTime(user.userId, achievementVM);

    await _syncBehaviouralHealthData(user.userId);

    if (!mounted) return;
    setState(() {
      _screenTime = liveScreenTime;
      _lastBackgroundSyncAt = DateTime.now();
    });

    // Show refresh complete toast
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppTheme.bg(context);
    final text = AppTheme.text(context);
    final accent = AppTheme.accent;

    final user = context.watch<ProfileViewModel>().userProfile;
    final dailyVM = context.watch<DailyActivityViewModel>();

    if (user != null && !_hasFetchedData) {
      _hasFetchedData = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _bootstrap(user.userId);
      });
    }

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: innerBoxIsScrolled
                  ? AppTheme.surface(context)
                  : bg,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              forceElevated: innerBoxIsScrolled,
              elevation: innerBoxIsScrolled ? 1 : 0,
              pinned: true,
              centerTitle: true,
              automaticallyImplyLeading: false,
              iconTheme: IconThemeData(color: text),
              title: Text(
                'Sleep Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: accent,
                labelColor: accent,
                unselectedLabelColor: text.withOpacity(0.5),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                dividerColor: text.withOpacity(0.1),
                tabs: const [
                  Tab(text: "Daily"),
                  Tab(text: "Weekly"),
                ],
              ),
            ),
          ];
        },
        body: Consumer<SleepViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading || !_isInitialLoadDone) {
              return SleepDashboardLoadingView(
                accent: accent,
                text: text,
              );
            }

            if (viewModel.errorMessage.isNotEmpty) {
              return SleepDashboardErrorView(
                message: viewModel.errorMessage,
                onRetry: () async {
                  final u = context.read<ProfileViewModel>().userProfile;
                  if (u == null) return;

                  setState(() {
                    _isInitialLoadDone = false;
                    _hasFetchedData = false;
                    _hasStartedBackgroundSync = false;
                  });

                  await _bootstrap(u.userId);
                },
              );
            }

            return TabBarView(
              controller: _tabController,
              children: [
                SleepDashboardDailyTab(
                  viewModel: viewModel,
                  dailyVM: dailyVM,
                  text: text,
                  accent: accent,
                  screenTime: _screenTime,
                  onRefresh: _fullRefresh,
                  onSubmitMood: _submitMood,
                ),
                SleepDashboardWeeklyTab(
                  viewModel: viewModel,
                  dailyVM: dailyVM,
                  text: text,
                  accent: accent,
                  last7DaysLabels: _getLast7DaysLabels(),
                  onRefresh: _fullRefresh,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
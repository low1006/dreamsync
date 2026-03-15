import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:dreamsync/models/sleep_model/mood_feedback.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

import 'package:dreamsync/views/sleep_dashboard_screen/sleep_dashboard_daily_tab.dart';
import 'package:dreamsync/views/sleep_dashboard_screen/sleep_dashboard_weekly_tab.dart';
import 'package:dreamsync/widget/sleep_dashboard/components/sleep_dashboard_loading.dart';
import 'package:dreamsync/widget/sleep_dashboard/components/sleep_dashboard_error.dart';

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

  Future<void> fetchScreenTime() async {
    final user = context.read<UserViewModel>().userProfile;
    if (user == null) return;

    final achievementVM = context.read<AchievementViewModel>();

    final String result = await context
        .read<DailyActivityViewModel>()
        .fetchAndSaveScreenTime(user.userId, achievementVM);

    if (mounted) {
      setState(() {
        _screenTime = result;
      });
    }
  }

  Future<void> _bootstrap(String userId) async {
    final sleepVM = context.read<SleepViewModel>();
    final dailyVM = context.read<DailyActivityViewModel>();
    final achievementVM = context.read<AchievementViewModel>();

    try {
      await sleepVM.loadSleepData(
        context: context,
        userId: userId,
        achievementVM: achievementVM,
      );

      await dailyVM.loadTodayData(userId);
      await dailyVM.fetchAndSaveExerciseFromHealthConnect(userId);
      await dailyVM.fetchAndSaveScreenTime(userId, achievementVM);
      await dailyVM.loadWeeklyData(userId);

      if (!mounted) return;
      setState(() {
        _screenTime = dailyVM.formatScreenTime(dailyVM.screenTimeMinutes);
        _isInitialLoadDone = true;
      });
    } catch (e) {
      debugPrint("❌ Sleep dashboard bootstrap error: $e");
      if (!mounted) return;
      setState(() {
        _isInitialLoadDone = true;
      });
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);

    final user = context.watch<UserViewModel>().userProfile;
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
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Sleep Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, color: text),
        ),
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(color: text),
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
                final u = context.read<UserViewModel>().userProfile;
                if (u == null) return;

                setState(() {
                  _isInitialLoadDone = false;
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
                onRefresh: () async {
                  final user = context.read<UserViewModel>().userProfile;
                  if (user == null) return;

                  final achievementVM =
                  context.read<AchievementViewModel>();

                  await viewModel.refreshData(
                    context: context,
                    userId: user.userId,
                    achievementVM: achievementVM,
                  );

                  await dailyVM.loadTodayData(user.userId);
                  await dailyVM.fetchAndSaveExerciseFromHealthConnect(
                    user.userId,
                  );
                  await dailyVM.fetchAndSaveScreenTime(
                    user.userId,
                    achievementVM,
                  );
                  await dailyVM.loadWeeklyData(user.userId);

                  if (!mounted) return;
                  setState(() {
                    _screenTime =
                        dailyVM.formatScreenTime(dailyVM.screenTimeMinutes);
                  });
                },
                onSubmitMood: _submitMood,
              ),
              SleepDashboardWeeklyTab(
                viewModel: viewModel,
                dailyVM: dailyVM,
                text: text,
                accent: accent,
                last7DaysLabels: _getLast7DaysLabels(),
                onRefresh: () async {
                  final user = context.read<UserViewModel>().userProfile;
                  if (user == null) return;

                  final achievementVM =
                  context.read<AchievementViewModel>();

                  await viewModel.refreshData(
                    context: context,
                    userId: user.userId,
                    achievementVM: achievementVM,
                  );

                  await dailyVM.loadTodayData(user.userId);
                  await dailyVM.fetchAndSaveExerciseFromHealthConnect(
                    user.userId,
                  );
                  await dailyVM.fetchAndSaveScreenTime(
                    user.userId,
                    achievementVM,
                  );
                  await dailyVM.loadWeeklyData(user.userId);

                  if (!mounted) return;
                  setState(() {
                    _screenTime =
                        dailyVM.formatScreenTime(dailyVM.screenTimeMinutes);
                  });
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
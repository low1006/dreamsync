import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ViewModels
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

// Custom Widgets & Painters
import 'package:dreamsync/widget/sleep_dashboard/behavioural_card.dart';
import 'package:dreamsync/widget/sleep_dashboard/behavioural_dialogs.dart';
import 'package:dreamsync/widget/sleep_dashboard/sleep_score_gauge_painter.dart';
import 'package:dreamsync/widget/sleep_dashboard/hypnogram_painter.dart';
import 'package:dreamsync/widget/sleep_dashboard/weekly_bar_chart.dart';

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

  // ✅ NEW: Added this flag to prevent the "No Data" flicker on first load
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

  double _parseScreenTimeToHours(String screenTimeStr) {
    if (screenTimeStr == "Fetching..." || screenTimeStr.isEmpty) return 0.0;
    double hours = 0.0;

    final RegExp hourRegExp = RegExp(r'(\d+)\s*h');
    final RegExp minRegExp = RegExp(r'(\d+)\s*m');

    final hMatch = hourRegExp.firstMatch(screenTimeStr);
    if (hMatch != null) hours += double.parse(hMatch.group(1)!);

    final mMatch = minRegExp.firstMatch(screenTimeStr);
    if (mMatch != null) hours += double.parse(mMatch.group(1)!) / 60.0;

    return hours;
  }

  List<String> _getLast7DaysLabels() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      switch (date.weekday) {
        case 1: return "Mon";
        case 2: return "Tue";
        case 3: return "Wed";
        case 4: return "Thu";
        case 5: return "Fri";
        case 6: return "Sat";
        case 7: return "Sun";
        default: return "";
      }
    });
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
        final achievementVM = context.read<AchievementViewModel>();

        await context.read<SleepViewModel>().loadSleepData(
          context: context,
          userId: user.userId,
          achievementVM: achievementVM,
        );

        await context
            .read<DailyActivityViewModel>()
            .loadTodayData(user.userId);

        if (mounted) {
          await fetchScreenTime();
          await context
              .read<DailyActivityViewModel>()
              .loadWeeklyData(user.userId);

          // ✅ NEW: Tell the UI that the initial sequence is fully complete
          setState(() {
            _isInitialLoadDone = true;
          });
        }
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

          // ✅ FIXED: Now checks if the initial load is done.
          // This keeps the spinner active on frame 1, preventing the flash.
          if (viewModel.isLoading || !_isInitialLoadDone) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: accent),
                  const SizedBox(height: 16),
                  Text("Syncing data...", style: TextStyle(color: text)),
                ],
              ),
            );
          }

          if (viewModel.errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        final u = context.read<UserViewModel>().userProfile;
                        if (u != null) {
                          final achievementVM =
                          context.read<AchievementViewModel>();

                          setState(() { _isInitialLoadDone = false; }); // Reset flag

                          await viewModel.loadSleepData(
                            context: context,
                            userId: u.userId,
                            achievementVM: achievementVM,
                          );

                          if (mounted) {
                            setState(() { _isInitialLoadDone = true; }); // Set flag again
                          }
                        }
                      },
                      child: const Text("Try Again"),
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildDailyTab(context, viewModel, dailyVM, text, accent),
              _buildWeeklyTab(context, viewModel, dailyVM, text, accent),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 0 — DAILY
  // ─────────────────────────────────────────────
  Widget _buildDailyTab(
      BuildContext context,
      SleepViewModel viewModel,
      DailyActivityViewModel dailyVM,
      Color text,
      Color accent,
      ) {
    final bool noData = viewModel.dailyTotalSleepDuration == "0h 0m";

    return RefreshIndicator(
      onRefresh: () async {
        final user = context.read<UserViewModel>().userProfile;
        if (user != null) {
          final achievementVM = context.read<AchievementViewModel>();
          await viewModel.refreshData(
            context: context,
            userId: user.userId,
            achievementVM: achievementVM,
          );
          await context
              .read<DailyActivityViewModel>()
              .loadTodayData(user.userId);
          await context
              .read<DailyActivityViewModel>()
              .loadWeeklyData(user.userId);
        }
        await fetchScreenTime();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (viewModel.isDataPendingSync && !noData)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Today's sleep hasn't synced yet. Please open your fitness app to sync your latest data.",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              viewModel.isDataPendingSync
                  ? "Last Recorded Sleep"
                  : "Yesterday's Sleep",
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: text),
            ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: noData ? 0.4 : 1.0,
                  child: IgnorePointer(
                    ignoring: noData,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score + Duration card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              CustomPaint(
                                size: const Size(100, 100),
                                painter: SleepScoreGaugePainter(
                                  score: viewModel.dailySleepScore,
                                  themeColor: Colors.indigoAccent,
                                ),
                              ),
                              Container(
                                  width: 1,
                                  height: 60,
                                  color: Colors.grey.shade200),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    viewModel.dailyTotalSleepDuration,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Time Asleep",
                                    style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Hypnogram
                        const SizedBox(height: 20),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Sleep Cycle (Hypnogram)",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 120,
                                child: CustomPaint(
                                  size: Size.infinite,
                                  painter: HypnogramPainter(
                                      data: viewModel.hypnogramData),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildLegendItem(
                                      "Awake", const Color(0xFFFF7043)),
                                  _buildLegendItem(
                                      "REM", const Color(0xFF9C64FF)),
                                  _buildLegendItem(
                                      "Light", const Color(0xFF42A5F5)),
                                  _buildLegendItem(
                                      "Deep", const Color(0xFF1A237E)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Sleep stages breakdown
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildSleepStageRow("Deep Sleep",
                                  viewModel.dailyDeepSleep, Colors.indigo),
                              const Divider(height: 16),
                              _buildSleepStageRow("Light Sleep",
                                  viewModel.dailyLightSleep, Colors.lightBlue),
                              const Divider(height: 16),
                              _buildSleepStageRow("REM Sleep",
                                  viewModel.dailyRemSleep, Colors.purpleAccent),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // No data overlay
                if (noData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bedtime_off,
                            size: 56, color: Colors.indigoAccent),
                        SizedBox(height: 16),
                        Text(
                          "No sleep data found",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Ensure your smartwatch is synced\nwith Health Connect.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text("Behavioural Data",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: text)),
            const SizedBox(height: 12),
            BehaviouralCard(
              title: "Screen Time",
              value: _screenTime,
              subtitle: "Fetched from OS",
              icon: Icons.phone_android,
              iconColor: Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BehaviouralCard(
                    title: "Exercise",
                    value: "${dailyVM.exerciseMinutes} mins",
                    subtitle: "Tap to add",
                    icon: Icons.fitness_center,
                    iconColor: Colors.orange,
                    onTap: () =>
                        BehaviouralDialogs.showAddExerciseDialog(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BehaviouralCard(
                    title: "Food Intake",
                    value: "${dailyVM.foodCalories} kcal",
                    subtitle: "Tap to add",
                    icon: Icons.restaurant,
                    iconColor: Colors.green,
                    onTap: () =>
                        BehaviouralDialogs.showAddFoodDialog(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 1 — WEEKLY
  // ─────────────────────────────────────────────
  Widget _buildWeeklyTab(
      BuildContext context,
      SleepViewModel viewModel,
      DailyActivityViewModel dailyVM,
      Color text,
      Color accent,
      ) {
    return RefreshIndicator(
      onRefresh: () async {
        final user = context.read<UserViewModel>().userProfile;
        if (user != null) {
          final achievementVM = context.read<AchievementViewModel>();
          await viewModel.refreshData(
            context: context,
            userId: user.userId,
            achievementVM: achievementVM,
          );
          await context
              .read<DailyActivityViewModel>()
              .loadWeeklyData(user.userId);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("7-Day Average",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: text)),
            const SizedBox(height: 12),
            // Score + Average duration card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: SleepScoreGaugePainter(
                      score: viewModel.weeklySleepScore,
                      themeColor: Colors.indigoAccent,
                    ),
                  ),
                  Container(
                      width: 1, height: 60, color: Colors.grey.shade200),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        viewModel.weeklyTotalSleepDuration,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Average Time",
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 7-Day Sleep Trend
            if (viewModel.weeklyData.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text("7-Day Trend",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: text)),
              const SizedBox(height: 12),
              WeeklyBarChart(
                values: viewModel.weeklyData
                    .map((e) => e.totalMinutes / 60.0)
                    .toList(),
                labels:
                viewModel.weeklyData.map((e) => e.shortDayName).toList(),
                color: Colors.indigoAccent,
                unit: "h",
                maxY: 8.0,
                isDecimal: true,
              ),
            ],
            const SizedBox(height: 24),
            Text("Behavioural Data",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: text)),
            const SizedBox(height: 12),
            Text("Screen Time Trend",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: text)),
            const SizedBox(height: 8),
            WeeklyBarChart(
              values: dailyVM.weeklyData.isEmpty
                  ? [0, 0, 0, 0, 0, 0, 0]
                  : dailyVM.weeklyData
                  .map((e) => e.screenTimeMinutes / 60.0)
                  .toList(),
              labels: _getLast7DaysLabels(),
              color: Colors.blueGrey,
              unit: "h",
              maxY: 8.0,
              isDecimal: true,
            ),
            const SizedBox(height: 24),
            Text("Exercise Trend",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: text)),
            const SizedBox(height: 8),
            WeeklyBarChart(
              values: dailyVM.weeklyData.isEmpty
                  ? [0, 0, 0, 0, 0, 0, 0]
                  : dailyVM.weeklyData
                  .map((e) => e.exerciseMinutes.toDouble())
                  .toList(),
              labels: _getLast7DaysLabels(),
              color: Colors.orange,
              unit: "m",
            ),
            const SizedBox(height: 24),
            Text("Food Intake Trend",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: text)),
            const SizedBox(height: 8),
            WeeklyBarChart(
              values: dailyVM.weeklyData.isEmpty
                  ? [0, 0, 0, 0, 0, 0, 0]
                  : dailyVM.weeklyData
                  .map((e) => e.foodCalories.toDouble())
                  .toList(),
              labels: _getLast7DaysLabels(),
              color: Colors.green,
              unit: "k",
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSleepStageRow(String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87),
        ),
        const Spacer(),
        Text(
          duration,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87),
        ),
      ],
    );
  }
}
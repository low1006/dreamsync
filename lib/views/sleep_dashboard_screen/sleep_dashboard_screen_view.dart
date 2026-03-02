import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ViewModels
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';

// Custom Widgets & Painters
import 'package:dreamsync/widget/sleep_dashboard/behavioural_card.dart';
import 'package:dreamsync/widget/sleep_dashboard/behavioural_dialogs.dart';
import 'package:dreamsync/widget/sleep_dashboard/sleep_score_gauge_painter.dart'; // NEW
import 'package:dreamsync/widget/sleep_dashboard/hypnogram_painter.dart';        // NEW

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({super.key});

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen> {
  String _screenTime = "Fetching...";

  // Flag to ensure we only fetch data once after the user loads
  bool _hasFetchedData = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> fetchScreenTime() async {
    final user = context.read<UserViewModel>().userProfile;
    if (user == null) return;

    final String result = await context
        .read<DailyActivityViewModel>()
        .fetchAndSaveScreenTime(user.userId);

    if (mounted) {
      setState(() {
        _screenTime = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. WATCH the user profile so the UI knows when it finishes loading
    final user = context.watch<UserViewModel>().userProfile;
    final dailyVM = context.watch<DailyActivityViewModel>();

    // 2. TRIGGER the fetches once the user is NOT null, but only do it ONCE.
    if (user != null && !_hasFetchedData) {
      _hasFetchedData = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SleepViewModel>().loadSleepData(context, user.userId);
        context.read<DailyActivityViewModel>().loadTodayData(user.userId);
        fetchScreenTime();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Sleep Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<SleepViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Syncing data..."),
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final user = context.read<UserViewModel>().userProfile;
                        if (user != null) {
                          viewModel.loadSleepData(context, user.userId);
                        }
                      },
                      child: const Text("Try Again"),
                    )
                  ],
                ),
              ),
            );
          }

          final bool noData = viewModel.totalSleepDuration == "0h 0m";

          return RefreshIndicator(
            onRefresh: () async {
              final user = context.read<UserViewModel>().userProfile;
              if (user != null) {
                await viewModel.refreshData(context, user.userId);
                await context.read<DailyActivityViewModel>().loadTodayData(user.userId);
              }
              await fetchScreenTime();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Last Night's Sleep",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // STACK FOR DIMMING EFFECT & NO DATA OVERLAY
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: noData ? 0.4 : 1.0,
                        child: IgnorePointer(
                          ignoring: noData,
                          child: Column(
                            children: [
                              // 1. Main Sleep Score & Duration Card
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
                                        score: viewModel.sleepScore,
                                        themeColor: Colors.indigoAccent,
                                      ),
                                    ),
                                    Container(width: 1, height: 60, color: Colors.grey.shade200),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          viewModel.totalSleepDuration,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Time Asleep",
                                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Sleep Cycle (Hypnogram)",
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 2. The Hypnogram Chart Container
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
                                          data: viewModel.hypnogramData,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildLegendItem("Awake", const Color(0xFFFF7043)),
                                        _buildLegendItem("REM", const Color(0xFF9C64FF)),
                                        _buildLegendItem("Light", const Color(0xFF42A5F5)),
                                        _buildLegendItem("Deep", const Color(0xFF1A237E)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 3. Sleep Stages Breakdown
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
                                    _buildSleepStageRow("Deep Sleep", viewModel.deepSleep, Colors.indigo),
                                    const Divider(height: 16),
                                    _buildSleepStageRow("Light Sleep", viewModel.lightSleep, Colors.lightBlue),
                                    const Divider(height: 16),
                                    _buildSleepStageRow("REM Sleep", viewModel.remSleep, Colors.purpleAccent),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top Layer: The "No Data" Overlay Message
                      if (noData)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                            ],
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bedtime_off, size: 56, color: Colors.indigoAccent),
                              SizedBox(height: 16),
                              Text(
                                "No sleep data found",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Ensure your smartwatch is synced\nwith Health Connect.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              )
                            ],
                          ),
                        ),
                    ],
                  ),

                  // --- BEHAVIOURAL DATA SUMMARY ---
                  const SizedBox(height: 24),
                  const Text(
                    "Behavioural Data",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
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
                          onTap: () => BehaviouralDialogs.showAddExerciseDialog(context),
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
                          onTap: () => BehaviouralDialogs.showAddFoodDialog(context),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          duration,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
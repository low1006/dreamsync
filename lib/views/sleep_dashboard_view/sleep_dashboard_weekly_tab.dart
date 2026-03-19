import 'package:flutter/material.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/widget/sleep_dashboard/charts/bar_chart.dart';
import 'package:dreamsync/widget/sleep_dashboard/charts/sleep_score_gauge.dart';

class SleepDashboardWeeklyTab extends StatelessWidget {
  final SleepViewModel viewModel;
  final DailyActivityViewModel dailyVM;
  final Color text;
  final Color accent;
  final List<String> last7DaysLabels;
  final Future<void> Function() onRefresh;

  const SleepDashboardWeeklyTab({
    super.key,
    required this.viewModel,
    required this.dailyVM,
    required this.text,
    required this.accent,
    required this.last7DaysLabels,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final shadowColor = Colors.black.withOpacity(isDark ? 0.20 : 0.05);
    final subText = isDark ? Colors.white70 : Colors.grey;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "7-Day Average",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
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
                      themeColor: accent,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        viewModel.weeklyTotalSleepDuration,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Average Time",
                        style: TextStyle(
                          color: subText,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (viewModel.weeklyData.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                "7-Day Sleep Trend",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
              const SizedBox(height: 12),
              WeeklyBarChart(
                values: viewModel.weeklyData
                    .map((e) => e.totalMinutes / 60.0)
                    .toList(),
                labels:
                viewModel.weeklyData.map((e) => e.shortDayName).toList(),
                color: accent,
                unit: "h",
                maxY: 8.0,
                isDecimal: true,
              ),
            ],

            const SizedBox(height: 24),

            Text(
              "Behavioural Data",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              "Screen Time Trend",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            WeeklyBarChart(
              values: dailyVM.weeklyData.isEmpty
                  ? [0, 0, 0, 0, 0, 0, 0]
                  : dailyVM.weeklyData
                  .map((e) => e.screenTimeMinutes / 60.0)
                  .toList(),
              labels: last7DaysLabels,
              color: Colors.blueGrey,
              unit: "h",
              maxY: 8.0,
              isDecimal: true,
            ),

            const SizedBox(height: 24),

            Text(
              "Exercise Trend",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            WeeklyBarChart(
              values: dailyVM.weeklyData.isEmpty
                  ? [0, 0, 0, 0, 0, 0, 0]
                  : dailyVM.weeklyData
                  .map((e) => e.exerciseMinutes.toDouble())
                  .toList(),
              labels: last7DaysLabels,
              color: Colors.orange,
              unit: "h",
            ),

            const SizedBox(height: 24),

            Text(
              "Food Intake Trend",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            WeeklyBarChart(
              values: dailyVM.weeklyData.isEmpty
                  ? [0, 0, 0, 0, 0, 0, 0]
                  : dailyVM.weeklyData
                  .map((e) => e.foodCalories.toDouble())
                  .toList(),
              labels: last7DaysLabels,
              color: Colors.green,
              unit: "k",
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
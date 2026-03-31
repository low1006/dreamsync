import 'package:flutter/material.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/widget/sleep_dashboard/charts/bar_chart.dart';
import 'package:dreamsync/widget/sleep_dashboard/charts/sleep_score_gauge.dart';
import 'package:dreamsync/util/app_theme.dart';

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

  List<double> _normalizeTo7(
      List<dynamic> data,
      double Function(dynamic item) mapper,
      ) {
    final values = data.map(mapper).toList();

    if (values.length >= 7) {
      return values.sublist(values.length - 7);
    }

    final padding = List<double>.filled(7 - values.length, 0);
    return [...padding, ...values];
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = AppTheme.card(context);
    final shadowColor = AppTheme.shadow(context);
    final subText = AppTheme.subText(context);

    final sleepTrendValues = _normalizeTo7(
      viewModel.weeklyData,
          (e) => e.totalMinutes / 60.0,
    );

    final screenTimeValues = _normalizeTo7(
      dailyVM.weeklyData,
          (e) => e.screenTimeMinutes / 60.0,
    );

    final exerciseValues = _normalizeTo7(
      dailyVM.weeklyData,
          (e) => e.exerciseMinutes.toDouble(),
    );

    final burnedCaloriesValues = _normalizeTo7(
      dailyVM.weeklyData,
          (e) => e.burnedCalories.toDouble(),
    );

    final foodValues = _normalizeTo7(
      dailyVM.weeklyData,
          (e) => e.foodCalories.toDouble(),
    );

    final caffeineValues = _normalizeTo7(
      dailyVM.weeklyData,
          (e) => e.caffeineIntakeMg,
    );

    final sugarValues = _normalizeTo7(
      dailyVM.weeklyData,
          (e) => e.sugarIntakeG,
    );

    final alcoholValues = _normalizeTo7(
      dailyVM.weeklyData,
          (e) => e.alcoholIntakeG,
    );

    final hasSleepTrend = sleepTrendValues.any((v) => v > 0);
    final hasSubstanceData = caffeineValues.any((v) => v > 0) ||
        sugarValues.any((v) => v > 0) ||
        alcoholValues.any((v) => v > 0);

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
                    painter: SleepScoreGauge(
                      score: viewModel.weeklySleepScore,
                      themeColor: accent,
                      textColor: AppTheme.text(context),
                      subTextColor: subText,
                      trackColor: AppTheme.isDark(context)
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade200,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: AppTheme.isDark(context) ? Colors.white12 : Colors.grey.shade200,
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

            if (hasSleepTrend) ...[
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
                values: sleepTrendValues,
                labels: last7DaysLabels,
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
              values: screenTimeValues,
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
              values: exerciseValues,
              labels: last7DaysLabels,
              color: Colors.orange,
              unit: "m",
            ),

            const SizedBox(height: 24),

            Text(
              "Calories Burned Trend",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: text,
              ),
            ),
            const SizedBox(height: 8),
            WeeklyBarChart(
              values: burnedCaloriesValues,
              labels: last7DaysLabels,
              color: Colors.redAccent,
              unit: "k",
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
              values: foodValues,
              labels: last7DaysLabels,
              color: Colors.green,
              unit: "k",
            ),

            if (hasSubstanceData) ...[
              const SizedBox(height: 24),

              Text(
                "Sleep Impact Substances",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
              const SizedBox(height: 12),

              if (caffeineValues.any((v) => v > 0)) ...[
                Text(
                  "Caffeine Trend",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
                const SizedBox(height: 8),
                WeeklyBarChart(
                  values: caffeineValues,
                  labels: last7DaysLabels,
                  color: Colors.brown,
                  unit: "mg",
                ),
                const SizedBox(height: 24),
              ],

              if (sugarValues.any((v) => v > 0)) ...[
                Text(
                  "Sugar Trend",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
                const SizedBox(height: 8),
                WeeklyBarChart(
                  values: sugarValues,
                  labels: last7DaysLabels,
                  color: Colors.amber,
                  unit: "g",
                ),
                const SizedBox(height: 24),
              ],

              if (alcoholValues.any((v) => v > 0)) ...[
                Text(
                  "Alcohol Trend",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
                const SizedBox(height: 8),
                WeeklyBarChart(
                  values: alcoholValues,
                  labels: last7DaysLabels,
                  color: Colors.purple,
                  unit: "g",
                ),
              ],
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:dreamsync/models/sleep_model/mood_feedback.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/widget/sleep_dashboard/cards/behavioural_card.dart';
import 'package:dreamsync/widget/sleep_dashboard/behavioural_dialogs.dart';
import 'package:dreamsync/widget/sleep_dashboard/charts/hypnogram.dart';
import 'package:dreamsync/widget/sleep_dashboard/cards/sleep_mood_prompt_card.dart';
import 'package:dreamsync/widget/sleep_dashboard/charts/sleep_score_gauge.dart';
import 'package:dreamsync/widget/sleep_dashboard/states/sync_pending_banner.dart';
import 'package:dreamsync/util/app_theme.dart';

class SleepDashboardDailyTab extends StatelessWidget {
  final SleepViewModel viewModel;
  final DailyActivityViewModel dailyVM;
  final Color text;
  final Color accent;
  final String screenTime;
  final Future<void> Function() onRefresh;
  final Future<void> Function(MoodFeedback mood) onSubmitMood;

  const SleepDashboardDailyTab({
    super.key,
    required this.viewModel,
    required this.dailyVM,
    required this.text,
    required this.accent,
    required this.screenTime,
    required this.onRefresh,
    required this.onSubmitMood,
  });

  @override
  Widget build(BuildContext context) {
    final bool noData = viewModel.dailyTotalSleepDuration == "0h 0m";

    final cardColor = AppTheme.card(context);
    final shadowColor = AppTheme.shadow(context);
    final subText = AppTheme.subText(context);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (viewModel.isDataPendingSync && !noData)
              const SyncPendingBanner(),

            if (viewModel.showMoodFeedbackPrompt && !noData)
              SleepMoodPromptCard(
                pendingFeedbackDate: viewModel.pendingFeedbackDate,
                isSubmitting: viewModel.isSubmittingMoodFeedback,
                onSubmit: onSubmitMood,
              ),

            Text(
              viewModel.isDataPendingSync
                  ? "Last Recorded Sleep"
                  : "Yesterday's Sleep",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: text,
              ),
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
                                  score: viewModel.dailySleepScore,
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
                                color: AppTheme.isDark(context)
                                    ? Colors.white12
                                    : Colors.grey.shade200,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    viewModel.dailyTotalSleepDuration,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Time Asleep",
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

                        const SizedBox(height: 20),

                        Text(
                          "Sleep Cycle (Hypnogram)",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: text,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
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
                                  _buildLegendItem(
                                    "Awake",
                                    const Color(0xFFFF7043),
                                    subText,
                                  ),
                                  _buildLegendItem(
                                    "REM",
                                    const Color(0xFF9C64FF),
                                    subText,
                                  ),
                                  _buildLegendItem(
                                    "Light",
                                    const Color(0xFF42A5F5),
                                    subText,
                                  ),
                                  _buildLegendItem("Deep", accent, subText),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: shadowColor,
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildSleepStageRow(
                                "Deep Sleep",
                                viewModel.dailyDeepSleep,
                                accent,
                                text,
                              ),
                              const Divider(height: 16),
                              _buildSleepStageRow(
                                "Light Sleep",
                                viewModel.dailyLightSleep,
                                Colors.lightBlue,
                                text,
                              ),
                              const Divider(height: 16),
                              _buildSleepStageRow(
                                "REM Sleep",
                                viewModel.dailyRemSleep,
                                Colors.purpleAccent,
                                text,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (noData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bedtime_off,
                          size: 56,
                          color: accent,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No sleep data found",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ensure your smartwatch is synced\nwith Health Connect.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subText,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

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

            BehaviouralCard(
              title: "Screen Time",
              value: screenTime,
              subtitle: "Foreground app usage today",
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
                    title: "Calories Burned",
                    value: "${dailyVM.burnedCalories} kcal",
                    subtitle: "From exercise & Health Connect",
                    icon: Icons.local_fire_department,
                    iconColor: Colors.redAccent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            BehaviouralCard(
              title: "Food Intake",
              value: "${dailyVM.foodCalories} kcal",
              subtitle: "Tap to add",
              icon: Icons.restaurant,
              iconColor: Colors.green,
              onTap: () => BehaviouralDialogs.showAddFoodDialog(context),
            ),

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

            Row(
              children: [
                Expanded(
                  child: BehaviouralCard(
                    title: "Caffeine",
                    value: "${dailyVM.caffeineIntakeMg.round()} mg",
                    subtitle: dailyVM.caffeineIntakeMg > 200
                        ? "⚠️ High — may affect sleep"
                        : "From food intake",
                    icon: Icons.coffee,
                    iconColor: Colors.brown,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BehaviouralCard(
                    title: "Sugar",
                    value: "${dailyVM.sugarIntakeG.toStringAsFixed(1)} g",
                    subtitle: dailyVM.sugarIntakeG > 50
                        ? "⚠️ High — may reduce sleep quality"
                        : "From food intake",
                    icon: Icons.cake,
                    iconColor: Colors.amber,
                  ),
                ),
              ],
            ),

            if (dailyVM.alcoholIntakeG > 0) ...[
              const SizedBox(height: 12),
              BehaviouralCard(
                title: "Alcohol",
                value: "${dailyVM.alcoholIntakeG.toStringAsFixed(1)} g",
                subtitle: "⚠️ Reduces REM sleep quality",
                icon: Icons.local_bar,
                iconColor: Colors.purple,
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: textColor),
        ),
      ],
    );
  }

  Widget _buildSleepStageRow(
      String title,
      String duration,
      Color color,
      Color textColor,
      ) {
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const Spacer(),
        Text(
          duration,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
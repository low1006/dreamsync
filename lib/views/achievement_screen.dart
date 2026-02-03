import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';
import 'package:dreamsync/models/user_achievement_model.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({super.key});

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await context.read<AchievementViewModel>().fetchUserAchievements(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Achievements")),
      body: Consumer<AchievementViewModel>(
        builder: (context, viewModel, child) {

          // Loading
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Empty
          if (viewModel.userAchievements.isEmpty) {
            return RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("No achievements found.")),
                ],
              ),
            );
          }

          // ✅ FIXED SCROLLABLE LIST
          return RefreshIndicator(
            onRefresh: _fetchData,
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 20, top: 10),
                itemCount: viewModel.userAchievements.length,
                itemBuilder: (context, index) {
                  final userAchievement = viewModel.userAchievements[index];
                  return AchievementTile(
                    userAchievement: userAchievement,
                    viewModel: viewModel,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- TILE WIDGET (UNCHANGED) ---
class AchievementTile extends StatefulWidget {
  final UserAchievementModel userAchievement;
  final AchievementViewModel viewModel;

  const AchievementTile({
    super.key,
    required this.userAchievement,
    required this.viewModel,
  });

  @override
  State<AchievementTile> createState() => _AchievementTileState();
}

class _AchievementTileState extends State<AchievementTile> {
  late double _localSliderValue;

  @override
  void initState() {
    super.initState();
    _localSliderValue = widget.userAchievement.currentProgress;
  }

  @override
  void didUpdateWidget(covariant AchievementTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userAchievement.currentProgress !=
        widget.userAchievement.currentProgress) {
      _localSliderValue = widget.userAchievement.currentProgress;
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.userAchievement.achievement;
    if (details == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: widget.userAchievement.isUnlocked ? Colors.white : Colors.grey[200],
      elevation: widget.userAchievement.isUnlocked ? 2 : 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: widget.userAchievement.isUnlocked
                        ? Colors.green.shade50
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.userAchievement.isUnlocked
                        ? Icons.emoji_events
                        : Icons.lock,
                    color: widget.userAchievement.isUnlocked
                        ? Colors.amber
                        : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: widget.userAchievement.isUnlocked
                              ? Colors.black
                              : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    "${_localSliderValue.toInt()}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _localSliderValue.clamp(
                      0.0,
                      details.criteriaValue,
                    ),
                    min: 0.0,
                    max: details.criteriaValue,
                    activeColor: widget.userAchievement.isUnlocked
                        ? Colors.green
                        : Colors.blue,
                    inactiveColor: Colors.grey[300],
                    onChanged: (newValue) {
                      setState(() {
                        _localSliderValue = newValue;
                      });
                    },
                    onChangeEnd: (finalValue) {
                      final difference =
                          finalValue - widget.userAchievement.currentProgress;
                      if (difference.abs() > 0) {
                        widget.viewModel.updateProgress(
                          widget.userAchievement.userAchievementId,
                          difference,
                        );
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    "${details.criteriaValue.toInt()}",
                    textAlign: TextAlign.end,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

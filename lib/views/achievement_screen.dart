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
    if (userId != null && mounted) {
      await context.read<AchievementViewModel>().fetchUserAchievements(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Theme Logic
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final primaryText = Theme.of(context).colorScheme.onSurface;

    // Surface colors for Cards
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          "My Achievements",
          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: scaffoldBg,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
      ),
      body: Consumer<AchievementViewModel>(
        builder: (context, viewModel, child) {

          // Loading
          if (viewModel.isLoading) {
            return Center(child: CircularProgressIndicator(color: const Color(0xFF3B82F6)));
          }

          // Empty
          if (viewModel.userAchievements.isEmpty) {
            return RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 200),
                  Center(
                    child: Text(
                      "No achievements found.",
                      style: TextStyle(color: primaryText.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            );
          }

          // List
          return RefreshIndicator(
            onRefresh: _fetchData,
            color: const Color(0xFF3B82F6),
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: viewModel.userAchievements.length,
                itemBuilder: (context, index) {
                  final userAchievement = viewModel.userAchievements[index];
                  return AchievementTile(
                    userAchievement: userAchievement,
                    viewModel: viewModel,
                    isDark: isDark,
                    surfaceColor: surfaceColor,
                    textColor: primaryText,
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

// --- TILE WIDGET (THEMED) ---
class AchievementTile extends StatefulWidget {
  final UserAchievementModel userAchievement;
  final AchievementViewModel viewModel;

  // Theme props
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;

  const AchievementTile({
    super.key,
    required this.userAchievement,
    required this.viewModel,
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
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

    final isUnlocked = widget.userAchievement.isUnlocked;

    // Colors
    final secondaryText = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final accentBrand = const Color(0xFF3B82F6); // Bright Blue
    final goldColor = const Color(0xFFFFB020);   // Achievement Gold

    // Determine Icon & Color
    final iconColor = isUnlocked ? goldColor : secondaryText.withOpacity(0.5);
    final iconBg = isUnlocked ? goldColor.withOpacity(0.15) : Colors.black.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        // Optional: Gold border if unlocked
        border: isUnlocked ? Border.all(color: goldColor.withOpacity(0.3), width: 1) : null,
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isUnlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: widget.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Slider Row
          Row(
            children: [
              // Current Value
              Container(
                width: 45,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.black26 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  "${_localSliderValue.toInt()}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                    fontSize: 12,
                  ),
                ),
              ),

              // Custom Styled Slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6.0,
                    activeTrackColor: isUnlocked ? goldColor : accentBrand,
                    inactiveTrackColor: widget.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    thumbColor: isUnlocked ? goldColor : accentBrand,
                    overlayColor: (isUnlocked ? goldColor : accentBrand).withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                  ),
                  child: Slider(
                    value: _localSliderValue.clamp(0.0, details.criteriaValue),
                    min: 0.0,
                    max: details.criteriaValue,
                    onChanged: (newValue) {
                      setState(() {
                        _localSliderValue = newValue;
                      });
                    },
                    // Critical: Only update DB when user STOPS dragging
                    onChangeEnd: (finalValue) {
                      final difference = finalValue - widget.userAchievement.currentProgress;
                      if (difference.abs() > 0) {
                        widget.viewModel.updateProgress(
                          widget.userAchievement.userAchievementId,
                          difference,
                        );
                      }
                    },
                  ),
                ),
              ),

              // Max Value
              Container(
                width: 45,
                alignment: Alignment.centerRight,
                child: Text(
                  "${details.criteriaValue.toInt()}",
                  style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
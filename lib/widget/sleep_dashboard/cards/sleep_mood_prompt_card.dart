import 'package:flutter/material.dart';
import 'package:dreamsync/models/sleep_model/mood_feedback.dart';
import 'package:dreamsync/util/app_theme.dart';

class SleepMoodPromptCard extends StatelessWidget {
  final String? pendingFeedbackDate;
  final bool isSubmitting;
  final Future<void> Function(MoodFeedback mood) onSubmit;

  const SleepMoodPromptCard({
    super.key,
    required this.pendingFeedbackDate,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF4FF), Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mood, color: AppTheme.accent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "How do you feel after waking up today?",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pendingFeedbackDate == null
                ? "Please record your mood for the latest sleep sync."
                : "Feedback for $pendingFeedbackDate",
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MoodButton(
                  label: "Sad",
                  emoji: "😢",
                  onTap: isSubmitting ? null : () => onSubmit(MoodFeedback.sad),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoodButton(
                  label: "Neutral",
                  emoji: "😐",
                  onTap:
                  isSubmitting ? null : () => onSubmit(MoodFeedback.neutral),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MoodButton(
                  label: "Happy",
                  emoji: "😊",
                  onTap:
                  isSubmitting ? null : () => onSubmit(MoodFeedback.happy),
                ),
              ),
            ],
          ),
          if (isSubmitting) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 4),
          ],
        ],
      ),
    );
  }
}

class _MoodButton extends StatelessWidget {
  final String label;
  final String emoji;
  final VoidCallback? onTap;

  const _MoodButton({
    required this.label,
    required this.emoji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
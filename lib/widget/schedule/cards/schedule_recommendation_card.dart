import 'package:flutter/material.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/recommendation_viewmodel.dart';

class ScheduleRecommendationCard extends StatelessWidget {
  final RecommendationViewModel recommendationVM;
  final bool isDark;
  final Color text;
  final Color accent;
  final VoidCallback onRefresh;
  final VoidCallback onApply;

  const ScheduleRecommendationCard({
    super.key,
    required this.recommendationVM,
    required this.isDark,
    required this.text,
    required this.accent,
    required this.onRefresh,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subText = isDark ? Colors.white70 : Colors.grey.shade600;
    final shadowColor = Colors.black.withOpacity(isDark ? 0.20 : 0.06);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accent),
              const SizedBox(width: 10),
              Text(
                "Tonight Recommendation",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: text,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onRefresh,
                icon: Icon(Icons.refresh, color: accent),
                tooltip: "Refresh recommendation",
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recommendationVM.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recommendationVM.currentRecommendation == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendationVM.errorMessage.isNotEmpty
                      ? recommendationVM.errorMessage
                      : "No recommendation available yet.",
                  style: TextStyle(color: subText, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  "Sync more sleep history to get a personalised recommendation.",
                  style: TextStyle(color: subText, fontSize: 13),
                ),
              ],
            )
          else ...[
              Builder(
                builder: (_) {
                  final rec = recommendationVM.currentRecommendation!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metricBox(
                              label: "Recommended Sleep",
                              value: rec.recommendedLabel,
                              text: text,
                              subText: subText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricBox(
                              label: "Expected Score",
                              value: "${rec.scoreInt}",
                              text: text,
                              subText: subText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metricBox(
                              label: "Deep Sleep",
                              value: rec.deepLabel,
                              text: text,
                              subText: subText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricBox(
                              label: "REM Sleep",
                              value: rec.remLabel,
                              text: text,
                              subText: subText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        rec.explanation,
                        style: TextStyle(
                          color: subText,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      if ((rec.message ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          rec.message!,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onApply,
                          icon: const Icon(Icons.bedtime),
                          label: const Text("Apply Recommendation"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
        ],
      ),
    );
  }

  Widget _metricBox({
    required String label,
    required String value,
    required Color text,
    required Color subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: subText, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
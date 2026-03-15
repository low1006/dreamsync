import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/recommendation_viewmodel.dart';

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecommendationViewModel>();

    if (vm.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (vm.currentRecommendation == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(vm.errorMessage.isEmpty
              ? 'No recommendation yet.'
              : vm.errorMessage),
        ),
      );
    }

    final rec = vm.currentRecommendation!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tonight Recommendation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Recommended sleep: ${rec.recommendedLabel}'),
            Text('Expected score: ${rec.scoreInt}'),
            Text('Deep sleep: ${rec.deepLabel}'),
            Text('REM sleep: ${rec.remLabel}'),
          ],
        ),
      ),
    );
  }
}
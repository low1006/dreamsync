import 'package:flutter/material.dart';

class SleepDashboardLoadingView extends StatelessWidget {
  final Color accent;
  final Color text;

  const SleepDashboardLoadingView({
    super.key,
    required this.accent,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
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
}
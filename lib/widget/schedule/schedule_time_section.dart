import 'package:flutter/material.dart';
import 'package:dreamsync/widget/schedule/time_card.dart';
import 'package:dreamsync/widget/schedule/day_selector.dart';

class ScheduleTimeSection extends StatelessWidget {
  final TimeOfDay bedTime;
  final TimeOfDay wakeTime;
  final List<String> selectedDays;
  final bool isEditing;

  final Color bg;
  final Color text;
  final Color accent;
  final Color wakeAccent;

  final VoidCallback onPickBedTime;
  final VoidCallback onPickWakeTime;
  final Function(String) onToggleDay;

  const ScheduleTimeSection({
    super.key,
    required this.bedTime,
    required this.wakeTime,
    required this.selectedDays,
    required this.isEditing,
    required this.bg,
    required this.text,
    required this.accent,
    this.wakeAccent = Colors.orange,
    required this.onPickBedTime,
    required this.onPickWakeTime,
    required this.onToggleDay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TimeCard(
                title: "BEDTIME",
                time: bedTime,
                icon: Icons.bed,
                bg: bg,
                text: text,
                accent: accent,
                isEditing: isEditing,
                onTap: onPickBedTime,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TimeCard(
                title: "WAKE UP",
                time: wakeTime,
                icon: Icons.wb_sunny,
                bg: bg,
                text: text,
                accent: wakeAccent,
                isEditing: isEditing,
                onTap: onPickWakeTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Center(
          child: Column(
            children: [
              Text(
                "REPEAT ON",
                style: TextStyle(
                  color: text.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              DaySelector(
                selectedDays: selectedDays,
                activeColor: accent,
                textColor: text,
                isEditing: isEditing,
                onToggle: onToggleDay,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
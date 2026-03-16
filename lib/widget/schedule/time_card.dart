import 'package:flutter/material.dart';
import 'package:dreamsync/util/time_formatter.dart';

class TimeCard extends StatelessWidget {
  final String title;
  final TimeOfDay time;
  final IconData icon;
  final Color bg;
  final Color text;
  final Color accent;
  final bool isEditing;
  final VoidCallback onTap;

  const TimeCard({
    super.key,
    required this.title,
    required this.time,
    required this.icon,
    required this.bg,
    required this.text,
    required this.accent,
    required this.isEditing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = isEditing ? 1.0 : 0.8;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: isEditing ? null : Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: isEditing
              ? Border.all(color: accent.withOpacity(0.5), width: 1.5)
              : Border.all(color: text.withOpacity(0.05)),
        ),
        child: Opacity(
          opacity: opacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: text.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                TimeFormatter.formatTimeOfDay(time),
                style: TextStyle(
                  color: text,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
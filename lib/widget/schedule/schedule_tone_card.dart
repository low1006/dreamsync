import 'package:flutter/material.dart';

class ScheduleToneCard extends StatelessWidget {
  final String toneName;
  final bool isEditing;
  final VoidCallback onTap;
  final Color text;
  final Color subText;
  final Color surface;
  final Color accent;

  const ScheduleToneCard({
    super.key,
    required this.toneName,
    required this.isEditing,
    required this.onTap,
    required this.text,
    required this.subText,
    required this.surface,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withOpacity(0.12),
              child: Icon(Icons.music_note, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Alarm Tone",
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    toneName,
                    style: TextStyle(color: subText, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (isEditing)
              Icon(Icons.chevron_right, color: accent)
            else
              Text(
                toneName,
                style: TextStyle(color: text, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
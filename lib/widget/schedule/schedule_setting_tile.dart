import 'package:flutter/material.dart';

class ScheduleSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final Color text;
  final Color subText;
  final IconData icon;
  final Color iconColor;

  const ScheduleSettingTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.enabled,
    required this.text,
    required this.subText,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: iconColor.withOpacity(0.12),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: subText, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class ScheduleSnoozeCard extends StatelessWidget {
  final bool isEditing;
  final bool isSnoozeOn;
  final int snoozeDurationMinutes;
  final ValueChanged<bool> onToggleSnooze;
  final ValueChanged<double> onSnoozeDurationChanged;

  final Color text;
  final Color subText;
  final Color surface;
  final Color accent;

  const ScheduleSnoozeCard({
    super.key,
    required this.isEditing,
    required this.isSnoozeOn,
    required this.snoozeDurationMinutes,
    required this.onToggleSnooze,
    required this.onSnoozeDurationChanged,
    required this.text,
    required this.subText,
    required this.surface,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bool showDurationSection = isEditing && isSnoozeOn;

    return Opacity(
      opacity: isEditing ? 1.0 : 0.45,
      child: IgnorePointer(
        ignoring: !isEditing,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.orange.withOpacity(0.12),
                      child: const Icon(
                        Icons.snooze_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Snooze",
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            !isSnoozeOn
                                ? "Snooze is turned off"
                                : isEditing
                                ? "Allow alarm snoozing"
                                : "Allow alarm snoozing",
                            style: TextStyle(
                              color: subText,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isEditing && isSnoozeOn) ...[
                      Text(
                        "$snoozeDurationMinutes min",
                        style: TextStyle(
                          color: subText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Switch(
                      value: isSnoozeOn,
                      onChanged: onToggleSnooze,
                    ),
                  ],
                ),
              ),
              if (showDurationSection) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: text.withOpacity(0.06),
                ),
                _SnoozeDurationSection(
                  snoozeDurationMinutes: snoozeDurationMinutes,
                  onChanged: onSnoozeDurationChanged,
                  text: text,
                  subText: subText,
                  accent: accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SnoozeDurationSection extends StatelessWidget {
  final int snoozeDurationMinutes;
  final ValueChanged<double> onChanged;
  final Color text;
  final Color subText;
  final Color accent;

  const _SnoozeDurationSection({
    required this.snoozeDurationMinutes,
    required this.onChanged,
    required this.text,
    required this.subText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Snooze Duration",
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                "$snoozeDurationMinutes min",
                style: TextStyle(
                  color: subText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26, right: 4),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: accent,
                inactiveTrackColor: accent.withOpacity(0.15),
                thumbColor: accent,
                overlayColor: accent.withOpacity(0.12),
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 9,
                ),
              ),
              child: Slider(
                value: snoozeDurationMinutes.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                label: "$snoozeDurationMinutes min",
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              "Slide to adjust snooze duration",
              style: TextStyle(
                color: subText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
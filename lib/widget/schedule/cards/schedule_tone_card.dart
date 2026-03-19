import 'package:flutter/material.dart';

class ScheduleToneCard extends StatelessWidget {
  final String toneName;
  final bool isEditing;
  final VoidCallback onTap;
  final Color text;
  final Color subText;
  final Color surface;
  final Color accent;

  final double alarmVolume;
  final ValueChanged<double>? onVolumeChanged;

  // ✅ Restored Preview properties
  final bool isPreviewPlaying;
  final VoidCallback? onTogglePreview;

  const ScheduleToneCard({
    super.key,
    required this.toneName,
    required this.isEditing,
    required this.onTap,
    required this.text,
    required this.subText,
    required this.surface,
    required this.accent,
    required this.alarmVolume,
    this.onVolumeChanged,
    this.isPreviewPlaying = false,
    this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEditing ? 1.0 : 0.7,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IgnorePointer(
              ignoring: !isEditing,
              child: InkWell(
                onTap: onTap,
                borderRadius: isEditing
                    ? const BorderRadius.vertical(top: Radius.circular(18))
                    : BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                              isEditing
                                  ? "Tap to change"
                                  : "Currently selected",
                              style: TextStyle(
                                color: subText,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        toneName,
                        style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: accent),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            if (isEditing) ...[
              Divider(
                height: 1,
                thickness: 1,
                color: text.withOpacity(0.06),
              ),
              _VolumeSection(
                alarmVolume: alarmVolume,
                onVolumeChanged: onVolumeChanged,
                isPreviewPlaying: isPreviewPlaying,
                onTogglePreview: onTogglePreview,
                text: text,
                subText: subText,
                accent: accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VolumeSection extends StatelessWidget {
  final double alarmVolume;
  final ValueChanged<double>? onVolumeChanged;
  final bool isPreviewPlaying;
  final VoidCallback? onTogglePreview;
  final Color text;
  final Color subText;
  final Color accent;

  const _VolumeSection({
    required this.alarmVolume,
    required this.onVolumeChanged,
    required this.isPreviewPlaying,
    required this.onTogglePreview,
    required this.text,
    required this.subText,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final int volumePercent = (alarmVolume * 100).round();

    IconData volumeIcon;
    if (alarmVolume <= 0.01) {
      volumeIcon = Icons.volume_off;
    } else if (alarmVolume < 0.5) {
      volumeIcon = Icons.volume_down;
    } else {
      volumeIcon = Icons.volume_up;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(volumeIcon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Device Alarm Volume",
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                "$volumePercent%",
                style: TextStyle(
                  color: subText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: accent.withOpacity(0.15),
              thumbColor: accent,
              overlayColor: accent.withOpacity(0.12),
              trackHeight: 5,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: alarmVolume,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: onVolumeChanged,
            ),
          ),

          const SizedBox(height: 8),

          // ✅ Restored Preview Button
          Center(
            child: TextButton.icon(
              onPressed: onTogglePreview,
              icon: Icon(
                isPreviewPlaying ? Icons.stop_circle : Icons.play_circle,
                color: isPreviewPlaying ? Colors.redAccent : accent,
                size: 20,
              ),
              label: Text(
                isPreviewPlaying
                    ? "Stop Preview"
                    : "Preview at This Volume",
                style: TextStyle(
                  color: isPreviewPlaying ? Colors.redAccent : accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: isPreviewPlaying
                    ? Colors.redAccent.withOpacity(0.1)
                    : accent.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
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
  final int systemAlarmMaxSteps;
  final ValueChanged<double>? onVolumeChanged;
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
    this.systemAlarmMaxSteps = 15,
    this.onVolumeChanged,
    this.isPreviewPlaying = false,
    this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    final headerRadius = isEditing
        ? const BorderRadius.vertical(top: Radius.circular(18))
        : BorderRadius.circular(18);

    return Opacity(
      opacity: isEditing ? 1.0 : 0.45,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: isEditing ? onTap : null,
              borderRadius: headerRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                                ? "Tap to change tone"
                                : "Currently selected",
                            style: TextStyle(
                              color: subText,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 72,
                        maxWidth: 150,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              toneName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: text,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isEditing) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: accent,
                              size: 22,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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
                systemAlarmMaxSteps: systemAlarmMaxSteps,
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
  final int systemAlarmMaxSteps;
  final ValueChanged<double>? onVolumeChanged;
  final bool isPreviewPlaying;
  final VoidCallback? onTogglePreview;
  final Color text;
  final Color subText;
  final Color accent;

  const _VolumeSection({
    required this.alarmVolume,
    required this.systemAlarmMaxSteps,
    required this.onVolumeChanged,
    required this.isPreviewPlaying,
    required this.onTogglePreview,
    required this.text,
    required this.subText,
    required this.accent,
  });

  double _snapToSystemStep(double rawValue) {
    final value = rawValue.clamp(0.0, 1.0);

    if (systemAlarmMaxSteps <= 0) return value;

    final stepIndex = (value * systemAlarmMaxSteps)
        .round()
        .clamp(0, systemAlarmMaxSteps);

    return stepIndex / systemAlarmMaxSteps;
  }

  @override
  Widget build(BuildContext context) {
    final snappedValue = _snapToSystemStep(alarmVolume);
    final volumePercent = (snappedValue * 100).round().clamp(0, 100);

    IconData volumeIcon;
    if (snappedValue <= 0.001) {
      volumeIcon = Icons.volume_off;
    } else if (snappedValue < 0.5) {
      volumeIcon = Icons.volume_down;
    } else {
      volumeIcon = Icons.volume_up;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                value: snappedValue,
                min: 0.0,
                max: 1.0,
                divisions: systemAlarmMaxSteps > 0 ? systemAlarmMaxSteps : 15,
                onChanged: onVolumeChanged == null
                    ? null
                    : (raw) => onVolumeChanged!(_snapToSystemStep(raw)),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(
              "Slide to adjust — tone plays automatically",
              style: TextStyle(
                color: subText,
                fontSize: 12,
              ),
            ),
          ),
          if (isPreviewPlaying) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: TextButton.icon(
                onPressed: onTogglePreview,
                icon: Icon(
                  Icons.stop_circle_outlined,
                  color: Colors.redAccent,
                ),
                label: Text(
                  "Stop preview",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
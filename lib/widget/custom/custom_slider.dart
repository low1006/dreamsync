import 'package:flutter/material.dart';

class CustomSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String unit;
  final Function(double) onChanged;

  const CustomSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Determine Theme Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Define Colors Dynamically
    // Labels: Muted Blue-Grey (Dark) vs Slate (Light)
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Tracks: Dark Slate (Dark) vs Light Grey (Light)
    final inactiveTrack = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    // Value Box Background: Dark Surface (Dark) vs Light Grey (Light)
    final valueBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    // Value Box Border: Matches inactive track for subtle outline
    final borderColor = inactiveTrack;

    // Brand Colors (Keep these consistent to maintain identity)
    const activeTrack = Color(0xFF3B82F6);   // Bright Blue
    const thumbColor = Color(0xFF60A5FA);    // Light Blue

    return Column(
      children: [
        // Label & Value Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: secondaryText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: valueBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                "${value.toInt()} $unit",
                style: const TextStyle(
                  color: thumbColor, // Highlight value with brand color
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // The Slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 6.0,
            activeTrackColor: activeTrack,
            inactiveTrackColor: inactiveTrack,
            thumbColor: thumbColor,
            overlayColor: thumbColor.withOpacity(0.2), // Glow around thumb
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0, elevation: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
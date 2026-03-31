import 'package:flutter/material.dart';

class DaySelector extends StatelessWidget {
  final List<String> selectedDays;
  final Function(String) onToggle;
  final Color activeColor;
  final Color textColor;
  final bool isEditing;

  const DaySelector({
    super.key,
    required this.selectedDays,
    required this.onToggle,
    required this.activeColor,
    required this.textColor,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    return IgnorePointer(
      ignoring: !isEditing,
      child: Opacity(
        opacity: isEditing ? 1.0 : 0.45,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: allDays.map((day) {
            final isSelected = selectedDays.contains(day);

            return InkWell(
              onTap: () => onToggle(day),
              borderRadius: BorderRadius.circular(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? activeColor : textColor.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  day[0],
                  style: TextStyle(
                    color: isSelected ? Colors.white : textColor.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
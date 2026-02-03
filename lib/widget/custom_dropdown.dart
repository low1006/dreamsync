import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String label;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;

  const CustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Determine Theme Mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Define Dynamic Colors (Exact match with CustomTextField)
    // Surface: Dark Blue-Grey (Dark) vs Light Grey (Light)
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    // Text: White (Dark) vs Dark Blue-Grey (Light)
    final primaryText = Theme.of(context).colorScheme.onSurface;

    // Icons/Labels: Muted Blue-Grey (Dark) vs Slate (Light)
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Universal Colors
    const focusColor = Color(0xFF3B82F6);
    const errorColor = Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), // Softer shadow in light mode
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((String val) {
          return DropdownMenuItem(
            value: val,
            child: Text(val),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,

        isExpanded: true,
        dropdownColor: surfaceColor, // Menu background matches the field
        borderRadius: BorderRadius.circular(16),
        menuMaxHeight: 300,

        style: TextStyle(
          color: primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
        ),

        icon: Icon(Icons.keyboard_arrow_down, color: secondaryText),

        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryText),
          floatingLabelStyle: const TextStyle(color: focusColor),

          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),

          border: InputBorder.none,

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: focusColor, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: errorColor, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: errorColor, width: 1.5),
          ),
        ),
      ),
    );
  }
}
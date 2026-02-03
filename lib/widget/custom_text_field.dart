import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isObscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  final String? prefixText;
  final TextStyle? prefixStyle;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.isObscure = false,
    this.keyboardType,
    this.validator,
    this.prefixText,
    this.prefixStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final secondaryText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const focusColor = Color(0xFF3B82F6);
    const errorColor = Color(0xFFEF4444);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isObscure,
        keyboardType: keyboardType,
        style: TextStyle(
          color: primaryText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: focusColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryText),
          floatingLabelStyle: const TextStyle(color: focusColor),

          // --- NEW: Add the Prefix Logic Here ---
          prefixText: prefixText,
          prefixStyle: prefixStyle ?? TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold
          ),
          // --------------------------------------

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
        validator: validator,
      ),
    );
  }
}
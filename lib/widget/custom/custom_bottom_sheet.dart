import 'package:flutter/material.dart';
import 'package:dreamsync/util/app_theme.dart';

class CustomBottomSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final String buttonText;
  final bool isButtonEnabled;
  final VoidCallback? onSave;
  final bool showBottomButton; // Added this flag

  const CustomBottomSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.buttonText = "Save",
    this.isButtonEnabled = true,
    this.onSave,
    this.showBottomButton = true, // Defaults to true so other screens don't break
  });

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg = AppTheme.card(context);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardHeight + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.subText(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Header ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Unique Content ──
            content,

            // ── Conditional Bottom Button ──
            if (showBottomButton) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isButtonEnabled
                        ? AppTheme.accent
                        : AppTheme.subText(context).withOpacity(0.2),
                    foregroundColor: isButtonEnabled
                        ? Colors.white
                        : AppTheme.subText(context),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: isButtonEnabled ? onSave : null,
                  child: Text(buttonText,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
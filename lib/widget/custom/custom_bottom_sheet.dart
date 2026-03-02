import 'package:flutter/material.dart';

class CustomBottomSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final String buttonText;
  final bool isButtonEnabled;
  final VoidCallback? onSave;

  const CustomBottomSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    this.buttonText = "Save",
    this.isButtonEnabled = true,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    // This padding ensures the sheet sits above the keyboard
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, keyboardHeight + 20),
      // THE FIX: SingleChildScrollView only takes a child.
      // MainAxisSize.min must be inside the Column.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Correct placement
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
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
                    color: Colors.indigoAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.indigoAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Unique Content (Search Bars / TextFields) ──
            content,

            const SizedBox(height: 28),

            // ── Standard Save Button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isButtonEnabled ? Colors.indigoAccent : Colors.grey.shade300,
                  foregroundColor: isButtonEnabled ? Colors.white : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: isButtonEnabled ? onSave : null,
                child: Text(buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dreamsync/services/notification_service.dart';

class AlarmRingScreen extends StatefulWidget {
  final int notificationId;
  final VoidCallback onStop; // Callback to stop alarm sound
  final Function(int) onSnooze; // Callback to handle snooze

  const AlarmRingScreen({
    super.key,
    required this.notificationId,
    required this.onStop,
    required this.onSnooze,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSnoozeEnabled = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Check if snooze is enabled for this alarm
    _checkSnoozeStatus();
  }

  Future<void> _checkSnoozeStatus() async {
    // Extract the base alarm ID from notification ID
    final baseId = (widget.notificationId ~/ 10) % 100000;
    final isEnabled = NotificationService().isSnoozeEnabled(baseId);

    setState(() {
      _isSnoozeEnabled = isEnabled;
    });

    debugPrint("💤 Snooze enabled for this alarm: $_isSnoozeEnabled");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _stopAlarm() {
    debugPrint("🛑 Stop button pressed");

    // Stop the alarm sound
    widget.onStop();

    // Cancel the notification
    NotificationService()
        .flutterLocalNotificationsPlugin
        .cancel(widget.notificationId);

    // Close the screen
    Navigator.of(context).pop();
  }

  void _snoozeAlarm() {
    if (!_isSnoozeEnabled) {
      // If snooze is disabled, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snooze is disabled for this alarm'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    debugPrint("😴 Snooze button pressed");

    // Trigger snooze callback (handles scheduling next alarm)
    widget.onSnooze(widget.notificationId);

    // Close the screen
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    return WillPopScope(
      // Prevent back button from dismissing alarm
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                ),
              ),
            ),

            // Main content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Alarm icon with pulsing animation
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.2).animate(_controller),
                  child: const Icon(
                    Icons.alarm,
                    size: 100,
                    color: Colors.white70,
                  ),
                ),

                const SizedBox(height: 30),

                // "Wake Up!" text
                Text(
                  "WAKE UP!",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 32,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // Current time display
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 90,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                // Date display
                Text(
                  DateFormat('EEEE, MMMM d').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 80),

                // SNOOZE BUTTON (only shown if enabled)
                if (_isSnoozeEnabled)
                  OutlinedButton(
                    onPressed: _snoozeAlarm,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54, width: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.snooze, color: Colors.white, size: 24),
                        SizedBox(width: 10),
                        Text(
                          "SNOOZE (9 min)",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_isSnoozeEnabled) const SizedBox(height: 30),

                // STOP BUTTON (always shown)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ScaleTransition(
                    scale: Tween(begin: 1.0, end: 1.05).animate(_controller),
                    child: ElevatedButton(
                      onPressed: _stopAlarm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 70,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        elevation: 15,
                        shadowColor: Colors.redAccent.withOpacity(0.6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.stop_circle, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Text(
                            "STOP ALARM",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Instruction text
                if (!_isSnoozeEnabled)
                  Text(
                    "Snooze is disabled",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dreamsync/services/notification_service.dart'; // Import this

class AlarmRingScreen extends StatefulWidget {
  final String? payload;
  final int notificationId; // REQUIRED: To know which alarm to stop

  const AlarmRingScreen({
    super.key,
    this.payload,
    required this.notificationId // Add this
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _stopAlarm() {
    // 1. Stop the sound/notification
    // Note: We need to cancel the specific ID associated with this instance
    // Since your unique ID generation logic relies on Days, and we might
    // simply want to stop the sound *now*, passing the exact notification ID is safest.
    NotificationService().flutterLocalNotificationsPlugin.cancel(widget.notificationId);

    // 2. Close the screen
    Navigator.of(context).pop();
  }

  void _snoozeAlarm() {
    // Logic: Stop current sound, schedule new one in 9 mins
    NotificationService().flutterLocalNotificationsPlugin.cancel(widget.notificationId);

    // You would add logic here to schedule a new one-off notification for +9 mins
    // For now, we just close the screen
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm, size: 80, color: Colors.white70),
              const SizedBox(height: 20),
              Text(
                "Wake Up!",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 24, letterSpacing: 2),
              ),
              const SizedBox(height: 10),
              Text(
                timeStr,
                style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 60),

              // SNOOZE
              OutlinedButton(
                onPressed: _snoozeAlarm,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("SNOOZE (9 min)", style: TextStyle(color: Colors.white, fontSize: 18)),
              ),

              const SizedBox(height: 40),

              // STOP BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.1).animate(_controller),
                  child: ElevatedButton(
                    onPressed: _stopAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      elevation: 10,
                      shadowColor: Colors.redAccent.withOpacity(0.5),
                    ),
                    child: const Text(
                        "STOP ALARM",
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
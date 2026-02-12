import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dreamsync/services/notification_service.dart';

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  int _notificationId = 0;
  String _title = "Wake Up!";
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _notificationId = args['id'] ?? 0;
        _title = args['title'] ?? 'Wake Up!';
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    // 1. Stop the Sound
    await NotificationService().stopNotification(_notificationId);
    await NotificationService().stopNotification(_notificationId + 100000); // Check snooze ID too

    if (mounted) {
      // 2. Navigate Home
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<void> _snoozeAlarm() async {
    // 1. Stop Sound
    await NotificationService().stopNotification(_notificationId);
    await NotificationService().stopNotification(_notificationId + 100000);

    // 2. Schedule Snooze
    // Use base ID logic
    int baseId = _notificationId > 100000 ? _notificationId - 100000 : _notificationId;
    await NotificationService().scheduleSnooze(baseId);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
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
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.2).animate(_controller),
                  child: const Icon(Icons.alarm, size: 100, color: Colors.white70),
                ),
                const SizedBox(height: 30),
                Text(
                  _title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 90,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 80),
                OutlinedButton(
                  onPressed: _snoozeAlarm,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54, width: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                  ),
                  child: const Text("SNOOZE (9 min)",
                      style: TextStyle(color: Colors.white, fontSize: 20)),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _stopAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 70),
                    ),
                    child: const Text("STOP ALARM",
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
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

  // --- ALARM DATA ---
  bool _isSmartAlarm = false;
  bool _isSnoozeOn = true;
  int _snoozeCount = 0;
  String _currentSoundFile = "classic.mp3"; // Default if payload fails

  Timer? _smartTimer;
  final AudioPlayer _loudPlayer = AudioPlayer();
  bool _isPanicMode = false;

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
        _isSmartAlarm = args['isSmartAlarm'] ?? false;
        _isSnoozeOn = args['isSnoozeOn'] ?? true;
        _snoozeCount = args['snoozeCount'] ?? 0;
        _currentSoundFile = args['soundFile'] ?? "classic.mp3"; // Get from payload
      }

      // 1. Strike Limit (Triggered immediately if this notification was the 3rd ring)
      if (_isSmartAlarm && _snoozeCount >= 2) {
        debugPrint("🚨 Strike Limit Reached (2 Snoozes). Panic Mode Active.");
        _activatePanicMode();
        // Force snooze off in UI as a failsafe
        setState(() => _isSnoozeOn = false);
      }
      // 2. Timer Fallback (If user ignores alarm for 5 mins)
      else if (_isSmartAlarm) {
        debugPrint("⏰ Smart Alarm: Timer started. (Snoozes used: $_snoozeCount)");
        _smartTimer = Timer(const Duration(minutes: 5), _activatePanicMode);
      }

      _isInit = false;
    }
  }

  Future<void> _activatePanicMode() async {
    if (!mounted) return;

    // Stop notification immediately so they don't overlap
    await NotificationService().stopNotification(_notificationId);

    try {
      await _loudPlayer.setVolume(1.0);
      await _loudPlayer.setReleaseMode(ReleaseMode.loop);
      await _loudPlayer.play(AssetSource('audio/buzzer.mp3'));
    } catch (e) {
      debugPrint("Error playing panic sound: $e");
    }

    setState(() {
      _isPanicMode = true;
      _title = "WAKE UP NOW!";
      _controller.duration = const Duration(milliseconds: 300);
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _smartTimer?.cancel();
    _loudPlayer.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    _smartTimer?.cancel();
    await _loudPlayer.stop();

    await NotificationService().stopNotification(_notificationId);
    await NotificationService().stopNotification(_notificationId + 100000);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<void> _snoozeAlarm() async {
    _smartTimer?.cancel();
    await _loudPlayer.stop();

    await NotificationService().stopNotification(_notificationId);
    await NotificationService().stopNotification(_notificationId + 100000);

    // --- DECIDE NEXT SOUND ---
    // If next ring will be the 3rd one (count 2), use BUZZER.
    // Otherwise use the current normal sound (e.g. Classic).
    String nextSoundFile = _currentSoundFile;
    if (_isSmartAlarm && (_snoozeCount + 1) >= 2) {
      nextSoundFile = 'buzzer.mp3';
    }

    await NotificationService().scheduleSnooze(
      originalId: _notificationId > 100000 ? _notificationId - 100000 : _notificationId,
      currentSnoozeCount: _snoozeCount,
      isSmartAlarm: _isSmartAlarm,
      isSnoozeOn: _isSnoozeOn,
      soundFile: nextSoundFile, // <--- KEY FIX
    );

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
        backgroundColor: _isPanicMode ? Colors.red.shade900 : Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _isPanicMode
                      ? [const Color(0xFF8B0000), const Color(0xFF2E0000)]
                      : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.2).animate(_controller),
                  child: Icon(
                      Icons.alarm,
                      size: 100,
                      color: _isPanicMode ? Colors.yellow : Colors.white70
                  ),
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
                if (_isSmartAlarm) ...[
                  const SizedBox(height: 10),
                  Text(
                    _isPanicMode
                        ? "Smart Alarm: Limit Reached!"
                        : "Smart Alarm Active (Snoozes: $_snoozeCount/2)",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 80),

                // Hide Snooze button if Panic Mode is on OR Snooze is disabled
                if (_isSnoozeOn && !_isPanicMode) ...[
                  OutlinedButton(
                    onPressed: _snoozeAlarm,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                    ),
                    child: const Text("SNOOZE (5 min)",
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  const SizedBox(height: 30),
                ],

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _stopAlarm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPanicMode ? Colors.white : Colors.redAccent,
                      foregroundColor: _isPanicMode ? Colors.red : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 70),
                    ),
                    child: const Text("STOP ALARM",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
import 'dart:async';

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

  bool _isSmartAlarm = false;
  bool _isSnoozeOn = true;
  int _snoozeCount = 0;
  String _currentSoundFile = "classic.mp3";

  Timer? _smartTimer;
  bool _isPanicMode = false;

  double _sliderValue = 0.0;
  bool _isStopping = false;

  final NotificationService _service = NotificationService();

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
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        _notificationId = (args['id'] as num?)?.toInt() ?? 0;

        final rawSmartAlarm = args['isSmartAlarm'];
        _isSmartAlarm = rawSmartAlarm == true || rawSmartAlarm == 'true' || rawSmartAlarm == 1;

        final rawSnooze = args['isSnoozeOn'];
        _isSnoozeOn = rawSnooze == null ? true : (rawSnooze == true || rawSnooze == 'true' || rawSnooze == 1);

        _snoozeCount = (args['snoozeCount'] as num?)?.toInt() ?? 0;

        _currentSoundFile = NotificationService.normalizeSoundFile(
          args['soundFile']?.toString(),
        );
      }

      debugPrint(
          '🔔 AlarmRingScreen opened: id=$_notificationId '
              'snooze=$_snoozeCount isSnoozeOn=$_isSnoozeOn '
              'isSmartAlarm=$_isSmartAlarm sound=$_currentSoundFile '
      );

      if (_service.shouldEnterPanicMode(
        isSmartAlarm: _isSmartAlarm,
        snoozeCount: _snoozeCount,
      )) {
        debugPrint(
          "🚨 Strike limit reached ($_snoozeCount/"
              "${NotificationService.smartAlarmMaxSnoozes}). Panic mode!",
        );
        _activatePanicMode();
        setState(() => _isSnoozeOn = false);
      } else {
        if (_isSmartAlarm) {
          _smartTimer = Timer(
              const Duration(minutes: 1),
                  () {
                debugPrint("⏳ 1 minute elapsed with no action. Escalating to Panic Mode!");
                _activatePanicMode();
              }
          );
        }
      }

      _isInit = false;
    }
  }

  Future<void> _activatePanicMode() async {
    if (!mounted || _isPanicMode) return;

    await _service.stopNotification(_notificationId);

    // Fire a NEW notification with the buzzer sound
    await _service.showAlarmNotification(
        id: _notificationId,
        title: "WAKE UP NOW!",
        body: "Smart Alarm Limit Reached",
        soundFile: "buzzer.mp3"
    );

    setState(() {
      _isPanicMode = true;
      _title = "WAKE UP NOW!";
      _controller.duration = const Duration(milliseconds: 300);
      _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _smartTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    if (_isStopping) return;
    _isStopping = true;

    _smartTimer?.cancel();

    await _service.handleStopAlarm(notificationId: _notificationId);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _snoozeAlarm() async {
    _smartTimer?.cancel();

    await _service.handleSnooze(
      notificationId: _notificationId,
      snoozeCount: _snoozeCount,
      isSmartAlarm: _isSmartAlarm,
      isSnoozeOn: _isSnoozeOn,
      soundFile: _currentSoundFile,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/');
  }

  Widget _buildStopSlider() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Slide to stop alarm",
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              inactiveTrackColor: Colors.white24,
              activeTrackColor: _isPanicMode ? Colors.yellow : Colors.redAccent,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _sliderValue,
              min: 0,
              max: 1,
              onChanged: (value) async {
                setState(() => _sliderValue = value);
                if (value >= 0.95) {
                  await _stopAlarm();
                }
              },
              onChangeEnd: (value) {
                if (value < 0.95 && mounted) {
                  setState(() => _sliderValue = 0.0);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(DateTime.now());

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _isPanicMode ? Colors.red.shade900 : Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isPanicMode
                  ? [const Color(0xFF8B0000), const Color(0xFF2E0000)]
                  : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: Tween(begin: 1.0, end: 1.2).animate(_controller),
                              child: Icon(
                                Icons.alarm,
                                size: 90,
                                color: _isPanicMode ? Colors.yellow : Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _title.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 80,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isSmartAlarm)
                              Text(
                                _isPanicMode
                                    ? "Smart Alarm: Limit Reached!"
                                    : "Smart Alarm Active "
                                    "(Snoozes: $_snoozeCount/"
                                    "${NotificationService.smartAlarmMaxSnoozes})",
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isSnoozeOn && !_isPanicMode) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _snoozeAlarm,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          "SNOOZE (1 min)",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildStopSlider(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
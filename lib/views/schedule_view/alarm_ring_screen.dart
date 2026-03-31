import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/alarm_ring_viewmodel.dart';

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AlarmRingViewModel _vm;

  double _sliderValue = 0.0;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _vm = AlarmRingViewModel();

    _vm.onAlarmDismissed = () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/');
    };

    _vm.onPanicModeActivated = () {
      if (mounted) {
        _controller.duration = const Duration(milliseconds: 300);
        _controller.repeat(reverse: true);
      }
    };

    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInit) {
      final args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _vm.initialize(args);
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    _controller.dispose();
    super.dispose();
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
              activeTrackColor:
              _vm.isPanicMode ? Colors.yellow : Colors.redAccent,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: _sliderValue,
              min: 0,
              max: 1,
              onChanged: (value) async {
                setState(() => _sliderValue = value);
                if (value >= 0.95) {
                  await _vm.stopAlarm();
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
        backgroundColor:
        _vm.isPanicMode ? Colors.red.shade900 : Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _vm.isPanicMode
                  ? [const Color(0xFF8B0000), const Color(0xFF2E0000)]
                  : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: Tween(begin: 1.0, end: 1.2)
                                  .animate(_controller),
                              child: Icon(
                                Icons.alarm,
                                size: 90,
                                color: _vm.isPanicMode
                                    ? Colors.yellow
                                    : Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _vm.title.toUpperCase(),
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
                            if (_vm.isSmartAlarm)
                              Text(
                                _vm.isPanicMode
                                    ? "Smart Alarm: Limit Reached!"
                                    : "Smart Alarm Active "
                                    "(Snoozes: ${_vm.snoozeCount}/"
                                    "${_vm.maxSnoozes})",
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
                  if (_vm.isSnoozeOn && !_vm.isPanicMode) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _vm.snooze,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.white54, width: 2),
                          padding:
                          const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          "SNOOZE (${_vm.snoozeDurationMinutes} min)",
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
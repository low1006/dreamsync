import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dreamsync/services/notification_service.dart';

/// ViewModel for the alarm ring screen.
///
/// Manages snooze counting, panic mode escalation, smart alarm timer,
/// and notification interactions. The View only handles UI and navigation.
class AlarmRingViewModel extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  // ─── State ──────────────────────────────────────────────────────────────
  int _notificationId = 0;
  String _title = "Wake Up!";
  bool _isSmartAlarm = false;
  bool _isSnoozeOn = true;
  int _snoozeCount = 0;
  String _currentSoundFile = "classic.mp3";
  bool _isPanicMode = false;
  bool _isStopping = false;
  int _snoozeDurationMinutes = 5;
  Timer? _smartTimer;

  // ─── Callbacks for View (navigation, animation) ─────────────────────────
  VoidCallback? onAlarmDismissed;
  VoidCallback? onPanicModeActivated;

  // ─── Getters ────────────────────────────────────────────────────────────
  int get notificationId => _notificationId;
  String get title => _title;
  bool get isSmartAlarm => _isSmartAlarm;
  bool get isSnoozeOn => _isSnoozeOn;
  int get snoozeCount => _snoozeCount;
  bool get isPanicMode => _isPanicMode;
  bool get isStopping => _isStopping;
  int get snoozeDurationMinutes => _snoozeDurationMinutes;
  int get maxSnoozes => NotificationService.smartAlarmMaxSnoozes;

  // ─── Initialization ─────────────────────────────────────────────────────

  /// Parses route arguments and starts smart alarm timer if needed.
  void initialize(Map<String, dynamic>? args) {
    if (args != null) {
      _notificationId = (args['id'] as num?)?.toInt() ?? 0;

      final rawSmartAlarm = args['isSmartAlarm'];
      _isSmartAlarm =
          rawSmartAlarm == true || rawSmartAlarm == 'true' || rawSmartAlarm == 1;

      final rawSnooze = args['isSnoozeOn'];
      _isSnoozeOn = rawSnooze == null
          ? true
          : (rawSnooze == true || rawSnooze == 'true' || rawSnooze == 1);

      _snoozeCount = (args['snoozeCount'] as num?)?.toInt() ?? 0;

      _currentSoundFile = NotificationService.normalizeSoundFile(
        args['soundFile']?.toString(),
      );

      _snoozeDurationMinutes =
          (args['snoozeDurationMinutes'] as num?)?.toInt() ?? 5;
    }

    debugPrint(
      '🔔 AlarmRingVM initialized: id=$_notificationId '
          'snooze=$_snoozeCount isSnoozeOn=$_isSnoozeOn '
          'isSmartAlarm=$_isSmartAlarm sound=$_currentSoundFile',
    );

    // If smart alarm already reached max snoozes, enter panic mode in UI only.
    // DO NOT re-show the native alarm notification here, because the callback
    // already showed it when the alarm fired.
    if (_service.shouldEnterPanicMode(
      isSmartAlarm: _isSmartAlarm,
      snoozeCount: _snoozeCount,
    )) {
      debugPrint(
        "🚨 Strike limit reached ($_snoozeCount/$maxSnoozes). Panic mode!",
      );
      _activatePanicMode();
    } else if (_isSmartAlarm) {
      // Auto-trigger after 1 minute of no interaction.
      _smartTimer = Timer(const Duration(minutes: 1), () async {
        debugPrint(
          "⏳ 1 minute elapsed with no action.",
        );

        if (!_isSnoozeOn) {
          // Snooze is off: Change to buzzer notification immediately
          await _service.stopNotification(_notificationId);
          await _service.showAlarmNotification(
            id: _notificationId,
            title: "WAKE UP NOW!",
            body: "Smart Alarm triggered!",
            soundFile: "buzzer.mp3",
          );
          _activatePanicMode();
        } else {
          // Snooze is on: proceed with standard auto-snooze
          debugPrint("Auto-snoozing (snooze ${_snoozeCount + 1}/$maxSnoozes).");
          snooze();
        }
      });
    }
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  Future<void> _activatePanicMode() async {
    if (_isPanicMode) return;

    // Important:
    // The alarm callback already displayed the loud native notification.
    // Panic mode here should only update in-app UI state and disable snooze.
    _isPanicMode = true;
    _isSnoozeOn = false;
    _title = "WAKE UP NOW!";

    notifyListeners();
    onPanicModeActivated?.call();

    debugPrint(
      "🚨 Panic mode activated in UI only for id=$_notificationId "
          "(native alarm notification will not be shown again).",
    );
  }

  Future<void> stopAlarm() async {
    if (_isStopping) return;

    _isStopping = true;
    notifyListeners();

    _smartTimer?.cancel();

    try {
      await _service.handleStopAlarm(notificationId: _notificationId);
      onAlarmDismissed?.call();
    } catch (e, st) {
      debugPrint('❌ stopAlarm error: $e');
      debugPrint('$st');
      _isStopping = false;
      notifyListeners();
    }
  }

  Future<void> snooze() async {
    if (_isStopping) return;

    _smartTimer?.cancel();

    try {
      await _service.handleSnooze(
        notificationId: _notificationId,
        snoozeCount: _snoozeCount,
        isSmartAlarm: _isSmartAlarm,
        isSnoozeOn: _isSnoozeOn,
        soundFile: _currentSoundFile,
        snoozeDurationMinutes: _snoozeDurationMinutes,
      );

      onAlarmDismissed?.call();
    } catch (e, st) {
      debugPrint('❌ snooze error: $e');
      debugPrint('$st');
    }
  }

  // ─── Cleanup ────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _smartTimer?.cancel();
    super.dispose();
  }
}
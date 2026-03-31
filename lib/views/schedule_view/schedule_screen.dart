import "package:dreamsync/util/app_theme.dart";
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/recommendation_viewmodel.dart';

import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/models/inventory_model.dart';

// Widgets
import 'package:dreamsync/widget/schedule/selectors/tone_selector.dart';
import 'package:dreamsync/widget/schedule/schedule_setting_tile.dart';
import 'package:dreamsync/widget/schedule/cards/schedule_recommendation_card.dart';
import 'package:dreamsync/widget/schedule/schedule_time_section.dart';
import 'package:dreamsync/widget/schedule/cards/schedule_tone_card.dart';
import 'package:dreamsync/widget/schedule/cards/schedule_snooze_card.dart';
import 'package:dreamsync/util/time_formatter.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isEditing = false;
  bool _isInit = true;
  bool _isBootstrapping = false;
  String? _existingId;

  late TimeOfDay _bedTime;
  late TimeOfDay _wakeTime;
  late List<String> _selectedDays;
  late bool _isSmartAlarm;
  late bool _isSmartNotification;
  late bool _isAlarmOn;
  late bool _isSnoozeOn;
  int _snoozeDurationMinutes = 5;

  int _currentToneId = 1;
  String _currentToneName = "Classic";
  String _currentToneFile = "classic.mp3";

  double _hardwareAlarmVolume = 1.0;
  int _systemAlarmMaxSteps = 7;

  final AudioPlayer _volumePreviewPlayer = AudioPlayer();
  bool _isPreviewPlaying = false;
  Timer? _volumePreviewAutoStop;
  Timer? _volumeSliderDebounce;

  @override
  void initState() {
    super.initState();

    _bedTime = const TimeOfDay(hour: 22, minute: 30);
    _wakeTime = const TimeOfDay(hour: 7, minute: 0);
    _selectedDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
    _isSmartAlarm = true;
    _isSmartNotification = true;
    _isAlarmOn = true;
    _isSnoozeOn = true;

    FlutterVolumeController.getVolume(stream: AudioStream.alarm).then((vol) {
      if (mounted && vol != null) {
        setState(() => _hardwareAlarmVolume = vol);
      }
    });

    NotificationService.getSystemAlarmMaxSteps().then((steps) {
      if (mounted) {
        setState(() => _systemAlarmMaxSteps = steps);
        debugPrint('🔊 Device alarm stream has $_systemAlarmMaxSteps steps');
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _volumePreviewAutoStop?.cancel();
    _volumeSliderDebounce?.cancel();
    _volumePreviewPlayer.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_isBootstrapping) return;
    _isBootstrapping = true;

    try {
      await NotificationService().init();

      final scheduleVM = context.read<ScheduleViewModel>();
      final inventoryVM = context.read<InventoryViewModel>();
      final dailyVM = context.read<DailyActivityViewModel>();
      final profileVM = context.read<ProfileViewModel>();

      await scheduleVM.loadSchedules();
      await inventoryVM.loadInventory();

      final userId = profileVM.userProfile?.userId;
      if (userId != null) {
        await dailyVM.loadTodayData(userId);
        await _loadRecommendation(forceRefresh: true);
      }

      _syncFromViewModel(scheduleVM);
    } finally {
      if (mounted) {
        setState(() => _isInit = false);
      }
      _isBootstrapping = false;
    }
  }

  void _syncFromViewModel(
      ScheduleViewModel vm, {
        ScheduleModel? overrideSchedule,
      }) {
    final schedule =
        overrideSchedule ?? (vm.schedules.isNotEmpty ? vm.schedules.first : null);
    if (schedule == null) return;

    _existingId = schedule.id;
    _bedTime = schedule.bedtime;
    _wakeTime = schedule.wakeTime;
    _selectedDays = List<String>.from(schedule.days);
    _isAlarmOn = schedule.isActive;
    _isSmartAlarm = schedule.isSmartAlarm;
    _isSnoozeOn = schedule.isSnoozeOn;
    _snoozeDurationMinutes = schedule.snoozeDurationMinutes;
    _currentToneId = schedule.toneId;
    _currentToneName = schedule.toneName;
    _currentToneFile = schedule.toneFile;
    _isSmartNotification = schedule.isSmartNotification;
  }

  Future<void> _loadRecommendation({bool forceRefresh = false}) async {
    final profileVM = context.read<ProfileViewModel>();
    final dailyVM = context.read<DailyActivityViewModel>();
    final recommendationVM = context.read<RecommendationViewModel>();

    final userId = profileVM.userProfile?.userId;
    if (userId == null) return;

    await recommendationVM.loadRecommendation(
      userId: userId,
      exerciseMinutes: dailyVM.exerciseMinutes,
      foodCalories: dailyVM.foodCalories,
      screenMinutes: dailyVM.screenTimeMinutes,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _rescheduleAlarm() async {
    const int baseNotificationId = 10000;

    if (_isAlarmOn || _isSmartNotification) {
      await NotificationService().scheduleAlarm(
        id: baseNotificationId,
        title: "Wake Up",
        time: _wakeTime,
        bedTime: _bedTime,
        days: _selectedDays,
        isAlarmEnabled: _isAlarmOn,
        isSnoozeOn: _isSnoozeOn,
        isSmartNotification: _isSmartNotification,
        isSmartAlarm: _isSmartAlarm,
        soundFile: _currentToneFile,
        snoozeDurationMinutes: _snoozeDurationMinutes,
      );
    } else {
      await NotificationService().cancelAlarm(baseNotificationId);
    }
  }

  Future<void> _quickUpdate(bool isAlarmActive) async {
    if (_existingId == null || _existingId!.isEmpty) return;

    await context.read<ScheduleViewModel>().toggleSchedule(
      _existingId!,
      isAlarmActive,
    );

    await _rescheduleAlarm();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAlarmActive ? "Alarm Enabled" : "Alarm Disabled"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleEditMode() {
    if (_isEditing) {
      _stopVolumePreview();
      _saveSchedule();
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _pickTime(bool isBedtime) async {
    if (!_isEditing) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: isBedtime ? _bedTime : _wakeTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isBedtime) {
          _bedTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  Future<void> _saveSchedule() async {
    final scheduleVM = context.read<ScheduleViewModel>();
    final userVM = context.read<ProfileViewModel>();

    final double mySleepGoal = userVM.userProfile?.sleepGoalHours ?? 8.0;

    final validationResult = await scheduleVM.validateScheduleBeforeSave(
      bedtime: _bedTime,
      wakeTime: _wakeTime,
      days: _selectedDays,
      sleepGoal: mySleepGoal,
    );

    if (validationResult.status == ScheduleSaveStatus.validationError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationResult.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (validationResult.status == ScheduleSaveStatus.confirmationRequired) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Less Duration"),
          content: Text(validationResult.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Confirm"),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    final scheduleBeingSaved = ScheduleModel(
      id: _existingId ?? '',
      label: "Main Schedule",
      bedtime: _bedTime,
      wakeTime: _wakeTime,
      isActive: _isAlarmOn,
      days: _selectedDays,
      isSmartAlarm: _isSmartAlarm,
      isSmartNotification: _isSmartNotification,
      isSnoozeOn: _isSnoozeOn,
      snoozeDurationMinutes: _snoozeDurationMinutes,
      toneId: _currentToneId,
      toneName: _currentToneName,
      toneFile: _currentToneFile,
    );

    final saveResult = await scheduleVM.saveScheduleFromForm(
      existingId: _existingId,
      bedtime: _bedTime,
      wakeTime: _wakeTime,
      days: _selectedDays,
      isAlarmOn: _isAlarmOn,
      isSmartAlarm: _isSmartAlarm,
      isSmartNotification: _isSmartNotification,
      isSnoozeOn: _isSnoozeOn,
      snoozeDurationMinutes: _snoozeDurationMinutes,
      toneId: _currentToneId,
      toneName: _currentToneName,
      toneFile: _currentToneFile,
    );

    if (saveResult.status == ScheduleSaveStatus.saveError) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saveResult.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _syncFromViewModel(scheduleVM, overrideSchedule: scheduleBeingSaved);
    await _rescheduleAlarm();

    if (!mounted) return;
    setState(() => _isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saveResult.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openToneSelector() {
    if (!_isEditing) return;

    _stopVolumePreview();

    final inventoryVM = context.read<InventoryViewModel>();
    final allItems = inventoryVM.myItems;

    final audioItems = allItems
        .where((i) => i.details.type == StoreItemType.audio)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ToneSelector(
        currentToneFile: _currentToneFile,
        unlockedTones: audioItems,
        onToneSelected: (id, name, file) {
          if (!mounted) return;
          setState(() {
            _currentToneId = id;
            _currentToneName = name;
            _currentToneFile = file;
          });
        },
      ),
    );
  }

  Future<void> _startVolumePreview({Duration? autoStopAfter}) async {
    _volumePreviewAutoStop?.cancel();

    try {
      if (!_isPreviewPlaying) {
        await _volumePreviewPlayer.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.alarm,
              contentType: AndroidContentType.sonification,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.playback,
              options: {AVAudioSessionOptions.duckOthers},
            ),
          ),
        );

        await _volumePreviewPlayer.setVolume(1.0);
        await _volumePreviewPlayer.setReleaseMode(ReleaseMode.loop);

        await _volumePreviewPlayer.play(
          AssetSource(NotificationService.audioAssetPath(_currentToneFile)),
        );

        if (mounted) setState(() => _isPreviewPlaying = true);
      }

      if (autoStopAfter != null) {
        _volumePreviewAutoStop = Timer(autoStopAfter, () {
          _stopVolumePreview();
        });
      }
    } catch (e) {
      debugPrint('Volume preview error: $e');
    }
  }

  Future<void> _stopVolumePreview() async {
    _volumePreviewAutoStop?.cancel();
    if (!_isPreviewPlaying) return;
    try {
      await _volumePreviewPlayer.stop();
    } catch (_) {}
    if (mounted) setState(() => _isPreviewPlaying = false);
  }

  void _toggleVolumePreview() {
    if (_isPreviewPlaying) {
      _stopVolumePreview();
    } else {
      _startVolumePreview();
    }
  }

  void _onVolumeChanged(double value) {
    setState(() => _hardwareAlarmVolume = value);
    try {
      FlutterVolumeController.setVolume(value, stream: AudioStream.alarm);
    } catch (e) {
      debugPrint("Failed to set hardware volume: $e");
    }

    _volumeSliderDebounce?.cancel();
    _volumeSliderDebounce = Timer(const Duration(milliseconds: 200), () {
      _startVolumePreview(autoStopAfter: const Duration(seconds: 3));
    });
  }

  Duration _recommendedDuration(double hours) {
    final totalMinutes = (hours * 60).round();
    return Duration(minutes: totalMinutes);
  }

  TimeOfDay _subtractDuration(TimeOfDay time, Duration duration) {
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final result = dateTime.subtract(duration);
    return TimeOfDay(hour: result.hour, minute: result.minute);
  }

  void _applyRecommendation() {
    final rec = context.read<RecommendationViewModel>().currentRecommendation;
    if (rec == null) return;

    final duration = _recommendedDuration(rec.recommendedHours);
    final newBedTime = _subtractDuration(_wakeTime, duration);

    setState(() {
      _bedTime = newBedTime;
      _isEditing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Recommendation applied. Bedtime updated to "
              "${TimeFormatter.formatTimeOfDay(newBedTime)}",
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendationVM = context.watch<RecommendationViewModel>();

    final bg = AppTheme.bg(context);
    final text = AppTheme.text(context);
    final accent = AppTheme.accent;
    final surface = AppTheme.surface(context);
    final subText = AppTheme.subText(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Sleep Schedule",
          style: TextStyle(color: text, fontWeight: FontWeight.bold),
        ),
        actions: _isInit
            ? []
            : [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: _toggleEditMode,
              icon: Icon(
                _isEditing ? Icons.save : Icons.edit,
                color: accent,
                size: 28,
              ),
              tooltip: _isEditing ? "Save Changes" : "Edit Schedule",
            ),
          ),
        ],
      ),
      body: _isInit
          ? Center(child: CircularProgressIndicator(color: accent))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                title: Text(
                  "Alarm Enabled",
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Text(
                  _isAlarmOn ? "Alarm is active" : "Alarm is off",
                  style: TextStyle(color: subText, fontSize: 13),
                ),
                value: _isAlarmOn,
                activeColor: accent,
                onChanged: (v) async {
                  setState(() => _isAlarmOn = v);
                  await _quickUpdate(v);
                },
              ),
            ),
            const SizedBox(height: 24),
            ScheduleTimeSection(
              bedTime: _bedTime,
              wakeTime: _wakeTime,
              selectedDays: _selectedDays,
              isEditing: _isEditing,
              bg: surface,
              text: text,
              accent: accent,
              wakeAccent: Colors.orange,
              onPickBedTime: () => _pickTime(true),
              onPickWakeTime: () => _pickTime(false),
              onToggleDay: (day) {
                if (!_isEditing) return;
                setState(() {
                  if (_selectedDays.contains(day)) {
                    _selectedDays.remove(day);
                  } else {
                    _selectedDays.add(day);
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            ScheduleRecommendationCard(
              recommendationVM: recommendationVM,
              isDark: AppTheme.isDark(context),
              text: text,
              accent: accent,
              onRefresh: () => _loadRecommendation(forceRefresh: true),
              onApply: _applyRecommendation,
            ),
            const SizedBox(height: 30),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                iconColor: accent,
                collapsedIconColor: subText,
                title: Text(
                  "Advanced Settings",
                  style: TextStyle(
                    color: text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                children: [
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        "SMART FEATURES",
                        style: TextStyle(
                          color: subText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  ScheduleSettingTile(
                    title: "Smart Alarm",
                    subtitle: "Enable smart wake behaviour",
                    value: _isSmartAlarm,
                    onChanged: (v) {
                      if (!_isEditing) return;
                      setState(() => _isSmartAlarm = v);
                    },
                    enabled: _isEditing,
                    text: text,
                    subText: subText,
                    icon: Icons.auto_mode,
                    iconColor: Colors.indigo,
                  ),
                  ScheduleSettingTile(
                    title: "Do Not Disturb",
                    subtitle:
                    "Silence calls and notifications during bedtime",
                    value: _isSmartNotification,
                    onChanged: (v) {
                      if (!_isEditing) return;
                      setState(() => _isSmartNotification = v);
                    },
                    enabled: _isEditing,
                    text: text,
                    subText: subText,
                    icon: Icons.do_not_disturb_on,
                    iconColor: Colors.blueAccent,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Divider(color: subText.withOpacity(0.2)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Text(
                        "SOUND & SNOOZE",
                        style: TextStyle(
                          color: subText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  ScheduleSnoozeCard(
                    isEditing: _isEditing,
                    isSnoozeOn: _isSnoozeOn,
                    snoozeDurationMinutes: _snoozeDurationMinutes,
                    onToggleSnooze: (v) {
                      if (!_isEditing) return;
                      setState(() => _isSnoozeOn = v);
                    },
                    onSnoozeDurationChanged: (v) {
                      if (!_isEditing) return;
                      setState(() => _snoozeDurationMinutes = v.round());
                    },
                    text: text,
                    subText: subText,
                    surface: surface,
                    accent: accent,
                  ),
                  const SizedBox(height: 8),
                  ScheduleToneCard(
                    toneName: _currentToneName,
                    isEditing: _isEditing,
                    onTap: _openToneSelector,
                    text: text,
                    subText: subText,
                    surface: surface,
                    accent: accent,
                    alarmVolume: _hardwareAlarmVolume,
                    systemAlarmMaxSteps: _systemAlarmMaxSteps,
                    onVolumeChanged: _onVolumeChanged,
                    isPreviewPlaying: _isPreviewPlaying,
                    onTogglePreview: _toggleVolumePreview,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
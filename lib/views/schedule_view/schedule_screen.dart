import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart'; // ✅ Brought back audioplayers
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel/recommendation_viewmodel.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/widget/schedule/selectors/tone_selector.dart';
import 'package:dreamsync/widget/schedule/cards/schedule_recommendation_card.dart';
import 'package:dreamsync/widget/schedule/schedule_time_section.dart';
import 'package:dreamsync/widget/schedule/schedule_settings_section.dart';
import 'package:dreamsync/widget/schedule/cards/schedule_tone_card.dart';
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

  int _currentToneId = 1;
  String _currentToneName = "Classic";
  String _currentToneFile = "classic.mp3";

  // Tracks the phone's physical hardware volume
  double _hardwareAlarmVolume = 1.0;

  // ✅ Restored the audio player for the preview
  final AudioPlayer _volumePreviewPlayer = AudioPlayer();
  bool _isPreviewPlaying = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _volumePreviewPlayer.dispose(); // ✅ Dispose safely
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

  void _syncFromViewModel(ScheduleViewModel vm) {
    if (vm.schedules.isEmpty) return;

    final schedule = vm.schedules.first;

    _existingId = schedule.id;
    _bedTime = schedule.bedtime;
    _wakeTime = schedule.wakeTime;
    _selectedDays = List<String>.from(schedule.days);
    _isAlarmOn = schedule.isActive;
    _isSmartAlarm = schedule.isSmartAlarm;
    _isSnoozeOn = schedule.isSnoozeOn;
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
      );
    } else {
      await NotificationService().cancelAlarm(baseNotificationId);
    }
  }

  Future<void> _quickUpdate(bool isAlarmActive) async {
    if (_existingId == null || _existingId!.isEmpty) return;

    await context
        .read<ScheduleViewModel>()
        .toggleSchedule(_existingId!, isAlarmActive);

    await _rescheduleAlarm();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAlarmActive ? "Alarm Enabled" : "Alarm Disabled"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _quickUpdateNotification(bool isSmartNotif) async {
    if (_existingId == null || _existingId!.isEmpty) return;

    await context
        .read<ScheduleViewModel>()
        .toggleSmartNotification(_existingId!, isSmartNotif);

    await _rescheduleAlarm();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isSmartNotif
              ? "Do Not Disturb Enabled"
              : "Do Not Disturb Disabled",
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _quickUpdateSnooze(bool isSnooze) async {
    if (_existingId == null || _existingId!.isEmpty) return;

    await context
        .read<ScheduleViewModel>()
        .toggleSnooze(_existingId!, isSnooze);

    await _rescheduleAlarm();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSnooze ? "Snooze Enabled" : "Snooze Disabled"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleEditMode() {
    if (_isEditing) {
      _stopVolumePreview(); // ✅ Stop preview when saving
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

    final String? hardError = scheduleVM.validateBlockingIssues(
      bedtime: _bedTime,
      wakeTime: _wakeTime,
      days: _selectedDays,
    );

    if (hardError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hardError), backgroundColor: Colors.red),
      );
      return;
    }

    if (scheduleVM.isSleepDurationShort(
      bedtime: _bedTime,
      wakeTime: _wakeTime,
      sleepGoal: mySleepGoal,
    )) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Less Duration"),
          content: const Text(
            "Calculated sleep duration is less than your sleep goal.\nSave anyway?",
          ),
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

    final scheduleToSave = ScheduleModel(
      id: _existingId ?? '',
      label: "Main Schedule",
      bedtime: _bedTime,
      wakeTime: _wakeTime,
      isActive: _isAlarmOn,
      days: _selectedDays,
      isSmartAlarm: _isSmartAlarm,
      isSmartNotification: _isSmartNotification,
      isSnoozeOn: _isSnoozeOn,
      toneId: _currentToneId,
      toneName: _currentToneName,
      toneFile: _currentToneFile,
    );

    await scheduleVM.saveSchedule(scheduleToSave);
    await scheduleVM.loadSchedules();

    _syncFromViewModel(scheduleVM);
    await _rescheduleAlarm();

    if (!mounted) return;
    setState(() => _isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Schedule saved successfully"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openToneSelector() {
    if (!_isEditing) return;

    _stopVolumePreview(); // ✅ Stop preview when opening sheet

    final inventoryVM = context.read<InventoryViewModel>();
    final allItems = inventoryVM.myItems;

    final audioItems = allItems
        .where((i) => i.details.type == StoreItemType.AUDIO)
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

  // ✅ PREVIEW LOGIC: Fixed to force AudioContext right before playing
  Future<void> _startVolumePreview() async {
    if (_isPreviewPlaying) return;

    try {
      // 1. Force the audio context to the ALARM stream so it ignores Media Mute
      await _volumePreviewPlayer.setAudioContext( AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.duckOthers},
        ),
      ));

      // 2. Set the software player volume to MAX (because the hardware slider controls the real volume!)
      await _volumePreviewPlayer.setVolume(1.0);
      await _volumePreviewPlayer.setReleaseMode(ReleaseMode.loop);

      // 3. Play the exact sound asset
      await _volumePreviewPlayer.play(
        AssetSource(NotificationService.audioAssetPath(_currentToneFile)),
      );

      setState(() => _isPreviewPlaying = true);
    } catch (e) {
      debugPrint('Volume preview error: $e');
    }
  }

  Future<void> _stopVolumePreview() async {
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

  // ✅ Modifies physical device hardware volume!
  void _onVolumeChanged(double value) {
    setState(() => _hardwareAlarmVolume = value);
    try {
      FlutterVolumeController.setVolume(value, stream: AudioStream.alarm);
    } catch (e) {
      debugPrint("Failed to set hardware volume: $e");
    }
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);
    final surface = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final subText = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: text),
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
            ScheduleRecommendationCard(
              recommendationVM: recommendationVM,
              isDark: isDark,
              text: text,
              accent: accent,
              onRefresh: () => _loadRecommendation(forceRefresh: true),
              onApply: _applyRecommendation,
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
            const SizedBox(height: 30),

            Text(
              "Alarm Settings",
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),

            ScheduleSettingsSection(
              isEditing: _isEditing,
              isAlarmOn: _isAlarmOn,
              isSmartAlarm: _isSmartAlarm,
              isSmartNotification: _isSmartNotification,
              isSnoozeOn: _isSnoozeOn,
              text: text,
              subText: subText,
              onAlarmChanged: (v) async {
                setState(() => _isAlarmOn = v);
                await _quickUpdate(v);
              },
              onSmartAlarmChanged: (v) {
                if (!_isEditing) return;
                setState(() => _isSmartAlarm = v);
              },
              onSmartNotificationChanged: (v) async {
                setState(() => _isSmartNotification = v);
                await _quickUpdateNotification(v);
              },
              onSnoozeChanged: (v) async {
                setState(() => _isSnoozeOn = v);
                await _quickUpdateSnooze(v);
              },
            ),
            const SizedBox(height: 4),

            ScheduleToneCard(
              toneName: _currentToneName,
              isEditing: _isEditing,
              onTap: _openToneSelector,
              text: text,
              subText: subText,
              surface: surface,
              accent: accent,
              alarmVolume: _hardwareAlarmVolume,
              onVolumeChanged: _onVolumeChanged,

              // ✅ Passed the restored preview methods
              isPreviewPlaying: _isPreviewPlaying,
              onTogglePreview: _toggleVolumePreview,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
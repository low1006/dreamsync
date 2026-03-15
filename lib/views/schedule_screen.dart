import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/viewmodels/recommendation_viewmodel.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/widget/schedule/day_selector.dart';
import 'package:dreamsync/widget/tone_selector.dart';
import 'package:dreamsync/widget/schedule/time_card.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool _isEditing = false;
  bool _isInit = true;
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final scheduleVM = context.read<ScheduleViewModel>();
      final inventoryVM = context.read<InventoryViewModel>();
      final dailyVM = context.read<DailyActivityViewModel>();
      final profileVM = context.read<UserViewModel>();

      await scheduleVM.loadSchedules();
      await inventoryVM.loadInventory();

      final userId = profileVM.userProfile?.userId;
      if (userId != null) {
        await dailyVM.loadTodayData(userId);
        await _loadRecommendation(forceRefresh: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInit) {
      final vm = context.watch<ScheduleViewModel>();
      if (!vm.isLoading && vm.schedules.isNotEmpty) {
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
        _isInit = false;
      } else if (!vm.isLoading) {
        _isInit = false;
      }
    }
  }

  Future<void> _loadRecommendation({bool forceRefresh = false}) async {
    final profileVM = context.read<UserViewModel>();
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

  int _getStableId(String uuid) {
    int hash = 0;
    for (int i = 0; i < uuid.length; i++) {
      hash = (31 * hash + uuid.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return hash;
  }

  Future<void> _quickUpdate(bool isAlarmActive) async {
    if (_existingId == null) return;

    await context.read<ScheduleViewModel>().toggleSchedule(_existingId!, isAlarmActive);

    final notificationId = _getStableId(_existingId!);

    if (isAlarmActive || _isSmartNotification) {
      await NotificationService().scheduleAlarm(
        id: notificationId,
        title: "Wake Up",
        time: _wakeTime,
        bedTime: _bedTime,
        days: _selectedDays,
        isAlarmEnabled: isAlarmActive,
        isSnoozeOn: _isSnoozeOn,
        isSmartNotification: _isSmartNotification,
        isSmartAlarm: _isSmartAlarm,
        soundFile: _currentToneFile,
      );
    } else {
      await NotificationService().cancelAlarm(notificationId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isAlarmActive ? "Alarm Enabled" : "Alarm Disabled"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _quickUpdateNotification(bool isSmartNotif) async {
    if (_existingId == null) return;

    await context
        .read<ScheduleViewModel>()
        .toggleSmartNotification(_existingId!, isSmartNotif);

    if (isSmartNotif) {
      final hasAccess = await NotificationService().hasDndAccess();
      if (!hasAccess && mounted) {
        setState(() => _isSmartNotification = false);
        _showPermissionDialog();
        return;
      }
    }

    final notificationId = _getStableId(_existingId!);

    if (_isAlarmOn || isSmartNotif) {
      await NotificationService().scheduleAlarm(
        id: notificationId,
        title: "Wake Up",
        time: _wakeTime,
        bedTime: _bedTime,
        days: _selectedDays,
        isAlarmEnabled: _isAlarmOn,
        isSnoozeOn: _isSnoozeOn,
        isSmartNotification: isSmartNotif,
        isSmartAlarm: _isSmartAlarm,
        soundFile: _currentToneFile,
      );
    } else {
      await NotificationService().cancelAlarm(notificationId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
    if (_existingId == null) return;

    await context.read<ScheduleViewModel>().toggleSnooze(_existingId!, isSnooze);

    final notificationId = _getStableId(_existingId!);

    if (_isAlarmOn || _isSmartNotification) {
      await NotificationService().scheduleAlarm(
        id: notificationId,
        title: "Wake Up",
        time: _wakeTime,
        bedTime: _bedTime,
        days: _selectedDays,
        isAlarmEnabled: _isAlarmOn,
        isSnoozeOn: isSnooze,
        isSmartNotification: _isSmartNotification,
        isSmartAlarm: _isSmartAlarm,
        soundFile: _currentToneFile,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSnooze ? "Snooze Enabled" : "Snooze Disabled"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPermissionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.do_not_disturb_on, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Text(
              "Permission Needed",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "To automatically silence calls and notifications during your bedtime, DreamSync needs 'Do Not Disturb' access.\n\nPlease enable it for DreamSync on the next screen.",
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await NotificationService().openDndSettings();
            },
            child: const Text(
              "Grant Access",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleEditMode() {
    if (_isEditing) {
      _saveSchedule();
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _pickTime(bool isBedtime) async {
    if (!_isEditing) return;

    final initial = isBedtime ? _bedTime : _wakeTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );

    if (picked != null) {
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
    final userVM = context.read<UserViewModel>();

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

    final notificationSeed = _existingId?.isNotEmpty == true
        ? _existingId!
        : scheduleToSave.id;
    final notificationId = _getStableId(notificationSeed);

    if (_isAlarmOn || _isSmartNotification) {
      await NotificationService().scheduleAlarm(
        id: notificationId,
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
      await NotificationService().cancelAlarm(notificationId);
    }

    if (!mounted) return;
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Schedule saved successfully")),
    );
  }

  void _openToneSelector() {
    if (!_isEditing) return;

    final inventoryVM = context.read<InventoryViewModel>();
    final allItems = inventoryVM.myItems;
    final audioItems =
    allItems.where((i) => i.details.type == StoreItemType.AUDIO).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ToneSelector(
        currentToneId: _currentToneId,
        unlockedTones: audioItems,
        onToneSelected: (id, name, file) {
          setState(() {
            _currentToneId = id;
            _currentToneName = name;
            _currentToneFile = file;
          });
        },
      ),
    );
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
          "Recommendation applied. Bedtime updated to ${_formatTimeOfDay(newBedTime)}",
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildAiRecommendationCard(
      bool isDark,
      Color text,
      Color accent,
      ) {
    final recommendationVM = context.watch<RecommendationViewModel>();
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subText = isDark ? Colors.white70 : Colors.grey.shade600;
    final shadowColor = Colors.black.withOpacity(isDark ? 0.20 : 0.06);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: accent),
              const SizedBox(width: 10),
              Text(
                "Tonight Recommendation",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: text,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => _loadRecommendation(forceRefresh: true),
                icon: Icon(Icons.refresh, color: accent),
                tooltip: "Refresh recommendation",
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (recommendationVM.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recommendationVM.currentRecommendation == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendationVM.errorMessage.isNotEmpty
                      ? recommendationVM.errorMessage
                      : "No recommendation available yet.",
                  style: TextStyle(color: subText, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  "Sync more sleep history to get a personalised recommendation.",
                  style: TextStyle(color: subText, fontSize: 13),
                ),
              ],
            )
          else ...[
              Builder(
                builder: (_) {
                  final rec = recommendationVM.currentRecommendation!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _metricBox(
                              label: "Recommended Sleep",
                              value: rec.recommendedLabel,
                              text: text,
                              subText: subText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricBox(
                              label: "Expected Score",
                              value: "${rec.scoreInt}",
                              text: text,
                              subText: subText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metricBox(
                              label: "Deep Sleep",
                              value: rec.deepLabel,
                              text: text,
                              subText: subText,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricBox(
                              label: "REM Sleep",
                              value: rec.remLabel,
                              text: text,
                              subText: subText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        rec.explanation,
                        style: TextStyle(
                          color: subText,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      if ((rec.message ?? '').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          rec.message!,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _applyRecommendation,
                          icon: const Icon(Icons.bedtime),
                          label: const Text("Apply Recommendation"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
        ],
      ),
    );
  }

  Widget _metricBox({
    required String label,
    required String value,
    required Color text,
    required Color subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: subText, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool enabled,
    required Color text,
    required Color subText,
    required IconData icon,
    required Color iconColor,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E293B)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: iconColor.withOpacity(0.12),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(color: subText, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToneCard(Color text, Color subText, Color surface, Color accent) {
    return InkWell(
      onTap: _openToneSelector,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withOpacity(0.12),
              child: Icon(Icons.music_note, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Alarm Tone",
                    style: TextStyle(
                      color: text,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _currentToneName,
                    style: TextStyle(color: subText, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (_isEditing)
              Icon(Icons.chevron_right, color: accent)
            else
              Text(
                _currentToneName,
                style: TextStyle(color: text, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final accent = const Color(0xFF3B82F6);
    final surface = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final subText = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          "Sleep Schedule",
          style: TextStyle(color: text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        actions: _isInit
            ? []
            : [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: _toggleEditMode,
              icon: Icon(
                _isEditing ? Icons.check_circle : Icons.edit,
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
            _buildAiRecommendationCard(isDark, text, accent),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: TimeCard(
                    title: "BEDTIME",
                    time: _bedTime,
                    icon: Icons.bed,
                    bg: surface,
                    text: text,
                    accent: accent,
                    isEditing: _isEditing,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TimeCard(
                    title: "WAKE UP",
                    time: _wakeTime,
                    icon: Icons.wb_sunny,
                    bg: surface,
                    text: text,
                    accent: Colors.orange,
                    isEditing: _isEditing,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            Center(
              child: Column(
                children: [
                  Text(
                    "REPEAT ON",
                    style: TextStyle(
                      color: text.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DaySelector(
                    selectedDays: _selectedDays,
                    activeColor: accent,
                    textColor: text,
                    isEditing: _isEditing,
                    onToggle: (day) {
                      if (!_isEditing) return;
                      setState(() {
                        _selectedDays.contains(day)
                            ? _selectedDays.remove(day)
                            : _selectedDays.add(day);
                      });
                    },
                  ),
                ],
              ),
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

            _buildSettingTile(
              title: "Alarm Enabled",
              subtitle: "Turn your main wake-up alarm on or off",
              value: _isAlarmOn,
              onChanged: (v) {
                setState(() => _isAlarmOn = v);
                _quickUpdate(v);
              },
              enabled: true,
              text: text,
              subText: subText,
              icon: Icons.alarm,
              iconColor: Colors.redAccent,
            ),

            _buildSettingTile(
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

            _buildSettingTile(
              title: "Do Not Disturb",
              subtitle: "Silence calls and notifications during bedtime",
              value: _isSmartNotification,
              onChanged: (v) {
                setState(() => _isSmartNotification = v);
                _quickUpdateNotification(v);
              },
              enabled: true,
              text: text,
              subText: subText,
              icon: Icons.do_not_disturb_on,
              iconColor: Colors.blueAccent,
            ),

            _buildSettingTile(
              title: "Snooze",
              subtitle: "Allow alarm snoozing",
              value: _isSnoozeOn,
              onChanged: (v) {
                setState(() => _isSnoozeOn = v);
                _quickUpdateSnooze(v);
              },
              enabled: true,
              text: text,
              subText: subText,
              icon: Icons.snooze,
              iconColor: Colors.orange,
            ),

            const SizedBox(height: 4),
            _buildToneCard(text, subText, surface, accent),
            const SizedBox(height: 30),

            if (_isEditing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSchedule,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Schedule"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
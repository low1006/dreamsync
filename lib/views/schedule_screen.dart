import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/services/notification_service.dart';

// --- IMPORT VIEWMODELS ---
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/models/inventory_model.dart';

// --- IMPORT WIDGETS ---
import 'package:dreamsync/widget/schedule/day_selector.dart';
import 'package:dreamsync/widget/schedule/time_card.dart';
import 'package:dreamsync/widget/schedule/schedule_controls.dart';
import 'package:dreamsync/widget/tone_selector.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // --- STATE VARIABLES ---
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

  // Tone Variables
  int _currentToneId = 1;
  String _currentToneName = "Classic";
  String _currentToneFile = "classic.mp3"; // Default file

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    // Default Values
    _bedTime = const TimeOfDay(hour: 22, minute: 30);
    _wakeTime = const TimeOfDay(hour: 7, minute: 0);
    _selectedDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
    _isSmartAlarm = true;
    _isSmartNotification = true;
    _isAlarmOn = true;
    _isSnoozeOn = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleViewModel>().loadSchedules();
      context.read<InventoryViewModel>().loadInventory();
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
        _selectedDays = List.from(schedule.days);
        _isAlarmOn = schedule.isActive;
        _isSmartAlarm = schedule.isSmartAlarm;
        _isSnoozeOn = schedule.isSnoozeOn;
        _currentToneId = schedule.toneId;
        _currentToneName = schedule.toneName;
        _currentToneFile = schedule.toneFile; // Load the saved file

        _isInit = false;
      }
    }
  }

  // --- LOGIC ---

  Future<void> _quickUpdate(bool isActive) async {
    if (_existingId == null) return;

    await context.read<ScheduleViewModel>().toggleSchedule(_existingId!, isActive);

    int notificationId = _existingId.hashCode;

    if (isActive) {
      // Re-schedule with current settings
      await NotificationService().scheduleAlarm(
        id: notificationId,
        title: "Wake Up",
        time: _wakeTime,
        days: _selectedDays,
        isEnabled: true,
        isSnoozeOn: _isSnoozeOn,
        soundFile: _currentToneFile, // Pass the sound file
      );
    } else {
      await NotificationService().cancelAlarm(notificationId);
    }

    if(mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? "Alarm Enabled" : "Alarm Disabled"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
        if (isBedtime) _bedTime = picked;
        else _wakeTime = picked;
      });
    }
  }

  void _saveSchedule() async {
    final scheduleVM = context.read<ScheduleViewModel>();
    final userVM = context.read<UserViewModel>();
    final double mySleepGoal = userVM.userProfile?.sleepGoalHours ?? 8.0;

    final String? hardError = scheduleVM.validateBlockingIssues(
      bedtime: _bedTime, wakeTime: _wakeTime, days: _selectedDays,
    );
    if (hardError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hardError), backgroundColor: Colors.red));
      return;
    }

    if (scheduleVM.isSleepDurationShort(bedtime: _bedTime, wakeTime: _wakeTime, sleepGoal: mySleepGoal)) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Less Duration"),
          content: const Text("Calculated sleep duration is less than your sleep goal. Save anyway?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Confirm")),
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
      isSnoozeOn: _isSnoozeOn,
      toneId: _currentToneId,
      toneName: _currentToneName,
      toneFile: _currentToneFile, // Save the actual filename
    );

    await scheduleVM.saveSchedule(scheduleToSave);

    int notificationId = scheduleToSave.id.hashCode;

    await NotificationService().scheduleAlarm(
      id: notificationId,
      title: "Wake Up",
      time: _wakeTime,
      days: _selectedDays,
      isEnabled: _isAlarmOn,
      isSnoozeOn: _isSnoozeOn,
      soundFile: _currentToneFile, // Pass the sound file
    );

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule saved successfully")));
    }
  }

  void _openToneSelector() {
    // 1. Get unlocked tones from Inventory
    final inventoryVM = context.read<InventoryViewModel>();
    final allItems = inventoryVM.myItems;

    // Filter for AUDIO type
    final audioItems = allItems.where((i) => i.details.type == StoreItemType.AUDIO).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to be taller
      backgroundColor: Colors.transparent,
      builder: (_) => ToneSelector(
        currentToneId: _currentToneId,
        unlockedTones: audioItems,

        // 2. Handle Selection
        onToneSelected: (id, name, file) {
          setState(() {
            _currentToneId = id;
            _currentToneName = name;
            _currentToneFile = file;
          });
          // Note: We don't pop immediately so user can preview.
          // Or you can add Navigator.pop(context); if you want instant close.
        },
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

    if (_isInit) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
            title: Text("Sleep Schedule", style: TextStyle(color: text)),
            backgroundColor: bg,
            elevation: 0
        ),
        body: Center(
          child: CircularProgressIndicator(color: accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text("Sleep Schedule", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        backgroundColor: bg,
        elevation: 0,
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: _toggleEditMode,
              icon: Icon(_isEditing ? Icons.check_circle : Icons.edit, color: accent, size: 28),
              tooltip: _isEditing ? "Save Changes" : "Edit Schedule",
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAiRecommendationCard(isDark, text),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: TimeCard(
                    title: "BEDTIME", time: _bedTime, icon: Icons.bed,
                    bg: surface, text: text, accent: accent,
                    isEditing: _isEditing, onTap: () => _pickTime(true)
                )),
                const SizedBox(width: 16),
                Expanded(child: TimeCard(
                    title: "WAKE UP", time: _wakeTime, icon: Icons.wb_sunny,
                    bg: surface, text: text, accent: Colors.orange,
                    isEditing: _isEditing, onTap: () => _pickTime(false)
                )),
              ],
            ),

            const SizedBox(height: 30),

            Center(
              child: Column(
                children: [
                  Text("REPEAT ON", style: TextStyle(color: text.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  DaySelector(
                    selectedDays: _selectedDays,
                    activeColor: accent,
                    textColor: text,
                    isEditing: _isEditing,
                    onToggle: (day) {
                      if (!_isEditing) return;
                      setState(() {
                        _selectedDays.contains(day) ? _selectedDays.remove(day) : _selectedDays.add(day);
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            ScheduleControls(
              isAlarmOn: _isAlarmOn,
              isSnoozeOn: _isSnoozeOn,
              isSmartAlarm: _isSmartAlarm,
              isSmartNotification: _isSmartNotification,
              currentToneName: _currentToneName,
              isEditing: _isEditing,
              bg: surface, text: text, accent: accent,

              onToneTap: _openToneSelector,

              onToggleAlarm: (val) {
                setState(() => _isAlarmOn = val);
                if (!_isEditing) _quickUpdate(val);
              },
              onToggleSnooze: (val) => setState(() => _isSnoozeOn = val),
              onToggleSmartAlarm: (val) => setState(() => _isSmartAlarm = val),
              onToggleNotification: (val) => setState(() => _isSmartNotification = val),
            ),

            if (_isEditing) ...[
              const SizedBox(height: 40),
              Center(child: Text("Tap 'Check' to save changes.", style: TextStyle(color: text.withOpacity(0.4), fontStyle: FontStyle.italic))),
              const SizedBox(height: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiRecommendationCard(bool isDark, Color titleColor) {
    final gradientColors = isDark ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)] : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)];
    final iconColor = isDark ? Colors.amber : Colors.orange;
    final realTitleColor = isDark ? Colors.white : const Color(0xFF1E40AF);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(Icons.auto_awesome, color: iconColor, size: 20), const SizedBox(width: 8), Text("AI Recommendation", style: TextStyle(color: realTitleColor, fontWeight: FontWeight.bold, fontSize: 14))]),
          const SizedBox(height: 12),
          Text("Based on your recent sleep quality, your optimal window is:", style: TextStyle(color: realTitleColor.withOpacity(0.8), fontSize: 13)),
          const SizedBox(height: 8),
          Text("22:45 - 07:15", style: TextStyle(color: realTitleColor, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
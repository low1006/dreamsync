import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/widget/schedule/day_selector.dart';
import 'package:dreamsync/widget/schedule/schedule_controls.dart';
import 'package:dreamsync/widget/tone_selector.dart';
import 'package:dreamsync/widget/schedule/time_card.dart'; // Ensure this import exists if you use TimeCard widget

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
  late bool _isSmartAlarm; // <--- ADDED
  late bool _isSmartNotification;
  late bool _isAlarmOn;
  late bool _isSnoozeOn;

  int _currentToneId = 1;
  String _currentToneName = "Classic";
  String _currentToneFile = "classic.mp3";

  // --- INITIALIZATION ---
  @override
  void initState() {
    super.initState();
    _bedTime = const TimeOfDay(hour: 22, minute: 30);
    _wakeTime = const TimeOfDay(hour: 7, minute: 0);
    _selectedDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
    _isSmartAlarm = true; // Default to true
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
        _isSmartAlarm = schedule.isSmartAlarm; // <--- LOAD FROM DB
        _isSnoozeOn = schedule.isSnoozeOn;
        _currentToneId = schedule.toneId;
        _currentToneName = schedule.toneName;
        _currentToneFile = schedule.toneFile;
        _isSmartNotification = schedule.isSmartNotification;

        _isInit = false;
      }
    }
  }

  // --- LOGIC ---

  // 1. ALARM TOGGLE
  Future<void> _quickUpdate(bool isAlarmActive) async {
    if (_existingId == null) return;
    await context.read<ScheduleViewModel>().toggleSchedule(_existingId!, isAlarmActive);
    int notificationId = _existingId.hashCode;

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
        isSmartAlarm: _isSmartAlarm, // <--- PASS CURRENT STATE
        soundFile: _currentToneFile,
      );
    } else {
      await NotificationService().cancelAlarm(notificationId);
    }

    if(mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAlarmActive ? "Alarm Enabled" : "Alarm Disabled"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 2. DND TOGGLE
  Future<void> _quickUpdateNotification(bool isSmartNotif) async {
    if (_existingId == null) return;
    await context.read<ScheduleViewModel>().toggleSmartNotification(_existingId!, isSmartNotif);

    if (isSmartNotif) {
      bool hasAccess = await NotificationService().hasDndAccess();
      if (!hasAccess && mounted) {
        setState(() => _isSmartNotification = false);
        _showPermissionDialog();
        return;
      }
    }

    int notificationId = _existingId.hashCode;

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
        isSmartAlarm: _isSmartAlarm, // <--- PASS CURRENT STATE
        soundFile: _currentToneFile,
      );
    } else {
      await NotificationService().cancelAlarm(notificationId);
    }

    if(mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSmartNotif ? "Do Not Disturb Enabled" : "Do Not Disturb Disabled"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 3. SNOOZE TOGGLE
  Future<void> _quickUpdateSnooze(bool isSnooze) async {
    if (_existingId == null) return;

    await context.read<ScheduleViewModel>().toggleSnooze(_existingId!, isSnooze);

    int notificationId = _existingId.hashCode;
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
        isSmartAlarm: _isSmartAlarm, // <--- PASS CURRENT STATE
        soundFile: _currentToneFile,
      );
    }

    if(mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSnooze ? "Snooze Enabled" : "Snooze Disabled"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
            Text("Permission Needed", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "To automatically silence calls and notifications during your bedtime, DreamSync needs 'Do Not Disturb' access.\n\nPlease enable it for DreamSync on the next screen.",
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await NotificationService().openDndSettings();
            },
            child: const Text("Grant Access", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      isSmartAlarm: _isSmartAlarm, // <--- SAVE NEW VALUE
      isSmartNotification: _isSmartNotification,
      isSnoozeOn: _isSnoozeOn,
      toneId: _currentToneId,
      toneName: _currentToneName,
      toneFile: _currentToneFile,
    );

    await scheduleVM.saveSchedule(scheduleToSave);

    int notificationId = scheduleToSave.id.hashCode;

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
        isSmartAlarm: _isSmartAlarm, // <--- PASS NEW VALUE
        soundFile: _currentToneFile,
      );
    } else {
      await NotificationService().cancelAlarm(notificationId);
    }

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule saved successfully")));
    }
  }

  void _openToneSelector() {
    if (!_isEditing) return;

    final inventoryVM = context.read<InventoryViewModel>();
    final allItems = inventoryVM.myItems;
    final audioItems = allItems.where((i) => i.details.type == StoreItemType.AUDIO).toList();

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
        appBar: AppBar(title: Text("Sleep Schedule", style: TextStyle(color: text)), backgroundColor: bg, elevation: 0),
        body: Center(child: CircularProgressIndicator(color: accent)),
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

            // 1. TIME DISPLAY (TOP)
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

            // 2. CONTROLS (Updated with Smart Alarm Support)
            ScheduleControls(
              isAlarmOn: _isAlarmOn,
              isSnoozeOn: _isSnoozeOn,
              isSmartAlarm: _isSmartAlarm, // <--- Pass State
              isSmartNotification: _isSmartNotification,
              currentToneName: _currentToneName,
              isEditing: _isEditing,
              bg: surface,
              text: text,
              accent: accent,
              onToneTap: _openToneSelector,

              onToggleAlarm: (val) {
                setState(() => _isAlarmOn = val);
                if (!_isEditing) _quickUpdate(val);
              },
              onToggleSnooze: (val) => setState(() => _isSnoozeOn = val),

              // Only update state here. Saved on "Check" button.
              onToggleSmartAlarm: (val) => setState(() => _isSmartAlarm = val),

              onToggleNotification: (val) {
                setState(() => _isSmartNotification = val);
                if (!_isEditing) _quickUpdateNotification(val);
              },
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
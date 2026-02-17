import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/schedule_viewmodel.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:dreamsync/viewmodels/inventory_viewmodel.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/widget/schedule/day_selector.dart';
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
      isSmartAlarm: _isSmartAlarm,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("CURRENT SCHEDULE", style: TextStyle(color: text.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                if (!_isEditing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: text.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.lock, size: 12, color: text.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text("Tap Edit to Change", style: TextStyle(fontSize: 10, color: text.withOpacity(0.5))),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Opacity(
              opacity: _isEditing ? 1.0 : 1.0,
              child: IgnorePointer(
                ignoring: !_isEditing,
                child: Row(
                  children: [
                    Expanded(child: _buildTimeCard("BEDTIME", _bedTime, Icons.bed, surface, text, accent, () => _pickTime(true))),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTimeCard("WAKE UP", _wakeTime, Icons.wb_sunny, surface, text, Colors.orange, () => _pickTime(false))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Opacity(
              opacity: _isEditing ? 1.0 : 0.8,
              child: IgnorePointer(
                ignoring: !_isEditing,
                child: DaySelector(
                  selectedDays: _selectedDays,
                  activeColor: accent,
                  textColor: text,
                  isEditing: true,
                  onToggle: (day) => setState(() => _selectedDays.contains(day) ? _selectedDays.remove(day) : _selectedDays.add(day)),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // 2. TOGGLES (MIDDLE)
            Text("QUICK CONTROLS", style: TextStyle(color: text.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 12),

            // --- ALARM (1st) ---
            _buildToggleCard(
              title: "Alarm Active",
              subtitle: _isAlarmOn ? "Will ring at ${_formatTime(_wakeTime)}" : "Alarm is off",
              isActive: _isAlarmOn,
              icon: Icons.alarm,
              accent: accent,
              surface: surface,
              text: text,
              onToggle: (val) {
                setState(() => _isAlarmOn = val);
                _quickUpdate(val);
              },
            ),
            const SizedBox(height: 12),

            // --- SNOOZE (2nd - MOVED HERE) ---
            // Wrapped in Opacity/IgnorePointer to disable if Alarm is OFF
            Opacity(
              opacity: _isAlarmOn ? 1.0 : 0.5, // Visual Cue: Dimmed if Alarm OFF
              child: IgnorePointer(
                ignoring: !_isAlarmOn, // Logic: Unclickable if Alarm OFF
                child: _buildToggleCard(
                  title: "Snooze Mode",
                  subtitle: "Allow 5 min snooze",
                  isActive: _isSnoozeOn,
                  icon: Icons.snooze,
                  accent: Colors.orangeAccent,
                  surface: surface,
                  text: text,
                  onToggle: (val) {
                    setState(() => _isSnoozeOn = val);
                    _quickUpdateSnooze(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- SMART NOTIFICATION (3rd) ---
            _buildToggleCard(
              title: "Smart Notification",
              subtitle: "Auto DND during sleep",
              isActive: _isSmartNotification,
              icon: Icons.notifications_paused,
              accent: Colors.purpleAccent,
              surface: surface,
              text: text,
              onToggle: (val) {
                setState(() => _isSmartNotification = val);
                _quickUpdateNotification(val);
              },
            ),

            const SizedBox(height: 32),

            // 3. TONE (BOTTOM)
            Opacity(
              opacity: _isEditing ? 1.0 : 0.6,
              child: IgnorePointer(
                ignoring: !_isEditing,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: text.withOpacity(0.05)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.music_note, color: accent),
                    ),
                    title: Text("Alarm Tone", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
                    subtitle: Text(_currentToneName, style: TextStyle(color: text.withOpacity(0.6))),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: _openToneSelector,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildToggleCard({required String title, required String subtitle, required bool isActive, required IconData icon, required Color accent, required Color surface, required Color text, required Function(bool) onToggle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? accent.withOpacity(0.5) : text.withOpacity(0.05)),
        boxShadow: isActive ? [BoxShadow(color: accent.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))] : [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? accent : text.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? Colors.white : text.withOpacity(0.3), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: text.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Switch(value: isActive, activeColor: accent, onChanged: onToggle),
        ],
      ),
    );
  }

  Widget _buildTimeCard(String title, TimeOfDay time, IconData icon, Color bg, Color text, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: text.withOpacity(0.05))),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 16, color: accent), const SizedBox(width: 8), Text(title, style: TextStyle(color: text.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold))]),
            const SizedBox(height: 12),
            Text(_formatTime(time), style: TextStyle(color: text, fontSize: 26, fontWeight: FontWeight.bold)),
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

  String _formatTime(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }
}
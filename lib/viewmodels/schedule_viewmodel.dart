import 'package:flutter/material.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/repositories/schedule_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScheduleViewModel extends ChangeNotifier {
  final ScheduleRepository _repository = ScheduleRepository();
  List<ScheduleModel> schedules = [];
  bool isLoading = false;

  Future<void> loadSchedules() async {
    isLoading = true;
    notifyListeners();
    try {
      schedules = await _repository.fetchSchedules();

      if (schedules.isEmpty) {
        await _createDefaultSchedule();
        schedules = await _repository.fetchSchedules();
      }
    } catch (e) {
      debugPrint("Error loading schedules: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createDefaultSchedule() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final defaultToneData = await supabase
          .from('store_items')
          .select()
          .eq('cost', 0)
          .eq('type', 'TONE')
          .limit(1)
          .maybeSingle();

      final int defaultId = defaultToneData != null
          ? defaultToneData['item_id']
          : 1;

      await supabase.from('user_inventory').upsert({
        'user_id': userId,
        'item_id': defaultId,
      }, onConflict: 'user_id, item_id');

      // 3. Create Schedule with that ID
      await _repository.createSchedule(
        bedtime: const TimeOfDay(hour: 22, minute: 30),
        wakeTime: const TimeOfDay(hour: 7, minute: 0),
        days: ["Mon", "Tue", "Wed", "Thu", "Fri"],
        isSmartAlarm: true,
        isSmartNotification: true,
        itemId: defaultId,
        isSnoozeOn: true,
      );
    } catch (e) {
      debugPrint("Error creating default schedule: $e");
    }
  }

  Future<void> saveSchedule(ScheduleModel schedule) async {
    try {
      if (schedule.id.isEmpty) {
        // For manual creation, default to ID 2 (Classic) if we don't have a selector yet
        await _repository.createSchedule(
          bedtime: schedule.bedtime,
          wakeTime: schedule.wakeTime,
          days: schedule.days,
          isSmartAlarm: schedule.isSmartAlarm,
          isSmartNotification: schedule.isSmartNotification,
          itemId:
              2, // Hardcoded default for now until you build a Tone Selector UI
        );
      } else {
        await _repository.updateSchedule(schedule);
      }
      await loadSchedules();
    } catch (e) {
      debugPrint("Error saving schedule: $e");
    }
  }

  // ... toggleSchedule and deleteSchedule remain the same ...
  Future<void> toggleSchedule(String id, bool currentStatus) async {
    await _repository.toggleActive(id, currentStatus);
    await loadSchedules();
  }

  Future<void> toggleSmartNotification(String id, bool currentStatus) async {
    await _repository.toggleSmartNotification(id, currentStatus);
    await loadSchedules();
  }

  Future<void> deleteSchedule(String id) async {
    await _repository.deleteSchedule(id);
    schedules.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  //================================================
  // SCHEDULE VALIDATION
  //================================================

  String? validateBlockingIssues({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
  }) {
    // 1. Must select days
    if (days.isEmpty) {
      return "Please select at least one day";
    }

    // 2. Times cannot be identical
    if (bedtime.hour == wakeTime.hour && bedtime.minute == wakeTime.minute) {
      return "Bedtime and wake time cannot be the same";
    }

    // 3. Safety: Block < 1 hour sleep (Nonsensical)
    double toDouble(TimeOfDay t) => t.hour + t.minute / 60.0;
    double duration = toDouble(wakeTime) - toDouble(bedtime);
    if (duration <= 0) duration += 24;

    if (duration < 1.0) {
      return "Sleep duration must be at least 1 hour.";
    }

    return null; // No blocking errors
  }

  // 2. CHECK WARNING (Triggers the Confirmation Dialog)
  bool isSleepDurationShort({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required double sleepGoal,
  }) {
    double toDouble(TimeOfDay t) => t.hour + t.minute / 60.0;
    double duration = toDouble(wakeTime) - toDouble(bedtime);

    // Handle overnight logic (e.g., 23:00 to 07:00)
    if (duration <= 0) duration += 24;

    return duration < sleepGoal;
  }

  bool isSleepDurationLong({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
  }) {
    double toDouble(TimeOfDay t) => t.hour + t.minute / 60.0;
    double duration = toDouble(wakeTime) - toDouble(bedtime);
    if (duration <= 0) duration += 24;

    // Trigger warning if duration is more than 12 hours
    return duration > 12.0;
  }
}

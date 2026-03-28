import 'package:flutter/material.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/repositories/schedule_repository.dart';

enum ScheduleSaveStatus {
  success,
  validationError,
  confirmationRequired,
  saveError,
}

class ScheduleSaveResult {
  final ScheduleSaveStatus status;
  final String message;

  const ScheduleSaveResult({
    required this.status,
    required this.message,
  });
}

class ScheduleViewModel extends ChangeNotifier {
  final ScheduleRepository _repository = ScheduleRepository();

  List<ScheduleModel> schedules = [];
  bool isLoading = false;

  Future<void> loadSchedules() async {
    isLoading = true;
    notifyListeners();

    // FIX: Track whether schedules were empty BEFORE the fetch.
    // Only create a default if we had nothing cached AND the server confirms empty.
    // This prevents the 7am default from firing when Supabase returns [] offline.
    final hadSchedulesBefore = schedules.isNotEmpty;

    try {
      final fetched = await _repository.fetchSchedules();

      schedules = fetched;

      if (schedules.isEmpty && !hadSchedulesBefore) {
        // Truly a first-time user with no schedules anywhere — safe to create default.
        await _createDefaultSchedule();
        schedules = await _repository.fetchSchedules();
      }
    } catch (e) {
      debugPrint("Error loading schedules (keeping existing in-memory state): $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createDefaultSchedule() async {
    try {
      final defaultId = await _repository.assignDefaultTone();

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

  /// FIX: Optimistic local update — after a successful (or queued-offline) write,
  /// update the in-memory [schedules] list directly instead of re-fetching from
  /// Supabase. Re-fetching offline returns stale/empty data which overwrites the
  /// user's just-saved changes and can trigger the 7am default schedule.
  Future<void> saveSchedule(ScheduleModel schedule) async {
    try {
      if (schedule.id.isEmpty) {
        await _repository.createSchedule(
          bedtime: schedule.bedtime,
          wakeTime: schedule.wakeTime,
          days: schedule.days,
          isSmartAlarm: schedule.isSmartAlarm,
          isSmartNotification: schedule.isSmartNotification,
          itemId: schedule.toneId,
          isSnoozeOn: schedule.isSnoozeOn,
        );
        // For a brand-new schedule we don't have a server-assigned id yet,
        // so do a refresh to pick it up (only on create).
        await loadSchedules();
      } else {
        await _repository.updateSchedule(schedule);
        // Optimistic update: reflect the change instantly in memory.
        _applyLocalUpdate(schedule);
      }
    } catch (e) {
      debugPrint("Error saving schedule: $e");
      rethrow;
    }
  }

  /// Replaces the matching schedule in [schedules] in-place and notifies listeners.
  void _applyLocalUpdate(ScheduleModel updated) {
    final index = schedules.indexWhere((s) => s.id == updated.id);
    if (index >= 0) {
      schedules[index] = updated;
    } else {
      schedules.add(updated);
    }
    notifyListeners();
  }

  Future<void> toggleSchedule(String id, bool currentStatus) async {
    await _repository.toggleActive(id, currentStatus);
    await loadSchedules();
  }

  Future<void> toggleSmartNotification(String id, bool currentStatus) async {
    await _repository.toggleSmartNotification(id, currentStatus);
    await loadSchedules();
  }

  Future<void> toggleSmartAlarm(String id, bool currentStatus) async {
    await _repository.toggleSmartAlarm(id, currentStatus);
    await loadSchedules();
  }

  Future<void> toggleSnooze(String id, bool isSnoozeOn) async {
    try {
      await _repository.toggleSnooze(id, isSnoozeOn);
      await loadSchedules();
    } catch (e) {
      debugPrint("Error toggling snooze: $e");
    }
  }

  Future<void> deleteSchedule(String id) async {
    await _repository.deleteSchedule(id);
    schedules.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  String? validateBlockingIssues({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
  }) {
    if (days.isEmpty) return "Please select at least one day";

    if (bedtime.hour == wakeTime.hour && bedtime.minute == wakeTime.minute) {
      return "Bedtime and wake time cannot be the same";
    }

    double toDouble(TimeOfDay t) => t.hour + t.minute / 60.0;
    double duration = toDouble(wakeTime) - toDouble(bedtime);

    if (duration <= 0) duration += 24;
    if (duration < 1.0) return "Sleep duration must be at least 1 hour.";
    if (duration > 12.0) return "Sleep duration cannot exceed 12 hours.";

    return null;
  }

  bool isSleepDurationShort({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required double sleepGoal,
  }) {
    double toDouble(TimeOfDay t) => t.hour + t.minute / 60.0;
    double duration = toDouble(wakeTime) - toDouble(bedtime);

    if (duration <= 0) duration += 24;

    return duration < sleepGoal;
  }

  Future<ScheduleSaveResult> validateScheduleBeforeSave({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
    required double sleepGoal,
  }) async {
    final String? hardError = validateBlockingIssues(
      bedtime: bedtime,
      wakeTime: wakeTime,
      days: days,
    );

    if (hardError != null) {
      return ScheduleSaveResult(
        status: ScheduleSaveStatus.validationError,
        message: hardError,
      );
    }

    if (isSleepDurationShort(
      bedtime: bedtime,
      wakeTime: wakeTime,
      sleepGoal: sleepGoal,
    )) {
      return const ScheduleSaveResult(
        status: ScheduleSaveStatus.confirmationRequired,
        message:
        "Calculated sleep duration is less than your sleep goal.\nSave anyway?",
      );
    }

    return const ScheduleSaveResult(
      status: ScheduleSaveStatus.success,
      message: "",
    );
  }

  Future<ScheduleSaveResult> saveScheduleFromForm({
    required String? existingId,
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
    required bool isAlarmOn,
    required bool isSmartAlarm,
    required bool isSmartNotification,
    required bool isSnoozeOn,
    required int toneId,
    required String toneName,
    required String toneFile,
  }) async {
    try {
      final scheduleToSave = ScheduleModel(
        id: existingId ?? '',
        label: "Main Schedule",
        bedtime: bedtime,
        wakeTime: wakeTime,
        isActive: isAlarmOn,
        days: days,
        isSmartAlarm: isSmartAlarm,
        isSmartNotification: isSmartNotification,
        isSnoozeOn: isSnoozeOn,
        toneId: toneId,
        toneName: toneName,
        toneFile: toneFile,
      );

      await saveSchedule(scheduleToSave);

      return const ScheduleSaveResult(
        status: ScheduleSaveStatus.success,
        message: "Schedule saved successfully",
      );
    } catch (e) {
      return ScheduleSaveResult(
        status: ScheduleSaveStatus.saveError,
        message: "Failed to save schedule: $e",
      );
    }
  }
}
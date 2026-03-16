import 'package:flutter/material.dart';
import 'package:dreamsync/widget/schedule/schedule_setting_tile.dart';

class ScheduleSettingsSection extends StatelessWidget {
  final bool isEditing;
  final bool isAlarmOn;
  final bool isSmartAlarm;
  final bool isSmartNotification;
  final bool isSnoozeOn;

  final Color text;
  final Color subText;

  final ValueChanged<bool> onAlarmChanged;
  final ValueChanged<bool> onSmartAlarmChanged;
  final ValueChanged<bool> onSmartNotificationChanged;
  final ValueChanged<bool> onSnoozeChanged;

  const ScheduleSettingsSection({
    super.key,
    required this.isEditing,
    required this.isAlarmOn,
    required this.isSmartAlarm,
    required this.isSmartNotification,
    required this.isSnoozeOn,
    required this.text,
    required this.subText,
    required this.onAlarmChanged,
    required this.onSmartAlarmChanged,
    required this.onSmartNotificationChanged,
    required this.onSnoozeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScheduleSettingTile(
          title: "Alarm Enabled",
          subtitle: "Turn your main wake-up alarm on or off",
          value: isAlarmOn,
          onChanged: onAlarmChanged,
          enabled: true,
          text: text,
          subText: subText,
          icon: Icons.alarm,
          iconColor: Colors.redAccent,
        ),
        ScheduleSettingTile(
          title: "Smart Alarm",
          subtitle: "Enable smart wake behaviour",
          value: isSmartAlarm,
          onChanged: onSmartAlarmChanged,
          enabled: isEditing,
          text: text,
          subText: subText,
          icon: Icons.auto_mode,
          iconColor: Colors.indigo,
        ),
        ScheduleSettingTile(
          title: "Do Not Disturb",
          subtitle: "Silence calls and notifications during bedtime",
          value: isSmartNotification,
          onChanged: onSmartNotificationChanged,
          enabled: true,
          text: text,
          subText: subText,
          icon: Icons.do_not_disturb_on,
          iconColor: Colors.blueAccent,
        ),
        ScheduleSettingTile(
          title: "Snooze",
          subtitle: "Allow alarm snoozing",
          value: isSnoozeOn,
          onChanged: onSnoozeChanged,
          enabled: true,
          text: text,
          subText: subText,
          icon: Icons.snooze,
          iconColor: Colors.orange,
        ),
      ],
    );
  }
}
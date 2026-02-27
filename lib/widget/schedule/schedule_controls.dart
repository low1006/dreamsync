import 'package:flutter/material.dart';

class ScheduleControls extends StatelessWidget {
  final bool isAlarmOn;
  final bool isSnoozeOn;
  final bool isSmartAlarm;
  final bool isSmartNotification;
  final String currentToneName;
  final bool isEditing;

  final Color bg;
  final Color text;
  final Color accent;

  final Function(bool) onToggleAlarm;
  final Function(bool) onToggleSnooze;
  final Function(bool) onToggleSmartAlarm;
  final Function(bool) onToggleNotification;
  final VoidCallback onToneTap;

  const ScheduleControls({
    super.key,
    required this.isAlarmOn,
    required this.isSnoozeOn,
    required this.isSmartAlarm,
    required this.isSmartNotification,
    required this.currentToneName,
    required this.isEditing,
    required this.bg,
    required this.text,
    required this.accent,
    required this.onToggleAlarm,
    required this.onToggleSnooze,
    required this.onToggleSmartAlarm,
    required this.onToggleNotification,
    required this.onToneTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. MAIN ALARM TOGGLE
        IgnorePointer(
          ignoring: isEditing,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isEditing ? 0.4 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isAlarmOn ? accent.withOpacity(0.1) : bg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isAlarmOn ? accent : text.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isAlarmOn ? "Alarm is ON" : "Alarm is OFF", style: TextStyle(color: isAlarmOn ? accent : text.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 16)),
                  Switch(value: isAlarmOn, activeColor: accent, onChanged: onToggleAlarm),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 30),

        Text("ALARM SETTINGS", style: TextStyle(color: text.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),

        _buildSettingsCard(context),

        const SizedBox(height: 30),

        Text("SMART FEATURES", style: TextStyle(color: text.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 10),

        // Smart Alarm: Only editable in "Edit Mode"
        _buildFeatureCard(
            "Smart Alarm", "Dynamic tones to prevent habituation.", Icons.music_note,
            isSmartAlarm, onToggleSmartAlarm,
            alwaysActive: false // Disabled unless editing
        ),

        const SizedBox(height: 12),

        // Smart Notification: Always active (Nightly toggle)
        _buildFeatureCard(
            "Smart Notification", "Get intelligent sleep reminders.", Icons.notifications_active,
            isSmartNotification, onToggleNotification,
            alwaysActive: true
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    final bool isDisabled = !isEditing;

    return IgnorePointer(
      ignoring: isDisabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: text.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: _iconBox(Icons.queue_music, Colors.purple),
                title: Text("Alarm Tone", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
                subtitle: Text(currentToneName, style: TextStyle(color: text.withOpacity(0.6), fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text("Change", style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios, size: 16, color: text.withOpacity(0.3)),
                ]),
                onTap: onToneTap,
              ),
              Divider(height: 1, color: text.withOpacity(0.05)),
              ListTile(
                leading: _iconBox(Icons.snooze, Colors.orange),
                title: Text("Snooze", style: TextStyle(color: text, fontWeight: FontWeight.bold)),
                subtitle: Text("5 minutes interval", style: TextStyle(color: text.withOpacity(0.6), fontSize: 12)),
                trailing: Switch(value: isSnoozeOn, activeColor: accent, onChanged: onToggleSnooze),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged, {bool alwaysActive = false}) {
    final bool isDisabled = alwaysActive ? false : !isEditing;

    return IgnorePointer(
      ignoring: isDisabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isDisabled ? 0.6 : 1.0,
        child: Card(
          color: bg, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: text.withOpacity(0.05))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _iconBox(icon, accent),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: text.withOpacity(0.6), fontSize: 12)),
                ])),
                Switch(value: value, activeColor: accent, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
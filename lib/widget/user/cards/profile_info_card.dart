import 'package:flutter/material.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/util/time_formatter.dart';

class ProfileInfoCard extends StatelessWidget {
  final UserModel user;
  final bool isEditing;
  final double tempHeight;
  final double tempWeight;
  final bool? isHealthConnected;
  final Color text;
  final Color accent;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback onRequestHealthAccess;

  const ProfileInfoCard({
    super.key,
    required this.user,
    required this.isEditing,
    required this.tempHeight,
    required this.tempWeight,
    required this.isHealthConnected,
    required this.text,
    required this.accent,
    required this.onHeightChanged,
    required this.onWeightChanged,
    required this.onRequestHealthAccess,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEditing ? accent.withOpacity(0.5) : text.withOpacity(0.05),
          width: isEditing ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          _buildTile('Gender', user.gender),
          _divider(),
          _buildTile('Age', '${user.age} years'),
          _divider(),
          _buildTile('Birth Date', user.dateBirth),
          _divider(),
          _buildHealthConnectTile(),
          _divider(),
          _buildEditableRow(
            label: 'Height',
            value: tempHeight,
            unit: 'cm',
            min: 100,
            max: 220,
            onChanged: onHeightChanged,
          ),
          _divider(),
          _buildEditableRow(
            label: 'Weight',
            value: tempWeight,
            unit: 'kg',
            min: 30,
            max: 150,
            onChanged: onWeightChanged,
          ),
          _divider(),
          _buildTile(
            'Sleep Goal',
            TimeFormatter.formatHours(user.sleepGoalHours),
            isHighlight: true,
          ),
          _divider(),
          _buildTile(
            'Points',
            '${user.currentPoints} pts',
            isHighlight: true,
          ),
          _divider(),
          _buildTile(
            'Streak',
            '${user.streak} day${user.streak == 1 ? '' : 's'}',
            isHighlight: true,
            icon: Icons.local_fire_department,
            iconColor: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthConnectTile() {
    final statusText = isHealthConnected == null
        ? 'Checking...'
        : (isHealthConnected! ? 'Connected' : 'Not Connected');

    final statusColor = isHealthConnected == null
        ? text.withOpacity(0.5)
        : (isHealthConnected! ? Colors.green : Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart, color: accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Health Connect',
                style: TextStyle(
                  color: text.withOpacity(0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isHealthConnected == false && !isEditing) ...[
                const SizedBox(width: 12),
                InkWell(
                  onTap: onRequestHealthAccess,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sync, size: 16, color: accent),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required String label,
    required double value,
    required String unit,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    if (!isEditing) {
      return _buildTile(label, '${value.toStringAsFixed(1)} $unit');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 2).toInt(),
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
      String label,
      String value, {
        bool isHighlight = false,
        IconData? icon,
        Color? iconColor,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: text.withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: iconColor ?? accent,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isHighlight ? accent : text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      color: text.withOpacity(0.05),
      thickness: 1,
      height: 1,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/services/notification_service.dart';

class ToneSelector extends StatefulWidget {
  final String currentToneFile;
  final List<InventoryItem> unlockedTones;
  final Function(int id, String name, String file) onToneSelected;

  const ToneSelector({
    super.key,
    required this.currentToneFile,
    required this.unlockedTones,
    required this.onToneSelected,
  });

  @override
  State<ToneSelector> createState() => _ToneSelectorState();
}

class _ToneSelectorState extends State<ToneSelector> {
  List<InventoryItem> get _availableAlarmTones {
    return widget.unlockedTones.where((item) {
      final file = NotificationService.normalizeSoundFile(
        item.details.audioFile,
      );
      return file != 'classic.mp3';
    }).toList();
  }

  void _selectAndClose(
      BuildContext context,
      int id,
      String name,
      String fileName,
      ) {
    final normalizedFile = NotificationService.normalizeSoundFile(fileName);
    widget.onToneSelected(id, name, normalizedFile);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);
    const accent = Color(0xFF3B82F6);

    final currentNormalized = NotificationService.normalizeSoundFile(
      widget.currentToneFile,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: text.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select Alarm Tone",
                  style: TextStyle(
                    color: text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: text.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              children: [
                _buildSectionHeader("Default", text),
                _buildToneTile(
                  context: context,
                  id: 1,
                  name: "Classic",
                  subtitle: "Default alarm tone",
                  fileName: "classic.mp3",
                  isSelected: currentNormalized == 'classic.mp3',
                  textColor: text,
                  accentColor: accent,
                ),
                const SizedBox(height: 16),
                if (_availableAlarmTones.isNotEmpty) ...[
                  _buildSectionHeader("Available Alarm Tones", text),
                  ..._availableAlarmTones.map((item) {
                    final normalizedFile = NotificationService.normalizeSoundFile(
                      item.details.audioFile,
                    );

                    return _buildToneTile(
                      context: context,
                      id: item.details.id,
                      name: item.details.name,
                      subtitle: "Unlocked tone",
                      fileName: normalizedFile,
                      isSelected: currentNormalized == normalizedFile,
                      textColor: text,
                      accentColor: accent,
                    );
                  }),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "No extra alarm tones available yet.",
                      style: TextStyle(
                        color: text.withOpacity(0.5),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color.withOpacity(0.5),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildToneTile({
    required BuildContext context,
    required int id,
    required String name,
    required String subtitle,
    required String fileName,
    required bool isSelected,
    required Color textColor,
    required Color accentColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _selectAndClose(context, id, name, fileName),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? accentColor.withOpacity(0.10)
                : textColor.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : textColor.withOpacity(0.08),
              width: isSelected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.music_note_rounded,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor.withOpacity(0.55),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accentColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : textColor.withOpacity(0.22),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 15,
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
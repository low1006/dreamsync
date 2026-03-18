import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dreamsync/models/inventory_model.dart';

class ToneSelector extends StatefulWidget {
  final int currentToneId;
  final List<InventoryItem> unlockedTones;
  final Function(int id, String name, String file) onToneSelected;

  const ToneSelector({
    super.key,
    required this.currentToneId,
    required this.unlockedTones,
    required this.onToneSelected,
  });

  @override
  State<ToneSelector> createState() => _ToneSelectorState();
}

class _ToneSelectorState extends State<ToneSelector> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingId;
  bool _isPlayingDefault = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPreview(String fileName, int id, {bool isDefault = false}) async {
    try {
      await _audioPlayer.stop();

      // If tapping the same tone that is playing, just stop it.
      if ((_playingId == id && !isDefault) || (_isPlayingDefault && isDefault && _playingId == 1)) {
        setState(() {
          _playingId = null;
          _isPlayingDefault = false;
        });
        return;
      }

      // Play new tone
      await _audioPlayer.play(AssetSource('audio/$fileName'));

      setState(() {
        _playingId = isDefault ? 1 : id;
        _isPlayingDefault = isDefault;
      });

      // Reset state when finished
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playingId = null;
            _isPlayingDefault = false;
          });
        }
      });
    } catch (e) {
      debugPrint("Error playing preview: $e");
    }
  }

  void _selectAndClose(int id, String name, String fileName) {
    widget.onToneSelected(id, name, fileName);
    _audioPlayer.stop(); // Stop audio when closing
    Navigator.pop(context); // Automatically close the bottom sheet
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7, // Takes up to 70% of screen
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
          // Drag Handle
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

          // Header
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
                  onPressed: () {
                    _audioPlayer.stop();
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close, color: text.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          const Divider(),

          // Scrollable List
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              children: [
                // --- SECTION 1: DEFAULTS ---
                _buildSectionHeader("Default", text),
                _buildToneTile(
                  id: 1,
                  name: "Classic",
                  fileName: "classic.mp3",
                  isSelected: widget.currentToneId == 1,
                  isPlaying: _isPlayingDefault && _playingId == 1,
                  isDefault: true,
                  textColor: text,
                ),

                const SizedBox(height: 16),

                // --- SECTION 2: MY TONES ---
                if (widget.unlockedTones.isNotEmpty) ...[
                  _buildSectionHeader("My Tones", text),
                  ...widget.unlockedTones.map((item) {
                    return _buildToneTile(
                      id: item.details.id,
                      name: item.details.name,
                      fileName: item.details.audioFile,
                      isSelected: widget.currentToneId == item.details.id,
                      isPlaying: _playingId == item.details.id,
                      isDefault: false,
                      textColor: text,
                    );
                  }).toList(),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      "No unlocked tones yet. Visit the Shop to unlock more!",
                      style: TextStyle(color: text.withOpacity(0.5), fontStyle: FontStyle.italic),
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
    required int id,
    required String name,
    required String fileName,
    required bool isSelected,
    required bool isPlaying,
    required bool isDefault,
    required Color textColor,
  }) {
    final accent = const Color(0xFF3B82F6);

    return Card(
      elevation: 0,
      color: isSelected ? accent.withOpacity(0.08) : Colors.transparent,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected ? BorderSide(color: accent.withOpacity(0.5), width: 1.5) : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () => _selectAndClose(id, name, fileName),
        leading: CircleAvatar(
          backgroundColor: isPlaying ? Colors.redAccent.withOpacity(0.1) : accent.withOpacity(0.1),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.stop : Icons.play_arrow,
              color: isPlaying ? Colors.redAccent : accent,
              size: 22,
            ),
            onPressed: () => _playPreview(fileName, id, isDefault: isDefault),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: accent)
            : null,
      ),
    );
  }
}
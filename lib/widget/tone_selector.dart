import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dreamsync/models/inventory_model.dart'; // Ensure this import is correct

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
  int? _playingId; // Track which tone ID is currently playing
  bool _isPlayingDefault = false; // Track if the default tone is playing

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPreview(String fileName, int id, {bool isDefault = false}) async {
    try {
      await _audioPlayer.stop();

      // If we are tapping the same tone that is playing, just stop it.
      if ((_playingId == id && !isDefault) || (_isPlayingDefault && isDefault && _playingId == 1)) {
        setState(() {
          _playingId = null;
          _isPlayingDefault = false;
        });
        return;
      }

      // Play new tone
      // Note: 'classic.mp3' or unlocked files usually live in assets/audio/
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      height: 500, // Fixed height or use logic
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: text.withOpacity(0.5)),
                ),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // --- SECTION 1: DEFAULTS ---
                _buildSectionHeader("Default", text),
                _buildToneTile(
                  id: 1, // Classic ID
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
                      fileName: item.details.audioFile, // Assumes getter exists
                      isSelected: widget.currentToneId == item.details.id,
                      isPlaying: _playingId == item.details.id,
                      isDefault: false,
                      textColor: text,
                    );
                  }).toList(),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "No unlocked tones yet. Visit the Shop!",
                      style: TextStyle(color: text.withOpacity(0.5), fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: 40),
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
          color: color.withOpacity(0.6),
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
    return Card(
      elevation: 0,
      color: isSelected
          ? const Color(0xFF3B82F6).withOpacity(0.1)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: Color(0xFF3B82F6), width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: () {
          // Select this tone
          widget.onToneSelected(id, name, fileName);
          // Optional: Auto-play when selected?
          _playPreview(fileName, id, isDefault: isDefault);
        },
        leading: CircleAvatar(
          backgroundColor: isPlaying ? Colors.redAccent : const Color(0xFF3B82F6).withOpacity(0.2),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.stop : Icons.play_arrow,
              color: isPlaying ? Colors.white : const Color(0xFF3B82F6),
              size: 20,
            ),
            onPressed: () => _playPreview(fileName, id, isDefault: isDefault),
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle, color: Color(0xFF3B82F6))
            : null,
      ),
    );
  }
}
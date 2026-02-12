import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dreamsync/models/inventory_model.dart';

class ToneSelector extends StatefulWidget {
  final int currentToneId;
  final List<InventoryItem> unlockedTones; // Received from parent
  final Function(InventoryItem) onToneSelected;

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

  Future<void> _previewTone(String filename, int id) async {
    try {
      await _audioPlayer.stop();
      // Assuming files are in assets/audio/ or assets/sounds/
      // Adjust path based on your actual asset structure
      await _audioPlayer.play(AssetSource('audio/$filename'));
      setState(() => _playingId = id);
    } catch (e) {
      debugPrint("Error playing preview: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ... styling ...
      child: Column(
        children: [
          // ... header ...
          Expanded(
            child: ListView.builder(
              itemCount: widget.unlockedTones.length,
              itemBuilder: (context, index) {
                final item = widget.unlockedTones[index];
                final isSelected = widget.currentToneId == item.details.id;
                final isPlaying = _playingId == item.details.id;

                return ListTile(
                  title: Text(item.details.name),
                  leading: IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle_outline),
                    onPressed: () {
                      if (isPlaying) {
                        _audioPlayer.stop();
                        setState(() => _playingId = null);
                      } else {
                        // Use the file from metadata
                        _previewTone(item.details.audioFile, item.details.id);
                      }
                    },
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () {
                    widget.onToneSelected(item);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class ToneSelector extends StatefulWidget {
  final String currentTone;
  final Function(String) onToneSelected;

  const ToneSelector({
    super.key,
    required this.currentTone,
    required this.onToneSelected,
  });

  @override
  State<ToneSelector> createState() => _ToneSelectorState();
}

class _ToneSelectorState extends State<ToneSelector> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingTone;

  // MAP: Display Name -> Filename (without extension)
  final Map<String, String> _tones = {
    "Classic Alarm": "Classic",
    "Buzzer Sounds": "Buzzer",

  };

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _previewTone(String filename) async {
    try {
      await _audioPlayer.stop();

      // Plays from assets/sounds/{filename}.mp3
      // Ensure your assets are defined in pubspec.yaml
      await _audioPlayer.play(AssetSource('sounds/$filename.mp3'));

      setState(() => _playingTone = filename);
    } catch (e) {
      debugPrint("Error playing preview: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Select Alarm Tone",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.grey.withOpacity(0.2)),

          Expanded(
            child: ListView.builder(
              itemCount: _tones.length,
              itemBuilder: (context, index) {
                final name = _tones.keys.elementAt(index);
                final filename = _tones.values.elementAt(index);
                final isSelected = widget.currentTone == name;
                final isPlaying = _playingTone == filename;

                return ListTile(
                  title: Text(name, style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Theme.of(context).primaryColor : null,
                  )),
                  leading: Icon(
                    isPlaying ? Icons.pause_circle : Icons.play_circle_outline,
                    color: isPlaying ? Colors.orange : Colors.grey,
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
                  onTap: () async {
                    if (isPlaying) {
                      await _audioPlayer.stop();
                      setState(() => _playingTone = null);
                    } else {
                      await _previewTone(filename);
                    }
                  },
                  onLongPress: () {
                    // Select without playing
                    widget.onToneSelected(name);
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
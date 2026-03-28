import 'package:flutter/material.dart';
import 'package:dreamsync/widget/custom/user_avatar.dart';

class AvatarPickerCard extends StatelessWidget {
  final List<String> avatarPaths;
  final bool isLoading;
  final String selectedAvatarAssetPath;
  final Color surface;
  final Color text;
  final Color accent;
  final ValueChanged<String> onAvatarSelected;

  const AvatarPickerCard({
    super.key,
    required this.avatarPaths,
    required this.isLoading,
    required this.selectedAvatarAssetPath,
    required this.surface,
    required this.text,
    required this.accent,
    required this.onAvatarSelected,
  });

  String _labelFor(String path) {
    if (path == UserAvatar.defaultPath) return 'Default';
    return 'Avatar';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: text.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Avatar',
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (avatarPaths.isEmpty)
            Text(
              'No avatars available.',
              style: TextStyle(color: text.withOpacity(0.5)),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: avatarPaths.map((path) {
                final selected = selectedAvatarAssetPath == path;

                return GestureDetector(
                  onTap: () => onAvatarSelected(path),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 72,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? accent : text.withOpacity(0.08),
                        width: selected ? 2 : 1,
                      ),
                      color: selected
                          ? accent.withOpacity(0.08)
                          : Colors.transparent,
                    ),
                    child: Column(
                      children: [
                        UserAvatar(
                          avatarPath: path,
                          size: 60,
                          borderRadius: BorderRadius.circular(12),
                          fallbackIconColor: accent,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _labelFor(path),
                          style: TextStyle(
                            color: selected ? accent : text.withOpacity(0.65),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
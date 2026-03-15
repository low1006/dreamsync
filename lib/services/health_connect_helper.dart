import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthConnectHelper {
  static Future<void> showInstallDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text('Health Connect Required', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          'To sync your sleep data, DreamSync requires the official Google Health Connect app. Would you like to install it from the Play Store now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final Uri playStoreUri = Uri.parse(
                'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
              );
              if (await canLaunchUrl(playStoreUri)) {
                await launchUrl(
                  playStoreUri,
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }
}

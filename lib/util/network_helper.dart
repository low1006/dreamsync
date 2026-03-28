import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NetworkHelper {
  static final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  static Timer? _timer;

  static const Color offlineBannerColor = Color(0xFFEF4444);
  static const Color offlineTextColor = Colors.white;

  static Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> checkConnection() async {
    final connected = await hasInternet();
    isOffline.value = !connected;
  }

  static void startMonitoring() {
    _timer?.cancel();
    unawaited(checkConnection());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(checkConnection());
    });
  }

  static void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<bool> ensureInternet(
      BuildContext context, {
        String message = 'No internet connection. Please connect and try again.',
      }) async {
    final connected = await hasInternet();
    isOffline.value = !connected;

    if (!connected && context.mounted) {
      showOfflineSnackBar(context, message: message);
    }

    return connected;
  }

  static void showOfflineSnackBar(
      BuildContext context, {
        String message = 'No internet connection. Please connect and try again.',
      }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: offlineTextColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: offlineTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: offlineBannerColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}

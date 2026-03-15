import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkHelper {
  static bool? _lastStatus;
  static DateTime? _lastCheckedAt;

  /// Cached internet reachability check.
  /// Prevents repeated DNS lookups when many repositories call this at startup.
  static Future<bool> isOnline() async {
    final now = DateTime.now();

    if (_lastStatus != null &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!).inSeconds < 10) {
      return _lastStatus!;
    }

    try {
      final result = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));

      final hasConnectionType =
          result == ConnectivityResult.mobile ||
              result == ConnectivityResult.wifi ||
              result == ConnectivityResult.ethernet;

      if (!hasConnectionType) {
        _lastStatus = false;
        _lastCheckedAt = now;
        return false;
      }

      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      final online =
          lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;

      _lastStatus = online;
      _lastCheckedAt = now;
      return online;
    } catch (_) {
      _lastStatus = false;
      _lastCheckedAt = now;
      return false;
    }
  }

  static void clearCache() {
    _lastStatus = null;
    _lastCheckedAt = null;
  }
}
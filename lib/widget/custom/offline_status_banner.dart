import 'package:flutter/material.dart';
import 'package:dreamsync/util/network_helper.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkHelper.isOffline,
      builder: (context, isOffline, child) {
        if (!isOffline) return const SizedBox.shrink();

        final topInset = MediaQuery.of(context).padding.top;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: topInset + 10,
            left: 16,
            right: 16,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            border: Border(
              bottom: BorderSide(
                color: Colors.orange.withOpacity(0.35),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.wifi_off_rounded,
                color: Color(0xFFB26A00),
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You are offline',
                  style: TextStyle(
                    color: Color(0xFF8A5300),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
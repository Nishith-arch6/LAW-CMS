import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});

class OfflineBanner extends ConsumerStatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  bool _wasOffline = false;

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityProvider).value ?? true;

    if (!online) {
      _wasOffline = true;
    } else if (_wasOffline) {
      _wasOffline = false;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Back online'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    }

    return Column(
      children: [
        if (!online)
          Container(
            width: double.infinity,
            color: Colors.orange.shade800,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'No internet connection',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

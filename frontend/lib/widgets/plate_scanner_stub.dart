import 'dart:typed_data';
import 'package:flutter/material.dart';

class ScanResult {
  final Uint8List imageBytes;
  final String? plate;
  final bool granted;
  final String reason;
  final String? imageB64;
  const ScanResult(this.imageBytes, this.plate, this.granted, this.reason, this.imageB64);
}

class WebPlateScannerWidget extends StatelessWidget {
  final void Function(ScanResult result) onCapture;
  final VoidCallback? onAutoDetected;
  final VoidCallback? onError;
  final bool autoScan;
  final String gate;

  const WebPlateScannerWidget({
    required this.onCapture,
    this.onAutoDetected,
    this.onError,
    this.autoScan = true,
    this.gate = 'Entrée',
    super.key,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

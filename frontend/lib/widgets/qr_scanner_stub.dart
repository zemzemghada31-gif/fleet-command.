import 'package:flutter/material.dart';

/// Stub for non-web platforms. WebQrScannerWidget is never used on mobile
/// because devices_page.dart checks [kIsWeb] before using it.
class WebQrScannerWidget extends StatelessWidget {
  final void Function(String) onScan;
  final void Function(String?)? onError;

  const WebQrScannerWidget({
    required this.onScan,
    this.onError,
    super.key,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

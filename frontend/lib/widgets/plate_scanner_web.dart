import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class ScanResult {
  final Uint8List imageBytes;
  final String? plate;
  final bool granted;
  final String reason;
  final String? imageB64;
  const ScanResult(this.imageBytes, this.plate, this.granted, this.reason, this.imageB64);
}

class WebPlateScannerWidget extends StatefulWidget {
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
  State<WebPlateScannerWidget> createState() => _WebPlateScannerWidgetState();
}

class _WebPlateScannerWidgetState extends State<WebPlateScannerWidget> {
  late final String _viewType;
  web.MediaStream? _mediaStream;
  web.HTMLVideoElement? _video;
  bool _cameraReady = false;
  bool _capturing = false;
  bool _processing = false;
  int _scanCount = 0;
  int _scanAttempts = 0;
  static const int _maxScanAttempts = 30;
  String? _errorMessage;
  bool _detectionActive = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _viewType = 'plate-scanner-${identityHashCode(this)}';
    _registerViewFactory();
  }

  void _registerViewFactory() {
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        return _buildElement();
      });
    } catch (e) {
      debugPrint('plate_scanner registration error: $e');
    }
  }

  web.HTMLDivElement _buildElement() {
    final container = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.position = 'relative'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = '#000';

    final video = web.HTMLVideoElement()
      ..id = _viewType
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..setAttribute('autoplay', '')
      ..setAttribute('playsinline', '')
      ..setAttribute('muted', '');

    container.appendChild(video);
    _video = video;

    Future.delayed(const Duration(milliseconds: 300), _startCamera);
    return container;
  }

  Future<void> _startCamera() async {
    try {
      final constraints = web.MediaStreamConstraints(
        video: {
          'facingMode': 'environment',
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        }.jsify() as JSAny,
      );
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints).toDart;
      _mediaStream = stream;
      final video = _video;
      if (video != null) {
        video.srcObject = stream;
        await video.play().toDart;
        if (mounted) {
          setState(() => _cameraReady = true);
          if (widget.autoScan) _startAutoScan();
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('NotAllowed') || msg.contains('PermissionDenied')) {
        _setError('Accès caméra refusé');
      } else if (msg.contains('NotFound')) {
        _setError('Aucune caméra trouvée');
      } else {
        _setError('Erreur caméra');
      }
    }
  }

  void _startAutoScan() {
    _detectionActive = true;
    _scanAttempts = 0;
    _scheduleNextPreview();
  }

  void _scheduleNextPreview() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted || !_cameraReady) return;
      _captureAndDetect();
    });
  }

  Future<void> _captureAndDetect() async {
    if (!mounted || !_cameraReady || _processing || !_detectionActive) return;

    final video = _video;
    if (video == null || video.videoWidth == 0) {
      _scheduleNextPreview();
      return;
    }

    _scanAttempts++;
    if (_scanAttempts >= _maxScanAttempts) {
      _detectionActive = false;
      if (mounted) setState(() => _processing = false);
      _retryTimer?.cancel();
      widget.onCapture(ScanResult(
        Uint8List(0), null, false, 'Aucune plaque détectée après plusieurs tentatives', null,
      ));
      return;
    }

    final videoW = min(video.videoWidth, 1920);
    final videoH = min(video.videoHeight, 1080);

    final captureCanvas = web.HTMLCanvasElement();
    captureCanvas.width = videoW;
    captureCanvas.height = videoH;
    final captureCtx = captureCanvas.getContext('2d') as web.CanvasRenderingContext2D;
    captureCtx.filter = 'contrast(1.2) brightness(1.1) saturate(1.1)';
    captureCtx.drawImage(video, 0, 0, videoW, videoH);

    final dataUrl = captureCanvas.toDataURL('image/jpeg', 0.95.toJS);
    final b64 = dataUrl.split(',').last;
    final bytes = base64.decode(b64);

    _scanCount++;
    if (mounted) setState(() => _processing = true);

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/gate/quick-scan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'gate': widget.gate, 'image_b64': b64}),
      ).timeout(const Duration(seconds: 5));

      if (!mounted) return;

      debugPrint('[AUTO] quick-scan response: ${res.statusCode} ${res.body}');

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final plate = data['plate'] as String?;
        debugPrint('[AUTO] plate detected: $plate');

        if (plate != null) {
          _detectionActive = false;
          if (mounted) setState(() => _processing = false);
          widget.onAutoDetected?.call();
          widget.onCapture(ScanResult(
            bytes, plate,
            data['granted'] as bool? ?? false,
            data['reason'] as String? ?? '',
            data['image_b64'] as String?,
          ));
          return;
        }
      }
    } catch (e) {
      debugPrint('[AUTO] quick-scan error: $e');
    }

    if (mounted) setState(() => _processing = false);
    _scheduleNextPreview();
  }

  void _setError(String msg) {
    if (mounted) {
      setState(() => _errorMessage = msg);
      widget.onError?.call();
    }
  }

  void _capture() {
    if (_capturing || _processing) return;
    _doCapture();
  }

  Future<void> _doCapture() async {
    final video = _video;
    if (video == null || video.videoWidth == 0) return;
    _capturing = true;
    _detectionActive = false;

    final videoW = min(video.videoWidth, 1920);
    final videoH = min(video.videoHeight, 1080);

    final canvas = web.HTMLCanvasElement();
    canvas.width = videoW;
    canvas.height = videoH;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.filter = 'contrast(1.2) brightness(1.1) saturate(1.1)';
    ctx.drawImage(video, 0, 0, videoW, videoH);
    final dataUrl = canvas.toDataURL('image/jpeg', 0.95.toJS);
    final b64 = dataUrl.split(',').last;
    final bytes = base64.decode(b64);

    _capturing = false;
    _processing = true;
    _scanCount++;
    if (mounted) setState(() {});

    String? plate;
    bool granted = false;
    String reason = '';
    String? imageB64;
    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/gate/quick-scan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'gate': widget.gate, 'image_b64': b64}),
      ).timeout(const Duration(seconds: 5));
      debugPrint('[MANUAL] quick-scan response: ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        plate = data['plate'] as String?;
        debugPrint('[MANUAL] plate detected: $plate');
        granted = data['granted'] as bool? ?? false;
        reason = data['reason'] as String? ?? '';
        imageB64 = data['image_b64'] as String?;
      }
    } catch (e) {
      debugPrint('[MANUAL] quick-scan error: $e');
    }
    widget.onCapture(ScanResult(bytes, plate, granted, reason, imageB64));

    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _processing = false;
        if (widget.autoScan && !_detectionActive) {
          _detectionActive = true;
          _scanAttempts = 0;
          _scheduleNextPreview();
        }
      }
    });
  }

  @override
  void dispose() {
    _detectionActive = false;
    _retryTimer?.cancel();
    if (_mediaStream != null) {
      final tracks = _mediaStream!.getTracks();
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (_cameraReady && !_capturing) ...[
          CustomPaint(painter: _PlateGuidePainter(isScanning: _processing),
              size: Size.infinite),
          if (_cameraReady && widget.autoScan)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: _processing ? Colors.white : const Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _processing ? 'Analyse... ($_scanCount)' : 'Analyse...',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _processing ? null : _capture,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: _processing
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF3B82F6),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    _processing ? Icons.hourglass_top : Icons.camera_alt,
                    size: 28,
                    color: _processing
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ],
        if (_capturing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3, color: Colors.white,
              ),
            ),
          ),
        if (_errorMessage != null)
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.videocam_off, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ]),
            ),
          )
        else if (!_cameraReady)
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3, color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlateGuidePainter extends CustomPainter {
  final bool isScanning;

  const _PlateGuidePainter({this.isScanning = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rw = size.width * 0.78;
    final rh = rw * 0.30;
    final l = (size.width - rw) / 2;
    final t = (size.height - rh) / 2;

    final overlay = Paint()..color = Colors.black45;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, t), overlay);
    canvas.drawRect(Rect.fromLTWH(0, t + rh, size.width, size.height - t - rh), overlay);
    canvas.drawRect(Rect.fromLTWH(0, t, l, rh), overlay);
    canvas.drawRect(Rect.fromLTWH(l + rw, t, size.width - l - rw, rh), overlay);

    final cornerColor = isScanning
        ? const Color(0xFF3B82F6)
        : Colors.greenAccent;
    final corner = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const cl = 24.0;
    canvas.drawLine(Offset(l, t + cl), Offset(l, t), corner);
    canvas.drawLine(Offset(l, t), Offset(l + cl, t), corner);
    canvas.drawLine(Offset(l + rw - cl, t), Offset(l + rw, t), corner);
    canvas.drawLine(Offset(l + rw, t), Offset(l + rw, t + cl), corner);
    canvas.drawLine(Offset(l + rw, t + rh - cl), Offset(l + rw, t + rh), corner);
    canvas.drawLine(Offset(l + rw, t + rh), Offset(l + rw - cl, t + rh), corner);
    canvas.drawLine(Offset(l + cl, t + rh), Offset(l, t + rh), corner);
    canvas.drawLine(Offset(l, t + rh), Offset(l, t + rh - cl), corner);

    final tp = TextPainter(
      text: TextSpan(
        text: 'Centrez la plaque dans le cadre',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, t - 30));
  }

  @override
  bool shouldRepaint(covariant _PlateGuidePainter old) =>
      old.isScanning != isScanning;
}

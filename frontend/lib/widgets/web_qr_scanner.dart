import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;

class WebQrScannerWidget extends StatefulWidget {
  final void Function(String) onScan;
  final void Function(String?)? onError;

  const WebQrScannerWidget({
    required this.onScan,
    this.onError,
    super.key,
  });

  @override
  State<WebQrScannerWidget> createState() => _WebQrScannerWidgetState();
}

class _WebQrScannerWidgetState extends State<WebQrScannerWidget> {
  late final String _viewType;
  web.MediaStream? _mediaStream;
  bool _hasScanned = false;
  bool _cameraReady = false;
  String? _errorMessage;
  bool _useNative = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'web-qr-scanner-${identityHashCode(this)}';
    _useNative =
        ((web.window as JSObject)['BarcodeDetector'] as JSFunction?) != null;
    _registerViewFactory();
  }

  void _registerViewFactory() {
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        return _buildScannerElement();
      });
    } catch (e) {
      debugPrint('View factory registration error: $e');
    }
  }

  web.HTMLDivElement _buildScannerElement() {
    final container = web.HTMLDivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.position = 'relative'
      ..style.overflow = 'hidden'
      ..style.backgroundColor = '#000000';

    final video = web.HTMLVideoElement()
      ..id = 'qr-video-$_viewType'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..setAttribute('autoplay', '')
      ..setAttribute('playsinline', '')
      ..setAttribute('muted', '');

    container.appendChild(video);

    Future.delayed(const Duration(milliseconds: 300), () {
      _startCamera(video);
    });

    return container;
  }

  Future<String?> _detectNative(web.HTMLVideoElement video) async {
    try {
      final ctor = (web.window as JSObject)['BarcodeDetector'] as JSFunction?;
      if (ctor == null) return null;

      final options = {'formats': ['qr_code']}.jsify() as JSAny;
      final detector = ctor.callAsConstructor(options);

      final detectFn = (detector as JSObject)['detect'] as JSFunction;
      final promise = detectFn.callAsFunction(detector, video) as JSPromise;
      final barcodes = await promise.toDart;
      if (barcodes == null) return null;

      final arr = barcodes as JSObject;
      final len = (arr['length'] as JSNumber?)?.toDartInt ?? 0;
      if (len > 0) {
        final first = arr['0'] as JSObject?;
        if (first == null) return null;
        final raw = first['rawValue'] as JSString?;
        if (raw != null) return raw.toDart.trim().toUpperCase();
      }
    } catch (e) {
      debugPrint('BarcodeDetector error: $e');
    }
    return null;
  }

  Future<String?> _detectJsQr(web.HTMLVideoElement video) async {
    try {
      final jsQR = (web.window as JSObject)['jsQR'] as JSFunction?;
      if (jsQR == null) return null;

      int w = video.videoWidth;
      int h = video.videoHeight;
      if (w > 640) {
        h = (h * 640 / w).round();
        w = 640;
      }

      final canvas = web.HTMLCanvasElement()..width = w..height = h;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(video, 0, 0, w, h);
      final imageData = ctx.getImageData(0, 0, w, h);
      final result = jsQR.callAsFunction(
        (imageData as JSObject)['data'],
        w.toJS,
        h.toJS,
      ) as JSObject?;

      if (result != null) {
        final raw = result['data'] as JSString?;
        if (raw != null) return raw.toDart.trim().toUpperCase();
      }
    } catch (e) {
      debugPrint('jsQR error: $e');
    }
    return null;
  }

  Future<void> _startCamera(web.HTMLVideoElement video) async {
    try {
      if (!_useNative) {
        final jsQR = (web.window as JSObject)['jsQR'] as JSFunction?;
        if (jsQR == null) {
          _setError(
              'Aucun detecteur disponible. Verifiez que jsQR.min.js est charge.');
          return;
        }
      }

      final constraints = web.MediaStreamConstraints(
        video: {
          'facingMode': 'environment',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        }.jsify() as JSAny,
      );

      final stream =
          await web.window.navigator.mediaDevices
              .getUserMedia(constraints)
              .toDart;

      _mediaStream = stream;
      video.srcObject = stream;

      await video.play().toDart;

      if (mounted) {
        setState(() => _cameraReady = true);
      }

      _startScanning(video);
    } catch (e) {
      debugPrint('Camera error: $e');
      final msg = e.toString();
      if (msg.contains('NotAllowed') || msg.contains('PermissionDenied')) {
        _setError(
            'Acces camera refuse. Autorisez la camera dans les parametres du navigateur.');
      } else if (msg.contains('NotFound')) {
        _setError('Aucune camera trouvee sur cet appareil.');
      } else if (msg.contains('NotReadable') || msg.contains('could not start video source')) {
        _setError(
            'Caméra utilisée par une autre application (Zoom, Teams...). Fermez-la ou utilisez la saisie manuelle.');
      } else {
        _setError(
            'Erreur camera: ${msg.length > 80 ? msg.substring(0, 80) : msg}');
      }
    }
  }

  void _setError(String msg) {
    debugPrint('WebQrScanner error: $msg');
    if (mounted) {
      setState(() => _errorMessage = msg);
      widget.onError?.call(msg);
    }
  }

  void _startScanning(web.HTMLVideoElement video) {
    void scan() async {
      if (!mounted || _hasScanned) {
        _disposeStream();
        return;
      }

      if (video.readyState >= 2 &&
          video.videoWidth > 0 &&
          video.videoHeight > 0) {
        String? raw;

        if (_useNative) {
          raw = await _detectNative(video);
        }

        raw ??= await _detectJsQr(video);

        if (raw != null && raw.isNotEmpty && mounted && !_hasScanned) {
          _hasScanned = true;
          widget.onScan(raw.toUpperCase());
          return;
        }
      }

      if (mounted && !_hasScanned) {
        Future.delayed(const Duration(milliseconds: 300), scan);
      }
    }

    void waitForVideo(num _) {
      if (!mounted) return;
      if (video.readyState >= 2 &&
          video.videoWidth > 0 &&
          video.videoHeight > 0) {
        scan();
      } else {
        web.window.requestAnimationFrame(waitForVideo.toJS);
      }
    }

    web.window.requestAnimationFrame(waitForVideo.toJS);
  }

  void _disposeStream() {
    if (_mediaStream != null) {
      final tracks = _mediaStream!.getTracks();
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }
      _mediaStream = null;
    }
  }

  @override
  void dispose() {
    _disposeStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (_errorMessage != null)
          Container(
            color: Colors.black87,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (!_cameraReady)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: Colors.white),
                  ),
                  SizedBox(height: 12),
                  Text('Demarrage camera…',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white70),
                      ),
                      SizedBox(width: 8),
                      Text('Scan en cours…',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../widgets/plate_scanner_stub.dart' if (dart.library.html) '../widgets/plate_scanner_web.dart';
import 'dart:math' as math;

class AccessControlPage extends StatefulWidget {
  const AccessControlPage({super.key});

  @override
  State<AccessControlPage> createState() => _AccessControlPageState();
}

class _AccessControlPageState extends State<AccessControlPage> {
  String? _token;
  bool _isLoading = true;
  bool _backendOffline = false;

  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _logs = [];

  int _tabIndex = 0;
  String _logFilter = '';

  String _gateMode = 'Entrée';

  int get _allowedCount => _rules.where((r) => r['allowed'] == true).length;
  int get _blockedCount => _rules.where((r) => r['allowed'] == false).length;
  int get _grantedCount => _logs.where((l) => l['granted'] == true).length;
  int get _deniedCount => _logs.where((l) => l['granted'] == false).length;

  List<Map<String, dynamic>> get _filteredLogs {
    if (_logFilter.isEmpty) return _logs;
    final q = _logFilter.toUpperCase();
    return _logs.where((l) =>
      (l['vehicle_plate'] as String? ?? '').toUpperCase().contains(q)
    ).toList();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    await Future.wait([_fetchRules(), _fetchLogs()]);
  }

  Future<void> _fetchRules() async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/api/access/rules'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _rules = List<Map<String, dynamic>>.from(json.decode(res.body));
          _isLoading = false;
          _backendOffline = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) { setState(() {
      _isLoading = false;
      _backendOffline = true;
      _rules = _mockRules;
    }); }
  }

  static List<Map<String, dynamic>> get _mockRules => [
    {'id': 1, 'vehicle_plate': '123-TUN-45', 'vehicle_model': 'Mercedes-Benz Actros', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 2, 'vehicle_plate': '123-TUN-45', 'vehicle_model': 'Mercedes-Benz Actros', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 3, 'vehicle_plate': '456-NBL-78', 'vehicle_model': 'Scania R-Series', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 4, 'vehicle_plate': '456-NBL-78', 'vehicle_model': 'Scania R-Series', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 5, 'vehicle_plate': '789-SF-01', 'vehicle_model': 'Volvo FH', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 6, 'vehicle_plate': '789-SF-01', 'vehicle_model': 'Volvo FH', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 7, 'vehicle_plate': '111-ARI-22', 'vehicle_model': 'MAN TGX', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 8, 'vehicle_plate': '333-BEN-44', 'vehicle_model': 'DAF XF', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 9, 'vehicle_plate': '555-MON-66', 'vehicle_model': 'Renault Trucks T', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 10, 'vehicle_plate': '777-SUS-88', 'vehicle_model': 'Mercedes-Benz Arocs', 'allowed': false, 'gate': 'Entrée', 'time_start': '06:00', 'time_end': '22:00', 'created_at': '2025-01-01T00:00:00'},
    {'id': 11, 'vehicle_plate': 'FI-202-IK', 'vehicle_model': 'Scania G-Series', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 12, 'vehicle_plate': 'NN-303-LP', 'vehicle_model': 'Volvo FM', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 13, 'vehicle_plate': 'FR-606-TY', 'vehicle_model': 'Ford F-MAX', 'allowed': false, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 14, 'vehicle_plate': 'CO-7710-D', 'vehicle_model': 'DAF CF', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 15, 'vehicle_plate': 'CO-7710-D', 'vehicle_model': 'DAF CF', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 16, 'vehicle_plate': 'HY-505-UI', 'vehicle_model': 'Iveco S-Way', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 17, 'vehicle_plate': 'HY-505-UI', 'vehicle_model': 'Iveco S-Way', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 18, 'vehicle_plate': 'TY-404-ER', 'vehicle_model': 'MAN TGS', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 19, 'vehicle_plate': 'TY-404-ER', 'vehicle_model': 'MAN TGS', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 20, 'vehicle_plate': 'FR-4401-P', 'vehicle_model': 'Renault Trucks D', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 21, 'vehicle_plate': 'FR-4401-P', 'vehicle_model': 'Renault Trucks D', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 22, 'vehicle_plate': '199 تونس 199', 'vehicle_model': 'Citroën C3', 'allowed': true, 'gate': 'Entrée', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
    {'id': 23, 'vehicle_plate': '199 تونس 199', 'vehicle_model': 'Citroën C3', 'allowed': true, 'gate': 'Sortie', 'time_start': '00:00', 'time_end': '23:59', 'created_at': '2025-01-01T00:00:00'},
  ];

  Future<void> _fetchLogs() async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/api/access/logs?limit=50'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() { _logs = List<Map<String, dynamic>>.from(json.decode(res.body)); });
        return;
      }
    } catch (_) {}
    if (mounted && _logs.isEmpty) {
      setState(() { _logs = _mockLogs; });
    }
  }

  static List<Map<String, dynamic>> get _mockLogs => [
    {'id': 1, 'vehicle_plate': '123-TUN-45', 'action': 'ENTRY', 'gate': 'Entrée', 'granted': true, 'reason': 'Accès autorisé', 'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String()},
    {'id': 2, 'vehicle_plate': '789-SF-01', 'action': 'EXIT', 'gate': 'Sortie', 'granted': true, 'reason': 'Sortie enregistrée', 'timestamp': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String()},
    {'id': 3, 'vehicle_plate': '111-ARI-22', 'action': 'ENTRY', 'gate': 'Entrée', 'granted': true, 'reason': 'Véhicule connu', 'timestamp': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String()},
    {'id': 4, 'vehicle_plate': 'FR-606-TY', 'action': 'ENTRY', 'gate': 'Entrée', 'granted': false, 'reason': 'Plaque non autorisée', 'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()},
    {'id': 5, 'vehicle_plate': '123-TUN-45', 'action': 'EXIT', 'gate': 'Sortie', 'granted': true, 'reason': 'Sortie enregistrée', 'timestamp': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()},
    {'id': 6, 'vehicle_plate': '456-NBL-78', 'action': 'ENTRY', 'gate': 'Entrée', 'granted': true, 'reason': 'Accès autorisé', 'timestamp': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String()},
    {'id': 7, 'vehicle_plate': '777-SUS-88', 'action': 'ENTRY', 'gate': 'Entrée', 'granted': false, 'reason': 'Accès refusé par règle', 'timestamp': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String()},
    {'id': 8, 'vehicle_plate': '333-BEN-44', 'action': 'EXIT', 'gate': 'Sortie', 'granted': true, 'reason': 'Sortie enregistrée', 'timestamp': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String()},
    {'id': 9, 'vehicle_plate': '199 تونس 199', 'action': 'ENTRY', 'gate': 'Entrée', 'granted': true, 'reason': 'Accès autorisé', 'timestamp': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String()},
  ];

  String _timeAgo(String? ts) {
    if (ts == null) return '';
    try {
      final dt = DateTime.parse(ts);
      final diff = DateTime.now().toUtc().difference(dt);
      if (diff.inSeconds < 60) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return '${diff.inDays}j';
    } catch (_) {
      try { return ts.substring(0, 16).replaceAll('T', ' '); } catch (_) { return ts; }
    }
  }

  // ── Scan with camera preview + guide overlay ──

  Future<void> _scanGate() async {
    if (kIsWeb) {
      await _webPlateScanLive();
    } else {
      await _mobileScan();
    }
  }

  Future<void> _webPlateScanLive() async {
    String? detectedPlate;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WebVerifyLiveDialog(
        gateMode: _gateMode,
        onVerify: (plate) {
          detectedPlate = plate;
          Navigator.of(ctx).pop();
        },
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );

    if (!mounted || detectedPlate == null) return;
    _checkPlateAccess(detectedPlate!);
  }

  Future<void> _mobileScan() async {
    final doScan = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: math.min(MediaQuery.of(context).size.width - 32, 360),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 160, width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(painter: _PlateGuidePainter(), size: const Size(360, 160)),
            ),
            const SizedBox(height: 20),
            const Text('Centrez la plaque dans le cadre',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            const Text('Le scan utilise la caméra du serveur',
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Lancer le scan'),
              ),
            ]),
          ]),
        ),
      ),
    );

    if (doScan != true || !mounted) return;
    setState(() => _isLoading = true);

    String? plate;
    bool granted = false;
    String reason = 'Erreur de scan';
    String? imageB64;
    String action = '';

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/yolo/scan'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: json.encode({'gate': _gateMode}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        plate = data['plate'];
        granted = data['granted'] ?? false;
        reason = data['reason'] ?? '';
        imageB64 = data['image_b64'];
        action = data['action'] ?? '';
      } else if (res.statusCode == 503) {
        try {
          final data = json.decode(res.body);
          reason = data['detail'] ?? 'Caméra serveur indisponible';
        } catch (_) {
          reason = 'Caméra serveur indisponible';
        }
      } else {
        reason = 'Erreur serveur (${res.statusCode})';
      }
    } catch (_) {
      reason = 'Backend hors ligne';
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _showScanResult(plate, granted, reason, imageB64, action);
    if (plate != null) _fetchLogs();
  }



  Future<void> _checkPlateAccess(String plate) async {
    setState(() => _isLoading = true);
    bool granted = false;
    String reason = 'Erreur de vérification';

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/access/check'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: json.encode({'vehicle_plate': plate, 'gate': 'Entrée'}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        granted = data['granted'] ?? false;
        reason = data['reason'] ?? '';
      } else {
        reason = 'Erreur serveur (${res.statusCode})';
      }
    } catch (_) {
      reason = 'Backend hors ligne';
    }

    try {
      await http.post(
        Uri.parse('$kApiBaseUrl/api/access/log'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: json.encode({
          'vehicle_plate': plate, 'action': 'ENTRY', 'gate': 'Entrée',
          'granted': granted, 'reason': reason,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);
    _fetchLogs();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: math.min(MediaQuery.of(context).size.width - 32, 360),
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: granted ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(granted ? Icons.check_circle : Icons.cancel, size: 48, color: granted ? Colors.green : Colors.red),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0F172A), letterSpacing: 1)),
            ),
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: granted ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: granted ? Colors.green : Colors.red, width: 2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(granted ? Icons.check : Icons.close, size: 18, color: granted ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                Text(granted ? 'ACCÈS AUTORISÉ' : 'ACCÈS REFUSÉ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: granted ? Colors.green : Colors.red, letterSpacing: 1),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text(reason, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
          ]),
        ),
        actions: [
          Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(fontSize: 14)))),
        ],
      ),
    );
  }

  void _showScanResult(String? plate, bool granted, String reason, String? imageB64, String action) {
    final isExit = action == 'EXIT';

    Color resultColor;
    IconData resultIcon;
    String resultLabel;

    if (plate == null) {
      resultColor = Colors.orange;
      resultIcon = Icons.videocam_off;
      resultLabel = 'ÉCHEC DÉTECTION';
    } else if (isExit) {
      resultColor = Colors.blue;
      resultIcon = Icons.logout;
      resultLabel = 'SORTIE ENREGISTRÉE';
    } else if (granted) {
      resultColor = Colors.green;
      resultIcon = Icons.check_circle;
      resultLabel = 'ACCÈS AUTORISÉ';
    } else {
      resultColor = Colors.red;
      resultIcon = Icons.cancel;
      resultLabel = 'ACCÈS REFUSÉ';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: math.min(MediaQuery.of(context).size.width - 32, 380),
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (imageB64 != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(imageB64),
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(resultIcon, size: 48, color: resultColor),
            ),
            const SizedBox(height: 20),
            if (plate != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0F172A), letterSpacing: 1)),
              ),
              const SizedBox(height: 16),
            ],
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: resultColor, width: 2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(resultIcon, size: 18, color: resultColor),
                const SizedBox(width: 8),
                Text(resultLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: resultColor, letterSpacing: 1)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(reason, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
          ]),
        ),
        actions: [
          if (plate == null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openManualEntry();
                },
                icon: const Icon(Icons.keyboard, size: 16),
                label: const Text('Saisie manuelle', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _scanGate();
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer', style: TextStyle(fontSize: 14)),
              ),
            ]),
          ] else ...[
            Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(fontSize: 14)))),
          ],
        ],
      ),
    );
  }

  void _openManualEntry() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.keyboard, size: 20, color: Color(0xFF0F172A)),
          SizedBox(width: 10),
          Text('Saisie manuelle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: math.min(MediaQuery.of(context).size.width - 32, 350),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Entrez la plaque d\'immatriculation :', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. 123-TUN-45',
                filled: true, fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.directions_car, size: 18, color: Color(0xFF64748B)),
              ),
              onSubmitted: (value) {
                final plate = value.trim().toUpperCase();
                if (plate.isNotEmpty) {
                  Navigator.pop(ctx);
                  _checkPlateAccess(plate);
                }
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final plate = ctrl.text.trim().toUpperCase();
              if (plate.isEmpty) return;
              Navigator.pop(ctx);
              _checkPlateAccess(plate);
            },
            child: const Text('Vérifier'),
          ),
        ],
      ),
    );
  }

  void _showRuleDialog({Map<String, dynamic>? rule}) {
    final isEdit = rule != null;
    final plateCtrl = TextEditingController(text: isEdit ? rule['vehicle_plate'] ?? '' : '');
    final modelCtrl = TextEditingController(text: isEdit ? rule['vehicle_model'] ?? '' : '');
    String gate = isEdit ? rule['gate'] ?? 'Entrée' : 'Entrée';
    bool allowed = isEdit ? rule['allowed'] ?? true : true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(children: [
            Icon(isEdit ? Icons.edit : Icons.add_circle_outline, size: 20, color: const Color(0xFF0F172A)),
            const SizedBox(width: 10),
            Text(isEdit ? 'Modifier la règle' : 'Nouvelle règle'),
          ]),
          content: SizedBox(
            width: math.min(MediaQuery.of(context).size.width - 32, 400),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: plateCtrl, decoration: const InputDecoration(labelText: 'Plaque', hintText: 'e.g. 123-TUN-45', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_car, size: 18))),
                const SizedBox(height: 14),
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modèle (optionnel)', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder(), prefixIcon: Icon(Icons.model_training, size: 18))),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: gate,
                  decoration: const InputDecoration(labelText: 'Porte', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder(), prefixIcon: Icon(Icons.door_front_door, size: 18)),
                  items: const [
                    DropdownMenuItem(value: 'Entrée', child: Row(children: [Icon(Icons.login, size: 16), SizedBox(width: 8), Text('Entrée')])),
                    DropdownMenuItem(value: 'Sortie', child: Row(children: [Icon(Icons.logout, size: 16), SizedBox(width: 8), Text('Sortie')])),
                    DropdownMenuItem(value: 'Main Gate', child: Row(children: [Icon(Icons.home, size: 16), SizedBox(width: 8), Text('Main Gate')])),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => gate = v); },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: Row(children: [
                    Icon(allowed ? Icons.check_circle : Icons.cancel, color: allowed ? Colors.green : Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Text(allowed ? 'Autorisé' : 'Bloqué', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: allowed ? Colors.green : Colors.red)),
                    const Spacer(),
                    Switch(
                      value: allowed,
                      onChanged: (v) => setDialogState(() => allowed = v),
                      activeThumbColor: Colors.green,
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isEdit ? const Color(0xFF0F172A) : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (plateCtrl.text.trim().isEmpty) { _showSnack('Plaque obligatoire', isError: true); return; }
                final body = {
                  'vehicle_plate': plateCtrl.text.trim().toUpperCase(),
                  'vehicle_model': modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
                  'allowed': allowed,
                  'gate': gate,
                };
                if (_backendOffline) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  setState(() {
                    if (isEdit) {
                      final idx = _rules.indexWhere((r) => r['id'] == rule['id']);
                      if (idx >= 0) _rules[idx] = {..._rules[idx], ...body};
                    } else {
                      final newId = _rules.isEmpty ? 1 : (_rules.map((r) => r['id'] as int).reduce(math.max) + 1);
                      _rules.add({...body, 'id': newId, 'time_start': '00:00', 'time_end': '23:59', 'created_at': DateTime.now().toIso8601String()});
                    }
                  });
                  _showSnack(isEdit ? 'Règle modifiée' : 'Règle créée');
                  return;
                }
                try {
                  final res = isEdit
                    ? await http.put(
                        Uri.parse('$kApiBaseUrl/api/access/rules/${rule['id']}'),
                        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
                        body: json.encode(body),
                      ).timeout(const Duration(seconds: 10))
                    : await http.post(
                        Uri.parse('$kApiBaseUrl/api/access/rules'),
                        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
                        body: json.encode(body),
                      ).timeout(const Duration(seconds: 10));
                  if (res.statusCode == 200 || res.statusCode == 201) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _fetchRules();
                    _showSnack(isEdit ? 'Règle modifiée' : 'Règle créée');
                  } else {
                    _showSnack('Erreur (${res.statusCode})', isError: true);
                  }
                } catch (_) { _showSnack('Erreur serveur', isError: true); }
              },
              child: Text(isEdit ? 'Enregistrer' : 'Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRule(int ruleId, String plate) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirmer'),
        content: Text('Supprimer la règle pour "$plate" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(context);
              if (_backendOffline) {
                setState(() => _rules.removeWhere((r) => r['id'] == ruleId));
                _showSnack('Règle supprimée');
                return;
              }
              try {
                await http.delete(
                  Uri.parse('$kApiBaseUrl/api/access/rules/$ruleId'),
                  headers: {'Authorization': 'Bearer $_token'},
                ).timeout(const Duration(seconds: 10));
                _fetchRules();
                _showSnack('Règle supprimée');
              } catch (_) { _showSnack('Erreur serveur', isError: true); }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _toggleRule(Map<String, dynamic> rule) async {
    if (_backendOffline) {
      setState(() {
        rule['allowed'] = !(rule['allowed'] ?? true);
      });
      return;
    }
    try {
      await http.put(
        Uri.parse('$kApiBaseUrl/api/access/rules/${rule['id']}'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: json.encode({
          'vehicle_plate': rule['vehicle_plate'],
          'vehicle_model': rule['vehicle_model'],
          'allowed': !(rule['allowed'] ?? true),
          'gate': rule['gate'] ?? 'Entrée',
        }),
      ).timeout(const Duration(seconds: 10));
      _fetchRules();
    } catch (_) { _showSnack('Erreur', isError: true); }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(msg),
      ]),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0F172A),
      duration: const Duration(seconds: 3),
    ));
  }

  List<Map<String, dynamic>> get _todayLogs {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _logs.where((l) {
      final ts = l['timestamp'] as String? ?? '';
      return ts.startsWith(today);
    }).toList();
  }

  int get _todayGranted => _todayLogs.where((l) => l['granted'] == true).length;
  int get _todayDenied => _todayLogs.where((l) => l['granted'] == false).length;

  static const _gates = ['Entrée', 'Sortie'];

  @override
  Widget build(BuildContext context) {
    final uniquePlates = _logs.map((l) => l['vehicle_plate'] as String? ?? '').where((p) => p.isNotEmpty).toSet().length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_backendOffline) Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
          child: Row(children: [
            const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 16),
            const SizedBox(width: 10),
            const Expanded(child: Text('Backend hors ligne', style: TextStyle(color: Color(0xFF92400E), fontSize: 11))),
            TextButton(onPressed: () { _fetchRules(); _fetchLogs(); }, child: const Text('Réessayer', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11))),
          ]),
        ),
        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Contrôle d\'accès', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text('${_logs.length} accès enregistrés · $uniquePlates plaques uniques',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ])),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            _buildGateSelector(),
            const SizedBox(width: 8),
            _buildButton('Scanner', Icons.qr_code_scanner, onTap: _scanGate, isPrimary: true),
            const SizedBox(width: 8),
            _buildButton('Saisie', Icons.keyboard, onTap: _openManualEntry),
            const SizedBox(width: 8),
            _buildButton('Actualiser', Icons.refresh, onTap: () { _fetchRules(); _fetchLogs(); }),
          ])),
        ]),
        const SizedBox(height: 20),

        // Stats row
        _buildStatsRow(),
        const SizedBox(height: 20),

        // Gates overview
        _buildGatesSection(),
        const SizedBox(height: 20),

        // Today activity
        _buildTodaySection(),
        const SizedBox(height: 20),

        // Tabs
        Row(children: [
          _buildTab('Règles', _rules.length, 0),
          const SizedBox(width: 8),
          _buildTab('Journal', _logs.length, 1),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _tabIndex == 0 ? _buildRulesTab() : _buildLogsTab(),
        ),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final cards = [
      _statCard('Règles', '$_allowedCount', Icons.shield_outlined, const Color(0xFF0F172A), '$_blockedCount bloquées'),
      _statCard('Accès', '$_grantedCount', Icons.check_circle, const Color(0xFF10B981), '$_deniedCount refusés'),
      _statCard('Aujourd\'hui', '$_todayGranted', Icons.today, const Color(0xFF3B82F6), '$_todayDenied refusés'),
      _statCard('Portes', '${_gates.length}', Icons.door_front_door, const Color(0xFF8B5CF6), 'actives'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ]);
        } else {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: cards[0]),
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: cards[1]),
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: cards[2]),
              SizedBox(width: (constraints.maxWidth - 12) / 2, child: cards[3]),
            ],
          );
        }
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ]),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFFCBD5E1))),
      ]),
    );
  }

  Widget _buildGatesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.door_front_door, size: 16, color: Color(0xFF8B5CF6)),
          ),
          const SizedBox(width: 10),
          const Text('Portes & Barrières', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 10, color: Color(0xFF10B981)),
              SizedBox(width: 4),
              Text('Tout opérationnel', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: _gates.map((gate) {
          final gateLogs = _logs.where((l) => l['gate'] == gate).toList();
          final gateOk = gateLogs.where((l) => l['granted'] == true).length;
          final gateKo = gateLogs.where((l) => l['granted'] == false).length;
          return Expanded(child: Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(children: [
              Icon(Icons.door_front_door, size: 28, color: gateOk + gateKo > 0 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
              const SizedBox(height: 8),
              Text(gate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(6)),
                  child: Text('$gateOk OK', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ),
                if (gateKo > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
                    child: Text('$gateKo KO', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                  ),
                ],
              ]),
            ]),
          ));
        }).toList()),
      ]),
    );
  }

  Widget _buildTodaySection() {
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.today, size: 16, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 10),
            const Text('Activité aujourd\'hui', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            const Spacer(),
            Text('${_todayLogs.length} événements', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
          ]),
          if (_todayLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 6),
                Text('Aucune activité aujourd\'hui — cliquez pour voir les autorisations',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ]),
            )
          else ...[
            const SizedBox(height: 14),
            // Barre de proportion autorisé/refusé
            if (_todayGranted + _todayDenied > 0) ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Flexible(
                    flex: _todayGranted,
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  if (_todayDenied > 0)
                    Flexible(
                      flex: _todayDenied,
                      child: Container(color: const Color(0xFFEF4444)),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _miniStat(Icons.check_circle, '$_todayGranted autorisés', const Color(0xFF10B981)),
              const SizedBox(width: 16),
              _miniStat(Icons.cancel, '$_todayDenied refusés', const Color(0xFFEF4444)),
            ]),
            const SizedBox(height: 12),
            // Derniers scans du jour
            ..._todayLogs.take(5).map((l) => _todayLogRow(l)),
          ],
        ]),
      ),
    );
  }

  Widget _miniStat(IconData icon, String text, Color color) {
    return Row(children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
    ]);
  }

  Widget _todayLogRow(Map<String, dynamic> l) {
    final granted = l['granted'] as bool? ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: granted ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(l['vehicle_plate'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Text(l['gate'] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        const SizedBox(width: 8),
        Text(granted ? '✓' : '✗', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: granted ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
      ]),
    );
  }

  Widget _buildTab(String label, int count, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? Colors.white : const Color(0xFF64748B))),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? Colors.white : const Color(0xFF64748B))),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildRulesTab() {
    return Column(key: const ValueKey('rules'), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.check_circle, size: 14, color: Colors.green),
          ),
          const SizedBox(width: 6),
          Text('$_allowedCount autorisées', style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.cancel, size: 14, color: Colors.red),
          ),
          const SizedBox(width: 6),
          Text('$_blockedCount bloquées', style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
        _buildButton('Ajouter', Icons.add, onTap: () => _showRuleDialog()),
      ]),
      const SizedBox(height: 12),
      if (_isLoading)
        const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
      else if (_rules.isEmpty)
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Column(children: [
            Icon(Icons.shield_outlined, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text('Aucune règle configurée', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
            SizedBox(height: 4),
            Text('Ajoutez une règle pour autoriser ou bloquer des véhicules', style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
          ])),
        )
      else
        ..._rules.map((r) => _buildRuleCard(r)),
    ]);
  }

  Widget _buildRuleCard(Map<String, dynamic> r) {
    final allowed = r['allowed'] as bool? ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: allowed ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: allowed ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(allowed ? Icons.check_circle : Icons.cancel, color: allowed ? Colors.green : Colors.red, size: 22),
        ),
        title: Row(children: [
          Expanded(child: Text(r['vehicle_plate'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
          if (r['vehicle_model'] != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4)),
              child: Text(r['vehicle_model'], style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
            ),
          ],
        ]),
        subtitle: Row(children: [
          const Icon(Icons.door_front_door, size: 12, color: Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Flexible(child: Text(r['gate'] ?? '', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Flexible(child: Text('${r['time_start'] ?? '00:00'} - ${r['time_end'] ?? '23:59'}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), overflow: TextOverflow.ellipsis)),
          const Spacer(),
          Switch(
            value: allowed,
            onChanged: (_) => _toggleRule(r),
            activeTrackColor: Colors.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (action) {
            if (action == 'edit') _showRuleDialog(rule: r);
            if (action == 'delete') _deleteRule(r['id'], r['vehicle_plate'] ?? '');
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Modifier')])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsTab() {
    return Column(key: const ValueKey('logs'), children: [
      TextField(
        onChanged: (v) => setState(() => _logFilter = v),
        decoration: InputDecoration(
          hintText: 'Rechercher par plaque…',
          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      const SizedBox(height: 12),
      if (_filteredLogs.isEmpty)
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Column(children: [
            Icon(_logFilter.isEmpty ? Icons.history : Icons.search_off, size: 48, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(_logFilter.isEmpty ? 'Aucun accès enregistré' : 'Aucun résultat pour "$_logFilter"',
              style: const TextStyle(color: Color(0xFF94A3B8))),
          ])),
        )
      else
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              child: Row(children: [
                Expanded(flex: 2, child: Text('PLAQUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1))),
                Expanded(flex: 1, child: Text('ACTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1))),
                Expanded(flex: 1, child: Text('PORTE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1))),
                Expanded(flex: 1, child: Text('STATUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1))),
                Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade400, letterSpacing: 1))),
              ]),
            ),
            const Divider(color: Color(0xFFF1F5F9)),
            ..._filteredLogs.map((l) => _buildLogRow(l)),
          ]),
        ),
    ]);
  }

  Widget _buildLogRow(Map<String, dynamic> l) {
    final granted = l['granted'] as bool? ?? false;
    final action = l['action'] as String? ?? 'ENTRY';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(children: [
        Expanded(flex: 2, child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: granted ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(granted ? Icons.check_circle : Icons.cancel, size: 16, color: granted ? Colors.green : Colors.red),
          ),
          const SizedBox(width: 10),
          Text(l['vehicle_plate'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
        ])),
        Expanded(flex: 1, child: Row(children: [
          Icon(action == 'ENTRY' ? Icons.login : Icons.logout, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Flexible(child: Text(action == 'ENTRY' ? 'Entrée' : 'Sortie', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(flex: 1, child: Text(l['gate'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12), overflow: TextOverflow.ellipsis)),
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: granted ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(granted ? 'OK' : 'NON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: granted ? Colors.green : Colors.red), textAlign: TextAlign.center),
        )),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_timeAgo(l['timestamp'] as String?), style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11, fontWeight: FontWeight.w500)),
          Text(_formatTimestamp(l['timestamp'] as String? ?? ''), style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 9)),
        ])),
      ]),
    );
  }

  String _formatTimestamp(String ts) {
    try { return ts.substring(0, 16).replaceAll('T', ' '); }
    catch (_) { return ts; }
  }

  Widget _buildGateSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _gateOption('Entrée', Icons.login),
        const SizedBox(width: 2),
        _gateOption('Sortie', Icons.logout),
      ]),
    );
  }

  Widget _gateOption(String gate, IconData icon) {
    final selected = _gateMode == gate;
    return GestureDetector(
      onTap: () => setState(() => _gateMode = gate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(gate, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFF64748B),
          )),
        ]),
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, {VoidCallback? onTap, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: isPrimary ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : const Color(0xFF64748B))),
        ]),
      ),
    );
  }
}

class _WebVerifyLiveDialog extends StatefulWidget {
  final String gateMode;
  final ValueChanged<String> onVerify;
  final VoidCallback onClose;

  const _WebVerifyLiveDialog({
    required this.gateMode,
    required this.onVerify,
    required this.onClose,
  });

  @override
  State<_WebVerifyLiveDialog> createState() => _WebVerifyLiveDialogState();
}

class _WebVerifyLiveDialogState extends State<_WebVerifyLiveDialog> {
  String? _detectedPlate;
  String? _imageB64;
  bool _scanFailed = false;
  int _scanKey = 0;

  void _onPlateCaptured(ScanResult result) {
    if (result.plate == null) {
      setState(() => _scanFailed = true);
      return;
    }
    setState(() {
      _detectedPlate = result.plate;
      _imageB64 = result.imageB64;
    });
  }

  void _restartScan() {
    setState(() {
      _scanKey++;
      _detectedPlate = null;
      _imageB64 = null;
      _scanFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: math.min(MediaQuery.of(context).size.width - 32, 520),
        height: 460,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebPlateScannerWidget(
                key: ValueKey(_scanKey),
                onCapture: _onPlateCaptured,
                onError: () {},
                autoScan: true,
                gate: widget.gateMode,
              ),
              if (_detectedPlate != null) ...[
                Container(color: Colors.black54),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_imageB64 != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(_imageB64!),
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Icon(Icons.check_circle, color: Colors.green, size: 40),
                    const SizedBox(height: 8),
                    const Text('Plaque détectée',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_detectedPlate!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => widget.onVerify(_detectedPlate!),
                      icon: const Icon(Icons.shield, size: 18),
                      label: const Text('Vérifier l\'accès',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _restartScan,
                      child: const Text('Nouveau scan',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ]),
                ),
              ],
              if (_scanFailed) ...[
                Container(color: Colors.black54),
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.videocam_off, color: Colors.orange, size: 40),
                    const SizedBox(height: 12),
                    const Text('Aucune plaque détectée',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _restartScan,
                      child: const Text('Réessayer'),
                    ),
                  ]),
                ),
              ],
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rw = size.width * 0.78;
    final rh = rw * 0.30;
    final l = (size.width - rw) / 2;
    final t = (size.height - rh) / 2;

    final overlay = Paint()..color = Colors.black54;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, t), overlay);
    canvas.drawRect(Rect.fromLTWH(0, t + rh, size.width, size.height - t - rh), overlay);
    canvas.drawRect(Rect.fromLTWH(0, t, l, rh), overlay);
    canvas.drawRect(Rect.fromLTWH(l + rw, t, size.width - l - rw, rh), overlay);

    final corner = Paint()
      ..color = Colors.greenAccent
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

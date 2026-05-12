import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../mock_data.dart';
import '../widgets/qr_scanner_stub.dart' if (dart.library.html) '../widgets/web_qr_scanner.dart';

class EntryExitRecord {
  final int id;
  final int vehicleId;
  final String vehiclePlate;
  final String vehicleModel;
  final String? driver;
  final String entryTime;
  final String? exitTime;
  final String gate;
  final String status;
  final String? notes;
  final bool isKnown;
  final bool hasImage;
  String? _imageB64;

  EntryExitRecord({
    required this.id,
    required this.vehicleId,
    required this.vehiclePlate,
    required this.vehicleModel,
    this.driver,
    required this.entryTime,
    this.exitTime,
    required this.gate,
    required this.status,
    this.notes,
    this.isKnown = true,
    this.hasImage = false,
    String? imageB64,
  }) : _imageB64 = imageB64;

  String? get imageB64 => _imageB64;

  Future<String?> fetchImage(String token) async {
    if (_imageB64 != null) return _imageB64;
    if (!hasImage) return null;
    try {
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/api/entry-exit/$id/image'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _imageB64 = data['image_b64'];
        return _imageB64;
      }
    } catch (_) {}
    return null;
  }

  factory EntryExitRecord.fromJson(Map<String, dynamic> j) => EntryExitRecord(
        id: j['id'] ?? 0,
        vehicleId: j['vehicle_id'] ?? 0,
        vehiclePlate: j['vehicle_plate'] ?? '',
        vehicleModel: j['vehicle_model'] ?? '',
        driver: j['driver'],
        entryTime: j['entry_time'] ?? '',
        exitTime: j['exit_time'],
        gate: j['gate'] ?? 'Main Gate',
        status: j['status'] ?? 'INSIDE',
        notes: j['notes'],
        isKnown: j['is_known'] ?? true,
        hasImage: j['has_image'] ?? false,
      );

  String get duration {
    if (exitTime == null) return 'En cours';
    final fmt = RegExp(r'(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2})');
    final eMatch = fmt.firstMatch(entryTime);
    final xMatch = fmt.firstMatch(exitTime!);
    if (eMatch == null || xMatch == null) return '—';
    try {
      final e = DateTime.parse('${eMatch.group(1)}T${eMatch.group(2)}:00');
      final x = DateTime.parse('${xMatch.group(1)}T${xMatch.group(2)}:00');
      final diff = x.difference(e);
      if (diff.inDays > 0) return '${diff.inDays}j ${diff.inHours % 24}h';
      return '${diff.inHours}h ${diff.inMinutes % 60}min';
    } catch (_) {
      return '—';
    }
  }

  Color get statusColor => status == 'INSIDE'
      ? const Color(0xFF3B82F6)
      : const Color(0xFF64748B);
}

class HistoriqueESPage extends StatefulWidget {
  final void Function(int pageIndex, String plate, String model)? onNavigate;

  const HistoriqueESPage({super.key, this.onNavigate});

  @override
  State<HistoriqueESPage> createState() => _HistoriqueESPageState();
}

class _HistoriqueESPageState extends State<HistoriqueESPage> {
  List<EntryExitRecord> _records = [];
  bool _isLoading = true;
  bool _backendOffline = false;
  String? _filterStatus;
  bool _hideUnknown = true;

  static List<EntryExitRecord> get _mockRecords => kMockEntryExits.map((me) => EntryExitRecord(
    id: me.id,
    vehicleId: me.vehicleId,
    vehiclePlate: me.vehiclePlate,
    vehicleModel: me.vehicleModel,
    driver: me.driver,
    entryTime: me.entryTime,
    exitTime: me.exitTime,
    gate: me.gate,
    status: me.status,
    notes: me.notes,
    isKnown: me.isKnown,
  )).toList();

  List<EntryExitRecord> get _knownRecords => _records.where((r) {
    if (!_hideUnknown) return true;
    if (r.vehiclePlate.trim().isEmpty) return false;
    if (r.vehicleModel == 'Inconnu' || r.vehicleModel == 'Sans plaque') return false;
    return r.isKnown;
  }).toList();

  List<EntryExitRecord> get _filtered => _filterStatus == null
      ? _knownRecords
      : _knownRecords.where((r) => r.status == _filterStatus).toList();

  List<EntryExitRecord> get _uniqueVehicles {
    final seen = <String>{};
    final sorted = List<EntryExitRecord>.from(_filtered)
      ..sort((a, b) => b.entryTime.compareTo(a.entryTime));
    return sorted.where((r) => seen.add(r.vehiclePlate)).toList();
  }

  int get _uniqueInsideCount => _uniqueVehicles.where((r) => r.status == 'INSIDE').length;
  int get _uniqueOutsideCount => _uniqueVehicles.where((r) => r.status == 'OUTSIDE').length;

  @override
  void initState() {
    super.initState();
    setState(() { _records = List.from(_mockRecords); _isLoading = false; _backendOffline = false; });
    _loadCached().then((_) => _fetchRecords());
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cached_entry_exit');
      if (data != null && mounted) {
        final list = (json.decode(data) as List).map((e) => EntryExitRecord.fromJson(e)).toList();
        if (list.isNotEmpty) {
          final existingKeys = _records.map((r) => '${r.vehiclePlate}_${r.entryTime}').toSet();
          final newRecords = list.where((r) => !existingKeys.contains('${r.vehiclePlate}_${r.entryTime}')).toList();
          if (newRecords.isNotEmpty) setState(() { _records = [...newRecords, ..._records]; });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCache(List<EntryExitRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_entry_exit', json.encode(records.map((r) => {
        'id': r.id, 'vehicle_id': r.vehicleId, 'vehicle_plate': r.vehiclePlate,
        'vehicle_model': r.vehicleModel, 'driver': r.driver,
        'entry_time': r.entryTime, 'exit_time': r.exitTime,
        'gate': r.gate, 'status': r.status, 'notes': r.notes, 'is_known': r.isKnown,
      }).toList()));
    } catch (_) {}
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/api/entry-exit')).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final serverList = (json.decode(res.body) as List).map((e) => EntryExitRecord.fromJson(e)).toList();
        setState(() => _backendOffline = false);
        if (serverList.isNotEmpty) {
          final existingKeys = _records.map((r) => '${r.vehiclePlate}_${r.entryTime}').toSet();
          final newRecords = serverList.where((r) => !existingKeys.contains('${r.vehiclePlate}_${r.entryTime}')).toList();
          if (newRecords.isNotEmpty) {
            setState(() { _records = [...newRecords, ..._records]; _isLoading = false; });
            _saveCache(_records);
          } else {
            setState(() => _isLoading = false);
          }
          if (mounted) _showSnack('Données synchronisées avec le serveur', const Color(0xFF0F172A));
        } else {
          setState(() => _isLoading = false);
          if (mounted) _showSnack('Aucun enregistrement sur le serveur', const Color(0xFF64748B));
        }
        return;
      }
      setState(() => _isLoading = false);
      if (mounted) _showSnack('Erreur serveur (${res.statusCode})', Colors.red.shade700);
    } catch (_) {
      if (!mounted) return;
      setState(() { _backendOffline = true; _isLoading = false; });
      if (_records.isEmpty) {
        setState(() { _records = List.from(_mockRecords); });
        _showSnack('Backend hors ligne — données locales chargées', const Color(0xFFF59E0B));
      } else {
        _showSnack('Backend hors ligne — données en cache affichées', const Color(0xFFF59E0B));
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _openPlateScanner() {
    if (kIsWeb) {
      _openWebPlateScanner();
    } else {
      _openMobilePlateScanner();
    }
  }

  void _openMobilePlateScanner() {
    final controller = MobileScannerController(autoStart: true, facing: CameraFacing.back);
    bool hasScanned = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 300, width: double.infinity,
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (BarcodeCapture capture) {
                      if (hasScanned) return;
                      final barcode = capture.barcodes.firstOrNull;
                      if (barcode?.rawValue == null || barcode!.rawValue!.isEmpty) return;
                      hasScanned = true;
                      Navigator.of(dialogCtx).pop();
                      controller.dispose();
                      _showAddEntryWithPlate(barcode.rawValue!.trim().toUpperCase());
                    },
                    errorBuilder: (context, error, child) => Center(child: Text('Camera error: $error', style: const TextStyle(color: Colors.red))),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('OU SAISIR LA PLAQUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. BT-904-TX',
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: const Icon(Icons.directions_car, size: 18, color: Color(0xFF64748B)),
                    ),
                    onSubmitted: (value) {
                      final plate = value.trim().toUpperCase();
                      if (plate.isNotEmpty) {
                        Navigator.pop(dialogCtx);
                        controller.dispose();
                        _showAddEntryWithPlate(plate);
                      }
                    },
                  ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () { controller.dispose(); Navigator.pop(dialogCtx); }, child: const Text('Fermer')),
          ],
        ),
      ),
    ).then((_) { try { controller.dispose(); } catch (_) {} });
  }

  void _openWebPlateScanner() {
    bool hasScanned = false;
    bool cameraFailed = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: cameraFailed ? 180 : 360,
                width: double.infinity,
                decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                clipBehavior: Clip.antiAlias,
                child: cameraFailed
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.videocam_off, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(errorMessage ?? 'Caméra non disponible', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () { cameraFailed = false; errorMessage = null; setDialogState(() {}); },
                          icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                          label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38)),
                        ),
                      ]))
                    : WebQrScannerWidget(
                        onScan: (scannedId) {
                          if (hasScanned) return;
                          hasScanned = true;
                          Navigator.of(dialogCtx).pop();
                          _showAddEntryWithPlate(scannedId.trim().toUpperCase());
                        },
                        onError: (msg) { cameraFailed = true; errorMessage = msg ?? 'Erreur caméra'; setDialogState(() {}); },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  const Text('OU SAISIR LA PLAQUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. BT-904-TX',
                      filled: true, fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: const Icon(Icons.directions_car, size: 18, color: Color(0xFF64748B)),
                    ),
                    onSubmitted: (value) {
                      final plate = value.trim().toUpperCase();
                      if (plate.isNotEmpty) {
                        Navigator.pop(dialogCtx);
                        _showAddEntryWithPlate(plate);
                      }
                    },
                  ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () { Navigator.pop(dialogCtx); }, child: const Text('Fermer')),
          ],
        ),
      ),
    );
  }

  void _showAddEntryWithPlate(String plate) {
    final knownModels = <String, String>{
      for (final v in kMockVehicles) v.plate: v.model,
    };
    final model = knownModels[plate] ?? 'Inconnu';
    final driver = kMockVehicles.where((v) => v.plate == plate).firstOrNull?.driver;
    final now = DateTime.now().toString().substring(0, 16);

    _addEntry({
      'vehicle_id': kMockVehicles.where((v) => v.plate == plate).firstOrNull?.id ?? 0,
      'vehicle_plate': plate,
      'vehicle_model': model,
      'driver': driver,
      'entry_time': now,
      'exit_time': null,
      'gate': 'Entrée',
      'status': 'INSIDE',
      'notes': 'Scanné par caméra',
      'is_known': knownModels.containsKey(plate),
    });
  }

  Future<void> _addEntry(Map<String, dynamic> data) async {
    final newRecord = EntryExitRecord(
      id: _records.length + 1,
      vehicleId: data['vehicle_id'] ?? 0,
      vehiclePlate: data['vehicle_plate'] ?? '',
      vehicleModel: data['vehicle_model'] ?? '',
      driver: data['driver'],
      entryTime: data['entry_time'] ?? '',
      exitTime: data['exit_time'],
      gate: data['gate'] ?? 'Entrée',
      status: data['status'] ?? 'INSIDE',
      notes: data['notes'],
      isKnown: data['is_known'] ?? true,
    );

    setState(() { _records.insert(0, newRecord); });
    _saveCache(_records);

    if (_backendOffline) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrée ajoutée (hors-ligne)'), backgroundColor: Color(0xFF0F172A)));
      return;
    }

    try {
      await http.post(
        Uri.parse('$kApiBaseUrl/api/entry-exit'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 30));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrée enregistrée'), backgroundColor: Color(0xFF0F172A)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de l\'enregistrement'), backgroundColor: Colors.red,));
    }
  }

  void _showAddEntryDialog() {
    final plateCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final driverCtrl = TextEditingController();
    final entryCtrl = TextEditingController(text: DateTime.now().toString().substring(0, 16));
    final gateCtrl = TextEditingController(text: 'Entrée');
    String selectedStatus = 'INSIDE';
    bool isKnown = true;

    final knownModels = <String, String>{
      for (final v in kMockVehicles) v.plate: v.model,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Nouvelle entrée E/S', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: plateCtrl,
                  decoration: const InputDecoration(labelText: 'Véhicule (immatriculation)', hintText: 'e.g. NY-9904-TX', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder()),
                  textInputAction: TextInputAction.next,
                  onChanged: (v) {
                    final upper = v.trim().toUpperCase();
                    final model = knownModels[upper];
                    if (model != null && modelCtrl.text.isEmpty) {
                      modelCtrl.text = model;
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: 'Modèle', hintText: 'e.g. Tesla Semi v2.0', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder()),),
                const SizedBox(height: 14),
                TextField(controller: driverCtrl, decoration: const InputDecoration(labelText: 'Chauffeur', hintText: 'e.g. Marcus Reed', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder()),),
                const SizedBox(height: 14),
                TextField(controller: entryCtrl, decoration: const InputDecoration(labelText: "Date d'entrée", filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder()),),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Statut', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder()),
                  items: const [DropdownMenuItem(value: 'INSIDE', child: Text('À l\'intérieur')), DropdownMenuItem(value: 'OUTSIDE', child: Text('Sorti'))],
                  onChanged: (v) { if (v != null) setDialogState(() { selectedStatus = v; gateCtrl.text = v == 'INSIDE' ? 'Entrée' : 'Sortie'; }); },
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(children: [
                    Icon(isKnown ? Icons.check_circle : Icons.help_outline, size: 16, color: isKnown ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    const Text('Véhicule', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setDialogState(() { isKnown = !isKnown; }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isKnown ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isKnown ? 'Connu (site)' : 'Inconnu',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isKnown ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                if (plateCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Saisissez une immatriculation'), backgroundColor: Colors.orange));
                  return;
                }
                final now = DateTime.now().toString().substring(0, 16);
                _addEntry({
                  'vehicle_id': 0,
                  'vehicle_plate': plateCtrl.text.trim().toUpperCase(),
                  'vehicle_model': modelCtrl.text.trim().isEmpty ? 'Inconnu' : modelCtrl.text.trim(),
                  'driver': driverCtrl.text.trim().isEmpty ? null : driverCtrl.text.trim(),
                  'entry_time': entryCtrl.text.trim().isEmpty ? now : entryCtrl.text.trim(),
                  'exit_time': null,
                  'gate': gateCtrl.text.trim().isEmpty ? 'Entrée' : gateCtrl.text.trim(),
                  'status': selectedStatus,
                  'notes': null,
                  'is_known': isKnown,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Filtrer par statut'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(dense: true, title: const Text('Tous'), trailing: _filterStatus == null ? const Icon(Icons.check_circle, color: Color(0xFF0F172A)) : null, onTap: () { setState(() { _filterStatus = null; }); Navigator.pop(context); }),
          ListTile(dense: true, title: const Text('À l\'intérieur'), trailing: _filterStatus == 'INSIDE' ? const Icon(Icons.check_circle, color: Color(0xFF0F172A)) : null, onTap: () { setState(() { _filterStatus = 'INSIDE'; }); Navigator.pop(context); }),
          ListTile(dense: true, title: const Text('Sorti'), trailing: _filterStatus == 'OUTSIDE' ? const Icon(Icons.check_circle, color: Color(0xFF0F172A)) : null, onTap: () { setState(() { _filterStatus = 'OUTSIDE'; }); Navigator.pop(context); }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_backendOffline) _buildOfflineBanner(),
        _buildHeader(),
        const SizedBox(height: 16),
        _buildStatsRow(),
        const SizedBox(height: 16),
        _buildTable(),
      ]),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 16),
        const SizedBox(width: 10),
        const Expanded(child: Text('Backend hors ligne — données locales affichées.', style: TextStyle(color: Color(0xFF92400E), fontSize: 11))),
        TextButton(onPressed: _fetchRecords, child: const Text('Réessayer', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11))),
      ]),
    );
  }

  Widget _buildHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Historique Entrées / Sorties', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 2),
        Text('${_uniqueVehicles.length} véhicule(s) — $_uniqueInsideCount à l\'intérieur, $_uniqueOutsideCount sortis${_hideUnknown ? "" : " (incl. inconnus)"}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ]),
      Flexible(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildButton('Scanner plaque', Icons.qr_code_scanner, onTap: _openPlateScanner, isPrimary: true),
            const SizedBox(width: 10),
            _buildButton('Nouvelle entrée', Icons.add, onTap: _showAddEntryDialog),
            const SizedBox(width: 10),
            _buildButton('Filtrer', Icons.tune, onTap: _showFilterDialog),
            const SizedBox(width: 10),
            _buildButton(
              _hideUnknown ? 'Connus' : 'Tous',
              _hideUnknown ? Icons.visibility : Icons.visibility_off,
              onTap: () => setState(() => _hideUnknown = !_hideUnknown),
            ),
            const SizedBox(width: 10),
            _buildButton('Actualiser', Icons.refresh, onTap: _fetchRecords),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildStatsRow() {
    return Row(children: [
      _buildStatCard('À L\'INTÉRIEUR', _uniqueInsideCount.toString(), Icons.login, const Color(0xFF3B82F6)),
      const SizedBox(width: 16),
      _buildStatCard('SORTIS', _uniqueOutsideCount.toString(), Icons.logout, const Color(0xFF64748B)),
      const SizedBox(width: 16),
      _buildStatCard('TOTAL', _uniqueVehicles.length.toString(), Icons.swap_horiz, const Color(0xFF0F172A)),
    ]);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, {VoidCallback? onTap, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: isPrimary ? Colors.white : const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPrimary ? Colors.white : const Color(0xFF64748B))),
        ]),
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Registre E/S', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text('${_uniqueVehicles.length} véhicule(s) unique(s)${_filterStatus != null ? " · filtre: ${_filterStatus == "INSIDE" ? "À l\u2019intérieur" : "Sorti"}" : ""}${_hideUnknown ? "" : " · tous"}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 16),
        _buildTableHeader(),
        const Divider(color: Color(0xFFF1F5F9)),
        if (_isLoading)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (_uniqueVehicles.isEmpty)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucun enregistrement.', style: TextStyle(color: Color(0xFF94A3B8)))))
        else
          ..._uniqueVehicles.map((r) => Column(children: [_buildTableRow(r), const Divider(color: Color(0xFFF8FAFC), height: 1)]))
      ]),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(children: [
        Expanded(flex: 2, child: Text('VÉHICULE',    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        Expanded(flex: 2, child: Text('ENTRÉE',      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        Expanded(flex: 2, child: Text('SORTIE',      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        Expanded(flex: 1, child: Text('DURÉE',       style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        Expanded(flex: 1, child: Text('PORTE',       style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        SizedBox(width: 80, child: Text('STATUT',    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
      ]),
    );
  }

  void _showVehicleHistory(EntryExitRecord record) {
    final vehicleRecords = _records
        .where((r) => r.vehiclePlate == record.vehiclePlate)
        .toList()
      ..sort((a, b) => b.entryTime.compareTo(a.entryTime));

    final totalTrips = vehicleRecords.length;
    final completed = vehicleRecords.where((r) => r.exitTime != null).length;
    final totalDuration = completed > 0 ? vehicleRecords
        .where((r) => r.exitTime != null)
        .fold<Duration>(Duration.zero, (sum, r) {
          try {
            final fmt = RegExp(r'(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2})');
            final e = fmt.firstMatch(r.entryTime);
            final x = fmt.firstMatch(r.exitTime!);
            if (e != null && x != null) {
              return sum + DateTime.parse('${x.group(1)}T${x.group(2)}:00')
                  .difference(DateTime.parse('${e.group(1)}T${e.group(2)}:00'));
            }
          } catch (_) {}
          return sum;
        }) : Duration.zero;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.local_shipping, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(record.vehiclePlate, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('${record.vehicleModel} · ${record.driver ?? "Chauffeur inconnu"}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                    child: Text('$totalTrips trajet(s)', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _historyStat('Trajets', '$totalTrips', Icons.swap_horiz),
                      const SizedBox(width: 12),
                      _historyStat('Terminés', '$completed', Icons.check_circle),
                      const SizedBox(width: 12),
                      _historyStat('Durée totale', '${totalDuration.inHours}h ${totalDuration.inMinutes % 60}min', Icons.schedule),
                    ]),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onNavigate?.call(4, record.vehiclePlate, record.vehicleModel);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.timeline, size: 14, color: Color(0xFF3B82F6)),
                              SizedBox(width: 6),
                              Text('Trajectoire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onNavigate?.call(5, record.vehiclePlate, record.vehicleModel);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(8)),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.build, size: 14, color: Color(0xFF0369A1)),
                              SizedBox(width: 6),
                              Text('Maintenance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0369A1))),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    const Text('HISTORIQUE COMPLET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                    const SizedBox(height: 12),
                    if (vehicleRecords.isEmpty)
                      const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Aucun trajet enregistré.', style: TextStyle(color: Color(0xFF94A3B8))))),
                    ...vehicleRecords.map((r) => Column(children: [
                      _buildHistoryTimelineItem(r),
                      if (r.hasImage) _buildHistoryImage(r),
                    ])),
                  ]),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _historyStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ]),
      ),
    );
  }

  Widget _buildHistoryTimelineItem(EntryExitRecord r) {
    final isInside = r.status == 'INSIDE';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: isInside ? const Color(0xFF3B82F6) : const Color(0xFF64748B), shape: BoxShape.circle),
          ),
          Container(width: 2, height: 50, color: const Color(0xFFE2E8F0)),
        ]),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.gate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: isInside ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4)),
                child: Text(isInside ? 'En cours' : 'Terminé', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isInside ? const Color(0xFF3B82F6) : const Color(0xFF64748B))),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.login, size: 12, color: Color(0xFF3B82F6)),
              const SizedBox(width: 4),
              Text(r.entryTime, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              if (r.exitTime != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.logout, size: 12, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(r.exitTime!, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ]),
            const SizedBox(height: 2),
            Text('Durée: ${r.duration} · ${r.driver ?? "N/A"}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTableRow(EntryExitRecord r) {
    return GestureDetector(
      onTap: () => _showVehicleHistory(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(children: [
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(r.vehiclePlate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: r.isKnown ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(r.isKnown ? 'Connu' : '?', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: r.isKnown ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B))),
              ),
              if (r.hasImage) ...[
                const SizedBox(width: 4),
                Icon(Icons.image, size: 12, color: const Color(0xFF3B82F6)),
              ],
            ]),
            Text(r.vehicleModel, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
          ])),
          Expanded(flex: 2, child: Text(r.entryTime, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
          Expanded(flex: 2, child: Text(r.exitTime ?? '—', style: TextStyle(color: r.exitTime == null ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12))),
          Expanded(flex: 1, child: Text(r.duration, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onTap: () => _navigateToTrajectory(r.vehiclePlate, r.vehicleModel),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timeline, size: 10, color: Color(0xFF3B82F6)),
                  SizedBox(width: 3),
                  Text('Trajet', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF3B82F6))),
                ]),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: r.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(r.status == 'INSIDE' ? "À l'intérieur" : 'Sorti', style: TextStyle(color: r.statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHistoryImage(EntryExitRecord r) {
    return Padding(
      padding: const EdgeInsets.only(left: 26, bottom: 12),
      child: FutureBuilder<String?>(
        future: r.fetchImage(''),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done || snap.data == null) {
            return const SizedBox.shrink();
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              base64Decode(snap.data!),
              height: 80,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }

  void _navigateToTrajectory(String plate, String model) {
    widget.onNavigate?.call(4, plate, model);
  }
}

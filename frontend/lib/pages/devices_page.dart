import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../mock_data.dart';
import '../services/sync_service.dart';

// Conditional import: web QR scanner on web, stub on native
import '../widgets/qr_scanner_stub.dart' if (dart.library.html) '../widgets/web_qr_scanner.dart';
import 'dart:math' as math;

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class DeviceModel {
  final String id;
  final String model;
  String assignment;
  String lastConnection;
  final String statusColor;
  final String assignedVehicle;
  final String assignedSince;

  DeviceModel({
    required this.id,
    required this.model,
    required this.assignment,
    required this.lastConnection,
    required this.statusColor,
    this.assignedVehicle = '—',
    this.assignedSince = '—',
  });

  factory DeviceModel.fromJson(Map<String, dynamic> j) => DeviceModel(
        id: j['id'],
        model: j['model'],
        assignment: j['assignment'],
        lastConnection: j['last_connection'],
        statusColor: j['status_color'],
        assignedVehicle: j['assigned_vehicle'] ?? '—',
        assignedSince: j['assigned_since'] ?? '—',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'model': model,
        'assignment': assignment,
        'last_connection': lastConnection,
        'status_color': statusColor,
        'assigned_vehicle': assignedVehicle,
        'assigned_since': assignedSince,
      };
}



class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<DeviceModel> _devices = [];
  List<DeviceModel> _trashDevices = [];
  bool _showTrash = false;
  bool _isLoading = true;
  bool _isRegistering = false;
  bool _backendOffline = false;
  int _pendingSyncCount = 0;

  String? _filterAssignment;
  int _currentPage = 1;
  static const _pageSize = 5;

  // Form state
  final _idController = TextEditingController();
  String _selectedModel = 'Apex Tracker V3';
  String _selectedAssignment = 'UNASSIGNED';

  static const _modelOptions = ['Apex Tracker V3', 'Core Link Hub', 'Nano Sensor X1'];
  static const _assignmentOptions = ['ASSIGNED', 'UNASSIGNED', 'MAINTENANCE'];


  static List<DeviceModel> get _mockDevices => kMockDevices.map((md) => DeviceModel(
    id: md.id,
    model: md.model,
    assignment: md.assignment,
    lastConnection: md.lastConnection,
    statusColor: md.statusColor,
    assignedVehicle: md.assignedVehicle,
    assignedSince: md.assignedSince,
  )).toList();


  List<DeviceModel> get _filtered => _filterAssignment == null
      ? _devices
      : _devices.where((d) => d.assignment == _filterAssignment).toList();

  int get _totalPages => (_filtered.length / _pageSize).ceil().clamp(1, 999);

  List<DeviceModel> get _paged {
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return start < _filtered.length ? _filtered.sublist(start, end) : [];
  }

  int get _assignedCount    => _devices.where((d) => d.assignment == 'ASSIGNED').length;
  int get _unassignedCount  => _devices.where((d) => d.assignment == 'UNASSIGNED').length;
  int get _maintenanceCount => _devices.where((d) => d.assignment == 'MAINTENANCE').length;



  @override
  void initState() {
    super.initState();
    _loadDevicesFromLocal().then((_) {
      _fetchDevices();
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // API calls
  // ---------------------------------------------------------------------------

  Future<void> _fetchDevices() async {
    if (!mounted) return;
    // Only show loading spinner if we have no cached data yet
    if (_devices.isEmpty) {
      setState(() { _isLoading = true; _backendOffline = false; });
    }
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/devices'))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (json.decode(res.body) as List).map((e) => DeviceModel.fromJson(e)).toList();
        setState(() { _devices = list; _isLoading = false; _backendOffline = false; });
        await _saveDevicesLocally(list);
        // Sync pending operations now that backend is reachable
        await _syncPendingOperations();
      }
    } catch (_) {
      // Only show offline if we have no cached data at all
      if (_devices.isEmpty && mounted) {
        setState(() { _isLoading = false; _backendOffline = true; });
      }
    }
    // Update pending count
    _pendingSyncCount = await SyncService.getPendingCount();
    if (mounted) setState(() {});
  }

  Future<void> _syncPendingOperations() async {
    try {
      await SyncService.processPendingOperations(
        onCreateDevice: (data) async {
          final res = await http.post(
            Uri.parse('$kApiBaseUrl/api/devices'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          ).timeout(const Duration(seconds: 30));
          if (res.statusCode != 200) throw Exception('Failed to sync device creation');
        },
        onUpdateAssignment: (deviceId, assignment) async {
          final res = await http.put(
            Uri.parse('$kApiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'assignment': assignment}),
          ).timeout(const Duration(seconds: 30));
          if (res.statusCode != 200) throw Exception('Failed to sync assignment update');
        },
        onDeleteDevice: (deviceId) async {
          final res = await http
              .delete(Uri.parse('$kApiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}'))
              .timeout(const Duration(seconds: 30));
          if (res.statusCode != 200) throw Exception('Failed to sync device deletion');
        },
      );
      final pendingCount = await SyncService.getPendingCount();
      if (pendingCount == 0 && mounted) {
        _showSnack('All pending changes synced successfully!');
      } else if (mounted) {
        _showSnack('$pendingCount changes still pending sync.', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Sync failed: $e', isError: true);
    }
  }

  Future<void> _saveDevicesLocally(List<DeviceModel> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = devices.map((d) => d.toJson()).toList();
      await prefs.setString('cached_devices', json.encode(jsonList));
    } catch (_) {}
  }

  Future<void> _saveTrashLocally(List<DeviceModel> devices) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = devices.map((d) => d.toJson()).toList();
      await prefs.setString('cached_devices_trash', json.encode(jsonList));
    } catch (_) {}
  }

  Future<void> _loadDevicesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cached_devices');
      if (data != null) {
        final list = (json.decode(data) as List).map((e) => DeviceModel.fromJson(e)).toList();
        if (mounted) {
          setState(() { _devices = list; _isLoading = false; _backendOffline = true; });
        }
      }
      final trashData = prefs.getString('cached_devices_trash');
      if (trashData != null) {
        final trashList = (json.decode(trashData) as List).map((e) => DeviceModel.fromJson(e)).toList();
        if (mounted) {
          setState(() => _trashDevices = trashList);
        }
      }
      return;
    } catch (_) {}
    if (mounted) _fallbackToMock();
  }

  void _fallbackToMock() {
    setState(() {
      _devices = List.from(_mockDevices);
      _isLoading = false;
      _backendOffline = true;
    });
  }

  Future<void> _registerDevice() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      _showSnack('Please enter a Device ID.', isError: true);
      return;
    }
    if (_devices.any((d) => d.id == id)) {
      _showSnack('Device ID "$id" already exists.', isError: true);
      return;
    }

    setState(() => _isRegistering = true);
    final newDevice = DeviceModel(
      id: id,
      model: _selectedModel,
      assignment: _selectedAssignment,
      lastConnection: 'Just now',
      statusColor: _assignmentColor(_selectedAssignment),
    );

    if (_backendOffline) {
      // Queue for sync when backend comes back online
      await SyncService.addOperation(SyncOperationType.createDevice, newDevice.toJson());
      setState(() {
        _devices.add(newDevice);
        _idController.clear();
        _isRegistering = false;
      });
      await _saveDevicesLocally(_devices);
      _showSnack('Device registered locally (will sync when online).');
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/devices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newDevice.toJson()),
      ).timeout(const Duration(seconds: 30));
      if (!mounted) return;

      if (res.statusCode == 200) {
        _idController.clear();
        await _fetchDevices();
        _showSnack('Device "$id" registered successfully!');
      } else {
        final detail = json.decode(res.body)['detail'] ?? 'Unknown error';
        _showSnack('Registration failed: $detail', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      // Queue for sync when backend comes back online
      await SyncService.addOperation(SyncOperationType.createDevice, newDevice.toJson());
      setState(() {
        _devices.add(newDevice);
        _idController.clear();
        _backendOffline = true;
        _isRegistering = false;
      });
      await _saveDevicesLocally(_devices);
      _showSnack('Backend unreachable — device queued for sync.', isError: false);
      return;
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final deleted = _devices.firstWhere((d) => d.id == deviceId,
        orElse: () => DeviceModel(id: '', model: '', assignment: '', lastConnection: '', statusColor: ''));

    if (_backendOffline) {
      await SyncService.addOperation(SyncOperationType.deleteDevice, {'deviceId': deviceId});
      setState(() {
        _devices.removeWhere((d) => d.id == deviceId);
        _trashDevices.add(deleted);
      });
      await _saveDevicesLocally(_devices);
      await _saveTrashLocally(_trashDevices);
      _showSnack('Device "$deviceId" moved to trash (will sync when online).');
      return;
    }
    try {
      final res = await http
          .delete(Uri.parse('$kApiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}'))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _devices.removeWhere((d) => d.id == deviceId);
          _trashDevices.add(deleted);
        });
        await _saveDevicesLocally(_devices);
        await _saveTrashLocally(_trashDevices);
        _showSnack('Device "$deviceId" moved to trash.');
      } else {
        _showSnack('Delete failed.', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      await SyncService.addOperation(SyncOperationType.deleteDevice, {'deviceId': deviceId});
      setState(() {
        _devices.removeWhere((d) => d.id == deviceId);
        _trashDevices.add(deleted);
        _backendOffline = true;
      });
      await _saveDevicesLocally(_devices);
      await _saveTrashLocally(_trashDevices);
      _showSnack('Moved to trash locally (queued for sync).');
    }
  }

  Future<void> _fetchTrashDevices() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/devices/trash'))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (json.decode(res.body) as List).map((e) => DeviceModel.fromJson(e)).toList();
        setState(() => _trashDevices = list);
        await _saveTrashLocally(list);
      }
    } catch (_) {}
  }

  Future<void> _restoreDevice(String deviceId) async {
    try {
      final res = await http
          .post(Uri.parse('$kApiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}/restore'))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _trashDevices.removeWhere((d) => d.id == deviceId);
        });
        await _saveTrashLocally(_trashDevices);
        _showSnack('Device "$deviceId" restored.');
        _fetchDevices();
      } else {
        _showSnack('Restore failed.', isError: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Backend unreachable.', isError: true);
    }
  }

  Future<void> _updateAssignment(DeviceModel device, String newAssignment) async {
    final updated = DeviceModel(
      id: device.id,
      model: device.model,
      assignment: newAssignment,
      lastConnection: device.lastConnection,
      statusColor: _assignmentColor(newAssignment),
    );

    setState(() {
      final i = _devices.indexWhere((d) => d.id == device.id);
      if (i >= 0) _devices[i] = updated;
    });
    await _saveDevicesLocally(_devices);

    if (_backendOffline) {
      // Queue for sync when backend comes back online
      await SyncService.addOperation(SyncOperationType.updateAssignment, {
        'deviceId': device.id,
        'assignment': newAssignment,
      });
      _showSnack('Status updated locally (will sync when online).');
      return;
    }
    try {
      await http.put(
        Uri.parse('$kApiBaseUrl/api/devices/${Uri.encodeComponent(device.id)}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updated.toJson()),
      ).timeout(const Duration(seconds: 30));
    } catch (_) {
      if (mounted) {
        setState(() => _backendOffline = true);
        // Queue for sync when backend comes back online
        await SyncService.addOperation(SyncOperationType.updateAssignment, {
          'deviceId': device.id,
          'assignment': newAssignment,
        });
        _showSnack('Status updated locally (queued for sync).');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _assignmentColor(String assignment) {
    switch (assignment) {
      case 'ASSIGNED':    return '0xFF3B82F6';
      case 'MAINTENANCE': return '0xFFF59E0B';
      default:            return '0xFF64748B';
    }
  }

  Color _statusBadgeColor(String assignment) {
    switch (assignment) {
      case 'ASSIGNED':    return const Color(0xFF3B82F6);
      case 'MAINTENANCE': return const Color(0xFFF59E0B);
      default:            return const Color(0xFF64748B);
    }
  }

  Color _statusBadgeBg(String assignment) {
    switch (assignment) {
      case 'ASSIGNED':    return const Color(0xFFEFF6FF);
      case 'MAINTENANCE': return const Color(0xFFFFFBEB);
      default:            return const Color(0xFFF8FAFC);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0F172A),
      duration: const Duration(seconds: 3),
    ));
  }

  // ---------------------------------------------------------------------------
  // QR Scan Dialog
  // ---------------------------------------------------------------------------

  void _openQrScanDialog() {
    if (kIsWeb) {
      _openWebQrScanDialog();
    } else {
      _openMobileQrScanDialog();
    }
  }

  void _openMobileQrScanDialog() {
    final controller = MobileScannerController(
      autoStart: true,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    bool hasScanned = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: math.min(MediaQuery.of(context).size.width - 32, 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Camera viewfinder
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: controller,
                          overlayBuilder: (context, constraints) => CustomPaint(
                            size: constraints.biggest,
                            painter: _QrCornerPainter(),
                          ),
                          onDetect: (BarcodeCapture capture) {
                            if (hasScanned) return;
                            final barcode = capture.barcodes.firstOrNull;
                            if (barcode?.rawValue == null || barcode!.rawValue!.isEmpty) return;
                            final scannedId = barcode.rawValue!.trim().toUpperCase();
                            if (_devices.any((d) => d.id == scannedId)) {
                              hasScanned = true;
                              Navigator.of(dialogCtx).pop();
                              controller.dispose();
                              _showSnack('Le code "$scannedId" est déjà dans l\'inventaire.', isError: true);
                              return;
                            }
                            hasScanned = true;
                            Navigator.of(dialogCtx).pop();
                            controller.dispose();
                            // Auto-register device with scanned ID
                            _idController.text = scannedId;
                            _registerDevice();
                          },
                          errorBuilder: (context, error, child) {
                            return Center(
                              child: Text(
                                'Camera error: ${error.toString()}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Manual fallback input
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('OR ENTER ID MANUALLY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                      const SizedBox(height: 10),
                      TextField(
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. X-9941-ALPHA',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          prefixIcon: const Icon(Icons.qr_code, size: 18, color: Color(0xFF64748B)),
                        ),
                        onSubmitted: (value) {
                          final scannedId = value.trim().toUpperCase();
                          if (scannedId.isNotEmpty) {
                            if (_devices.any((d) => d.id == scannedId)) {
                              _showSnack('Le code "$scannedId" est déjà dans l\'inventaire.', isError: true);
                              return;
                            }
                            Navigator.pop(dialogCtx);
                            controller.dispose();
                            // Auto-register device with entered ID
                            _idController.text = scannedId;
                            _registerDevice();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.dispose();
                Navigator.pop(dialogCtx);
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ).then((_) {
      try {
        controller.dispose();
      } catch (_) {}
    });
  }

  void _openWebQrScanDialog() {
    bool hasScanned = false;
    bool cameraFailed = false;
    String? errorMessage;
    final manualCtrl = TextEditingController();

    void cleanup() {
      manualCtrl.dispose();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: math.min(MediaQuery.of(context).size.width - 32, 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: cameraFailed ? 180 : 360,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: cameraFailed
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off, color: Colors.red, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  errorMessage ?? 'Caméra non disponible',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    cameraFailed = false;
                                    errorMessage = null;
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                                  label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white38),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : WebQrScannerWidget(
                          onScan: (scannedId) {
                            if (hasScanned) return;
                            hasScanned = true;
                            // Vérifier si le device existe déjà
                            if (_devices.any((d) => d.id == scannedId)) {
                              cleanup();
                              Navigator.of(dialogCtx).pop();
                              _showSnack('Le code "$scannedId" est déjà dans l\'inventaire.', isError: true);
                              return;
                            }
                            cleanup();
                            Navigator.of(dialogCtx).pop();
                            _idController.text = scannedId;
                            _registerDevice();
                          },
                          onError: (msg) {
                            cameraFailed = true;
                            errorMessage = msg ?? 'Erreur caméra';
                            setDialogState(() {});
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('OU SAISIR MANUELLEMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: manualCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. X-9941-ALPHA',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          prefixIcon: const Icon(Icons.qr_code, size: 18, color: Color(0xFF64748B)),
                        ),
                        onSubmitted: (value) {
                          final scannedId = value.trim().toUpperCase();
                          if (scannedId.isNotEmpty) {
                            if (_devices.any((d) => d.id == scannedId)) {
                              cleanup();
                              Navigator.pop(dialogCtx);
                              _showSnack('Le code "$scannedId" est déjà dans l\'inventaire.', isError: true);
                              return;
                            }
                            cleanup();
                            Navigator.pop(dialogCtx);
                            _idController.text = scannedId;
                            _registerDevice();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cleanup();
                Navigator.pop(dialogCtx);
              },
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter dialog
  // ---------------------------------------------------------------------------

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Filter by Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filterTile('All', null),
            ..._assignmentOptions.map((o) => _filterTile(o, o)),
          ],
        ),
      ),
    );
  }

  Widget _filterTile(String label, String? value) {
    final selected = _filterAssignment == value;
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF0F172A)) : null,
      onTap: () {
        setState(() { _filterAssignment = value; _currentPage = 1; });
        Navigator.pop(context);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_backendOffline) _buildOfflineBanner(),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 1, child: _buildRegisterCard()),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: _buildMapCard()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildRegisterCard(),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: isMobile ? 280 : 380,
                      child: _buildMapCard(),
                    ),
                  ],
                );
              }
            },
          ),
          SizedBox(height: isMobile ? 16 : 32),
          _buildInventoryTable(isMobile),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline banner
  // ---------------------------------------------------------------------------

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _pendingSyncCount > 0
                  ? 'Backend offline — $_pendingSyncCount change(s) pending sync. Start server: python main.py'
                  : 'Backend server unreachable — running in offline mode with demo data. Start the server with: python main.py',
              style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _fetchDevices,
            child: const Text('Retry', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Register card
  // ---------------------------------------------------------------------------

  Widget _buildRegisterCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add New Device', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('Register a new tracking unit to your command grid.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 28),

          // Device ID
          const Text('DEVICE ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.0)),
          const SizedBox(height: 8),
          TextField(
            controller: _idController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'e.g. X-9941-ALPHA',
              hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Model
          const Text('MODEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.0)),
          const SizedBox(height: 8),
          _buildDropdown(_selectedModel, _modelOptions, (v) => setState(() => _selectedModel = v!)),
          const SizedBox(height: 16),

          // Assignment
          const Text('ASSIGNMENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1.0)),
          const SizedBox(height: 8),
          _buildDropdown(_selectedAssignment, _assignmentOptions, (v) => setState(() => _selectedAssignment = v!)),
          const SizedBox(height: 28),

          // Register button
          ElevatedButton(
            onPressed: _isRegistering ? null : _registerDevice,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              disabledBackgroundColor: const Color(0xFF475569),
            ),
            child: _isRegistering
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text('Register Device', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Divider
          Row(children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
          ]),
          const SizedBox(height: 20),

          // QR scan button
          OutlinedButton(
            onPressed: _openQrScanDialog,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.qr_code_scanner, size: 18, color: Color(0xFF0F172A)),
                SizedBox(width: 8),
                Text('Scan QR Code', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : (options.isEmpty ? null : options.first),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Map / stats card
  // ---------------------------------------------------------------------------

  Widget _buildMapCard() {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Decorative grid lines
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          // Top stats row
          Positioned(
            top: 24, left: 24, right: 24,
            child: Row(
              children: [
                _buildMapStatCard('ACTIVE', _assignedCount.toString(), Icons.sensors, const Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                _buildMapStatCard('MAINTENANCE', _maintenanceCount.toString(), Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                _buildMapStatCard('UNASSIGNED', _unassignedCount.toString(), Icons.sensors_off, const Color(0xFF64748B)),
              ],
            ),
          ),
          // Center label
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: 56, color: Colors.white.withValues(alpha: 0.12)),
                const SizedBox(height: 8),
                Text(
                  '${_devices.length} devices tracked globally',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                ),
              ],
            ),
          ),
          // Bottom refresh button
          Positioned(
            bottom: 20, right: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _fetchDevices,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text('Refresh', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inventory table
  // ---------------------------------------------------------------------------

  Widget _buildInventoryTable([bool isMobile = false]) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          isMobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Device Inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(
                      _showTrash
                          ? '${_trashDevices.length} deleted device${_trashDevices.length == 1 ? '' : 's'}'
                          : '${_filtered.length} device${_filtered.length == 1 ? '' : 's'}'
                              '${_filterAssignment != null ? ' · filtered: $_filterAssignment' : ''}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _buildTableButton(_showTrash ? 'Active' : 'Trash', _showTrash ? Icons.devices : Icons.delete_outline, onTap: () { setState(() => _showTrash = !_showTrash); if (_showTrash) _fetchTrashDevices(); }),
                      const SizedBox(width: 8),
                      _buildTableButton('Filter', Icons.tune, onTap: _openFilterDialog),
                      const SizedBox(width: 8),
                      _buildTableButton('Export CSV', Icons.download, onTap: _exportCsv),
                      const SizedBox(width: 8),
                      _buildTableButton('Refresh', Icons.refresh, onTap: _showTrash ? _fetchTrashDevices : _fetchDevices),
                    ]),
                  ),
                ])
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Device Inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text(
                        _showTrash
                            ? '${_trashDevices.length} deleted device${_trashDevices.length == 1 ? '' : 's'}'
                            : '${_filtered.length} device${_filtered.length == 1 ? '' : 's'}'
                                '${_filterAssignment != null ? ' · filtered: $_filterAssignment' : ''}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ]),
                    Row(children: [
                      _buildTableButton(_showTrash ? 'Active' : 'Trash', _showTrash ? Icons.devices : Icons.delete_outline, onTap: () { setState(() => _showTrash = !_showTrash); if (_showTrash) _fetchTrashDevices(); }),
                      const SizedBox(width: 12),
                      _buildTableButton('Filter', Icons.tune, onTap: _openFilterDialog),
                      const SizedBox(width: 12),
                      _buildTableButton('Export CSV', Icons.download, onTap: _exportCsv),
                      const SizedBox(width: 12),
                      _buildTableButton('Refresh', Icons.refresh, onTap: _showTrash ? _fetchTrashDevices : _fetchDevices),
                    ]),
                  ],
                ),
          const SizedBox(height: 24),

          isMobile
              ? Column(children: [
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (_showTrash && _trashDevices.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('Trash is empty.', style: TextStyle(color: Color(0xFF94A3B8)))))
                  else if (!_showTrash && _paged.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No devices found.', style: TextStyle(color: Color(0xFF94A3B8)))))
                  else if (_showTrash)
                    ..._trashDevices.map((d) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildMobileTrashCard(d)))
                  else
                    ..._paged.map((d) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildMobileDeviceCard(d))),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildTableHeader(),
                  const Divider(color: Color(0xFFF1F5F9)),
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (_showTrash && _trashDevices.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('Trash is empty.', style: TextStyle(color: Color(0xFF94A3B8)))))
                  else if (!_showTrash && _paged.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('No devices found.', style: TextStyle(color: Color(0xFF94A3B8)))))
                  else if (_showTrash)
                    ..._trashDevices.map((d) => Column(children: [_buildTrashRow(d), const Divider(color: Color(0xFFF8FAFC), height: 1)]))
                  else
                    ..._paged.map((d) => Column(children: [_buildTableRow(d), const Divider(color: Color(0xFFF8FAFC), height: 1)])),
                ]),

          const SizedBox(height: 20),

          // Pagination
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text('Page $_currentPage of $_totalPages  (${_filtered.length} total)', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _buildPageButton(Icons.chevron_left, isEnabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
                ...List.generate(_totalPages.clamp(0, 5), (i) => _buildPageNumber('${i + 1}', isSelected: _currentPage == i + 1, onTap: () => setState(() => _currentPage = i + 1))),
                _buildPageButton(Icons.chevron_right, isEnabled: _currentPage < _totalPages, onTap: () => setState(() => _currentPage++)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDeviceCard(DeviceModel d) {
    final badgeColor = _statusBadgeColor(d.assignment);
    final badgeBg = _statusBadgeBg(d.assignment);
    final isAssigned = d.assignment == 'ASSIGNED';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(d.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (action) => _handleDeviceAction(action, d),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'assign',      child: _PopupItem(Icons.link,              'Set ASSIGNED',    Color(0xFF3B82F6))),
              const PopupMenuItem(value: 'unassign',    child: _PopupItem(Icons.link_off,           'Set UNASSIGNED',  Color(0xFF64748B))),
              const PopupMenuItem(value: 'maintenance', child: _PopupItem(Icons.build,              'Set MAINTENANCE', Color(0xFFF59E0B))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete',      child: _PopupItem(Icons.delete_outline,     'Delete Device',   Colors.red)),
            ],
          ),
        ]),
        const SizedBox(height: 6),
        Text(d.model, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          if (isAssigned) ...[
            const Icon(Icons.directions_car, size: 13, color: Color(0xFF3B82F6)),
            const SizedBox(width: 4),
            Expanded(child: Text(d.assignedVehicle, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12), overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
          ] else ...[
            Expanded(child: Text(d.assignedVehicle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
            child: Text(d.assignment, style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.schedule, size: 12, color: Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(isAssigned ? d.assignedSince : '—', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildMobileTrashCard(DeviceModel d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444))),
          Text('${d.model} · ${d.assignedVehicle}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ])),
        IconButton(
          icon: const Icon(Icons.restore_from_trash, color: Color(0xFF3B82F6), size: 20),
          tooltip: 'Restore',
          onPressed: () => _restoreDevice(d.id),
        ),
      ]),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('DEVICE ID',        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          Expanded(flex: 1, child: Text('MODEL',            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          Expanded(flex: 2, child: Text('VEHICLE',          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          Expanded(flex: 2, child: Text('ASSIGNED SINCE',   style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          Expanded(flex: 1, child: Text('STATUS',           style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          SizedBox(width: 60,         child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        ],
      ),
    );
  }

  Widget _buildTableRow(DeviceModel d) {
    final badgeColor = _statusBadgeColor(d.assignment);
    final badgeBg    = _statusBadgeBg(d.assignment);
    final isAssigned = d.assignment == 'ASSIGNED';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          // ID
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(d.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)))),
              ],
            ),
          ),
          // Model
          Expanded(flex: 1, child: Text(d.model, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
          // Assigned vehicle
          Expanded(
            flex: 2,
            child: isAssigned
                ? Row(
                    children: [
                      const Icon(Icons.directions_car, size: 14, color: Color(0xFF3B82F6)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d.assignedVehicle, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w500))),
                    ],
                  )
                : Text(d.assignedVehicle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ),
          // Assigned since
          Expanded(
            flex: 2,
            child: isAssigned
                ? Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(d.assignedSince, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
                    ],
                  )
                : Text(d.assignedSince, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
          ),
          // Assignment badge (STATUS)
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(d.assignment, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 60,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (action) => _handleDeviceAction(action, d),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'assign',      child: _PopupItem(Icons.link,              'Set ASSIGNED',    Color(0xFF3B82F6))),
                const PopupMenuItem(value: 'unassign',    child: _PopupItem(Icons.link_off,           'Set UNASSIGNED',  Color(0xFF64748B))),
                const PopupMenuItem(value: 'maintenance', child: _PopupItem(Icons.build,              'Set MAINTENANCE', Color(0xFFF59E0B))),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete',      child: _PopupItem(Icons.delete_outline,     'Delete Device',   Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashRow(DeviceModel d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 14, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(child: Text(d.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444)))),
            ],
          )),
          Expanded(flex: 1, child: Text(d.model, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13))),
          Expanded(flex: 2, child: Text(d.assignedVehicle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
          Expanded(flex: 2, child: Text(d.assignedSince, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12))),
          Expanded(flex: 1, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(6)),
            child: const Text('DELETED', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
          )),
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.restore_from_trash, color: Color(0xFF3B82F6), size: 20),
              tooltip: 'Restore',
              onPressed: () => _restoreDevice(d.id),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDeviceAction(String action, DeviceModel d) {
    switch (action) {
      case 'assign':      _updateAssignment(d, 'ASSIGNED');    break;
      case 'unassign':    _updateAssignment(d, 'UNASSIGNED');  break;
      case 'maintenance': _updateAssignment(d, 'MAINTENANCE'); break;
      case 'delete':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: const Text('Delete Device'),
            content: Text('Are you sure you want to delete device "${d.id}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () { Navigator.pop(context); _deleteDevice(d.id); },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        break;
    }
  }

  void _exportCsv() {
    final rows = _devices.map((d) => '"${d.id}","${d.model}","${d.assignment}","${d.lastConnection}"').join('\n');
    final csv = 'Device ID,Model,Assignment,Last Connection\n$rows';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(children: [
          Icon(Icons.download_done_rounded, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('Export CSV'),
        ]),
        content: SizedBox(
          width: math.min(440, MediaQuery.of(context).size.width - 48), height: 220,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(child: SelectableText(csv, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared small widgets
  // ---------------------------------------------------------------------------

  Widget _buildTableButton(String label, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF64748B)),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPageButton(IconData icon, {bool isEnabled = true, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isEnabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: isEnabled ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Widget _buildPageNumber(String num, {bool isSelected = false, VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(num, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _PopupItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _PopupItem(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(color: color, fontSize: 13)),
  ]);
}

// QR corner bracket painter
class _QrCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    final w = size.width; final h = size.height;
    // Top-left
    canvas.drawLine(const Offset(0, len), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, len), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - len), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(len, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - len, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - len), paint);
  }
  @override bool shouldRepaint(_) => false;
}

// Decorative grid for the map card
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class DeviceModel {
  final String id;
  final String model;
  String assignment;
  String lastConnection;
  final String statusColor;

  DeviceModel({
    required this.id,
    required this.model,
    required this.assignment,
    required this.lastConnection,
    required this.statusColor,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> j) => DeviceModel(
        id: j['id'],
        model: j['model'],
        assignment: j['assignment'],
        lastConnection: j['last_connection'],
        statusColor: j['status_color'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'model': model,
        'assignment': assignment,
        'last_connection': lastConnection,
        'status_color': statusColor,
      };
}



class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<DeviceModel> _devices = [];
  bool _isLoading = true;
  bool _isRegistering = false;
  bool _backendOffline = false;

  String? _filterAssignment;
  int _currentPage = 1;
  static const _pageSize = 5;

  // Form state
  final _idController = TextEditingController();
  String _selectedModel = 'Apex Tracker V3';
  String _selectedAssignment = 'UNASSIGNED';

  static const _modelOptions = ['Apex Tracker V3', 'Core Link Hub', 'Nano Sensor X1'];
  static const _assignmentOptions = ['ASSIGNED', 'UNASSIGNED', 'MAINTENANCE'];


  static final List<DeviceModel> _mockDevices = [
    DeviceModel(id: 'X-9941-ALPHA', model: 'Apex Tracker V3',  assignment: 'ASSIGNED',    lastConnection: '2 mins ago',      statusColor: '0xFF3B82F6'),
    DeviceModel(id: 'X-8820-BETA',  model: 'Core Link Hub',    assignment: 'UNASSIGNED',  lastConnection: '14 hrs ago',      statusColor: '0xFF64748B'),
    DeviceModel(id: 'X-1011-DELTA', model: 'Apex Tracker V3',  assignment: 'MAINTENANCE', lastConnection: 'Offline (3 days)',statusColor: '0xFFF59E0B'),
    DeviceModel(id: 'X-9950-GAMMA', model: 'Core Link Hub',    assignment: 'ASSIGNED',    lastConnection: 'Just now',        statusColor: '0xFF3B82F6'),
  ];


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
    _fetchDevices();
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
    setState(() { _isLoading = true; _backendOffline = false; });
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/devices'))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (json.decode(res.body) as List).map((e) => DeviceModel.fromJson(e)).toList();
        setState(() { _devices = list; _isLoading = false; _backendOffline = false; });
      } else {
        _fallbackToMock();
      }
    } catch (_) {
      if (mounted) _fallbackToMock();
    }
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
    final now = DateTime.now();
    final newDevice = DeviceModel(
      id: id,
      model: _selectedModel,
      assignment: _selectedAssignment,
      lastConnection: 'Just now',
      statusColor: _assignmentColor(_selectedAssignment),
    );

    if (_backendOffline) {
      // Offline mode — update local list only
      setState(() {
        _devices.add(newDevice);
        _idController.clear();
        _isRegistering = false;
      });
      _showSnack('Device registered locally (offline mode).');
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/devices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(newDevice.toJson()),
      ).timeout(const Duration(seconds: 6));
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
      // Fall back to local add
      setState(() {
        _devices.add(newDevice);
        _idController.clear();
        _backendOffline = true;
      });
      _showSnack('Backend unreachable — device saved locally.', isError: false);
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    if (_backendOffline) {
      setState(() => _devices.removeWhere((d) => d.id == deviceId));
      _showSnack('Device "$deviceId" removed.');
      return;
    }
    try {
      final res = await http
          .delete(Uri.parse('$kApiBaseUrl/api/devices/${Uri.encodeComponent(deviceId)}'))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _devices.removeWhere((d) => d.id == deviceId));
        _showSnack('Device "$deviceId" deleted.');
      } else {
        _showSnack('Delete failed.', isError: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _devices.removeWhere((d) => d.id == deviceId);
        _backendOffline = true;
      });
      _showSnack('Deleted locally (backend unreachable).');
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

    if (_backendOffline) {
      _showSnack('Status updated locally (offline mode).');
      return;
    }
    try {
      await http.put(
        Uri.parse('$kApiBaseUrl/api/devices/${Uri.encodeComponent(device.id)}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(updated.toJson()),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {
      if (mounted) setState(() => _backendOffline = true);
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
    final qrController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QR viewfinder
              Container(
                height: 220,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Corner brackets
                      SizedBox(
                        width: 140, height: 140,
                        child: CustomPaint(painter: _QrCornerPainter()),
                      ),
                      // Scan line animation
                      const _ScanLineWidget(),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_2, size: 60, color: Colors.white24),
                          SizedBox(height: 8),
                          Text('Align QR code within frame', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
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
                      controller: qrController,
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final scannedId = qrController.text.trim().toUpperCase();
              Navigator.pop(ctx);
              if (scannedId.isNotEmpty) {
                setState(() => _idController.text = scannedId);
                _showSnack('QR scanned: $scannedId — review and click Register.');
              }
            },
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Use This ID'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline banner
          if (_backendOffline) _buildOfflineBanner(),
          // Top row: form + map
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: _buildRegisterCard()),
              const SizedBox(width: 32),
              Expanded(flex: 2, child: _buildMapCard()),
            ],
          ),
          const SizedBox(height: 32),
          _buildInventoryTable(),
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
          const Expanded(
            child: Text(
              'Backend server unreachable — running in offline mode with demo data. Start the server with: python main.py',
              style: TextStyle(color: Color(0xFF92400E), fontSize: 12),
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

  Widget _buildInventoryTable() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Device Inventory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(
                  '${_filtered.length} device${_filtered.length == 1 ? '' : 's'}'
                  '${_filterAssignment != null ? ' · filtered: $_filterAssignment' : ''}',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ]),
              Row(children: [
                _buildTableButton('Filter', Icons.tune, onTap: _openFilterDialog),
                const SizedBox(width: 12),
                _buildTableButton('Export CSV', Icons.download, onTap: _exportCsv),
                const SizedBox(width: 12),
                _buildTableButton('Refresh', Icons.refresh, onTap: _fetchDevices),
              ]),
            ],
          ),
          const SizedBox(height: 24),

          // Table header
          _buildTableHeader(),
          const Divider(color: Color(0xFFF1F5F9)),

          // Rows
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (_paged.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('No devices found.', style: TextStyle(color: Color(0xFF94A3B8)))),
            )
          else
            ..._paged.map((d) => Column(
                  children: [
                    _buildTableRow(d),
                    const Divider(color: Color(0xFFF8FAFC), height: 1),
                  ],
                )),

          const SizedBox(height: 20),

          // Pagination
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page $_currentPage of $_totalPages  (${_filtered.length} total)',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              Row(children: [
                _buildPageButton(Icons.chevron_left,
                    isEnabled: _currentPage > 1,
                    onTap: () => setState(() => _currentPage--)),
                ...List.generate(_totalPages.clamp(0, 5), (i) => _buildPageNumber(
                    '${i + 1}', isSelected: _currentPage == i + 1,
                    onTap: () => setState(() => _currentPage = i + 1))),
                _buildPageButton(Icons.chevron_right,
                    isEnabled: _currentPage < _totalPages,
                    onTap: () => setState(() => _currentPage++)),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('DEVICE ID',        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          Expanded(flex: 2, child: Text('MODEL',            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          Expanded(flex: 2, child: Text('ASSIGNMENT',       style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          Expanded(flex: 2, child: Text('LAST CONNECTION',  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
          SizedBox(width: 60,         child: Text('ACTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)))),
        ],
      ),
    );
  }

  Widget _buildTableRow(DeviceModel d) {
    final badgeColor = _statusBadgeColor(d.assignment);
    final badgeBg    = _statusBadgeBg(d.assignment);

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
          Expanded(flex: 2, child: Text(d.model, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
          // Assignment badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                child: Text(d.assignment, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          // Last connection
          Expanded(flex: 2, child: Text(d.lastConnection, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13))),
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
          width: 440, height: 220,
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
    canvas.drawLine(Offset(0, len), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(len, 0), paint);
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

// Animated scan line
class _ScanLineWidget extends StatefulWidget {
  const _ScanLineWidget();
  @override State<_ScanLineWidget> createState() => _ScanLineState();
}
class _ScanLineState extends State<_ScanLineWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        top: 20 + _anim.value * 100,
        left: 10, right: 10,
        child: Container(height: 2, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, const Color(0xFF3B82F6).withValues(alpha: 0.8), Colors.transparent]),
        )),
      ),
    );
  }
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
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class MaintenanceLog {
  final int id;
  final int vehicleId;
  final String date;
  final String type;
  final String title;
  final String description;
  final String? file;
  final String? mileage;

  const MaintenanceLog({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.type,
    required this.title,
    required this.description,
    this.file,
    this.mileage,
  });

  factory MaintenanceLog.fromJson(Map<String, dynamic> j) => MaintenanceLog(
        id: j['id'],
        vehicleId: j['vehicle_id'],
        date: j['date'],
        type: j['type'],
        title: j['title'],
        description: j['description'],
        file: j['file'],
        mileage: j['mileage'],
      );
}

class ReplacementPart {
  final int id;
  final String name;
  final String partNumber;
  final String status; // IN_STOCK, LOW_STOCK, ORDER_NOW
  final int quantity;
  final String lastReplaced;
  final String nextReplacement;

  const ReplacementPart({
    required this.id,
    required this.name,
    required this.partNumber,
    required this.status,
    required this.quantity,
    required this.lastReplaced,
    required this.nextReplacement,
  });

  factory ReplacementPart.fromJson(Map<String, dynamic> j) => ReplacementPart(
        id: j['id'],
        name: j['name'],
        partNumber: j['part_number'],
        status: j['status'],
        quantity: j['quantity'],
        lastReplaced: j['last_replaced'],
        nextReplacement: j['next_replacement'],
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({super.key});

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  // ─── State ───────────────────────────────────────────────────────────────
  int _selectedVehicleId = 1;
  int _selectedTab = 0;
  bool _isLoading = true;
  bool _isScanning = false;
  bool _backendOffline = false;

  List<Map<String, dynamic>> _vehicles = [];
  List<MaintenanceLog> _logs = [];
  Map<String, dynamic> _diagnostics = {};
  List<ReplacementPart> _parts = [];

  // ─── Mock fallback data ──────────────────────────────────────────────────
  static const _mockVehicles = [
    {'id': 1, 'model': 'Tesla Model X', 'plate': 'BT-904-TX', 'status': 'ACTIVE'},
    {'id': 2, 'model': 'Mercedes Sprinter', 'plate': 'CA-123-VN', 'status': 'MAINTENANCE'},
    {'id': 3, 'model': 'Ford Transit XL', 'plate': 'TX-4409-LP', 'status': 'IDLE'},
  ];

  // High-quality vehicle images per ID (Unsplash CDN)
  static const _vehicleImages = {
    1: 'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&q=80&w=600', // Tesla SUV sleek
    2: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?auto=format&fit=crop&q=80&w=600', // Mercedes white van
    3: 'https://images.unsplash.com/photo-1519003722824-194d4455a60c?auto=format&fit=crop&q=80&w=600', // Ford transit highway
  };

  static final _mockLogsByVehicle = <int, List<MaintenanceLog>>{
    1: [
      const MaintenanceLog(id: 1, vehicleId: 1, date: 'OCT 12, 2023', type: 'ROUTINE', title: 'Level 2 Service: Transmission Flush & Filtration', description: 'System pressure normalized. Minor wear detected on coupling. Fluid analyzed: Optimal.', file: 'Service_Report_A402.pdf', mileage: '11,200 mi'),
      const MaintenanceLog(id: 2, vehicleId: 1, date: 'AUG 29, 2023', type: 'REPAIR', title: 'Sensor Array Calibration (OBD Code P0121)', description: 'Replaced primary oxygen sensor in block 1. Cleared OBD system fault codes.', mileage: '9,840 mi'),
      const MaintenanceLog(id: 3, vehicleId: 1, date: 'JUN 14, 2023', type: 'INSPECTION', title: 'Annual Safety Inspection', description: 'All safety systems passed. Minor brake wear noted for monitoring.', mileage: '8,120 mi'),
    ],
    2: [
      const MaintenanceLog(id: 4, vehicleId: 2, date: 'NOV 01, 2023', type: 'REPAIR', title: 'Engine Overhaul — Cylinder Head Replacement', description: 'Severe overheating detected. Replaced cylinder head and gaskets. Full coolant flush performed.', mileage: '62,300 mi'),
      const MaintenanceLog(id: 5, vehicleId: 2, date: 'SEP 05, 2023', type: 'ROUTINE', title: 'Oil & Filter Change', description: 'Full synthetic 5W-30 replaced. Air filter inspected and cleared.', mileage: '59,800 mi'),
    ],
    3: [
      const MaintenanceLog(id: 6, vehicleId: 3, date: 'SEP 20, 2023', type: 'ROUTINE', title: 'Oil & Filter Change', description: 'Full synthetic 5W-30 oil replaced. Air filter inspected and cleared.', mileage: '44,900 mi'),
    ],
  };

  static final _mockDiagnosticsByVehicle = <int, Map<String, dynamic>>{
    1: {
      'battery_health': 94, 'next_service_days': 12, 'next_service_type': 'Brake Fluid Replacement',
      'fuel_consumption': 18.4, 'brake_pad_life': 42, 'coolant_temp': 102,
      'thermostat_temp': '194°', 'thermostat_trend': '+0.2% Stability',
      'thermostat_spots': [3.0, 2.0, 4.0, 3.0, 5.0, 3.0],
      'dtc_codes': [
        {'code': 'P0420', 'description': 'Catalyst Efficiency Below Threshold', 'detected': '4h ago', 'location': 'Block 1', 'severity': 'WARNING'},
      ],
      'predictive': {'probability': 82, 'component': 'fuel pump', 'miles_remaining': 450},
    },
    2: {
      'battery_health': 61, 'next_service_days': 2, 'next_service_type': 'Engine Inspection',
      'fuel_consumption': 22.1, 'brake_pad_life': 15, 'coolant_temp': 118,
      'thermostat_temp': '212°', 'thermostat_trend': '+1.8% Rising',
      'thermostat_spots': [4.0, 5.0, 5.5, 6.0, 6.5, 7.0],
      'dtc_codes': [
        {'code': 'P0300', 'description': 'Random/Multiple Cylinder Misfire', 'detected': '2h ago', 'location': 'All Cylinders', 'severity': 'CRITICAL'},
        {'code': 'P0115', 'description': 'Engine Coolant Temperature Sensor Circuit', 'detected': '5h ago', 'location': 'ECU', 'severity': 'WARNING'},
      ],
      'predictive': {'probability': 94, 'component': 'engine cooling system', 'miles_remaining': 120},
    },
    3: {
      'battery_health': 88, 'next_service_days': 45, 'next_service_type': 'Tire Rotation',
      'fuel_consumption': 16.2, 'brake_pad_life': 71, 'coolant_temp': 95,
      'thermostat_temp': '188°', 'thermostat_trend': '-0.1% Stable',
      'thermostat_spots': [3.2, 3.0, 3.1, 2.9, 3.0, 2.8],
      'dtc_codes': [],
      'predictive': {'probability': 31, 'component': 'transmission', 'miles_remaining': 2100},
    },
  };

  static final _mockPartsByVehicle = <int, List<ReplacementPart>>{
    1: [
      const ReplacementPart(id: 1, name: 'Brake Pads (Front)', partNumber: 'BP-2023-F', status: 'LOW_STOCK', quantity: 2, lastReplaced: 'JAN 2023', nextReplacement: 'DEC 2023'),
      const ReplacementPart(id: 2, name: 'Engine Air Filter', partNumber: 'AF-1102-X', status: 'IN_STOCK', quantity: 5, lastReplaced: 'MAR 2023', nextReplacement: 'MAR 2024'),
      const ReplacementPart(id: 3, name: 'Transmission Fluid', partNumber: 'TF-884-SYN', status: 'ORDER_NOW', quantity: 0, lastReplaced: 'OCT 2022', nextReplacement: 'OCT 2023'),
      const ReplacementPart(id: 4, name: 'Spark Plugs (Set)', partNumber: 'SP-440-NGK', status: 'IN_STOCK', quantity: 8, lastReplaced: 'JUN 2023', nextReplacement: 'JUN 2025'),
    ],
    2: [
      const ReplacementPart(id: 5, name: 'Cylinder Head Gasket', partNumber: 'CHG-221-MB', status: 'ORDER_NOW', quantity: 0, lastReplaced: 'NOV 2023', nextReplacement: 'NOV 2026'),
      const ReplacementPart(id: 6, name: 'Coolant (5L)', partNumber: 'CL-442-GRN', status: 'LOW_STOCK', quantity: 1, lastReplaced: 'NOV 2023', nextReplacement: 'NOV 2024'),
    ],
    3: [
      const ReplacementPart(id: 7, name: 'Engine Oil (5W-30)', partNumber: 'OIL-5W30-5L', status: 'IN_STOCK', quantity: 10, lastReplaced: 'SEP 2023', nextReplacement: 'MAR 2024'),
      const ReplacementPart(id: 8, name: 'Wiper Blades', partNumber: 'WB-224-FRD', status: 'IN_STOCK', quantity: 4, lastReplaced: 'JUL 2023', nextReplacement: 'JUL 2024'),
    ],
  };

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ─── API ─────────────────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([_fetchVehicles(), _fetchVehicleData()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchVehicles() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/vehicles'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _vehicles = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        _backendOffline = false;
        return;
      }
    } catch (_) {}
    _vehicles = _mockVehicles.map((e) => Map<String, dynamic>.from(e)).toList();
    _backendOffline = true;
  }

  Future<void> _fetchVehicleData() async {
    await Future.wait([_fetchLogs(), _fetchDiagnostics(), _fetchParts()]);
  }

  Future<void> _fetchLogs() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/maintenance/$_selectedVehicleId/logs'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _logs = (jsonDecode(res.body) as List).map((e) => MaintenanceLog.fromJson(e)).toList();
        return;
      }
    } catch (_) {}
    _logs = List.from(_mockLogsByVehicle[_selectedVehicleId] ?? []);
  }

  Future<void> _fetchDiagnostics() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/maintenance/$_selectedVehicleId/diagnostics'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _diagnostics = jsonDecode(res.body) as Map<String, dynamic>;
        return;
      }
    } catch (_) {}
    _diagnostics = Map.from(_mockDiagnosticsByVehicle[_selectedVehicleId] ?? _mockDiagnosticsByVehicle[1]!);
  }

  Future<void> _fetchParts() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/maintenance/$_selectedVehicleId/parts'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        _parts = (jsonDecode(res.body) as List).map((e) => ReplacementPart.fromJson(e)).toList();
        return;
      }
    } catch (_) {}
    _parts = List.from(_mockPartsByVehicle[_selectedVehicleId] ?? []);
  }

  Future<void> _onVehicleChanged(int vehicleId) async {
    setState(() {
      _selectedVehicleId = vehicleId;
      _isLoading = true;
    });
    await _fetchVehicleData();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addLog(Map<String, dynamic> data) async {
    try {
      final res = await http
          .post(
            Uri.parse('$kApiBaseUrl/api/maintenance/$_selectedVehicleId/logs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchLogs();
        return;
      }
    } catch (_) {}
    // Offline: add locally
    final newLog = MaintenanceLog(
      id: DateTime.now().millisecondsSinceEpoch,
      vehicleId: _selectedVehicleId,
      date: data['date'],
      type: data['type'],
      title: data['title'],
      description: data['description'],
      mileage: data['mileage'],
    );
    if (mounted) setState(() => _logs.insert(0, newLog));
  }

  Future<List<Map<String, dynamic>>> _runScan() async {
    await Future.delayed(const Duration(seconds: 2));
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/maintenance/$_selectedVehicleId/diagnostics'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) setState(() => _diagnostics = data);
        return List<Map<String, dynamic>>.from(data['dtc_codes'] ?? []);
      }
    } catch (_) {}
    return List<Map<String, dynamic>>.from(_diagnostics['dtc_codes'] ?? []);
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  Map<String, dynamic> get _currentVehicle => _vehicles.firstWhere(
        (v) => v['id'] == _selectedVehicleId,
        orElse: () => Map<String, dynamic>.from(_mockVehicles.first),
      );

  String _formatNow() {
    final now = DateTime.now();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':      return const Color(0xFF3B82F6);
      case 'MAINTENANCE': return const Color(0xFFF59E0B);
      case 'IDLE':        return const Color(0xFF64748B);
      default:            return const Color(0xFF3B82F6);
    }
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────
  void _showAddLogDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final mileageCtrl = TextEditingController();
    String logType = 'ROUTINE';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('Add Maintenance Log', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 500,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: logType,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: ['ROUTINE', 'REPAIR', 'INSPECTION']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setDs(() => logType = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mileageCtrl,
                  decoration: const InputDecoration(labelText: 'Mileage (optional)', border: OutlineInputBorder()),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                await _addLog({
                  'type': logType,
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'mileage': mileageCtrl.text.trim().isEmpty ? null : mileageCtrl.text.trim(),
                  'date': _formatNow(),
                });
                if (mounted) setState(() {});
              },
              child: const Text('Save Log'),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanResultsDialog(List<Map<String, dynamic>> codes) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.radar, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Text('Full System Scan — Results', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: 520,
          child: codes.isEmpty
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 12),
                  Text('No fault codes detected.', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('All systems operating within normal parameters.', style: GoogleFonts.inter(color: Colors.grey)),
                ])
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${codes.length} code(s) detected:', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ...codes.map((c) => _buildDTCRow(c)),
                ]),
        ),
        actions: [
          if (codes.isNotEmpty)
            ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Schedule Repair'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
                _showScheduleDialog();
              },
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showScheduleDialog() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 3));
    String priority = 'NORMAL';
    final notesCtrl = TextEditingController();
    final pred = _diagnostics['predictive'] as Map? ?? {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('Schedule Preemptive Fix', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.psychology, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AI predicts ${pred['probability'] ?? 82}% probability of ${pred['component'] ?? 'component'} issues within ${pred['miles_remaining'] ?? 450} miles.',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Color(0xFF3B82F6)),
                title: Text('Appointment Date', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: GoogleFonts.inter(fontSize: 13)),
                trailing: TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setDs(() => selectedDate = picked);
                  },
                  child: const Text('Change'),
                ),
              ),
              const Divider(),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                items: ['URGENT', 'HIGH', 'NORMAL', 'LOW']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setDs(() => priority = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Confirm Schedule'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Fix scheduled for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year} [$priority]'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderPartsDialog() {
    final urgent = _parts.where((p) => p.status == 'ORDER_NOW' || p.status == 'LOW_STOCK').toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Order Parts', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          child: urgent.isEmpty
              ? Text('All parts are well stocked.', style: GoogleFonts.inter())
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('The following parts need attention:', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  ...urgent.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(p.partNumber, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11)),
                      ])),
                      _buildPartStatusBadge(p.status),
                    ]),
                  )),
                ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Parts order submitted successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ));
            },
            child: const Text('Submit Order'),
          ),
        ],
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_backendOffline) _buildOfflineBanner(),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildTabBar(),
                  const SizedBox(height: 24),
                  _buildTabContent(),
                  const SizedBox(height: 24),
                  _buildPredictiveBanner(),
                ],
              ),
            ),
    );
  }

  // ─── Offline banner ──────────────────────────────────────────────────────
  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 16),
        const SizedBox(width: 8),
        Text('Backend offline — showing cached data', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(onPressed: _loadAll, child: Text('Retry', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF59E0B)))),
      ]),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final v = _currentVehicle;
    final diag = _diagnostics;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(children: [
        // ── Vehicle image — dynamic per selected vehicle ───────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Image.network(
                  _vehicleImages[_selectedVehicleId] ??
                      'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&q=80&w=600',
                  key: ValueKey(_selectedVehicleId),
                  width: 200, height: 130, fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          width: 200, height: 130,
                          color: const Color(0xFFF1F5F9),
                          child: const Center(
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
                            ),
                          ),
                        ),
                  errorBuilder: (_, __, ___) => Container(
                    width: 200, height: 130,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.directions_car, size: 48, color: Colors.grey),
                  ),
                ),
              ),
              // Bottom gradient overlay with plate number
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    v['plate'] as String? ?? '',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButton<int>(
            value: _selectedVehicleId,
            underline: const SizedBox(),
            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            items: _vehicles.map((vehicle) => DropdownMenuItem<int>(
              value: vehicle['id'] as int,
              child: Text(
                '${vehicle['model']} — ${vehicle['plate']}',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            )).toList(),
            onChanged: (id) { if (id != null) _onVehicleChanged(id); },
          ),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(v['status'] as String? ?? 'ACTIVE', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _buildStatusBadge(v['status'] as String? ?? 'ACTIVE', _statusColor(v['status'] as String? ?? 'ACTIVE')),
            const SizedBox(width: 12),
            Text('${_logs.length} Maintenance Record(s)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF64748B))),
          ]),
        ])),
        _buildHeaderStatCard('BATTERY HEALTH', '${diag['battery_health'] ?? 94}%', null),
        const SizedBox(width: 16),
        _buildHeaderStatCard('NEXT SERVICE', '${diag['next_service_days'] ?? 12} Days', diag['next_service_type']?.toString(), isWarning: true),
        const SizedBox(width: 16),
        IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF64748B)), tooltip: 'Refresh', onPressed: _loadAll),
      ]),
    );
  }

  Widget _buildHeaderStatCard(String label, String value, String? subtext, {bool isWarning = false}) {
    return Container(
      width: 160, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: isWarning ? const Color(0xFFF59E0B) : const Color(0xFF0F172A))),
        if (subtext != null && subtext.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(subtext, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
        ],
      ]),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ─── Tab bar ─────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    const tabs = ['Maintenance History', 'OBD Data & Diagnostics', 'Replacement Parts'];
    return Row(
      children: List.generate(tabs.length, (i) => GestureDetector(
        onTap: () => setState(() => _selectedTab = i),
        child: Container(
          margin: const EdgeInsets.only(right: 32),
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: _selectedTab == i ? const Color(0xFF3B82F6) : Colors.transparent,
              width: 2,
            )),
          ),
          child: Text(tabs[i], style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: _selectedTab == i ? FontWeight.bold : FontWeight.w500,
            color: _selectedTab == i ? const Color(0xFF0F172A) : Colors.grey,
          )),
        ),
      )),
    );
  }

  // ─── Tab content ─────────────────────────────────────────────────────────
  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:  return _buildHistoryTab();
      case 1:  return _buildDiagnosticsTab();
      case 2:  return _buildPartsTab();
      default: return _buildHistoryTab();
    }
  }

  // ─── Tab 0: Maintenance History ───────────────────────────────────────────
  Widget _buildHistoryTab() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 2, child: _buildServiceTimeline()),
      const SizedBox(width: 24),
      Expanded(flex: 3, child: _buildDiagnosticsGrid()),
    ]);
  }

  Widget _buildServiceTimeline() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Service Timeline', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton.icon(
          onPressed: _showAddLogDialog,
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add Log', style: GoogleFonts.inter(fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 16),
      if (_logs.isEmpty)
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Center(child: Column(children: [
            const Icon(Icons.history, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text('No maintenance records yet', style: GoogleFonts.inter(color: Colors.grey)),
          ])),
        )
      else
        ...List.generate(_logs.length, (i) => _buildTimelineItem(
          log: _logs[i],
          isLast: i == _logs.length - 1,
        )),
    ]);
  }

  Widget _buildTimelineItem({required MaintenanceLog log, bool isLast = false}) {
    final typeColors = {
      'ROUTINE':    const Color(0xFF3B82F6),
      'REPAIR':     const Color(0xFFF59E0B),
      'INSPECTION': const Color(0xFF10B981),
    };
    final typeColor = typeColors[log.type] ?? const Color(0xFF3B82F6);
    return IntrinsicHeight(
      child: Row(children: [
        Column(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
          if (!isLast) Expanded(child: Container(width: 2, color: const Color(0xFFE2E8F0))),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(log.date, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              Row(children: [
                if (log.mileage != null) ...[
                  const Icon(Icons.speed, size: 10, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(log.mileage!, style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(log.type, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: typeColor)),
                ),
              ]),
            ]),
            const SizedBox(height: 12),
            Text(log.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Text(log.description, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.5)),
            if (log.file != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening ${log.file}…'), duration: const Duration(seconds: 2)),
                ),
                child: Row(children: [
                  const Icon(Icons.picture_as_pdf, size: 14, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 6),
                  Text(log.file!, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF3B82F6), decoration: TextDecoration.underline)),
                ]),
              ),
            ],
          ]),
        )),
      ]),
    );
  }

  // ─── Tab 0 right panel: diagnostics overview ─────────────────────────────
  Widget _buildDiagnosticsGrid() {
    final diag = _diagnostics;
    final codes = (diag['dtc_codes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final spots = _toSpots(diag['thermostat_spots']);
    return Column(children: [
      Row(children: [
        Expanded(child: _buildEfficiencyCard(
          temp: diag['thermostat_temp'] as String? ?? '194°',
          trend: diag['thermostat_trend'] as String? ?? '+0.2% Stability',
          spots: spots,
        )),
        const SizedBox(width: 24),
        Expanded(child: _buildDTCCard(codes: codes)),
      ]),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: _buildSmallStatCard('FUEL CONSUMPTION', '${diag['fuel_consumption'] ?? 18.4}', 'mpg', trend: '-4.2%', showProgress: true, progressFactor: 0.6)),
        const SizedBox(width: 16),
        Expanded(child: _buildSmallStatCard('BRAKE PAD LIFE', '${diag['brake_pad_life'] ?? 42}', '%',
          isWarning: (diag['brake_pad_life'] as num? ?? 100) < 50,
          showProgress: true,
          progressFactor: (diag['brake_pad_life'] as num? ?? 42) / 100,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildSmallStatCard('COOLANT TEMP', '${diag['coolant_temp'] ?? 102}', '°C',
          status: (diag['coolant_temp'] as num? ?? 100) > 110 ? 'HIGH' : 'Nominal',
        )),
      ]),
    ]);
  }

  List<FlSpot> _toSpots(dynamic raw) {
    if (raw is List) {
      return raw.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value as num).toDouble())).toList();
    }
    return const [FlSpot(0, 3), FlSpot(1, 2), FlSpot(2, 4), FlSpot(3, 3), FlSpot(4, 5), FlSpot(5, 3)];
  }

  Widget _buildEfficiencyCard({required String temp, required String trend, required List<FlSpot> spots}) {
    return Container(
      height: 220, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Engine Thermostat', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('Efficiency', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('Last 30 Days Variance', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
          ]),
          const Icon(Icons.thermostat, color: Colors.blue, size: 20),
        ]),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(temp, style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(trend, style: GoogleFonts.inter(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 60, child: LineChart(LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true, color: Colors.blue, barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.1)),
          )],
        ))),
      ]),
    );
  }

  Widget _buildDTCCard({required List<Map<String, dynamic>> codes}) {
    return Container(
      height: 220, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Active DTC\nCodes', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
            child: Text('LIVE DIAGNOSTIC', style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
        const Spacer(),
        codes.isEmpty
            ? Center(child: Text('No active codes ✓', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12)))
            : Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(codes.first['code'] ?? '', style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(codes.first['description'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('${codes.first['detected'] ?? ''} · ${codes.first['location'] ?? ''}', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey)),
                  ])),
                  if (codes.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
                      child: Text('+${codes.length - 1}', style: GoogleFonts.inter(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  else
                    const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                ]),
              ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isScanning ? null : () async {
              setState(() => _isScanning = true);
              final results = await _runScan();
              if (mounted) {
                setState(() => _isScanning = false);
                _showScanResultsDialog(results);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isScanning
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('RUN FULL SYSTEM SCAN', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _buildSmallStatCard(String label, String value, String unit, {String? trend, bool isWarning = false, String? status, bool showProgress = false, double progressFactor = 0.6}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(unit, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
          const Spacer(),
          if (trend != null) Text(trend, style: GoogleFonts.inter(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
          if (status != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: status == 'HIGH' ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status, style: GoogleFonts.inter(fontSize: 8, color: status == 'HIGH' ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
          ),
        ]),
        if (showProgress) ...[
          const SizedBox(height: 12),
          Container(
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(2)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressFactor.clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(
                color: isWarning ? const Color(0xFFF59E0B) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(2),
              )),
            ),
          ),
        ],
      ]),
    );
  }

  // ─── Tab 1: OBD Data & Diagnostics ───────────────────────────────────────
  Widget _buildDiagnosticsTab() {
    final diag = _diagnostics;
    final codes = (diag['dtc_codes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final spots = _toSpots(diag['thermostat_spots']);

    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _buildEfficiencyCard(
          temp: diag['thermostat_temp'] as String? ?? '194°',
          trend: diag['thermostat_trend'] as String? ?? '+0.2% Stability',
          spots: spots,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildSmallStatCard('FUEL CONSUMPTION', '${diag['fuel_consumption'] ?? 18.4}', 'mpg', trend: '-4.2%', showProgress: true, progressFactor: 0.6)),
        const SizedBox(width: 16),
        Expanded(child: _buildSmallStatCard('BRAKE PAD LIFE', '${diag['brake_pad_life'] ?? 42}', '%',
          isWarning: (diag['brake_pad_life'] as num? ?? 100) < 50,
          showProgress: true,
          progressFactor: (diag['brake_pad_life'] as num? ?? 42) / 100,
        )),
        const SizedBox(width: 16),
        Expanded(child: _buildSmallStatCard('COOLANT TEMP', '${diag['coolant_temp'] ?? 102}', '°C',
          status: (diag['coolant_temp'] as num? ?? 100) > 110 ? 'HIGH' : 'Nominal',
        )),
      ]),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Diagnostic Trouble Codes (DTC)', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(4)),
                child: Text('LIVE', style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: _isScanning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.radar, size: 16),
                label: Text(_isScanning ? 'Scanning…' : 'Run Full Scan', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isScanning ? null : () async {
                  setState(() => _isScanning = true);
                  final results = await _runScan();
                  if (mounted) {
                    setState(() => _isScanning = false);
                    _showScanResultsDialog(results);
                  }
                },
              ),
            ]),
          ]),
          const SizedBox(height: 16),
          codes.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 40),
                    const SizedBox(height: 8),
                    Text('No active fault codes', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.w600)),
                  ]),
                ))
              : Column(children: codes.map((c) => _buildDTCRow(c)).toList()),
        ]),
      ),
    ]);
  }

  Widget _buildDTCRow(Map<String, dynamic> c) {
    final isCritical = c['severity'] == 'CRITICAL';
    final color = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
          child: Text(c['code'] ?? '', style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['description'] ?? '', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
          Text('${c['detected'] ?? ''} · ${c['location'] ?? ''}', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: Text(c['severity'] ?? '', style: GoogleFonts.inter(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ─── Tab 2: Replacement Parts ─────────────────────────────────────────────
  Widget _buildPartsTab() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Replacement Parts Inventory', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text('Order Parts'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: _showOrderPartsDialog,
            ),
          ]),
        ),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1),
            4: FlexColumnWidth(2),
            5: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
              children: ['PART NAME', 'PART NUMBER', 'STATUS', 'QTY', 'LAST REPLACED', 'NEXT DUE'].map((h) =>
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(h, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ).toList(),
            ),
            ..._parts.map((p) => TableRow(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(p.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(p.partNumber, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: _buildPartStatusBadge(p.status)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text('${p.quantity}', style: GoogleFonts.inter(fontSize: 13))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(p.lastReplaced, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(p.nextReplacement, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            )),
            if (_parts.isEmpty)
              TableRow(children: List.filled(6, Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No parts data available', style: GoogleFonts.inter(color: Colors.grey)),
              ))),
          ],
        ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildPartStatusBadge(String status) {
    final cfg = {
      'IN_STOCK':  [Colors.green,              'IN STOCK'],
      'LOW_STOCK': [const Color(0xFFF59E0B),   'LOW STOCK'],
      'ORDER_NOW': [const Color(0xFFEF4444),   'ORDER NOW'],
    };
    final color = cfg[status]?[0] as Color? ?? Colors.grey;
    final label = cfg[status]?[1] as String? ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: (color).withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: (color).withOpacity(0.3))),
      child: Text(label, style: GoogleFonts.inter(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }

  // ─── Predictive banner ───────────────────────────────────────────────────
  Widget _buildPredictiveBanner() {
    final pred = _diagnostics['predictive'] as Map? ?? {};
    final prob      = pred['probability']     as int?    ?? 82;
    final component = pred['component']       as String? ?? 'fuel pump';
    final miles     = pred['miles_remaining'] as int?    ?? 450;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.psychology, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 24),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Predictive Analysis Active', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: prob > 70 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$prob% RISK', style: GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'AI model suggests a $prob% probability of $component issues within the next $miles miles based on current telemetry.',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7)),
          ),
        ])),
        const SizedBox(width: 24),
        ElevatedButton(
          onPressed: _showScheduleDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text('SCHEDULE PREEMPTIVE FIX', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

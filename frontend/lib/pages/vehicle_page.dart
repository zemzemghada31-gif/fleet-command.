import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class Vehicle {
  final int id;
  final String model;
  final String plate;
  final String year;
  String status;
  String tracker;
  String notes;

  Vehicle({
    required this.id,
    required this.model,
    required this.plate,
    this.year = '',
    required this.status,
    this.tracker = 'Not Assigned',
    this.notes = '',
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'],
        model: j['model'],
        plate: j['plate'],
        status: j['status'] ?? 'ACTIVE',
        tracker: j['tracker'] ?? 'Not Assigned',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'model': model,
        'plate': plate,
        'status': status,
        'tracker': tracker,
      };
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class VehiclePage extends StatefulWidget {
  const VehiclePage({super.key});

  @override
  State<VehiclePage> createState() => _VehiclePageState();
}

class _VehiclePageState extends State<VehiclePage> {
  List<Vehicle> _vehicles = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _backendOffline = false;
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  int? _editingId;

  // Form controllers
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _yearCtrl  = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _formStatus  = 'ACTIVE';
  String? _formTracker;

  static const _statusOptions  = ['ACTIVE', 'MAINTENANCE', 'IDLE'];
  static const _statusFilters  = ['ALL', 'ACTIVE', 'MAINTENANCE', 'IDLE'];
  static const _trackerOptions = ['Not Assigned', 'ST-449-ALPHA', 'ST-112-BETA', 'ST-889-GAMMA', 'ST-221-DELTA'];

  // Offline mock data
  static final _mock = [
    Vehicle(id: 1, model: 'Tesla Model X',      plate: 'BT-904-TX',  status: 'ACTIVE',       tracker: 'ST-449-ALPHA'),
    Vehicle(id: 2, model: 'Mercedes Sprinter',  plate: 'CA-123-VN',  status: 'MAINTENANCE',  tracker: 'Not Assigned'),
    Vehicle(id: 3, model: 'Ford Transit XL',    plate: 'TX-4409-LP', status: 'IDLE',         tracker: 'ST-112-BETA'),
  ];

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  List<Vehicle> get _filtered {
    return _vehicles.where((v) {
      final matchStatus = _statusFilter == 'ALL' || v.status == _statusFilter;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          v.model.toLowerCase().contains(q) ||
          v.plate.toLowerCase().contains(q) ||
          v.tracker.toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList();
  }

  int get _activeCount      => _vehicles.where((v) => v.status == 'ACTIVE').length;
  int get _maintenanceCount => _vehicles.where((v) => v.status == 'MAINTENANCE').length;
  int get _idleCount        => _vehicles.where((v) => v.status == 'IDLE').length;

  bool get _isEditing => _editingId != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _yearCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  Future<void> _fetchVehicles() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _backendOffline = false; });
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/vehicles'))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (json.decode(res.body) as List).map((e) => Vehicle.fromJson(e)).toList();
        setState(() { _vehicles = list; _isLoading = false; });
      } else {
        _fallbackToMock();
      }
    } catch (_) {
      if (mounted) _fallbackToMock();
    }
  }

  void _fallbackToMock() {
    setState(() { _vehicles = List.from(_mock); _isLoading = false; _backendOffline = true; });
  }

  Future<void> _saveForm() async {
    if (_modelCtrl.text.trim().isEmpty || _plateCtrl.text.trim().isEmpty) {
      _snack('Model and Plate Number are required.', error: true);
      return;
    }
    setState(() => _isSaving = true);

    final body = json.encode({
      'id': _editingId ?? DateTime.now().millisecondsSinceEpoch % 100000,
      'model':   _modelCtrl.text.trim(),
      'plate':   _plateCtrl.text.trim(),
      'status':  _formStatus,
      'tracker': _formTracker ?? 'Not Assigned',
    });

    if (_backendOffline) {
      _applyLocalSave(body);
      return;
    }

    try {
      final res = _isEditing
          ? await http.put(Uri.parse('$kApiBaseUrl/api/vehicles/$_editingId'),
              headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 6))
          : await http.post(Uri.parse('$kApiBaseUrl/api/vehicles'),
              headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 6));

      if (!mounted) return;
      if (res.statusCode == 200) {
        _clearForm();
        await _fetchVehicles();
        _snack(_isEditing ? 'Vehicle updated.' : 'Vehicle registered.');
      } else {
        _snack('Save failed (${res.statusCode}).', error: true);
      }
    } catch (_) {
      if (mounted) _applyLocalSave(body);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _applyLocalSave(String body) {
    final data = json.decode(body);
    final v = Vehicle(
      id:      data['id'],
      model:   data['model'],
      plate:   data['plate'],
      status:  data['status'],
      tracker: data['tracker'],
    );
    setState(() {
      if (_isEditing) {
        final i = _vehicles.indexWhere((x) => x.id == _editingId);
        if (i >= 0) _vehicles[i] = v;
      } else {
        _vehicles.add(v);
      }
      _backendOffline = true;
      _isSaving = false;
    });
    _clearForm();
    _snack(_isEditing ? 'Vehicle updated locally.' : 'Vehicle registered locally (offline).');
  }

  Future<void> _deleteVehicle(Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Vehicle'),
        content: Text('Delete ${v.model} (${v.plate})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    if (_backendOffline) {
      setState(() => _vehicles.removeWhere((x) => x.id == v.id));
      _snack('Vehicle deleted locally.');
      return;
    }
    try {
      final res = await http
          .delete(Uri.parse('$kApiBaseUrl/api/vehicles/${v.id}'))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _vehicles.removeWhere((x) => x.id == v.id));
        _snack('Vehicle "${v.model}" deleted.');
        if (_editingId == v.id) _clearForm();
      } else {
        _snack('Delete failed.', error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() { _vehicles.removeWhere((x) => x.id == v.id); _backendOffline = true; });
        _snack('Deleted locally (offline).');
      }
    }
  }

  void _startEdit(Vehicle v) {
    setState(() {
      _editingId    = v.id;
      _modelCtrl.text = v.model;
      _plateCtrl.text = v.plate;
      _yearCtrl.text  = v.year;
      _notesCtrl.text = v.notes;
      _formStatus   = v.status;
      _formTracker  = v.tracker == 'Not Assigned' ? null : v.tracker;
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _modelCtrl.clear();
      _plateCtrl.clear();
      _yearCtrl.clear();
      _notesCtrl.clear();
      _formStatus  = 'ACTIVE';
      _formTracker = null;
      _isSaving    = false;
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : const Color(0xFF0F172A),
    ));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline banner
          if (_backendOffline) _buildOfflineBanner(),

          // Page header
          _buildPageHeader(),
          const SizedBox(height: 24),

          // Stats row
          _buildStatsRow(),
          const SizedBox(height: 24),

          // Main two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left – inventory
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildSearchAndFilter(),
                    const SizedBox(height: 16),
                    _buildInventoryTable(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right – registration / edit form
              SizedBox(width: 320, child: _buildFormPanel()),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Offline banner
  // ---------------------------------------------------------------------------

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 10),
          const Expanded(child: Text('Offline mode — demo data. Run: python main.py', style: TextStyle(color: Color(0xFF92400E), fontSize: 12))),
          TextButton(
            onPressed: _fetchVehicles,
            child: const Text('Retry', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page header
  // ---------------------------------------------------------------------------

  Widget _buildPageHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vehicle Management', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              SizedBox(height: 4),
              Text('Configure, monitor, and assign assets to your tactical grid.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _clearForm,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Stats row
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('TOTAL FLEET',  _vehicles.length.toString(), Icons.directions_car,   const Color(0xFF6366F1)),
        const SizedBox(width: 16),
        _buildStatCard('ACTIVE',       _activeCount.toString(),      Icons.check_circle,     const Color(0xFF22C55E)),
        const SizedBox(width: 16),
        _buildStatCard('MAINTENANCE',  _maintenanceCount.toString(), Icons.build,            const Color(0xFFF59E0B)),
        const SizedBox(width: 16),
        _buildStatCard('IDLE',         _idleCount.toString(),        Icons.timer,            const Color(0xFF3B82F6)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search + filter
  // ---------------------------------------------------------------------------

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        // Search
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search model, plate, tracker…',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Status filter chips
        ..._statusFilters.map((f) => _buildFilterChip(f)),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final selected = _statusFilter == label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? Colors.white : const Color(0xFF64748B))),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Inventory table
  // ---------------------------------------------------------------------------

  Widget _buildInventoryTable() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF475569)),
                const SizedBox(width: 8),
                const Text('Fleet Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('${_filtered.length} ASSETS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('MODEL / PLATE', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
                Expanded(flex: 2, child: Text('STATUS',        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
                Expanded(flex: 3, child: Text('GPS TRACKER',   style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
                SizedBox(width: 80, child: Text('ACTIONS',     style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
              ],
            ),
          ),

          // Rows
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text(_vehicles.isEmpty ? 'No vehicles found.' : 'No vehicles match the filter.',
                  style: const TextStyle(color: Color(0xFF94A3B8)))),
            )
          else
            ..._filtered.map((v) => _buildVehicleRow(v)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(Vehicle v) {
    final isEditingThis = _editingId == v.id;
    final sc = _statusColor(v.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isEditingThis ? const Color(0xFFF0F9FF) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Model / Plate
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.directions_car, color: sc, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                      Text(v.plate, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Status
          Expanded(flex: 2, child: _statusBadge(v.status)),
          // Tracker
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.satellite_alt, size: 13, color: v.tracker == 'Not Assigned' ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    v.tracker,
                    style: TextStyle(
                      fontSize: 12,
                      color: v.tracker == 'Not Assigned' ? const Color(0xFFEF4444) : const Color(0xFF475569),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          SizedBox(
            width: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBtn(Icons.edit_outlined,  const Color(0xFF3B82F6), () => _startEdit(v),    tooltip: 'Edit'),
                const SizedBox(width: 4),
                _iconBtn(Icons.delete_outline, const Color(0xFFEF4444), () => _deleteVehicle(v), tooltip: 'Delete'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap, {String? tooltip}) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form panel
  // ---------------------------------------------------------------------------

  Widget _buildFormPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: _isEditing ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Panel title
          Row(
            children: [
              Icon(_isEditing ? Icons.edit : Icons.app_registration, size: 18, color: const Color(0xFF475569)),
              const SizedBox(width: 8),
              Text(_isEditing ? 'Edit Vehicle' : 'Register Vehicle',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
            ],
          ),
          const SizedBox(height: 4),
          Text(_isEditing ? 'Editing vehicle ID $_editingId' : 'Add a new asset to the fleet.',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 20),

          // Model
          _fieldLabel('MODEL'),
          const SizedBox(height: 6),
          _textField(_modelCtrl, 'e.g. Mercedes Sprinter'),
          const SizedBox(height: 14),

          // Plate
          _fieldLabel('PLATE NUMBER'),
          const SizedBox(height: 6),
          _textField(_plateCtrl, 'e.g. TX-4409-LP'),
          const SizedBox(height: 14),

          // Year
          _fieldLabel('YEAR'),
          const SizedBox(height: 6),
          _textField(_yearCtrl, '2024', keyboardType: TextInputType.number),
          const SizedBox(height: 14),

          // Status
          _fieldLabel('STATUS'),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _formStatus,
            options: _statusOptions,
            onChanged: (v) => setState(() => _formStatus = v!),
            itemBuilder: (s) => Row(children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: _statusColor(s), shape: BoxShape.circle)),
              Text(s),
            ]),
          ),
          const SizedBox(height: 14),

          // Tracker
          _fieldLabel('ASSIGN GPS TRACKER'),
          const SizedBox(height: 6),
          _buildDropdown(
            value: _formTracker ?? 'Not Assigned',
            options: _trackerOptions,
            onChanged: (v) => setState(() => _formTracker = v == 'Not Assigned' ? null : v),
          ),
          const SizedBox(height: 14),

          // Notes
          _fieldLabel('OPERATION NOTES'),
          const SizedBox(height: 6),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add notes about this vehicle…',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('CANCEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFF93C5FD),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_isEditing ? 'UPDATE' : 'SAVE', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small shared widgets
  // ---------------------------------------------------------------------------

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Color(0xFF475569), letterSpacing: 0.5));

  Widget _textField(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    Widget Function(String)? itemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 18),
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13),
          items: options.map((o) => DropdownMenuItem(
            value: o,
            child: itemBuilder != null ? itemBuilder(o) : Text(o),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':      return const Color(0xFF22C55E);
      case 'MAINTENANCE': return const Color(0xFFF59E0B);
      case 'IDLE':        return const Color(0xFF3B82F6);
      default:            return Colors.grey;
    }
  }

  Widget _statusBadge(String status) {
    final c = _statusColor(status);
    final icons = {'ACTIVE': Icons.check_circle, 'MAINTENANCE': Icons.build, 'IDLE': Icons.timer};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icons[status] ?? Icons.circle, size: 12, color: c),
          const SizedBox(width: 5),
          Text(status, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ),
    );
  }
}
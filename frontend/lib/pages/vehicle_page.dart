import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';
import '../mock_data.dart';
import '../services/sync_service.dart';
import 'dart:math' as math;

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
  List<Vehicle> _trashVehicles = [];
  bool _showTrash = false;
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
  // Offline mock data — sourced from mock_data.dart central repository
  static final List<String> _trackerOptions = () {
    final assigned = kMockDevices.where((d) => d.assignment == 'ASSIGNED').map((d) => d.id).toList();
    final unassigned = kMockDevices.where((d) => d.assignment == 'UNASSIGNED').map((d) => d.id).toList();
    return ['Not Assigned', ...unassigned, ...assigned];
  }();

  static List<Vehicle> get _mock => kMockVehicles.map((mv) => Vehicle(
    id: mv.id,
    model: mv.model,
    plate: mv.plate,
    status: mv.status,
    tracker: mv.tracker,
  )).toList();

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
    _loadVehiclesFromLocal().then((_) {
      // Après avoir chargé le cache local, fetch le backend en arrière-plan
      _fetchVehicles();
    });
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
    // Only show loading spinner if we have no cached data yet
    if (_vehicles.isEmpty) {
      setState(() { _isLoading = true; _backendOffline = false; });
    }
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/vehicles'))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (json.decode(res.body) as List).map((e) => Vehicle.fromJson(e)).toList();
        setState(() { _vehicles = list; _isLoading = false; });
        await _saveVehiclesLocally(list);
        // Sync pending operations now that backend is reachable
        await _syncPendingOperations();
      }
    } catch (_) {
      // Only show offline if we have no cached data at all
      if (_vehicles.isEmpty && mounted) {
        setState(() { _isLoading = false; _backendOffline = true; });
      }
    }
  }

  Future<void> _syncPendingOperations() async {
    try {
      await SyncService.processPendingOperations(
        onCreateDevice: (_) async {},
        onUpdateAssignment: (_, __) async {},
        onDeleteDevice: (_) async {},
        onCreateVehicle: (data) async {
          final res = await http.post(
            Uri.parse('$kApiBaseUrl/api/vehicles'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          ).timeout(const Duration(seconds: 30));
          if (res.statusCode != 200) throw Exception('Failed to sync vehicle creation');
        },
        onUpdateVehicle: (vehicleId, data) async {
          final res = await http.put(
            Uri.parse('$kApiBaseUrl/api/vehicles/$vehicleId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          ).timeout(const Duration(seconds: 30));
          if (res.statusCode != 200) throw Exception('Failed to sync vehicle update');
        },
        onDeleteVehicle: (vehicleId) async {
          final res = await http
              .delete(Uri.parse('$kApiBaseUrl/api/vehicles/$vehicleId'))
              .timeout(const Duration(seconds: 30));
          if (res.statusCode != 200) throw Exception('Failed to sync vehicle deletion');
        },
      );
      final pendingCount = await SyncService.getPendingCount();
      if (pendingCount == 0 && mounted) {
        _snack('All pending changes synced successfully!');
      } else if (mounted) {
        _snack('$pendingCount changes still pending sync.', error: true);
      }
    } catch (e) {
      if (mounted) _snack('Sync failed: $e', error: true);
    }
  }

  Future<void> _saveVehiclesLocally(List<Vehicle> vehicles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = vehicles.map((v) => v.toJson()).toList();
      await prefs.setString('cached_vehicles', json.encode(jsonList));
    } catch (_) {}
  }

  Future<void> _saveTrashLocally(List<Vehicle> vehicles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = vehicles.map((v) => v.toJson()).toList();
      await prefs.setString('cached_vehicles_trash', json.encode(jsonList));
    } catch (_) {}
  }

  Future<void> _loadVehiclesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('cached_vehicles');
      if (data != null) {
        final list = (json.decode(data) as List).map((e) => Vehicle.fromJson(e)).toList();
        if (mounted) {
          setState(() { _vehicles = list; _isLoading = false; _backendOffline = true; });
        }
      }
      final trashData = prefs.getString('cached_vehicles_trash');
      if (trashData != null) {
        final trashList = (json.decode(trashData) as List).map((e) => Vehicle.fromJson(e)).toList();
        if (mounted) {
          setState(() => _trashVehicles = trashList);
        }
      }
      return;
    } catch (_) {}
    if (mounted) _fallbackToMock();
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
      await _applyLocalSave(body);
      return;
    }

    try {
      final res = _isEditing
          ? await http.put(Uri.parse('$kApiBaseUrl/api/vehicles/$_editingId'),
              headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 30))
          : await http.post(Uri.parse('$kApiBaseUrl/api/vehicles'),
              headers: {'Content-Type': 'application/json'}, body: body)
              .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (res.statusCode == 200) {
        _clearForm();
        await _fetchVehicles();
        _snack(_isEditing ? 'Vehicle updated.' : 'Vehicle registered.');
      } else {
        _snack('Save failed (${res.statusCode}).', error: true);
      }
    } catch (_) {
      if (mounted) await _applyLocalSave(body);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _applyLocalSave(String body) async {
    final data = json.decode(body);
    final v = Vehicle(
      id:      data['id'],
      model:   data['model'],
      plate:   data['plate'],
      status:  data['status'],
      tracker: data['tracker'],
    );

    if (_isEditing) {
      // Queue update for sync
      await SyncService.addOperation(SyncOperationType.updateVehicle, data);
    } else {
      // Queue creation for sync
      await SyncService.addOperation(SyncOperationType.createVehicle, data);
    }

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
    await _saveVehiclesLocally(_vehicles);
    _clearForm();
    _snack(_isEditing ? 'Vehicle updated locally (will sync when online).' : 'Vehicle registered locally (will sync when online).');
  }

  Future<void> _deleteVehicle(Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Vehicle'),
        content: Text('Move ${v.model} (${v.plate}) to trash?'),
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
      await SyncService.addOperation(SyncOperationType.deleteVehicle, {'id': v.id});
      setState(() {
        _vehicles.removeWhere((x) => x.id == v.id);
        _trashVehicles.add(v);
      });
      await _saveVehiclesLocally(_vehicles);
      await _saveTrashLocally(_trashVehicles);
      _snack('Vehicle moved to trash locally (will sync when online).');
      return;
    }
    try {
      final res = await http
          .delete(Uri.parse('$kApiBaseUrl/api/vehicles/${v.id}'))
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _vehicles.removeWhere((x) => x.id == v.id);
          _trashVehicles.add(v);
        });
        await _saveVehiclesLocally(_vehicles);
        await _saveTrashLocally(_trashVehicles);
        _snack('Vehicle "${v.model}" moved to trash.');
        if (_editingId == v.id) _clearForm();
      } else {
        _snack('Delete failed.', error: true);
      }
    } catch (_) {
      if (mounted) {
        await SyncService.addOperation(SyncOperationType.deleteVehicle, {'id': v.id});
        setState(() {
          _vehicles.removeWhere((x) => x.id == v.id);
          _trashVehicles.add(v);
          _backendOffline = true;
        });
        await _saveVehiclesLocally(_vehicles);
        await _saveTrashLocally(_trashVehicles);
        _snack('Moved to trash locally (queued for sync).');
      }
    }
  }

  Future<void> _fetchTrashVehicles() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/vehicles/trash'))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (json.decode(res.body) as List).map((e) => Vehicle.fromJson(e)).toList();
        setState(() => _trashVehicles = list);
        await _saveTrashLocally(list);
      }
    } catch (_) {}
  }

  Future<void> _restoreVehicle(Vehicle v) async {
    try {
      final res = await http
          .post(Uri.parse('$kApiBaseUrl/api/vehicles/${v.id}/restore'))
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() => _trashVehicles.removeWhere((x) => x.id == v.id));
        await _saveTrashLocally(_trashVehicles);
        _snack('Vehicle "${v.model}" restored.');
        _fetchVehicles();
      } else {
        _snack('Restore failed.', error: true);
      }
    } catch (_) {
      if (mounted) _snack('Backend unreachable.', error: true);
    }
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_backendOffline) _buildOfflineBanner(),
          _buildPageHeader(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          _buildStatsRow(),
          SizedBox(height: isMobile ? 16 : 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        children: [
                          _buildSearchAndFilter(isMobile),
                          const SizedBox(height: 16),
                          _buildInventoryTable(isMobile),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(width: math.min(constraints.maxWidth * 0.3, 320), child: _buildFormPanel()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildSearchAndFilter(isMobile),
                    const SizedBox(height: 16),
                    _buildInventoryTable(isMobile),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: _buildFormPanel()),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Page header
  // ---------------------------------------------------------------------------

  Widget _buildPageHeader([bool isMobile = false]) {
    if (isMobile) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Vehicle Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Configure, monitor, and assign assets to your tactical grid.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
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
        ),
      ]);
    }
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
    final cards = [
      _buildStatCard('TOTAL FLEET',  _vehicles.length.toString(), Icons.local_shipping,   const Color(0xFF6366F1)),
      _buildStatCard('ACTIVE',       _activeCount.toString(),      Icons.check_circle,     const Color(0xFF22C55E)),
      _buildStatCard('MAINTENANCE',  _maintenanceCount.toString(), Icons.build,            const Color(0xFFF59E0B)),
      _buildStatCard('IDLE',         _idleCount.toString(),        Icons.timer,            const Color(0xFF3B82F6)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
              const SizedBox(width: 16),
              Expanded(child: cards[3]),
            ],
          );
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
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
    );
  }

  // ---------------------------------------------------------------------------
  // Search + filter
  // ---------------------------------------------------------------------------

  Widget _buildSearchAndFilter([bool isMobile = false]) {
    return Column(
      children: [
        Container(
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
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _statusFilters.map((f) => _buildFilterChip(f)).toList()),
        ),
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

  Widget _buildInventoryTable([bool isMobile = false]) {
    final tableContent = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
        child: Row(
          children: [
            const Expanded(flex: 3, child: Text('MODEL / PLATE', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
            const Expanded(flex: 2, child: Text('STATUS',        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
            const Expanded(flex: 3, child: Text('GPS TRACKER',   style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
            SizedBox(width: isMobile ? 64 : 80, child: const Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 11))),
          ],
        ),
      ),
      if (_isLoading)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
      else if (_showTrash && _trashVehicles.isEmpty)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Trash is empty.', style: TextStyle(color: Color(0xFF94A3B8)))))
      else if (_showTrash)
        ..._trashVehicles.map((v) => _buildTrashRow(v, isMobile))
      else if (_filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(_vehicles.isEmpty ? 'No vehicles found.' : 'No vehicles match the filter.',
              style: const TextStyle(color: Color(0xFF94A3B8)))),
        )
      else
        ..._filtered.map((v) => _buildVehicleRow(v, isMobile)),
      const SizedBox(height: 8),
    ]);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, isMobile ? 12 : 20, isMobile ? 12 : 20, 0),
            child: isMobile
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF475569)),
                      const SizedBox(width: 8),
                      const Text('Fleet Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                      const Spacer(),
                      _buildIconToggle(),
                    ]),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(_showTrash ? '${_trashVehicles.length} DELETED' : '${_filtered.length} ASSETS',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    ),
                  ])
                : Row(children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 8),
                    const Text('Fleet Inventory', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                    const Spacer(),
                    _buildIconToggle(),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(_showTrash ? '${_trashVehicles.length} DELETED' : '${_filtered.length} ASSETS',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                    ),
                  ]),
          ),
          const SizedBox(height: 16),
          isMobile
              ? Column(children: [
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                  else if (_showTrash && _trashVehicles.isEmpty)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Trash is empty.', style: TextStyle(color: Color(0xFF94A3B8)))))
                  else if (_showTrash)
                    ..._trashVehicles.map((v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildMobileTrashCard(v)))
                  else if (_filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(_vehicles.isEmpty ? 'No vehicles found.' : 'No vehicles match the filter.',
                          style: const TextStyle(color: Color(0xFF94A3B8)))),
                    )
                  else
                    ..._filtered.map((v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _buildMobileVehicleCard(v))),
                ])
              : tableContent,
        ],
      ),
    );
  }

  Widget _buildMobileVehicleCard(Vehicle v) {
    final sc = _statusColor(v.status);
    final isEditingThis = _editingId == v.id;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEditingThis ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.local_shipping, color: sc, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            Text(v.plate, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ])),
          _statusBadge(v.status),
          const SizedBox(width: 4),
          _iconBtn(Icons.edit_outlined, const Color(0xFF3B82F6), () => _startEdit(v), tooltip: 'Edit'),
          const SizedBox(width: 2),
          _iconBtn(Icons.delete_outline, const Color(0xFFEF4444), () => _deleteVehicle(v), tooltip: 'Delete'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.satellite_alt, size: 12, color: v.tracker == 'Not Assigned' ? const Color(0xFFEF4444) : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(v.tracker,
              style: TextStyle(fontSize: 11, color: v.tracker == 'Not Assigned' ? const Color(0xFFEF4444) : const Color(0xFF475569)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildMobileTrashCard(Vehicle v) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444))),
          Text(v.plate, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ])),
        IconButton(
          icon: const Icon(Icons.restore_from_trash, color: Color(0xFF3B82F6), size: 20),
          tooltip: 'Restore',
          onPressed: () => _restoreVehicle(v),
        ),
      ]),
    );
  }

  Widget _buildIconToggle() {
    return GestureDetector(
      onTap: () {
        setState(() => _showTrash = !_showTrash);
        if (_showTrash) _fetchTrashVehicles();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _showTrash ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _showTrash ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        ),
        child: Icon(
          _showTrash ? Icons.devices : Icons.delete_outline,
          size: 18,
          color: _showTrash ? const Color(0xFFEF4444) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildTrashRow(Vehicle v, [bool isMobile = false]) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFEF4444))),
                  Text(v.plate, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                ],
              )),
            ],
          )),
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete, size: 12, color: Color(0xFFEF4444)),
                SizedBox(width: 5),
                Text('DELETED', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600, fontSize: 11)),
              ],
            ),
          )),
          Expanded(flex: 3, child: Text(v.tracker, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
          SizedBox(
            width: isMobile ? 56 : 80,
            child: IconButton(
              icon: const Icon(Icons.restore_from_trash, color: Color(0xFF3B82F6)),
              tooltip: 'Restore',
              onPressed: () => _restoreVehicle(v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleRow(Vehicle v, [bool isMobile = false]) {
    final isEditingThis = _editingId == v.id;
    final sc = _statusColor(v.status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 14),
      decoration: BoxDecoration(
        color: isEditingThis ? const Color(0xFFF0F9FF) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.local_shipping, color: sc, size: 22),
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
          Expanded(flex: 2, child: _statusBadge(v.status)),
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
          SizedBox(
            width: isMobile ? 64 : 80,
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
          _textField(_plateCtrl, 'e.g. DXB-4400-LP'),
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

  // ---------------------------------------------------------------------------
  // Helper methods
  // ---------------------------------------------------------------------------

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        backgroundColor: error ? Colors.red : const Color(0xFF22C55E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearForm() {
    _modelCtrl.clear();
    _plateCtrl.clear();
    _yearCtrl.clear();
    _notesCtrl.clear();
    setState(() {
      _editingId = null;
      _formStatus = 'ACTIVE';
      _formTracker = null;
    });
  }

  void _startEdit(Vehicle v) {
    setState(() {
      _editingId = v.id;
      _modelCtrl.text = v.model;
      _plateCtrl.text = v.plate;
      _yearCtrl.text = v.year;
      _notesCtrl.text = v.notes;
      _formStatus = v.status;
      _formTracker = v.tracker;
    });
  }

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
}
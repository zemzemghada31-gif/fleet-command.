import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class LiveVehicle {
  final String id;
  final String location;
  final String status;       // MOVING | IDLE | MAINTENANCE
  final double speed;        // mph
  final int fuel;            // %
  final String driver;
  final String eta;
  final String heading;
  final List<double> speedHistory;
  final double lat;
  final double lng;

  const LiveVehicle({
    required this.id,
    required this.location,
    required this.status,
    required this.speed,
    required this.fuel,
    required this.driver,
    required this.eta,
    required this.heading,
    required this.speedHistory,
    required this.lat,
    required this.lng,
  });

  LiveVehicle copyWith({
    double? speed, int? fuel, List<double>? speedHistory,
    double? lat, double? lng,
  }) => LiveVehicle(
        id: id, location: location, status: status,
        speed: speed ?? this.speed, fuel: fuel ?? this.fuel,
        driver: driver, eta: eta, heading: heading,
        speedHistory: speedHistory ?? this.speedHistory,
        lat: lat ?? this.lat, lng: lng ?? this.lng,
      );

  factory LiveVehicle.fromJson(Map<String, dynamic> j) => LiveVehicle(
        id: j['id'],
        location: j['location'],
        status: j['status'],
        speed: (j['speed'] as num).toDouble(),
        fuel: j['fuel'] as int,
        driver: j['driver'],
        eta: j['eta'],
        heading: j['heading'] ?? '—',
        speedHistory: (j['speed_history'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            List.filled(10, 0.0),
        lat: (j['lat'] as num?)?.toDouble() ?? 41.8781,
        lng: (j['lng'] as num?)?.toDouble() ?? -87.6298,
      );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  // ─── State ───────────────────────────────────────────────────────────────
  String _filter = 'All';
  String _searchQuery = '';
  bool _isTracking = false;
  bool _backendOffline = false;
  int _secondsSinceUpdate = 0;
  bool _mapInitialized = false;

  String? _selectedId;
  List<LiveVehicle> _vehicles = [];
  List<LatLng> _routeHistory = [];

  Timer? _refreshTimer;
  Timer? _clockTimer;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  final MapController _mapController = MapController();
  final _rnd = Random();

  // ─── Mock data with real GPS coordinates ─────────────────────────────────
  static final _mock = [
    const LiveVehicle(id: 'TX-0912-A', location: 'Interstate 90, Chicago IL',   status: 'MOVING',      speed: 68.0, fuel: 92, driver: 'Marcus Reed',   eta: '4.2H TO GO',  heading: 'NE', speedHistory: [62,65,68,70,67,69,68,71,66,68], lat: 41.8781, lng: -87.6298),
    const LiveVehicle(id: 'NY-8271-C', location: 'South Bay Distribution Ctr',  status: 'IDLE',        speed:  0.0, fuel: 44, driver: 'Sarah Kim',     eta: 'OFFLOADING',  heading: '—',  speedHistory: [0,0,0,0,0,0,0,0,0,0],           lat: 37.3382, lng: -121.8863),
    const LiveVehicle(id: 'FL-1102-K', location: 'Service Hub Station #4',      status: 'MAINTENANCE', speed:  0.0, fuel: 31, driver: 'James Wu',      eta: 'IN SERVICE',  heading: '—',  speedHistory: [0,0,0,0,0,0,0,0,0,0],           lat: 27.9506, lng: -82.4572),
    const LiveVehicle(id: 'CA-5501-M', location: 'US-101, San Francisco CA',    status: 'MOVING',      speed: 54.0, fuel: 67, driver: 'Elena Torres',  eta: '1.8H TO GO',  heading: 'S',  speedHistory: [48,51,54,52,55,56,53,54,57,54], lat: 37.7749, lng: -122.4194),
    const LiveVehicle(id: 'TX-3302-B', location: 'Dallas Fort Worth Depot',     status: 'IDLE',        speed:  0.0, fuel: 88, driver: 'Kevin Park',    eta: 'LOADING',     heading: '—',  speedHistory: [0,0,0,0,0,0,0,0,0,0],           lat: 32.8998, lng: -97.0403),
  ];

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _loadFleet();

    // Refresh data every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshData());

    // "X seconds ago" counter
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsSinceUpdate++);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Data ────────────────────────────────────────────────────────────────
  Future<void> _loadFleet() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/api/live'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && mounted) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _vehicles = list.map((e) => LiveVehicle.fromJson(e)).toList();
          _backendOffline = false;
          _secondsSinceUpdate = 0;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() { _vehicles = List.from(_mock); _backendOffline = true; });
  }

  void _refreshData() {
    if (!mounted) return;
    if (_backendOffline) {
      // Simulate live updates locally
      setState(() {
        _vehicles = _vehicles.map((v) {
          if (v.status != 'MOVING') return v;
          final newSpeed = (v.speed + _rnd.nextDouble() * 6 - 3).clamp(0.0, 120.0);
          final newFuel  = (v.fuel  - (_rnd.nextDouble() < 0.2 ? 1 : 0)).clamp(0, 100).toInt();
          final newHist  = [...v.speedHistory.skip(1), newSpeed];
          // Simulate GPS movement in direction of heading
          double dlat = 0, dlng = 0;
          switch (v.heading) {
            case 'N':  dlat =  0.0005; break;
            case 'NE': dlat =  0.0003; dlng =  0.0004; break;
            case 'E':  dlng =  0.0005; break;
            case 'SE': dlat = -0.0003; dlng =  0.0004; break;
            case 'S':  dlat = -0.0005; break;
            case 'SW': dlat = -0.0003; dlng = -0.0004; break;
            case 'W':  dlng = -0.0005; break;
            case 'NW': dlat =  0.0003; dlng = -0.0004; break;
          }
          final newLat = v.lat + dlat + (_rnd.nextDouble() * 0.0002 - 0.0001);
          final newLng = v.lng + dlng + (_rnd.nextDouble() * 0.0002 - 0.0001);
          return v.copyWith(
            speed: double.parse(newSpeed.toStringAsFixed(1)),
            fuel: newFuel,
            speedHistory: newHist.cast<double>(),
            lat: newLat, lng: newLng,
          );
        }).toList();
        _secondsSinceUpdate = 0;
      });
    } else {
      _loadFleet();
    }
    // Move map to updated vehicle position
    if (_isTracking && _mapInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final sv = _selectedVehicle;
        if (sv != null && _mapInitialized) {
          _routeHistory.add(LatLng(sv.lat, sv.lng));
          if (_routeHistory.length > 60) _routeHistory.removeAt(0);
          try { _mapController.move(LatLng(sv.lat, sv.lng), 15); } catch (_) {}
        }
      });
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  LiveVehicle? get _selectedVehicle =>
      _selectedId == null ? null : _vehicles.where((v) => v.id == _selectedId).firstOrNull;

  List<LiveVehicle> get _filteredVehicles {
    return _vehicles.where((v) {
      final matchesFilter = _filter == 'All' ||
          (_filter == 'Moving' && v.status == 'MOVING') ||
          (_filter == 'Idle'   && v.status == 'IDLE')   ||
          (_filter == 'Alert'  && v.status == 'MAINTENANCE');
      final matchesSearch = _searchQuery.isEmpty ||
          v.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.driver.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          v.location.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  void _startTracking(LiveVehicle v) {
    setState(() {
      _isTracking = true;
      _routeHistory = [LatLng(v.lat, v.lng)];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mapInitialized) {
        try { _mapController.move(LatLng(v.lat, v.lng), 15); } catch (_) {}
      }
    });
  }

  // ─── Reports storage ──────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _reports = [];

  void _showRouteDialog(LiveVehicle v) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: _RouteDialogContent(vehicle: v, routeHistory: List.from(_routeHistory)),
      ),
    );
  }

  void _showReportDialog(LiveVehicle v) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: _ReportDialogContent(
          vehicle: v,
          reportNumber: _reports.length + 1,
          onSubmit: (report) {
            setState(() => _reports.add(report));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Incident report #${_reports.length} submitted — ${report['severity']} · ${report['incident_type']}'),
              ]),
              backgroundColor: Colors.green.shade700,
              duration: const Duration(seconds: 4),
            ));
          },
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'MOVING':      return Colors.blue;
      case 'IDLE':        return Colors.grey;
      case 'MAINTENANCE': return Colors.red;
      default:            return Colors.grey;
    }
  }

  String get _lastUpdateLabel {
    if (_secondsSinceUpdate == 0) return 'just now';
    if (_secondsSinceUpdate < 60) return '${_secondsSinceUpdate}s ago';
    return '${_secondsSinceUpdate ~/ 60}m ago';
  }

  int get _movingCount => _vehicles.where((v) => v.status == 'MOVING').length;

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // ── Background: real OSM map when tracking, static image otherwise ──
      if (_isTracking && _selectedVehicle != null)
        _buildLiveMap(_selectedVehicle!)
      else
        Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage('assets/images/mon_fond.jpg'), fit: BoxFit.cover),
          ),
        ),

      // ── Search bar (hidden during tracking to keep map clean) ──
      if (!_isTracking)
        Positioned(
          top: 24, left: 24,
          child: Row(children: [
            Container(
              width: 350, height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Row(children: [
                const Icon(Icons.search, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search vehicle ID, driver…',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                )),
              ]),
            ),
            const SizedBox(width: 12),
            Container(
              height: 48, width: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Tooltip(
                message: 'Auto-refresh every 5s',
                child: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Icon(Icons.wifi_tethering, color: Colors.blue.withOpacity(_pulseAnim.value), size: 22),
                ),
              ),
            ),
          ]),
        ),

      // ── GPS coordinates overlay (shown during tracking) ──
      if (_isTracking && _selectedVehicle != null)
        Positioned(
          top: 16, left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.satellite_alt, color: Colors.greenAccent, size: 14),
              const SizedBox(width: 8),
              Text(
                '${_selectedVehicle!.lat.toStringAsFixed(5)}° N   ${_selectedVehicle!.lng.abs().toStringAsFixed(5)}° W',
                style: GoogleFonts.robotoMono(fontSize: 12, color: Colors.greenAccent, fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ),

      // ── Selected vehicle popup (floating on map) ──
      if (_selectedVehicle != null && !_isTracking)
        _buildVehiclePopup(_selectedVehicle!),


      // ── Right panel ──
      Positioned(
        top: 24, right: 24, bottom: 24,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
          child: _isTracking && _selectedVehicle != null
              ? _buildTrackingPanel(_selectedVehicle!, key: const ValueKey('tracking'))
              : _buildFleetPanel(key: const ValueKey('fleet')),
        ),
      ),
    ]);
  }

  // ─── Real OpenStreetMap ───────────────────────────────────────────────────
  Widget _buildLiveMap(LiveVehicle selected) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(selected.lat, selected.lng),
        initialZoom: 15,
        onMapReady: () => setState(() => _mapInitialized = true),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.fleet.command',
        ),
        // Route trail (blue polyline)
        if (_routeHistory.length > 1)
          PolylineLayer(polylines: [
            Polyline(
              points: _routeHistory,
              color: const Color(0xFF3B82F6).withOpacity(0.75),
              strokeWidth: 4,
            ),
          ]),
        // All vehicle markers
        MarkerLayer(markers: [
          for (final v in _vehicles)
            Marker(
              point: LatLng(v.lat, v.lng),
              width: v.id == selected.id ? 52 : 32,
              height: v.id == selected.id ? 52 : 32,
              child: _buildMapMarker(v, isSelected: v.id == selected.id),
            ),
        ]),
      ],
    );
  }

  Widget _buildMapMarker(LiveVehicle v, {bool isSelected = false}) {
    if (isSelected) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _statusColor(v.status).withOpacity(0.15 + _pulseAnim.value * 0.15),
          ),
          child: Center(
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _statusColor(v.status),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: _statusColor(v.status).withOpacity(0.5),
                  blurRadius: 8 + _pulseAnim.value * 6,
                  spreadRadius: 2,
                )],
              ),
              child: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
            ),
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: _statusColor(v.status),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Icon(Icons.local_shipping, color: Colors.white, size: 14),
    );
  }

  // ─── Vehicle popup ───────────────────────────────────────────────────────
  Widget _buildVehiclePopup(LiveVehicle v) {
    return Positioned(
      top: 140, left: 180,
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('VEHICLE ID', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(v.id, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            Row(children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: v.status == 'MOVING'
                        ? Colors.blue.withOpacity(_pulseAnim.value)
                        : _statusColor(v.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(v.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(v.status, style: TextStyle(color: _statusColor(v.status), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _popupStat('Speed', '${v.speed.toStringAsFixed(0)} mph')),
            Expanded(child: _popupStat('Driver', v.driver)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _popupStat('Fuel', '${v.fuel}%')),
            Expanded(child: _popupStat('ETA', v.eta)),
          ]),
          const SizedBox(height: 8),
          // GPS coordinates in popup
          Row(children: [
            const Icon(Icons.location_on, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '${v.lat.toStringAsFixed(4)}° N  ${v.lng.abs().toStringAsFixed(4)}° W',
              style: GoogleFonts.robotoMono(fontSize: 10, color: Colors.grey),
            ),
          ]),
          const Divider(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Updated $_lastUpdateLabel', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
            Row(children: [
              TextButton(
                onPressed: () => setState(() => _selectedId = null),
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text('Close', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => _startTracking(v),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(_pulseAnim.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('TRACK LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ]),
        ]),
      ),
    );
  }

  Widget _popupStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
      Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
    ],
  );

  // ─── Fleet panel ─────────────────────────────────────────────────────────
  Widget _buildFleetPanel({Key? key}) {
    final filtered = _filteredVehicles;
    return Container(
      key: key,
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Active Fleet', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
              Row(children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(_pulseAnim.value),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('$_movingCount/${_vehicles.length} MOVING', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 4),
            Text(
              _backendOffline ? 'Simulated live data  ·  Updated $_lastUpdateLabel' : 'Live telemetry  ·  Updated $_lastUpdateLabel',
              style: GoogleFonts.inter(fontSize: 11, color: _backendOffline ? Colors.orange : Colors.grey),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in ['All', 'Moving', 'Idle', 'Alert'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(f),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('No vehicles match', style: GoogleFonts.inter(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _buildFleetItem(filtered[i]),
                ),
        ),
      ]),
    );
  }

  // ─── Live tracking panel ──────────────────────────────────────────────────
  Widget _buildTrackingPanel(LiveVehicle v, {Key? key}) {
    final spots = v.speedHistory.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maxSpeed = v.speedHistory.isEmpty ? 10.0 : v.speedHistory.reduce(max).clamp(10.0, 200.0);

    return Container(
      key: key,
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
      ),
      child: Column(children: [
        // ── Dark header ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => setState(() { _isTracking = false; _mapInitialized = false; }),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
              Row(children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(_pulseAnim.value),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('LIVE TRACKING', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ]),
              Text(_lastUpdateLabel, style: GoogleFonts.inter(fontSize: 10, color: Colors.white54)),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v.id, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.person, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Text(v.driver, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
                ]),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(v.status).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(v.status).withOpacity(0.5)),
                ),
                child: Text(v.status, style: GoogleFonts.inter(color: _statusColor(v.status), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [

              // ── Speed + Fuel row ──
              Row(children: [
                Expanded(child: _buildLiveStatBox(
                  icon: Icons.speed,
                  iconColor: Colors.blue,
                  label: 'SPEED',
                  value: '${v.speed.toStringAsFixed(0)}',
                  unit: 'mph',
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildLiveStatBox(
                  icon: Icons.local_gas_station,
                  iconColor: v.fuel < 30 ? Colors.red : Colors.green,
                  label: 'FUEL',
                  value: '${v.fuel}',
                  unit: '%',
                  progress: v.fuel / 100,
                  progressColor: v.fuel < 30 ? Colors.red : Colors.green,
                )),
              ]),
              const SizedBox(height: 12),

              // ── ETA + Heading row ──
              Row(children: [
                Expanded(child: _buildLiveStatBox(
                  icon: Icons.timer_outlined,
                  iconColor: Colors.orange,
                  label: 'ETA',
                  value: v.eta,
                  unit: '',
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildLiveStatBox(
                  icon: Icons.explore_outlined,
                  iconColor: Colors.purple,
                  label: 'HEADING',
                  value: v.heading,
                  unit: '',
                )),
              ]),
              const SizedBox(height: 16),

              // ── Location ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(v.location, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: 10),

              // ── GPS Coordinates ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.satellite_alt, color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('GPS COORDINATES', style: GoogleFonts.robotoMono(fontSize: 9, color: Colors.white38, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(
                      '${v.lat.toStringAsFixed(5)}° N   ${v.lng.abs().toStringAsFixed(5)}° W',
                      style: GoogleFonts.robotoMono(fontSize: 13, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Speed history chart ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Speed History', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('Last 10 readings', style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: LineChart(LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true, reservedSize: 28,
                          getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                        )),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: 0, maxY: maxSpeed + 10,
                      lineBarsData: [LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: const Color(0xFF3B82F6),
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                            radius: spot == spots.last ? 4 : 2,
                            color: spot == spots.last ? const Color(0xFF3B82F6) : Colors.blue.shade200,
                            strokeWidth: 0,
                            strokeColor: Colors.transparent,
                          ),
                        ),
                        belowBarData: BarAreaData(show: true, color: const Color(0xFF3B82F6).withOpacity(0.08)),
                      )],
                    )),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Quick actions ──
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.route, size: 16),
                  label: Text('View Route', style: GoogleFonts.inter(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    side: const BorderSide(color: Color(0xFF3B82F6)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showRouteDialog(v),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.report_problem_outlined, size: 16),
                  label: Text('Report', style: GoogleFonts.inter(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showReportDialog(v),
                )),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildLiveStatBox({required IconData icon, required Color iconColor, required String label, required String value, required String unit, double? progress, Color? progressColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
          if (unit.isNotEmpty) ...[
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(unit, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        if (progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: progressColor,
              minHeight: 4,
            ),
          ),
        ],
      ]),
    );
  }

  // ─── Filter chip ─────────────────────────────────────────────────────────
  Widget _buildFilterChip(String label) {
    final isSelected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── Fleet item ───────────────────────────────────────────────────────────
  Widget _buildFleetItem(LiveVehicle v) {
    final isSelected = v.id == _selectedId;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedId = v.id;
        _isTracking = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFF1F5F9), width: isSelected ? 1.5 : 1),
        ),
        child: Column(children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _statusColor(v.status).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.directions_car, size: 20, color: _statusColor(v.status)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.id, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(v.location, style: GoogleFonts.inter(color: Colors.grey, fontSize: 11), overflow: TextOverflow.ellipsis),
            ])),
            Row(children: [
              if (v.status == 'MOVING')
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(_pulseAnim.value),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                Container(width: 7, height: 7, decoration: BoxDecoration(color: _statusColor(v.status), shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text(v.status, style: GoogleFonts.inter(color: _statusColor(v.status), fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ]),
          const SizedBox(height: 12),
          if (v.status == 'MAINTENANCE')
            Container(
              width: double.infinity, padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(4)),
              child: Text('MAINTENANCE IN PROGRESS', style: GoogleFonts.inter(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            )
          else
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildFleetStat(Icons.speed, '${v.speed.toStringAsFixed(0)} mph'),
              _buildFleetStat(Icons.local_gas_station, '${v.fuel}% fuel'),
              _buildFleetStat(Icons.timer_outlined, v.eta),
            ]),
          if (isSelected) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(color: Colors.red.withOpacity(_pulseAnim.value), shape: BoxShape.circle),
                  ),
                ),
                label: Text('TRACK LIVE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _startTracking(v),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildFleetStat(IconData icon, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: const Color(0xFF64748B)),
      const SizedBox(width: 4),
      Text(value, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _RouteDialogContent extends StatefulWidget {
  final LiveVehicle vehicle;
  final List<LatLng> routeHistory;
  const _RouteDialogContent({required this.vehicle, required this.routeHistory});
  @override
  State<_RouteDialogContent> createState() => _RouteDialogContentState();
}

class _RouteDialogContentState extends State<_RouteDialogContent> {
  final _mapCtrl = MapController();
  bool _mapReady = false;

  double _calcDistanceKm() {
    final pts = widget.routeHistory;
    if (pts.length < 2) return 0;
    const r = 6371.0;
    double total = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final lat1 = pts[i].latitude * pi / 180;
      final lat2 = pts[i + 1].latitude * pi / 180;
      final dLat = lat2 - lat1;
      final dLng = (pts[i + 1].longitude - pts[i].longitude) * pi / 180;
      final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
      total += r * 2 * atan2(sqrt(a), sqrt(1 - a));
    }
    return total;
  }

  void _fitRoute() {
    if (!_mapReady) return;
    final pts = widget.routeHistory;
    if (pts.isEmpty) return;
    if (pts.length == 1) { _mapCtrl.move(pts.first, 15); return; }
    try {
      _mapCtrl.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts),
        padding: const EdgeInsets.all(50),
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.routeHistory;
    final v = widget.vehicle;
    final distKm = _calcDistanceKm();
    final distLabel = distKm < 1 ? '${(distKm * 1000).toStringAsFixed(0)} m' : '${distKm.toStringAsFixed(2)} km';

    return SizedBox(
      width: 620, height: 540,
      child: Column(children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.route, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Route View — ${v.id}', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${v.driver}  ·  ${v.location}', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
            ])),
            // Stats chips
            if (pts.isNotEmpty) ...[
              _headerChip(Icons.pin_drop, '${pts.length} pts'),
              const SizedBox(width: 8),
              _headerChip(Icons.straighten, distLabel),
            ],
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        ),
        // ── Map ──
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16),
            ),
            child: Stack(children: [
              FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: LatLng(v.lat, v.lng),
                  initialZoom: 14,
                  onMapReady: () {
                    setState(() => _mapReady = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fleet.command',
                  ),
                  // Route polyline
                  if (pts.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(points: pts, color: const Color(0xFF3B82F6), strokeWidth: 4),
                    ]),
                  MarkerLayer(markers: [
                    if (pts.isNotEmpty) ...[
                      // Start marker (green)
                      Marker(
                        point: pts.first, width: 30, height: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green, shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                        ),
                      ),
                      // Current vehicle (animated blue)
                      Marker(
                        point: LatLng(v.lat, v.lng), width: 44, height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.18),
                          ),
                          child: Center(child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: v.status == 'MAINTENANCE' ? Colors.red : Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.local_shipping, color: Colors.white, size: 15),
                          )),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
              // Coordinates overlay
              Positioned(
                bottom: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.satellite_alt, color: Colors.greenAccent, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      '${v.lat.toStringAsFixed(5)}° N   ${v.lng.abs().toStringAsFixed(5)}° W',
                      style: GoogleFonts.robotoMono(fontSize: 11, color: Colors.greenAccent),
                    ),
                  ]),
                ),
              ),
              // Fit route FAB
              Positioned(
                top: 12, right: 12,
                child: FloatingActionButton.small(
                  heroTag: 'fitRoute',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  tooltip: 'Fit route in view',
                  onPressed: _fitRoute,
                  child: const Icon(Icons.fit_screen, size: 18),
                ),
              ),
              // No route hint
              if (pts.length <= 1)
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.route, color: Colors.grey, size: 28),
                    const SizedBox(height: 8),
                    Text('Route history is building…', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Keep tracking to record the path.', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                  ]),
                )),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _headerChip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white70, size: 12),
      const SizedBox(width: 5),
      Text(label, style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Incident Report Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ReportDialogContent extends StatefulWidget {
  final LiveVehicle vehicle;
  final int reportNumber;
  final void Function(Map<String, dynamic>) onSubmit;
  const _ReportDialogContent({required this.vehicle, required this.reportNumber, required this.onSubmit});
  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  String _incidentType = 'Breakdown';
  String _severity = 'Medium';
  bool _submitting = false;

  static const _incidentTypes = ['Breakdown', 'Accident', 'Fuel Issue', 'Driver Issue', 'Road Hazard', 'Suspicious Activity', 'Other'];
  static const _severities = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Color _severityColor(String s) {
    switch (s) {
      case 'Critical': return Colors.red;
      case 'High':     return Colors.orange;
      case 'Medium':   return Colors.amber;
      case 'Low':      return Colors.green;
      default:         return Colors.grey;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 600)); // simulate API call
    final now = DateTime.now();
    final report = {
      'id': 'INC-${widget.reportNumber.toString().padLeft(4, '0')}',
      'vehicle_id': widget.vehicle.id,
      'driver': widget.vehicle.driver,
      'location': widget.vehicle.location,
      'lat': widget.vehicle.lat,
      'lng': widget.vehicle.lng,
      'incident_type': _incidentType,
      'severity': _severity,
      'description': _descCtrl.text.trim(),
      'timestamp': '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}  ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
      'status': 'submitted',
    };
    if (mounted) Navigator.of(context).pop();
    widget.onSubmit(report);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    return SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.report_problem, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Incident Report', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${v.id}  ·  ${v.driver}  ·  INC-${widget.reportNumber.toString().padLeft(4, '0')}',
                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 11)),
              ])),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          // ── Body ──
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Pre-filled vehicle info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('VEHICLE INFO', style: GoogleFonts.inter(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _infoField('Location', v.location)),
                    const SizedBox(width: 16),
                    Expanded(child: _infoField('GPS', '${v.lat.toStringAsFixed(4)}° N  ${v.lng.abs().toStringAsFixed(4)}° W')),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _infoField('Speed', '${v.speed.toStringAsFixed(0)} mph')),
                    const SizedBox(width: 16),
                    Expanded(child: _infoField('Fuel', '${v.fuel}%')),
                  ]),
                ]),
              ),
              const SizedBox(height: 18),
              // Incident type chips
              Text('Incident Type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in _incidentTypes)
                  GestureDetector(
                    onTap: () => setState(() => _incidentType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _incidentType == t ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _incidentType == t ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(t, style: GoogleFonts.inter(
                        color: _incidentType == t ? Colors.white : const Color(0xFF64748B),
                        fontSize: 12, fontWeight: FontWeight.w500,
                      )),
                    ),
                  ),
              ]),
              const SizedBox(height: 18),
              // Severity buttons
              Text('Severity', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                for (int i = 0; i < _severities.length; i++) ...[
                  Expanded(child: GestureDetector(
                    onTap: () => setState(() => _severity = _severities[i]),
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: _severity == _severities[i] ? _severityColor(_severities[i]) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _severity == _severities[i] ? _severityColor(_severities[i]) : const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: Text(_severities[i], style: GoogleFonts.inter(
                        color: _severity == _severities[i] ? Colors.white : _severityColor(_severities[i]),
                        fontSize: 12, fontWeight: FontWeight.bold,
                      )),
                    ),
                  )),
                  if (i < _severities.length - 1) const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 18),
              // Description
              Text('Description', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe the incident in detail…',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                  contentPadding: const EdgeInsets.all(12),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please describe the incident' : null,
              ),
              const SizedBox(height: 20),
              // Submit
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.send, size: 16),
                          const SizedBox(width: 8),
                          Text('Submit Report', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                        ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoField(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
    Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
  ]);
}

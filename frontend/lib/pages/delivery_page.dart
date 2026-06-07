import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;
import '../constants.dart';

class Delivery {
  final int id;
  final int vehicleId;
  final String vehiclePlate;
  final String? vehicleModel;
  final String? driver;
  final double? departureLat;
  final double? departureLng;
  final String? departureName;
  final String? departureTime;
  final double destinationLat;
  final double destinationLng;
  final String? destinationName;
  final String status;
  final double? etaMinutes;
  final String? assignedAt;
  final String? arrivedAt;
  final String? deliveredAt;
  final String? notes;

  Delivery({
    required this.id, required this.vehicleId, required this.vehiclePlate,
    this.vehicleModel, this.driver,
    this.departureLat, this.departureLng, this.departureName, this.departureTime,
    required this.destinationLat, required this.destinationLng,
    this.destinationName,
    required this.status, this.etaMinutes, this.assignedAt, this.arrivedAt,
    this.deliveredAt, this.notes,
  });

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
    id: j['id'], vehicleId: j['vehicle_id'], vehiclePlate: j['vehicle_plate'],
    vehicleModel: j['vehicle_model'], driver: j['driver'],
    departureLat: j['departure_lat']?.toDouble(),
    departureLng: j['departure_lng']?.toDouble(),
    departureName: j['departure_name'],
    departureTime: j['departure_time'],
    destinationLat: (j['destination_lat'] as num).toDouble(),
    destinationLng: (j['destination_lng'] as num).toDouble(),
    destinationName: j['destination_name'], status: j['status'],
    etaMinutes: j['eta_minutes']?.toDouble(),
    assignedAt: j['assigned_at'], arrivedAt: j['arrived_at'],
    deliveredAt: j['delivered_at'], notes: j['notes'],
  );

  String get etaText {
    if (etaMinutes == null) return '—';
    if (etaMinutes! < 1) return '< 1 min';
    final h = etaMinutes! ~/ 60;
    final m = etaMinutes! % 60;
    if (h > 0) return '${h}h ${m.toInt()}min';
    return '${m.toInt()} min';
  }
}

class _VehicleOption {
  final int id;
  final String model;
  final String plate;
  final double lat;
  final double lng;
  _VehicleOption({required this.id, required this.model, required this.plate, required this.lat, required this.lng});
  String get label => '$model ($plate)';
}

class _SearchResult {
  final String displayName;
  final double lat;
  final double lng;
  _SearchResult({required this.displayName, required this.lat, required this.lng});
}

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  List<Delivery> _deliveries = [];
  final Set<int> _notifiedArrivalIds = {};
  final List<Delivery> _pendingArrivals = [];
  Timer? _pollTimer;
  Timer? _refreshTimer;
  Timer? _elapsedTimer;
  bool _loading = true;
  bool _formExpanded = false;
  List<_VehicleOption> _vehicles = [];

  // Stock state
  int _stockCurrent = 5000;
  int _stockTotal = 5000;
  int _stockPpv = 500;
  bool _stockLoading = true;

  final _formKey = GlobalKey<FormState>();
  _VehicleOption? _selectedVehicle;
  final _depNameCtrl = TextEditingController();
  final _destNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Map state
  final MapController _mapController = MapController();
  int _mapMode = 0; // 0 = departure, 1 = destination
  LatLng? _mapDeparture;
  LatLng? _mapDestination;
  bool _mapReady = false;

  // Search state
  final _searchCtrl = TextEditingController();
  List<_SearchResult> _searchResults = [];
  Timer? _searchDebounce;

  static const _statusColors = {
    'en_route': Color(0xFF3B82F6),
    'arrived': Color(0xFFF59E0B),
    'delivered': Color(0xFF10B981),
  };

  static const _statusIcons = {
    'en_route': Icons.route,
    'arrived': Icons.location_on,
    'delivered': Icons.check_circle,
  };

  @override
  void initState() {
    super.initState();
    _fetchAll();
    _fetchStock();
    _fetchVehicles();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) { _fetchAll(); _fetchStock(); });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollArrivals());
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refreshTimer?.cancel();
    _elapsedTimer?.cancel();
    _depNameCtrl.dispose();
    _destNameCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchVehicles() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/api/vehicles'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _vehicles = list.map((e) => _VehicleOption(
          id: e['id'], model: e['model'] ?? '', plate: e['plate'] ?? '',
          lat: (e['lat'] as num?)?.toDouble() ?? 0.0,
          lng: (e['lng'] as num?)?.toDouble() ?? 0.0,
        )).toList();
      }
    } catch (_) {}
  }

  void _onVehicleSelected(_VehicleOption? v) {
    setState(() {
      _selectedVehicle = v;
      if (v != null) {
        _mapDeparture = LatLng(v.lat, v.lng);
        _depNameCtrl.text = 'Dépôt ${v.plate}';
      }
    });
    if (v != null) _fitMapToBounds();
  }

  void _onMapTap(TapPosition tp, LatLng pos) {
    setState(() {
      if (_mapMode == 0) {
        _mapDeparture = pos;
      } else {
        _mapDestination = pos;
      }
    });
  }

  void _locateMe() {
    try {
      web.window.navigator.geolocation.getCurrentPosition(
        ((web.GeolocationPosition pos) {
          if (!mounted) return;
          final lat = pos.coords.latitude;
          final lng = pos.coords.longitude;
          setState(() {
            _mapDeparture = LatLng(lat, lng);
            _depNameCtrl.text = 'Ma position';
          });
          _fitMapToBounds();
        }).toJS,
        ((web.GeolocationPositionError err) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Géolocalisation refusée ou indisponible',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            duration: const Duration(seconds: 3),
          ));
        }).toJS,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Géolocalisation non supportée',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () => _searchAddress(q));
  }

  Future<void> _searchAddress(String q) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=5');
      final res = await http.get(uri, headers: {
        'User-Agent': 'FleetCommandApp/1.0',
      }).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _searchResults = list.map((e) => _SearchResult(
          displayName: e['display_name'] ?? '',
          lat: double.parse(e['lat'] ?? '0'),
          lng: double.parse(e['lon'] ?? '0'),
        )).toList();
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  void _selectSearchResult(_SearchResult r) {
    final pos = LatLng(r.lat, r.lng);
    setState(() {
      _mapDestination = pos;
      _destNameCtrl.text = r.displayName.split(',').first;
      _mapMode = 1;
      _searchCtrl.text = '';
      _searchResults = [];
    });
    _fitMapToBounds();
  }

  void _fitMapToBounds() {
    if (_mapDeparture == null && _mapDestination == null) return;
    if (!_mapReady) return;
    try {
      if (_mapDeparture != null && _mapDestination != null) {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([_mapDeparture!, _mapDestination!]),
          padding: const EdgeInsets.all(60),
        ));
      } else {
        _mapController.move(_mapDeparture ?? _mapDestination!, 13);
      }
    } catch (_) {}
  }

  Future<void> _createDelivery() async {
    if (!_formKey.currentState!.validate() || _selectedVehicle == null) return;
    if (_mapDeparture == null || _mapDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.orange,
        content: Text('Veuillez définir le départ et la destination sur la carte',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    try {
      final body = jsonEncode({
        'vehicle_id': _selectedVehicle!.id,
        'departure_lat': _mapDeparture!.latitude,
        'departure_lng': _mapDeparture!.longitude,
        'departure_name': _depNameCtrl.text.isNotEmpty ? _depNameCtrl.text : 'Départ',
        'destination_lat': _mapDestination!.latitude,
        'destination_lng': _mapDestination!.longitude,
        'destination_name': _destNameCtrl.text.isNotEmpty ? _destNameCtrl.text : 'Destination',
        'notes': _notesCtrl.text,
      });
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/deliveries'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 201) {
        _formKey.currentState!.reset();
        _selectedVehicle = null;
        _mapDeparture = null;
        _mapDestination = null;
        _depNameCtrl.clear();
        _destNameCtrl.clear();
        _notesCtrl.clear();
        _searchCtrl.clear();
        _searchResults = [];
        setState(() => _formExpanded = false);
        _fetchAll();
        // Déduire du stock
        try {
          await http.post(Uri.parse('$kApiBaseUrl/api/stock/decrement'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pieces': _stockPpv}),
          ).timeout(const Duration(seconds: 5));
          _fetchStock();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Livraison créée !', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text('Erreur lors de la création', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  Future<void> _fetchAll() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/api/deliveries'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => Delivery.fromJson(e)).toList();
        if (mounted) setState(() { _deliveries = list; _loading = false; });
      }
    } catch (_) {}
  }

  Future<void> _fetchStock() async {
    try {
      final res = await http.get(Uri.parse('$kApiBaseUrl/api/stock'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() {
          _stockCurrent = data['current_pieces'];
          _stockTotal = data['total_pieces'];
          _stockPpv = data['pieces_per_vehicle'];
          _stockLoading = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _pollArrivals() async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/api/deliveries/recent-arrivals?minutes=30'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final arrivals = (jsonDecode(res.body) as List)
            .map((e) => Delivery.fromJson(e))
            .where((d) => !_notifiedArrivalIds.contains(d.id))
            .toList();
        for (final a in arrivals) {
          _notifiedArrivalIds.add(a.id);
        }
        if (arrivals.isNotEmpty && mounted) {
          setState(() => _pendingArrivals.addAll(arrivals));
        }
      }
    } catch (_) {}
  }

  Future<void> _confirmDelivery(int id) async {
    try {
      final res = await http.put(
        Uri.parse('$kApiBaseUrl/api/deliveries/$id/confirm'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _fetchAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('Livraison confirmée !',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _cancelDelivery(int id) async {
    try {
      final res = await http.put(
        Uri.parse('$kApiBaseUrl/api/deliveries/$id/cancel'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _fetchAll();
        try {
          await http.post(Uri.parse('$kApiBaseUrl/api/stock/increment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pieces': _stockPpv}),
          ).timeout(const Duration(seconds: 5));
          _fetchStock();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFFF59E0B),
            content: Text('Livraison annulée',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteDelivery(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la livraison'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette livraison ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await http.delete(
        Uri.parse('$kApiBaseUrl/api/deliveries/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _fetchAll();
        try {
          await http.post(Uri.parse('$kApiBaseUrl/api/stock/increment'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pieces': _stockPpv}),
          ).timeout(const Duration(seconds: 5));
          _fetchStock();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Livraison supprimée',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (_) {}
  }

  void _showArrivalsDialog() {
    if (_pendingArrivals.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 8),
          Text('${_pendingArrivals.length} livraison(s) arrivée(s)',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
        ]),
        content: SizedBox(
          width: 400,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _pendingArrivals.length,
            itemBuilder: (_, i) {
              final a = _pendingArrivals[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a.vehicleModel ?? "Véhicule"} (${a.vehiclePlate})',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('→ ${a.destinationName ?? "Destination"}',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                  ])),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, size: 14),
                      label: Text('Confirmer', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmDelivery(a.id);
                        _pendingArrivals.removeAt(i);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDatetime(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso)?.toUtc();
  }

  double _distanceKm(LatLng a, LatLng b) {
    final dlat = (a.latitude - b.latitude) * 111.32;
    final mid = (a.latitude + b.latitude) / 2 * 3.14159 / 180;
    final dlng = (a.longitude - b.longitude) * 111.32 * math.cos(mid);
    return math.sqrt((dlat * dlat + dlng * dlng).abs());
  }

  @override
  Widget build(BuildContext context) {
    final enRoute = _deliveries.where((d) => d.status == 'en_route').length;
    final arrived = _deliveries.where((d) => d.status == 'arrived').length;
    final delivered = _deliveries.where((d) => d.status == 'delivered').length;

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Suivi des livraisons',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('Surveillez les arrivées automatiques et confirmez les livraisons',
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
              ])),
              Stack(children: [
                IconButton(
                  icon: Icon(_formExpanded ? Icons.expand_less : Icons.add_circle_outline,
                      color: const Color(0xFF3B82F6), size: 28),
                  onPressed: () => setState(() => _formExpanded = !_formExpanded),
                  tooltip: 'Nouvelle livraison',
                ),
              ]),
              const SizedBox(width: 4),
              Stack(children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Color(0xFF0F172A), size: 24),
                  onPressed: _pendingArrivals.isEmpty ? null : () => _showArrivalsDialog(),
                  tooltip: 'Arrivées',
                ),
                if (_pendingArrivals.isNotEmpty)
                  Positioned(
                    right: 4, top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text('${_pendingArrivals.length}',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center),
                    ),
                  ),
              ]),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _statCard('En route', '$enRoute', const Color(0xFF3B82F6), Icons.route),
              const SizedBox(width: 12),
              _statCard('Arrivées', '$arrived', const Color(0xFFF59E0B), Icons.location_on),
              const SizedBox(width: 12),
              _statCard('Livrées', '$delivered', const Color(0xFF10B981), Icons.check_circle),
            ]),
            const SizedBox(height: 16),
            _buildStockCard(),
          ]),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _deliveries.isEmpty && !_formExpanded
                  ? Center(child: Text('Aucune livraison', style: GoogleFonts.inter(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _deliveries.length + (_formExpanded ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (_formExpanded && i == 0) return _buildForm();
                        return _deliveryCard(_deliveries[i - (_formExpanded ? 1 : 0)]);
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _buildStockCard() {
    final pct = _stockTotal > 0 ? _stockCurrent / _stockTotal : 0.0;
    final color = pct <= 0.2 ? const Color(0xFFEF4444)
        : pct <= 0.4 ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);
    final alert = _stockCurrent <= 1000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alert ? const Color(0xFFEF4444).withValues(alpha: 0.5) : color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.inventory_2, size: 18, color: color),
          const SizedBox(width: 8),
          Text('Stock', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
          const Spacer(),
          if (_stockLoading)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text('$_stockCurrent / $_stockTotal pièces', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ]),
        const SizedBox(height: 10),
        if (!_stockLoading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${(_stockPpv * (_stockTotal - _stockCurrent) ~/ _stockPpv)} véhicule(s) parti(s)',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
            const Spacer(),
            Text('$_stockCurrent restants', style: GoogleFonts.inter(fontSize: 10, color: color)),
          ]),
        ],
        if (alert) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Rupture de stock prochainement ! Il ne reste que $_stockCurrent pièces.',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF991B1B)),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildForm() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.add_location, color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Text('Nouvelle livraison',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 16),

          DropdownButtonFormField<_VehicleOption>(
            key: ValueKey(_selectedVehicle?.id),
            initialValue: _selectedVehicle,
            decoration: _inputDec('Véhicule', Icons.local_shipping),
            items: _vehicles.map((v) => DropdownMenuItem(value: v, child: Text(v.label, style: GoogleFonts.inter(fontSize: 13)))).toList(),
            onChanged: _onVehicleSelected,
            validator: (v) => v == null ? 'Sélectionnez un véhicule' : null,
          ),
          const SizedBox(height: 16),

          _buildMapPicker(),
          const SizedBox(height: 16),

          TextFormField(
            controller: _depNameCtrl,
            decoration: _inputDec('Nom du départ', Icons.place),
            style: GoogleFonts.inter(fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _destNameCtrl,
            decoration: _inputDec('Nom de la destination', Icons.location_on),
            style: GoogleFonts.inter(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtrl,
            decoration: _inputDec('Notes (optionnel)', Icons.notes),
            style: GoogleFonts.inter(fontSize: 12),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: Text('Créer la livraison',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _createDelivery,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMapPicker() {
    final markers = <Marker>[];
    if (_mapDeparture != null) {
      markers.add(Marker(
        point: _mapDeparture!,
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => setState(() => _mapMode = 0),
          child: Container(
            decoration: BoxDecoration(
              color: _mapMode == 0
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF3B82F6).withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
            ),
            child: const Icon(Icons.trip_origin, color: Colors.white, size: 18),
          ),
        ),
      ));
    }
    if (_mapDestination != null) {
      markers.add(Marker(
        point: _mapDestination!,
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => setState(() => _mapMode = 1),
          child: Container(
            decoration: BoxDecoration(
              color: _mapMode == 1
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 18),
          ),
        ),
      ));
    }

    return Column(children: [
      // Geolocate + Search row
      Row(children: [
        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.my_location, size: 16),
            label: Text('Ma position', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: const BorderSide(color: Color(0xFF3B82F6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: _locateMe,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _searchCtrl,
          decoration: _inputDec('Rechercher une adresse', Icons.search),
          style: GoogleFonts.inter(fontSize: 12),
          onChanged: _onSearchChanged,
        )),
      ]),

      // Search results dropdown
      if (_searchResults.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
          ),
          constraints: const BoxConstraints(maxHeight: 180),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _searchResults.length,
            itemBuilder: (_, i) => InkWell(
              onTap: () => _selectSearchResult(_searchResults[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(_searchResults[i].displayName,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF0F172A)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        ),

      const SizedBox(height: 8),

      // Mode toggle chips
      Row(children: [
        _modeChip(0, 'Départ', const Color(0xFF3B82F6), Icons.trip_origin),
        const SizedBox(width: 8),
        _modeChip(1, 'Destination', const Color(0xFFF59E0B), Icons.location_on),
        const Spacer(),
        if (_mapDeparture != null || _mapDestination != null)
          SizedBox(
            height: 30,
            child: TextButton.icon(
              icon: const Icon(Icons.fit_screen, size: 16),
              label: Text('Ajuster', style: GoogleFonts.inter(fontSize: 10)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B), padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: _fitMapToBounds,
            ),
          ),
      ]),

      // Coordinate bar
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          if (_mapDeparture != null)
            Text('D: ${_mapDeparture!.latitude.toStringAsFixed(4)}, ${_mapDeparture!.longitude.toStringAsFixed(4)}',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF3B82F6))),
          if (_mapDeparture != null && _mapDestination != null)
            Text('  |  ${_distanceKm(_mapDeparture!, _mapDestination!).toStringAsFixed(1)} km  |  ',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
          if (_mapDestination != null)
            Text('A: ${_mapDestination!.latitude.toStringAsFixed(4)}, ${_mapDestination!.longitude.toStringAsFixed(4)}',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFF59E0B))),
        ]),
      ),

      // Map
      SizedBox(
        height: 280,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(36.8, 10.18),
              initialZoom: 5,
              onMapReady: () => setState(() => _mapReady = true),
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.fleet.command',
              ),
              if (_mapDeparture != null && _mapDestination != null)
                PolylineLayer(polylines: [
                  Polyline(
                    points: [_mapDeparture!, _mapDestination!],
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.5),
                    strokeWidth: 2,
                  ),
                ]),
              if (markers.isNotEmpty)
                MarkerLayer(markers: markers),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
      ),

      // Info text
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _mapMode == 0
              ? 'Cliquez sur la carte pour définir le départ, ou utilisez "Ma position"'
              : 'Cliquez sur la carte pour définir la destination',
          style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
        ),
      ),
    ]);
  }

  Widget _modeChip(int mode, String label, Color color, IconData icon) {
    final selected = _mapMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mapMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : const Color(0xFFE2E8F0), width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? color : const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: selected ? color : const Color(0xFF94A3B8),
          )),
        ]),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
        ]),
      ]),
    ));
  }

  Widget _deliveryCard(Delivery d) {
    final color = _statusColors[d.status] ?? Colors.grey;
    final icon = _statusIcons[d.status] ?? Icons.help_outline;
    final statusLabel = d.status == 'en_route' ? 'En route'
        : d.status == 'arrived' ? 'Arrivé'
        : d.status == 'delivered' ? 'Livré'
        : d.status;

    final depTime = _parseDatetime(d.departureTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d.vehicleModel ?? "Véhicule"} (${d.vehiclePlate})',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
            if (d.driver != null)
              Text('Chauffeur: ${d.driver}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
        ]),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.trip_origin, size: 14, color: Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                d.departureName ?? 'Départ',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
              )),
            ]),
            if (d.departureLat != null && d.departureLng != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                const SizedBox(width: 20),
                Text('${d.departureLat!.toStringAsFixed(4)}, ${d.departureLng!.toStringAsFixed(4)}',
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
              ]),
            ],
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.arrow_downward, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(depTime != null ? 'Départ ${depTime.toLocal().toString().substring(11, 16)}' : '',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.location_on, size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                d.destinationName ?? '${d.destinationLat.toStringAsFixed(4)}, ${d.destinationLng.toStringAsFixed(4)}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
              )),
            ]),
            if (d.status == 'en_route' && d.etaMinutes != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const SizedBox(width: 20),
                const Icon(Icons.access_time, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 4),
                Text('Arrivée estimée vers ${DateTime.now().toLocal().add(Duration(minutes: d.etaMinutes!.toInt())).toString().substring(11, 16)}',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
              ]),
            ],
          ]),
        ),

        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Expanded(child: Text(
            d.status == 'delivered'
                ? 'Livré le ${d.deliveredAt ?? "—"}'
                : d.status == 'cancelled'
                    ? 'Annulée'
                    : d.status == 'arrived'
                        ? 'Arrivé le ${d.arrivedAt ?? "—"}'
                        : d.etaMinutes != null
                            ? 'Arrivée vers ${DateTime.now().toLocal().add(Duration(minutes: d.etaMinutes!.toInt())).toString().substring(11, 16)}'
                            : 'Assigné le ${d.assignedAt ?? "—"}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          )),
        ]),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final today = DateTime.now();
              final todayStr = today.toIso8601String().substring(0, 10);
              final monthStr = todayStr.substring(0, 7);
              final yearStr = todayStr.substring(0, 4);
              final sameVehicle = _deliveries.where((x) => x.vehiclePlate == d.vehiclePlate);
              final todayCount = sameVehicle.where((x) {
                final dt = _parseDatetime(x.assignedAt);
                return dt != null && dt.toIso8601String().substring(0, 10) == todayStr;
              }).length;
              final monthCount = sameVehicle.where((x) {
                final dt = _parseDatetime(x.assignedAt);
                return dt != null && dt.toIso8601String().substring(0, 7) == monthStr;
              }).length;
              final yearCount = sameVehicle.where((x) {
                final dt = _parseDatetime(x.assignedAt);
                return dt != null && dt.toIso8601String().substring(0, 4) == yearStr;
              }).length;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  _vehicleStat(Icons.today, 'Aujourd\'hui', todayCount, const Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  _vehicleStat(Icons.date_range, 'Ce mois', monthCount, const Color(0xFF8B5CF6)),
                  const SizedBox(width: 12),
                  _vehicleStat(Icons.calendar_month, 'Cette année', yearCount, const Color(0xFF0F172A)),
                ]),
              );
            },
          ),
        ),

        const SizedBox(height: 8),
        Row(children: [
          if (d.status == 'en_route' || d.status == 'arrived')
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: Text('Annuler',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _cancelDelivery(d.id),
              ),
            ),
          if (d.status == 'arrived') ...[
            if (d.status == 'en_route' || d.status == 'arrived') const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 16),
                label: Text('Confirmer',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _confirmDelivery(d.id),
              ),
            ),
          ],
          if (d.status == 'delivered' || d.status == 'cancelled')
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text('Supprimer',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _deleteDelivery(d.id),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _vehicleStat(IconData icon, String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
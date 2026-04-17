import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';

import 'package:intl/intl.dart';



class TrajectoryPage extends StatefulWidget {

  const TrajectoryPage({super.key});



  @override

  State<TrajectoryPage> createState() => _TrajectoryPageState();

}



class _TrajectoryPageState extends State<TrajectoryPage> {

  // Données des véhicules

  List<VehicleTrajectory> vehicles = [];

  VehicleTrajectory? selectedVehicle;

 

  // Map + tab + date state
  final MapController _mapController = MapController();
  String _selectedTab = 'Route';
  DateTimeRange? _dateRange;
  int? _selectedSegment; // index into _routeSegments

  // Position de la carte (centrée sur le monde)
  LatLng mapCenter = const LatLng(20.0, 0.0);

  // Points de trajectoire
  List<LatLng> trajectoryPoints = [];

  // Segments de la route NYC → LA (indices dans trajectoryPoints)
  static const _routeSegments = [
    {
      'start': 'New York, NY',  'end': 'Baltimore, MD',
      'from': 0, 'to': 2,
      'date': 'Apr 14', 'time': '06:00 AM – 09:30 AM',
      'distance': '195 mi',    'duration': '3h 30m',
      'hasWarning': false,
    },
    {
      'start': 'Baltimore, MD', 'end': 'Charlotte, NC',
      'from': 2, 'to': 5,
      'date': 'Apr 14', 'time': '10:00 AM – 04:50 PM',
      'distance': '420 mi',    'duration': '6h 50m',
      'hasWarning': false,
    },
    {
      'start': 'Charlotte, NC', 'end': 'Memphis, TN',
      'from': 5, 'to': 8,
      'date': 'Apr 14', 'time': '05:30 PM – 02:45 AM',
      'distance': '570 mi',    'duration': '9h 15m',
      'hasWarning': false,
    },
    {
      'start': 'Memphis, TN',   'end': 'Albuquerque, NM',
      'from': 8, 'to': 11,
      'date': 'Apr 15', 'time': '03:30 AM – 08:00 PM',
      'distance': '1 050 mi',  'duration': '16h 30m',
      'hasWarning': true,
    },
    {
      'start': 'Albuquerque, NM', 'end': 'Los Angeles, CA',
      'from': 11, 'to': 13,
      'date': 'Apr 16', 'time': '09:00 AM – 09:40 PM',
      'distance': '790 mi',    'duration': '12h 40m',
      'hasWarning': false,
    },
  ];

 

  @override

  void initState() {

    super.initState();

    loadVehicles();

    loadTrajectoryData();

  }

 

  void loadVehicles() {

    vehicles = [

      VehicleTrajectory(
        id: "T-482",
        name: "Tesla Semi v2.0",
        plate: "NY-9904-TX",
        status: "ACTIVE",
        currentLocation: const LatLng(34.0522, -118.2437), // Los Angeles, USA
        temperature: 38,
        speed: 68,
        lastUpdate: DateTime.now(),
      ),

      VehicleTrajectory(
        id: "T-483",
        name: "Mercedes Sprinter",
        plate: "UK-1123-VN",
        status: "MAINTENANCE",
        currentLocation: const LatLng(51.5074, -0.1278), // London, UK
        temperature: 42,
        speed: 0,
        lastUpdate: DateTime.now(),
      ),

      VehicleTrajectory(
        id: "T-484",
        name: "Ford Transit XL",
        plate: "DXB-4400-LP",
        status: "IDLE",
        currentLocation: const LatLng(25.2048, 55.2708), // Dubai, UAE
        temperature: 40,
        speed: 45,
        lastUpdate: DateTime.now(),
      ),

    ];

    selectedVehicle = vehicles.first;

  }

 

  void loadTrajectoryData() {

    trajectoryPoints = [
      const LatLng(40.7128, -74.0060),  // New York, NY
      const LatLng(39.9526, -75.1652),  // Philadelphia, PA
      const LatLng(39.2904, -76.6122),  // Baltimore, MD
      const LatLng(38.9072, -77.0369),  // Washington DC
      const LatLng(37.5407, -77.4360),  // Richmond, VA
      const LatLng(35.2271, -80.8431),  // Charlotte, NC
      const LatLng(33.7490, -84.3880),  // Atlanta, GA
      const LatLng(33.4484, -86.8103),  // Birmingham, AL
      const LatLng(35.1495, -90.0490),  // Memphis, TN
      const LatLng(35.4676, -97.5164),  // Oklahoma City, OK
      const LatLng(35.2220, -101.8313), // Amarillo, TX
      const LatLng(35.0844, -106.6504), // Albuquerque, NM
      const LatLng(33.4484, -112.0740), // Phoenix, AZ
      const LatLng(34.0522, -118.2437), // Los Angeles, CA
    ];

  }

 

  String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • HH:mm:ss').format(date);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _dateRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked != null && mounted) setState(() => _dateRange = picked);
  }

  void _exportLog() {
    final vehicle = selectedVehicle?.id ?? 'unknown';
    final start = _dateRange != null ? DateFormat('yyyy-MM-dd').format(_dateRange!.start) : 'all';
    final end = _dateRange != null ? DateFormat('yyyy-MM-dd').format(_dateRange!.end) : 'time';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Export Trajectory Log'),
        content: Text('Exporting trajectory for $vehicle\nPeriod: $start → $end\n\nFormat: CSV'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Exported trajectory_${vehicle}_$start.csv'), backgroundColor: const Color(0xFF22C55E)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

 

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF1F5F9),

      body: Column(

        children: [

          // AppBar avec recherche

          Container(

            color: Colors.white,

            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),

            child: Row(

              children: [

                const Text(
                  'Trajectory Tracker',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const Spacer(),

                // Date range & export
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(_dateRange == null ? 'Date Range' : '${DateFormat('MMM dd').format(_dateRange!.start)} – ${DateFormat('MMM dd').format(_dateRange!.end)}', style: const TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2563EB), side: const BorderSide(color: Color(0xFF2563EB))),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _exportLog,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Log', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                ),

              ],

            ),

          ),

         

          // Contenu principal

          Expanded(

            child: SingleChildScrollView(

              padding: const EdgeInsets.all(24),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  // Sélecteur de véhicule

                  Container(

                    margin: const EdgeInsets.only(bottom: 20),

                    child: Row(

                      children: [

                        const Text(

                          'Vehicle: ',

                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),

                        ),

                        const SizedBox(width: 12),

                        ...vehicles.map((vehicle) => Padding(

                          padding: const EdgeInsets.only(right: 12),

                          child: FilterChip(

                            label: Text(vehicle.id),

                            selected: selectedVehicle?.id == vehicle.id,

                            onSelected: (selected) {

                              setState(() {

                                selectedVehicle = vehicle;

                                mapCenter = vehicle.currentLocation;

                              });

                              _mapController.move(vehicle.currentLocation, 5);

                            },

                            backgroundColor: Colors.white,

                            selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.1),

                            checkmarkColor: const Color(0xFF2563EB),

                            labelStyle: TextStyle(

                              color: selectedVehicle?.id == vehicle.id ? const Color(0xFF2563EB) : const Color(0xFF64748B),

                              fontWeight: selectedVehicle?.id == vehicle.id ? FontWeight.w600 : FontWeight.normal,

                            ),

                          ),

                        )).toList(),

                      ],

                    ),

                  ),

                 

                  // Carte et informations

                  Row(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      // COLONNE CARTE

                      Expanded(

                        flex: 2,

                        child: Column(

                          children: [

                            // Titre de la carte

                            Container(

                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

                              decoration: BoxDecoration(

                                color: Colors.white,

                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),

                                border: Border.all(color: const Color(0xFFE2E8F0)),

                              ),

                              child: Row(

                                children: [

                                  const Icon(Icons.map, size: 20, color: Color(0xFF2563EB)),

                                  const SizedBox(width: 8),

                                  const Text(

                                    'TRAJECTORY VIEW',

                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),

                                  ),

                                  const Spacer(),

                                  Container(

                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                                    decoration: BoxDecoration(

                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),

                                      borderRadius: BorderRadius.circular(12),

                                    ),

                                    child: Row(

                                      mainAxisSize: MainAxisSize.min,

                                      children: [

                                        const Icon(Icons.thermostat, size: 14, color: Color(0xFF2563EB)),

                                        const SizedBox(width: 4),

                                        Text(

                                          '${selectedVehicle?.temperature ?? 0}°F',

                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),

                                        ),

                                      ],

                                    ),

                                  ),

                                ],

                              ),

                            ),

                           

                            // ── Carte monde réelle ─────────────────────────
                            Container(
                              height: 540,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                child: Stack(children: [
                                  // ── Fond OSM ──────────────────────────────
                                  FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: mapCenter,
                                      initialZoom: 2.0,
                                      interactionOptions: const InteractionOptions(
                                        flags: InteractiveFlag.all,
                                      ),
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName: 'com.fleet.command',
                                      ),
                                      // Halo de la route
                                      if (trajectoryPoints.isNotEmpty)
                                        PolylineLayer(polylines: [
                                          Polyline(
                                            points: trajectoryPoints,
                                            color: Colors.blue.withOpacity(0.22),
                                            strokeWidth: 10,
                                          ),
                                        ]),
                                      // Route principale
                                      if (trajectoryPoints.isNotEmpty)
                                        PolylineLayer(polylines: [
                                          Polyline(
                                            points: trajectoryPoints,
                                            color: const Color(0xFF2563EB),
                                            strokeWidth: 3.5,
                                          ),
                                        ]),
                                      // Segment sélectionné (surligné en jaune)
                                      if (_selectedSegment != null && trajectoryPoints.isNotEmpty)
                                        PolylineLayer(polylines: [
                                          Polyline(
                                            points: trajectoryPoints.sublist(
                                              _routeSegments[_selectedSegment!]['from'] as int,
                                              (_routeSegments[_selectedSegment!]['to'] as int) + 1,
                                            ),
                                            color: const Color(0xFFF59E0B),
                                            strokeWidth: 6,
                                          ),
                                        ]),
                                      // Waypoints intermédiaires
                                      if (trajectoryPoints.length > 2)
                                        MarkerLayer(
                                          markers: trajectoryPoints
                                              .sublist(1, trajectoryPoints.length - 1)
                                              .map((pt) => Marker(
                                                    point: pt,
                                                    width: 10, height: 10,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.white,
                                                        border: Border.all(color: const Color(0xFF2563EB), width: 2),
                                                      ),
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      // Tous les véhicules
                                      MarkerLayer(
                                        markers: vehicles.map((v) {
                                          final isSel = selectedVehicle?.id == v.id;
                                          final color = v.status == 'ACTIVE'
                                              ? const Color(0xFF22C55E)
                                              : v.status == 'MAINTENANCE'
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFFF59E0B);
                                          return Marker(
                                            point: v.currentLocation,
                                            width: isSel ? 48 : 36,
                                            height: isSel ? 48 : 36,
                                            child: GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  selectedVehicle = v;
                                                  mapCenter = v.currentLocation;
                                                });
                                                _mapController.move(v.currentLocation, 5);
                                              },
                                              child: Tooltip(
                                                message: '${v.id} · ${v.name}\n${v.status} · ${v.speed} km/h',
                                                preferBelow: false,
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 200),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: color,
                                                    border: Border.all(color: Colors.white, width: isSel ? 3 : 2),
                                                    boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: isSel ? 14 : 5)],
                                                  ),
                                                  child: Icon(Icons.local_shipping, color: Colors.white, size: isSel ? 24 : 17),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      // Marqueur départ
                                      if (trajectoryPoints.isNotEmpty)
                                        MarkerLayer(markers: [
                                          Marker(
                                            point: trajectoryPoints.first,
                                            width: 32, height: 32,
                                            child: Container(
                                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E)),
                                              child: const Icon(Icons.trip_origin, size: 16, color: Colors.white),
                                            ),
                                          ),
                                        ]),
                                      // Marqueur arrivée
                                      if (trajectoryPoints.isNotEmpty)
                                        MarkerLayer(markers: [
                                          Marker(
                                            point: trajectoryPoints.last,
                                            width: 32, height: 32,
                                            child: Container(
                                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444)),
                                              child: const Icon(Icons.flag_rounded, size: 16, color: Colors.white),
                                            ),
                                          ),
                                        ]),
                                    ],
                                  ),

                                  // ── Contrôles zoom ────────────────────────
                                  Positioned(
                                    top: 12, right: 12,
                                    child: Column(children: [
                                      _mapCtrlBtn(Icons.add, () => _mapController.move(
                                          _mapController.camera.center, _mapController.camera.zoom + 1)),
                                      const SizedBox(height: 4),
                                      _mapCtrlBtn(Icons.remove, () => _mapController.move(
                                          _mapController.camera.center, _mapController.camera.zoom - 1)),
                                      const SizedBox(height: 4),
                                      _mapCtrlBtn(Icons.fit_screen, () {
                                        if (trajectoryPoints.isNotEmpty) {
                                          _mapController.fitCamera(CameraFit.bounds(
                                            bounds: LatLngBounds.fromPoints(trajectoryPoints),
                                            padding: const EdgeInsets.all(48),
                                          ));
                                        } else {
                                          _mapController.move(const LatLng(20, 0), 2);
                                        }
                                      }),
                                      const SizedBox(height: 4),
                                      _mapCtrlBtn(Icons.my_location, () =>
                                          _mapController.move(selectedVehicle?.currentLocation ?? const LatLng(20, 0), 5)),
                                    ]),
                                  ),

                                  // ── Légende ───────────────────────────────
                                  Positioned(
                                    bottom: 12, left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.92),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
                                      ),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                        const Text('LEGEND', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 1)),
                                        const SizedBox(height: 6),
                                        _legendRow(Icons.local_shipping, 'Active',      const Color(0xFF22C55E)),
                                        _legendRow(Icons.local_shipping, 'Maintenance', const Color(0xFFEF4444)),
                                        _legendRow(Icons.local_shipping, 'Idle',        const Color(0xFFF59E0B)),
                                        const SizedBox(height: 4),
                                        _legendRow(Icons.trip_origin,  'Start', const Color(0xFF22C55E)),
                                        _legendRow(Icons.flag_rounded, 'End',   const Color(0xFFEF4444)),
                                      ]),
                                    ),
                                  ),

                                  // ── GPS overlay ───────────────────────────
                                  Positioned(
                                    bottom: 12, right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.65),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${(selectedVehicle?.currentLocation.latitude ?? 0).toStringAsFixed(4)}°N  '
                                        '${(selectedVehicle?.currentLocation.longitude ?? 0).toStringAsFixed(4)}°E',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),

                           

                            const SizedBox(height: 16),

                           

                            // Informations du véhicule

                            Container(

                              padding: const EdgeInsets.all(16),

                              decoration: BoxDecoration(

                                color: Colors.white,

                                borderRadius: BorderRadius.circular(12),

                                border: Border.all(color: const Color(0xFFE2E8F0)),

                              ),

                              child: Row(

                                children: [

                                  Expanded(

                                    child: Column(

                                      crossAxisAlignment: CrossAxisAlignment.start,

                                      children: [

                                        Text(

                                          '${selectedVehicle?.id ?? "Vehicle"} History',

                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),

                                        ),

                                        const SizedBox(height: 8),

                                        Row(

                                          children: [

                                            _buildTabButton("Route", Icons.route),

                                            const SizedBox(width: 8),

                                            _buildTabButton("Stops", Icons.stop_circle),

                                            const SizedBox(width: 8),

                                            _buildTabButton("Events", Icons.event),

                                          ],

                                        ),

                                      ],

                                    ),

                                  ),

                                  Column(

                                    crossAxisAlignment: CrossAxisAlignment.end,

                                    children: [

                                      Text(

                                        formatDate(selectedVehicle?.lastUpdate ?? DateTime.now()),

                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),

                                      ),

                                      const SizedBox(height: 4),

                                      Row(

                                        children: [

                                          const Icon(Icons.speed, size: 16, color: Color(0xFF64748B)),

                                          const SizedBox(width: 4),

                                          Text(

                                            '${selectedVehicle?.speed ?? 0} MPH',

                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),

                                          ),

                                        ],

                                      ),

                                    ],

                                  ),

                                ],

                              ),

                            ),

                          ],

                        ),

                      ),

                     

                      const SizedBox(width: 24),

                     

                      // COLONNE DE DROITE (STATISTIQUES)

                      SizedBox(

                        width: 320,

                        child: Column(

                          children: [

                            // PERIOD SUMMARY

                            Container(

                              padding: const EdgeInsets.all(16),

                              decoration: BoxDecoration(

                                color: Colors.white,

                                borderRadius: BorderRadius.circular(12),

                                border: Border.all(color: const Color(0xFFE2E8F0)),

                              ),

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  const Text(

                                    'PERIOD SUMMARY',

                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),

                                  ),

                                  const SizedBox(height: 16),

                                  Row(

                                    children: [

                                      Expanded(

                                        child: Column(

                                          crossAxisAlignment: CrossAxisAlignment.start,

                                          children: [

                                            const Text(

                                              'TOTAL DISTANCE',

                                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),

                                            ),

                                            const SizedBox(height: 4),

                                            const Text(

                                              '2 825 mi',

                                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),

                                            ),

                                            const SizedBox(height: 4),

                                            Container(

                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),

                                              decoration: BoxDecoration(

                                                color: const Color(0xFF22C55E).withValues(alpha: 0.1),

                                                borderRadius: BorderRadius.circular(12),

                                              ),

                                              child: const Text(

                                                '72% ↑',

                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF22C55E)),

                                              ),

                                            ),

                                            const Text(

                                              'FROM LAST WEEK',

                                              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),

                                            ),

                                          ],

                                        ),

                                      ),

                                      const SizedBox(width: 16),

                                      const Expanded(

                                        child: Column(

                                          crossAxisAlignment: CrossAxisAlignment.start,

                                          children: [

                                            Text(

                                              'AVG SPEED',

                                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),

                                            ),

                                            SizedBox(height: 4),

                                            Text(

                                              '58.4 MPH',

                                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),

                                            ),

                                            SizedBox(height: 4),

                                            Text(

                                              '↑ 12%',

                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF22C55E)),

                                            ),

                                          ],

                                        ),

                                      ),

                                    ],

                                  ),

                                ],

                              ),

                            ),

                           

                            const SizedBox(height: 20),

                           

                            // ACTIVE SEGMENTS

                            Container(

                              padding: const EdgeInsets.all(16),

                              decoration: BoxDecoration(

                                color: Colors.white,

                                borderRadius: BorderRadius.circular(12),

                                border: Border.all(color: const Color(0xFFE2E8F0)),

                              ),

                              child: Column(

                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [

                                  Row(children: [
                                    const Text(
                                      'ROUTE SEGMENTS',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_routeSegments.length} legs',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ]),

                                  const SizedBox(height: 12),

                                  // Liste dynamique des segments
                                  ...List.generate(_routeSegments.length, (i) {
                                    final seg = _routeSegments[i];
                                    final isSel = _selectedSegment == i;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildSegmentCard(
                                        index: i,
                                        isSelected: isSel,
                                        start: seg['start'] as String,
                                        end:   seg['end']   as String,
                                        date:  seg['date']  as String,
                                        time:  seg['time']  as String,
                                        distance: seg['distance'] as String,
                                        duration: seg['duration'] as String,
                                        hasWarning: seg['hasWarning'] as bool,
                                        onTap: () {
                                          final from = seg['from'] as int;
                                          final to   = seg['to']   as int;
                                          setState(() => _selectedSegment = isSel ? null : i);
                                          if (!isSel && trajectoryPoints.isNotEmpty) {
                                            final pts = trajectoryPoints.sublist(from, to + 1);
                                            _mapController.fitCamera(CameraFit.bounds(
                                              bounds: LatLngBounds.fromPoints(pts),
                                              padding: const EdgeInsets.all(60),
                                            ));
                                          }
                                        },
                                      ),
                                    );
                                  }),

                                ],

                              ),

                            ),

                          ],

                        ),

                      ),

                    ],

                  ),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }

 

  Widget _buildTabButton(String label, IconData icon) {
    final isSelected = _selectedTab == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

 

  Widget _buildSegmentCard({
    required int index,
    required bool isSelected,
    required String start,
    required String end,
    required String date,
    required String time,
    required String distance,
    required String duration,
    bool hasWarning = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$start → $end',
                    style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,
                      color: isSelected ? const Color(0xFFD97706) : const Color(0xFF1E293B),
                    )),
              ),
              if (isSelected)
                const Icon(Icons.location_searching, size: 14, color: Color(0xFFF59E0B)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.calendar_today, size: 10, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              const SizedBox(width: 12),
              const Icon(Icons.access_time, size: 10, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Flexible(child: Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.straighten, size: 11, color: Color(0xFF94A3B8)),
                const SizedBox(width: 3),
                Text(distance, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, size: 11, color: Color(0xFF94A3B8)),
                const SizedBox(width: 3),
                Text(duration, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              ]),
              if (hasWarning)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_amber, size: 10, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text('Long Stop Detected (45m)',
                        style: TextStyle(fontSize: 9, color: Color(0xFF92400E))),
                  ]),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Helpers carte ─────────────────────────────────────────────────────────
  Widget _mapCtrlBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF1E293B)),
    ),
  );

  Widget _legendRow(IconData icon, String label, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

}



// Modèle de données

class VehicleTrajectory {

  final String id;

  final String name;

  final String plate;

  final String status;

  final LatLng currentLocation;

  final double temperature;

  final double speed;

  final DateTime lastUpdate;

 

  VehicleTrajectory({

    required this.id,

    required this.name,

    required this.plate,

    required this.status,

    required this.currentLocation,

    required this.temperature,

    required this.speed,

    required this.lastUpdate,

  });

}
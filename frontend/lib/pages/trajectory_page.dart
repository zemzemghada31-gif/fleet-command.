import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../mock_data.dart';
import '../nav_service.dart';

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
  DateTime? _startDate;
  DateTime? _baseDate;
  int? _selectedSegment;
  int? _tappedIndex;

  // Routes par véhicule (plate → RouteData)
  final Map<String, RouteData> _routesData = {};

  // Idle vehicles (not on route) — sourced from mock_data.dart
  final Set<String> _idlePlates = kIdlePlates;

  // Simulation de mouvement
  Timer? _simTimer;
  final Map<String, double> _vehicleProgress = {};
  final Map<String, List<LatLng>> _vehicleRoutes = {};

  LatLng get _mapCenter => selectedVehicle?.currentLocation ?? const LatLng(20.0, 0.0);

 

  @override

  void initState() {

    super.initState();

    loadTrajectoryData();
    loadVehicles();
    _initBaseDate();
    _simTimer = Timer.periodic(const Duration(seconds: 2), _simulateMovement);

  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

 

  void loadTrajectoryData() {
    _routesData['BT-904-TX'] = RouteData(
      points: [
        const LatLng(40.7128, -74.0060),  const LatLng(39.9526, -75.1652),
        const LatLng(39.2904, -76.6122),  const LatLng(38.9072, -77.0369),
        const LatLng(37.5407, -77.4360),  const LatLng(35.2271, -80.8431),
        const LatLng(33.7490, -84.3880),  const LatLng(33.4484, -86.8103),
        const LatLng(35.1495, -90.0490),  const LatLng(35.4676, -97.5164),
        const LatLng(35.2220, -101.8313), const LatLng(35.0844, -106.6504),
        const LatLng(33.4484, -112.0740), const LatLng(34.0522, -118.2437),
      ],
      cityNames: const [
        'New York, NY', 'Philadelphia, PA', 'Baltimore, MD', 'Washington DC',
        'Richmond, VA', 'Charlotte, NC', 'Atlanta, GA', 'Birmingham, AL',
        'Memphis, TN', 'Oklahoma City, OK', 'Amarillo, TX', 'Albuquerque, NM',
        'Phoenix, AZ', 'Los Angeles, CA',
      ],
      segments: const [
        {'start': 'New York, NY',  'end': 'Baltimore, MD',  'from': 0, 'to': 2,  'date': 'Apr 14', 'time': '06:00 AM – 09:30 AM',  'distance': '195 mi',  'duration': '3h 30m', 'hasWarning': false},
        {'start': 'Baltimore, MD', 'end': 'Charlotte, NC',  'from': 2, 'to': 5,  'date': 'Apr 14', 'time': '10:00 AM – 04:50 PM', 'distance': '420 mi',  'duration': '6h 50m', 'hasWarning': false},
        {'start': 'Charlotte, NC', 'end': 'Memphis, TN',    'from': 5, 'to': 8,  'date': 'Apr 14', 'time': '05:30 PM – 02:45 AM', 'distance': '570 mi',  'duration': '9h 15m', 'hasWarning': false},
        {'start': 'Memphis, TN',   'end': 'Albuquerque, NM','from': 8, 'to': 11, 'date': 'Apr 15', 'time': '03:30 AM – 08:00 PM', 'distance': '1 050 mi','duration': '16h 30m','hasWarning': true},
        {'start': 'Albuquerque, NM','end': 'Los Angeles, CA','from': 11, 'to': 13,'date': 'Apr 16', 'time': '09:00 AM – 09:40 PM', 'distance': '790 mi',  'duration': '12h 40m','hasWarning': false},
      ],
    );

    _routesData['CA-123-VN'] = RouteData(
      points: [
        const LatLng(51.5074, -0.1278),  const LatLng(52.4862, -1.8904),
        const LatLng(53.4808, -2.2426),   const LatLng(53.8008, -1.5491),
        const LatLng(54.9783, -1.6178),   const LatLng(55.9533, -3.1883),
      ],
      cityNames: const [
        'London, UK', 'Birmingham, UK', 'Manchester, UK',
        'Leeds, UK', 'Newcastle, UK', 'Edinburgh, UK',
      ],
      segments: const [
        {'start': 'London, UK',     'end': 'Birmingham, UK', 'from': 0, 'to': 1, 'date': 'Apr 14', 'time': '08:00 AM – 10:30 AM', 'distance': '120 mi', 'duration': '2h 30m', 'hasWarning': false},
        {'start': 'Birmingham, UK', 'end': 'Manchester, UK', 'from': 1, 'to': 2, 'date': 'Apr 14', 'time': '11:00 AM – 01:00 PM', 'distance': '90 mi',  'duration': '2h 00m', 'hasWarning': false},
        {'start': 'Manchester, UK', 'end': 'Leeds, UK',      'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '01:30 PM – 03:00 PM', 'distance': '45 mi',  'duration': '1h 30m', 'hasWarning': false},
        {'start': 'Leeds, UK',      'end': 'Newcastle, UK',  'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '03:30 PM – 06:00 PM', 'distance': '100 mi', 'duration': '2h 30m', 'hasWarning': true},
        {'start': 'Newcastle, UK',  'end': 'Edinburgh, UK',  'from': 4, 'to': 5, 'date': 'Apr 15', 'time': '08:00 AM – 10:30 AM', 'distance': '110 mi', 'duration': '2h 30m', 'hasWarning': false},
      ],
    );

    _routesData['TX-4409-LP'] = RouteData(
      points: [
        const LatLng(25.2048, 55.2708),  const LatLng(25.3463, 55.4209),
        const LatLng(25.4052, 55.5136),  const LatLng(25.7895, 55.9432),
        const LatLng(25.1288, 56.3265),
      ],
      cityNames: const [
        'Dubai, UAE', 'Sharjah, UAE', 'Ajman, UAE',
        'Ras Al Khaimah, UAE', 'Fujairah, UAE',
      ],
      segments: const [
        {'start': 'Dubai, UAE',         'end': 'Sharjah, UAE',         'from': 0, 'to': 1, 'date': 'Apr 14', 'time': '07:00 AM – 08:00 AM', 'distance': '20 mi', 'duration': '1h 00m', 'hasWarning': false},
        {'start': 'Sharjah, UAE',       'end': 'Ajman, UAE',           'from': 1, 'to': 2, 'date': 'Apr 14', 'time': '08:15 AM – 09:00 AM', 'distance': '10 mi', 'duration': '0h 45m', 'hasWarning': false},
        {'start': 'Ajman, UAE',         'end': 'Ras Al Khaimah, UAE',  'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '09:30 AM – 11:30 AM', 'distance': '55 mi', 'duration': '2h 00m', 'hasWarning': false},
        {'start': 'Ras Al Khaimah, UAE','end': 'Fujairah, UAE',        'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '12:00 PM – 02:00 PM', 'distance': '50 mi', 'duration': '2h 00m', 'hasWarning': true},
      ],
    );

    _routesData['ZZ-123-ZZ'] = RouteData(
      points: [
        const LatLng(25.7617, -80.1918),  const LatLng(28.5383, -81.3792),
        const LatLng(30.3322, -81.6557),  const LatLng(32.0809, -81.0912),
        const LatLng(35.2271, -80.8431),  const LatLng(36.1627, -86.7816),
        const LatLng(39.7684, -86.1581),  const LatLng(41.8781, -87.6298),
      ],
      cityNames: const [
        'Miami, FL', 'Orlando, FL', 'Jacksonville, FL',
        'Savannah, GA', 'Charlotte, NC', 'Nashville, TN',
        'Indianapolis, IN', 'Chicago, IL',
      ],
      segments: const [
        {'start': 'Miami, FL',     'end': 'Orlando, FL',       'from': 0, 'to': 1, 'date': 'Apr 14', 'time': '06:00 AM – 08:30 AM', 'distance': '235 mi', 'duration': '2h 30m', 'hasWarning': false},
        {'start': 'Orlando, FL',   'end': 'Jacksonville, FL',  'from': 1, 'to': 2, 'date': 'Apr 14', 'time': '09:00 AM – 11:00 AM', 'distance': '140 mi', 'duration': '2h 00m', 'hasWarning': false},
        {'start': 'Jacksonville, FL','end': 'Savannah, GA',    'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '11:30 AM – 01:30 PM', 'distance': '140 mi', 'duration': '2h 00m', 'hasWarning': false},
        {'start': 'Savannah, GA',  'end': 'Charlotte, NC',    'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '02:00 PM – 05:00 PM', 'distance': '200 mi', 'duration': '3h 00m', 'hasWarning': false},
        {'start': 'Charlotte, NC', 'end': 'Nashville, TN',    'from': 4, 'to': 5, 'date': 'Apr 15', 'time': '08:00 AM – 12:00 PM', 'distance': '330 mi', 'duration': '4h 00m', 'hasWarning': true},
        {'start': 'Nashville, TN', 'end': 'Indianapolis, IN', 'from': 5, 'to': 6, 'date': 'Apr 15', 'time': '01:00 PM – 05:00 PM', 'distance': '290 mi', 'duration': '4h 00m', 'hasWarning': false},
        {'start': 'Indianapolis, IN','end': 'Chicago, IL',    'from': 6, 'to': 7, 'date': 'Apr 15', 'time': '06:00 PM – 09:00 PM', 'distance': '180 mi', 'duration': '3h 00m', 'hasWarning': false},
      ],
    );

    _routesData['PY-456-RT'] = RouteData(
      points: [
        const LatLng(37.7749, -122.4194), const LatLng(38.5816, -121.4944),
        const LatLng(45.5152, -122.6784), const LatLng(47.6062, -122.3321),
      ],
      cityNames: const [
        'San Francisco, CA', 'Sacramento, CA',
        'Portland, OR', 'Seattle, WA',
      ],
      segments: const [
        {'start': 'San Francisco, CA', 'end': 'Sacramento, CA', 'from': 0, 'to': 1, 'date': 'Apr 14', 'time': '07:00 AM – 09:00 AM', 'distance': '90 mi', 'duration': '2h 00m', 'hasWarning': false},
        {'start': 'Sacramento, CA',    'end': 'Portland, OR',    'from': 1, 'to': 2, 'date': 'Apr 14', 'time': '09:30 AM – 05:30 PM', 'distance': '580 mi', 'duration': '8h 00m', 'hasWarning': false},
        {'start': 'Portland, OR',      'end': 'Seattle, WA',     'from': 2, 'to': 3, 'date': 'Apr 15', 'time': '07:00 AM – 10:00 AM', 'distance': '175 mi', 'duration': '3h 00m', 'hasWarning': false},
      ],
    );

    _routesData['CI-789-YU'] = RouteData(
      points: [
        const LatLng(29.7604, -95.3698),  const LatLng(32.7767, -96.7970),
        const LatLng(35.4676, -97.5164),  const LatLng(37.6872, -97.3301),
        const LatLng(39.7392, -104.9903),
      ],
      cityNames: const [
        'Houston, TX', 'Dallas, TX',
        'Oklahoma City, OK', 'Wichita, KS', 'Denver, CO',
      ],
      segments: const [
        {'start': 'Houston, TX',      'end': 'Dallas, TX',          'from': 0, 'to': 1, 'date': 'Apr 14', 'time': '06:00 AM – 09:30 AM', 'distance': '240 mi', 'duration': '3h 30m', 'hasWarning': false},
        {'start': 'Dallas, TX',       'end': 'Oklahoma City, OK',   'from': 1, 'to': 2, 'date': 'Apr 14', 'time': '10:00 AM – 01:30 PM', 'distance': '210 mi', 'duration': '3h 30m', 'hasWarning': false},
        {'start': 'Oklahoma City, OK','end': 'Wichita, KS',         'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '02:00 PM – 05:00 PM', 'distance': '165 mi', 'duration': '3h 00m', 'hasWarning': false},
        {'start': 'Wichita, KS',      'end': 'Denver, CO',          'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '06:00 PM – 11:30 PM', 'distance': '425 mi', 'duration': '5h 30m', 'hasWarning': true},
      ],
    );

    _routesData['VB-101-PO'] = RouteData(
      points: [
        const LatLng(52.5200, 13.4050),  const LatLng(52.5365, 13.3850),
        const LatLng(53.0793, 8.8017),   const LatLng(51.2277, 6.7735),
        const LatLng(50.9375, 6.9603),
      ],
      cityNames: const ['Berlin', 'Berlin-Spandau', 'Bremen', 'Düsseldorf', 'Cologne'],
      segments: const [
        {'start': 'Berlin',      'end': 'Bremen',     'from': 0, 'to': 2, 'date': 'Apr 14', 'time': '06:00 AM – 09:30 AM',  'distance': '200 mi', 'duration': '3h 30m', 'hasWarning': false},
        {'start': 'Bremen',      'end': 'Düsseldorf', 'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '10:00 AM – 01:00 PM',  'distance': '180 mi', 'duration': '3h 00m', 'hasWarning': false},
        {'start': 'Düsseldorf',  'end': 'Cologne',    'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '03:00 PM – 03:30 PM',  'distance': '25 mi',  'duration': '0h 30m', 'hasWarning': true},
      ],
    );

    _routesData['FI-202-IK'] = RouteData(
      points: [
        const LatLng(41.9028, 12.4964),  const LatLng(41.9250, 12.4850),
        const LatLng(43.7696, 11.2558),  const LatLng(45.4642, 9.1900),
        const LatLng(45.0703, 7.6869),
      ],
      cityNames: const ['Rome', 'Rome-Nord', 'Florence', 'Milan', 'Turin'],
      segments: const [
        {'start': 'Rome',     'end': 'Florence',  'from': 0, 'to': 2, 'date': 'Apr 14', 'time': '07:00 AM – 10:00 AM',  'distance': '175 mi', 'duration': '3h 00m', 'hasWarning': false},
        {'start': 'Florence', 'end': 'Milan',     'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '11:00 AM – 02:30 PM',  'distance': '190 mi', 'duration': '3h 30m', 'hasWarning': false},
        {'start': 'Milan',    'end': 'Turin',     'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '03:00 PM – 04:30 PM',  'distance': '85 mi',  'duration': '1h 30m', 'hasWarning': false},
      ],
    );

    _routesData['NN-303-LP'] = RouteData(
      points: [
        const LatLng(35.6762, 139.6503),  const LatLng(35.6800, 139.7000),
        const LatLng(35.1815, 136.9066),  const LatLng(35.0116, 135.7681),
        const LatLng(34.6901, 135.1955),
      ],
      cityNames: const ['Tokyo', 'Tokyo-Est', 'Nagoya', 'Kyoto', 'Kobe'],
      segments: const [
        {'start': 'Tokyo',  'end': 'Nagoya',  'from': 0, 'to': 2, 'date': 'Apr 14', 'time': '08:00 AM – 10:30 AM',  'distance': '160 mi', 'duration': '2h 30m', 'hasWarning': false},
        {'start': 'Nagoya', 'end': 'Kyoto',   'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '11:00 AM – 12:15 PM',  'distance': '75 mi',  'duration': '1h 15m', 'hasWarning': false},
        {'start': 'Kyoto',  'end': 'Kobe',    'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '01:00 PM – 02:00 PM',  'distance': '45 mi',  'duration': '1h 00m', 'hasWarning': true},
      ],
    );

    _routesData['TY-404-ER'] = RouteData(
      points: [
        const LatLng(51.5074, -0.1278),  const LatLng(51.5100, -0.1500),
        const LatLng(51.4545, -2.5879),  const LatLng(51.4816, -3.1791),
        const LatLng(53.4084, -2.9916),
      ],
      cityNames: const ['London', 'London-Ouest', 'Bristol', 'Cardiff', 'Liverpool'],
      segments: const [
        {'start': 'London',  'end': 'Bristol',   'from': 0, 'to': 2, 'date': 'Apr 14', 'time': '09:00 AM – 11:15 AM',  'distance': '120 mi', 'duration': '2h 15m', 'hasWarning': false},
        {'start': 'Bristol', 'end': 'Cardiff',   'from': 2, 'to': 3, 'date': 'Apr 14', 'time': '12:00 PM – 01:00 PM',  'distance': '45 mi',  'duration': '1h 00m', 'hasWarning': false},
        {'start': 'Cardiff', 'end': 'Liverpool', 'from': 3, 'to': 4, 'date': 'Apr 14', 'time': '02:00 PM – 05:00 PM',  'distance': '140 mi', 'duration': '3h 00m', 'hasWarning': true},
      ],
    );
  }

  void loadVehicles() {
    vehicles = [
      VehicleTrajectory(id: "T-482", name: "Mercedes-Benz Actros",  plate: "BT-904-TX", status: "MOVING",     currentLocation: const LatLng(40.7128, -74.0060), temperature: 38, speed: 68, lastUpdate: DateTime.now(), driverName: 'Marc Dubois'),
      VehicleTrajectory(id: "T-483", name: "Scania R-Series",        plate: "CA-123-VN", status: "MAINTENANCE", currentLocation: const LatLng(51.5074, -0.1278),  temperature: 42, speed: 0,  lastUpdate: DateTime.now(), driverName: 'James Carter'),
      VehicleTrajectory(id: "T-484", name: "Volvo FH",               plate: "TX-4409-LP", status: "IDLE",       currentLocation: const LatLng(25.2048, 55.2708),  temperature: 40, speed: 0,  lastUpdate: DateTime.now(), driverName: 'Ahmed Al-Rashid'),
      VehicleTrajectory(id: "T-485", name: "MAN TGX",                plate: "ZZ-123-ZZ", status: "MOVING",     currentLocation: const LatLng(25.7617, -80.1918), temperature: 36, speed: 72, lastUpdate: DateTime.now(), driverName: 'Sarah Johnson'),
      VehicleTrajectory(id: "T-486", name: "DAF XF",                 plate: "PY-456-RT", status: "MOVING",     currentLocation: const LatLng(37.7749, -122.4194), temperature: 30, speed: 55, lastUpdate: DateTime.now(), driverName: 'Carlos Mendez'),
      VehicleTrajectory(id: "T-487", name: "Renault Trucks T",       plate: "CI-789-YU", status: "MOVING",     currentLocation: const LatLng(29.7604, -95.3698), temperature: 44, speed: 58, lastUpdate: DateTime.now(), driverName: 'Kevin Brooks'),
      VehicleTrajectory(id: "T-488", name: "Mercedes-Benz Arocs",    plate: "VB-101-PO", status: "IDLE",       currentLocation: const LatLng(52.5200, 13.4050),  temperature: 37, speed: 0,  lastUpdate: DateTime.now(), driverName: 'Hans Schmidt'),
      VehicleTrajectory(id: "T-489", name: "Scania G-Series",        plate: "FI-202-IK", status: "MOVING",     currentLocation: const LatLng(41.9028, 12.4964),  temperature: 41, speed: 71, lastUpdate: DateTime.now(), driverName: 'Luigi Rossi'),
      VehicleTrajectory(id: "T-490", name: "Volvo FM",               plate: "NN-303-LP", status: "MOVING",     currentLocation: const LatLng(35.6762, 139.6503), temperature: 35, speed: 48, lastUpdate: DateTime.now(), driverName: 'Yuki Tanaka'),
      VehicleTrajectory(id: "T-491", name: "MAN TGS",                plate: "TY-404-ER", status: "IDLE",       currentLocation: const LatLng(51.5074, -0.1278),  temperature: 39, speed: 0,  lastUpdate: DateTime.now(), driverName: 'James Wilson'),
    ];

    selectedVehicle = vehicles.first;

    _vehicleRoutes.clear();
    _vehicleProgress.clear();
    for (final v in vehicles) {
      final rd = _routesData[v.plate];
      if (rd != null) {
        _vehicleRoutes[v.plate] = List<LatLng>.from(rd.points);
        _vehicleProgress[v.plate] = 0.0;
        v.currentLocation = rd.points.first;
        v.speed = rd.points.length > 5 ? 55.0 + (rd.points.length * 2) : 35.0;
        if (_idlePlates.contains(v.plate)) {
          v.speed = 0;
          v.status = _idlePlates.contains(v.plate) && v.plate == 'CA-123-VN' ? 'MAINTENANCE' : 'IDLE';
        }
      }
    }
  }

  void _simulateMovement(Timer _) {
    if (!mounted || vehicles.isEmpty) return;
    setState(() {
      for (final v in vehicles) {
        if (_idlePlates.contains(v.plate)) continue;
        final route = _vehicleRoutes[v.plate];
        if (route == null || route.length < 2) continue;
        double progress = _vehicleProgress[v.plate] ?? 0;
        progress += 0.025 + (v.speed / 3000);
        if (progress >= route.length - 1) progress = 0;
        _vehicleProgress[v.plate] = progress;
        final seg = progress.floor();
        final frac = progress - seg;
        final idx = (seg + 1).clamp(0, route.length - 1);
        final p1 = route[seg];
        final p2 = route[idx];
        final lat = p1.latitude + (p2.latitude - p1.latitude) * frac;
        final lng = p1.longitude + (p2.longitude - p1.longitude) * frac;
        v.currentLocation = LatLng(lat, lng);
        v.lastUpdate = DateTime.now();
        v.status = 'MOVING';
      }
    });
  }

 

  String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • HH:mm:ss').format(date);
  }

  void _onMapTap(LatLng pos) {
    final rd = _routesData[selectedVehicle?.plate];
    if (rd == null || rd.points.isEmpty) return;
    double minDist = double.infinity;
    int nearest = 0;
    for (int i = 0; i < rd.points.length; i++) {
      final d = _distance(pos, rd.points[i]);
      if (d < minDist) { minDist = d; nearest = i; }
    }
    if (minDist > 5.0) return;
    setState(() => _tappedIndex = nearest);
    _showPointInfo(nearest);
  }

  double _distance(LatLng a, LatLng b) {
    final dlat = (a.latitude - b.latitude) * 111.32;
    final dlng = (a.longitude - b.longitude) * 111.32 * math.cos(_deg2rad(a.latitude));
    return dlat * dlat + dlng * dlng;
  }

  double _deg2rad(double deg) => deg * math.pi / 180.0;

  String _remainingTime(int fromIndex, double speedMph) {
    if (speedMph <= 0) return '—';
    final rd = _routesData[selectedVehicle?.plate];
    if (rd == null) return '—';
    double totalMiles = 0;
    for (int i = fromIndex; i < rd.points.length - 1; i++) {
      totalMiles += _haversineMiles(rd.points[i], rd.points[i + 1]);
    }
    final hours = totalMiles / speedMph;
    if (hours < 1) return '${(hours * 60).round()} min';
    return '${hours.toStringAsFixed(1)} h';
  }

  double _haversineMiles(LatLng a, LatLng b) {
    const R = 3958.8;
    final dlat = _deg2rad(b.latitude - a.latitude);
    final dlon = _deg2rad(b.longitude - a.longitude);
    final x = _deg2rad(a.latitude);
    final y = _deg2rad(b.latitude);
    final aa = math.sin(dlat / 2) * math.sin(dlat / 2) +
        math.cos(x) * math.cos(y) * math.sin(dlon / 2) * math.sin(dlon / 2);
    return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  }

  void _showPointInfo(int index) {
    final v = selectedVehicle;
    final rd = _routesData[v?.plate];
    if (v == null || rd == null) return;
    final city = index < rd.cityNames.length ? rd.cityNames[index] : 'Position $index';
    final speed = v.speed;
    final remaining = _remainingTime(index, speed);
    final dest = rd.cityNames.last;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.location_on, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(child: Text(city, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)))),
            ]),
            const Divider(height: 24),
            _infoRow(Icons.speed, 'Vitesse', '$speed mph'),
            _infoRow(Icons.person, 'Chauffeur', v.driverName),
            _infoRow(Icons.local_shipping, 'Véhicule', '${v.plate} · ${v.name}'),
            _infoRow(Icons.timer_outlined, 'Temps restant', remaining),
            _infoRow(Icons.flag, 'Destination', dest),
          ],
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        SizedBox(width: 120, child: Text('$label :', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)))),
      ]),
    );
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? _baseDate ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDate: initial,
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  DateTime? _parseSegmentDate(String dateStr) {
    const months = {'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12};
    final parts = dateStr.split(' ');
    if (parts.length != 2) return null;
    final month = months[parts[0]];
    final day = int.tryParse(parts[1]);
    if (month == null || day == null) return null;
    return DateTime(now.year, month, day);
  }

  String _formatSegmentDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _getShiftedDate(String originalDate) {
    if (_startDate == null || _baseDate == null) return originalDate;
    final parsed = _parseSegmentDate(originalDate);
    if (parsed == null) return originalDate;
    final diff = _startDate!.difference(_baseDate!).inDays;
    final shifted = parsed.add(Duration(days: diff));
    return _formatSegmentDate(shifted);
  }

  DateTime get now => DateTime.now();

  void _initBaseDate() {
    final rd = _routesData[selectedVehicle?.plate];
    if (rd != null && rd.segments.isNotEmpty) {
      final firstDateStr = rd.segments.first['date'] as String;
      _baseDate = _parseSegmentDate(firstDateStr);
    }
  }

  void _exportLog() {
    final vehicle = selectedVehicle?.id ?? 'unknown';
    final start = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'all';
    final end = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : 'time';
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

  Widget _buildTabContent() {
    if (selectedVehicle == null) return const SizedBox.shrink();
    switch (_selectedTab) {
      case 'Stops':
        return _buildStopsContent();
      case 'Events':
        return _buildEventsContent();
      default:
        return _buildRouteContent();
    }
  }

  Widget _buildRouteContent() {
    final rd = _routesData[selectedVehicle?.plate];
    if (rd == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${selectedVehicle?.plate} · ${rd.cityNames.first} → ${rd.cityNames.last}',
           style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
      const SizedBox(height: 8),
      const Text('SEGMENTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
      const SizedBox(height: 6),
      ...List.generate(rd.segments.length, (i) {
        final seg = rd.segments[i];
        final dateStr = (_startDate != null && _baseDate != null)
            ? _getShiftedDate(seg['date'] as String)
            : seg['date'] as String;
        final isSelected = _selectedSegment == i;
        return _buildSegmentCard(
          index: i,
          isSelected: isSelected,
          start: seg['start'] as String,
          end: seg['end'] as String,
          date: dateStr,
          time: seg['time'] as String,
          distance: seg['distance'] as String,
          duration: seg['duration'] as String,
          hasWarning: seg['hasWarning'] as bool,
          onTap: () => setState(() {
            _selectedSegment = isSelected ? null : i;
            final from = seg['from'] as int;
            final to = (seg['to'] as int) + 1;
            if (from < rd.points.length && to <= rd.points.length) {
              _mapController.fitCamera(CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(rd.points.sublist(from, to)),
                padding: const EdgeInsets.all(60),
              ));
            }
          }),
        );
      }),
    ]);
  }

  List<Map<String, String>> _stopsForVehicle(String plate) {
    final stops = kStopsForVehicle(plate);
    if (stops.isEmpty) return [];
    return stops.map((s) => {
      'city': s['city'] as String,
      'type': s['type'] as String,
      'time': s['time'] as String,
    }).toList();
  }

  Widget _buildStopsContent() {
    final stops = _stopsForVehicle(selectedVehicle?.plate ?? '');
    if (stops.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No stops for this route.', style: TextStyle(color: Color(0xFF94A3B8))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ARRÊTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
      const SizedBox(height: 6),
      ...stops.map((s) => Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          Icon(s['type'] == 'Fuel Stop' ? Icons.local_gas_station : s['type'] == 'Rest Break' ? Icons.free_breakfast : s['type'] == 'Cargo Check' ? Icons.inventory : Icons.warning_amber, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(child: Text('${s['city']}', style: const TextStyle(fontSize: 10, color: Color(0xFF475569)))),
          Text('${s['type']} · ${s['time']}', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
        ]),
      )),
    ]);
  }

  Widget _buildEventsContent() {
    final events = _eventsForVehicle(selectedVehicle?.plate ?? '');
    if (events.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No events for this route.', style: TextStyle(color: Color(0xFF94A3B8))));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ÉVÉNEMENTS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.8)),
      const SizedBox(height: 6),
      ...events.map((e) => Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Color(e['bgColor'] as int),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Color(e['borderColor'] as int)),
        ),
        child: Row(children: [
          Icon(e['icon'] as IconData, size: 14, color: Color(e['iconColor'] as int)),
          const SizedBox(width: 6),
          Expanded(child: Text(e['text'] as String, style: TextStyle(fontSize: 10, color: Color(e['textColor'] as int)))),
        ]),
      )),
    ]);
  }

  List<Map<String, dynamic>> _eventsForVehicle(String plate) {
    const allEvents = <String, List<Map<String, dynamic>>>{
      'BT-904-TX': [
        {'icon': Icons.warning_amber_rounded, 'iconColor': 0xFFF59E0B, 'bgColor': 0xFFFFFBEB, 'borderColor': 0xFFFDE68A, 'textColor': 0xFF92400E, 'text': 'Long Stop Detected (45m) — Scranton, PA'},
        {'icon': Icons.check_circle, 'iconColor': 0xFF22C55E, 'bgColor': 0xFFF0FDF4, 'borderColor': 0xFFBBF7D0, 'textColor': 0xFF166534, 'text': 'Cargo delivered on time — Chicago, IL'},
        {'icon': Icons.speed, 'iconColor': 0xFFEF4444, 'bgColor': 0xFFFEF2F2, 'borderColor': 0xFFFECACA, 'textColor': 0xFF991B1B, 'text': 'Speed alert — 89 mph on I-80, Illinois'},
      ],
      'CA-123-VN': [
        {'icon': Icons.warning_amber_rounded, 'iconColor': 0xFFF59E0B, 'bgColor': 0xFFFFFBEB, 'borderColor': 0xFFFDE68A, 'textColor': 0xFF92400E, 'text': 'Maintenance programmée — Engine Overhaul'},
      ],
      'TX-4409-LP': [
        {'icon': Icons.local_gas_station, 'iconColor': 0xFF2563EB, 'bgColor': 0xFFEFF6FF, 'borderColor': 0xFFBFDBFE, 'textColor': 0xFF1E40AF, 'text': 'Fuel efficiency optimal — 22 MPG on highway'},
      ],
      'ZZ-123-ZZ': [
        {'icon': Icons.check_circle, 'iconColor': 0xFF22C55E, 'bgColor': 0xFFF0FDF4, 'borderColor': 0xFFBBF7D0, 'textColor': 0xFF166534, 'text': 'On-time departure — Miami Terminal'},
        {'icon': Icons.warning_amber_rounded, 'iconColor': 0xFFF59E0B, 'bgColor': 0xFFFFFBEB, 'borderColor': 0xFFFDE68A, 'textColor': 0xFF92400E, 'text': 'Weather alert — Heavy rain near Nashville'},
      ],
      'PY-456-RT': [
        {'icon': Icons.speed, 'iconColor': 0xFFEF4444, 'bgColor': 0xFFFEF2F2, 'borderColor': 0xFFFECACA, 'textColor': 0xFF991B1B, 'text': 'Overspeed warning — US-101 South, 78 mph'},
      ],
      'CI-789-YU': [
        {'icon': Icons.check_circle, 'iconColor': 0xFF22C55E, 'bgColor': 0xFFF0FDF4, 'borderColor': 0xFFBBF7D0, 'textColor': 0xFF166534, 'text': 'Border crossing cleared — Texas-Oklahoma line'},
        {'icon': Icons.warning_amber_rounded, 'iconColor': 0xFFF59E0B, 'bgColor': 0xFFFFFBEB, 'borderColor': 0xFFFDE68A, 'textColor': 0xFF92400E, 'text': 'Construction zone — I-35 near Wichita'},
      ],
      'VB-101-PO': [
        {'icon': Icons.warning_amber_rounded, 'iconColor': 0xFFF59E0B, 'bgColor': 0xFFFFFBEB, 'borderColor': 0xFFFDE68A, 'textColor': 0xFF92400E, 'text': 'Traffic jam — A2 near Hanover, 30 min delay'},
      ],
      'FI-202-IK': [
        {'icon': Icons.speed, 'iconColor': 0xFFEF4444, 'bgColor': 0xFFFEF2F2, 'borderColor': 0xFFFECACA, 'textColor': 0xFF991B1B, 'text': 'Speed alert — 145 km/h on A1, Florence sector'},
      ],
      'NN-303-LP': [
        {'icon': Icons.warning_amber_rounded, 'iconColor': 0xFFF59E0B, 'bgColor': 0xFFFFFBEB, 'borderColor': 0xFFFDE68A, 'textColor': 0xFF92400E, 'text': 'Hard brake detected — Tomei Expressway, near Yokohama'},
      ],
      'TY-404-ER': [
        {'icon': Icons.build, 'iconColor': 0xFF0369A1, 'bgColor': 0xFFF0F9FF, 'borderColor': 0xFFBAE6FD, 'textColor': 0xFF0369A1, 'text': 'Brake wear detected — service advised at Liverpool depot'},
      ],
    };
    return allEvents[plate] ?? [];
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF1E293B)),
    ),
  );

  List<Widget> _buildRouteLayers() {
    final rd = _routesData[selectedVehicle?.plate];
    if (rd == null || rd.points.length < 2) return [];

    return [
      PolylineLayer(
        polylines: [
          Polyline(
            points: rd.points,
            color: const Color(0xFF2563EB).withValues(alpha: 0.5),
            strokeWidth: 3,
          ),
        ],
      ),
      // Points cliquables le long de la route
      MarkerLayer(
        markers: List.generate(rd.points.length, (i) {
          final isTapped = _tappedIndex == i;
          return Marker(
            point: rd.points[i],
            width: isTapped ? 32 : 28,
            height: isTapped ? 32 : 28,
            child: GestureDetector(
              onTap: () => _onMapTap(rd.points[i]),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTapped ? const Color(0xFF2563EB).withValues(alpha: 0.3) : Colors.transparent,
                  border: Border.all(
                    color: isTapped ? const Color(0xFF2563EB) : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isTapped
                    ? const Center(child: Icon(Icons.location_on, size: 16, color: Color(0xFF2563EB)))
                    : null,
              ),
            ),
          );
        }),
      ),
      // Marqueurs départ / arrivée
      MarkerLayer(
        markers: [
          Marker(
            point: rd.points.first,
            width: 36, height: 36,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
              ),
              child: const Center(child: Icon(Icons.flag, size: 16, color: Colors.white)),
            ),
          ),
          Marker(
            point: rd.points.last,
            width: 36, height: 36,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
              ),
              child: const Center(child: Icon(Icons.flag, size: 16, color: Colors.white)),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (NavService.instance.needsNavigation) {
      final match = vehicles.cast<VehicleTrajectory?>().firstWhere(
        (v) => v?.plate == NavService.instance.targetPlate,
        orElse: () => null,
      );
      if (match != null) {
        Future.microtask(() {
          if (mounted) setState(() => selectedVehicle = match);
          NavService.instance.consume();
        });
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 28, 12, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('TRAJECTORY MAP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Real-time fleet tracking & route monitoring', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              ),
              _mapCtrlBtn(Icons.calendar_month, _pickStartDate),
              const SizedBox(width: 8),
              _mapCtrlBtn(Icons.download, _exportLog),
            ],
          ),
          const SizedBox(height: 20),

          // Map
          Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 2.5,
                    onTap: (tp, pos) => _onMapTap(pos),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fleetcommand.app',
                    ),
                    ..._buildRouteLayers(),
                    MarkerLayer(
                      markers: vehicles.map((v) {
                        final isSelected = v == selectedVehicle;
                        return Marker(
                          point: v.currentLocation,
                          width: isSelected ? 40 : 32,
                          height: isSelected ? 40 : 32,
                          child: GestureDetector(
                            onTap: () => setState(() { selectedVehicle = v; _initBaseDate(); }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                                border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A)).withValues(alpha: isSelected ? 0.5 : 0.3),
                                    blurRadius: isSelected ? 12 : 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(Icons.near_me, size: isSelected ? 18 : 14, color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Zoom controls
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(children: [
                    _mapCtrlBtn(Icons.add, () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                    const SizedBox(height: 4),
                    _mapCtrlBtn(Icons.remove, () => _mapController.move(_mapController.camera.center, (_mapController.camera.zoom - 1).clamp(1, 18))),
                  ]),
                ),

                // Locate vehicle button
                if (selectedVehicle != null)
                  Positioned(
                    right: 12,
                    bottom: 80,
                    child: _mapCtrlBtn(Icons.my_location, () {
                      _mapController.move(selectedVehicle!.currentLocation, 6);
                    }),
                  ),

                // Bottom gradient overlay
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                      ),
                    ),
                  ),
                ),

                // Vehicle info overlay
                if (selectedVehicle != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(selectedVehicle!.status).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(selectedVehicle!.status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${selectedVehicle!.plate} · ${selectedVehicle!.name}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('${selectedVehicle!.driverName} · ${selectedVehicle!.speed.toStringAsFixed(0)} mph', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${vehicles.length} en route', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle selector
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final v = vehicles[i];
                final isSelected = v == selectedVehicle;
                return GestureDetector(
                  onTap: () => setState(() { selectedVehicle = v; _initBaseDate(); }),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _statusColor(v.status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(child: Icon(Icons.local_shipping, size: 18, color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(v.plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B))),
                              const SizedBox(height: 2),
                              Text('${v.speed.toStringAsFixed(0)} mph · ${v.status}',
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Bottom panel: tabs + content
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tab bar
                Row(
                  children: ['Route', 'Stops', 'Events'].map((tab) {
                    final active = _selectedTab == tab;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTab = tab),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: active ? const Color(0xFF2563EB) : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          tab.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: active ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                // Tab content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTabContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'MOVING':
      case 'ACTIVE':
        return const Color(0xFF22C55E);
      case 'IDLE':
        return const Color(0xFFF59E0B);
      case 'MAINTENANCE':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }
}



// Modèle de données

class VehicleTrajectory {
  final String id;
  final String name;
  final String plate;
  String status;
  LatLng currentLocation;
  final double temperature;
  double speed;
  DateTime lastUpdate;
  String driverName;

  VehicleTrajectory({
    required this.id,
    required this.name,
    required this.plate,
    required this.status,
    required this.currentLocation,
    required this.temperature,
    required this.speed,
    required this.lastUpdate,
    this.driverName = 'Inconnu',
  });
}

class RouteData {
  final List<LatLng> points;
  final List<String> cityNames;
  final List<Map<String, dynamic>> segments;

  RouteData({
    required this.points,
    required this.cityNames,
    required this.segments,
  });
}
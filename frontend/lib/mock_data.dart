// ignore_for_file: unnecessary_const, prefer_const_constructors
import 'dart:math';
import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

// =============================================================================
// DONNEES CENTRALISEES ET CONSISTANTES
// Toutes les pages utilisent ces memes donnees quand le backend est hors ligne.
// =============================================================================

// ─── VEHICULES (correspondent aux seed data du backend) ─────────────────────
class MockVehicle {
  final int id;
  final String model;
  final String plate;
  final String status;
  final String tracker;
  final double lat;
  final double lng;
  final double speed;
  final int fuel;
  final String driver;
  final String eta;
  final String heading;

  const MockVehicle({
    required this.id,
    required this.model,
    required this.plate,
    required this.status,
    this.tracker = 'Not Assigned',
    this.lat = 40.7128,
    this.lng = -74.0060,
    this.speed = 0,
    this.fuel = 80,
    this.driver = 'Unassigned',
    this.eta = '—',
    this.heading = '—',
  });
}

const List<MockVehicle> kMockVehicles = [
  MockVehicle(id: 1, model: 'Mercedes-Benz Actros',   plate: '123-TUN-45', status: 'ACTIVE',     tracker: 'X-9941-ALPHA', lat: 41.8781, lng: -87.6298, speed: 68, fuel: 92, driver: 'Marcus Reed',   eta: '4.2H TO GO', heading: 'NE'),
  MockVehicle(id: 2, model: 'Scania R-Series',        plate: '456-NBL-78', status: 'MAINTENANCE', tracker: 'X-7703-GAMMA', lat: 37.3382, lng: -121.8863, speed: 0,  fuel: 44, driver: 'Sarah Kim',     eta: 'OFFLOADING',  heading: '—'),
  MockVehicle(id: 3, model: 'Volvo FH',               plate: '789-SF-01',status: 'IDLE',       tracker: 'X-1001-BETA',  lat: 37.7749, lng: -122.4194, speed: 0,  fuel: 88, driver: 'Kevin Park',    eta: 'LOADING',     heading: '—'),
  MockVehicle(id: 4, model: 'MAN TGX',                plate: '111-ARI-22', status: 'ACTIVE',     tracker: 'X-7705-EPSILON', lat: 48.8566, lng: 2.3522, speed: 45, fuel: 76, driver: 'Pierre Dubois', eta: '2.1H TO GO', heading: 'SE'),
  MockVehicle(id: 5, model: 'DAF XF',                 plate: '333-BEN-44', status: 'ACTIVE',     tracker: 'X-8821-GAMMA', lat: 45.7640, lng: 4.8357, speed: 52, fuel: 61, driver: 'Marie Laurent', eta: '1.8H TO GO', heading: 'SW'),
  MockVehicle(id: 6, model: 'Renault Trucks T',       plate: '555-MON-66', status: 'IDLE',       tracker: 'X-8824-ZETA',  lat: 43.6047, lng: 1.4442, speed: 0,  fuel: 95, driver: 'Jean Moreau',   eta: '—',          heading: '—'),
  MockVehicle(id: 7, model: 'Mercedes-Benz Arocs',    plate: '777-SUS-88', status: 'MAINTENANCE', tracker: 'X-7701-ALPHA', lat: 52.5200, lng: 13.4050, speed: 0,  fuel: 33, driver: 'Hans Schmidt',  eta: 'OFFLOADING',  heading: '—'),
  MockVehicle(id: 8, model: 'Scania G-Series',        plate: 'FI-202-IK', status: 'ACTIVE',     tracker: 'X-1005-ZETA',  lat: 41.9028, lng: 12.4964, speed: 71, fuel: 84, driver: 'Luigi Rossi',   eta: '3.5H TO GO', heading: 'NE'),
  MockVehicle(id: 9, model: 'Volvo FM',               plate: 'NN-303-LP', status: 'ACTIVE',     tracker: 'X-8822-DELTA', lat: 35.6762, lng: 139.6503, speed: 48, fuel: 67, driver: 'Yuki Tanaka',   eta: '5.1H TO GO', heading: 'E'),
  MockVehicle(id: 10, model: 'MAN TGS',               plate: 'TY-404-ER', status: 'IDLE',       tracker: 'X-8827-KAPPA', lat: 51.5074, lng: -0.1278, speed: 0,  fuel: 91, driver: 'James Wilson',  eta: '—',          heading: '—'),
  MockVehicle(id: 11, model: 'Iveco S-Way',           plate: 'HY-505-UI', status: 'ACTIVE',     tracker: 'X-1008-KAPPA', lat: 37.5665, lng: 126.9780, speed: 55, fuel: 72, driver: 'Min-Jun Kim',  eta: '2.9H TO GO', heading: 'NW'),
  MockVehicle(id: 12, model: 'Ford F-MAX',            plate: 'FR-606-TY', status: 'MAINTENANCE', tracker: 'X-8826-IOTA',  lat: -33.8688, lng: 151.2093, speed: 0,  fuel: 28, driver: 'Jack Thompson', eta: 'OFFLOADING',  heading: '—'),
  MockVehicle(id: 13, model: 'DAF CF',                plate: 'CO-7710-D', status: 'ACTIVE',     tracker: 'X-1006-THETA', lat: 39.7392, lng: -104.9903, speed: 62, fuel: 78, driver: 'Amanda Lee',   eta: '2.5H TO GO', heading: 'NW'),
  MockVehicle(id: 14, model: 'Renault Trucks D',      plate: 'FR-4401-P', status: 'ACTIVE',     tracker: 'X-1002-GAMMA', lat: 46.2276, lng: 4.8126, speed: 71, fuel: 85, driver: 'Lucas Moreau',  eta: '3.0H TO GO', heading: 'N'),
];

// ─── APPAREILS (trackers) ───────────────────────────────────────────────────
class MockDevice {
  final String id;
  final String model;
  final String assignment;
  final String lastConnection;
  final String statusColor;
  final String assignedVehicle;
  final String assignedSince;

  const MockDevice({
    required this.id,
    required this.model,
    required this.assignment,
    required this.lastConnection,
    required this.statusColor,
    this.assignedVehicle = '—',
    this.assignedSince = '—',
  });
}

const List<MockDevice> kMockDevices = [
  MockDevice(id: 'X-9941-ALPHA', model: 'Apex Tracker V3',  assignment: 'ASSIGNED',    lastConnection: '2 mins ago',  statusColor: '0xFF3B82F6', assignedVehicle: 'Mercedes-Benz Actros (123-TUN-45)',   assignedSince: '2025-03-10 14:30'),
  MockDevice(id: 'X-1001-BETA',  model: 'Apex Tracker V3',  assignment: 'ASSIGNED',    lastConnection: '5 mins ago',  statusColor: '0xFF3B82F6', assignedVehicle: 'Volvo FH (789-SF-01)',              assignedSince: '2025-04-01 09:15'),
  MockDevice(id: 'X-1002-GAMMA', model: 'Apex Tracker V3',  assignment: 'ASSIGNED',    lastConnection: '12 mins ago', statusColor: '0xFF3B82F6', assignedVehicle: 'Renault Trucks D (FR-4401-P)',       assignedSince: '2025-02-18 11:00'),
  MockDevice(id: 'X-1003-DELTA', model: 'Apex Tracker V3',  assignment: 'UNASSIGNED',  lastConnection: '1 hr ago',    statusColor: '0xFF64748B'),
  MockDevice(id: 'X-1004-EPSILON', model: 'Apex Tracker V3',assignment: 'MAINTENANCE', lastConnection: '3 days ago',  statusColor: '0xFFF59E0B'),
  MockDevice(id: 'X-1005-ZETA',  model: 'Apex Tracker V3',  assignment: 'ASSIGNED',    lastConnection: 'Just now',    statusColor: '0xFF3B82F6', assignedVehicle: 'Scania G-Series (FI-202-IK)',         assignedSince: '2025-05-01 08:00'),
  MockDevice(id: 'X-1006-THETA', model: 'Apex Tracker V3',  assignment: 'ASSIGNED',    lastConnection: '30 mins ago', statusColor: '0xFF3B82F6', assignedVehicle: 'DAF CF (CO-7710-D)',                 assignedSince: '2025-04-22 16:45'),
  MockDevice(id: 'X-1007-IOTA',  model: 'Apex Tracker V3',  assignment: 'UNASSIGNED',  lastConnection: '5 hrs ago',   statusColor: '0xFF64748B'),
  MockDevice(id: 'X-1008-KAPPA', model: 'Apex Tracker V3',  assignment: 'ASSIGNED',    lastConnection: '1 min ago',   statusColor: '0xFF3B82F6', assignedVehicle: 'Iveco S-Way (HY-505-UI)',             assignedSince: '2025-03-28 13:20'),
  MockDevice(id: 'X-1009-LAMBDA',model: 'Apex Tracker V3',  assignment: 'MAINTENANCE', lastConnection: '1 week ago',  statusColor: '0xFFF59E0B'),
  MockDevice(id: 'X-8820-BETA',  model: 'Core Link Hub',    assignment: 'UNASSIGNED',  lastConnection: '14 hrs ago',  statusColor: '0xFF64748B'),
  MockDevice(id: 'X-8821-GAMMA', model: 'Core Link Hub',    assignment: 'ASSIGNED',    lastConnection: '3 mins ago',  statusColor: '0xFF3B82F6', assignedVehicle: 'DAF XF (333-BEN-44)',                 assignedSince: '2025-01-15 10:30'),
  MockDevice(id: 'X-8822-DELTA', model: 'Core Link Hub',    assignment: 'ASSIGNED',    lastConnection: '45 mins ago', statusColor: '0xFF3B82F6', assignedVehicle: 'Volvo FM (NN-303-LP)',               assignedSince: '2025-04-10 07:00'),
  MockDevice(id: 'X-8823-EPSILON',model: 'Core Link Hub',   assignment: 'MAINTENANCE', lastConnection: '2 days ago',  statusColor: '0xFFF59E0B'),
  MockDevice(id: 'X-8824-ZETA',  model: 'Core Link Hub',    assignment: 'ASSIGNED',    lastConnection: '10 mins ago', statusColor: '0xFF3B82F6', assignedVehicle: 'Renault Trucks T (555-MON-66)',       assignedSince: '2025-05-05 12:00'),
  MockDevice(id: 'X-8825-THETA', model: 'Core Link Hub',    assignment: 'UNASSIGNED',  lastConnection: '8 hrs ago',   statusColor: '0xFF64748B'),
  MockDevice(id: 'X-8826-IOTA',  model: 'Core Link Hub',    assignment: 'ASSIGNED',    lastConnection: 'Just now',    statusColor: '0xFF3B82F6', assignedVehicle: 'Ford F-MAX (FR-606-TY)',              assignedSince: '2025-04-18 09:30'),
  MockDevice(id: 'X-8827-KAPPA', model: 'Core Link Hub',    assignment: 'ASSIGNED',    lastConnection: '25 mins ago', statusColor: '0xFF3B82F6', assignedVehicle: 'MAN TGS (TY-404-ER)',                assignedSince: '2025-03-05 14:15'),
  MockDevice(id: 'X-7701-ALPHA', model: 'Nano Sensor X1',   assignment: 'ASSIGNED',    lastConnection: '15 mins ago', statusColor: '0xFF3B82F6', assignedVehicle: 'Mercedes-Benz Arocs (777-SUS-88)',     assignedSince: '2025-02-28 16:00'),
  MockDevice(id: 'X-7702-BETA',  model: 'Nano Sensor X1',   assignment: 'UNASSIGNED',  lastConnection: '6 hrs ago',   statusColor: '0xFF64748B'),
  MockDevice(id: 'X-7703-GAMMA', model: 'Nano Sensor X1',   assignment: 'ASSIGNED',    lastConnection: '1 min ago',   statusColor: '0xFF3B82F6', assignedVehicle: 'Scania R-Series (456-NBL-78)',         assignedSince: '2025-04-29 11:45'),
  MockDevice(id: 'X-7704-DELTA', model: 'Nano Sensor X1',   assignment: 'MAINTENANCE', lastConnection: '4 days ago',  statusColor: '0xFFF59E0B'),
  MockDevice(id: 'X-7705-EPSILON',model: 'Nano Sensor X1',  assignment: 'ASSIGNED',    lastConnection: '20 mins ago', statusColor: '0xFF3B82F6', assignedVehicle: 'MAN TGX (111-ARI-22)',                assignedSince: '2025-05-08 10:00'),
  MockDevice(id: 'X-7706-ZETA',  model: 'Nano Sensor X1',   assignment: 'ASSIGNED',    lastConnection: 'Just now',    statusColor: '0xFF3B82F6', assignedVehicle: 'Renault Trucks D (FR-4401-P)',        assignedSince: '2025-04-12 08:30'),
];

// ─── HISTORIQUE ENTREE/SORTIE ───────────────────────────────────────────────
class MockEntryExit {
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

  const MockEntryExit({
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
  });
}

final List<MockEntryExit> kMockEntryExits = _generateEntryExits();

List<MockEntryExit> _generateEntryExits() {
  final rng = Random(42);
  final notes = ['Livraison effectuee', 'Maintenance programmee', '', 'Stationnement longue duree', null];
  final list = <MockEntryExit>[];
  int id = 1;

  for (int day = 0; day < 5; day++) {
    for (final v in kMockVehicles.take(8)) {
      final h = 6 + rng.nextInt(14);
      final m = rng.nextInt(60);
      final entry = '2026-05-${(7 - day).toString().padLeft(2, '0')} ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      final hasExit = rng.nextDouble() > 0.15;
      final exit = hasExit
          ? '2026-05-${(7 - day).toString().padLeft(2, '0')} ${(h + 4 + rng.nextInt(6)).toString().padLeft(2, '0')}:${rng.nextInt(60).toString().padLeft(2, '0')}'
          : null;

      list.add(MockEntryExit(
        id: id++,
        vehicleId: v.id,
        vehiclePlate: v.plate,
        vehicleModel: v.model,
        driver: v.driver,
        entryTime: entry,
        exitTime: exit,
        gate: hasExit ? 'Sortie' : 'Entrée',
        status: hasExit ? 'OUTSIDE' : 'INSIDE',
        notes: notes[rng.nextInt(notes.length)],
      ));
    }
  }

  final unknownPlates = ['XX-000-XX', 'ZZ-777-Q'];
  final unknownModels = ['Inconnu', 'Sans plaque'];
  for (int i = 0; i < unknownPlates.length; i++) {
    final h = 8 + rng.nextInt(10);
    final m = rng.nextInt(60);
    final entry = '2026-05-${(2 - i).toString().padLeft(2, '0')} ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    list.add(MockEntryExit(
      id: id++,
      vehicleId: 999 + i,
      vehiclePlate: unknownPlates[i],
      vehicleModel: unknownModels[i],
      driver: null,
      entryTime: entry,
      exitTime: null,
      gate: 'Entrée',
      status: 'INSIDE',
      notes: 'Véhicule inconnu signalé par agent de sécurité',
      isKnown: false,
    ));
  }

  return list;
}

// ─── MAINTENANCE LOGS ───────────────────────────────────────────────────────
class MockMaintenanceLog {
  final int id;
  final int vehicleId;
  final String date;
  final String type;
  final String title;
  final String description;
  final String? file;
  final String? mileage;

  const MockMaintenanceLog({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.type,
    required this.title,
    required this.description,
    this.file,
    this.mileage,
  });
}

final Map<int, List<MockMaintenanceLog>> kMockLogsByVehicle = {
  1: [
    const MockMaintenanceLog(id: 1, vehicleId: 1, date: 'OCT 12, 2023', type: 'ROUTINE', title: 'Level 2 Service: Transmission Flush & Filtration', description: 'System pressure normalized. Minor wear detected on coupling.', file: 'Service_Report_A402.pdf', mileage: '11,200 mi'),
    const MockMaintenanceLog(id: 2, vehicleId: 1, date: 'NOV 25, 2023', type: 'ROUTINE', title: 'Sensor Calibration & Alignment', description: 'All proximity sensors recalibrated. GPS module firmware updated.', file: 'Calibration_Log.pdf', mileage: '15,800 mi'),
  ],
  2: [
    const MockMaintenanceLog(id: 3, vehicleId: 2, date: 'NOV 01, 2023', type: 'REPAIR', title: 'Engine Overhaul - Cylinder Head Replacement', description: 'Severe overheating. Replaced cylinder head and gaskets.', file: 'Repair_Invoice_B208.pdf', mileage: '62,300 mi'),
  ],
  3: [
    const MockMaintenanceLog(id: 4, vehicleId: 3, date: 'SEP 15, 2023', type: 'ROUTINE', title: 'Oil Change & Filter Replacement', description: 'Standard oil change. All fluids topped up.', file: 'Service_Report_C315.pdf', mileage: '45,800 mi'),
  ],
  4: [
    const MockMaintenanceLog(id: 5, vehicleId: 4, date: 'DEC 05, 2023', type: 'REPAIR', title: 'Brake Pad Replacement', description: 'Front brake pads worn below 3mm. Replaced pads and rotors.', file: 'Repair_Invoice_D420.pdf', mileage: '28,150 mi'),
  ],
  5: [
    const MockMaintenanceLog(id: 6, vehicleId: 5, date: 'JAN 20, 2024', type: 'ROUTINE', title: 'Tire Rotation & Alignment', description: 'Rotated tires and performed wheel alignment.', mileage: '33,400 mi'),
  ],
  7: [
    const MockMaintenanceLog(id: 7, vehicleId: 7, date: 'FEB 10, 2024', type: 'REPAIR', title: 'Turbocharger Inspection', description: 'Whining noise from turbo. Inspected and replaced bearings.', file: 'Repair_Invoice_E501.pdf', mileage: '78,900 mi'),
  ],
  8: [
    const MockMaintenanceLog(id: 8, vehicleId: 8, date: 'MAR 01, 2024', type: 'ROUTINE', title: 'Battery Test & Replacement', description: 'Battery health at 62%. Replaced with new AGM battery.', file: 'Battery_Report.pdf', mileage: '55,200 mi'),
  ],
  13: [
    const MockMaintenanceLog(id: 9, vehicleId: 13, date: 'MAR 15, 2024', type: 'REPAIR', title: 'Rear Door Hinge Replacement', description: 'Hinge corrosion detected. Replaced both rear door hinges.', mileage: '41,200 mi'),
  ],
};

// ─── DONNEES POUR TRAJECTOIRE ───────────────────────────────────────────────
class RouteSegment {
  final LatLng from;
  final LatLng to;
  final String fromCity;
  final String toCity;
  final String date;
  final String time;
  final String distance;
  final String duration;
  final bool hasWarning;

  const RouteSegment({
    required this.from,
    required this.to,
    required this.fromCity,
    required this.toCity,
    required this.date,
    required this.time,
    required this.distance,
    required this.duration,
    this.hasWarning = false,
  });
}

class MockRoute {
  final List<LatLng> points;
  final List<String> cityNames;
  final List<RouteSegment> segments;

  const MockRoute({
    required this.points,
    required this.cityNames,
    required this.segments,
  });
}

final Map<String, MockRoute> kMockRoutes = {
  '123-TUN-45': const MockRoute(
    points: [
      const LatLng(40.7128, -74.0060), const LatLng(40.7580, -73.9855),
      const LatLng(40.7890, -74.1250), const LatLng(40.8500, -74.2000),
      const LatLng(41.0700, -74.9000), const LatLng(41.1000, -75.0000),
      const LatLng(41.2000, -75.5000), const LatLng(41.3000, -75.8000),
      const LatLng(41.4000, -76.0000), const LatLng(41.5000, -76.5000),
      const LatLng(41.7000, -77.0000), const LatLng(41.8000, -77.5000),
      const LatLng(41.8781, -87.6298),
    ],
    cityNames: ['New York, NY', 'Secaucus, NJ', 'Parsippany, NJ', 'Dover, NJ', 'Newton, NJ', 'Scranton, PA', 'Williamsport, PA', 'Lock Haven, PA', 'State College, PA', 'Altoona, PA', 'Johnstown, PA', 'Pittsburgh, PA', 'Chicago, IL'],
    segments: [
      const RouteSegment(from: const LatLng(40.7128, -74.0060), to: const LatLng(40.7580, -73.9855), fromCity: 'New York, NY', toCity: 'Secaucus, NJ', date: '2026-05-07', time: '08:00', distance: '4.2 mi', duration: '12 min'),
      const RouteSegment(from: const LatLng(40.7580, -73.9855), to: const LatLng(40.7890, -74.1250), fromCity: 'Secaucus, NJ', toCity: 'Parsippany, NJ', date: '2026-05-07', time: '09:15', distance: '8.1 mi', duration: '18 min'),
      const RouteSegment(from: const LatLng(40.7890, -74.1250), to: const LatLng(41.8781, -87.6298), fromCity: 'Parsippany, NJ', toCity: 'Chicago, IL', date: '2026-05-07', time: '09:33', distance: '795 mi', duration: '12 h 27 min', hasWarning: true),
    ],
  ),
  '456-NBL-78': const MockRoute(
    points: [
      const LatLng(51.5074, -0.1278), const LatLng(51.8000, -0.2000),
      const LatLng(52.0000, -0.5000), const LatLng(52.5000, -1.0000),
      const LatLng(52.9000, -1.5000), const LatLng(53.0000, -2.0000),
      const LatLng(53.5000, -2.5000), const LatLng(53.8000, -2.0000),
      const LatLng(54.0000, -2.0000), const LatLng(54.5000, -3.0000),
      const LatLng(55.0000, -3.0000), const LatLng(55.9533, -3.1883),
    ],
    cityNames: ['London', 'St Albans', 'Milton Keynes', 'Northampton', 'Leicester', 'Derby', 'Stoke-on-Trent', 'Manchester', 'Leeds', 'Carlisle', 'Glasgow', 'Edinburgh'],
    segments: [
      const RouteSegment(from: const LatLng(51.5074, -0.1278), to: const LatLng(51.8000, -0.2000), fromCity: 'London', toCity: 'St Albans', date: '2026-05-06', time: '22:00', distance: '21 mi', duration: '28 min'),
      const RouteSegment(from: const LatLng(51.8000, -0.2000), to: const LatLng(55.9533, -3.1883), fromCity: 'St Albans', toCity: 'Edinburgh', date: '2026-05-06', time: '22:28', distance: '400 mi', duration: '6 h 47 min'),
    ],
  ),
  '789-SF-01': const MockRoute(
    points: [
      const LatLng(25.2048, 55.2708), const LatLng(25.3000, 55.4000),
      const LatLng(25.4000, 55.5000), const LatLng(25.5000, 55.6000),
      const LatLng(25.6000, 55.7000), const LatLng(25.7000, 55.8000),
    ],
    cityNames: ['Dubai', 'Sharjah', 'Ajman', 'Fujairah'],
    segments: [
      const RouteSegment(from: const LatLng(25.2048, 55.2708), to: const LatLng(25.3000, 55.4000), fromCity: 'Dubai', toCity: 'Sharjah', date: '2026-05-05', time: '06:00', distance: '12 mi', duration: '18 min'),
      const RouteSegment(from: const LatLng(25.3000, 55.4000), to: const LatLng(25.7000, 55.8000), fromCity: 'Sharjah', toCity: 'Fujairah', date: '2026-05-05', time: '06:18', distance: '60 mi', duration: '1 h 15 min'),
    ],
  ),
  '111-ARI-22': MockRoute(
    points: [
      const LatLng(25.7617, -80.1918), const LatLng(26.5000, -80.5000),
      const LatLng(27.5000, -81.0000), const LatLng(28.5000, -81.5000),
      const LatLng(29.5000, -82.0000), const LatLng(30.5000, -82.5000),
      const LatLng(31.5000, -83.0000), const LatLng(32.5000, -83.5000),
      const LatLng(33.5000, -84.0000), const LatLng(34.0000, -84.5000),
      const LatLng(35.0000, -85.0000), const LatLng(36.0000, -86.0000),
      const LatLng(37.0000, -87.0000), const LatLng(37.7749, -122.4194),
    ],
    cityNames: ['Miami, FL', 'Fort Lauderdale, FL', 'West Palm Beach, FL', 'Port St. Lucie, FL', 'Melbourne, FL', 'Titusville, FL', 'Jacksonville, FL', 'Savannah, GA', 'Macon, GA', 'Atlanta, GA', 'Chattanooga, TN', 'Nashville, TN', 'St. Louis, MO', 'San Francisco, CA'],
    segments: [
      const RouteSegment(from: const LatLng(25.7617, -80.1918), to: const LatLng(26.5000, -80.5000), fromCity: 'Miami, FL', toCity: 'Fort Lauderdale, FL', date: '2026-05-07', time: '07:45', distance: '30 mi', duration: '35 min'),
      const RouteSegment(from: const LatLng(26.5000, -80.5000), to: const LatLng(37.7749, -122.4194), fromCity: 'Fort Lauderdale, FL', toCity: 'San Francisco, CA', date: '2026-05-07', time: '08:20', distance: '2550 mi', duration: '38 h', hasWarning: true),
    ],
  ),
  '333-BEN-44': MockRoute(
    points: [
      const LatLng(37.7749, -122.4194), const LatLng(38.0000, -122.5000),
      const LatLng(38.5000, -122.8000), const LatLng(39.0000, -123.0000),
      const LatLng(39.5000, -123.5000), const LatLng(40.0000, -123.5000),
      const LatLng(40.5000, -123.0000), const LatLng(41.0000, -122.5000),
      const LatLng(41.5000, -122.0000), const LatLng(42.0000, -121.5000),
      const LatLng(42.5000, -122.0000), const LatLng(43.0000, -122.5000),
      const LatLng(43.5000, -123.0000), const LatLng(44.0000, -123.0000),
      const LatLng(44.5000, -123.0000), const LatLng(45.0000, -123.0000),
      const LatLng(45.5000, -122.5000), const LatLng(46.0000, -122.5000),
      const LatLng(46.5000, -122.5000), const LatLng(47.0000, -122.5000),
      const LatLng(47.6062, -122.3321),
    ],
    cityNames: ['San Francisco, CA', 'Novato, CA', 'Santa Rosa, CA', 'Ukiah, CA', 'Willits, CA', 'Garberville, CA', 'Fortuna, CA', 'Eureka, CA', 'Crescent City, CA', 'Brookings, OR', 'Gold Beach, OR', 'Port Orford, OR', 'Bandon, OR', 'Coos Bay, OR', 'Reedsport, OR', 'Florence, OR', 'Newport, OR', 'Lincoln City, OR', 'Tillamook, OR', 'Cannon Beach, OR', 'Seattle, WA'],
    segments: [
      const RouteSegment(from: const LatLng(37.7749, -122.4194), to: const LatLng(38.0000, -122.5000), fromCity: 'San Francisco, CA', toCity: 'Novato, CA', date: '2026-05-06', time: '08:00', distance: '20 mi', duration: '25 min'),
      const RouteSegment(from: const LatLng(38.0000, -122.5000), to: const LatLng(47.6062, -122.3321), fromCity: 'Novato, CA', toCity: 'Seattle, WA', date: '2026-05-06', time: '08:25', distance: '800 mi', duration: '12 h 35 min'),
    ],
  ),
  '555-MON-66': MockRoute(
    points: [
      const LatLng(29.7604, -95.3698), const LatLng(30.0000, -95.5000),
      const LatLng(30.5000, -96.0000), const LatLng(31.0000, -96.5000),
      const LatLng(31.5000, -97.0000), const LatLng(32.0000, -97.5000),
      const LatLng(32.5000, -98.0000), const LatLng(33.0000, -98.5000),
      const LatLng(33.5000, -99.0000), const LatLng(34.0000, -99.5000),
      const LatLng(34.5000, -100.0000), const LatLng(35.0000, -100.5000),
      const LatLng(35.5000, -101.0000), const LatLng(36.0000, -101.5000),
      const LatLng(36.5000, -102.0000), const LatLng(37.0000, -102.5000),
      const LatLng(37.5000, -103.0000), const LatLng(38.0000, -103.5000),
      const LatLng(38.5000, -104.0000), const LatLng(39.0000, -104.5000),
      const LatLng(39.7392, -104.9903),
    ],
    cityNames: ['Houston, TX', 'Conroe, TX', 'Huntsville, TX', 'Madisonville, TX', 'Corsicana, TX', 'Waco, TX', 'Gatesville, TX', 'Brownwood, TX', 'Sweetwater, TX', 'Abilene, TX', 'Lubbock, TX', 'Amarillo, TX', 'Dalhart, TX', 'Branson, CO', 'Trinidad, CO', 'Pueblo, CO', 'Colorado Springs, CO', 'Denver, CO'],
    segments: [
      const RouteSegment(from: const LatLng(29.7604, -95.3698), to: const LatLng(32.0000, -97.5000), fromCity: 'Houston, TX', toCity: 'Waco, TX', date: '2026-05-06', time: '14:00', distance: '185 mi', duration: '3 h', hasWarning: true),
      const RouteSegment(from: const LatLng(32.0000, -97.5000), to: const LatLng(39.7392, -104.9903), fromCity: 'Waco, TX', toCity: 'Denver, CO', date: '2026-05-06', time: '17:00', distance: '800 mi', duration: '12 h'),
    ],
  ),
  '777-SUS-88': MockRoute(
    points: [
      const LatLng(52.5200, 13.4050), const LatLng(52.5365, 13.3850),
      const LatLng(53.0793, 8.8017), const LatLng(51.2277, 6.7735),
      const LatLng(50.9375, 6.9603),
    ],
    cityNames: ['Berlin', 'Berlin-Spandau', 'Bremen', 'Düsseldorf', 'Cologne'],
    segments: [
      const RouteSegment(from: const LatLng(52.5200, 13.4050), to: const LatLng(53.0793, 8.8017), fromCity: 'Berlin', toCity: 'Bremen', date: '2026-05-06', time: '06:00', distance: '200 mi', duration: '3 h 30 min'),
      const RouteSegment(from: const LatLng(53.0793, 8.8017), to: const LatLng(51.2277, 6.7735), fromCity: 'Bremen', toCity: 'Düsseldorf', date: '2026-05-06', time: '10:00', distance: '180 mi', duration: '3 h'),
      const RouteSegment(from: const LatLng(51.2277, 6.7735), to: const LatLng(50.9375, 6.9603), fromCity: 'Düsseldorf', toCity: 'Cologne', date: '2026-05-06', time: '15:00', distance: '25 mi', duration: '30 min', hasWarning: true),
    ],
  ),
  'FI-202-IK': MockRoute(
    points: [
      const LatLng(41.9028, 12.4964), const LatLng(41.9250, 12.4850),
      const LatLng(43.7696, 11.2558), const LatLng(45.4642, 9.1900),
      const LatLng(45.0703, 7.6869),
    ],
    cityNames: ['Rome', 'Rome-Nord', 'Florence', 'Milan', 'Turin'],
    segments: [
      const RouteSegment(from: const LatLng(41.9028, 12.4964), to: const LatLng(43.7696, 11.2558), fromCity: 'Rome', toCity: 'Florence', date: '2026-05-07', time: '07:00', distance: '175 mi', duration: '3 h'),
      const RouteSegment(from: const LatLng(43.7696, 11.2558), to: const LatLng(45.4642, 9.1900), fromCity: 'Florence', toCity: 'Milan', date: '2026-05-07', time: '11:00', distance: '190 mi', duration: '3 h 30 min'),
      const RouteSegment(from: const LatLng(45.4642, 9.1900), to: const LatLng(45.0703, 7.6869), fromCity: 'Milan', toCity: 'Turin', date: '2026-05-07', time: '15:00', distance: '85 mi', duration: '1 h 30 min'),
    ],
  ),
  'NN-303-LP': MockRoute(
    points: [
      const LatLng(35.6762, 139.6503), const LatLng(35.6800, 139.7000),
      const LatLng(35.1815, 136.9066), const LatLng(35.0116, 135.7681),
      const LatLng(34.6901, 135.1955),
    ],
    cityNames: ['Tokyo', 'Tokyo-Est', 'Nagoya', 'Kyoto', 'Kobe'],
    segments: [
      const RouteSegment(from: const LatLng(35.6762, 139.6503), to: const LatLng(35.1815, 136.9066), fromCity: 'Tokyo', toCity: 'Nagoya', date: '2026-05-07', time: '08:00', distance: '160 mi', duration: '2 h 30 min'),
      const RouteSegment(from: const LatLng(35.1815, 136.9066), to: const LatLng(35.0116, 135.7681), fromCity: 'Nagoya', toCity: 'Kyoto', date: '2026-05-07', time: '11:00', distance: '75 mi', duration: '1 h 15 min'),
      const RouteSegment(from: const LatLng(35.0116, 135.7681), to: const LatLng(34.6901, 135.1955), fromCity: 'Kyoto', toCity: 'Kobe', date: '2026-05-07', time: '13:00', distance: '45 mi', duration: '1 h', hasWarning: true),
    ],
  ),
  'TY-404-ER': MockRoute(
    points: [
      const LatLng(51.5074, -0.1278), const LatLng(51.5100, -0.1500),
      const LatLng(51.4545, -2.5879), const LatLng(51.4816, -3.1791),
      const LatLng(53.4084, -2.9916),
    ],
    cityNames: ['London', 'London-Ouest', 'Bristol', 'Cardiff', 'Liverpool'],
    segments: [
      const RouteSegment(from: const LatLng(51.5074, -0.1278), to: const LatLng(51.4545, -2.5879), fromCity: 'London', toCity: 'Bristol', date: '2026-05-05', time: '09:00', distance: '120 mi', duration: '2 h 15 min'),
      const RouteSegment(from: const LatLng(51.4545, -2.5879), to: const LatLng(51.4816, -3.1791), fromCity: 'Bristol', toCity: 'Cardiff', date: '2026-05-05', time: '12:00', distance: '45 mi', duration: '1 h'),
      const RouteSegment(from: const LatLng(51.4816, -3.1791), to: const LatLng(53.4084, -2.9916), fromCity: 'Cardiff', toCity: 'Liverpool', date: '2026-05-05', time: '14:00', distance: '140 mi', duration: '3 h', hasWarning: true),
    ],
  ),
  'HY-505-UI': MockRoute(
    points: [
      const LatLng(37.5665, 126.9780), const LatLng(37.0000, 127.0000),
      const LatLng(35.1796, 129.0756),
    ],
    cityNames: ['Seoul, SK', 'Cheongju, SK', 'Busan, SK'],
    segments: [
      const RouteSegment(from: const LatLng(37.5665, 126.9780), to: const LatLng(37.0000, 127.0000), fromCity: 'Seoul, SK', toCity: 'Cheongju, SK', date: '2026-05-07', time: '07:00', distance: '80 mi', duration: '2 h 30 min'),
      const RouteSegment(from: const LatLng(37.0000, 127.0000), to: const LatLng(35.1796, 129.0756), fromCity: 'Cheongju, SK', toCity: 'Busan, SK', date: '2026-05-07', time: '10:00', distance: '150 mi', duration: '4 h 30 min'),
    ],
  ),
  'FR-606-TY': MockRoute(
    points: [
      const LatLng(-33.8688, 151.2093), const LatLng(-33.8680, 150.0000),
      const LatLng(-34.9285, 138.6007),
    ],
    cityNames: ['Sydney, AU', 'Canberra, AU', 'Adelaide, AU'],
    segments: [
      const RouteSegment(from: const LatLng(-33.8688, 151.2093), to: const LatLng(-33.8680, 150.0000), fromCity: 'Sydney, AU', toCity: 'Canberra, AU', date: '2026-05-06', time: '06:00', distance: '180 mi', duration: '2 h 30 min'),
      const RouteSegment(from: const LatLng(-33.8680, 150.0000), to: const LatLng(-34.9285, 138.6007), fromCity: 'Canberra, AU', toCity: 'Adelaide, AU', date: '2026-05-06', time: '09:00', distance: '730 mi', duration: '7 h 00 min', hasWarning: true),
    ],
  ),
  'CO-7710-D': MockRoute(
    points: [
      const LatLng(39.7392, -104.9903), const LatLng(39.0000, -105.0000),
      const LatLng(38.2527, -85.7585),
    ],
    cityNames: ['Denver, CO', 'Colorado Springs, CO', 'Louisville, KY'],
    segments: [
      const RouteSegment(from: const LatLng(39.7392, -104.9903), to: const LatLng(39.0000, -105.0000), fromCity: 'Denver, CO', toCity: 'Colorado Springs, CO', date: '2026-05-07', time: '08:00', distance: '70 mi', duration: '2 h 00 min'),
      const RouteSegment(from: const LatLng(39.0000, -105.0000), to: const LatLng(38.2527, -85.7585), fromCity: 'Colorado Springs, CO', toCity: 'Louisville, KY', date: '2026-05-07', time: '10:30', distance: '850 mi', duration: '8 h 00 min'),
    ],
  ),
  'FR-4401-P': MockRoute(
    points: [
      const LatLng(46.2276, 4.8126), const LatLng(46.0000, 4.5000),
      const LatLng(45.7640, 4.8357),
    ],
    cityNames: ['Bourg-en-Bresse', 'Mâcon', 'Lyon'],
    segments: [
      const RouteSegment(from: const LatLng(46.2276, 4.8126), to: const LatLng(46.0000, 4.5000), fromCity: 'Bourg-en-Bresse', toCity: 'Mâcon', date: '2026-05-07', time: '08:00', distance: '30 mi', duration: '1 h 00 min'),
      const RouteSegment(from: const LatLng(46.0000, 4.5000), to: const LatLng(45.7640, 4.8357), fromCity: 'Mâcon', toCity: 'Lyon', date: '2026-05-07', time: '09:30', distance: '45 mi', duration: '1 h 00 min'),
    ],
  ),
};

final Set<String> kIdlePlates = {'456-NBL-78', '789-SF-01', '777-SUS-88', 'TY-404-ER', 'FR-606-TY'};

List<Map<String, dynamic>> kStopsForVehicle(String plate) {
  final stops = <String, List<Map<String, dynamic>>>{
    '123-TUN-45': [
      {'city': 'New York, NY', 'type': 'Départ', 'time': '08:00', 'duration': '—'},
      {'city': 'Parsippany, NJ', 'type': 'Arrêt', 'time': '09:15', 'duration': '15 min'},
      {'city': 'Scranton, PA', 'type': 'Arrêt', 'time': '10:45', 'duration': '30 min'},
      {'city': 'Chicago, IL', 'type': 'Arrivée', 'time': '22:30', 'duration': '—'},
    ],
    '456-NBL-78': [
      {'city': 'London', 'type': 'Départ', 'time': '22:00', 'duration': '—'},
      {'city': 'Edinburgh', 'type': 'Arrivée', 'time': '06:30', 'duration': '—'},
    ],
    '111-ARI-22': [
      {'city': 'Miami, FL', 'type': 'Départ', 'time': '07:45', 'duration': '—'},
      {'city': 'San Francisco, CA', 'type': 'Arrivée', 'time': '22:00', 'duration': '—'},
    ],
    '777-SUS-88': [
      {'city': 'Berlin', 'type': 'Départ', 'time': '06:00', 'duration': '—'},
      {'city': 'Hamburg', 'type': 'Arrêt', 'time': '09:00', 'duration': '20 min'},
      {'city': 'Düsseldorf', 'type': 'Arrêt', 'time': '14:00', 'duration': '15 min'},
      {'city': 'Cologne', 'type': 'Arrivée', 'time': '15:30', 'duration': '—'},
    ],
    'FI-202-IK': [
      {'city': 'Rome', 'type': 'Départ', 'time': '07:00', 'duration': '—'},
      {'city': 'Florence', 'type': 'Arrêt', 'time': '10:00', 'duration': '25 min'},
      {'city': 'Milan', 'type': 'Arrêt', 'time': '14:30', 'duration': '30 min'},
      {'city': 'Turin', 'type': 'Arrivée', 'time': '16:30', 'duration': '—'},
    ],
    'NN-303-LP': [
      {'city': 'Tokyo', 'type': 'Départ', 'time': '08:00', 'duration': '—'},
      {'city': 'Nagoya', 'type': 'Arrêt', 'time': '10:30', 'duration': '15 min'},
      {'city': 'Kyoto', 'type': 'Arrêt', 'time': '12:15', 'duration': '20 min'},
      {'city': 'Kobe', 'type': 'Arrivée', 'time': '14:00', 'duration': '—'},
    ],
    'TY-404-ER': [
      {'city': 'London', 'type': 'Départ', 'time': '09:00', 'duration': '—'},
      {'city': 'Bristol', 'type': 'Arrêt', 'time': '11:15', 'duration': '10 min'},
      {'city': 'Cardiff', 'type': 'Arrêt', 'time': '13:00', 'duration': '30 min'},
      {'city': 'Liverpool', 'type': 'Arrivée', 'time': '17:00', 'duration': '—'},
    ],
    'HY-505-UI': [
      {'city': 'Seoul, SK', 'type': 'Départ', 'time': '07:00', 'duration': '—'},
      {'city': 'Cheongju, SK', 'type': 'Arrêt', 'time': '09:30', 'duration': '15 min'},
      {'city': 'Busan, SK', 'type': 'Arrivée', 'time': '14:30', 'duration': '—'},
    ],
    'FR-606-TY': [
      {'city': 'Sydney, AU', 'type': 'Départ', 'time': '06:00', 'duration': '—'},
      {'city': 'Canberra, AU', 'type': 'Arrêt', 'time': '08:30', 'duration': '20 min'},
      {'city': 'Adelaide, AU', 'type': 'Arrivée', 'time': '16:00', 'duration': '—'},
    ],
    'CO-7710-D': [
      {'city': 'Denver, CO', 'type': 'Départ', 'time': '08:00', 'duration': '—'},
      {'city': 'Colorado Springs, CO', 'type': 'Arrêt', 'time': '10:00', 'duration': '10 min'},
      {'city': 'Louisville, KY', 'type': 'Arrivée', 'time': '18:30', 'duration': '—'},
    ],
    'FR-4401-P': [
      {'city': 'Bourg-en-Bresse', 'type': 'Départ', 'time': '08:00', 'duration': '—'},
      {'city': 'Mâcon', 'type': 'Arrêt', 'time': '09:00', 'duration': '5 min'},
      {'city': 'Lyon', 'type': 'Arrivée', 'time': '10:30', 'duration': '—'},
    ],
  };
  return stops[plate] ?? [];
}

List<Map<String, dynamic>> kEventsForVehicle(String plate) {
  final events = <String, List<Map<String, dynamic>>>{
    '123-TUN-45': [
      {'icon': 'speed', 'title': 'Excès de vitesse', 'description': 'Détecté à 158 km/h sur I-80', 'time': '14:23', 'color': const Color(0xFFEF4444)},
      {'icon': 'warning', 'title': 'Arrêt prolongé', 'description': 'Arrêt de 45 min à Scranton, PA', 'time': '10:45', 'color': const Color(0xFFF59E0B)},
    ],
    '456-NBL-78': [
      {'icon': 'build', 'title': 'Maintenance', 'description': 'Révision moteur programmée', 'time': '08:00', 'color': const Color(0xFFF59E0B)},
    ],
    '111-ARI-22': [
      {'icon': 'traffic', 'title': 'Trafic dense', 'description': 'Ralentissement sur I-10', 'time': '09:30', 'color': const Color(0xFFF59E0B)},
    ],
    '777-SUS-88': [
      {'icon': 'warning', 'title': 'Embouteillage A2', 'description': 'Fort trafic près de Hanovre', 'time': '11:15', 'color': const Color(0xFFF59E0B)},
    ],
    'FI-202-IK': [
      {'icon': 'speed', 'title': 'Excès de vitesse', 'description': 'Flashé à 145 km/h sur A1', 'time': '12:40', 'color': const Color(0xFFEF4444)},
    ],
    'NN-303-LP': [
      {'icon': 'warning', 'title': 'Freinage brusque', 'description': 'Détecté sur Tomei Expressway', 'time': '09:50', 'color': const Color(0xFFF59E0B)},
    ],
    'TY-404-ER': [
      {'icon': 'build', 'title': 'Révision freins', 'description': 'Usure détectée à Liverpool', 'time': '16:00', 'color': const Color(0xFFF59E0B)},
    ],
    'HY-505-UI': [
      {'icon': 'speed', 'title': 'Excès de vitesse', 'description': '95 mph sur Gyeongbu Expressway', 'time': '12:30', 'color': const Color(0xFFEF4444)},
      {'icon': 'warning', 'title': 'Arrêt prolongé', 'description': 'Arrêt de 30 min à Cheongju', 'time': '09:30', 'color': const Color(0xFFF59E0B)},
    ],
    'FR-606-TY': [
      {'icon': 'build', 'title': 'Maintenance', 'description': 'Inspection moteur programmée', 'time': '08:00', 'color': const Color(0xFFF59E0B)},
    ],
    'CO-7710-D': [
      {'icon': 'warning', 'title': 'Conditions météo', 'description': 'Tempête de neige près de Denver', 'time': '10:15', 'color': const Color(0xFFF59E0B)},
    ],
    'FR-4401-P': [
      {'icon': 'check', 'title': 'Livraison effectuée', 'description': 'Colis livré à Lyon', 'time': '10:30', 'color': const Color(0xFF22C55E)},
    ],
  };
  return events[plate] ?? [];
}

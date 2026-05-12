import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';

class Delivery {
  final int id;
  final int vehicleId;
  final String vehiclePlate;
  final String? vehicleModel;
  final String? driver;
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
    required this.destinationLat, required this.destinationLng,
    this.destinationName,
    required this.status, this.etaMinutes, this.assignedAt, this.arrivedAt,
    this.deliveredAt, this.notes,
  });

  factory Delivery.fromJson(Map<String, dynamic> j) => Delivery(
    id: j['id'], vehicleId: j['vehicle_id'], vehiclePlate: j['vehicle_plate'],
    vehicleModel: j['vehicle_model'], driver: j['driver'],
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

class DeliveryPage extends StatefulWidget {
  const DeliveryPage({super.key});
  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  List<Delivery> _deliveries = [];
  final Set<int> _notifiedArrivalIds = {};
  Timer? _pollTimer;
  Timer? _refreshTimer;
  bool _loading = true;

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchAll());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollArrivals());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(seconds: 6),
              backgroundColor: const Color(0xFF0F172A),
              content: Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🚛 Livraison arrivée',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('${a.vehicleModel} (${a.vehiclePlate}) à ${a.destinationName ?? "destination"}',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                  ],
                )),
              ]),
              action: SnackBarAction(
                label: 'Voir',
                textColor: const Color(0xFF3B82F6),
                onPressed: () => _confirmDelivery(a.id),
              ),
            ));
          }
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

  @override
  Widget build(BuildContext context) {
    final enRoute = _deliveries.where((d) => d.status == 'en_route').length;
    final arrived = _deliveries.where((d) => d.status == 'arrived').length;
    final delivered = _deliveries.where((d) => d.status == 'delivered').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Suivi des livraisons',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text('Surveillez les arrivées automatiques et confirmez les livraisons',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
            const SizedBox(height: 16),
            Row(children: [
              _statCard('En route', '$enRoute', const Color(0xFF3B82F6), Icons.route),
              const SizedBox(width: 12),
              _statCard('Arrivées', '$arrived', const Color(0xFFF59E0B), Icons.location_on),
              const SizedBox(width: 12),
              _statCard('Livrées', '$delivered', const Color(0xFF10B981), Icons.check_circle),
            ]),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _deliveries.isEmpty
                  ? Center(child: Text('Aucune livraison', style: GoogleFonts.inter(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _deliveries.length,
                      itemBuilder: (_, i) => _deliveryCard(_deliveries[i]),
                    ),
        ),
      ]),
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
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Expanded(child: Text(d.destinationName ?? '${d.destinationLat.toStringAsFixed(4)}, ${d.destinationLng.toStringAsFixed(4)}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.access_time, size: 14, color: Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Expanded(child: Text(
            d.status == 'delivered'
                ? 'Livré le ${d.deliveredAt ?? "—"}'
                : d.status == 'arrived'
                    ? 'Arrivé le ${d.arrivedAt ?? "—"}'
                    : d.etaMinutes != null
                        ? 'ETA: ${d.etaText} — Assigné le ${d.assignedAt ?? "—"}'
                        : 'Assigné le ${d.assignedAt ?? "—"}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          )),
        ]),
        if (d.status == 'arrived') ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle, size: 16),
              label: Text('Confirmer la livraison',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _confirmDelivery(d.id),
            ),
          ),
        ],
      ]),
    );
  }
}

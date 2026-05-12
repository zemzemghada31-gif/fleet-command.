import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  // Stats
  String totalDistance = "Loading...";
  String avgFuelEconomy = "Loading...";
  int activeAlerts = 0;
  String distanceTrend = "";
  String fuelTrend = "";
  bool isLoading = true;
  bool isExporting = false;

  // Trend chart data
  List<double> _activeSpots = [3, 4, 3.5, 5, 4.5, 2, 1.5];
  List<double> _maintenanceSpots = [1, 1.5, 1, 2, 1.5, 1, 0.5];
  List<String> _trendDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  // Filter state
  String _selectedPeriod = 'Last 30 Days';
  int _selectedTimeHorizon = 1; // 0=Real-time, 1=Historical, 2=Predictive
  int _selectedRegion = 0;     // 0=All, 1=North America, 2=Europe, 3=APAC, 4=LATAM

  // Network map fleet data
  static const _fleetVehicles = [
    {'id': 'TRK-001', 'name': 'Truck Alpha',   'lat': 37.7749,  'lng': -122.4194, 'status': 'moving',  'fuel': 78, 'speed': 62},
    {'id': 'TRK-002', 'name': 'Truck Beta',    'lat': 34.0522,  'lng': -118.2437, 'status': 'moving',  'fuel': 45, 'speed': 55},
    {'id': 'TRK-003', 'name': 'Truck Gamma',   'lat': 40.7128,  'lng': -74.0060,  'status': 'parked',  'fuel': 92, 'speed': 0},
    {'id': 'TRK-004', 'name': 'Truck Delta',   'lat': 41.8781,  'lng': -87.6298,  'status': 'moving',  'fuel': 31, 'speed': 70},
    {'id': 'TRK-005', 'name': 'Truck Epsilon', 'lat': 29.7604,  'lng': -95.3698,  'status': 'service', 'fuel': 60, 'speed': 0},
  ];
  int? _hoveredVehicle;
  final MapController _netMapController = MapController();

  static const _periodMap = {
    'Last 30 Days': 'last_30_days',
    'Quarterly':    'quarterly',
    'Yearly':       'yearly',
  };

  static const _horizonMap = {
    0: 'realtime',
    1: 'historical',
    2: 'predictive',
  };

  static const _regionMap = {
    0: 'all',
    1: 'north_america',
    2: 'europe',
    3: 'apac',
    4: 'latam',
  };

  static const _timeHorizonLabels = ['Real-time Stream', 'Historical Aggregate', 'Predictive Analysis'];
  static const _regionLabels = ['All Regions', 'North America', 'Europe', 'APAC', 'LATAM'];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  String get _apiPeriod => _periodMap[_selectedPeriod] ?? 'last_30_days';
  String get _apiHorizon => _horizonMap[_selectedTimeHorizon] ?? 'historical';
  String get _apiRegion => _regionMap[_selectedRegion] ?? 'all';

  // Count non-default filter selections (defaults: period=Last 30 Days, horizon=1, region=0)
  int get _activeFilterCount {
    int n = 0;
    if (_selectedPeriod != 'Last 30 Days') n++;
    if (_selectedTimeHorizon != 1) n++;
    if (_selectedRegion != 0) n++;
    return n;
  }

  // Human-readable summary of active filters
  String get _activeFilterSummary {
    if (_activeFilterCount == 0) return 'No active filters';
    final parts = <String>[];
    if (_selectedPeriod != 'Last 30 Days') parts.add(_selectedPeriod);
    if (_selectedTimeHorizon != 1) parts.add(_timeHorizonLabels[_selectedTimeHorizon]);
    if (_selectedRegion != 0) parts.add(_regionLabels[_selectedRegion]);
    return parts.join(' · ');
  }

  void _resetFilters() {
    setState(() {
      _selectedPeriod = 'Last 30 Days';
      _selectedTimeHorizon = 1;
      _selectedRegion = 0;
    });
    _refreshData();
  }

  String _buildQueryString() =>
      'period=$_apiPeriod&time_horizon=$_apiHorizon&region=$_apiRegion';

  void _refreshData() {
    fetchStats();
    fetchTrends();
  }

  Future<void> fetchStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$kApiBaseUrl/api/analytics/stats?${_buildQueryString()}'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          totalDistance  = data['total_distance'];
          avgFuelEconomy = data['avg_fuel_economy'];
          activeAlerts   = data['active_alerts'];
          distanceTrend  = data['distance_trend'];
          fuelTrend      = data['fuel_trend'];
          isLoading      = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> fetchTrends() async {
    try {
      final response = await http.get(
        Uri.parse('$kApiBaseUrl/api/analytics/trends?period=$_apiPeriod&region=$_apiRegion'),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _activeSpots      = List<double>.from(data['active'].map((v) => (v as num).toDouble()));
          _maintenanceSpots = List<double>.from(data['maintenance'].map((v) => (v as num).toDouble()));
          _trendDays        = List<String>.from(data['days']);
        });
      }
    } catch (e) {
      debugPrint("Error fetching trends: $e");
    }
  }

  Future<void> _generateExport() async {
    setState(() => isExporting = true);
    try {
      final response = await http.get(
        Uri.parse('$kApiBaseUrl/api/analytics/export?${_buildQueryString()}'),
      );
      setState(() => isExporting = false);
      if (!mounted) return;

      if (response.statusCode == 200) {
        _showExportDialog(response.body);
      } else {
        _showErrorSnack('Export failed (${response.statusCode})');
      }
    } catch (e) {
      setState(() => isExporting = false);
      if (!mounted) return;
      _showErrorSnack('Export failed. Is the server running?');
    }
  }

  void _showExportDialog(String csvContent) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.download_done_rounded, color: Color(0xFF3B82F6)),
          SizedBox(width: 10),
          Text('Export Ready', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fleet analytics exported — Period: $_selectedPeriod · Region: ${_regionLabels[_selectedRegion]} · Horizon: ${_timeHorizonLabels[_selectedTimeHorizon]}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                height: 220,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csvContent,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF334155)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV content is selectable — copy it from the preview.'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy CSV'),
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

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: constraints.maxWidth - 64, // 32px padding × 2
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column
                Expanded(
                  flex: 3,
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fleet Analytics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Global performance metrics and operational efficiency data.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildTimeFilter(),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    _buildStatCard('TOTAL DISTANCE', totalDistance, distanceTrend, Icons.gesture, const Color(0xFF3B82F6)),
                    const SizedBox(width: 20),
                    _buildStatCard('AVG FUEL ECONOMY', avgFuelEconomy, fuelTrend, Icons.local_gas_station, const Color(0xFF6366F1)),
                    const SizedBox(width: 20),
                    _buildStatCard('ACTIVE ALERTS', activeAlerts.toString(), 'Urgent', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
                  ],
                ),
                const SizedBox(height: 32),
                _buildUtilizationChart(),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Right Column
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildRefineDataPanel(),
                const SizedBox(height: 24),
                _buildNetworkMapCard(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
    },
  );
  }

  Widget _buildTimeFilter() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          _buildTimeButton('Last 30 Days'),
          _buildTimeButton('Quarterly'),
          _buildTimeButton('Yearly'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label) {
    final isSelected = _selectedPeriod == label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_selectedPeriod != label) {
          setState(() => _selectedPeriod = label);
          _refreshData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String trend, IconData icon, Color color) {
    final isPositive = trend.contains('+');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        // Always render the same Column structure — avoids render-box-no-size during loading transitions
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (!isLoading)
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (trend != 'Urgent' && trend.isNotEmpty)
                          Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                              color: isPositive ? Colors.green : Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            trend,
                            style: TextStyle(
                              color: trend == 'Urgent' ? Colors.orange : (isPositive ? Colors.green : Colors.red),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            isLoading
                ? Container(
                    height: 24,
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )
                : Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: 80,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(2)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.6,
                child: Container(decoration: BoxDecoration(color: isLoading ? const Color(0xFFCBD5E1) : color, borderRadius: BorderRadius.circular(2))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtilizationChart() {
    final spots = _activeSpots.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final maintenanceSpotsList = _maintenanceSpots.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();
    final days = _trendDays;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Fleet Utilization Trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A))),
                  Text(
                    'Vehicle activity · ${_regionLabels[_selectedRegion]} · $_selectedPeriod',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ]),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _buildLegendItem('Active', const Color(0xFF0F172A)),
                const SizedBox(width: 16),
                _buildLegendItem('Maintenance', const Color(0xFFE2E8F0)),
                const SizedBox(width: 16),
                const Icon(Icons.more_vert, color: Colors.grey),
              ]),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 250,
            child: LineChart(LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    return Text(
                      i >= 0 && i < days.length ? days[i] : '',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    );
                  },
                )),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF0F172A),
                  barWidth: 3,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: const Color(0xFF0F172A).withValues(alpha: 0.05)),
                ),
                LineChartBarData(
                  spots: maintenanceSpotsList,
                  isCurved: true,
                  color: const Color(0xFFE2E8F0),
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
    ]);
  }

  Widget _buildRefineDataPanel() {
    final hasFilters = _activeFilterCount > 0;
    final iconColor  = hasFilters ? const Color(0xFF3B82F6) : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with dynamic icon ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REFINE DATA',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                    color: Color(0xFF0F172A)),
              ),
              Tooltip(
                message: hasFilters
                    ? 'Active: $_activeFilterSummary\nClick to reset'
                    : 'No active filters',
                preferBelow: false,
                child: GestureDetector(
                  onTap: hasFilters ? _resetFilters : null,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: hasFilters
                              ? const Color(0xFFEFF6FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              RotationTransition(
                                turns: Tween(begin: 0.85, end: 1.0)
                                    .animate(anim),
                                child: FadeTransition(
                                    opacity: anim, child: child),
                              ),
                          child: Icon(
                            hasFilters
                                ? Icons.filter_alt
                                : Icons.tune,
                            key: ValueKey(hasFilters),
                            size: 17,
                            color: iconColor,
                          ),
                        ),
                      ),
                      // Badge: count of active filters
                      if (hasFilters)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$_activeFilterCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Active filter summary pill (visible only when filters active)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: hasFilters
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                    children: [
                          const Icon(Icons.info_outline,
                              size: 12, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _activeFilterSummary,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: _resetFilters,
                            child: const Icon(Icons.close,
                                size: 12, color: Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          _buildFilterSection(
            'TIME HORIZON',
            _timeHorizonLabels,
            _selectedTimeHorizon,
            (i) {
              setState(() => _selectedTimeHorizon = i);
              _refreshData();
            },
          ),
          const SizedBox(height: 32),
          _buildFilterSection(
            'REGIONAL FILTER',
            _regionLabels,
            _selectedRegion,
            (i) {
              setState(() => _selectedRegion = i);
              _refreshData();
            },
            isChip: true,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: isExporting ? null : _generateExport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              disabledBackgroundColor: const Color(0xFF475569),
            ),
            child: isExporting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('GENERATE EXPORT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    int selectedIndex,
    void Function(int) onChanged, {
    bool isChip = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
        const SizedBox(height: 12),
        if (isChip)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.asMap().entries
                .map((e) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(e.key),
                      child: _buildChip(e.value, e.key == selectedIndex),
                    ))
                .toList(),
          )
        else
          ...options.asMap().entries.map((e) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(e.key),
                child: _buildFilterOption(e.value, e.key == selectedIndex),
              )),
      ],
    );
  }

  Widget _buildFilterOption(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontSize: 13,
              ),
            ),
          ),
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildNetworkMapCard() {
    final moving  = _fleetVehicles.where((v) => v['status'] == 'moving').length;
    final parked  = _fleetVehicles.where((v) => v['status'] == 'parked').length;
    final service = _fleetVehicles.where((v) => v['status'] == 'service').length;

    return GestureDetector(
      onTap: () => _openFullMap(context),
      child: Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // ── Real OSM mini-map ─────────────────────────────────────
              FlutterMap(
                mapController: _netMapController,
                options: const MapOptions(
                  initialCenter: LatLng(37.5, -97.0), // center of USA
                  initialZoom: 3.5,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.none, // locked in mini view
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.fleet.command',
                  ),
                  MarkerLayer(
                    markers: _fleetVehicles.asMap().entries.map((entry) {
                      final i = entry.key;
                      final v = entry.value;
                      final color = _vehicleStatusColor(v['status'] as String);
                      final isHovered = _hoveredVehicle == i;
                      return Marker(
                        point: LatLng(v['lat'] as double, v['lng'] as double),
                        width: isHovered ? 36 : 26,
                        height: isHovered ? 36 : 26,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          onEnter: (_) => setState(() => _hoveredVehicle = i),
                          onExit:  (_) => setState(() => _hoveredVehicle = null),
                          child: Tooltip(
                            message: '${v['id']} · ${v['name']}\n'
                                '${(v['status'] as String).toUpperCase()} · '
                                '${v['speed']} km/h · Fuel ${v['fuel']}%',
                            preferBelow: false,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: isHovered ? 2.5 : 1.5),
                                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: isHovered ? 8 : 3)],
                              ),
                              child: Icon(
                                v['status'] == 'moving' ? Icons.local_shipping : v['status'] == 'service' ? Icons.build : Icons.local_parking,
                                color: Colors.white,
                                size: isHovered ? 18 : 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // ── Dark overlay + title bar ──────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.map_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text('NETWORK MAP',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(children: [
                        Icon(Icons.circle, size: 7, color: Color(0xFF22C55E)),
                        SizedBox(width: 4),
                        Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ]),
                ),
              ),

              // ── Bottom status bar ─────────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
                    ),
                  ),
                  child: Row(children: [
                    _statusPill(Icons.local_shipping, '$moving Moving', const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _statusPill(Icons.local_parking, '$parked Parked', const Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    _statusPill(Icons.build, '$service Service', const Color(0xFFF59E0B)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.fullscreen, color: Colors.white, size: 13),
                        SizedBox(width: 4),
                        Text('Expand', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _vehicleStatusColor(String status) => switch (status) {
    'moving'  => const Color(0xFF3B82F6),
    'parked'  => const Color(0xFF94A3B8),
    'service' => const Color(0xFFF59E0B),
    _         => Colors.grey,
  };

  Widget _statusPill(IconData icon, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    ],
  );

  void _openFullMap(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const Dialog(
        insetPadding: EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        child: _NetworkMapDialog(vehicles: _fleetVehicles),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen Network Map Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkMapDialog extends StatefulWidget {
  final List<Map<String, Object>> vehicles;
  const _NetworkMapDialog({required this.vehicles});

  @override
  State<_NetworkMapDialog> createState() => _NetworkMapDialogState();
}

class _NetworkMapDialogState extends State<_NetworkMapDialog> {
  final MapController _ctrl = MapController();
  int? _selected;

  Color _statusColor(String s) => switch (s) {
    'moving'  => const Color(0xFF3B82F6),
    'parked'  => const Color(0xFF94A3B8),
    'service' => const Color(0xFFF59E0B),
    _         => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final sel = _selected != null ? widget.vehicles[_selected!] : null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: (mq.width - 48).clamp(400, 900),
        maxHeight: mq.height * 0.88,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Row(children: [
            const Icon(Icons.map_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Fleet Network Map',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${widget.vehicles.length} vehicles tracked in real-time',
                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ])),
            // Legend chips
            Row(children: [
              _legendChip('Moving',  const Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              _legendChip('Parked',  const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              _legendChip('Service', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
            ]),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ]),
        ),

        // Map body
        Flexible(
          child: Stack(children: [
            FlutterMap(
              mapController: _ctrl,
              options: MapOptions(
                initialCenter: const LatLng(37.5, -97.0),
                initialZoom: 3.8,
                onTap: (_, __) => setState(() => _selected = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fleet.command',
                ),
                MarkerLayer(
                  markers: widget.vehicles.asMap().entries.map((entry) {
                    final i = entry.key;
                    final v = entry.value;
                    final color = _statusColor(v['status'] as String);
                    final isSel = _selected == i;
                    return Marker(
                      point: LatLng(v['lat'] as double, v['lng'] as double),
                      width: isSel ? 44 : 32,
                      height: isSel ? 44 : 32,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selected = i);
                          _ctrl.move(LatLng(v['lat'] as double, v['lng'] as double), 6);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: isSel ? 3 : 2),
                            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: isSel ? 12 : 4)],
                          ),
                          child: Icon(
                            v['status'] == 'moving' ? Icons.local_shipping
                                : v['status'] == 'service' ? Icons.build
                                : Icons.local_parking,
                            color: Colors.white,
                            size: isSel ? 22 : 15,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            // Vehicle info card (appears when a marker is tapped)
            if (sel != null)
              Positioned(
                bottom: 16, left: 16, right: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(sel['id']),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: _statusColor(sel['status'] as String).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.local_shipping,
                            color: _statusColor(sel['status'] as String), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(sel['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        Text('${sel['id']}  ·  Lat ${(sel['lat'] as double).toStringAsFixed(4)}, Lng ${(sel['lng'] as double).toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ])),
                      const SizedBox(width: 12),
                      _infoChip(Icons.speed, '${sel['speed']} km/h', const Color(0xFF3B82F6)),
                      const SizedBox(width: 8),
                      _infoChip(Icons.local_gas_station, '${sel['fuel']}%',
                          (sel['fuel'] as int) < 40 ? const Color(0xFFEF4444) : const Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(sel['status'] as String),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text((sel['status'] as String).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  ),
                ),
              ),

            // Zoom controls
            Positioned(
              top: 12, right: 12,
              child: Column(children: [
                _mapBtn(Icons.add, () => _ctrl.move(_ctrl.camera.center, _ctrl.camera.zoom + 1)),
                const SizedBox(height: 4),
                _mapBtn(Icons.remove, () => _ctrl.move(_ctrl.camera.center, _ctrl.camera.zoom - 1)),
                const SizedBox(height: 4),
                _mapBtn(Icons.my_location, () => _ctrl.move(const LatLng(37.5, -97.0), 3.8)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _legendChip(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.circle, size: 8, color: color),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]);

  Widget _infoChip(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _mapBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF0F172A)),
    ),
  );
}

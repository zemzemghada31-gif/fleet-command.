import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/analytics_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/devices_page.dart';
import 'pages/trajectory_page.dart';
import 'pages/vehicle_page.dart';
import 'pages/maintenance_page.dart';
import 'pages/historique_es_page.dart';
import 'pages/login_page.dart';
import 'pages/users_page.dart';
import 'pages/access_page.dart';
import 'pages/delivery_page.dart';
import 'nav_service.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ParkingLoraApp());
}

// ─── Notification model ───────────────────────────────────────────────────────

class _NotifItem {
  final String id, title, body, type, time;
  bool read;
  _NotifItem({required this.id, required this.title, required this.body,
              required this.type, required this.time, this.read = false});
}

// ─── Admin profile model ──────────────────────────────────────────────────────

class _AdminData {
  String name;
  String email;
  String title;
  String department;
  String phone;
  String bio;
  _AdminData({
    this.name       = 'Admin User',
    this.email      = 'admin@fleetcommand.io',
    this.title      = 'Fleet Operations Manager',
    this.department = 'Operations',
    this.phone      = '+1 (800) 555-FLEET',
    this.bio        = 'Responsible for real-time fleet monitoring and operations.',
  });
  String get initials => name.trim().isEmpty ? 'A'
      : name.trim().split(' ').map((w) => w[0].toUpperCase()).take(2).join();
}

// ─────────────────────────────────────────────────────────────────────────────

class ParkingLoraApp extends StatefulWidget {
  const ParkingLoraApp({super.key});
  @override
  State<ParkingLoraApp> createState() => _ParkingLoraAppState();
}

class _ParkingLoraAppState extends State<ParkingLoraApp> {
  Locale _locale = const Locale('en');

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_locale') ?? 'en';
    if (mounted) setState(() => _locale = Locale(code));
  }

  void _changeLocale(Locale locale) {
    setState(() => _locale = locale);
    SharedPreferences.getInstance().then((prefs) => prefs.setString('app_locale', locale.languageCode));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fleet Command - Active Ops',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/home':  (_) => MainNavigationWrapper(onLocaleChanged: _changeLocale, locale: _locale),
      },
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  final void Function(Locale) onLocaleChanged;
  final Locale locale;
  const MainNavigationWrapper({super.key, required this.onLocaleChanged, required this.locale});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _selectedIndex = 0;
  late AppLoc _appLoc;

  late final List<Widget> _pages;

  // ─── Admin profile ─────────────────────────────────────────────────────────
  final _admin = _AdminData();

  // ─── Notifications ─────────────────────────────────────────────────────────
  final List<_NotifItem> _notifications = [
    _NotifItem(id: '1', title: 'Speed Alert — TX-0912-A',      body: '89 mph on I-90, Chicago. Driver: Marcus Reed.',         type: 'alert',   time: '2 min ago'),
    _NotifItem(id: '2', title: 'Maintenance Due — FL-1102-K',  body: 'Engine check overdue by 3 days. Scheduled at Hub #4.',  type: 'warning', time: '15 min ago'),
    _NotifItem(id: '3', title: 'Fuel Low — CA-5501-M',         body: '18% fuel remaining on US-101. Elena Torres driving.',   type: 'warning', time: '38 min ago'),
    _NotifItem(id: '4', title: 'NY-8271-C Arrived',            body: 'Delivered to South Bay Distribution. Offloading now.',  type: 'success', time: '1h ago',  read: true),
    _NotifItem(id: '5', title: 'Weekly Report Ready',          body: 'Fleet performance report for the week is available.',   type: 'info',    time: 'Yesterday', read: true),
  ];

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  List<String> get _pageTitles => [
    _appLoc.home, _appLoc.dashboard, _appLoc.devices, _appLoc.vehicles, _appLoc.trajectory,
    _appLoc.maintenance, _appLoc.deliveries, _appLoc.history, _appLoc.accessControl, _appLoc.users,
  ];
  List<String> get _pageSubtitles => [
    _appLoc.subAnalytics, _appLoc.subDashboard, _appLoc.subDevices, _appLoc.subVehicles,
    _appLoc.subTrajectory, _appLoc.subMaintenance, _appLoc.subDeliveries,
    _appLoc.subHistory, _appLoc.subAccess, _appLoc.subUsers,
  ];
  static const _pageIcons   = [Icons.analytics_outlined, Icons.dashboard_outlined, Icons.sensors_outlined,
                                Icons.local_shipping_outlined, Icons.timeline_outlined, Icons.build_outlined, Icons.local_shipping, Icons.swap_horiz_outlined,
                                Icons.security_outlined, Icons.people_outlined];

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  void _showNotifPanel() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 72, right: 72),
            child: Material(
              elevation: 16,
              borderRadius: BorderRadius.circular(14),
              shadowColor: Colors.black26,
              child: _NotifPanel(
                notifications: _notifications,
                onMarkAll: () {
                  for (final n in _notifications) { n.read = true; }
                  setDialogState(() {});
                  setState(() {});
                },
                onMarkOne: (id) {
                  final n = _notifications.firstWhere((n) => n.id == id);
                  n.read = true;
                  setDialogState(() {});
                  setState(() {});
                },
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsPanel() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 72, right: 32),
          child: Material(
            elevation: 16,
            borderRadius: BorderRadius.circular(14),
            shadowColor: Colors.black26,
            child: _SettingsPanel(
              currentLocale: widget.locale,
              onLanguageChanged: (l) {
                widget.onLocaleChanged(l);
                Navigator.of(ctx).pop();
              },
              onClose: () => Navigator.of(ctx).pop(),
              onSaved: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(_appLoc.tr('Settings saved successfully', fr: 'Paramètres enregistrés', ar: 'تم حفظ الإعدادات بنجاح')),
                  ]),
                  backgroundColor: const Color(0xFF0F172A),
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showProfilePanel() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 72, right: 16),
          child: Material(
            elevation: 16,
            borderRadius: BorderRadius.circular(14),
            shadowColor: Colors.black26,
            child: _ProfilePanel(
              appLoc: _appLoc,
              admin: _admin,
              onClose: () => Navigator.of(ctx).pop(),
              onProfileUpdated: (updated) {
                setState(() {
                  _admin.name       = updated.name;
                  _admin.email      = updated.email;
                  _admin.title      = updated.title;
                  _admin.department = updated.department;
                  _admin.phone      = updated.phone;
                  _admin.bio        = updated.bio;
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(_appLoc.tr('Profile updated successfully', fr: 'Profil mis à jour', ar: 'تم تحديث الملف الشخصي بنجاح')),
                  ]),
                  backgroundColor: const Color(0xFF3B82F6),
                  duration: const Duration(seconds: 3),
                ));
              },
              onLogout: () {
                Navigator.of(ctx).pop();
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text(_appLoc.confirmLogout),
                    content: Text(_appLoc.logoutMessage),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(_appLoc.cancel)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.of(context, rootNavigator: true)
                            .pushNamedAndRemoveUntil('/login', (_) => false),
                        child: Text(_appLoc.logout, style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appLoc = AppLoc(widget.locale);
  }

  @override
  void didUpdateWidget(MainNavigationWrapper old) {
    super.didUpdateWidget(old);
    if (old.locale != widget.locale) {
      _appLoc = AppLoc(widget.locale);
    }
  }

  @override
  void initState() {
    super.initState();
    _appLoc = AppLoc(widget.locale);
    _pages = [
      const AnalyticsPage(), const DashboardPage(), const DevicesPage(),
      const VehiclePage(), const TrajectoryPage(), const MaintenancePage(),
      const DeliveryPage(),
      HistoriqueESPage(onNavigate: (int pageIndex, String plate, String model) {
        NavService.instance.navigate(pageIndex, plate, model);
        setState(() => _selectedIndex = pageIndex);
      }),
      const AccessControlPage(),
      const UsersPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final scaffold = Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          appBar: isMobile
              ? AppBar(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  scrolledUnderElevation: 1,
                  leading: Builder(
                    builder: (drawerContext) => IconButton(
                      icon: const Icon(Icons.menu, color: Color(0xFF0F172A)),
                      onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                    ),
                  ),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.local_shipping, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text('Fleet Command',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
                    ],
                  ),
                  actions: [
                    _TopBarIconButton(
                      tooltip: 'Notifications',
                      badge: _unreadCount > 0 ? '' : null,
                      onTap: _showNotifPanel,
                      child: const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _showProfilePanel,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildAvatar(radius: 12, initials: _admin.initials),
                      ),
                    ),
                  ],
                )
              : null,
          drawer: isMobile
              ? Drawer(
                  backgroundColor: Colors.white,
                  child: SafeArea(child: SingleChildScrollView(child: _buildSidebarContent())),
                )
              : null,
          body: isMobile
              ? Column(children: [
                  Expanded(child: IndexedStack(index: _selectedIndex, children: _pages)),
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // -- Sidebar (inline) --
                  Container(
                    width: 210,
                    color: Colors.white,
                    child: SingleChildScrollView(child: _buildSidebarContent()),
                  ),
                  // -- Main Content --
                  Expanded(
                    child: Column(children: [
                      _buildTopBar(),
                      Expanded(child: IndexedStack(index: _selectedIndex, children: _pages)),
                    ]),
                  ),
                ]),
        );
        return scaffold;
      },
    );
  }

  /// Shared sidebar content used inline (desktop) and inside Drawer (mobile).
  Widget _buildSidebarContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Brand
          Row(children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.local_shipping, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text('Fleet Command', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A))),
          ]),
          const SizedBox(height: 10),
          _buildSidebarProfile(),
        ]),
      ),
      _buildSidebarItem(Icons.home_outlined,            _appLoc.home,           index: 0),
      _buildSidebarItem(Icons.dashboard_outlined,       _appLoc.dashboard,      index: 1),
      _buildSidebarItem(Icons.sensors_outlined,         _appLoc.devices,        index: 2),
      _buildSidebarItem(Icons.local_shipping_outlined,  _appLoc.vehicles,       index: 3),
      _buildSidebarItem(Icons.timeline,                 _appLoc.trajectory,     index: 4),
      _buildSidebarItem(Icons.build_outlined,           _appLoc.maintenance,    index: 5),
      _buildSidebarItem(Icons.local_shipping,           _appLoc.deliveries,     index: 6),
      _buildSidebarItem(Icons.swap_horiz_outlined,      _appLoc.history,        index: 7),
      _buildSidebarItem(Icons.security_outlined,        _appLoc.accessControl,  index: 8),
      _buildSidebarItem(Icons.people_outlined,          _appLoc.users,          index: 9),
      const Divider(height: 1),
      const SizedBox(height: 2),
      _buildSidebarItem(Icons.help_outline, _appLoc.support, customOnTap: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_appLoc.tr('Fleet Command Support', fr: 'Support Fleet Command', ar: '??? ????? ???????')),
          content: Text(_appLoc.tr(
            'For technical assistance, contact:\n\nsupport@fleetcommand.io\n+1 (800) 555-FLEET\n\nAvailable 24/7',
            fr: 'Pour une assistance technique :\n\nsupport@fleetcommand.io\n+1 (800) 555-FLEET\n\nDisponible 24/7',
            ar: '????????? ?????:\n\nsupport@fleetcommand.io\n+1 (800) 555-FLEET\n\n???? 24/7',
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(_appLoc.close))],
        ),
      )),
      _buildSidebarItem(Icons.logout, _appLoc.logout, customOnTap: () => _showProfilePanel()),
    ]);
  }

  // ─── Sidebar profile card ─────────────────────────────────────────────────
  Widget _buildSidebarProfile() {
    return GestureDetector(
      onTap: _showProfilePanel,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          _buildAvatar(radius: 14, initials: _admin.initials),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_admin.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: const Color(0xFF0F172A))),
              Row(children: [
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 3),
                Text(_appLoc.activeOps, style: GoogleFonts.inter(fontSize: 8, color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              ]),
          ])),
          const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
        ]),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    final title    = _pageTitles[_selectedIndex];
    final subtitle = _pageSubtitles[_selectedIndex];
    final icon     = _pageIcons[_selectedIndex];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: Row(children: [
        // Page title
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0F172A)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
            Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
          ]),
        ]),
        const SizedBox(width: 24),

        // Search bar
        Expanded(child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(children: [
            const Icon(Icons.search, size: 17, color: Color(0xFF94A3B8)),
            const SizedBox(width: 10),
              Expanded(child: TextField(
                decoration: InputDecoration(
                  hintText: _appLoc.search,
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none, isDense: true,
                ),
              )),
          ]),
        )),
        const SizedBox(width: 20),

        // ── Notifications ──
        _TopBarIconButton(
          tooltip: 'Notifications',
          badge: _unreadCount > 0 ? '$_unreadCount' : null,
          onTap: _showNotifPanel,
          child: const Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF475569)),
        ),
        const SizedBox(width: 8),

        // ── Settings ──
        _TopBarIconButton(
          tooltip: 'Settings',
          onTap: _showSettingsPanel,
          child: const Icon(Icons.tune_outlined, size: 20, color: Color(0xFF475569)),
        ),
        const SizedBox(width: 16),

        // Vertical divider
        Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
        const SizedBox(width: 16),

        // ── Profile button ──
        GestureDetector(
          onTap: _showProfilePanel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(children: [
              _buildAvatar(radius: 14, initials: _admin.initials),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_admin.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF0F172A))),
                Text(_admin.title.split(' ').take(2).join(' '), style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
              ]),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, size: 16, color: Color(0xFF94A3B8)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── Shared gradient avatar ───────────────────────────────────────────────
  Widget _buildAvatar({required double radius, String initials = 'A'}) {
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(initials, style: GoogleFonts.inter(
        color: Colors.white, fontSize: radius * 0.75, fontWeight: FontWeight.bold,
      ))),
    );
  }

  // ─── Sidebar item ─────────────────────────────────────────────────────────
  Widget _buildSidebarItem(IconData icon, String label, {int? index, VoidCallback? customOnTap}) {
    final isSelected = index != null && _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        onTap: customOnTap ?? (index != null ? () => setState(() => _selectedIndex = index) : null),
        leading: Icon(icon, color: isSelected ? Colors.white : const Color(0xFF64748B), size: 16),
        title: Text(label, style: GoogleFonts.inter(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        )),
        dense: true,
        visualDensity: VisualDensity.compact,
        minLeadingWidth: 20,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        trailing: isSelected ? Container(
          width: 5, height: 5,
          decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
        ) : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar Icon Button (with optional badge)
// ─────────────────────────────────────────────────────────────────────────────

class _TopBarIconButton extends StatelessWidget {
  final Widget child;
  final String tooltip;
  final String? badge;
  final VoidCallback onTap;
  const _TopBarIconButton({required this.child, required this.tooltip, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Stack(alignment: Alignment.center, children: [
            child,
            if (badge != null)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications Panel
// ─────────────────────────────────────────────────────────────────────────────

class _NotifPanel extends StatelessWidget {
  final List<_NotifItem> notifications;
  final VoidCallback onMarkAll;
  final void Function(String id) onMarkOne;
  final VoidCallback onClose;
  const _NotifPanel({required this.notifications, required this.onMarkAll, required this.onMarkOne, required this.onClose});

  Color _typeColor(String t) {
    switch (t) {
      case 'alert':   return Colors.red;
      case 'warning': return Colors.orange;
      case 'success': return Colors.green;
      case 'info':    return Colors.blue;
      default:        return Colors.grey;
    }
  }
  IconData _typeIcon(String t) {
    switch (t) {
      case 'alert':   return Icons.warning_amber_rounded;
      case 'warning': return Icons.error_outline;
      case 'success': return Icons.check_circle_outline;
      case 'info':    return Icons.info_outline;
      default:        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((n) => !n.read).length;
    return SizedBox(
      width: math.min(MediaQuery.of(context).size.width - 32, 360),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Notifications', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                child: Text('$unread new', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
            const Spacer(),
            if (unread > 0)
              TextButton(
                onPressed: onMarkAll,
                style: TextButton.styleFrom(foregroundColor: Colors.blue.shade300, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text('Mark all read', style: GoogleFonts.inter(fontSize: 11)),
              ),
            IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18), onPressed: onClose, constraints: const BoxConstraints()),
          ]),
        ),
        // List
        ...notifications.map((n) => _buildNotifItem(n)),
        // Footer
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade100)),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14)),
          ),
          child: TextButton(
            onPressed: onClose,
            child: Text('View all notifications', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3B82F6))),
          ),
        ),
      ]),
    );
  }

  Widget _buildNotifItem(_NotifItem n) {
    final color = _typeColor(n.type);
    return Container(
      decoration: BoxDecoration(
        color: n.read ? Colors.white : color.withValues(alpha: 0.03),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
          left: BorderSide(color: n.read ? Colors.transparent : color, width: 3),
        ),
      ),
      child: ListTile(
        onTap: () => onMarkOne(n.id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(_typeIcon(n.type), color: color, size: 17),
        ),
        title: Text(n.title, style: GoogleFonts.inter(
          fontSize: 13, fontWeight: n.read ? FontWeight.normal : FontWeight.bold,
          color: const Color(0xFF0F172A),
        )),
        subtitle: Text(n.body, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(n.time, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
          if (!n.read) ...[
            const SizedBox(height: 4),
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Panel
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsPanel extends StatefulWidget {
  final Locale currentLocale;
  final void Function(Locale) onLanguageChanged;
  final VoidCallback onClose;
  final VoidCallback onSaved;
  const _SettingsPanel({
    required this.currentLocale,
    required this.onLanguageChanged,
    required this.onClose,
    required this.onSaved,
  });
  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  bool _notifEnabled  = true;
  bool _compactView   = false;
  bool _autoRefresh   = true;
  int  _refreshSecs   = 5;
  String _mapStyle    = 'Streets';
  late String _langValue;

  @override
  void initState() {
    super.initState();
    _langValue = _localeLabel(widget.currentLocale);
  }

  String _localeLabel(Locale l) {
    switch (l.languageCode) {
      case 'fr': return 'Français';
      case 'ar': return 'العربية';
      default:   return 'English';
    }
  }

  Locale _parseLocale(String label) {
    switch (label) {
      case 'Français':  return const Locale('fr');
      case 'العربية':   return const Locale('ar');
      default:          return const Locale('en');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLoc(widget.currentLocale);
    return SizedBox(
      width: math.min(MediaQuery.of(context).size.width - 32, 300),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          ),
          child: Row(children: [
            const Icon(Icons.tune, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(loc.settings, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18), onPressed: widget.onClose, constraints: const BoxConstraints()),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel(loc.display),
            _toggleRow(loc.pushNotif, Icons.notifications_outlined, _notifEnabled, (v) => setState(() => _notifEnabled = v)),
            _toggleRow(loc.compactSidebar, Icons.view_sidebar_outlined, _compactView, (v) => setState(() => _compactView = v)),
            const SizedBox(height: 12),
            _sectionLabel(loc.data),
            _toggleRow(loc.autoRefresh, Icons.sync, _autoRefresh, (v) => setState(() => _autoRefresh = v)),
            if (_autoRefresh) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 10),
                Text(loc.refreshEvery, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
                const Spacer(),
                _segmented([5, 10, 30], _refreshSecs, (v) => setState(() => _refreshSecs = v), suffix: 's'),
              ]),
            ],
            const SizedBox(height: 12),
            _sectionLabel(loc.map),
            Row(children: [
              const Icon(Icons.map_outlined, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              Text(loc.mapStyle, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
              const Spacer(),
              _segmented(['Streets', 'Satellite'], _mapStyle, (v) => setState(() => _mapStyle = v)),
            ]),
            const SizedBox(height: 12),
            _sectionLabel(loc.regional),
            Row(children: [
              const Icon(Icons.language, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              Text(loc.language, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
              const Spacer(),
              DropdownButton<String>(
                value: _langValue,
                isDense: true,
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF0F172A)),
                items: [loc.langEn, loc.langFr, loc.langAr]
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _langValue = v);
                  widget.onLanguageChanged(_parseLocale(v));
                },
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onSaved,
                child: Text(loc.saveChanges, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 1)),
  );

  Widget _toggleRow(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569))),
        const Spacer(),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value, onChanged: onChanged,
            activeThumbColor: const Color(0xFF3B82F6),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]),
    );
  }

  Widget _segmented<T>(List<T> options, T selected, ValueChanged<T> onChanged, {String suffix = ''}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < options.length; i++) ...[
        GestureDetector(
          onTap: () => onChanged(options[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: selected == options[i] ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.horizontal(
                left:  Radius.circular(i == 0 ? 6 : 0),
                right: Radius.circular(i == options.length - 1 ? 6 : 0),
              ),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text('${options[i]}$suffix', style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.bold,
              color: selected == options[i] ? Colors.white : const Color(0xFF475569),
            )),
          ),
        ),
      ],
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Panel
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePanel extends StatefulWidget {
  final AppLoc appLoc;
  final _AdminData admin;
  final VoidCallback onClose;
  final void Function(_AdminData) onProfileUpdated;
  final VoidCallback onLogout;
  const _ProfilePanel({
    required this.appLoc,
    required this.admin,
    required this.onClose,
    required this.onProfileUpdated,
    required this.onLogout,
  });
  @override
  State<_ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<_ProfilePanel> {

  void _openEditProfile() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _EditProfileDialog(
          admin: widget.admin,
          onSave: (updated) {
            widget.onProfileUpdated(updated);
            setState(() {}); // refresh panel header
          },
        ),
      ),
    );
  }

  void _openChangePassword() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _ChangePasswordDialog(
          onSuccess: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Row(children: [
                Icon(Icons.lock, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Password changed successfully'),
              ]),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.admin;
    final loc = widget.appLoc;
    return SizedBox(
      width: math.min(MediaQuery.of(context).size.width - 32, 300),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Profile header ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14)),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: widget.onClose, constraints: const BoxConstraints(), padding: EdgeInsets.zero,
              ),
            ]),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 12)],
              ),
              child: Center(child: Text(a.initials, style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 12),
            Text(a.name,  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 4),
            Text(a.title, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(loc.activeOps, style: GoogleFonts.inter(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _infoRow(Icons.email_outlined,      a.email),
            _infoRow(Icons.phone_outlined,       a.phone),
            _infoRow(Icons.badge_outlined,       loc.tr('Full Admin Access', fr: 'Accès Admin complet', ar: 'وصول المسؤول الكامل')),
            _infoRow(Icons.business_outlined,    loc.tr('${a.department} Department', fr: 'Département ${a.department}', ar: 'قسم ${a.department}')),
            _infoRow(Icons.access_time_outlined, loc.tr('Last login: Today, 09:42 AM', fr: 'Dernière connexion : Aujourd\'hui, 09:42', ar: 'آخر تسجيل دخول: اليوم, 09:42')),
            const SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),
            _actionButton(Icons.manage_accounts_outlined, loc.editProfile,    const Color(0xFF0F172A), Colors.white,               _openEditProfile),
            const SizedBox(height: 8),
            _actionButton(Icons.lock_outline,             loc.changePassword, const Color(0xFFF8FAFC), const Color(0xFF0F172A),    _openChangePassword, border: true),
            const SizedBox(height: 8),
            _actionButton(Icons.logout,                   loc.signOut,        Colors.red.shade50,       Colors.red, widget.onLogout, border: true, borderColor: Colors.red.shade200),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _actionButton(IconData icon, String label, Color bg, Color fg, VoidCallback onTap,
      {bool border = false, Color? borderColor}) {
    return SizedBox(
      width: double.infinity, height: 40,
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 15),
        label: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg, foregroundColor: fg,
          side: border ? BorderSide(color: borderColor ?? const Color(0xFFE2E8F0)) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Profile Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _EditProfileDialog extends StatefulWidget {
  final _AdminData admin;
  final void Function(_AdminData) onSave;
  const _EditProfileDialog({required this.admin, required this.onSave});
  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _bioCtrl;
  late String _department;
  bool _saving = false;

  static const _departments = ['Operations', 'IT', 'Finance', 'Management', 'Logistics', 'Security'];

  @override
  void initState() {
    super.initState();
    final a = widget.admin;
    _nameCtrl  = TextEditingController(text: a.name);
    _emailCtrl = TextEditingController(text: a.email);
    _titleCtrl = TextEditingController(text: a.title);
    _phoneCtrl = TextEditingController(text: a.phone);
    _bioCtrl   = TextEditingController(text: a.bio);
    _department = a.department;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _emailCtrl, _titleCtrl, _phoneCtrl, _bioCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 500));
    final updated = _AdminData(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      department: _department,
      phone: _phoneCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
    widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context).size;
    final maxW = (mq.width - 64).clamp(280.0, 520.0);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxW,
        maxHeight: mq.height * 0.90,
      ),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header (fixed, never scrolls) ──────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: Center(child: Text(
                  _nameCtrl.text.trim().isEmpty
                      ? 'A'
                      : _nameCtrl.text.trim().split(' ')
                          .map((w) => w[0].toUpperCase())
                          .take(2)
                          .join(),
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Edit Profile',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('Update your account information',
                    style: GoogleFonts.inter(
                        color: Colors.white54, fontSize: 11)),
              ])),
              IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white54, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),

          // ── Scrollable body ────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Row 1: Name + Email
                Row(children: [
                  Expanded(child: _field(
                    'Full Name', _nameCtrl, Icons.person_outline,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                    onChanged: (_) => setState(() {}),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _field(
                    'Email Address', _emailCtrl, Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                  )),
                ]),
                const SizedBox(height: 14),

                // Row 2: Title + Phone
                Row(children: [
                  Expanded(child: _field(
                    'Job Title', _titleCtrl, Icons.work_outline,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _field(
                      'Phone', _phoneCtrl, Icons.phone_outlined)),
                ]),
                const SizedBox(height: 14),

                // Department chips
                Text('Department',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151))),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final d in _departments)
                    GestureDetector(
                      onTap: () => setState(() => _department = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _department == d
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _department == d
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(d,
                            style: GoogleFonts.inter(
                              color: _department == d
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),

                // Bio
                Text('Bio / Notes',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF374151))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: _inputDecoration(
                      'Brief description of your role…',
                      Icons.notes_outlined),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 42,
                    width: 140,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.save_outlined, size: 16),
                                const SizedBox(width: 6),
                                Text('Save Profile',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 13),
        decoration: _inputDecoration(label, icon),
        validator: validator,
      ),
    ]);
  }

  InputDecoration _inputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
    prefixIcon: Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Change Password Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const _ChangePasswordDialog({required this.onSuccess});
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _currCtrl = TextEditingController();
  final _newCtrl  = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _showCurr = false, _showNew = false, _showConf = false;
  bool _saving = false;
  String? _currError;

  @override
  void dispose() {
    _currCtrl.dispose(); _newCtrl.dispose(); _confCtrl.dispose();
    super.dispose();
  }

  int _strength(String pw) {
    if (pw.length < 4) return 0;
    int s = 0;
    if (pw.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) s++;
    if (RegExp(r'[0-9]').hasMatch(pw)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) s++;
    return s;
  }

  String _strengthLabel(int s) => ['Too short', 'Weak', 'Fair', 'Strong', 'Very Strong'][s];
  Color  _strengthColor(int s) => [Colors.grey, Colors.red, Colors.orange, Colors.amber, Colors.green][s];

  Future<void> _submit() async {
    setState(() => _currError = null);
    if (!_formKey.currentState!.validate()) return;
    // Mock: current password must be "admin123"
    if (_currCtrl.text != 'admin123') {
      setState(() => _currError = 'Incorrect current password');
      return;
    }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) Navigator.of(context).pop();
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final pw = _newCtrl.text;
    final s  = _strength(pw);

    final mq = MediaQuery.of(context).size;
    final maxW = (mq.width - 64).clamp(260.0, 440.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: mq.height * 0.90),
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header (fixed) ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.lock_reset,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Change Password',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                Text('Choose a strong, unique password',
                    style: GoogleFonts.inter(
                        color: Colors.white54, fontSize: 11)),
              ])),
              IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white54, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),

          // ── Scrollable body ──────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _pwField('Current Password', _currCtrl, _showCurr,
                    () => setState(() => _showCurr = !_showCurr),
                    error: _currError,
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Enter your current password'
                        : null),
                const SizedBox(height: 14),
                _pwField('New Password', _newCtrl, _showNew,
                    () => setState(() => _showNew = !_showNew),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a new password';
                      if (v.length < 8) return 'At least 8 characters required';
                      return null;
                    }),
                if (pw.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: s / 4,
                        backgroundColor: Colors.grey.shade200,
                        color: _strengthColor(s),
                        minHeight: 5,
                      ),
                    )),
                    const SizedBox(width: 10),
                    Text(_strengthLabel(s),
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _strengthColor(s),
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  _req('At least 8 characters',   pw.length >= 8),
                  _req('Uppercase letter (A–Z)',   RegExp(r'[A-Z]').hasMatch(pw)),
                  _req('Number (0–9)',             RegExp(r'[0-9]').hasMatch(pw)),
                  _req('Special character (!@#…)', RegExp(r'[^A-Za-z0-9]').hasMatch(pw)),
                ],
                const SizedBox(height: 14),
                _pwField('Confirm New Password', _confCtrl, _showConf,
                    () => setState(() => _showConf = !_showConf),
                    validator: (v) =>
                        v != _newCtrl.text ? 'Passwords do not match' : null),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: GoogleFonts.inter(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 42,
                    width: 160,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_outline, size: 16),
                                const SizedBox(width: 6),
                                Text('Update Password',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool visible, VoidCallback toggle, {
    String? Function(String?)? validator, void Function(String)? onChanged, String? error,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        obscureText: !visible,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 13),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
          prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Color(0xFF94A3B8)),
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18, color: const Color(0xFF94A3B8)),
            onPressed: toggle,
          ),
          errorText: error,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error != null ? Colors.red : const Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          isDense: true,
        ),
        validator: validator,
      ),
    ]);
  }

  Widget _req(String text, bool met) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(children: [
      Icon(met ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 13, color: met ? Colors.green : Colors.grey),
      const SizedBox(width: 6),
      Text(text, style: GoogleFonts.inter(fontSize: 11, color: met ? Colors.green : Colors.grey)),
    ]),
  );
}


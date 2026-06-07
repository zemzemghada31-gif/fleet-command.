import 'package:flutter/material.dart';

class AppLoc {
  final Locale locale;
  AppLoc(this.locale);

  String get langCode => locale.languageCode;

  String tr(String en, {String? fr, String? ar}) {
    if (langCode == 'fr' && fr != null) return fr;
    if (langCode == 'ar' && ar != null) return ar;
    return en;
  }

  // ── Sidebar ──
  String get home => tr('Analytics', fr: 'Analytique', ar: 'التحليلات');
  String get dashboard => tr('Dashboard', fr: 'Tableau de bord', ar: 'لوحة القيادة');
  String get devices => tr('Devices', fr: 'Appareils', ar: 'الأجهزة');
  String get vehicles => tr('Vehicles', fr: 'Véhicules', ar: 'المركبات');
  String get trajectory => tr('Trajectory', fr: 'Trajectoire', ar: 'المسار');
  String get maintenance => tr('Maintenance', fr: 'Maintenance', ar: 'الصيانة');
  String get deliveries => tr('Deliveries', fr: 'Livraisons', ar: 'التسليم');
  String get history => tr('Hist. E/S', fr: 'Hist. E/S', ar: 'سجل الدخول');
  String get accessControl => tr('Access Ctrl', fr: 'Contrôle d\'accès', ar: 'التحكم في الوصول');
  String get users => tr('Users', fr: 'Utilisateurs', ar: 'المستخدمين');
  String get support => tr('Support', fr: 'Support', ar: 'الدعم');
  String get logout => tr('Logout', fr: 'Déconnexion', ar: 'تسجيل الخروج');

  // ── Page subtitles ──
  String get subAnalytics => tr('Fleet Overview', fr: 'Aperçu de la flotte', ar: 'نظرة عامة على الأسطول');
  String get subDashboard => tr('Real-time GPS', fr: 'GPS en temps réel', ar: 'GPS مباشر');
  String get subDevices => tr('IoT Sensors', fr: 'Capteurs IoT', ar: 'أجهزة الاستشعار');
  String get subVehicles => tr('Fleet Management', fr: 'Gestion de flotte', ar: 'إدارة الأسطول');
  String get subTrajectory => tr('Route History', fr: 'Historique des routes', ar: 'سجل المسارات');
  String get subMaintenance => tr('Service & OBD', fr: 'Service & OBD', ar: 'الصيانة والتشخيص');
  String get subDeliveries => tr('Auto Arrivals', fr: 'Arrivées automatiques', ar: 'الوصول التلقائي');
  String get subHistory => tr('Entry/Exit', fr: 'Entrée/Sortie', ar: 'دخول/خروج');
  String get subAccess => tr('Plate & Gate Mgmt', fr: 'Gestion des plaques', ar: 'إدارة اللوحات والبوابات');
  String get subUsers => tr('User Management', fr: 'Gestion des utilisateurs', ar: 'إدارة المستخدمين');

  // ── Common ──
  String get search => tr('Search fleet resources…', fr: 'Rechercher…', ar: 'ابحث في موارد الأسطول…');
  String get notifications => tr('Notifications', fr: 'Notifications', ar: 'الإشعارات');
  String get settings => tr('Settings', fr: 'Paramètres', ar: 'الإعدادات');
  String get save => tr('Save', fr: 'Enregistrer', ar: 'حفظ');
  String get saveChanges => tr('Save Changes', fr: 'Enregistrer', ar: 'حفظ التغييرات');
  String get cancel => tr('Cancel', fr: 'Annuler', ar: 'إلغاء');
  String get delete => tr('Delete', fr: 'Supprimer', ar: 'حذف');
  String get restore => tr('Restore', fr: 'Restaurer', ar: 'استعادة');
  String get edit => tr('Edit', fr: 'Modifier', ar: 'تعديل');
  String get refresh => tr('Refresh', fr: 'Actualiser', ar: 'تحديث');
  String get filter => tr('Filter', fr: 'Filtrer', ar: 'تصفية');
  String get exportCsv => tr('Export CSV', fr: 'Exporter CSV', ar: 'تصدير CSV');
  String get close => tr('Close', fr: 'Fermer', ar: 'إغلاق');
  String get noData => tr('No data', fr: 'Aucune donnée', ar: 'لا توجد بيانات');
  String get loading => tr('Loading…', fr: 'Chargement…', ar: 'جارٍ التحميل…');

  // ── Settings panel ──
  String get display => tr('DISPLAY', fr: 'AFFICHAGE', ar: 'العرض');
  String get pushNotif => tr('Push Notifications', fr: 'Notifications push', ar: 'الإشعارات');
  String get compactSidebar => tr('Compact Sidebar', fr: 'Barre latérale compacte', ar: 'شريط جانبي مضغوط');
  String get data => tr('DATA', fr: 'DONNÉES', ar: 'البيانات');
  String get autoRefresh => tr('Auto Refresh', fr: 'Actualisation auto', ar: 'تحديث تلقائي');
  String get refreshEvery => tr('Refresh every', fr: 'Actualiser chaque', ar: 'تحديث كل');
  String get map => tr('MAP', fr: 'CARTE', ar: 'الخريطة');
  String get mapStyle => tr('Map style', fr: 'Style de carte', ar: 'نمط الخريطة');
  String get regional => tr('REGIONAL', fr: 'RÉGIONAL', ar: 'الإقليمي');
  String get language => tr('Language', fr: 'Langue', ar: 'اللغة');

  // ── Profile panel ──
  String get profile => tr('Profile', fr: 'Profil', ar: 'الملف الشخصي');
  String get editProfile => tr('Edit Profile', fr: 'Modifier le profil', ar: 'تعديل الملف الشخصي');
  String get changePassword => tr('Change Password', fr: 'Changer mot de passe', ar: 'تغيير كلمة المرور');
  String get signOut => tr('Sign Out', fr: 'Déconnexion', ar: 'تسجيل الخروج');
  String get confirmLogout => tr('Confirm Logout', fr: 'Confirmer la déconnexion', ar: 'تأكيد تسجيل الخروج');
  String get logoutMessage => tr('Are you sure you want to log out?', fr: 'Voulez-vous vraiment vous déconnecter ?', ar: 'هل أنت متأكد من تسجيل الخروج؟');

  // ── Status ──
  String get active => tr('Active', fr: 'Actif', ar: 'نشط');
  String get maintenance_ => tr('Maintenance', fr: 'Maintenance', ar: 'صيانة');
  String get idle => tr('Idle', fr: 'Inactif', ar: 'خامل');
  String get assigned => tr('ASSIGNED', fr: 'ATTRIBUÉ', ar: 'معين');
  String get unassigned => tr('UNASSIGNED', fr: 'NON ATTRIBUÉ', ar: 'غير معين');
  String get trash => tr('Trash', fr: 'Corbeille', ar: 'سلة المهملات');
  String get deleted => tr('DELETED', fr: 'SUPPRIMÉ', ar: 'محذوف');
  String get activeOps => tr('ACTIVE OPS', fr: 'OPÉRATIONS ACTIVES', ar: 'عمليات نشطة');

  // ── Language names ──
  String get langEn => tr('English', fr: 'Anglais', ar: 'الإنجليزية');
  String get langFr => tr('French', fr: 'Français', ar: 'الفرنسية');
  String get langAr => tr('Arabic', fr: 'Arabe', ar: 'العربية');
}

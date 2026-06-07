import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../constants.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _backendOffline = false;
  String? _token;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userStr = prefs.getString('auth_user');
    if (userStr != null) {
      final u = json.decode(userStr);
      _isAdmin = u['role'] == 'admin';
    }
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('$kApiBaseUrl/api/users'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(json.decode(res.body));
          _isLoading = false;
          _backendOffline = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() { _isLoading = false; _backendOffline = true; });
  }

  Future<void> _createUser(Map<String, dynamic> data) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBaseUrl/api/users'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_token'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 201) {
        _showSnack('Utilisateur créé');
        _fetchUsers();
      } else {
        _showSnack('Erreur: ${json.decode(res.body)['detail'] ?? res.statusCode}', isError: true);
      }
    } catch (_) {
      _showSnack('Erreur serveur', isError: true);
    }
  }

  Future<void> _deleteUser(int userId) async {
    try {
      final res = await http.delete(
        Uri.parse('$kApiBaseUrl/api/users/$userId'),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        _showSnack('Utilisateur supprimé');
        _fetchUsers();
      } else {
        _showSnack('Erreur: ${json.decode(res.body)['detail'] ?? res.statusCode}', isError: true);
      }
    } catch (_) {
      _showSnack('Erreur serveur', isError: true);
    }
  }

  void _showAddDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    String role = 'operator';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Nouvel utilisateur'),
          content: SizedBox(
            width: math.min(MediaQuery.of(ctx).size.width - 32, 400),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Mot de passe', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder()), obscureText: true),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Rôle', filled: true, fillColor: Color(0xFFF8FAFC), border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'operator', child: Text('Opérateur')),
                    DropdownMenuItem(value: 'viewer', child: Text('Observateur')),
                  ],
                  onChanged: (v) { if (v != null) setDialogState(() => role = v); },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                  _showSnack('Champs obligatoires manquants', isError: true);
                  return;
                }
                _createUser({
                  'name': nameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'password': passCtrl.text,
                  'phone': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  'role': role,
                });
                Navigator.pop(ctx);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF0F172A),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline, size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text('Accès réservé aux administrateurs', style: TextStyle(color: Color(0xFF64748B), fontSize: 16)),
        ]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_backendOffline) Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
          child: Row(children: [
            const Icon(Icons.wifi_off, color: Color(0xFFF59E0B), size: 16),
            const SizedBox(width: 10),
            const Expanded(child: Text('Backend hors ligne', style: TextStyle(color: Color(0xFF92400E), fontSize: 11))),
            TextButton(onPressed: _fetchUsers, child: const Text('Réessayer', style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11))),
          ]),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Gestion des utilisateurs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text('${_users.length} utilisateur(s)', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _buildButton('Nouvel utilisateur', Icons.person_add, onTap: _showAddDialog),
                const SizedBox(width: 10),
                _buildButton('Actualiser', Icons.refresh, onTap: _fetchUsers),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (_isLoading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_users.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucun utilisateur', style: TextStyle(color: Color(0xFF94A3B8)))))
        else
          ..._users.map((u) => _buildUserCard(u)),
      ]),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final initials = (u['name'] as String).trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join();
    final role = u['role'] as String? ?? 'operator';
    final isActive = u['is_active'] as bool? ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        ),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
          Text(u['email'] ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11), overflow: TextOverflow.ellipsis),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: role == 'admin' ? const Color(0xFFEFF6FF) : role == 'operator' ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            role == 'admin' ? 'ADM' : role == 'operator' ? 'OP' : 'VIEW',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: role == 'admin' ? const Color(0xFF3B82F6) : role == 'operator' ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
          ),
        ),
        Container(width: 8, height: 8, decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, shape: BoxShape.circle)),
        if ((u['id'] as int?) != 1)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (action) {
              if (action == 'delete') {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Confirmer'),
                    content: Text('Supprimer ${u['name']} ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () { Navigator.pop(context); _deleteUser(u['id']); },
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: Colors.red))])),
            ],
          ),
      ]),
    );
  }

  Widget _buildButton(String label, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        ]),
      ),
    );
  }
}

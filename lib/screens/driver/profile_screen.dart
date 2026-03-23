// lib/screens/profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/welcome_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // MISMA BASE que estás usando en driver:
  static const String _api = 'https://158.23.170.129/flashride/public/api';

  // MISMO color que DriverHomeScreen
  static const _brand = Color(0xFFFF1B8F);

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final token = await AuthService.getToken();
      if (token == null) {
        _logout();
        return;
      }

      final res = await http.get(
        Uri.parse('$_api/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
        return;
      }

      if (res.statusCode == 401) {
        _logout();
        return;
      }

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error perfil (${res.statusCode})')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error de red. Intenta de nuevo.')),
      );
    }
  }

  Future<void> _goEdit() async {
    if (_profileData == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(initial: _profileData!),
      ),
    );

    // Si regresó "true", recarga perfil
    if (updated == true) {
      await _fetchProfile(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
    }
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: _brand),
        title: Text(title),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (_profileData?['name'] ?? '').toString();
    final email = (_profileData?['email'] ?? '').toString();
    final phone = (_profileData?['phone'] ?? '').toString();
    final role = (_profileData?['role'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        backgroundColor: _brand,
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: () => _fetchProfile(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profileData == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Error al cargar perfil'),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _fetchProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoTile(
                          icon: Icons.person,
                          title: 'Nombre completo',
                          value: name,
                        ),
                        _infoTile(
                          icon: Icons.email,
                          title: 'Email',
                          value: email,
                        ),
                        _infoTile(
                          icon: Icons.phone,
                          title: 'Teléfono',
                          value: phone,
                        ),
                        _infoTile(
                          icon: Icons.badge,
                          title: 'Rol',
                          value: role,
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _goEdit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit),
                            label: const Text('Editar perfil'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

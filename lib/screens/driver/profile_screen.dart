// lib/screens/profile_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    final token = await AuthService.getToken();
    if (token == null) {
      _logout();
      return;
    }

    final res = await http.get(
      Uri.parse('http://158.23.170.129/api/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } else {
      _logout();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        backgroundColor: const Color(0xFF73003C),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _profileData == null
                ? const Center(child: Text('Error al cargar perfil'))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Nombre completo'),
                          subtitle:
                              Text(_profileData!['name'] as String? ?? '-'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle:
                              Text(_profileData!['email'] as String? ?? '-'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.phone),
                          title: const Text('Teléfono'),
                          subtitle:
                              Text(_profileData!['phone'] as String? ?? '-'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.badge),
                          title: const Text('Rol'),
                          subtitle:
                              Text(_profileData!['role'] as String? ?? '-'),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              // Aquí podrías permitir editar datos de perfil
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Función de edición aún no implementada')),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF73003C),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 12),
                            ),
                            child: const Text('Editar perfil'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
